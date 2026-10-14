// Chart cache for the Istio and Longhorn Helm repositories.
// Packages are stored in R2 after a digest check against the index.
// The index is kept in R2 and refreshed from upstream every 5 minutes.

const HOST = "charts.siutsin.com";
const FRESH_MS = 5 * 60 * 1000;

const REPOS = {
  istio: {
    index: "https://istio-release.storage.googleapis.com/charts/index.yaml",
    indexKey: "index/istio.yaml",
    upstreamBase: "https://istio-release.storage.googleapis.com/charts/",
    localBase: `https://${HOST}/istio/`,
    upstreamPath: (rest) => rest,
    packagePath: (rest) => rest.endsWith(".tgz"),
  },
  longhorn: {
    index: "https://charts.longhorn.io/index.yaml",
    indexKey: "index/longhorn.yaml",
    upstreamBase: "https://github.com/longhorn/charts/releases/download/",
    localBase: `https://${HOST}/longhorn/releases/`,
    upstreamPath: (rest) => rest.replace(/^releases\//, ""),
    packagePath: (rest) => rest.startsWith("releases/") && rest.endsWith(".tgz"),
  },
};

const REDIRECT_HOSTS = new Set([
  "github.com",
  "release-assets.githubusercontent.com",
]);

// Fetch with redirects followed by hand, so a redirect can only land on
// the original host or a known download host.
async function fetchUpstream(url) {
  let current = url;
  for (let hop = 0; hop < 3; hop++) {
    const res = await fetch(current, { redirect: "manual" });
    if (res.status < 300 || res.status >= 400) return res;
    const next = new URL(res.headers.get("location"), current);
    if (next.host !== new URL(url).host && !REDIRECT_HOSTS.has(next.host)) {
      throw new Error(`redirect to unexpected host ${next.host}`);
    }
    current = next.toString();
  }
  throw new Error("too many redirects");
}

async function sha256Hex(buf) {
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// The digest belongs to the index entry that lists the package URL, so
// bound the search to that entry. Returns null when not found.
function indexDigest(indexText, localUrl) {
  const at = indexText.indexOf(localUrl);
  if (at < 0) return null;
  const start = indexText.lastIndexOf("\n  - ", at) + 1;
  const end = indexText.indexOf("\n  - ", at);
  const entry = indexText.slice(start, end < 0 ? undefined : end);
  const match = entry.match(/digest: ([a-f0-9]{64})/);
  return match ? match[1] : null;
}

// Returns the rewritten index text: the stored copy while it is fresh,
// a refreshed copy after 5 minutes, the stored copy at any age when the
// upstream fetch fails, and null when there is nothing to serve.
async function getIndex(env, repo, ctx) {
  const stored = await env.CHARTS.get(repo.indexKey);
  const fetchedAt = stored ? stored.uploaded.getTime() : 0;
  if (stored && Date.now() - fetchedAt < FRESH_MS) {
    return stored.text();
  }
  try {
    const res = await fetchUpstream(repo.index);
    if (!res.ok) throw new Error(`upstream status ${res.status}`);
    const text = (await res.text()).replaceAll(
      repo.upstreamBase,
      repo.localBase,
    );
    ctx.waitUntil(env.CHARTS.put(repo.indexKey, text));
    return text;
  } catch {
    return stored ? stored.text() : null;
  }
}

function packageResponse(body, cacheState) {
  return new Response(body, {
    headers: {
      "content-type": "application/octet-stream",
      "cache-control": "public, max-age=31536000, immutable",
      "x-chart-cache": cacheState,
    },
  });
}

async function getPackage(env, repoName, repo, rest, ctx) {
  const key = `pkg/${repoName}/${rest}`;
  const hit = await env.CHARTS.get(key);
  if (hit) return packageResponse(hit.body, "HIT");

  const upstream = repo.upstreamBase + repo.upstreamPath(rest);
  let buf;
  try {
    const res = await fetchUpstream(upstream);
    if (!res.ok) return new Response("upstream error", { status: 502 });
    buf = await res.arrayBuffer();
  } catch {
    return new Response("upstream error", { status: 502 });
  }

  const index = await getIndex(env, repo, ctx);
  const expected = index
    ? indexDigest(index, repo.localBase + repo.upstreamPath(rest))
    : null;
  if (!expected || (await sha256Hex(buf)) !== expected) {
    return new Response("digest check failed", { status: 502 });
  }
  // Awaited, not waitUntil: the warm-and-verify step lists R2 as soon as
  // the response returns.
  await env.CHARTS.put(key, buf, {
    customMetadata: { sha256: expected, upstream },
  });
  return packageResponse(buf, "MISS");
}

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("method not allowed", { status: 405 });
    }
    const url = new URL(request.url);
    if (url.search) return new Response("bad request", { status: 400 });
    const [repoName, ...restParts] = url.pathname.split("/").filter(Boolean);
    const rest = restParts.join("/");

    const repo = REPOS[repoName];
    if (!repo) return new Response("not found", { status: 404 });
    if (
      !rest ||
      rest.includes("..") ||
      rest.includes("\\") ||
      rest.includes("%")
    ) {
      return new Response("bad request", { status: 400 });
    }

    let response;
    if (rest === "index.yaml") {
      const index = await getIndex(env, repo, ctx);
      if (index === null) {
        return new Response("upstream unavailable", { status: 502 });
      }
      response = new Response(index, {
        headers: {
          "content-type": "text/yaml; charset=utf-8",
          "cache-control": "public, max-age=300",
        },
      });
    } else if (repo.packagePath(rest)) {
      response = await getPackage(env, repoName, repo, rest, ctx);
    } else {
      return new Response("not found", { status: 404 });
    }
    if (request.method === "HEAD") {
      return new Response(null, { status: response.status, headers: response.headers });
    }
    return response;
  },
};
