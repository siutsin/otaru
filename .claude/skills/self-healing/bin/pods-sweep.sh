#!/usr/bin/env bash
# pods-sweep.sh — fast parallel bad-pod sweep for the self-healing loop.
#
# The MCP k8s `pods_list` tool truncates its output (~20k chars), so the
# fleet-wide list is unusable. Querying `pods_list_in_namespace` one
# namespace at a time is correct but too slow sequentially (43 namespaces
# blew the 1200s cron budget when the tailnet stalled). This script runs
# the per-namespace queries in parallel — each job writes to its own file
# (sharing one stdout across -P jobs interleaves lines and corrupts
# records) — and prints only pods that need attention.
#
# Usage: pods-sweep.sh [--parallel N] [--restarts N]
# Exit 0 always; prints "OK: ..." when nothing bad is found.
set -u

PARALLEL=12
RESTART_ALERT=20
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parallel) PARALLEL="$2"; shift 2 ;;
    --restarts) RESTART_ALERT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

MCP="$HOME/workspace/skills/mcp/bin/mcp-cli"
export MCP

ns_names() {
  "$MCP" call-tool --endpoint k8s --name namespaces_list \
    --arguments-json '{}' 2>/dev/null \
  | python3 -c "
import json,sys
t=json.load(sys.stdin)['content'][0]['text']
for line in t.splitlines()[1:]:
    parts=line.split()
    if len(parts)>=3: print(parts[2])
"
}

sweep_ns() {
  local ns="$1"
  "$MCP" call-tool --endpoint k8s --name pods_list_in_namespace \
    --arguments-json "{\"namespace\":\"$ns\"}" 2>/dev/null \
  | python3 -c "
import json,sys
t=json.load(sys.stdin)['content'][0]['text']
print(t)
" 2>/dev/null | awk -v ns="$ns" -v ra="$RESTART_ALERT" '
NR==1 {next}
NF<8 {next}
{
  status=$6; restarts=$7+0
  if (status !~ /^(Running|Completed|Succeeded)$/ ||
      $0 ~ /CrashLoopBackOff|ImagePullBackOff|ErrImagePull|CreateContainerConfigError|ContainerCreating/ ||
      restarts >= ra)
    printf "BAD ns=%s pod=%s status=%s restarts=%s age=%s node=%s\n", ns, $4, status, $7, $8, $10
}'
}
export -f sweep_ns

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

ns_names > "$tmpdir/ns.txt"
total_ns=$(wc -l < "$tmpdir/ns.txt")
if [[ "$total_ns" -eq 0 ]]; then
  echo "QUERY_FAILED: could not list namespaces" >&2
  exit 1
fi

idx=0
while IFS= read -r ns; do
  printf '%s\t%s\n' "$idx" "$ns" >> "$tmpdir/jobs.tsv"
  idx=$((idx+1))
done < "$tmpdir/ns.txt"

run_job() {
  # $1 = index, $2 = namespace (xargs splits the tsv line)
  sweep_ns "$2" > "$tmpdir/ns-$1.out" 2>/dev/null || \
    echo "QUERY_FAILED ns=$2" > "$tmpdir/ns-$1.out"
}
export -f run_job

xargs -a "$tmpdir/jobs.tsv" -P "$PARALLEL" -n2 bash -c 'run_job "$0" "$1"' 2>/dev/null

cat "$tmpdir"/ns-*.out 2>/dev/null | sort > "$tmpdir/bad.txt"

if grep -q '^BAD ' "$tmpdir/bad.txt"; then
  grep '^BAD ' "$tmpdir/bad.txt"
  echo "RESULT: BAD_PODS_FOUND"
elif grep -q '^QUERY_FAILED' "$tmpdir/bad.txt"; then
  grep '^QUERY_FAILED' "$tmpdir/bad.txt"
  echo "RESULT: SWEEP_INCOMPLETE"
else
  echo "OK: $total_ns namespaces swept, no bad pods"
fi
