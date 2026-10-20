#!/usr/bin/env python3
"""Assert the zot generated files agree with the census record.

Checks, in order:
1. Generator fixtures (tag escaping, canonical names).
2. Staleness: the generated files equal a fresh generator run.
Skipped on bot pull requests (renovate/**, automated/**, and
[bot] actors): bot pin bumps cannot run the generator, and the
post-merge regeneration workflow closes the gap.
3. Census agreement: the chart mapping equals the census chart list,
and every retention keep list holds exactly the census current
tags plus the state file's previous tags.
4. CIDR oracle: cidrs.json holds one /32 per Ansible inventory node,
each the base of a distinct /24 inside the pod CIDR range, and
the rendered SecurityPolicy carries exactly those CIDRs.
"""

import ipaddress
import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
ZOT = ROOT / "helm-charts" / "zot"
FAILURES = []


def check(ok, message):
    if ok:
        print(f"ok: {message}")
    else:
        FAILURES.append(message)
        print(f"FAIL: {message}")


def bot_pr():
    ref = os.environ.get("GITHUB_HEAD_REF", "")
    actor = os.environ.get("GITHUB_ACTOR", "")
    return ref.startswith(("renovate/", "automated/")) or actor.endswith("[bot]")


def main():
    gen = ["python3", str(ZOT / "generate.py")]

    out = subprocess.run(gen + ["--selftest"], capture_output=True, text=True)
    check(
        out.returncode == 0,
        f"generator fixtures ({out.stdout.strip()} {out.stderr.strip()})",
    )

    if bot_pr():
        print("skip: staleness check on a bot pull request")
    else:
        out = subprocess.run(gen + ["--check"], capture_output=True, text=True)
        check(
            out.returncode == 0,
            f"generated files current ({out.stdout.strip()} {out.stderr.strip()})",
        )

    census = json.loads((ZOT / "census.json").read_text())
    state = json.loads((ZOT / "pin-state.json").read_text())
    generated = yaml.safe_load((ZOT / "generated.yaml").read_text())
    mapping = yaml.safe_load(
        (ROOT / "helm-charts/argocd/zot-chart-mapping.yaml").read_text()
    )

    # Chart mapping equals the census chart list.
    census_charts = {
        c["name"]: (c["zot_path"], c["locked_version"], c["tag_form"], c["form"])
        for c in census["charts"]["entries"]
    }
    mapping_charts = {
        c["name"]: (c["zotPath"], c["lockedVersion"], c["tagForm"], c["form"])
        for c in mapping["zotChartMapping"]["charts"]
    }
    check(
        mapping_charts == census_charts,
        f"chart mapping equals census ({len(mapping_charts)} charts)",
    )
    check(
        generated["chartRepositories"]
        == sorted(census_charts[n][0] for n in census_charts),
        "generated chart repository list equals census",
    )

    # Retention keep lists: census current tags plus state previous tags.
    census_tags = {}
    for e in census["images"]["entries"]:
        census_tags[e["image"]] = sorted(
            {p["tag"] for p in e["pin_strings"] if p["tag"]}
        )
    policies = generated["config"]["storage"]["retention"]["policies"]
    by_repo = {}
    for pol in policies:
        keep = set()
        for rule in pol.get("keepTags", []):
            pats = rule.get("patterns", [])
            if pats == [".*"]:
                continue
            keep.update(p.strip("^$").replace("\\", "") for p in pats)
        by_repo[pol["repositories"][0]] = (keep, pol.get("deleteUntagged"))

    ok = True
    for image, tags in census_tags.items():
        want = set(tags) | set(state["images"].get(image, []))
        got = by_repo.get(image, (set(), None))
        if got[0] != want or got[1] is not False:
            ok = False
            print(
                f"  image policy mismatch {image}: keep={sorted(got[0])} "
                f"want={sorted(want)} deleteUntagged={got[1]}"
            )
    check(
        ok,
        f"image retention policies cover census plus previous pins "
        f"({len(census_tags)} repositories)",
    )

    ok = True
    for name, (zot_path, _ver, tag_form, _form) in census_charts.items():
        repo = zot_path.lstrip("/")
        want = {tag_form} | (
            {state["charts"][name]} if state["charts"].get(name) else set()
        )
        got = by_repo.get(repo, (set(), None))
        if got[0] != want or got[1] is not True:
            ok = False
            print(
                f"  chart policy mismatch {repo}: keep={sorted(got[0])} "
                f"want={sorted(want)} deleteUntagged={got[1]}"
            )
    check(
        ok,
        f"chart retention policies cover census plus previous versions "
        f"({len(census_charts)} repositories)",
    )
    check(
        policies[-1]["repositories"] == ["**"]
        and policies[-1].get("deleteUntagged") is True,
        "trailing on-demand retention policy present",
    )

    # Sync registries: one entry per canonical host. The dhi.io mode
    # follows the pin-state dhi_poll flag; every other host is
    # on-demand with a manifest check interval.
    registries = generated["config"]["extensions"]["sync"]["registries"]
    want_urls = {
        "https://registry-1.docker.io",
        "https://dhi.io",
        "https://ghcr.io",
        "https://quay.io",
        "https://registry.k8s.io",
        "https://public.ecr.aws",
        "https://ecr-public.aws.com",
        "https://mirror.gcr.io",
        "https://registry.istio.io",
        "https://cr.fluentbit.io",
        "https://falco.docker.scarf.sh",
        "https://us-docker.pkg.dev",
    }
    got_urls = {r["urls"][0] for r in registries}
    check(
        got_urls == want_urls,
        f"sync registries cover the canonical hosts ({len(got_urls)})",
    )
    dhi_entries = [r for r in registries if r["urls"][0] == "https://dhi.io"]
    dhi_on_demand = [r for r in dhi_entries if r.get("onDemand") is True]
    dhi_poll = [r for r in dhi_entries if "pollInterval" in r]
    if state["dhi_poll"]:
        ok = len(dhi_poll) == 1
    else:
        ok = len(dhi_poll) == 0
    ok = (
        ok
        and len(dhi_on_demand) == 1
        and dhi_on_demand[0].get("manifestCheckInterval") == "24h"
    )
    check(ok, "dhi.io sync entries match the pin-state dhi_poll flag")
    ok = all(
        r.get("onDemand") is True and r.get("manifestCheckInterval") == "1h"
        for r in registries
        if r["urls"][0] != "https://dhi.io"
    )
    check(ok, "all other registries are on-demand with a manifest check interval")

    # CIDR oracle.
    inventory = yaml.safe_load((ROOT / "ansible/inventory.yaml").read_text())
    nodes = set()
    for group, body in inventory["all"]["children"].items():
        if group.startswith("node") and isinstance(body, dict):
            nodes.update((body.get("hosts") or {}).keys())
    doc = json.loads((ZOT / "cidrs.json").read_text())
    entries = doc["nodes"]
    check(
        len(entries) == len(nodes),
        f"cidrs.json holds one entry per inventory node "
        f"({len(entries)} vs {len(nodes)})",
    )
    nets = set()
    ok = True
    for e in entries:
        cidr = ipaddress.ip_network(e["cidr"])
        pod = ipaddress.ip_network(e["podCIDR"])
        if (
            cidr.prefixlen != 32
            or pod.prefixlen != 24
            or cidr.network_address != pod.network_address
            or not pod.subnet_of(ipaddress.ip_network("10.42.0.0/16"))
            or pod in nets
        ):
            ok = False
            print(f"  cidr entry mismatch: {e}")
        nets.add(pod)
    check(ok, "every CIDR is the base of a distinct /24 inside the pod CIDR range")

    if not (ZOT / "charts").exists():
        subprocess.run(
            ["helm", "dependency", "build", str(ZOT), "--skip-refresh"],
            capture_output=True,
            text=True,
        )
    out = subprocess.run(
        [
            "helm",
            "template",
            "zot",
            str(ZOT),
            "-n",
            "zot",
            "-f",
            str(ZOT / "values.yaml"),
            "-f",
            str(ZOT / "generated.yaml"),
        ],
        capture_output=True,
        text=True,
    )
    check(out.returncode == 0, f"zot chart renders ({out.stderr.strip()[:200]})")
    rendered = {}
    if out.returncode == 0:
        for obj in yaml.safe_load_all(out.stdout):
            if obj and obj.get("kind") == "SecurityPolicy":
                rules = obj["spec"]["authorization"]["rules"]
                rendered = {r["name"]: r["principal"]["clientCIDRs"] for r in rules}
    want_cidrs = sorted(e["cidr"] for e in entries)
    got_cidrs = sorted(rendered.get("allow-node-sources", []))
    check(
        got_cidrs == want_cidrs,
        "rendered SecurityPolicy carries exactly the cidrs.json list",
    )

    if FAILURES:
        print(f"\n{len(FAILURES)} zot census check(s) failed")
        return 1
    print("\nAll zot census checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
