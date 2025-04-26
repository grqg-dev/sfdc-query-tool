#!/bin/bash
set -eo pipefail

# Script to describe Salesforce objects and output their field information

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sfdc-utils.sh"

# --- Initialization ---
check_sf_cli
check_jq
# Save the JQ_INSTALLED value before it gets reset
JQ_WAS_INSTALLED=$JQ_INSTALLED

# --- Variables ---
OBJECTS=()
TARGET_ORG=${TARGET_ORG:-}
OUTPUT_DIR="$SCRIPT_DIR/../output"

# --- Functions ---
show_describe_usage() {
  echo "Usage: $(basename "$0") [options] [object1 object2 ...]"
  echo ""
  echo "Describes specified Salesforce objects and outputs field information."
  echo "If no objects are specified, uses defaults: User, Opportunity, Account, Contact, Lead."
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo "  -o, --org ORG     Target Salesforce org alias or username"
  echo ""
  echo "Output:"
  echo "  Generates JSON description and TXT field list files in the '../output' directory."
  echo ""
  echo "Environment Variables:"
  echo "  TARGET_ORG        Overrides the target org specified with -o."
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_describe_usage
      exit 0
      ;;
    -o|--org)
      TARGET_ORG="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      show_describe_usage
      exit 1
      ;;
    *)
      # If it's not an option, it's an object name
      OBJECTS+=("$1")
      shift
      ;;
  esac
done

# Get default TARGET_ORG if needed
if [[ -z "$TARGET_ORG" ]]; then
    # We already have the default from the initial source
    : # No action needed
else
    # If TARGET_ORG was set by arg, export it so sf commands pick it up
    export TARGET_ORG
fi

# Restore the JQ_INSTALLED value
JQ_INSTALLED=$JQ_WAS_INSTALLED

# Default set of objects if none specified
if [ ${#OBJECTS[@]} -eq 0 ]; then
  OBJECTS=("User" "Opportunity" "Account" "Contact" "Lead")
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# --- Main Logic ---
echo "Starting object description process..."

# Process each object
for object in "${OBJECTS[@]}"; do
  echo "Describing $object..."

  # Validate object
  if ! validate_object "$object"; then
    echo "Skipping invalid object: $object"
    continue
  fi

  # Generate filenames
  # Use lower case for filenames
  object_lower=$(echo "$object" | tr '[:upper:]' '[:lower:]')
  json_file="$OUTPUT_DIR/$(format_filename "${object_lower}" "describe").json"
  fields_file="$OUTPUT_DIR/$(format_filename "${object_lower}" "fields").txt"

  # Get full object description
  echo "Saving full description to $json_file"
  # Use --target-org explicitly for clarity
  if ! sf sobject describe --sobject "$object" --target-org "$TARGET_ORG" --json > "$json_file"; then
      echo "Error describing $object. Skipping."
      rm -f "$json_file" # Clean up empty/partial file
      continue
  fi

  # Extract just the field names for easy reference
  # Check if jq is installed before using it
  if [[ "$JQ_INSTALLED" -eq 1 ]]; then
    echo "Extracting field names to $fields_file"
    if ! jq -r '.result.fields[].name' "$json_file" > "$fields_file"; then
        echo "Error extracting fields for $object with jq. Skipping field list generation."
        rm -f "$fields_file"
    fi
  else
      echo "Skipping field list generation for $object (jq not installed)."
  fi

  echo "Completed $object description"
  echo "----------------------------"
done

echo "All object descriptions completed."
echo "Output files saved to $OUTPUT_DIR" 