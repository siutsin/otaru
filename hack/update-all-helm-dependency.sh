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

# Check if helm is installed
if ! command_exists helm; then
    exit_with_error "Helm is not installed or not in PATH"
fi

# Check if charts directory exists
if ! directory_exists "$CHARTS_DIR"; then
    exit_with_error "Charts directory '$CHARTS_DIR' does not exist"
fi

if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
    exit_with_error "Jobs must be a positive integer, got '$JOBS'"
fi

if [[ "$PARALLEL" != "true" && "$PARALLEL" != "false" ]]; then
    exit_with_error "Parallel mode must be 'true' or 'false', got '$PARALLEL'"
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
chart_files=()
while IFS= read -r -d '' chart; do
    chart_files+=("$chart")
done < <(find "$CHARTS_DIR" -name 'Chart.yaml' -print0 2>/dev/null)

if [ "${#chart_files[@]}" -eq 0 ]; then
    log_warning "No Chart.yaml files found in $CHARTS_DIR"
    exit 0
fi

# Count total charts
total_charts=${#chart_files[@]}
log_success "Found $total_charts chart(s) to update"
echo ""

# Initialize counters
success_count=0
failure_count=0

should_retry_helm_error() {
    local helm_output="$1"
    local normalized_output

    normalized_output=$(printf '%s' "$helm_output" | tr '[:upper:]' '[:lower:]')

    case "$normalized_output" in
        *"context deadline exceeded"*|\
        *"tls handshake timeout"*|\
        *"timeout"*|\
        *"temporary failure"*|\
        *"connection reset by peer"*|\
        *"connection refused"*|\
        *"unexpected eof"*|\
        *" eof"*|\
        *"no such host"*|\
        *"service unavailable"*|\
        *"too many requests"*|\
        *"response status code 429"*|\
        *"response status code 500"*|\
        *"response status code 502"*|\
        *"response status code 503"*|\
        *"response status code 504"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

count_results() {
    success_count=0
    failure_count=0

    if [ -f "$RESULTS_FILE" ]; then
        success_count=$(grep -c "^SUCCESS:" "$RESULTS_FILE" || true)
        failure_count=$(grep -c "^FAILURE:" "$RESULTS_FILE" || true)
    fi
}

# Function to update a single chart (works for both sequential and parallel)
update_chart() {
    local chart="$1"
    local display_index="${2:-}"
    local chart_dir
    local chart_name
    local attempt=1
    local retry_delay="$RETRY_DELAY_SECONDS"
    local helm_output=""
    local helm_exit_code=0
    local result_msg
    local progress_prefix=""

    chart_dir=$(dirname "$chart")
    chart_name=$(basename "$chart_dir")

    while true; do
        # Retry transient repository and download failures instead of failing
        # the full run on a single connection reset.
        helm_output=$(helm dependency update --skip-refresh "$chart_dir" 2>&1)
        helm_exit_code=$?

        if [ $helm_exit_code -eq 0 ] || [ $attempt -ge "$MAX_RETRIES" ] || ! should_retry_helm_error "$helm_output"; then
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

    if [ -n "$display_index" ]; then
        progress_prefix="${YELLOW}[$display_index/$total_charts]${NC} "
    fi

    echo -e "${progress_prefix}$result_msg"
}

# Process charts
# Temporarily disable exit on error for chart processing
set +e

# Initialize results file for all modes
rm -f "$RESULTS_FILE"

if [ "$PARALLEL" = "true" ]; then
    log_info "Processing charts in parallel mode..."
    export -f update_chart
    export -f should_retry_helm_error
    export PARALLEL total_charts GREEN YELLOW RED NC RESULTS_FILE MAX_RETRIES RETRY_DELAY_SECONDS
    printf '%s\0' "${chart_files[@]}" | xargs -0 -n 1 -P "$JOBS" bash -c "update_chart \"\$1\"" _
else
    log_info "Processing charts sequentially..."
    chart_index=0
    for chart in "${chart_files[@]}"; do
        chart_index=$((chart_index + 1))
        update_chart "$chart" "$chart_index"
    done
fi

# Re-enable exit on error
set -e

count_results

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
