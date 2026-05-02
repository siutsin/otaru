# Agent Instructions

## Testing Protocol

Always run `make test` after making changes and fix any failures immediately.

This executes:

- YAML syntax validation
- Markdown linting
- Helm chart validation
- Terraform linting
- Terragrunt linting
- EditorConfig compliance
- Zizmor audit

## Error Handling Policy

**CRITICAL**: Always fix the root cause of warnings and errors. Never suppress or hide them.

- Do not use output filtering to hide errors
- Do not disable linting rules to bypass checks
- Do not add suppression comments unless absolutely necessary and documented

### Specific Cases

**Helm Charts**: fix coalesce warnings by providing default values,
create missing values.yaml files, resolve template rendering issues.
Set memory requests equal to memory limits unless the user explicitly asks otherwise.
Do not set CPU limits unless the user explicitly asks for them.
Set explicit ephemeral-storage requests and limits with suitable values for the workload.

**Markdown**: fix linting violations directly, never disable markdownlint rules.

## Node Reboot Policy

Some Raspberry Pi nodes use LUKS encrypted root disks and do not return from a
plain reboot until the initramfs unlock step runs.

- Never reboot a node directly with `reboot`, `shutdown`, `systemctl reboot`,
  `kubectl debug`, or Ansible's generic `reboot` module.
- Use the repository's LUKS-aware Ansible playbooks for planned node reboots so
  they can cordon/drain, wait for initramfs dropbear, unlock LUKS, wait for SSH,
  and uncordon safely.
- For rolling maintenance, use `make maintenance` with
  `OTARU_LUKS_PASSWORD` available in the controller environment.
- For workload-only restarts that do not reboot hosts, use `make restart`.
- For emergency single-node reboot work, first check whether the target is in
  the `luks_root_nodes` inventory group; if it is, do not proceed unless a
  LUKS-aware playbook or unlock workflow is used.

## Tool Selection

| File Type   | Tool                  | Purpose                   |
|-------------|-----------------------|---------------------------|
| YAML        | `yq`                  | Parsing and modification  |
| Helm Charts | `helm`                | Validation and templating |
| Terraform   | `tofu` or `terraform` | Infrastructure as code    |
| Terragrunt  | `terragrunt`          | Terraform wrapper         |
| Markdown    | `markdownlint-cli2`   | Linting and validation    |
