#!/usr/bin/env bash

set -euxo pipefail

for dir in helm-charts/*; do
  if [ -d "$dir" ]; then
    helm dep update "$dir"
  fi
done
