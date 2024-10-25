#!/bin/bash

set -eo pipefail

CHARTS_DIR="./helm-charts"
JOBS=4

find "$CHARTS_DIR" -name 'Chart.yaml' | while read -r chart; do
  dirname "$chart"
done | xargs -P "$JOBS" -I {} bash -c "
  set -e
  chart_dir=\"{}\"
  if helm dependency update \"\$chart_dir\" > /dev/null 2>&1; then
    echo \"Success: \$chart_dir\"
  else
    echo \"Failure: \$chart_dir\"
  fi
"
