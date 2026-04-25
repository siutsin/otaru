# LUKS vault variables

LUKS passphrases must stay out of the repo. Keep the source of truth outside this repo and
supply the passphrase explicitly when running rebuild or unlock helpers.

Current pattern:

- one shared vault variable for all SSD nodes: `otaru_luks_password`

## Local file and key

Use:

```shell
~/dotfiles/secrets/ansible/ansible_vault.yaml
```

Expected key:

```yaml
otaru_luks_password: "replace-me"
```

## Usage pattern

When you need the passphrase, read it yourself from:

```shell
~/dotfiles/secrets/ansible/ansible_vault.yaml
```

Do not commit:

- the vault file
- any plaintext passphrase copy

## Notes

- Use one shared password for now to keep the first rollout simple.
- Use `otaru_luks_password` from `~/dotfiles/secrets/ansible/ansible_vault.yaml` as the source of truth.
- The current initramfs prep playbook does not need the passphrase yet.
- The passphrase becomes necessary for the actual encrypted-root conversion and any future automated
  unlock-assisted reboot workflow.
- Do not make repo scripts read the vault file directly.
- Provide the passphrase explicitly to helpers through `LUKS_PASSWORD_FILE` or
  `OTARU_LUKS_PASSWORD`.
- Avoid command arguments for the passphrase. Prefer a root-only temp file or controller env var.
