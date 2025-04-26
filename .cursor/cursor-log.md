# Cursor Work Log

## Initial SQLite3 SFDC Replica Guide Creation
- Created SQLite3 SFDC Replica rule (03-sqlite3-sfdc-replica.mdc) with:
  - Database setup instructions
  - Table creation patterns matching Salesforce objects
  - Comprehensive indexing strategy for all query-relevant columns
  - Data import patterns using transactions and prepared statements
  - Performance considerations and maintenance tips

## Bash Import Examples Update
- Updated SQLite3 SFDC Replica rule with bash import examples instead of JavaScript:
  - Added sf CLI command to export data as CSV
  - Used SQLite3 shell commands for CSV import with transactions
  - Added example for complex imports using SQL scripts 

# Salesforce Query Tools Development Log

## Project: SFDC Query Tool

### Work Completed:
- Created `describe-objects.sh` script to get field information for specified Salesforce objects
- Created `query-objects.sh` script to query data from specified Salesforce objects
- Created `sfdc-utils.sh` with shared utility functions
- Set up scripts to work with the following objects: User, Opportunity, Account, Contact, Lead
- Configured scripts to use environment variable for target org with PROD as default

### Next Steps:
- Enhance scripts to dynamically add sObjects
- Add data export capabilities 
- Implement filtering options 

# Log of SFDC Query Tool Enhancements (YYYY-MM-DD)

## Summary

Reviewed the bash scripts (`sfdc-utils.sh`, `describe-objects.sh`, `query-objects.sh`, `sfdc-data-tool.sh`) and applied several enhancements focused on robustness, usability, and maintainability.

## Changes Made

1.  **Error Handling (`set -eo pipefail`)**: Added `set -eo pipefail` to the top of all scripts to ensure they exit immediately on errors, unset variables, or pipe failures.
2.  **Prerequisite Checks**: 
    *   Added `check_sf_cli` function to `sfdc-utils.sh` and called it early in all executable scripts (`describe-objects.sh`, `query-objects.sh`, `sfdc-data-tool.sh`).
    *   Added `check_jq` function to `sfdc-utils.sh` to check for `jq` installation once. Modified `clean_json` to use this check, reducing redundant warnings. Called `check_jq` in scripts that use `clean_json` (`describe-objects.sh`, `query-objects.sh`).
3.  **Argument Parsing & Validation**:
    *   Replaced generic `show_usage` in `sfdc-utils.sh` with specific usage functions (`show_describe_usage`, `show_query_usage`, `show_main_usage`) in each respective script.
    *   Added handling for unknown command-line options in all executable scripts.
    *   Added validation for `--limit` (must be positive integer) and `--format` (must be `json` or `csv`) arguments in `query-objects.sh` and `sfdc-data-tool.sh`.
    *   Added conflict check between `--describe` and `--query` flags in `sfdc-data-tool.sh`.
4.  **Script Execution & Flow**:
    *   Modified `sfdc-data-tool.sh` to pass common arguments (`--org`) and query-specific arguments (`--limit`, `--format`) explicitly to sub-scripts using arrays, rather than relying on environment variable exports.
    *   Added checks for the exit status of `sf` commands and sub-script calls (`describe-objects.sh`, `query-objects.sh`).
    *   Added error messages and cleanup (e.g., removing partially created files) on failure.
5.  **Code Clarity & Consistency**:
    *   Added comments to structure scripts (Initialization, Variables, Functions, Argument Parsing, Main Logic).
    *   Improved log/echo messages for better user feedback.
    *   Standardized output filenames to use lowercase object names (`describe-objects.sh`, `query-objects.sh`).
    *   Refined `TARGET_ORG` handling to prioritize command-line arguments over environment variables over script defaults.
    *   Improved `get_fields_for_object` in `query-objects.sh` to provide a warning if default fields aren't found.

## Next Steps / Potential Future Enhancements

*   Consider removing the default `TARGET_ORG="PROD"` from `sfdc-utils.sh` or making it more configurable.
*   Evaluate the efficiency of `validate_object` - could object validation be done more efficiently?
*   Move the `DEFAULT_FIELDS` array in `query-objects.sh` to a separate configuration file.
*   Add more comprehensive unit/integration tests.
*   Implement more sophisticated logging (e.g., log levels, log file output).

## SQLite Replica Script Initialization
- Created initial `scripts/setup_sfdc_replica.sh` based on rule `03-sqlite3-sfdc-replica.mdc`.
- Includes structure for initializing DB, creating tables, indexing, importing data, and optimizing.
- Added command-line arguments for target org and DB file.
- Integrated with `sfdc-utils.sh` and included placeholders (`TODO`) for integrating `describe-objects.sh` and `query-objects.sh` (or direct `sf` calls) for schema generation and data fetching.
- Added a TODO for `check_sqlite3` prerequisite check in `sfdc-utils.sh`.

## Refactor SQLite Replica Script for CSV Import
- Modified `scripts/setup_sfdc_replica.sh` to primarily handle CSV imports.
- Removed direct Salesforce interaction commands (`create`, `index`, `import`).
- Added new command `import-csv <SObject> <CSV_FILE>`.
- `import-csv` function now:
  - Reads CSV header to define table schema (all `TEXT`, `Id` as PK if exists).
  - Creates the table (`CREATE TABLE IF NOT EXISTS`).
  - Imports data using SQLite `.import` command.
  - Calls `index_table` after import.
- `index_table` function now:
  - Uses `PRAGMA table_info` to get columns.
  - Creates indexes on common fields (`Name`, `LastModifiedDate`, `CreatedDate`) and potential foreign keys (fields ending in `Id`).
- Updated argument parsing and usage instructions.
- Ensured `check_sqlite3` (already present in `sfdc-utils.sh`) is called.

## Simplify Indexing Logic
- Updated `index_table` function in `scripts/setup_sfdc_replica.sh`.
- Changed logic to create an index for *all* columns obtained via `PRAGMA table_info`, except for the column designated as the primary key (which SQLite indexes automatically).
- Added quoting to identifiers in `CREATE INDEX` statement for robustness. 

# Salesforce Query Tool Analysis and Enhancement

## Project Overview
The Salesforce Query Tool is a collection of scripts for:
1. Describing Salesforce objects (schema/fields)
2. Querying Salesforce object data
3. Creating a SQLite replica of Salesforce data

## Initial State Analysis

### Scripts Inventory
- `sfdc-data-tool.sh` - Main script orchestrating describe/query operations
- `describe-objects.sh` - Script for describing Salesforce object schemas
- `query-objects.sh` - Script for querying Salesforce object data
- `sfdc-utils.sh` - Shared utility functions
- `setup_sfdc_replica.sh` - Script for setting up SQLite database with Salesforce data

### Identified Issues
- Missing output directory
- No full end-to-end integration between query and database setup
- Missing logging functions in utils script
- No streamlined workflow from Salesforce to SQLite

## Implemented Improvements

1. **Created Output Directory**
   - Created `output` directory to store query results and database files

2. **Added Missing Utility Functions**
   - Added logging functions to `sfdc-utils.sh`:
     - `log_info`
     - `log_success`
     - `log_warning`
     - `log_error`

3. **Created Integrated Workflow Script**
   - Created `sfdc-to-sqlite.sh` which:
     - Combines all operations (describe, query, import) in one script
     - Provides flexible options to skip individual steps
     - Automatically finds and imports the latest query results
     - Handles database initialization and optimization

4. **Updated Documentation**
   - Updated README.md with:
     - New script information
     - Complete workflow documentation
     - SQLite prerequisite
     - Examples for the new integrated workflow

## Final State
The project now has a complete end-to-end workflow to query Salesforce objects and create a SQLite replica with a single command, making it much more user-friendly and efficient.

# Code Review and Cleanup (2023-11-01)

## Project Review Summary
Reviewed the Salesforce Query Tool codebase to identify issues and unused code. The project consists of bash scripts for querying Salesforce data and creating a SQLite replica.

## Identified Issues and Unused Code

1. **Debug Script**
   - `debug-jq.sh` appears to be a debugging utility and is not used in the main workflow

2. **Default Organization Value**
   - `TARGET_ORG=${TARGET_ORG:-"PROD"}` in `sfdc-utils.sh` hardcodes "PROD" as default, which may not be appropriate for all users

3. **Unused Functions**
   - The generic `show_usage()` function in `sfdc-utils.sh` is not used since each script has its own specific usage function

4. **Duplicate Functionality**
   - `sfdc-data-tool.sh` and `sfdc-to-sqlite.sh` have overlapping functionality but the latter is more comprehensive

5. **Error Handling Inconsistencies**
   - Some scripts handle errors more robustly than others

## Suggested Improvements

1. **Remove Unused Code**
   - Delete `debug-jq.sh` as it's not part of the main workflow
   - Remove the unused `show_usage()` function from `sfdc-utils.sh`

2. **Standardize Default Values**
   - Replace hardcoded "PROD" default with empty default that prompts user if not set

3. **Improve Error Handling**
   - Standardize error handling across all scripts
   - Add better error messages and recovery options

4. **Streamline Script Architecture**
   - Consider deprecating `sfdc-data-tool.sh` and directing users to use the more comprehensive `sfdc-to-sqlite.sh`
   - Create a more modular architecture where functions have clearer responsibilities

# Integration Improvements (2023-11-02)

## Enhanced Query-Describe Integration

1. **Modified `query-objects.sh` to use describe results**
   - Updated `get_fields_for_object()` function to first check for field lists generated by the describe script
   - Added logic to prefer fields from `<object>_fields.txt` files in the output directory
   - Limited the number of fields to 50 to avoid hitting SOQL query limits
   - Maintained backward compatibility by falling back to DEFAULT_FIELDS if no describe results are found

2. **Modified `format_filename()` in `sfdc-utils.sh`**
   - Made timestamp parameter optional to enable different filename patterns
   - Describe files don't include timestamps to make them easier to find
   - Query result files still include timestamps to avoid overwriting previous results

3. **Updated file naming consistency**
   - Ensured describe files use `<object>_fields.txt` format
   - Query files continue to use `<object>_query_<timestamp>.<format>` to maintain historical data

# Bug Fixes (2023-11-03)

## Fixed SOQL Query Generation
1. **Fixed debug message output in query-objects.sh**
   - Changed debug message "Using field list from $fields_file" to output to stderr
   - This prevents the message from being included in the SOQL query, which was causing syntax errors
   - Error was: "unexpected token: '..'" when the path to the fields file was being included in the query 

# SFDC Query Tool Development Log

## macOS Bash Compatibility Review
- Fixed compatibility issues to support macOS default Bash 3.2:
  1. Replaced `mapfile` commands in `setup_sfdc_replica.sh` with `while read` loop
  2. Replaced `${var,,}` lowercase syntax with `tr '[:upper:]' '[:lower:]'` for string conversion
  3. Confirmed process substitution syntax `< <(command)` works correctly in current context
  4. Verified no associative arrays (`declare -A`) are used, only indexed arrays (`declare -a`)
  5. Verified all scripts use basic parameter expansion compatible with Bash 3.2

## Fixed macOS Bash Compatibility Issues
- Replaced `mapfile` commands in `setup_sfdc_replica.sh` with `while read` loop
- Replaced `${var,,}` lowercase syntax with `tr '[:upper:]' '[:lower:]'` for macOS compatibility
- Improved compatibility with older Bash versions (macOS default)
- Fixed "bad substitution" error in index creation

## Added Database Clear Flag
- Added `--clear-db` flag to `sfdc-to-sqlite.sh`
- Flag allows users to clear existing database before starting new import
- Maintains backward compatibility with existing behavior 

# Salesforce Query Tool Enhancement Log

## Improved SQLite Data Type Handling for Salesforce Booleans

- Enhanced the `map_sf_type_to_sqlite()` function to map Salesforce boolean fields to SQLite BOOLEAN type
- Added field name pattern detection for boolean fields (starting with "Is" or "Has")
- Modified import process to load field metadata from Salesforce object descriptions
- Implemented type mapping based on Salesforce field metadata when available

This improvement ensures proper data typing in SQLite for better querying and data integrity. 