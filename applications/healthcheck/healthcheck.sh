#!/usr/bin/env bash

set -euxo pipefail

retry=0
max_retries=3

while [[ $retry -lt $max_retries ]]; do
  if curl -s -i -m 2 "$TARGET_URL"; then
    curl -s "$HEALTH_CHECK_IO_SUCCESS_URL"
    exit 0
  fi
  ((retry++))
done

curl -s "$HEALTH_CHECK_IO_FAILURE_URL"
