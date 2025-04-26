#!/bin/bash
set -eo pipefail

# Shared utility functions for Salesforce CLI operations

# Default to PROD if not specified
TARGET_ORG=${TARGET_ORG:-"PROD"}
JQ_INSTALLED=0 # Flag to track if jq is installed

# Check if sf cli is installed
check_sf_cli() {
  if ! command -v sf &> /dev/null; then
    echo "Error: Salesforce CLI (sf) is not installed. Please install it first."
    echo "Visit: https://developer.salesforce.com/tools/sfdxcli"
    exit 1
  fi
}

# Check if jq is installed
check_jq() {
  if command -v jq &> /dev/null; then
    JQ_INSTALLED=1
  else
    echo "Warning: jq is not installed. JSON output will not be cleaned. Install jq for better formatting."
    JQ_INSTALLED=0
  fi
}

# Check if sqlite3 is installed
check_sqlite3() {
  if ! command -v sqlite3 &> /dev/null; then
    echo "Error: SQLite3 (sqlite3) is not installed. Please install it to build the replica."
    # Provide platform-specific install instructions if possible, otherwise a general message
    echo "On macOS (with Homebrew): brew install sqlite"
    echo "On Debian/Ubuntu: sudo apt-get install sqlite3"
    echo "On Fedora: sudo dnf install sqlite"
    exit 1
  fi
}

# Verify that the provided object name is valid
validate_object() {
  local object_name=$1
  
  # Try to describe the object - if it fails, it's invalid
  if ! sf sobject describe --sobject "$object_name" -o "$TARGET_ORG" --json &> /dev/null; then
    echo "Error: '$object_name' is not a valid Salesforce object in the target org."
    return 1
  fi
  
  return 0
}

# Clean JSON output by removing attributes if jq is installed
clean_json() {
  if [[ "$JQ_INSTALLED" -eq 1 ]]; then
    jq 'del(.result.records[].attributes)'
  else
    cat  # Pass through if jq is not available
  fi
}

# Format output filename based on object and type
format_filename() {
  local object_name=$1
  local file_type=$2  # "describe" or "query"
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  
  echo "${object_name}_${file_type}_${timestamp}"
}

# Logging functions
log_info() {
  echo -e "[INFO] $*" >&2
}

log_success() {
  echo -e "[SUCCESS] $*" >&2
}

log_warning() {
  echo -e "[WARNING] $*" >&2
}

log_error() {
  echo -e "[ERROR] $*" >&2
}

# Display usage information
show_usage() {
  echo "Usage: $1 [options] [object1 object2 ...]"
  echo "Options:"
  echo "  -h, --help     Show this help message"
  echo "  -o, --org ORG  Target Salesforce org (default: PROD)"
  echo
  echo "Environment variables:"
  echo "  TARGET_ORG     Override target org (default: PROD)"
} 