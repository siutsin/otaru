#!/usr/bin/env bash

set -euxo pipefail

response=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$TARGET_URL")

if [ "$response" -eq 200 ]; then
  curl -s -m 5 "$HEALTH_CHECK_IO_SUCCESS_URL"
else
  curl -s -m 5 "$HEALTH_CHECK_IO_FAILURE_URL"
fi
