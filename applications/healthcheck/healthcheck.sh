#!/usr/bin/env bash

set -euxo pipefail

retry=0
max_retries=3

while [[ $retry -lt $max_retries ]]; do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$TARGET_URL")

  if [[ $status_code -eq 200 ]]; then
    curl -s -m 5 "$HEALTH_CHECK_IO_SUCCESS_URL"
    exit 0
  fi

  ((retry++))
done

curl -s -m 5 "$HEALTH_CHECK_IO_FAILURE_URL"
