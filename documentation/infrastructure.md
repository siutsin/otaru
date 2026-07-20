# Infrastructure Operations

The external AWS, Backblaze B2, Cloudflare, and UniFi resources under
`infrastructure/` are managed with OpenTofu 1.12.4 and Terragrunt 1.1.1. This
runbook defines the routine plan cadence and the approval boundary for applies.

## Ownership and boundaries

- A human operator runs remote plans and applies from a trusted workstation
  with the environment described in [Secrets](secrets.md).
- GitHub Actions validates and formats the configuration but does not contact
  remote infrastructure. A hosted runner would need credentials for several
  providers and cannot reach the private UniFi endpoint.
- Routine plans exclude `infrastructure/local/`. UniFi plans and applies stay
  on a trusted workstation because the controller endpoint is private and plan
  output can include local network details.
- Treat the UniFi controller as discovery ground truth. Import existing
  resources before adding their non-sensitive desired configuration to HCL;
  do not create duplicates to resolve drift.
- Never use `terragrunt run --all` for apply. Apply one reviewed unit at a time.

## Cadence

| Trigger                      | Action                                                                             |
|------------------------------|------------------------------------------------------------------------------------|
| Monthly                      | Run the non-UniFi plan across all 11 cloud units.                                  |
| Infrastructure pull request  | Plan every affected unit before merge.                                             |
| Provider or module upgrade   | Plan affected units before merge and again after any approved apply.               |
| Suspected out-of-band change | Plan the affected unit and record whether Git or the live service is ground truth. |
| UniFi maintenance            | Plan each affected local unit and require a clean plan after an approved apply.    |

## Routine non-UniFi plan

Start from an up-to-date `master` checkout with the external environment loaded:

```shell
direnv allow
git pull --ff-only origin master
make test
make plan-infrastructure
```

The Make target uses Terragrunt's negative filter `!./local/**`, which selects
the 11 AWS, B2, and Cloudflare units while excluding both UniFi units. OpenTofu
returns exit code `0` when every plan is clean, `2` when drift is present, and
`1` when planning fails. A drift exit is a review signal, not permission to
apply.

Confirm the selected units without contacting provider APIs:

```shell
cd infrastructure
terragrunt find --filter '!./local/**'
```

## Apply gate

An apply requires explicit approval and a saved plan for one unit. Review the
plan for unexpected creates, replacements, or destroys before using it:

```shell
cd infrastructure/cloud/<provider>/<unit>
PLAN_FILE="$(pwd)/change.tfplan"
terragrunt plan -out="$PLAN_FILE"
tofu show -no-color "$PLAN_FILE"
terragrunt apply "$PLAN_FILE"
terragrunt plan -detailed-exitcode -no-color
rm "$PLAN_FILE"
```

Saved `*.tfplan` files may contain sensitive values and are ignored by Git.
Keep provider credentials in the environment; never add them to HCL, generated
files, logs, or plan artifacts.

## Current UniFi access policy

The custom zone policies deliberately add a small set of exceptions and
restrictions on top of UniFi's predefined system policies:

| VLAN | Network      | Expected custom-policy behavior                                                                                    |
|------|--------------|--------------------------------------------------------------------------------------------------------------------|
| 1    | Default      | Internet and all ports to K3s Ingress are allowed; new connections to other routed Internal networks are blocked.  |
| 3    | Guest        | K3s DNS/HTTPS and the selected media receivers are allowed; other routing follows the predefined Hotspot policies. |
| 4    | Client       | No new restriction; printer, Internal, Internet, and K3s access remain available.                                  |
| 5    | IoT Public   | Internet and all ports to K3s Ingress are allowed; new connections to other routed Internal networks are blocked.  |
| 6    | IoT Private  | All ports to K3s Ingress are allowed; other routed Internal connections and Internet access are blocked.           |
| 7    | Work         | No new restriction; Internal, Internet, and K3s access remain available.                                           |
| 8    | Unrestricted | No new restriction; Internal, Internet, and K3s access remain available.                                           |
| 10   | Server       | Hosts K3s nodes and VIPs; no new source restriction is applied.                                                    |

`Block Restricted Networks to Internal` matches only `NEW` and `INVALID`
connection states. Established replies remain available, so reconnect a test
client or start a fresh session when verifying a deny. The Internal-to-K3s
exception has no port restriction; for example, Default devices may reach
`192.168.10.51:2022` when a service is listening. Guest access to that VIP is
limited to TCP/UDP ports `53` and `443`.

The media exception targets fixed IP reservations for the selected AirPlay,
Chromecast, and Spotify Connect receivers. Adding a receiver is a two-unit
change: create its reservation in `local/lhr/unifi`, apply and verify it, then
reference the exported fixed IP from `local/lhr/unifi-firewall-rules`.

### Post-apply verification

Require clean plans for both local units:

```shell
cd infrastructure/local/lhr/unifi
terragrunt plan -detailed-exitcode --no-color
cd ../unifi-firewall-rules
terragrunt plan -detailed-exitcode --no-color
```

Then test from an actual client on every affected network. A test from one VLAN
cannot prove another VLAN's routed behavior.

```shell
# Expected on every Internal network; Guest is intentionally limited to 53/443.
nc -vz 192.168.10.51 443
dig @192.168.10.51 unifi A

# Use only when port 2022 has a known listener; the firewall allows it on Internal networks.
nc -vz 192.168.10.51 2022

# Expected everywhere except IoT Private.
curl -I https://example.com
```

Use a known listening service on another Internal host to verify an expected
deny; a failed ping is insufficient because the target may independently drop
ICMP. Finally, verify Guest casting and Client-to-Default printing with the real
applications because multicast discovery is not meaningfully covered by a TCP
port probe.

## UniFi firewall policy ordering

UniFi evaluates firewall policies in controller order. Within each zone pair,
the controller assigns contiguous positional indices beginning at `10000`, so
the next rule is `10001`, not a user-selectable `10100`. Attempts to introduce
numeric gaps are normalized. The UniFi provider can read this index but cannot
set or change it. Terraform creation dependencies therefore establish a safe
order only when a complete allow-before-deny policy set is created for the
first time.

Broad deny policies declare `allow_policy_keys_before` in the
`unifi-firewall-rules` module input. A Terraform lifecycle postcondition checks
the controller-reported indices, so every routine plan and apply fails when a
declared exception is below the deny it must precede. Do not recreate a broad
deny merely to change its position, and do not model a desired numeric priority
that the controller cannot preserve.

Roll out a new exception in an existing zone pair in two fail-closed stages:

1. Add the new allow policy with `enabled = false`, without adding its key to
    the deny's `allow_policy_keys_before`, then review and apply that unit.
2. In the UniFi UI, move the disabled allow above the broad deny.
3. Add the allow key to `allow_policy_keys_before` and run a plan. Continue only
    when the ordering postcondition passes.
4. Set `enabled = true`, review and apply the saved plan, then run a final clean
    plan.

If a future provider release supports controller-backed reordering, replace
this staged procedure with explicit provider-managed priorities only after a
live migration plan proves that existing policy order is preserved.

This controller firmware also rejects the provider's `CLIENT` firewall target.
Policies for selected clients therefore use fixed IP reservations managed by
the base UniFi unit and exported to the firewall unit. Add the reservation
before adding a client to an IP-targeted policy; keep its MAC only in the
private `tfconfig` document.

## CI drift planning

Scheduled remote plans remain disabled for now. Reconsider them only when each
provider can use appropriately scoped short-lived credentials and any private
endpoint runs on a trusted self-hosted runner. Split future jobs by provider so
a single workflow does not receive every infrastructure credential, and treat
plan output as sensitive rather than publishing it as a public artifact.

Provider constraint changes also remain deliberate, reviewed changes. Renovate
may maintain action and dependency pins, but it must not imply approval to apply
an infrastructure provider upgrade.
