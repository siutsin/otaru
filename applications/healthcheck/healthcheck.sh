#!/usr/bin/env bash

set -euxo pipefail

if curl -s -i -m 2 "$TARGET_URL"; then
  curl -s "$HEALTH_CHECK_IO_SUCCESS_URL"
else
  curl -s "$HEALTH_CHECK_IO_FAILURE_URL"
fi
