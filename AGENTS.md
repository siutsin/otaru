# Agent Instructions

## EditorConfig

Before editing any files, read `.editorconfig` at the repository root and
follow its formatting rules for charset, line endings, indentation, trailing
whitespace, final newlines, and line length.

## Multi-Agent Worktree Policy

Use a dedicated Git worktree only when another agent may be active in the same
repository. If no other agent is working in the repo, use the current checkout.

- When a worktree is needed, create one worktree per agent and per task branch,
  for example:
  `git worktree add -b <branch> /tmp/otaru-<task> origin/master`.
- Never have two agents edit the same worktree directory.
- Never intentionally check out the same branch in multiple worktrees.
- Keep commits, tests, and PR loops scoped to that worktree's branch.
- Avoid destructive shared Git operations while another agent is active,
  including force-pushes, hard resets, broad branch deletion, and aggressive
  cleanup.
- Before touching files in an existing checkout, run `git status --short
  --branch` and `git worktree list` to understand what branch and worktree are
  in use.

### Worktree Cleanup

Clean up worktrees and branches that belong to your completed task before your
final response. If a worktree you created must remain open because the task is
not merged, not pushed, or intentionally paused, say so explicitly. Do not clean
up another agent's worktree unless the user explicitly asks.

1. Inspect current worktrees with `git worktree list`.
2. Verify the target worktree has no uncommitted work with
  `git -C <worktree-path> status --short --branch`.
3. If the work is merged or intentionally discarded, remove the worktree with
  `git worktree remove <worktree-path>`.
4. Prune stale worktree metadata with `git worktree prune`.
5. Delete the local task branch only when it is merged or explicitly abandoned:
  `git branch -d <branch>`.
6. Delete the remote task branch only after the PR is merged or the user
  explicitly asks for discard: `git push origin --delete <branch>`.

Do not remove a worktree, local branch, or remote branch that another agent may
still be using. Always report which of your own worktrees were removed and which
remain open.

## GitHub CLI

When waiting on pull requests or CI, use `gh` watch commands instead of `sleep`
loops or manual polling.

- PR checks: `gh pr checks <number> --watch --fail-fast`
- Workflow run: `gh run watch <run-id> --exit-status`
- One-shot status: `gh pr checks <number>` or `gh pr view <number> --json statusCheckRollup`

For cluster or workload readiness, prefer `kubectl wait`, `kubectl rollout
status`, or `kubectl get <resource> -w` rather than `sleep`.

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
Whenever you change a resource request or limit, add an inline comment in the
resource block stating the observed symptom and the reason for the new value.
This covers CPU, memory, and ephemeral-storage bumps, whether triggered by an
OOMKill, CPU throttling, disk-pressure eviction, or capacity headroom. Record
the trigger, for example the exit code and the workload that caused it, and why
the previous value was too low.

**Markdown**: fix linting violations directly, never disable markdownlint rules.

## Cluster Access

Use the Kubernetes MCP tools for live cluster inspection whenever they are
available. Prefer them for read-only diagnostics such as listing Pods, reading
events, checking Argo CD Applications, inspecting resources, logs, and metrics
before falling back to `kubectl`.

For mutating operations, keep GitOps as the source of truth: patch the repo and
let Argo CD reconcile unless the user explicitly asks for an emergency live
change.

## KRR (Kubernetes Resource Recommender)

- Run: `krr simple -p <prometheus-url-via-ingress>`
- `<prometheus-url-via-ingress>`: HTTPS ingress for `httpRoutes.prometheus` in
  `helm-charts/monitoring/values.yaml` (see `route-internal.yaml`).
- When building the report and recommendations, read inline resource comments
  for past incidents (OOM, probe failures, scheduling pressure) and exclude
  downsizing past those guardrails.

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
- If a LUKS node is already waiting in initramfs after boot, unlock it with the
  documented make target, for example `make unlock <node-name>`.
- For emergency single-node reboot work, first check whether the target is in
  the `luks_root_nodes` inventory group; if it is, do not proceed unless a
  LUKS-aware playbook or `make unlock <node-name>` workflow is used.

## Tool Selection

| File Type   | Tool                  | Purpose                   |
|-------------|-----------------------|---------------------------|
| YAML        | `yq`                  | Parsing and modification  |
| Helm Charts | `helm`                | Validation and templating |
| Terraform   | `tofu` or `terraform` | Infrastructure as code    |
| Terragrunt  | `terragrunt`          | Terraform wrapper         |
| Markdown    | `markdownlint-cli2`   | Linting and validation    |

Before widening a pinned provider version constraint in `infrastructure/version.hcl`,
read `documentation/gotcha.md` for the Cloudflare provider state-migration gotcha —
large version jumps can break `plan`/`import` on resources whose schema changed,
not just produce plan noise.

## New Helm Chart Onboarding Checklist

When adding a new app under `helm-charts/<name>/`, update every integration
point below that applies. Missing one is a common production failure mode
(route `NotAllowedByListeners`, ExternalSecret blocked by Kyverno, pod never
Ready on a wrong probe path). Use a peer chart (for example `httpbin`,
`kubernetes-mcp-server`, or `unifi-mcp`) as the template.

### Chart package (`helm-charts/<name>/`)

- [ ] `Chart.yaml`, `values.yaml`, `.helmignore`, and templates for the workload
- [ ] Image digest-pinned (`tag: <version>@sha256:…`), not a floating tag alone
- [ ] Resources: memory request = memory limit; no CPU limit unless explicitly
  requested; ephemeral-storage request and limit set
- [ ] Pod/container securityContext: non-root, drop `ALL`, read-only rootfs when
  feasible (compensate in the chart if the upstream image runs as root)
- [ ] Probes that match what the process actually exposes (HTTP path that
  returns 2xx/3xx, or `tcpSocket` when there is no health endpoint)
- [ ] `Service` + `ServiceAccount` (`automountServiceAccountToken: false` unless
  the workload needs the API)
- [ ] Ambient mesh: `AuthorizationPolicy` with `targetRefs` on the `Service` and
  `from.source.principals` allowing the gateway SA
  (`cluster.local/ns/gateway/sa/gateway`) for ingress-backed ports
- [ ] Secrets: `ExternalSecret` → ClusterSecretStore `onepassword-secret-store`,
  plus Reloader (`reloader.stakater.com/auto: "true"`) when secret rotation
  should restart pods
- [ ] Ingress: internal and/or public `HTTPRoute` as needed (path rewrites,
  hostnames under `*.internal.siutsin.com` or public names)

### GitOps registration

- [ ] `argocd/manifest.jsonnet` — Application entry (`wave`, `name`,
  `namespace`; optional `path` / `helm` overrides). Path defaults to
  `helm-charts/<name>` when omitted
- [ ] `helm-charts/namespaces/values.yaml` — namespace list entry. Ambient labels
  default on; set `ambient: false` only when mesh must stay off

### Kyverno (`helm-charts/kyverno-policy/values.yaml`)

- [ ] **`clusterSecretStorePolicy.allowedNamespaces`** — required for any
  ExternalSecret that reads 1Password via `onepassword-secret-store`. Map
  `namespace: [1Password item name, …]`
- [ ] **`barmanObjectStorePolicy.allowedNamespaces`** — only if the chart uses
  CloudNativePG Barman object stores
- [ ] **Exclude-list policies** (`workloadResourcesPolicy`,
  `requireImageTagPolicy`, `requireContainerHardeningPolicy`,
  `meshAuthorizationPolicy`) — do **not** add the new namespace by default;
  make the chart compliant instead. Only add an exclude when the user
  explicitly accepts the risk and documents why

### Envoy Gateway (`helm-charts/envoy-gateway/templates/gateway.yaml`)

- [ ] HTTPS listener `allowedRoutes.namespaces` selector — add the chart
  namespace or the HTTPRoute stays `NotAllowedByListeners` and the hostname
  404s
- [ ] Extra listeners (TCP/UDP, non-443) only if the chart needs them; add the
  namespace to that listener's allowlist the same way

### Secrets and docs outside the chart

- [ ] 1Password item in the vault used by Connect (typically `github-otaru`),
  field names matching the ExternalSecret `remoteRef` properties. Prefer
  creating the item via `op`; never commit secret values
- [ ] `README.md` Cluster Components (and SaaS table if an external dependency
  is new)
- [ ] `documentation/secrets.md` or other docs only when the secret layout is
  non-obvious or operator-facing

### Verify before merge

- [ ] `make test` green (Helm lint/template, YAML, markdown, EditorConfig, …)
- [ ] After merge/sync: Application Synced/Healthy, ExternalSecret Ready (if
  any), pod Ready, HTTPRoute `Accepted`, and a real request through the
  published hostname or in-cluster Service
