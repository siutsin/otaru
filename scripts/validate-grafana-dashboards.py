#!/usr/bin/env python3
"""Validate in-repo Grafana dashboard YAML embeds.

Structural checks for shipped dashboard manifests under
helm-charts/monitoring/dashboards/. Catches empty PromQL targets and known
obsolete selectors that previously produced No-data panels in this cluster.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DASH_DIR = ROOT / "helm-charts" / "monitoring" / "dashboards"

FORBIDDEN = [
    (re.compile(r'job\s*=\s*"node-exporter"'), 'job="node-exporter" (use kubernetes-service-endpoints scrape job)'),
    (re.compile(r"container_name\s*="), "container_name label (use container)"),
    (re.compile(r"rkt_container_name"), "obsolete rkt_container_name selector"),
    (re.compile(r"cattle-\.\*openshift"), "broken cattle/openshift namespace regex (missing |)"),
    (re.compile(r"prometheus_local_storage_"), "obsolete prometheus_local_storage_* metrics"),
    (re.compile(r"prometheus_evaluator_duration_milliseconds"), "obsolete evaluator duration metric name"),
]


def iter_dashboard_docs(path: Path):
    import yaml

    doc = yaml.safe_load(path.read_text())

    def walk(obj, trail=""):
        if isinstance(obj, dict):
            if isinstance(obj.get("json"), str) and '"panels"' in obj["json"]:
                yield trail or path.name, json.loads(obj["json"])
            if obj.get("gnetId") is not None:
                yield trail or path.name, {"_gnetId": obj.get("gnetId"), "revision": obj.get("revision")}
            for k, v in obj.items():
                yield from walk(v, f"{trail}.{k}" if trail else k)
        elif isinstance(obj, list):
            for i, v in enumerate(obj):
                yield from walk(v, f"{trail}[{i}]")

    yield from walk(doc)


def walk_exprs(panels):
    for p in panels or []:
        title = p.get("title") or p.get("type") or "panel"
        for t in p.get("targets") or []:
            expr = t.get("expr")
            if expr:
                yield title, expr
        if p.get("panels"):
            yield from walk_exprs(p["panels"])


def walk_all_exprs(dash: dict):
    yield from walk_exprs(dash.get("panels"))
    for row in dash.get("rows") or []:
        yield from walk_exprs(row.get("panels"))


def main() -> int:
    if not DASH_DIR.is_dir():
        print(f"ERROR: missing {DASH_DIR}", file=sys.stderr)
        return 2

    errors: list[str] = []
    checked = 0

    for path in sorted(DASH_DIR.glob("*.yaml")):
        for name, dash in iter_dashboard_docs(path):
            if dash.get("_gnetId") is not None:
                if not dash.get("_gnetId"):
                    errors.append(f"{path.name}: empty gnetId")
                print(f"OK  {path.name}: gnetId={dash.get('_gnetId')} revision={dash.get('revision')}")
                continue

            exprs = list(walk_all_exprs(dash))
            if not exprs:
                errors.append(f"{path.name}: embedded dashboard has no PromQL targets")
                continue

            for title, expr in exprs:
                checked += 1
                if not expr.strip():
                    errors.append(f"{path.name}: empty expr in panel {title!r}")
                for cre, msg in FORBIDDEN:
                    if cre.search(expr):
                        errors.append(f"{path.name}: panel {title!r}: forbidden pattern: {msg}")

            if not dash.get("uid"):
                errors.append(f"{path.name}: missing dashboard uid")
            if not dash.get("title"):
                errors.append(f"{path.name}: missing dashboard title")

            print(f"OK  {path.name}: title={dash.get('title')!r} exprs={len(exprs)} version={dash.get('version')}")

    if errors:
        print("\nFAILED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(f"\nAll Grafana dashboards valid ({checked} PromQL targets checked).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
