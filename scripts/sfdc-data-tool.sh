#!/bin/bash
set -eo pipefail

# Main script for Salesforce data operations
# Orchestrates describe and query operations on Salesforce objects

# Source utility functions (initial source for SCRIPT_DIR)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sfdc-utils.sh"

# --- Initialization ---
# Check prerequisites early. Note: jq check is done in sourced scripts if needed.
check_sf_cli

# --- Configuration & Variables ---
OPERATION="both" # Default: run describe and query
OBJECTS=()
# Initialize script-specific vars that might be passed down
# Use defaults defined in the specific scripts unless overridden here
TARGET_ORG_ARG=""
QUERY_LIMIT_ARG=""
OUTPUT_FORMAT_ARG=""

# --- Functions ---
show_main_usage() {
    echo "Usage: $(basename "$0") [options] [object1 object2 ...]"
    echo ""
    echo "Main tool to describe and/or query Salesforce objects."
    echo "If no objects are specified, uses defaults: User, Opportunity, Account, Contact, Lead."
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -o, --org ORG        Target Salesforce org alias or username (overrides env var)"
    echo "  -d, --describe       Only run the describe operation"
    echo "  -q, --query          Only run the query operation"
    echo "  -l, --limit LIMIT    Maximum number of records for query (overrides env var)"
    echo "  -f, --format FORMAT  Output format for query: json or csv (overrides env var)"
    echo ""
    echo "Output:"
    echo "  Calls describe-objects.sh and/or query-objects.sh, which generate files"
    echo "  in the '../output' directory relative to the scripts."
    echo ""
    echo "Environment Variables:"
    echo "  TARGET_ORG           Specifies the target org (used if -o not provided)."
    echo "  QUERY_LIMIT          Specifies the query limit (used if -l not provided)."
    echo "  OUTPUT_FORMAT        Specifies the query output format (used if -f not provided)."
}

# --- Argument Parsing ---
# Parse arguments for this script, store values to pass down
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_main_usage
      exit 0
      ;;
    -o|--org)
      TARGET_ORG_ARG="$2"
      shift 2
      ;;
    -d|--describe)
      # Ensure it's not combined with -q
      if [[ "$OPERATION" == "query" ]]; then
          echo "Error: Cannot specify both --describe (-d) and --query (-q)." >&2
          exit 1
      fi
      OPERATION="describe"
      shift
      ;;
    -q|--query)
      # Ensure it's not combined with -d
      if [[ "$OPERATION" == "describe" ]]; then
          echo "Error: Cannot specify both --describe (-d) and --query (-q)." >&2
          exit 1
      fi
      OPERATION="query"
      shift
      ;;
    -l|--limit)
      # Basic validation: ensure limit is a positive integer
      if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
          QUERY_LIMIT_ARG="$2"
      else
          echo "Error: Invalid limit '$2'. Must be a positive integer." >&2
          exit 1
      fi
      shift 2
      ;;
    -f|--format)
      # Basic validation: ensure format is json or csv
      format_lower=$(echo "$2" | tr '[:upper:]' '[:lower:]')
      if [[ "$format_lower" == "json" || "$format_lower" == "csv" ]]; then
          OUTPUT_FORMAT_ARG="$format_lower"
      else
          echo "Error: Invalid format '$2'. Must be 'json' or 'csv'." >&2
          exit 1
      fi
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      show_main_usage
      exit 1
      ;;
    *)
      # If it's not an option, it's an object name
      OBJECTS+=("$1")
      shift
      ;;
  esac
done

# Use default set of objects if none specified
if [[ ${#OBJECTS[@]} -eq 0 ]]; then
  OBJECTS=("User" "Opportunity" "Account" "Contact" "Lead")
fi

# --- Prepare Arguments for Sub-scripts ---
# We pass arguments explicitly to the sub-scripts rather than relying solely on exports
COMMON_ARGS=()
if [[ -n "$TARGET_ORG_ARG" ]]; then
    COMMON_ARGS+=("--org" "$TARGET_ORG_ARG")
fi

QUERY_ARGS=()
if [[ -n "$QUERY_LIMIT_ARG" ]]; then
    QUERY_ARGS+=("--limit" "$QUERY_LIMIT_ARG")
fi
if [[ -n "$OUTPUT_FORMAT_ARG" ]]; then
    QUERY_ARGS+=("--format" "$OUTPUT_FORMAT_ARG")
fi

# --- Execute Operations ---
echo "Starting Salesforce data operations..."

# Run Describe
if [[ "$OPERATION" == "describe" || "$OPERATION" == "both" ]]; then
  echo "========================================"
  echo "Running Describe Objects..."
  echo "========================================"
  if ! "$SCRIPT_DIR/describe-objects.sh" "${COMMON_ARGS[@]}" "${OBJECTS[@]}"; then
      echo "Error occurred during describe operation." >&2
      # Continue to query if operation is 'both', otherwise exit
      [[ "$OPERATION" != "both" ]] && exit 1
  fi
  echo "Describe operation finished."
  echo
fi

# Run Query
if [[ "$OPERATION" == "query" || "$OPERATION" == "both" ]]; then
  echo "========================================"
  echo "Running Query Objects..."
  echo "========================================"
  if ! "$SCRIPT_DIR/query-objects.sh" "${COMMON_ARGS[@]}" "${QUERY_ARGS[@]}" "${OBJECTS[@]}"; then
      echo "Error occurred during query operation." >&2
      exit 1 # Exit if query fails
  fi
  echo "Query operation finished."
  echo
fi

echo "========================================"
echo "All requested operations completed successfully." 