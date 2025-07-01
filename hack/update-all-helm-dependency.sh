#!/bin/bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
CHARTS_DIR="${1:-./helm-charts}"
JOBS="${2:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

# Check if helm is installed
if ! command -v helm >/dev/null 2>&1; then
    echo -e "${RED}Error: Helm is not installed or not in PATH${NC}"
    exit 1
fi

# Check if charts directory exists
if [ ! -d "$CHARTS_DIR" ]; then
    echo -e "${RED}Error: Charts directory '$CHARTS_DIR' does not exist${NC}"
    exit 1
fi

echo -e "${GREEN}Updating Helm dependencies...${NC}"
echo -e "${YELLOW}Charts directory: $CHARTS_DIR${NC}"
echo -e "${YELLOW}Parallel jobs: $JOBS${NC}"
echo ""

# Find all Chart.yaml files
chart_files=$(find "$CHARTS_DIR" -name 'Chart.yaml' 2>/dev/null)

if [ -z "$chart_files" ]; then
    echo -e "${YELLOW}No Chart.yaml files found in $CHARTS_DIR${NC}"
    exit 0
fi

# Count total charts
total_charts=$(echo "$chart_files" | wc -l)
echo -e "${GREEN}Found $total_charts chart(s) to update${NC}"
echo ""

# Initialize counters
success_count=0
failure_count=0
current_count=0

# Process charts sequentially for now (safer approach)
while IFS= read -r chart; do
    chart_dir=$(dirname "$chart")
    chart_name=$(basename "$chart_dir")
    
    # Update counter
    ((current_count++))
    echo -e "${YELLOW}[$current_count/$total_charts] Processing: $chart_name${NC}"
    
    if helm dependency update "$chart_dir" > /dev/null 2>&1; then
        echo -e "${GREEN}Success: $chart_name${NC}"
        ((success_count++))
    else
        echo -e "${RED}Failure: $chart_name${NC}"
        ((failure_count++))
    fi
done <<< "$chart_files"

echo ""
echo -e "${GREEN}=== Summary ===${NC}"
echo -e "${GREEN}Total charts processed: $total_charts${NC}"
echo -e "${GREEN}Successful updates: $success_count${NC}"
if [ $failure_count -gt 0 ]; then
    echo -e "${RED}Failed updates: $failure_count${NC}"
    exit 1
else
    echo -e "${GREEN}All charts updated successfully!${NC}"
fi
