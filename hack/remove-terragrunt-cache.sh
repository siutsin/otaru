#!/bin/bash

set -euxo pipefail

find . -type d -name '.terragrunt-cache' -prune -exec rm -rf {} +
