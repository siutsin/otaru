#!/bin/bash

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
CHARTS_DIR="${1:-./helm-charts}"
JOBS="${2:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
PARALLEL="${3:-true}"

# Check if helm is installed
if ! command_exists helm; then
    exit_with_error "Helm is not installed or not in PATH"
fi

# Check if charts directory exists
if ! directory_exists "$CHARTS_DIR"; then
    exit_with_error "Charts directory '$CHARTS_DIR' does not exist"
fi

log_info "Updating Helm dependencies..."
log_info "Charts directory: $CHARTS_DIR"
log_info "Parallel jobs: $JOBS"
log_info "Parallel mode: $PARALLEL"
echo ""

# Find all Chart.yaml files
chart_files=$(find "$CHARTS_DIR" -name 'Chart.yaml' 2>/dev/null)

if [ -z "$chart_files" ]; then
    log_warning "No Chart.yaml files found in $CHARTS_DIR"
    exit 0
fi

# Count total charts
total_charts=$(echo "$chart_files" | wc -l)
log_success "Found $total_charts chart(s) to update"
echo ""

# Initialize counters
success_count=0
failure_count=0
current_count=0

# Function to update a single chart (works for both sequential and parallel)
update_chart() {
    local chart="$1"
    local chart_dir=$(dirname "$chart")
    local chart_name=$(basename "$chart_dir")
    local count

    # Capture helm output for error reporting
    helm_output=$(helm dependency update "$chart_dir" 2>&1)
    local helm_exit_code=$?

    if [ $helm_exit_code -eq 0 ]; then
        echo "SUCCESS:$chart_name" >> /tmp/helm_update_results
        result_msg="${GREEN}Success: $chart_name${NC}"
    else
        echo "FAILURE:$chart_name" >> /tmp/helm_update_results
        result_msg="${RED}Failure: $chart_name${NC}\n${YELLOW}Helm output:${NC}\n$helm_output"
    fi

    # Pure bash lock using mkdir
    while ! mkdir /tmp/helm_update_counter.lock 2>/dev/null; do sleep 0.05; done
    if [ ! -f /tmp/helm_update_counter ]; then
        echo 0 > /tmp/helm_update_counter
    fi
    count=$(< /tmp/helm_update_counter)
    count=$((count + 1))
    echo "$count" > /tmp/helm_update_counter
    rmdir /tmp/helm_update_counter.lock

    echo -e "${YELLOW}[$count/$total_charts]${NC} $result_msg"
}

# Process charts
# Temporarily disable exit on error for chart processing
set +e

# Initialize results and counter files for all modes
rm -f /tmp/helm_update_results /tmp/helm_update_counter /tmp/helm_update_counter.lock

if [ "$PARALLEL" = "true" ]; then
    log_info "Processing charts in parallel mode..."
    export -f update_chart
    export PARALLEL total_charts GREEN YELLOW RED NC
    echo "$chart_files" | xargs -P "$JOBS" -I {} bash -c 'update_chart "{}"'
    # Count results from the temporary file
    if [ -f /tmp/helm_update_results ]; then
        success_count=$(grep -c "^SUCCESS:" /tmp/helm_update_results || echo 0)
        failure_count=$(grep -c "^FAILURE:" /tmp/helm_update_results || echo 0)
    fi
else
    log_info "Processing charts sequentially..."
    while IFS= read -r chart; do
        update_chart "$chart"
    done <<< "$chart_files"
fi

# Re-enable exit on error
set -e

# After counting results from the temporary file (in both modes), ensure success_count and failure_count are always integers
success_count=${success_count:-0}
failure_count=${failure_count:-0}
if ! [[ "$failure_count" =~ ^[0-9]+$ ]]; then
  failure_count=0
fi
if ! [[ "$success_count" =~ ^[0-9]+$ ]]; then
  success_count=0
fi

echo ""
log_success "=== Summary ==="
log_success "Total charts processed: $total_charts"
log_success "Successful updates: $success_count"
if [ "$failure_count" -gt 0 ]; then
    log_error "Failed updates: $failure_count"
    exit 1
else
    log_success "All charts updated successfully!"
fi
