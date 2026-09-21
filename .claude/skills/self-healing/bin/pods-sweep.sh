#!/usr/bin/env bash
# pods-sweep.sh — batched bad-pod sweep for the self-healing loop.
#
# The MCP k8s `pods_list` tool truncates its output (~20k chars), so the
# fleet-wide list is unusable. This script batches `pods_list_in_namespace`
# calls through `mcp-cli call-tools` — one MCP session per batch, at most
# 15 namespaces per batch (larger batches risk the ~200 KB output cap,
# which truncates silently into invalid JSON) — and prints only pods that
# need attention.
#
# Table parsing is header-derived, never positional: a fixed column layout
# caused a merged defect (PR #3311) when the table gained a column.
#
# Usage: pods-sweep.sh [--restarts N] [--batch N]
# Markers on stdout: BAD / QUERY_FAILED / OK / RESULT:.
# Exits 1 only when the namespace list itself cannot be fetched (nothing
# can be swept at all).
set -uo pipefail

RESTART_ALERT=20
BATCH=15
while [[ $# -gt 0 ]]; do
  case "$1" in
    --restarts) RESTART_ALERT="${2:?--restarts needs a value}"; shift 2 ;;
    --batch) BATCH="${2:?--batch needs a value}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Base-10 arithmetic: plain (( )) treats leading-zero values as octal.
if ! [[ "$BATCH" =~ ^[0-9]+$ ]] || (( 10#$BATCH < 1 || 10#$BATCH > 15 )); then
  echo "--batch must be an integer 1-15 (output-cap safety limit)" >&2
  exit 2
fi
# Normalize: chunking below compares "$BATCH" textually, and [[ -ge ]]
# treats leading-zero values as octal — --batch 08 would silently merge
# every namespace into one batch, defeating the safety bound above.
BATCH=$((10#$BATCH))

if ! [[ "$RESTART_ALERT" =~ ^[0-9]+$ ]]; then
  echo "--restarts must be a non-negative integer" >&2
  exit 2
fi

# Overridable for the regression tests (tests/pods-sweep.test.sh); the
# scheduled loop always uses the real connector binary.
MCP="${MCP:-$HOME/workspace/skills/mcp/bin/mcp-cli}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# One session, one handshake, one call: list namespaces.
"$MCP" call-tools --endpoint k8s \
  --calls-json '[{"name":"namespaces_list","arguments":{}}]' \
  2>/dev/null > "$tmpdir/ns.json" || true

python3 - "$tmpdir/ns.json" > "$tmpdir/ns.txt" <<'EOF'
import json, sys
try:
    env = json.load(open(sys.argv[1]))[0]
    if not isinstance(env, dict) or not env.get("ok"):
        raise ValueError("bad envelope")
    text = env["result"]["content"][0]["text"]
    # Scan for the NAME header like parse_table does; a leading junk or
    # blank line must not shift the parse or crash the whole sweep.
    name_idx, start = None, 0
    lines = text.splitlines()
    for i, line in enumerate(lines):
        parts = line.split()
        if "NAME" in parts:
            name_idx = parts.index("NAME")
            start = i + 1
            break
    if name_idx is None:
        raise ValueError("no NAME header in namespace list")
except Exception as e:
    print("ns-list parse failed: %s" % e, file=sys.stderr)
    lines, name_idx, start = [], 0, 0
for line in lines[start:]:
    parts = line.split()
    if len(parts) > name_idx:
        print(parts[name_idx])
EOF

total_ns=$(grep -c . "$tmpdir/ns.txt" || true)
if [[ "$total_ns" -eq 0 ]]; then
  echo "QUERY_FAILED: could not list namespaces" >&2
  exit 1
fi

mapfile -t NS < "$tmpdir/ns.txt"

# Chunk namespaces into batches of $BATCH; one call-tools run per chunk.
batch=0
chunk=()
run_chunk() {
  local calls='[' sep=''
  local ns
  for ns in "${chunk[@]}"; do
    calls+="${sep}{\"name\":\"pods_list_in_namespace\",\"arguments\":{\"namespace\":\"$ns\"}}"
    sep=','
  done
  calls+=']'
  printf '%s\n' "${chunk[@]}" > "$tmpdir/batch-$batch.ns"
  "$MCP" call-tools --endpoint k8s --calls-json "$calls" 2>/dev/null \
    > "$tmpdir/batch-$batch.json" || echo "CALL_FAILED" > "$tmpdir/batch-$batch.json"
  batch=$((batch + 1))
}
for ns in "${NS[@]}"; do
  chunk+=("$ns")
  if [[ "${#chunk[@]}" -ge "$BATCH" ]]; then
    run_chunk
    chunk=()
  fi
done
[[ "${#chunk[@]}" -gt 0 ]] && run_chunk

sweep_out="$tmpdir/sweep.out"
# Any parser crash must fail closed: never leave sweep.out empty (or
# partial) where the final tally would read it as a clean OK.
if ! python3 - "$tmpdir" "$RESTART_ALERT" > "$sweep_out" <<'EOF'
import json, glob, os, sys, re

tmpdir, restart_alert = sys.argv[1], int(sys.argv[2])
bad_re = re.compile(
    r"CrashLoopBackOff|ImagePullBackOff|ErrImagePull|"
    r"CreateContainerConfigError|ContainerCreating")
GOOD = {"Running", "Completed", "Succeeded"}

def parse_table(text):
    """Header-derived parse -> rows with name/status/restarts/age/node.

    The RESTARTS column can render as `28 (35d ago)` — the parenthesised
    restart age contains spaces, so everything after RESTARTS shifts.
    Consume the group as part of RESTARTS before reading AGE/NODE.
    """
    rows, header = [], None
    if not text.strip():
        # The connector returns empty text (no table at all) for a
        # namespace with zero pods. That is not a failure signal.
        return rows
    for line in text.splitlines():
        parts = line.split()
        if not parts:
            continue
        if header is None:
            try:
                header = {t: parts.index(t)
                          for t in ("NAME", "STATUS", "RESTARTS", "AGE", "NODE")}
            except ValueError:
                continue  # not the header line; keep looking
            continue
        try:
            r_idx = header["RESTARTS"]
            extra = 0
            if (r_idx + 1 < len(parts) and parts[r_idx + 1].startswith("(")
                    and not parts[r_idx + 1].endswith(")")):
                j = r_idx + 1
                while j < len(parts) and not parts[j].endswith(")"):
                    j += 1
                extra = j - r_idx
            rows.append({
                "NAME": parts[header["NAME"]],
                "STATUS": parts[header["STATUS"]],
                "RESTARTS": parts[r_idx],
                "AGE": parts[header["AGE"] + extra],
                "NODE": parts[header["NODE"] + extra],
            })
        except (IndexError, ValueError):
            continue  # ragged row: skip rather than misparse
    # An ok:true envelope with non-empty non-table text (error text,
    # garbage) must not sweep as clean: a namespace with zero pods yields
    # empty text, which is handled above, not here.
    if header is None:
        raise ValueError("no table header in response")
    return rows

out = []
for path in sorted(glob.glob(os.path.join(tmpdir, "batch-*.json"))):
    tag = os.path.basename(path).replace(".json", "")
    ns_path = os.path.join(tmpdir, tag + ".ns")
    try:
        namespaces = open(ns_path).read().split()
    except OSError:
        out.append("QUERY_FAILED %s: missing batch manifest" % tag)
        continue
    try:
        envs = json.loads(open(path).read())
    except Exception:
        out.append("QUERY_FAILED %s: invalid JSON (truncated?)" % tag)
        continue
    if not isinstance(envs, list) or len(envs) != len(namespaces):
        out.append("QUERY_FAILED %s: envelope mismatch" % tag)
        continue
    for ns, env in zip(namespaces, envs):
        # A non-dict envelope (e.g. JSON null from a truncated batch) must
        # surface as QUERY_FAILED, never crash into an empty false-OK sweep.
        # The MCP server also reports tool-level errors as ok:true with
        # result.isError:true — an error text has no table, so it must be
        # rejected too, not swept as "no bad pods".
        if not isinstance(env, dict) or not env.get("ok"):
            out.append("QUERY_FAILED ns=%s" % ns)
            continue
        result = env.get("result")
        if isinstance(result, dict) and result.get("isError"):
            out.append("QUERY_FAILED ns=%s: tool error" % ns)
            continue
        try:
            text = env["result"]["content"][0]["text"]
        except Exception:
            out.append("QUERY_FAILED ns=%s: bad envelope" % ns)
            continue
        try:
            rows = parse_table(text)
        except ValueError as e:
            out.append("QUERY_FAILED ns=%s: %s" % (ns, e))
            continue
        for r in rows:
            try:
                restarts = int(r["RESTARTS"])
            except ValueError:
                restarts = 0
            if (r["STATUS"] not in GOOD or bad_re.search(r["STATUS"]) or
                    restarts >= restart_alert):
                out.append(
                    "BAD ns=%s pod=%s status=%s restarts=%s age=%s node=%s"
                    % (ns, r["NAME"], r["STATUS"], r["RESTARTS"],
                        r["AGE"], r["NODE"]))

for line in out:
    print(line)
EOF
then
  echo "QUERY_FAILED: sweep parser crashed" > "$sweep_out"
fi

bad_lines=$(grep '^BAD ' "$sweep_out" || true)
qf_lines=$(grep '^QUERY_FAILED' "$sweep_out" || true)

# Always surface incomplete-sweep evidence, even alongside bad pods.
[[ -n "$qf_lines" ]] && echo "$qf_lines"
if [[ -n "$bad_lines" ]]; then
  echo "$bad_lines"
  echo "RESULT: BAD_PODS_FOUND"
elif [[ -n "$qf_lines" ]]; then
  echo "RESULT: SWEEP_INCOMPLETE"
else
  echo "OK: $total_ns namespaces swept, no bad pods"
fi
