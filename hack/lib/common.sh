#!/bin/bash

# Common shell library for hack scripts
# Source this file in other scripts: source "$(dirname "$0")/lib/common.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Common error handling
set -euo pipefail

# Utility functions
log_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if directory exists
directory_exists() {
    [ -d "$1" ]
}

# Safe exit with error message
exit_with_error() {
    log_error "$1"
    exit 1
}

# Confirmation prompt
confirm_action() {
    local message="$1"
    local confirm_text="${2:-yes}"
    
    echo -e "${RED}WARNING: $message${NC}"
    read -p "Type '$confirm_text' to continue: " confirm
    if [[ "$confirm" != "$confirm_text" ]]; then
        log_warning "Action cancelled by user."
        exit 0
    fi
} 
