#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: luks-cryptroot-unlock.sh <host-or-ip> [port] [--passfifo | --vault-passfifo [vault-file] [vault-key] | remote-command...]
EOF
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

host="$1"
shift

port="1024"
if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
  port="$1"
  shift
fi

ssh_args=(
  -p "${port}"
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  "root@${host}"
)

if [[ $# -eq 0 ]]; then
  exec ssh "${ssh_args[@]}"
fi

if [[ "$1" == "--passfifo" ]]; then
  shift
  exec ssh "${ssh_args[@]}" 'cat > /lib/cryptsetup/passfifo'
fi

if [[ "$1" == "--vault-passfifo" ]]; then
  shift
  vault_file="${1:-$HOME/dotfiles/password/ansible_vault.yaml}"
  vault_key="${2:-ubuntu_luks_password}"
  passphrase="$(yq ".${vault_key}" "${vault_file}")"
  if [[ -z "${passphrase}" || "${passphrase}" == "null" ]]; then
    echo "Failed to read ${vault_key} from ${vault_file}" >&2
    exit 1
  fi
  printf '%s\n' "${passphrase}" | exec ssh "${ssh_args[@]}" 'cat > /lib/cryptsetup/passfifo'
fi

exec ssh "${ssh_args[@]}" "$@"
