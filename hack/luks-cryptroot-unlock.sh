#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <host-or-ip> [port] [--passfifo | remote-command...]" >&2
  exit 1
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

exec ssh "${ssh_args[@]}" "$@"
