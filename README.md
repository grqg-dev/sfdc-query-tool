# Salesforce Query Tool

A collection of bash scripts for interacting with Salesforce data via the Salesforce CLI and building a SQLite replica.

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) installed
- [jq](https://stedolan.github.io/jq/download/) installed (for JSON processing)
- [SQLite](https://www.sqlite.org/download.html) installed (for database operations)
- Authenticated with your Salesforce org via `sf login`

## Scripts

The tool consists of the following scripts:

- `scripts/sfdc-to-sqlite.sh` - **RECOMMENDED** Integrated workflow for Salesforce to SQLite
- `scripts/describe-objects.sh` - Get object schema information
- `scripts/query-objects.sh` - Query object data
- `scripts/sfdc-utils.sh` - Shared utility functions
- `scripts/setup_sfdc_replica.sh` - Set up and manage SQLite database
- `scripts/sfdc-data-tool.sh` - (Legacy) Main script to run both describe and query operations

## Complete Workflow

The recommended way to use this tool is with the integrated script:

```bash
# Query Salesforce objects and create SQLite replica
./scripts/sfdc-to-sqlite.sh

# Specify objects to process
./scripts/sfdc-to-sqlite.sh Account Contact

# Specify target org and query limit
./scripts/sfdc-to-sqlite.sh --org DevOrg --limit 500

# Skip certain steps if needed
./scripts/sfdc-to-sqlite.sh --skip-describe

# Use a custom database location
./scripts/sfdc-to-sqlite.sh --db ./my-database.db
```

## Individual Scripts Usage

### Main Data Tool (Legacy)

```bash
# Run both describe and query operations on default objects
./scripts/sfdc-data-tool.sh

# Run only describe operation
./scripts/sfdc-data-tool.sh --describe

# Run only query operation
./scripts/sfdc-data-tool.sh --query

# Specify objects to process
./scripts/sfdc-data-tool.sh Account Contact

# Specify target org and query limit
./scripts/sfdc-data-tool.sh --org DevOrg --limit 50

# Export in CSV format
./scripts/sfdc-data-tool.sh --format csv
```

### Individual Scripts

```bash
# Describe objects
./scripts/describe-objects.sh Account Contact

# Query objects with limit and format options
./scripts/query-objects.sh --limit 200 --format csv Account

# Initialize SQLite database
./scripts/setup_sfdc_replica.sh init

# Import CSV data into SQLite
./scripts/setup_sfdc_replica.sh import-csv Account output/account_query_20230101_120000.csv

# Optimize SQLite database
./scripts/setup_sfdc_replica.sh optimize
```

## Environment Variables

You can also control behavior using environment variables:

```bash
# Set target org
export TARGET_ORG=DevOrg

# Set query limit
export QUERY_LIMIT=50

# Set output format
export OUTPUT_FORMAT=csv

# Run the script
./scripts/sfdc-to-sqlite.sh
```

## Output

All output files are saved to the `output` directory:
- Object descriptions as JSON files
- Field lists as text files
- Query results as JSON or CSV files
- SQLite database file (by default: `output/sfdc-replica.db`)

## Default Objects

The scripts work with the following objects by default:
- User
- Opportunity
- Account
- Contact
- Lead

Additional objects can be specified as command-line arguments. 