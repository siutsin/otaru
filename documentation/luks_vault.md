# LUKS vault variables

LUKS passphrases must stay out of the repo. Use the local Ansible vault file and key below.

Current pattern:

- one shared vault variable for all SSD nodes: `ubuntu_luks_password`

## Existing local file and key

Use:

```shell
~/dotfiles/password/ansible_vault.yaml
```

Expected key:

```yaml
ubuntu_luks_password: "replace-me"
```

## Usage pattern

When a future playbook or handler needs the passphrase, load it from:

```shell
~/dotfiles/password/ansible_vault.yaml
```

Do not commit:

- the vault file
- any plaintext passphrase copy

## Notes

- Use one shared password for now to keep the first rollout simple and aligned with the previous
  LUKS workflow.
- Use `ubuntu_luks_password` from `~/dotfiles/password/ansible_vault.yaml` as the source of truth.
- The current initramfs prep playbook does not need the passphrase yet.
- The passphrase becomes necessary for the actual encrypted-root conversion and any future automated
  unlock-assisted reboot workflow.
- The rescue rebuild wrapper reads the passphrase from the vault locally and streams it to the rescue
  host over SSH stdin. It should not be placed in command arguments or committed files.
- If the passphrase is ever typed or embedded in command text during debugging, rotate it before the
  next real rebuild or boot validation.
