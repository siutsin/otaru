#!/usr/bin/env python3
"""Per-container memory sizing recommendations (KRR replacement).

The self-healing loop cannot run KRR: it needs the Kubernetes API and this
runner has no kubeconfig by design. This script queries Prometheus directly
(the same data KRR uses) and applies the repo memory-sizing rule from
AGENTS.md:

    baseline = p50 of container_memory_working_set_bytes over trailing 30d
    request  = ceil(baseline / 0.9), 32Mi floor
    spike    = max over trailing 30d
    limit    = ceil(spike * 1.2)

Statistics are per (namespace, container) — the workload level the loop
resizes — not per pod: pod names churn, and sizing from one hot pod
incarnation would mislead. p50 is the median of hourly per-pod averages;
spike is the highest single-pod hourly max. Hourly rollups are computed
server-side (small responses, kind to the tunnel); workloads younger than
30d use all available data. Only containers running now are listed: groups
with no current pods are dropped, and CronJob pods are too ephemeral to
baseline — size those from OOMKill events instead. Output is JSON, one row
per container:

    {namespace, container, p50_mib, max_mib,
    recommended_request_mib, recommended_limit_mib}

The loop agent joins this with chart values, skips VPA-managed and
guardrailed workloads, and opens the GitOps PR. Memory only: CPU-request
changes stay held until the user authorises them.

Usage:
    sizing-recommendations.py [--prometheus-url URL] [--self-test]
"""

import argparse
import json
import math
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

FLOOR_MIB = 32
WINDOW_DAYS = 30
STEP = "1h"
METRIC = "container_memory_working_set_bytes"
MIB = 1024 * 1024
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


def prom_query(base_url, query, timeout=180):
    params = urllib.parse.urlencode({"query": query})
    req = urllib.request.Request(base_url + "/api/v1/query?" + params)
    proxy = tunnel_proxy(base_url)
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({"https": proxy} if proxy else {})
    )
    try:
        with opener.open(req, timeout=timeout) as resp:
            data = json.load(resp)
    except Exception as e:  # noqa: BLE001 - surfaced to the loop as-is
        raise SystemExit(f"error: prometheus query failed: {e}")
    if data.get("status") != "success":
        raise SystemExit(f"error: prometheus said {data.get('errorType')}")
    return data["data"]["result"]


def recommend(p50_bytes, max_bytes):
    request_mib = max(FLOOR_MIB, math.ceil(p50_bytes / 0.9 / MIB))
    limit_mib = math.ceil(max_bytes * 1.2 / MIB)
    return request_mib, limit_mib


def series_key(metric):
    return (metric.get("namespace", ""), metric.get("container", ""))


def collect(base_url):
    # Workload-level stats per (namespace, container): pod names churn, so
    # per-pod numbers would swing with each restart. p50 is the median of
    # hourly per-pod averages; spike is the highest hourly max any pod hit.
    # `and on (namespace, container)` keeps only groups with running pods:
    # without it the 30d window also returns deleted workloads.
    sel = f'{METRIC}{{container!="",container!="POD"}}'
    live = f"sum by (namespace, container) ({sel})"
    p50_q = (
        f"quantile_over_time(0.5, avg by (namespace, container)"
        f" (avg_over_time({sel}[1h]))[{WINDOW_DAYS}d:{STEP}])"
        f" and on (namespace, container) {live}"
    )
    max_q = (
        f"max by (namespace, container)"
        f" (max_over_time(max_over_time({sel}[1h])[{WINDOW_DAYS}d:{STEP}]))"
        f" and on (namespace, container) {live}"
    )
    p50 = {
        series_key(r["metric"]): float(r["value"][1])
        for r in prom_query(base_url, p50_q)
    }
    peak = {
        series_key(r["metric"]): float(r["value"][1])
        for r in prom_query(base_url, max_q)
    }
    rows = []
    for namespace, container in sorted(set(p50) & set(peak)):
        req_mib, lim_mib = recommend(
            p50[(namespace, container)], peak[(namespace, container)]
        )
        rows.append(
            {
                "namespace": namespace,
                "container": container,
                "p50_mib": round(p50[(namespace, container)] / MIB, 1),
                "max_mib": round(peak[(namespace, container)] / MIB, 1),
                "recommended_request_mib": req_mib,
                "recommended_limit_mib": lim_mib,
            }
        )
    return rows


def self_test():
    # Rule math: ceil(p50 / 0.9), 32Mi floor, ceil(max * 1.2).
    got = recommend(100 * MIB, 200 * MIB)
    assert got == (112, 240), got
    assert recommend(1 * MIB, 10 * MIB) == (32, 12), recommend(1 * MIB, 10 * MIB)
    assert recommend(0, 0) == (32, 0), recommend(0, 0)
    # Hostname derivation from the route template pattern.
    tpl = "    - {{ $k }}.internal.siutsin.com\n"
    m = re.search(r"\{\{\s*\$k\s*\}\}\.([A-Za-z0-9.-]+)", tpl)
    url = "https://prometheus." + m.group(1)
    assert url == "https://prometheus.internal.siutsin.com", url
    # Tunnel proxy only for tailnet ingress, derived from HTTPS_PROXY.
    saved = {
        k: os.environ.pop(k)
        for k in ("HTTPS_PROXY", "https_proxy")
        if k in os.environ
    }
    try:
        os.environ["HTTPS_PROXY"] = "http://user:pass@hatch-egress-proxy:3128"
        assert tunnel_proxy("https://prometheus.internal.siutsin.com") == (
            "http://user:pass@hatch-egress-proxy:3130"
        )
        assert tunnel_proxy("http://127.0.0.1:8080") is None
        del os.environ["HTTPS_PROXY"]
        assert tunnel_proxy("https://prometheus.internal.siutsin.com") is None
    finally:
        os.environ.update(saved)
    print("self-test ok")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--prometheus-url", default=None)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    base_url = prometheus_url(repo_root(), args.prometheus_url)
    print(json.dumps(collect(base_url), indent=1))


if __name__ == "__main__":
    main()
