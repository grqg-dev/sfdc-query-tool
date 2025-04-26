#!/bin/bash
set -eo pipefail

# Script to query Salesforce objects and populate SQLite database
# Combines the functionality of sfdc-data-tool.sh and setup_sfdc_replica.sh

# --- Initialization ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sfdc-utils.sh"

# --- Check Prerequisites ---
check_sf_cli
check_jq
check_sqlite3

# --- Configuration & Variables ---
OBJECTS=()
TARGET_ORG=${TARGET_ORG:-}
QUERY_LIMIT=${QUERY_LIMIT:-100}
OUTPUT_FORMAT="csv" # Fixed to CSV for SQLite import
OUTPUT_DIR="$SCRIPT_DIR/../output"
DB_FILE="$OUTPUT_DIR/sfdc-replica.db"
SKIP_QUERY=0
SKIP_DESCRIBE=0
SKIP_IMPORT=0
OPTIMIZE_DB=1

# --- Functions ---
show_usage() {
  echo "Usage: $(basename "$0") [options] [object1 object2 ...]"
  echo ""
  echo "Queries Salesforce objects and imports them into a SQLite database."
  echo "If no objects are specified, uses defaults: User, Opportunity, Account, Contact, Lead."
  echo ""
  echo "Options:"
  echo "  -h, --help           Show this help message"
  echo "  -o, --org ORG        Target Salesforce org alias or username"
  echo "  -l, --limit LIMIT    Maximum number of records per object (default: 100)"
  echo "  -d, --db DB_FILE     SQLite database file (default: output/sfdc-replica.db)"
  echo "  --skip-query         Skip querying Salesforce (use existing CSV files)"
  echo "  --skip-describe      Skip describing Salesforce objects"
  echo "  --skip-import        Skip importing to SQLite (query only)"
  echo "  --no-optimize        Skip database optimization"
  echo ""
  echo "Output:"
  echo "  Generates CSV files in the 'output' directory and imports them to SQLite."
  echo ""
  echo "Environment Variables:"
  echo "  TARGET_ORG           Overrides the target org specified with -o."
  echo "  QUERY_LIMIT          Overrides the default query limit."
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_usage
      exit 0
      ;;
    -o|--org)
      TARGET_ORG="$2"
      shift 2
      ;;
    -l|--limit)
      if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
          QUERY_LIMIT="$2"
      else
          echo "Error: Invalid limit '$2'. Must be a positive integer." >&2
          exit 1
      fi
      shift 2
      ;;
    -d|--db)
      DB_FILE="$2"
      shift 2
      ;;
    --skip-query)
      SKIP_QUERY=1
      shift
      ;;
    --skip-describe)
      SKIP_DESCRIBE=1
      shift
      ;;
    --skip-import)
      SKIP_IMPORT=1
      shift
      ;;
    --no-optimize)
      OPTIMIZE_DB=0
      shift
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      show_usage
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

# Export TARGET_ORG for the sub-scripts
if [[ -n "$TARGET_ORG" ]]; then
  export TARGET_ORG
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# --- Main Workflow ---
echo "========================================================="
echo "Starting Salesforce to SQLite Workflow"
echo "========================================================="
echo "Target Org: ${TARGET_ORG:-Default}"
echo "Query Limit: $QUERY_LIMIT records per object"
echo "Database File: $DB_FILE"
echo "Objects: ${OBJECTS[*]}"
echo "--------------------------------------------------------"

# Initialize SQLite database if we're going to import
if [[ "$SKIP_IMPORT" -ne 1 ]]; then
  echo "Initializing SQLite database..."
  if [[ -f "$DB_FILE" ]]; then
    echo "Database file already exists at $DB_FILE"
  else
    echo "Creating new database at $DB_FILE"
    sqlite3 "$DB_FILE" ".databases"
    echo "Database created."
  fi
  echo "--------------------------------------------------------"
fi

# Describe Objects
if [[ "$SKIP_DESCRIBE" -ne 1 ]]; then
  echo "Describing Salesforce objects..."
  DESCRIBE_ARGS=()
  [[ -n "$TARGET_ORG" ]] && DESCRIBE_ARGS+=("--org" "$TARGET_ORG")
  
  if "$SCRIPT_DIR/describe-objects.sh" "${DESCRIBE_ARGS[@]}" "${OBJECTS[@]}"; then
    echo "Object description completed successfully."
  else
    echo "Warning: Object description encountered issues." >&2
    # Continue to the next step
  fi
  echo "--------------------------------------------------------"
fi

# Query Objects
if [[ "$SKIP_QUERY" -ne 1 ]]; then
  echo "Querying Salesforce objects..."
  QUERY_ARGS=()
  [[ -n "$TARGET_ORG" ]] && QUERY_ARGS+=("--org" "$TARGET_ORG")
  QUERY_ARGS+=("--limit" "$QUERY_LIMIT")
  QUERY_ARGS+=("--format" "csv") # Force CSV for SQLite import
  
  if "$SCRIPT_DIR/query-objects.sh" "${QUERY_ARGS[@]}" "${OBJECTS[@]}"; then
    echo "Query operation completed successfully."
  else
    echo "Error: Query operation failed." >&2
    exit 1
  fi
  echo "--------------------------------------------------------"
fi

# Import to SQLite
if [[ "$SKIP_IMPORT" -ne 1 ]]; then
  echo "Importing data to SQLite..."
  
  # For each object, find the most recent CSV file and import it
  for object in "${OBJECTS[@]}"; do
    object_lower=$(echo "$object" | tr '[:upper:]' '[:lower:]')
    # Find the most recent CSV file for this object
    csv_file=$(find "$OUTPUT_DIR" -name "${object_lower}_query_*.csv" -type f -print0 | xargs -0 ls -t | head -n 1)
    
    if [[ -n "$csv_file" ]]; then
      echo "Importing $object from $csv_file..."
      if "$SCRIPT_DIR/setup_sfdc_replica.sh" -d "$DB_FILE" import-csv "$object" "$csv_file"; then
        echo "Successfully imported $object."
      else
        echo "Error: Failed to import $object data." >&2
        # Continue with other objects
      fi
    else
      echo "Warning: No CSV file found for $object. Skipping import." >&2
    fi
  done
  echo "--------------------------------------------------------"
  
  # Optimize database if requested
  if [[ "$OPTIMIZE_DB" -eq 1 ]]; then
    echo "Optimizing SQLite database..."
    if "$SCRIPT_DIR/setup_sfdc_replica.sh" -d "$DB_FILE" optimize; then
      echo "Database optimization completed."
    else
      echo "Warning: Database optimization failed." >&2
    fi
    echo "--------------------------------------------------------"
  fi
fi

echo "Salesforce to SQLite workflow completed."
echo "Results available in: $OUTPUT_DIR"
echo "SQLite database: $DB_FILE"
echo "=========================================================" 