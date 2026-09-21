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
# Exit 0 normally; the caller greps stdout for BAD / QUERY_FAILED / OK /
# RESULT: markers. Exits 1 only when the namespace list itself cannot be
# fetched (nothing can be swept at all).
set -uo pipefail

PARALLEL=12
RESTART_ALERT=20
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parallel) PARALLEL="${2:?--parallel needs a value}"; shift 2 ;;
    --restarts) RESTART_ALERT="${2:?--restarts needs a value}"; shift 2 ;;
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
  # pipefail must be set inside the function: run_job executes in a
  # child bash spawned by xargs, which does not inherit -o pipefail
  # from the parent shell.
  set -o pipefail
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
# run_job/sweep_ns execute in child bash processes spawned by xargs:
# everything they touch must be exported, or they silently see empty
# values (unexported tmpdir once made every sweep report a false OK).
export tmpdir RESTART_ALERT

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

out_files=( "$tmpdir"/ns-*.out )
if [[ ! -e ${out_files[0]} ]]; then
  # No per-namespace output at all (xargs failed outright) — never OK.
  echo "QUERY_FAILED: no namespace sweep output files produced"
  echo "RESULT: SWEEP_INCOMPLETE"
  exit 0
fi

cat "${out_files[@]}" | sort > "$tmpdir/bad.txt"

bad_lines=$(grep '^BAD ' "$tmpdir/bad.txt" || true)
qf_lines=$(grep '^QUERY_FAILED' "$tmpdir/bad.txt" || true)

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
