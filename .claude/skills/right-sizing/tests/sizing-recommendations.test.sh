#!/usr/bin/env bash
# sizing-recommendations.test.sh — regression tests for
# bin/sizing-recommendations.py.
#
# Runs the real script against a stubbed Prometheus that routes on the query
# string: quantile_over_time queries get the p50 canned values, max_over_time
# queries get the max canned values. The two value sets are distinct, so the
# assertions prove the script joins p50 and max correctly — a script that
# mixed the two up would fail. Asserts the rule math on the JSON output:
# request = ceil(p50 / 0.9) with a 32Mi floor, limit = ceil(max * 1.2).
#
# Run: bash sizing-recommendations.test.sh   (or `make test-sizing` from repo root)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../bin/sizing-recommendations.py"
PORT=18731

pass=0
fail=0

ok() { pass=$((pass + 1)); }
not_ok() { fail=$((fail + 1)); echo "FAIL: $1 -- $2"; }

assert_contains() { # name haystack needle
  if [[ "$2" == *"$3"* ]]; then ok; else not_ok "$1" "missing [$3] in: $2"; fi
}

STUB_DIR="$(mktemp -d)"
trap 'kill "$SERVER_PID" 2>/dev/null; rm -rf "$STUB_DIR"' EXIT

# --- stub Prometheus -------------------------------------------------------
# Routes on the query: the p50 query gets p50 values, the max query gets max
# values. app: p50 30 -> request ceil(30/0.9)=34; max 100 -> limit
# ceil(100*1.2)=120. sidecar: p50 1 -> floor 32; max 2 -> limit ceil(2.4)=3.
# Series carry only namespace/container labels, like the real grouped query.
cat > "$STUB_DIR/stub.py" <<'PYEOF'
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

MIB = 1024 * 1024
LOG = os.environ["STUB_QUERY_LOG"]
# namespace, container, p50_mib, max_mib
SERIES = [
    ("demo", "app", 30, 100),
    ("demo", "sidecar", 1, 2),
]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        query = parse_qs(urlparse(self.path).query).get("query", [""])[0]
        with open(LOG, "a") as f:
            f.write(query + "\n")
        use_p50 = "quantile_over_time" in query
        result = []
        for ns, container, p50, maxv in SERIES:
            result.append({
                "metric": {"namespace": ns, "container": container},
                "value": [1790433600, str((p50 if use_p50 else maxv) * MIB)],
            })
        body = json.dumps({"status": "success", "data": {
            "resultType": "vector", "result": result}}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", int(os.environ["STUB_PORT"])), Handler).serve_forever()
PYEOF

export STUB_PORT="$PORT" STUB_QUERY_LOG="$STUB_DIR/queries.log"
touch "$STUB_DIR/queries.log"
python3 "$STUB_DIR/stub.py" &
SERVER_PID=$!
sleep 1

# --- tests -----------------------------------------------------------------
OUT="$(python3 "$SCRIPT" --prometheus-url "http://127.0.0.1:$PORT" 2>&1)"
CODE=$?
if [[ "$CODE" == "0" ]]; then ok; else not_ok "exit code" "got $CODE: $OUT"; fi

# p50 and max joined correctly: distinct canned values per query path, so a
# swap would fail these.
assert_contains "p50 passthrough" "$OUT" '"p50_mib": 30.0'
assert_contains "max passthrough" "$OUT" '"max_mib": 100.0'
assert_contains "request from p50" "$OUT" '"recommended_request_mib": 34'
assert_contains "limit from max" "$OUT" '"recommended_limit_mib": 120'
assert_contains "32Mi floor" "$OUT" '"recommended_request_mib": 32'
assert_contains "small limit math" "$OUT" '"recommended_limit_mib": 3'
assert_contains "namespace passthrough" "$OUT" '"namespace": "demo"'

LOG="$(cat "$STUB_DIR/queries.log")"
assert_contains "p50 query issued" "$LOG" "quantile_over_time"
assert_contains "max query issued" "$LOG" "max_over_time"

SELF_OUT="$(python3 "$SCRIPT" --self-test 2>&1)"
if [[ "$SELF_OUT" == *"self-test ok"* ]]; then ok; else not_ok "self-test" "$SELF_OUT"; fi

echo "pass=$pass fail=$fail"
[[ "$fail" == "0" ]]
