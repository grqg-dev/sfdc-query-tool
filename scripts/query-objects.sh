#!/bin/bash
set -eo pipefail

# Script to query data from Salesforce objects

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sfdc-utils.sh"

# --- Initialization ---
check_sf_cli
check_jq # Needed for clean_json

# --- Configuration & Variables ---
# Default field list for each object - consider moving to a config file
DEFAULT_FIELDS=(
  "User:Id,Name,Username,Email,IsActive,ProfileId,Profile.Name"
  "Opportunity:Id,Name,StageName,Amount,CloseDate,AccountId,CreatedDate"
  "Account:Id,Name,Type,Industry,BillingCity,BillingCountry,CreatedDate"
  "Contact:Id,FirstName,LastName,Email,Phone,AccountId,CreatedDate"
  "Lead:Id,FirstName,LastName,Email,Company,Status,CreatedDate"
)

# Default limit and format - use env vars or script defaults
DEFAULT_LIMIT=100
DEFAULT_FORMAT="json"
LIMIT=${QUERY_LIMIT:-$DEFAULT_LIMIT}
OUTPUT_FORMAT=${OUTPUT_FORMAT:-$DEFAULT_FORMAT}
TARGET_ORG=${TARGET_ORG:-}
OBJECTS=()
OUTPUT_DIR="$SCRIPT_DIR/../output"

# --- Functions ---
show_query_usage() {
  echo "Usage: $(basename "$0") [options] [object1 object2 ...]"
  echo ""
  echo "Queries specified Salesforce objects for data."
  echo "If no objects are specified, uses defaults: User, Opportunity, Account, Contact, Lead."
  echo ""
  echo "Options:"
  echo "  -h, --help           Show this help message"
  echo "  -o, --org ORG        Target Salesforce org alias or username"
  echo "  -l, --limit LIMIT    Maximum number of records to return (default: ${DEFAULT_LIMIT})"
  echo "  -f, --format FORMAT  Output format: json or csv (default: ${DEFAULT_FORMAT})"
  echo ""
  echo "Output:"
  echo "  Generates JSON or CSV query result files in the '../output' directory."
  echo ""
  echo "Environment Variables:"
  echo "  TARGET_ORG           Overrides the target org specified with -o."
  echo "  QUERY_LIMIT          Overrides the default query limit."
  echo "  OUTPUT_FORMAT        Overrides the default output format."
}

# Get fields for an object
get_fields_for_object() {
  local object_name="$1"
  local fields_found=0

  # Find the default fields for this object
  for field_spec in "${DEFAULT_FIELDS[@]}"; do
    # Split the spec into object name and fields
    IFS=":" read -r obj fields <<< "$field_spec"

    if [[ "$obj" == "$object_name" ]]; then
      echo "$fields"
      fields_found=1
      break
    fi
  done

  # If no specific fields found, return basic fields as fallback
  if [[ "$fields_found" -eq 0 ]]; then
      echo "Warning: No default fields configured for '$object_name'. Using fallback: Id, Name, CreatedDate" >&2
      echo "Id,Name,CreatedDate"
  fi
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_query_usage
      exit 0
      ;;
    -o|--org)
      TARGET_ORG="$2"
      shift 2
      ;;
    -l|--limit)
      # Basic validation: ensure limit is a positive integer
      if [[ "$2" =~ ^[1-9][0-9]*$ ]]; then
          LIMIT="$2"
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
          OUTPUT_FORMAT="$format_lower"
      else
          echo "Error: Invalid format '$2'. Must be 'json' or 'csv'." >&2
          exit 1
      fi
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      show_query_usage
      exit 1
      ;;
    *)
      # If it's not an option, it's an object name
      OBJECTS+=("$1")
      shift
      ;;
  esac
done

# Use default TARGET_ORG from utils if not overridden by args or env var
source "$SCRIPT_DIR/sfdc-utils.sh" # Re-source to get the default if needed
if [[ -z "$TARGET_ORG" ]]; then
    : # Default from utils will be used by sf commands
else
    export TARGET_ORG # Export if set by arg
fi

# Default set of objects if none specified
if [[ ${#OBJECTS[@]} -eq 0 ]]; then
  OBJECTS=("User" "Opportunity" "Account" "Contact" "Lead")
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# --- Main Logic ---
echo "Starting object query process..."

# Process each object
for object in "${OBJECTS[@]}"; do
  echo "Querying $object..."

  # Validate object
  if ! validate_object "$object"; then
    echo "Skipping invalid object: $object"
    continue
  fi

  # Get fields to query for this object
  fields=$(get_fields_for_object "$object")
  if [[ -z "$fields" ]]; then
      echo "Error: Could not determine fields for $object. Skipping." >&2
      continue
  fi

  # Build query
  query="SELECT $fields FROM $object LIMIT $LIMIT"
  echo "Query: $query"

  # Generate output filename (lowercase object name)
  object_lower=$(echo "$object" | tr '[:upper:]' '[:lower:]')
  output_file="$OUTPUT_DIR/$(format_filename "${object_lower}" "query").$OUTPUT_FORMAT"

  # Execute query
  echo "Saving $OUTPUT_FORMAT results to $output_file"
  query_cmd=("sf" "data" "query" "--query" "$query" "--target-org" "$TARGET_ORG" "--result-format" "$OUTPUT_FORMAT")

  # Only pipe through clean_json if format is json
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
      if ! "${query_cmd[@]}" --json | clean_json > "$output_file"; then
          echo "Error executing query for $object. Skipping."
          rm -f "$output_file" # Clean up partial file
      else
          echo "Completed $object query (JSON)"
      fi
  else # CSV format
      if ! "${query_cmd[@]}" > "$output_file"; then
          echo "Error executing query for $object. Skipping."
          rm -f "$output_file" # Clean up partial file
      else
          echo "Completed $object query (CSV)"
      fi
  fi

  echo "----------------------------"
done

echo "All object queries completed."
echo "Output files saved to $OUTPUT_DIR" 