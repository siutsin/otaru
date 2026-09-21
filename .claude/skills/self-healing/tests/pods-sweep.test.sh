#!/usr/bin/env bash
# pods-sweep.test.sh — regression tests for bin/pods-sweep.sh.
#
# Runs the real script against a stubbed mcp-cli (no cluster, no tunnel).
# Each test drops canned MCP envelopes into a temp dir and asserts on the
# script's stdout markers (BAD / QUERY_FAILED / OK / RESULT:) and exit code.
#
# Run: bash pods-sweep.test.sh   (or `make test-pods-sweep` from repo root)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEP="$SCRIPT_DIR/../bin/pods-sweep.sh"

pass=0
fail=0
FAILED_TESTS=()

ok() { pass=$((pass + 1)); }
not_ok() { fail=$((fail + 1)); FAILED_TESTS+=("$1"); echo "FAIL: $1 -- $2"; }

assert_eq() { # name expected actual
  if [[ "$2" == "$3" ]]; then ok; else not_ok "$1" "expected [$2], got [$3]"; fi
}

assert_contains() { # name haystack needle
  if [[ "$2" == *"$3"* ]]; then ok; else not_ok "$1" "missing [$3] in: $2"; fi
}

# --- stub fixtures -------------------------------------------------------
# STUB_DIR/ns.json: namespaces_list response. STUB_DIR/batch.json: one
# call-tools batch response. The stub picks by the requested tool name.
new_stub() {
  STUB_DIR=$(mktemp -d)
  cat > "$STUB_DIR/mcp-stub" <<'STUB'
#!/usr/bin/env bash
calls=""; prev=""
for a in "$@"; do
  [[ "$prev" == "--calls-json" ]] && calls="$a"
  prev="$a"
done
if [[ "${STUB_FAIL:-0}" == "1" ]]; then exit 1; fi
if [[ "$calls" == *"namespaces_list"* ]]; then
  cat "$STUB_DIR/ns.json"
else
  if [[ "${STUB_DYNAMIC:-0}" == "1" ]]; then
    n=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$calls")
    echo "$n" >> "$STUB_DIR/calls.log"
    python3 - "$n" "$STUB_DIR/batch.json" <<'EOF'
import json, sys
n, out = int(sys.argv[1]), sys.argv[2]
table = "NAME   STATUS   RESTARTS   AGE   NODE\nweb-abc   Running   0   10d   raspberrypi-00\n"
json.dump([{"ok": True, "result": {"content": [{"text": table}]}} for _ in range(n)],
          open(out, "w"))
EOF
  fi
  cat "$STUB_DIR/batch.json"
fi
STUB
  chmod +x "$STUB_DIR/mcp-stub"
}

ns_json() { # namespaces...
  python3 - "$STUB_DIR/ns.json" "$@" <<'EOF'
import json, sys
out, body = sys.argv[1], sys.argv[2:]
text = "NAME   STATUS   AGE\n" + "".join("%s   Active   100d\n" % n for n in body)
json.dump([{"ok": True, "result": {"content": [{"text": text}]}}], open(out, "w"))
EOF
}

pod_table() { # rows: "name status restarts age node" (ip omitted)
  local row=""
  printf 'NAME   STATUS   RESTARTS   AGE   NODE\n'
  for row in "$@"; do
    # shellcheck disable=SC2086
    set -- $row
    printf '%s   %s   %s   %s   %s\n' "$1" "$2" "$3" "$4" "$5"
  done
}

ok_env() { # text -> envelope file (ok:true, no isError)
  python3 - "$1" "$STUB_DIR/batch.json" <<'EOF'
import json, sys
json.dump([{"ok": True, "result": {"content": [{"text": sys.argv[1]}]}}],
          open(sys.argv[2], "w"))
EOF
}

run_sweep() { # extra args...
  MCP="$STUB_DIR/mcp-stub" STUB_DIR="$STUB_DIR" \
    STUB_DYNAMIC="${STUB_DYNAMIC:-0}" bash "$SWEEP" "$@" 2>&1
}

# --- tests ---------------------------------------------------------------
t_healthy_running_pod() {
  new_stub
  ns_json default
  ok_env "$(pod_table "web-abc Running 0 10d raspberrypi-00")"
  local out rc
  out=$(run_sweep); rc=$?
  assert_eq "running-clean exit" "0" "$rc"
  assert_contains "running-clean OK" "$out" "OK: 1 namespaces swept, no bad pods"
  rm -rf "$STUB_DIR"
}

t_completed_pod() {
  new_stub
  ns_json default
  ok_env "$(pod_table "job-xyz Completed 0 10d raspberrypi-01")"
  local out
  out=$(run_sweep)
  assert_contains "completed-clean OK" "$out" "OK: 1 namespaces swept, no bad pods"
  rm -rf "$STUB_DIR"
}

t_restart_age_parens() {
  new_stub
  ns_json default
  local table
  table=$(printf 'NAME   STATUS   RESTARTS   AGE   NODE\nimg-ei-a4d05f02-gc7b9   Running   28 (35d ago)   103d   raspberrypi-02\n')
  ok_env "$table"
  local out
  out=$(run_sweep)
  assert_contains "paren-restarts BAD" "$out" "RESULT: BAD_PODS_FOUND"
  assert_contains "paren-restarts count" "$out" "restarts=28"
  assert_contains "paren-restarts age" "$out" "age=103d"
  assert_contains "paren-restarts node" "$out" "node=raspberrypi-02"
  rm -rf "$STUB_DIR"
}

t_crashloop() {
  new_stub
  ns_json default
  ok_env "$(pod_table "api-def CrashLoopBackOff 5 2d raspberrypi-03")"
  local out
  out=$(run_sweep)
  assert_contains "crashloop BAD" "$out" "RESULT: BAD_PODS_FOUND"
  assert_contains "crashloop status" "$out" "status=CrashLoopBackOff"
  rm -rf "$STUB_DIR"
}

t_restart_threshold_boundary() {
  new_stub
  ns_json default
  ok_env "$(pod_table "a-1 Running 19 10d raspberrypi-00" "a-2 Running 20 10d raspberrypi-00")"
  local out
  out=$(run_sweep)
  assert_contains "threshold-20 BAD" "$out" "pod=a-2"
  if [[ "$out" == *"pod=a-1"* ]]; then
    not_ok "threshold-19 clean" "19-restart pod flagged: $out"
  else
    ok
  fi
  rm -rf "$STUB_DIR"
}

t_empty_namespace() {
  new_stub
  ns_json default
  ok_env "NAME   STATUS   RESTARTS   AGE   NODE"
  local out
  out=$(run_sweep)
  assert_contains "empty-ns OK" "$out" "OK: 1 namespaces swept, no bad pods"
  rm -rf "$STUB_DIR"
}

t_non_table_text() {
  # ok:true but unflagged non-table text must fail closed, never read as clean.
  new_stub
  ns_json default
  ok_env "error: connection refused"
  local out
  out=$(run_sweep)
  assert_contains "non-table QUERY_FAILED" "$out" "QUERY_FAILED ns=default"
  assert_contains "non-table incomplete" "$out" "RESULT: SWEEP_INCOMPLETE"
  rm -rf "$STUB_DIR"
}

t_ns_header_offset() {
  # A leading junk line in the namespace list must not shift or break parsing.
  new_stub
  python3 - "$STUB_DIR/ns.json" <<'EOF'
import json, sys
text = "junk line\nNAME   STATUS   AGE\ndefault   Active   100d\n"
json.dump([{"ok": True, "result": {"content": [{"text": text}]}}],
          open(sys.argv[1], "w"))
EOF
  ok_env "$(pod_table "web-abc Running 0 10d raspberrypi-00")"
  local out rc
  out=$(run_sweep); rc=$?
  assert_eq "ns-offset exit" "0" "$rc"
  assert_contains "ns-offset OK" "$out" "OK: 1 namespaces swept, no bad pods"
  rm -rf "$STUB_DIR"
}

t_failed_call() {
  new_stub
  ns_json default
  python3 - "$STUB_DIR/batch.json" <<'EOF'
import json, sys
json.dump([{"ok": False, "error": "boom"}], open(sys.argv[1], "w"))
EOF
  local out rc
  out=$(run_sweep); rc=$?
  assert_eq "failed-call exit" "0" "$rc"
  assert_contains "failed-call QUERY_FAILED" "$out" "QUERY_FAILED ns=default"
  assert_contains "failed-call incomplete" "$out" "RESULT: SWEEP_INCOMPLETE"
  rm -rf "$STUB_DIR"
}

t_null_envelope() {
  new_stub
  ns_json default
  echo '[null]' > "$STUB_DIR/batch.json"
  local out
  out=$(run_sweep)
  assert_contains "null-envelope QUERY_FAILED" "$out" "QUERY_FAILED ns=default"
  assert_contains "null-envelope incomplete" "$out" "RESULT: SWEEP_INCOMPLETE"
  rm -rf "$STUB_DIR"
}

t_iserror_envelope() {
  new_stub
  ns_json default
  python3 - "$STUB_DIR/batch.json" <<'EOF'
import json, sys
json.dump([{"ok": True, "result": {"isError": True,
            "content": [{"text": "failed to list pods: boom"}]}}],
          open(sys.argv[1], "w"))
EOF
  local out
  out=$(run_sweep)
  assert_contains "isError QUERY_FAILED" "$out" "QUERY_FAILED ns=default"
  assert_contains "isError incomplete" "$out" "RESULT: SWEEP_INCOMPLETE"
  rm -rf "$STUB_DIR"
}

t_truncated_json() {
  new_stub
  ns_json default
  echo '[{"ok": true, "result": {"content": [{"text": "NAME' > "$STUB_DIR/batch.json"
  local out
  out=$(run_sweep)
  assert_contains "truncated QUERY_FAILED" "$out" "QUERY_FAILED batch-0: invalid JSON"
  assert_contains "truncated incomplete" "$out" "RESULT: SWEEP_INCOMPLETE"
  rm -rf "$STUB_DIR"
}

t_envelope_mismatch() {
  new_stub
  ns_json default kube-system
  ok_env "$(pod_table "web-abc Running 0 10d raspberrypi-00")"
  local out
  out=$(run_sweep)
  assert_contains "mismatch QUERY_FAILED" "$out" "QUERY_FAILED batch-0: envelope mismatch"
  rm -rf "$STUB_DIR"
}

t_ns_list_failure() {
  new_stub
  echo '[{"ok": false, "error": "auth"}]' > "$STUB_DIR/ns.json"
  local out rc
  out=$(run_sweep); rc=$?
  assert_eq "ns-fail exit" "1" "$rc"
  assert_contains "ns-fail QUERY_FAILED" "$out" "QUERY_FAILED: could not list namespaces"
  rm -rf "$STUB_DIR"
}

t_batch_08_chunks() {
  # --batch 08 must chunk as 8, not collapse into a single batch: the old
  # code failed the [[ -ge ]] octal comparison and skipped the batch bound.
  new_stub
  # shellcheck disable=SC2046
  ns_json $(seq -f 'ns%g' 1 20)
  STUB_DYNAMIC=1
  local out rc
  out=$(run_sweep --batch 08 2>&1); rc=$?
  STUB_DYNAMIC=0
  assert_eq "batch-08 exit" "0" "$rc"
  # 20 namespaces at batch 8 -> three call-tools invocations of 8/8/4
  local calls
  calls=$(tr '\n' ' ' < "$STUB_DIR/calls.log")
  assert_eq "batch-08 chunk sizes" "8 8 4 " "$calls"
  assert_contains "batch-08 OK" "$out" "OK: 20 namespaces swept, no bad pods"
  rm -rf "$STUB_DIR"
}

t_bad_args() {
  local out rc
  out=$(MCP=/bin/false bash "$SWEEP" --batch 0 2>&1); rc=$?
  assert_eq "batch-0 exit" "2" "$rc"
  out=$(MCP=/bin/false bash "$SWEEP" --batch 16 2>&1); rc=$?
  assert_eq "batch-16 exit" "2" "$rc"
  out=$(MCP=/bin/false bash "$SWEEP" --batch abc 2>&1); rc=$?
  assert_eq "batch-abc exit" "2" "$rc"
  out=$(MCP=/bin/false bash "$SWEEP" --batch 08 2>&1); rc=$?
  # 08 is accepted as decimal 8 (arg validation passes); the sweep itself
  # then fails closed with exit 1 because the stubbed MCP cannot run.
  assert_eq "batch-08 accepted" "1" "$rc"
  out=$(MCP=/bin/false bash "$SWEEP" --restarts x 2>&1); rc=$?
  assert_eq "restarts-x exit" "2" "$rc"
}

t_bad_args
t_healthy_running_pod
t_completed_pod
t_restart_age_parens
t_crashloop
t_restart_threshold_boundary
t_empty_namespace
t_non_table_text
t_ns_header_offset
t_failed_call
t_null_envelope
t_iserror_envelope
t_truncated_json
t_envelope_mismatch
t_ns_list_failure
t_batch_08_chunks

echo "---"
echo "pass=$pass fail=$fail"
if [[ "$fail" -gt 0 ]]; then
  printf 'failed: %s\n' "${FAILED_TESTS[@]}"
  exit 1
fi
echo "pods-sweep regression tests passed"
