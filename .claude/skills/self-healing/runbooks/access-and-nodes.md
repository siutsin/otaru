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
reboot. If `unifi-network` MCP tools are available, check switch-port link
state and error counters first (`references/cluster.md` Network layer
section) — read-only, and can distinguish a dead host from a dead link
before escalating hardware. See hardware gotchas below.

**LUKS / initramfs.** Several nodes use LUKS-encrypted root
(`luks_root_nodes` in `ansible/inventory.yaml`). After a reboot they sit in
initramfs until unlock and will not rejoin without intervention.

- **Forbidden unattended:** `reboot`, `shutdown`, `systemctl reboot`,
  `kubectl debug` reboot paths, or Ansible's generic `reboot` module. See
  `AGENTS.md` Node Reboot Policy.
- **Auto-unlock when the signature is confirmed.** Run `make unlock
  <node-name>` directly — no escalation needed — when **all** of these
  hold:
  - the node is a Raspberry Pi (`raspberrypi-*`), not `nuc-00` (see the
    NIC-hang bullet below — always escalate that one instead)
  - the node is listed in `luks_root_nodes` (`ansible/inventory.yaml`)
  - the node IP responds to ping (network layer is up)
  - regular SSH (port 22) is refused or times out
  - the LUKS dropbear-initramfs port (`luks_dropbear_port` in the
    inventory; `1024` in this cluster) answers with an SSH banner
    (`documentation/luks_remote_unlock.md`)

  This combination uniquely matches "node powered back on and is waiting
  in initramfs for the passphrase" (for example after a PoE budget
  power-loss event, see `documentation/gotcha.md`) — not an unresolved
  hardware fault, not still fully down.

  `make unlock` reads the passphrase from `OTARU_LUKS_PASSWORD` via
  `direnv` internally (`--env-passfifo`). **Never read, print, echo, or
  otherwise inspect that variable yourself** — call the `make` target and
  let it flow straight through.

  After it returns, poll `kubectl get node <name>` for `Ready` (a few
  minutes is normal) before continuing the pass. If the command fails, or
  the node does not reach `Ready` within a reasonable wait, stop retrying
  and escalate with what was tried.

  **Still escalate:** planned/rolling reboots (`make maintenance` —
  full-cluster package update and reboot, a much larger action than
  recovering one already-down node); `nuc-00` and the other known
  hardware-fault patterns below, even if the same dropbear signature is
  present, since those need human awareness of a recurring fault, not
  just a one-off unlock; and any case where the signature above does not
  fully match (for example SSH also unreachable, or dropbear itself
  unreachable).

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

If instead a pod hits `exec format error` the same way on **every** node
of one architecture (not just one specific node), the pinned digest
itself may be the arm64-only (or amd64-only) child manifest rather than
the multi-arch index — a different root cause with a different fix. See
`documentation/gotcha.md` ("A Pinned Digest Can Silently Be Single-Arch,
Not Multi-Arch"). Worth checking whenever a pod is scheduled onto an
architecture it has never run on before (a manual reschedule, a new
descheduler policy) and immediately fails at container start.

## Pressure

- Any pressure condition **True** → journal and treat as P0
  storage/capacity risk; GitOps-fix or escalate.

## Healthy

- All Ready, no pressure → continue to the next runbook.
