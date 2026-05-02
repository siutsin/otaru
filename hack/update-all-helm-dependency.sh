#!/bin/bash

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

# Configuration
CHARTS_DIR="${1:-./helm-charts}"
JOBS="${2:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
PARALLEL="${3:-true}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-2}"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/helm-update.XXXXXX")
RESULTS_FILE="${TEMP_DIR}/results"
COUNTER_FILE="${TEMP_DIR}/counter"
COUNTER_LOCK_DIR="${TEMP_DIR}/counter.lock"

# Check if helm is installed
if ! command_exists helm; then
    exit_with_error "Helm is not installed or not in PATH"
fi

# Check if charts directory exists
if ! directory_exists "$CHARTS_DIR"; then
    exit_with_error "Charts directory '$CHARTS_DIR' does not exist"
fi

ensure_helm_repos() {
    "${SCRIPT_DIR}/add-helm-repos.sh" "$CHARTS_DIR"
}

log_info "Ensuring Helm repositories are configured..."
ensure_helm_repos

log_info "Updating Helm dependencies..."
log_info "Charts directory: $CHARTS_DIR"
log_info "Parallel jobs: $JOBS"
log_info "Parallel mode: $PARALLEL"
echo ""

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

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

# Function to update a single chart (works for both sequential and parallel)
update_chart() {
    local chart="$1"
    local chart_dir
    local chart_name
    local count
    local attempt=1
    local retry_delay="$RETRY_DELAY_SECONDS"
    local helm_output=""
    local helm_exit_code=0

    chart_dir=$(dirname "$chart")
    chart_name=$(basename "$chart_dir")

    while true; do
        # Retry transient repository and download failures instead of failing
        # the full run on a single connection reset.
        helm_output=$(helm dependency update "$chart_dir" 2>&1)
        helm_exit_code=$?

        if [ $helm_exit_code -eq 0 ] || [ $attempt -ge "$MAX_RETRIES" ]; then
            break
        fi

        echo -e "${YELLOW}Retrying ${chart_name} dependency update after attempt ${attempt}/${MAX_RETRIES}${NC}" >&2
        sleep "$retry_delay"
        attempt=$((attempt + 1))
        retry_delay=$((retry_delay * 2))
    done

    if [ $helm_exit_code -eq 0 ]; then
        echo "SUCCESS:$chart_name" >> "$RESULTS_FILE"
        if [ $attempt -gt 1 ]; then
            result_msg="${GREEN}Success: $chart_name${NC} ${YELLOW}(after $attempt attempts)${NC}"
        else
            result_msg="${GREEN}Success: $chart_name${NC}"
        fi
    else
        echo "FAILURE:$chart_name" >> "$RESULTS_FILE"
        result_msg="${RED}Failure: $chart_name${NC}\n${YELLOW}Helm output:${NC}\n$helm_output"
    fi

    # Pure bash lock using mkdir
    while ! mkdir "$COUNTER_LOCK_DIR" 2>/dev/null; do sleep 0.05; done
    if [ ! -f "$COUNTER_FILE" ]; then
        echo 0 > "$COUNTER_FILE"
    fi
    count=$(< "$COUNTER_FILE")
    count=$((count + 1))
    echo "$count" > "$COUNTER_FILE"
    rmdir "$COUNTER_LOCK_DIR"

    echo -e "${YELLOW}[$count/$total_charts]${NC} $result_msg"
}

# Process charts
# Temporarily disable exit on error for chart processing
set +e

# Initialize results and counter files for all modes
rm -f "$RESULTS_FILE" "$COUNTER_FILE"

if [ "$PARALLEL" = "true" ]; then
    log_info "Processing charts in parallel mode..."
    export -f update_chart
    export PARALLEL total_charts GREEN YELLOW RED NC RESULTS_FILE COUNTER_FILE COUNTER_LOCK_DIR MAX_RETRIES RETRY_DELAY_SECONDS
    echo "$chart_files" | xargs -P "$JOBS" -I {} bash -c 'update_chart "{}"'
    # Count results from the temporary file
    if [ -f "$RESULTS_FILE" ]; then
        success_count=$(grep -c "^SUCCESS:" "$RESULTS_FILE" || echo 0)
        failure_count=$(grep -c "^FAILURE:" "$RESULTS_FILE" || echo 0)
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
