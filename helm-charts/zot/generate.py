#!/usr/bin/env python3
"""Generate the zot pin artefacts from the repo pin sources.

Image pins come from the chart values files, read with the census
method (inline repo:tag@digest strings, split repository/tag/digest
fields, and split pins resolved against the wrapper's other values
files and the vendored subchart defaults). Chart pins come from the
Chart.lock dependency lists plus the direct chart source in
argocd/manifest.jsonnet. Chart classification (form, zot path, tag
form) is data in census.json; an unlisted chart fails the run.

Outputs: generated.yaml (sync entries and retention policies),
helm-charts/argocd/zot-chart-mapping.yaml (the chart mapping for
the argocd wrapper) and pin-state.json (the replaced pins of the
last pin change; the state rotates only when a pin changes, so
re-runs change nothing). Each run also refreshes census.json's
locked versions and pin tags from the scan.

Modes: no flag writes; --check diffs without writing; --selftest
runs the tag-escape and canonical-name fixtures; --cidrs rewrites
cidrs.json from the live nodes through the Kubernetes MCP client.
"""

import io
import json
import os
import re
import subprocess
import sys
import tarfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
CHART_DIR = Path(__file__).resolve().parent
SHA = r"sha256:[0-9a-f]{64}"
SHA_RE = re.compile(SHA)

# The canonical mapping table: one on-demand sync entry per host.
# pollInterval and syncTimeout for a poll entry: the first dhi.io
# cycle syncs the whole pinned set, so it gets the headroom a
# full-catalogue round needs.
HOSTS = [
    "docker.io",
    "dhi.io",
    "ghcr.io",
    "quay.io",
    "registry.k8s.io",
    "public.ecr.aws",
    "ecr-public.aws.com",
    "mirror.gcr.io",
    "registry.istio.io",
    "cr.fluentbit.io",
    "falco.docker.scarf.sh",
    "us-docker.pkg.dev",
]
UPSTREAM_URLS = {
    "docker.io": "https://registry-1.docker.io",
    "dhi.io": "https://dhi.io",
}
POLL_HOST = "dhi.io"
POLL_INTERVAL = "24h"
POLL_SYNC_TIMEOUT = "30m"
ON_DEMAND_SYNC_TIMEOUT = "60s"
RETENTION_PULLED_WITHIN = "720h"  # 30 days


def escape_tag(tag):
    """Anchor a tag as a literal regex: a dot matches a dot only."""
    return "^" + re.escape(tag) + "$"


def split_host(path):
    first = path.split("/")[0]
    if "." in first or ":" in first or first == "localhost":
        return first, path
    return "docker.io", path


def canon(host, path):
    host = {"index.docker.io": "docker.io", "registry-1.docker.io": "docker.io"}.get(
        host, host
    )
    first = path.split("/")[0]
    if "." in first or ":" in first:
        path = path.split("/", 1)[1] if "/" in path else path
    if host == "docker.io" and "/" not in path:
        path = "library/" + path
    return host, f"{host}/{path}"


# ---------------------------------------------------------------- images


def scan_images():
    refs = []
    split_candidates = []

    def add_ref(raw_repo, tag, digest, registry=None):
        raw_repo = str(raw_repo).strip().strip('"').strip("'")
        if not raw_repo or "://" in raw_repo:
            return
        full = raw_repo
        if registry and "." not in raw_repo.split("/")[0]:
            full = f"{registry}/{raw_repo}"
        host, canonical = canon(*split_host(full))
        if tag and "@" in str(tag) and "sha256:" in str(tag):
            tag, digest = str(tag).split("@", 1)
        if not digest or not str(digest).startswith("sha256:"):
            return
        refs.append(
            {
                "image": canonical,
                "host": host,
                "repository": canonical.split("/", 1)[1],
                "tag": str(tag) if tag else None,
                "digest": digest,
            }
        )

    img_str_re = re.compile(
        r"^(?P<repo>[a-zA-Z0-9._\-]+(?:/[a-zA-Z0-9._\-]+)+)"
        r"(?::(?P<tag>[^\s@]+))?(?:@(?P<digest>" + SHA + r"))?$"
    )

    def walk(node, wrapper, ypath):
        if isinstance(node, dict):
            repo = node.get("repository")
            tag = node.get("tag")
            if tag is None and isinstance(node.get("version"), str):
                tag = node["version"]
            digest = node.get("digest")
            has_pin = (digest and str(digest).startswith("sha256:")) or (
                isinstance(tag, str) and "@sha256:" in tag
            )
            if isinstance(repo, str) and repo and has_pin:
                add_ref(
                    repo,
                    tag,
                    digest,
                    registry=(
                        node.get("registry")
                        if isinstance(node.get("registry"), str)
                        else None
                    ),
                )
            elif has_pin and not isinstance(repo, str):
                split_candidates.append(
                    {
                        "tag": str(tag) if tag else None,
                        "digest": (
                            str(digest)
                            if digest
                            else (
                                str(tag).split("@", 1)[1]
                                if tag and "@" in str(tag)
                                else None
                            )
                        ),
                        "wrapper": wrapper,
                        "yaml_path": ypath,
                    }
                )
            for key in ("image", "imageName"):
                if isinstance(node.get(key), str):
                    m = img_str_re.match(node[key].strip())
                    if m and m.group("digest"):
                        add_ref(m.group("repo"), m.group("tag"), m.group("digest"))
            if isinstance(node.get("image_name"), str):
                ver = node.get("image_version") or node.get("image_tag")
                t = d = None
                if isinstance(ver, str) and "@" in ver:
                    t, d = ver.split("@", 1)
                elif isinstance(ver, str):
                    t = ver
                if d:
                    add_ref(node["image_name"], t, d)
            for k, v in node.items():
                walk(v, wrapper, f"{ypath}.{k}" if ypath else str(k))
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, wrapper, f"{ypath}[{i}]")
        elif isinstance(node, str):
            if "@sha256:" in node:
                m = img_str_re.match(node.strip())
                if m and m.group("digest"):
                    add_ref(m.group("repo"), m.group("tag"), m.group("digest"))

    def load_docs(path):
        try:
            return [d for d in yaml.safe_load_all(open(path)) if d]
        except Exception:
            return []

    tier_a = []
    charts_root = ROOT / "helm-charts"
    for root, dirs, files in os.walk(charts_root):
        dirs[:] = [d for d in dirs if d not in ("charts", "templates", "crds")]
        for f in files:
            p = Path(root) / f
            rel = p.relative_to(ROOT).as_posix()
            wrapper = rel.split("/")[1] if rel.startswith("helm-charts/") else None
            if (f.startswith("values") and f.endswith((".yaml", ".yml"))) or (
                "/value/" in rel and f.endswith(".yaml")
            ):
                tier_a.append(rel)
                for doc in load_docs(p):
                    walk(doc, wrapper, "")
            elif f == "Chart.yaml":
                for doc in load_docs(p):
                    doc = dict(doc)
                    doc.pop("dependencies", None)
                    walk(doc, wrapper, "")

    for root, dirs, files in os.walk(ROOT / "argocd"):
        for f in files:
            text = (Path(root) / f).read_text(errors="ignore")
            for m in re.finditer(
                r"[a-z0-9.\-]+(?:/[a-z0-9._\-]+)+"
                r"(?::[\w.\-]+)?(?:@sha256:[0-9a-f]{64})?",
                text,
            ):
                mm = img_str_re.match(m.group(0))
                if mm and mm.group("digest"):
                    add_ref(mm.group("repo"), mm.group("tag"), mm.group("digest"))

    # Split-pin resolution: same-wrapper values files first (same YAML
    # path), then the vendored subchart defaults scoped by chart name.
    ta_index = {}
    for rel in tier_a:
        wrapper = rel.split("/")[1]
        for doc in load_docs(ROOT / rel):

            def ta_walk(node, path):
                if isinstance(node, dict):
                    if isinstance(node.get("repository"), str) and node["repository"]:
                        ta_index.setdefault((wrapper, path), []).append(
                            {
                                "repository": node["repository"],
                                "registry": node.get("registry"),
                            }
                        )
                    for k, v in node.items():
                        ta_walk(v, path + (str(k),))
                elif isinstance(node, list):
                    for i, v in enumerate(node):
                        ta_walk(v, path + (str(i),))

            ta_walk(doc, ())

    alias_map = {}
    for root, dirs, files in os.walk(charts_root):
        dirs[:] = [d for d in dirs if d != "charts"]
        if "Chart.yaml" in files:
            rel = (Path(root) / "Chart.yaml").relative_to(ROOT).as_posix()
            wrapper = rel.split("/")[1]
            for doc in load_docs(Path(root) / "Chart.yaml"):
                for dep in doc.get("dependencies") or []:
                    if dep.get("name"):
                        alias_map[(wrapper, dep.get("alias") or dep["name"])] = dep[
                            "name"
                        ]
                        alias_map.setdefault((wrapper, dep["name"]), dep["name"])

    tb_index = {}
    for root, dirs, files in os.walk(charts_root):
        for f in files:
            if not f.endswith(".tgz"):
                continue
            tgz = Path(root) / f
            rel = tgz.relative_to(ROOT).as_posix()
            wrapper = rel.split("/")[1]
            try:
                tf = tarfile.open(tgz, "r:gz")
            except Exception:
                continue
            for member in tf.getmembers():
                if (
                    not (
                        member.name.endswith("/values.yaml")
                        or member.name == "values.yaml"
                    )
                    or not member.isfile()
                ):
                    continue
                try:
                    doc = yaml.safe_load(io.BytesIO(tf.extractfile(member).read()))
                except Exception:
                    continue
                if not isinstance(doc, dict):
                    continue
                chartname = member.name.split("/")[0]
                base = tuple(member.name.split("/")[1:-1])

                def index_walk(node, path):
                    if isinstance(node, dict):
                        if (
                            isinstance(node.get("repository"), str)
                            and node["repository"]
                        ):
                            tb_index.setdefault((wrapper, chartname, path), []).append(
                                {
                                    "repository": node["repository"],
                                    "registry": node.get("registry"),
                                }
                            )
                        for k, v in node.items():
                            index_walk(v, path + (str(k),))
                    elif isinstance(node, list):
                        for i, v in enumerate(node):
                            index_walk(v, path + (str(i),))

                index_walk(doc, base)

    unresolved = []
    for cand in split_candidates:
        tag, digest = cand["tag"], cand["digest"]
        if tag and "@" in tag:
            tag, digest = tag.split("@", 1)
        if not digest:
            unresolved.append(cand)
            continue
        ypath = tuple(cand["yaml_path"].split(".")) if cand["yaml_path"] else ()
        hit = None
        if (cand["wrapper"], ypath) in ta_index:
            hit = ta_index[(cand["wrapper"], ypath)][0]
        if not hit and ypath:
            chartname = alias_map.get((cand["wrapper"], ypath[0]))
            if chartname:
                rest = ypath[1:]
                for (w, cn, p), vals in tb_index.items():
                    if (
                        w == cand["wrapper"]
                        and cn == chartname
                        and rest
                        and len(p) >= len(rest)
                        and p[len(p) - len(rest) :] == rest
                    ):
                        hit = vals[0]
                        break
        if hit:
            add_ref(
                hit["repository"],
                tag,
                digest,
                registry=(
                    hit["registry"] if isinstance(hit.get("registry"), str) else None
                ),
            )
        else:
            unresolved.append(cand)
    if unresolved:
        raise SystemExit(
            f"error: {len(unresolved)} split pin(s) did not resolve: {unresolved}"
        )

    images = {}
    for r in refs:
        e = images.setdefault(
            r["image"],
            {
                "host": r["host"],
                "repository": r["repository"],
                "tags": set(),
                "pins": {},
            },
        )
        if r["tag"]:
            e["tags"].add(r["tag"])
        pin = f"{r['tag']}@{r['digest']}" if r["tag"] else f"@{r['digest']}"
        e["pins"][pin] = (r["tag"], r["digest"])
    # The parser artefact the census excludes by name: a platform field
    # in vendored defaults, not an image.
    images.pop("kubernetes.io/os", None)
    return images


# ---------------------------------------------------------------- charts


def scan_charts(census):
    by_name = {}
    for lock in sorted((ROOT / "helm-charts").glob("*/Chart.lock")):
        wrapper = lock.parent.name
        if wrapper == "zot":
            continue  # this wrapper's own subchart is not a plugin chart
        data = yaml.safe_load(lock.read_text()) or {}
        for dep in data.get("dependencies") or []:
            repo = dep.get("repository") or ""
            if repo.startswith("file://"):
                continue
            name = dep["name"]
            entry = by_name.setdefault(
                name, {"locked_version": str(dep["version"]), "repository": repo}
            )
            if (
                entry["locked_version"] != str(dep["version"])
                or entry["repository"] != repo
            ):
                raise SystemExit(
                    f"error: chart {name} has conflicting pins across wrappers"
                )
    mj = (ROOT / "argocd" / "manifest.jsonnet").read_text()
    m = re.search(
        r"name:\s*'(cloudnative-pg)'.*?repoURL:\s*'([^']+)',"
        r"\s*chart:\s*s\.name,\s*targetRevision:\s*'([^']+)'",
        mj,
        re.S,
    )
    if not m:
        raise SystemExit(
            "error: cloudnative-pg direct chart source not found "
            "in argocd/manifest.jsonnet"
        )
    by_name.setdefault(
        "cloudnative-pg", {"locked_version": m.group(3), "repository": m.group(2)}
    )

    charts = {}
    for name, pin in sorted(by_name.items()):
        cls = census["charts"].get(name)
        if cls is None:
            raise SystemExit(
                f"error: chart {name} is not in census.json; "
                "classify it before generating"
            )
        old_locked = cls["locked_version"]
        old_form = cls["tag_form"]
        new_locked = pin["locked_version"]
        if new_locked == old_locked or old_form == old_locked:
            new_form = old_form if new_locked == old_locked else new_locked
        elif old_form == "v" + old_locked:
            new_form = "v" + new_locked
        else:
            raise SystemExit(
                f"error: chart {name} tag form {old_form} does not follow "
                "its locked version; reclassify it in census.json"
            )
        charts[name] = {
            **pin,
            **cls,
            "locked_version": new_locked,
            "tag_form": new_form,
            "old_tag_form": old_form,
            "changed": new_locked != old_locked,
        }
    return charts


# ---------------------------------------------------------------- output


def build_outputs(images, charts, state, last_images):
    prev_images = state.get("images", {})
    prev_charts = state.get("charts", {})

    # The state rotates only when a pin changes. A run after a pin
    # change keeps the replaced tags from the census record's last
    # generation; a run with no change keeps the state file's tags.
    # Re-running the generator therefore changes nothing.
    def keep_tags(image, current):
        current = set(current)
        last = last_images.get(image, set())
        extra = set(prev_images.get(image, [])) if current == last else last
        return sorted(current | extra)

    def next_prev_image(image, current):
        last = last_images.get(image, set())
        if set(current) != last:
            return sorted(last)
        if image in prev_images:
            return prev_images[image]
        return sorted(current)

    registries = []
    for host in HOSTS:
        if host == POLL_HOST and state.get("dhi_poll"):
            content = []
            for image in sorted(i for i in images if images[i]["host"] == host):
                for tag in sorted(images[image]["tags"]):
                    content.append(
                        {
                            "prefix": images[image]["repository"],
                            "destination": f"/{host}",
                            "stripPrefix": False,
                            "tags": {"regex": escape_tag(tag), "semver": False},
                        }
                    )
            registries.append(
                {
                    "urls": [UPSTREAM_URLS.get(host, f"https://{host}")],
                    "pollInterval": POLL_INTERVAL,
                    "tlsVerify": True,
                    "maxRetries": 3,
                    "retryDelay": "30s",
                    "syncTimeout": POLL_SYNC_TIMEOUT,
                    "syncLegacyCosignTags": False,
                    "content": content,
                }
            )
        registries.append(
            {
                "urls": [UPSTREAM_URLS.get(host, f"https://{host}")],
                "onDemand": True,
                "tlsVerify": True,
                "syncTimeout": ON_DEMAND_SYNC_TIMEOUT,
                "manifestCheckInterval": "24h" if host == POLL_HOST else "1h",
                "syncLegacyCosignTags": False,
                "content": [
                    {"prefix": "**", "destination": f"/{host}", "stripPrefix": False}
                ],
            }
        )

    policies = []
    for image in sorted(images):
        info = images[image]
        keep = keep_tags(image, info["tags"])
        policies.append(
            {
                "repositories": [image],
                "deleteUntagged": False,
                "keepTags": [
                    {"patterns": [escape_tag(t) for t in keep]},
                    {"patterns": [".*"], "pulledWithin": RETENTION_PULLED_WITHIN},
                ],
            }
        )
    for name in sorted(charts):
        c = charts[name]
        if c["changed"]:
            extra = {c["old_tag_form"]}
        elif prev_charts.get(name):
            extra = {prev_charts[name]}
        else:
            extra = set()
        keep = sorted({c["tag_form"]} | extra)
        policies.append(
            {
                "repositories": [c["zot_path"].lstrip("/")],
                "deleteUntagged": True,
                "keepTags": [
                    {"patterns": [escape_tag(t) for t in keep]},
                    {"patterns": [".*"], "pulledWithin": RETENTION_PULLED_WITHIN},
                ],
            }
        )
    policies.append(
        {
            "repositories": ["**"],
            "deleteUntagged": True,
            "keepTags": [{"patterns": [".*"], "pulledWithin": RETENTION_PULLED_WITHIN}],
        }
    )

    generated = {
        "config": {
            "extensions": {"sync": {"registries": registries}},
            "storage": {"retention": {"dryRun": False, "policies": policies}},
        },
        "chartRepositories": sorted(c["zot_path"] for c in charts.values()),
    }
    mapping = {
        "zotChartMapping": {
            "charts": [
                {
                    "name": name,
                    "zotPath": c["zot_path"],
                    "lockedVersion": c["locked_version"],
                    "tagForm": c["tag_form"],
                    "form": c["form"],
                    "repository": c["repository"],
                }
                for name, c in sorted(charts.items())
            ]
        }
    }
    new_state = {
        "dhi_poll": bool(state.get("dhi_poll")),
        "images": {i: next_prev_image(i, images[i]["tags"]) for i in sorted(images)},
        "charts": {
            n: (
                charts[n]["old_tag_form"]
                if charts[n]["changed"]
                else prev_charts.get(n, charts[n]["tag_form"])
            )
            for n in sorted(charts)
        },
    }
    return generated, mapping, new_state


def dump_yaml(data, header):
    body = yaml.safe_dump(data, sort_keys=False, default_flow_style=False, width=1000)
    return header + body


GENERATED_HEADER = "# Generated by helm-charts/zot/generate.py. Do not edit.\n"


def load_census():
    raw = json.loads((CHART_DIR / "census.json").read_text())
    charts = {}
    for c in raw["charts"]["entries"]:
        charts[c["name"]] = {
            "form": c["form"],
            "zot_path": c["zot_path"],
            "tag_form": c["tag_form"],
            "locked_version": c["locked_version"],
        }
    return raw, {"charts": charts}


def refresh_census(raw, images, charts):
    """Refresh the census record's live data from the scan.

    Locked versions and pin tags follow the repo. Classification
    and provenance fields stay as recorded. Membership is not
    refreshed: an image or chart the census does not know, or one
    it knows that the scan no longer finds, fails the run, so the
    delta gets a human classification first.
    """
    entries = raw["images"]["entries"]
    recorded = {e["image"] for e in entries}
    if recorded != set(images):
        raise SystemExit(
            "error: census image set differs from the scan; "
            f"only in census: {sorted(recorded - set(images))}, "
            f"only in scan: {sorted(set(images) - recorded)}"
        )
    for e in entries:
        pins = images[e["image"]]["pins"]
        current = set(pins.values())
        have = {(p["tag"], p["digest"]) for p in e["pin_strings"]}
        if current != have:
            e["pin_strings"] = [
                {
                    "tag": tag,
                    "digest": digest,
                    "pin": pin,
                    "form": "generator-scan",
                    "sources": [],
                    "compressed_bytes_all_platforms": None,
                    "size_status": "not-measured",
                }
                for pin, (tag, digest) in sorted(pins.items())
            ]
    centries = raw["charts"]["entries"]
    recorded = {c["name"] for c in centries}
    if recorded != set(charts):
        raise SystemExit(
            "error: census chart set differs from the scan; "
            f"only in census: {sorted(recorded - set(charts))}, "
            f"only in scan: {sorted(set(charts) - recorded)}"
        )
    for c in centries:
        c["locked_version"] = charts[c["name"]]["locked_version"]
        c["tag_form"] = charts[c["name"]]["tag_form"]
    return raw


def selftest():
    cases = [
        (escape_tag("1.30.6-distroless"), "^1\\.30\\.6\\-distroless$"),
        (escape_tag("v2.1.22"), "^v2\\.1\\.22$"),
        (escape_tag("2026.10.0"), "^2026\\.10\\.0$"),
    ]
    for got, want in cases:
        assert got == want, f"escape_tag: got {got}, want {want}"
        assert re.fullmatch(
            got, want.strip("^$").replace("\\", "")
        ), f"regex {got} does not match its own tag"
    assert canon("docker.io", "busybox") == ("docker.io", "docker.io/library/busybox")
    assert canon("index.docker.io", "grafana/grafana") == (
        "docker.io",
        "docker.io/grafana/grafana",
    )
    assert canon("ghcr.io", "grafana/loki") == ("ghcr.io", "ghcr.io/grafana/loki")
    print("selftest: ok")


def cidrs():
    mcp = Path.home() / "workspace/custom-skills/local-mcp/bin/mcp-cli"
    calls = json.dumps(
        [{"name": "resources_list", "arguments": {"apiVersion": "v1", "kind": "Node"}}]
    )
    out = subprocess.run(
        [str(mcp), "call-tools", "--endpoint", "k8s", "--calls-json", calls],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    names = sorted(set(re.findall(r'"Name":\s*"([^"]+)"', out)))
    if not names:
        raise SystemExit("error: node list came back empty")
    # resources_list does not carry podCIDR; read each node object.
    result = []
    for name in names:
        calls = json.dumps(
            [
                {
                    "name": "resources_get",
                    "arguments": {"apiVersion": "v1", "kind": "Node", "name": name},
                }
            ]
        )
        out = subprocess.run(
            [str(mcp), "call-tools", "--endpoint", "k8s", "--calls-json", calls],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        m = re.search(r'"podCIDR":\s*"([0-9.]+)/(\d+)"', out)
        if not m:
            raise SystemExit(f"error: no podCIDR found for node {name}")
        result.append(
            {
                "node": name,
                "podCIDR": f"{m.group(1)}/{m.group(2)}",
                "cidr": f"{m.group(1)}/32",
            }
        )
    doc = {
        "comment": (
            "Generated by helm-charts/zot/generate.py --cidrs from the live "
            "node objects. One /32 per node: the base address of the node pod CIDR."
        ),
        "nodes": result,
    }
    (CHART_DIR / "cidrs.json").write_text(json.dumps(doc, indent=2) + "\n")
    print(f"cidrs: wrote {len(result)} entries")


def main():
    args = sys.argv[1:]
    if "--selftest" in args:
        selftest()
        return
    if "--cidrs" in args:
        cidrs()
        return
    raw, census = load_census()
    state_path = CHART_DIR / "pin-state.json"
    state = (
        json.loads(state_path.read_text())
        if state_path.exists()
        else {"dhi_poll": False, "images": {}, "charts": {}}
    )
    images = scan_images()
    charts = scan_charts(census)
    last_images = {
        e["image"]: {p["tag"] for p in e["pin_strings"] if p["tag"]}
        for e in raw["images"]["entries"]
    }
    refreshed = refresh_census(raw, images, charts)
    generated, mapping, new_state = build_outputs(images, charts, state, last_images)

    files = {
        CHART_DIR / "census.json": json.dumps(refreshed, indent=2, ensure_ascii=True)
        + "\n",
        CHART_DIR / "generated.yaml": dump_yaml(generated, GENERATED_HEADER),
        ROOT
        / "helm-charts/argocd/zot-chart-mapping.yaml": dump_yaml(
            mapping, GENERATED_HEADER
        ),
        state_path: json.dumps(new_state, indent=2) + "\n",
    }
    if "--check" in args:
        stale = [
            str(p)
            for p, content in files.items()
            if not p.exists() or p.read_text() != content
        ]
        if stale:
            print("stale generated files: " + ", ".join(stale))
            return 1
        print("generated files are current")
        return 0
    for path, content in files.items():
        path.write_text(content)
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
