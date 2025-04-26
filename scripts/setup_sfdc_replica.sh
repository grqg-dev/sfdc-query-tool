#!/bin/bash
# Script to set up and manage a SQLite replica of Salesforce data from CSV files

set -eo pipefail # Exit on error, unset var, pipe fail

# --- Configuration ---
DB_FILE="sfdc-replica.db"
# TARGET_ORG is not directly used in this version but kept for context consistency
TARGET_ORG="${SFDC_TARGET_ORG:-PROD}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
UTILS_SCRIPT="$SCRIPT_DIR/sfdc-utils.sh"

# --- Source Utilities ---
if [ -f "$UTILS_SCRIPT" ]; then
    # shellcheck source=scripts/sfdc-utils.sh
    source "$UTILS_SCRIPT"
else
    echo "Error: Utility script '$UTILS_SCRIPT' not found." >&2
    exit 1
fi

# --- Functions ---

# Function to show usage instructions
show_usage() {
    echo "Usage: $0 [-d <DB_FILE>] <COMMAND> [ARGS...]"
    echo "Commands:"
    echo "  init                       Initialize the database file."
    echo "  import-csv <SObject> <CSV_FILE>  Imports data from CSV, creates table, and indexes."
    # echo "  index <SObject>          (Re)Create recommended indexes for an existing table." # Future enhancement?
    echo "  optimize                   Run PRAGMA optimize and VACUUM on the database."
    echo "Options:"
    # echo "  -o TARGET_ORG  Specify the Salesforce target org alias (not used for import)."
    echo "  -d DB_FILE     Specify the SQLite database file path (defaults to ./sfdc-replica.db)."
    echo "  -h             Show this help message."
}

# Initialize the database file
init_db() {
    if [ -e "$DB_FILE" ]; then
        log_info "Database file '$DB_FILE' already exists."
    else
        log_info "Creating SQLite database file: $DB_FILE"
        sqlite3 "$DB_FILE" ".databases" # Creates the file if it doesn't exist
        log_success "Database file '$DB_FILE' created."
    fi
}

# SQLite doesn't have robust type checking, so TEXT is generally safest for import.
# We might enhance this later to detect basic types if needed.
map_sf_type_to_sqlite() {
    # For now, map everything to TEXT
    echo "TEXT"
}

# Create recommended indexes for a table based on common SFDC patterns
index_table() {
    local sobject="$1"
    if [ -z "$sobject" ]; then
        log_error "SObject name required for indexing."
        return 1 # Don't exit script, just report error from calling function
    fi
    log_info "Generating indexes for table: $sobject in $DB_FILE"

    local table_info
    table_info=$(sqlite3 "$DB_FILE" "PRAGMA table_info('$sobject');")

    if [ -z "$table_info" ]; then
        log_error "Could not get table info for '$sobject'. Does the table exist?"
        return 1
    fi

    local index_sql=""
    local has_id_pk=0

    # Read columns and primary key info into arrays using while read
    declare -a columns=()
    declare -a pks=()
    while IFS='|' read -r _ col _ _ _ pk _; do
        columns+=("$col")
        pks+=("$pk")
    done < <(echo "$table_info")

    for i in "${!columns[@]}"; do
        local col_name="${columns[$i]}"
        local is_pk="${pks[$i]}"

        # Skip the primary key column for explicit indexing
        # SQLite automatically indexes the PRIMARY KEY
        if [[ "$is_pk" -ne 0 ]]; then
            if [[ "$col_name" == "Id" ]]; then # Check if the PK is indeed 'Id'
                has_id_pk=1
            fi
            continue
        fi

        # Index every other column
        local index_name="idx_$(echo "$sobject" | tr '[:upper:]' '[:lower:]')_$(echo "$col_name" | tr '[:upper:]' '[:lower:]')" # Lowercase index name
        index_sql+="CREATE INDEX IF NOT EXISTS \"$index_name\" ON \"$sobject\"(\"$col_name\");"
        log_info " -> Planning index '$index_name' on column '$col_name'"
    done

    if [[ "$has_id_pk" -eq 0 ]]; then
       log_warning "Table '$sobject' does not seem to have 'Id' as a primary key. Indexing might be less effective."
    fi


    if [ -n "$index_sql" ]; then
        log_info "Applying indexes for '$sobject'..."
        sqlite3 "$DB_FILE" "$index_sql" || {
            log_error "Failed to apply indexes for '$sobject'."
            return 1
        }
        log_success "Indexes applied for '$sobject'."
    else
        log_info "No standard indexes identified for '$sobject'."
    fi
    return 0
}

# Import data from CSV, create table, and index
import_csv_data() {
    local sobject="$1"
    local csv_file="$2"

    if [ -z "$sobject" ]; then
        log_error "SObject name required for 'import-csv' command."
        show_usage
        exit 1
    fi
     if [ -z "$csv_file" ]; then
        log_error "CSV file path required for 'import-csv' command."
        show_usage
        exit 1
    fi
    if [ ! -f "$csv_file" ]; then
        log_error "CSV file not found: '$csv_file'"
        exit 1
    fi

    log_info "Starting import for SObject '$sobject' from file '$csv_file' into '$DB_FILE'"

    # --- 1. Read Header and Prepare CREATE TABLE ---
    local header
    header=$(head -n 1 "$csv_file")
    if [ -z "$header" ]; then
        log_error "CSV file '$csv_file' appears to be empty or has no header."
        exit 1
    fi

    local create_sql="CREATE TABLE IF NOT EXISTS "$sobject" ("
    local fields_list=""
    local has_id=0
    local col_defs=()

    # Save original IFS, set to comma, restore later
    local IFS=','
    read -r -a fields <<< "$header"
    local ORIGINAL_IFS="$IFS"
    IFS="$ORIGINAL_IFS"

    if [ ${#fields[@]} -eq 0 ]; then
         log_error "Could not parse header fields from '$csv_file'. Is it comma-separated?"
         exit 1
    fi

    for field in "${fields[@]}"; do
        # Trim potential whitespace and quotes (basic trimming)
        field=$(echo "$field" | sed -e 's/^[[:space:]"]*//' -e 's/[[:space:]"]*$//')
        if [ -z "$field" ]; then
            log_warning "Skipping empty header column."
            continue
        fi
        if [[ "$fields_list" != "" ]]; then
             fields_list+=","
        fi
         fields_list+=""$field"" # Quote field names for safety

        local sqlite_type
        sqlite_type=$(map_sf_type_to_sqlite "$field") # Currently always TEXT

        if [[ "$field" == "Id" ]]; then
            col_defs+=(""$field" $sqlite_type PRIMARY KEY")
            has_id=1
        else
            col_defs+=(""$field" $sqlite_type")
        fi
    done

    if [[ "$has_id" -eq 0 ]]; then
        log_warning "CSV header does not contain an 'Id' column. Creating table without a primary key."
    fi

    create_sql+=$(printf ", %s" "${col_defs[@]}")
    create_sql="${create_sql/, /}" # Remove leading comma space
    create_sql+=");"

    log_info "Generated Schema: $create_sql"

    # --- 2. Create Table ---
    log_info "Creating table '$sobject' if it doesn't exist..."
    sqlite3 "$DB_FILE" "$create_sql" || {
        log_error "Failed to create table '$sobject' in '$DB_FILE'."
        exit 1
    }
    log_success "Table '$sobject' created or already exists."

    # --- 3. Import Data ---
    log_info "Importing data from '$csv_file' into table '$sobject'..."
    # Using temporary import table to handle potential existing data or conflicts if needed later?
    # For now, simple import. Assumes table is empty or we want to append.
    # Consider adding a --replace option later.
    sqlite3 "$DB_FILE" << EOF || { log_error "SQLite import command failed."; exit 1; }
.mode csv
.separator ,
BEGIN TRANSACTION;
.import --skip 1 '$csv_file' $sobject
COMMIT;
EOF
    log_success "Data imported into '$sobject'."

    # --- 4. Index Table ---
    index_table "$sobject" || {
        # index_table logs its own errors, just note failure
        log_warning "Indexing step for '$sobject' encountered issues."
        # Decide if this should be a fatal error? For now, continue.
    }

    log_success "Successfully processed '$sobject' from '$csv_file'."
}


# Optimize the database
optimize_db() {
    log_info "Optimizing database: $DB_FILE"
    sqlite3 "$DB_FILE" "PRAGMA optimize; VACUUM;" || {
        log_error "Database optimization failed."
        exit 1
    }
    log_success "Database optimized."
}


# --- Argument Parsing ---
COMMAND=""
SOBJECT_ARG=""
CSV_FILE_ARG=""

while getopts ":ho:d:" opt; do
  case $opt in
    h) show_usage; exit 0 ;;
    # o) TARGET_ORG="$OPTARG" ;; # Keep for potential future use, but not primary now
    d) DB_FILE="$OPTARG" ;;
    \?) log_error "Invalid option: -$OPTARG"; show_usage; exit 1 ;;
    :) log_error "Option -$OPTARG requires an argument."; show_usage; exit 1 ;;
  esac
done
shift $((OPTIND-1))

COMMAND="$1"
if [ -z "$COMMAND" ]; then
    log_error "No command specified."
    show_usage
    exit 1
fi
shift # Remove command from arguments

# --- Main Logic ---
check_sqlite3 # Check prerequisite

log_info "Starting SFDC Replica Setup script..."
log_info "Using Database: $DB_FILE"
# log_info "Using Target Org: $TARGET_ORG" # Less relevant now

case "$COMMAND" in
    init)
        init_db
        ;;
    import-csv)
        SOBJECT_ARG="$1"
        CSV_FILE_ARG="$2"
        import_csv_data "$SOBJECT_ARG" "$CSV_FILE_ARG"
        ;;
    # index) # Future?
    #     SOBJECT_ARG="$1"
    #     index_table "$SOBJECT_ARG"
    #     ;;
    optimize)
        optimize_db
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac

log_success "Script finished successfully."
exit 0 