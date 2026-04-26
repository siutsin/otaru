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

## Tool Selection

| File Type   | Tool                  | Purpose                   |
|-------------|-----------------------|---------------------------|
| YAML        | `yq`                  | Parsing and modification  |
| Helm Charts | `helm`                | Validation and templating |
| Terraform   | `tofu` or `terraform` | Infrastructure as code    |
| Terragrunt  | `terragrunt`          | Terraform wrapper         |
| Markdown    | `markdownlint-cli2`   | Linting and validation    |
