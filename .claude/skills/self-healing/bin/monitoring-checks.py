#!/usr/bin/env python3
"""monitoring-checks.py — the five monitoring PromQL checks, in parallel.

One cheap probe query runs first: if the tunnel proxy flaps, the script
exits 1 fast instead of burning attempts on every check. Then the five
checks run concurrently, each with up to 3 attempts 15s apart (25s per
attempt). Prints one JSON object on stdout.

A non-empty result on any attempt is a real finding, never noise. A
series with value 0 (for example count(up == 0) with no down targets)
is ok.

Usage:
    monitoring-checks.py [--prometheus-url URL] [--self-test]
"""
import argparse
import concurrent.futures
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

CHECKS = [
    ("targets_down", "count(up == 0)"),
    ("firing_alerts", 'ALERTS{alertstate="firing"}'),
    (
        "node_memory_pressure",
        "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1",
    ),
    (
        "pvc_nearly_full",
        "kubelet_volume_stats_used_bytes / "
        "kubelet_volume_stats_capacity_bytes > 0.85",
    ),
    (
        "cert_expiring_7d",
        "(certmanager_certificate_expiration_timestamp_seconds - time())"
        " < 604800",
    ),
]
ATTEMPTS = 3
RETRY_SLEEP_S = 15
QUERY_TIMEOUT_S = 25
PROBE_TIMEOUT_S = 10
SERIES_CAP = 10
TUNNEL_PORT = "3130"


def repo_root():
    for parent in Path(__file__).resolve().parents:
        if (parent / "helm-charts" / "monitoring" / "values.yaml").exists():
            return parent
    raise SystemExit("error: cannot find repo root above " + str(__file__))


def prometheus_url(repo, override=None):
    if override:
        return override.rstrip("/")
    route = (
        repo / "helm-charts" / "monitoring" / "templates" / "route-internal.yaml"
    ).read_text()
    m = re.search(r"\{\{\s*\$k\s*\}\}\.([A-Za-z0-9.-]+)", route)
    if not m:
        raise SystemExit("error: hostname pattern missing in route-internal.yaml")
    return "https://prometheus." + m.group(1)


def tunnel_proxy(url):
    """Tunnel proxy for tailnet-only ingress; direct otherwise."""
    host = urllib.parse.urlparse(url).hostname or ""
    if not host.endswith(".internal.siutsin.com"):
        return None
    https_proxy = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy")
    if not https_proxy:
        return None
    return re.sub(r":\d+$", "", https_proxy) + ":" + TUNNEL_PORT


def fetch(base_url, query, timeout):
    params = urllib.parse.urlencode({"query": query})
    req = urllib.request.Request(base_url + "/api/v1/query?" + params)
    proxy = tunnel_proxy(base_url)
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({"https": proxy} if proxy else {})
    )
    with opener.open(req, timeout=timeout) as resp:
        data = json.load(resp)
    if data.get("status") != "success":
        raise RuntimeError("prometheus: " + str(data.get("errorType")))
    return data["data"]["result"]


def is_finding(result):
    return any(float(s["value"][1]) != 0 for s in result)


def check_one(base_url, name, query):
    for attempt in range(ATTEMPTS):
        try:
            result = fetch(base_url, query, timeout=QUERY_TIMEOUT_S)
        except Exception:  # noqa: BLE001 - transport blip, retry per runbook
            if attempt < ATTEMPTS - 1:
                time.sleep(RETRY_SLEEP_S)
            continue
        finding = is_finding(result)
        return {
            "name": name,
            "status": "finding" if finding else "ok",
            "count": len(result) if finding else 0,
            "series": [s["metric"] for s in result[:SERIES_CAP]] if finding else [],
        }
    return {"name": name, "status": "partial"}


def self_test():
    assert is_finding([]) is False
    # count(up == 0) returns one series with value 0 when nothing is down.
    assert is_finding([{"metric": {}, "value": [1, "0"]}]) is False
    assert (
        is_finding([{"metric": {"alertname": "X"}, "value": [1, "1"]}]) is True
    )
    print("self-test ok")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--prometheus-url", default=None)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    base_url = prometheus_url(repo_root(), args.prometheus_url)
    try:
        fetch(base_url, "count(up)", timeout=PROBE_TIMEOUT_S)
    except Exception as e:  # noqa: BLE001 - reported, not raised
        print("TRANSPORT_DOWN: %s" % e, file=sys.stderr)
        return 1
    with concurrent.futures.ThreadPoolExecutor(
        max_workers=len(CHECKS)
    ) as executor:
        checks = list(
            executor.map(lambda c: check_one(base_url, c[0], c[1]), CHECKS)
        )
    print(json.dumps({"transport": "ok", "checks": checks}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
