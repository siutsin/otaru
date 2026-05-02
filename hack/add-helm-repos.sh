#!/bin/bash

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

CHARTS_DIR="${1:-./helm-charts}"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/helm-repos.XXXXXX")
ALL_REPOS_FILE="${TEMP_DIR}/all-repos"
REPOS_FILE="${TEMP_DIR}/repos"

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

if ! command_exists helm; then
    exit_with_error "Helm is not installed or not in PATH"
fi

if ! command_exists yq; then
    exit_with_error "yq is not installed or not in PATH"
fi

if ! directory_exists "$CHARTS_DIR"; then
    exit_with_error "Charts directory '$CHARTS_DIR' does not exist"
fi

find "$CHARTS_DIR" -name 'Chart.yaml' -print0 \
    | while IFS= read -r -d '' chart; do
        yq -r '.dependencies[]?.repository // ""' "$chart"
    done \
    | sed '/^$/d' > "$ALL_REPOS_FILE"

awk '/^https?:\/\//' "$ALL_REPOS_FILE" | sort -u > "$REPOS_FILE"

if [ ! -s "$REPOS_FILE" ]; then
    log_warning "No HTTP Helm repositories found in $CHARTS_DIR"
    exit 0
fi

log_info "Adding Helm repositories from chart dependencies..."

while IFS= read -r repo; do
    repo_name=$(
        echo "$repo" \
            | sed -E 's#^https?://##; s#/$##; s#[^A-Za-z0-9]+#-#g; s#^-##; s#-$##' \
            | tr '[:upper:]' '[:lower:]'
    )
    helm repo add "$repo_name" "$repo" --force-update >/dev/null
    log_success "Added Helm repository: $repo_name"
done < "$REPOS_FILE"

helm repo update >/dev/null
log_success "Helm repositories are up to date"
