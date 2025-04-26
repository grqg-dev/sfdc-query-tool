# Cursor Learnings

## SQLite3 Performance Optimization
- Always create indexes AFTER bulk data import, not before
- Use transactions for bulk operations to dramatically improve performance
- Index all columns used in WHERE clauses and JOIN conditions
- Consider composite indexes for frequently combined query filters
- VACUUM and PRAGMA optimize help maintain database performance over time

# SFDC Query Tool Project Learnings

## Salesforce CLI Usage
- Salesforce CLI (sf) provides robust commands for interacting with Salesforce data
- `sf sobject describe` provides detailed schema information
- `sf data query` executes SOQL queries with options for JSON/CSV output
- jq can be used to clean Salesforce JSON responses and extract specific fields

## Bash Script Organization
- Separating utility functions into a shared file improves maintainability
- Default values can be overridden via environment variables or command-line arguments
- Command-line argument processing in bash benefits from a consistent pattern

## Output Handling
- Timestamped filenames prevent overwriting previous results
- JSON output requires cleaning to remove Salesforce metadata
- Formatting output consistently improves user experience

## Error Handling
- Validating objects before querying prevents runtime errors
- Checking for required dependencies (sf CLI, jq) early improves user experience
- Providing helpful error messages guides the user to correct issues

# Salesforce Query Tool Learnings

## Technical Insights
- Salesforce CLI (`sf`) is used for data operations rather than direct API calls
- Bash scripts can effectively orchestrate complex Salesforce data operations
- CSV format is a robust intermediate format for transferring data from Salesforce to SQLite
- SQLite provides a lightweight, portable database solution for offline data analysis

## Best Practices
- Separating concerns into distinct scripts (describe, query, database operations)
- Using a shared utilities script for common functions
- Handling command-line arguments consistently across scripts
- Validating objects before attempting operations
- Creating appropriate indexes for database performance
- Using transactions for data import operations

## Troubleshooting Insights
- When re-sourcing utility files in bash scripts, be careful about variable values being reset
- Save important flag values before re-sourcing and restore them afterward
- Use debug statements to trace variable values through script execution
- Command-line utilities (jq, sqlite3) need to be properly detected only once

## Potential Improvements
- Adding logging capabilities for better troubleshooting
- Implementing data refresh/sync mechanisms
- Adding data type mapping between Salesforce and SQLite
- Supporting incremental updates rather than full imports

# Bash Script Best Practices

## Functions should be focused and reusable
- Create reusable utility functions for common operations
- Keep functions small and focused on a single responsibility
- Use descriptive function names that indicate what the function does

## Error handling is critical in Bash
- Always include proper error handling and exit codes
- Use `set -e` to exit on error, `set -u` to exit on undefined variables, and `set -o pipefail` to fail on pipe errors
- Redirect error messages to stderr with `>&2`
- Provide clear error messages that suggest how to fix the problem

## Input validation and defaults
- Always validate user input, especially for command-line arguments
- Use reasonable defaults, but allow users to override them
- If a default is critical (like target org), prompt the user rather than using a hardcoded value

## Script documentation
- Document each script with a header comment explaining its purpose
- Include usage examples in documentation
- Document each function with its purpose, parameters, and return value
- Keep documentation in sync with actual functionality

## Cleanup and housekeeping 
- Remove debugging code like `debug-jq.sh` when no longer needed
- Remove obsolete/unused functions and variables
- Never commit credentials or sensitive information
- Keep logs focused and informative

# Salesforce CLI Best Practices

## Org Authentication
- Don't hardcode org names as defaults
- List available orgs when no target org is specified
- Allow the user to select an org via CLI args or environment variables

## Data Handling
- Always consider large data volumes - incorporate limits and pagination
- Include progress indicators for long-running operations
- Support multiple output formats (JSON, CSV) depending on use case
- Include error handling and retries for network operations

## Script Architecture
- Use modular design with clear separation of concerns
- Provide a high-level wrapper script (like sfdc-to-sqlite.sh) for common workflows
- Allow skipping steps for flexibility and debugging

## Shell Script Integration
- Make scripts work well with Unix pipes and redirects
- Return meaningful exit codes
- Support both interactive and non-interactive usage 