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

## Potential Improvements
- Adding logging capabilities for better troubleshooting
- Implementing data refresh/sync mechanisms
- Adding data type mapping between Salesforce and SQLite
- Supporting incremental updates rather than full imports 