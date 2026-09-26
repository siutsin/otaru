#!/usr/bin/env bash
# monitoring-checks.test.sh — regression tests for bin/monitoring-checks.py.
#
# Runs the real script against a stubbed Prometheus (python http.server,
# no cluster, no tunnel). Each test serves canned /api/v1/query responses
# and asserts on the script's JSON stdout and exit code.
#
# Run: bash monitoring-checks.test.sh   (or `make test-monitoring` from repo root)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../bin/monitoring-checks.py"

pass=0
fail=0
FAILED_TESTS=()

ok() { pass=$((pass + 1)); }
not_ok() { fail=$((fail + 1)); FAILED_TESTS+=("$1"); echo "FAIL: $1 -- $2"; }

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"; kill $SERVER_PID 2>/dev/null' EXIT
SERVER_PID=""

# Stub Prometheus: serves canned responses keyed by exact query string.
# $1 = path to a JSON file: {query: {status: int, body: object}}
start_stub() {
  cat > "$tmpdir/stub.py" <<'EOF'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
routes = json.load(open(sys.argv[1]))
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        q = parse_qs(urlparse(self.path).query).get("query", [""])[0]
        r = routes.get(q)
        if r is None:
            self.send_response(404); self.end_headers(); return
        body = json.dumps(r["body"]).encode()
        self.send_response(r["status"])
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
srv = HTTPServer(("127.0.0.1", 0), H)
print(srv.server_address[1], flush=True)
srv.serve_forever()
EOF
  # Drop the previous test's port: the wait loop below must see a fresh
  # file, otherwise it reads a stale port from the killed server.
  : > "$tmpdir/port"
  python3 "$tmpdir/stub.py" "$1" > "$tmpdir/port" 2>/dev/null &
  SERVER_PID=$!
  for _ in $(seq 1 50); do
    [[ -s "$tmpdir/port" ]] && break
    sleep 0.1
  done
  PORT=$(cat "$tmpdir/port")
}

stop_stub() { kill $SERVER_PID 2>/dev/null; SERVER_PID=""; }

# Canned routes for one test. $1 = mode: probe_down | healthy | firing |
# partial_pvc. Written by python from plain literals — no shell quoting
# of the PromQL (queries contain quotes, braces, and angle brackets).
write_routes() {
  ROUTES_MODE="$1" python3 - "$tmpdir/routes.json" <<'EOF'
import json, os, sys
VEC_OK = {"status": "success",
          "data": {"resultType": "vector", "result": []}}
VEC_ZERO = {"status": "success",
            "data": {"resultType": "vector", "result": [
                {"metric": {}, "value": [1727220000, "0"]}]}}
VEC_FIRING = {"status": "success",
              "data": {"resultType": "vector", "result": [
                  {"metric": {"alertname": "Watchdog"},
                    "value": [1727220000, "1"]}]}}
ERR500 = {"status": 500,
          "body": {"status": "error", "errorType": "bad_data"}}
routes = {
    "count(up)": {"status": 200, "body": VEC_ZERO},
    "count(up == 0)": {"status": 200, "body": VEC_ZERO},
    'ALERTS{alertstate="firing"}': {"status": 200, "body": VEC_OK},
    "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1":
        {"status": 200, "body": VEC_OK},
    "kubelet_volume_stats_used_bytes / "
    "kubelet_volume_stats_capacity_bytes > 0.85":
        {"status": 200, "body": VEC_OK},
    "(certmanager_certificate_expiration_timestamp_seconds - time()) < 604800":
        {"status": 200, "body": VEC_OK},
}
mode = os.environ["ROUTES_MODE"]
if mode == "probe_down":
    routes["count(up)"] = ERR500
elif mode == "firing":
    routes['ALERTS{alertstate="firing"}'] = {"status": 200, "body": VEC_FIRING}
elif mode == "partial_pvc":
    routes["kubelet_volume_stats_used_bytes / "
            "kubelet_volume_stats_capacity_bytes > 0.85"] = ERR500
elif mode != "healthy":
    raise SystemExit("unknown mode: " + mode)
json.dump(routes, open(sys.argv[1], "w"))
EOF
}

run_script() {
  python3 "$SCRIPT" --prometheus-url "http://127.0.0.1:$PORT" 2>/dev/null
}

# Test 1 needs stderr, so it calls the script directly instead of run_script.

# --- test 0: --self-test covers the pure-logic rules (is_finding zero-value) ---
SELF_OUT="$(python3 "$SCRIPT" --self-test 2>&1)"
if [[ "$SELF_OUT" == *"self-test ok"* ]]; then
  ok "--self-test passes"
else
  not_ok "--self-test passes" "$SELF_OUT"
fi

# --- test 1: probe fails -> exit 1 fast, TRANSPORT_DOWN ---
write_routes probe_down
start_stub "$tmpdir/routes.json"
out=$(python3 "$SCRIPT" --prometheus-url "http://127.0.0.1:$PORT" 2>"$tmpdir/err")
code=$?
if [[ $code -eq 1 ]] && grep -q "TRANSPORT_DOWN" "$tmpdir/err"; then
  ok "probe failure exits 1 with TRANSPORT_DOWN"
else
  not_ok "probe failure exits 1 with TRANSPORT_DOWN" "code=$code"
fi
stop_stub

# --- test 2: all healthy -> exit 0, every check ok ---
write_routes healthy
start_stub "$tmpdir/routes.json"
out=$(run_script)
code=$?
bad=$(echo "$out" | python3 -c "
import json, sys
checks = json.load(sys.stdin)['checks']
bad = [c['name'] for c in checks if c['status'] != 'ok' or len(checks) != 5]
print(','.join(bad))")
if [[ $code -eq 0 && -z "$bad" ]]; then
  ok "healthy cluster reports all checks ok"
else
  not_ok "healthy cluster reports all checks ok" "code=$code bad=$bad"
fi
stop_stub

# --- test 3: firing alert -> finding with series labels ---
write_routes firing
start_stub "$tmpdir/routes.json"
out=$(run_script)
code=$?
finding=$(echo "$out" | python3 -c "
import json, sys
checks = {c['name']: c for c in json.load(sys.stdin)['checks']}
c = checks['firing_alerts']
print('yes' if c['status'] == 'finding' and c['count'] == 1
      and c['series'][0].get('alertname') == 'Watchdog' else 'no')")
if [[ $code -eq 0 && "$finding" == "yes" ]]; then
  ok "firing alert reported as finding with labels"
else
  not_ok "firing alert reported as finding with labels" "code=$code finding=$finding"
fi
stop_stub

# --- test 4: one check always errors -> that check partial, rest ok ---
write_routes partial_pvc
start_stub "$tmpdir/routes.json"
out=$(run_script)
code=$?
partial=$(echo "$out" | python3 -c "
import json, sys
checks = {c['name']: c for c in json.load(sys.stdin)['checks']}
print('yes' if checks['pvc_nearly_full']['status'] == 'partial'
      and all(c['status'] == 'ok' for n, c in checks.items()
              if n != 'pvc_nearly_full') else 'no')")
if [[ $code -eq 0 && "$partial" == "yes" ]]; then
  ok "erroring check reported partial, others ok"
else
  not_ok "erroring check reported partial, others ok" "code=$code partial=$partial"
fi
stop_stub

echo "---"
echo "pass=$pass fail=$fail"
if [[ $fail -gt 0 ]]; then
  printf 'failed: %s\n' "${FAILED_TESTS[@]}"
  exit 1
fi
