#!/bin/bash

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
CHARTS_DIR="${1:-./helm-charts}"
JOBS="${2:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
PARALLEL="${3:-false}"

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

# Function to update a single chart
update_chart() {
    local chart="$1"
    local chart_dir=$(dirname "$chart")
    local chart_name=$(basename "$chart_dir")
    
    # Update counter
    ((current_count++))
    echo -e "${YELLOW}[$current_count/$total_charts] Processing: $chart_name${NC}"
    
    # Capture helm output for error reporting
    helm_output=$(helm dependency update "$chart_dir" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success: $chart_name${NC}"
        ((success_count++))
    else
        echo -e "${RED}Failure: $chart_name${NC}"
        echo -e "${YELLOW}Helm output:${NC}\n$helm_output"
        ((failure_count++))
    fi
}

# Process charts
if [ "$PARALLEL" = "true" ]; then
    log_info "Processing charts in parallel mode..."
    # Export function for parallel execution
    export -f update_chart
    export total_charts current_count success_count failure_count
    export GREEN YELLOW RED NC
    
    echo "$chart_files" | xargs -P "$JOBS" -I {} bash -c 'update_chart "{}"'
else
    log_info "Processing charts sequentially..."
    while IFS= read -r chart; do
        update_chart "$chart"
    done <<< "$chart_files"
fi

echo ""
log_success "=== Summary ==="
log_success "Total charts processed: $total_charts"
log_success "Successful updates: $success_count"
if [ $failure_count -gt 0 ]; then
    log_error "Failed updates: $failure_count"
    exit 1
else
    log_success "All charts updated successfully!"
fi
