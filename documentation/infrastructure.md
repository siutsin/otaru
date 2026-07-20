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
  inside an explicitly approved maintenance window because the provider
  migration and controller ground-truth work are still gated.
- Never use `terragrunt run --all` for apply. Apply one reviewed unit at a time.

## Cadence

| Trigger                      | Action                                                                             |
|------------------------------|------------------------------------------------------------------------------------|
| Monthly                      | Run the non-UniFi plan across all 11 cloud units.                                  |
| Infrastructure pull request  | Plan every affected unit before merge.                                             |
| Provider or module upgrade   | Plan affected units before merge and again after any approved apply.               |
| Suspected out-of-band change | Plan the affected unit and record whether Git or the live service is ground truth. |
| UniFi maintenance            | Plan only after the provider and ground-truth gates are explicitly opened.         |

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

## UniFi firewall policy ordering

UniFi evaluates firewall policies in controller order. The UniFi provider can
read each policy's zone-pair index, but the controller does not let it set or
change that index. Terraform creation dependencies therefore establish a safe
order only when a complete allow-before-deny policy set is created for the
first time.

Broad deny policies declare `allow_policy_keys_before` in the
`unifi-firewall-rules` module input. A Terraform lifecycle postcondition checks
the controller-reported indices, so every routine plan and apply fails when a
declared exception is below the deny it must precede. Do not recreate a broad
deny to change its position and do not automate the private UniFi UI reorder
endpoint.

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
