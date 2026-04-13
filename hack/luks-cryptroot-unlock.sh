#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: luks-cryptroot-unlock.sh <host-or-ip> [port] [--passfifo | --env-passfifo [env-var] | remote-command...]
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
  # cryptroot-unlock reads the passphrase from stdin and coordinates with the
  # real askpass waiter, so callers must pipe the exact passphrase bytes in.
  exec ssh "${ssh_args[@]}" '/usr/bin/cryptroot-unlock'
fi

if [[ "$1" == "--env-passfifo" ]]; then
  shift
  env_var="${1:-OTARU_LUKS_PASSWORD}"
  passphrase="${!env_var:-}"
  if [[ -z "${passphrase}" ]]; then
    echo "Missing required environment variable: ${env_var}" >&2
    exit 1
  fi
  printf '%s' "${passphrase}" | ssh "${ssh_args[@]}" '/usr/bin/cryptroot-unlock'
  exit 0
fi

exec ssh "${ssh_args[@]}" "$@"
