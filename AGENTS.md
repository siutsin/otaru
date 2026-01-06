# Agent Instructions

This document provides directives for LLM agents working on this project.

## Language and Format

### British English Only

- Write all comments, documentation, and commit messages in British English
- Use British English spelling (e.g., "colour", "behaviour", "optimise")
- Format dates as DD/MM/YYYY or YYYY-MM-DD (ISO 8601)

### No Emojis

- Never use emojis in code, comments, documentation, or commit messages
- Keep all communication professional and text-based

## Code Standards

### Editor Configuration

- **CRITICAL**: Always follow .editorconfig settings when generating or modifying code
- Read .editorconfig before making changes to understand indentation, line endings, and formatting rules

### Naming Conventions

- Use clear, descriptive names for variables, functions, and classes
- Avoid abbreviations unless they are widely recognised (e.g., "API", "HTTP")
- Prefer verbosity to brevity when it improves clarity

### Documentation Requirements

- Add docstrings to all new functions and classes
- Update existing docstrings when modifying function signatures or behaviour
- Include parameter types, return types, and examples where helpful

## Markdown Guidelines

### Structure

- Follow strict heading hierarchy: H1 → H2 → H3 (never skip levels)
- Use only one H1 per document (the title)
- Use H2 for main sections, H3 for subsections

### Tables

- Format tables using IntelliJ style (aligned columns with proper spacing)
- Ensure all table pipes align vertically
- Keep line length under 180 characters

### Content Quality

- Add alt text to all images: `![Description](path/to/image.png)`
- Use descriptive link text: `[Documentation](url)` not `[click here](url)`
- Check all Markdown files against markdownlint rules

## Testing Protocol

### Required Testing

1. **Always run `make test` after making changes**
2. Verify all checks pass before completing the task
3. Fix any failures immediately

### Test Command

```bash
make test
```

This executes:

- YAML syntax validation
- Markdown linting
- Helm chart validation
- Terraform linting
- Terragrunt linting
- EditorConfig compliance

## Error Handling Policy

### Fix, Never Suppress

**CRITICAL**: Always fix the root cause of warnings and errors. Never suppress or hide them.

### What to Do

- Investigate the underlying issue
- Apply the proper fix at the source
- Verify the fix resolves the problem

### What NOT to Do

- Do not use output filtering to hide errors
- Do not disable linting rules to bypass checks
- Do not add suppression comments unless absolutely necessary and documented
- Do not use workarounds that mask the real problem

### Specific Cases

**Helm Charts**:

- Fix coalesce warnings by providing default values
- Create missing values.yaml files
- Resolve template rendering issues

**YAML/JSON**:

- Fix syntax errors directly
- Correct validation issues
- Ensure proper formatting

**Markdown**:

- Fix linting violations (line length, heading hierarchy, etc.)
- Never disable markdownlint rules

## Automation Behaviour

### Auto-Fix and Auto-Apply

- Apply formatting fixes automatically without asking
- Run tests automatically after changes
- Apply suggested code changes immediately when safe
- Fix linting errors automatically when the fix is obvious

### When to Ask

- Only ask for confirmation when the change involves:
  - Significant refactoring
  - Behaviour changes
  - Architectural decisions
  - Deletion of substantial code

## Tool Selection

Use the appropriate tool for each file type:

| File Type            | Tool                  | Purpose                     |
|----------------------|-----------------------|-----------------------------|
| YAML                 | `yq`                  | Parsing and modification    |
| Helm Charts          | `helm`                | Validation and templating   |
| Terraform            | `tofu` or `terraform` | Infrastructure as code      |
| Terragrunt           | `terragrunt`          | Terraform wrapper           |
| Markdown             | `markdownlint`        | Linting and validation      |
| General file editing | `Edit` tool           | Text file modifications     |

## Diagram Conventions

### Arrow Direction

Use **action initiator** style for arrow directions - the arrow points FROM the component that initiates the action TO the target.

| Action | Arrow Direction         | Example                          |
|--------|-------------------------|----------------------------------|
| Pull   | Initiator → Source      | `ArgoCD → GitHub` (ArgoCD pulls) |
| Push   | Initiator → Destination | `GitHub → Cloudflare` (webhook)  |
| Fetch  | Initiator → Source      | `Client → Server`                |
| Send   | Initiator → Destination | `Server → Client`                |

### Examples

- **ArgoCD pulls from GitHub**: `argocd >> Edge(label="Pull") >> github`
- **GitHub sends webhook**: `github >> Edge(label="Webhook") >> cloudflare`
- **Master stores state in etcd**: `master >> Edge(label="state") >> etcd`

### Rationale

Action initiator style makes it clear WHO is performing the action, which aligns with how systems are typically described
(e.g., "ArgoCD pulls from GitHub" not "GitHub is pulled by ArgoCD").

### Icon Selection

When adding components to diagrams, follow this priority for icons:

#### 1. Prefer built-in icons from the diagrams library

- Check if the component has a built-in icon (e.g., `from diagrams.onprem.monitoring import Grafana`)
- Reuse similar built-in icons when appropriate (e.g., use `Grafana` icon for Promtail)

#### 2. Refer to diagrams/README.md for custom icon sources

- Check the Custom Icons table to see where existing icons come from
- Common sources include Dashboard Icons (Apache 2.0), CNCF Artwork, and official project repositories

#### 3. Search the internet as a last resort

- Look for official logos from project websites or repositories
- Ensure proper licensing before using
- Document the source and licence in diagrams/README.md

**Important**: Avoid creating unnecessary custom icon files. Reusing built-in icons is preferred over downloading new ones.

#### Icon Size Requirements

All custom icons in `assets/icons/` must be resized to **512x512 pixels** for consistency and to avoid unnecessarily large files.

**To resize icons:**

```bash
magick icon-name.png -resize 512x512 icon-name.png
```

**Verify icon size:**

```bash
file assets/icons/icon-name.png
```

Icons larger than 512x512 should be resized immediately after downloading.

## Project Conventions

### Consistency is Key

- Follow established patterns in the codebase
- Match the style of surrounding code when making changes
- Maintain consistent indentation and formatting throughout files

### When in Doubt

- Look for similar existing implementations
- Check recent commits for style guidance
- Refer to this document for general principles
