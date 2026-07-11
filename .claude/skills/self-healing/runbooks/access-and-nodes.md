# Access and Nodes

Prerequisites: otaru repo checkout, kubeconfig reaching API VIP
`192.168.10.50` (port optional; see runtime gate in `SKILL.md`).

## Checks

- `kubectl cluster-info` — API server host is `192.168.10.50`?
- `kubectl get nodes -o wide` — all five expected names present and Ready?
- Node pressure: `DiskPressure`, `MemoryPressure`, and `PIDPressure` must be
  **False** on every node. Prefer custom-columns / jsonpath on
  `.status.conditions` (or MCP); use `kubectl describe node` only when
  drilling into a True condition.

## NotReady triage (P0)

Journal **any** NotReady node as P0 before lower-priority categories.

**Reachability.** Ping the node IP from `references/cluster.md`. If the host
is dark (no ping, no SSH) but power may still be on, do not assume a clean
reboot — see hardware gotchas below.

**LUKS / initramfs.** Several nodes use LUKS-encrypted root
(`luks_root_nodes` in `ansible/inventory.yaml`). After a reboot they sit in
initramfs until unlock and will not rejoin without intervention.

- **Forbidden unattended:** `reboot`, `shutdown`, `systemctl reboot`,
  `kubectl debug` reboot paths, or Ansible's generic `reboot` module. See
  `AGENTS.md` Node Reboot Policy.
- **Escalate unlock / planned reboot** to the user. Documented paths:
  `make unlock <node-name>` when initramfs dropbear is already waiting;
  `make maintenance` for rolling LUKS-aware reboots. Details:
  `documentation/luks_remote_unlock.md`, `documentation/gotcha.md`.

**Hardware replace + stale node password.** If a node was replaced in place
and reuses the same name, look for `kube-system/<node>.node-password.k3s`
(see `documentation/gotcha.md`). **Escalate** — do not delete the secret
unattended (wrong-host risk).

**Known host NIC hang (`nuc-00`).** Onboard Intel 82579V (`eno1`, `e1000e`)
can hit `Detected Hardware Unit Hang`: host stays up, network dies, kubelet
goes NotReady. Recovery is a power cycle then `make unlock nuc-00` (LUKS).
Escalate; do not plain-reboot. See `documentation/gotcha.md` (e1000e
section).

**RPi5 Wi-Fi association loop.** `status_code=16` / endless
`CTRL-EVENT-ASSOC-REJECT` is a firmware/AP-rate-limit issue; rebooting the
node alone often fails. Escalate; see `documentation/gotcha.md`.

**Otherwise** journal symptoms (conditions, events, last heartbeat) and
escalate with a recommended next step.

## After a Node Rejoins: Check for Corrupted Image Pulls

A node that came back from an unclean shutdown or outage can have an
incomplete multi-arch image pull sitting in containerd's content store —
the top-level manifest-list metadata looks intact, but a child platform
manifest is silently missing, so every subsequent pod on that node using
that image resolves to the wrong architecture and fails with
`exec /path/to/binary: exec format error`, isolated to that one image on
that one node. `kubectl delete pod` alone does not fix it (the replacement
lands on the same node with the same broken cache). See
`documentation/gotcha.md` ("Missing Child Manifest After Interrupted Pull
Causes `exec format error`") for the diagnosis and fix (`k3s ctr -n k8s.io
content rm` on the actual content blob, not just `images rm`). Worth a
quick check for any pod that starts crash-looping specifically on a node
that just rejoined.

## Pressure

- Any pressure condition **True** → journal and treat as P0
  storage/capacity risk; GitOps-fix or escalate.

## Healthy

- All Ready, no pressure → continue to the next runbook.
