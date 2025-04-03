# Trino Scripts Collection

This directory contains utility scripts for setting up, testing, and cleaning up Trino and related services.

## Available Scripts

### Hive Setup and Cleanup

- **hive-setup.sh**: Sets up Hive metastore with AWS Glue
  - Creates an AWS Glue database and crawler
  - Copies sample taxi data to an S3 bucket
  - Sets up necessary IAM roles and permissions
  - Creates and runs a Glue crawler to catalog the data
  
  Detailed workflow:
  1. Retrieves configuration from Terraform outputs (region, bucket name)
  2. Creates IAM role "AWSGlueServiceRole-test-hive" with necessary permissions
  3. Creates Glue database "taxi_hive_database"
  4. Configures and creates a Glue crawler pointing to the S3 data location
  5. Runs the crawler to discover table schema from S3 data
  6. Verifies table creation in the Glue catalog

- **hive-cleanup.sh**: Cleans up Hive metastore resources
  - Removes the Glue database and crawler
  - Deletes IAM roles created during setup
  
  Detailed workflow:
  1. Retrieves configuration from Terraform outputs
  2. Stops the crawler if running
  3. Deletes the crawler configuration
  4. Removes the Glue database
  5. Detaches IAM policies from the Glue service role
  6. Deletes the IAM role

### Trino SQL Queries

- **trino_sf10000_tpcds_to_iceberg.sql**: Contains SQL for converting TPC-DS data to Iceberg format
  - Includes a comprehensive set of table creation statements
  - Defines the schema for the TPC-DS benchmark tables
  - Maps data from original format to Iceberg tables
  
  Key operations:
  1. Creates Iceberg tables with appropriate schema for each TPC-DS table
  2. Schema definitions include all columns with proper data types
  3. Includes partitioning information for larger tables
  4. Handles data transformation between formats

- **trino_select_query_iceberg.sql**: Example queries for Iceberg tables
  - Demonstrates various SELECT queries on Iceberg tables
  - Shows sample analytical queries for data analysis
  
  Query examples include:
  1. Basic SELECT operations with filtering conditions
  2. Aggregation queries with GROUP BY clauses
  3. Join operations across multiple tables
  4. Complex analytical queries with window functions

## Detailed Usage Guidelines

### Setting up Hive Metastore

To set up the Hive metastore with sample data:

```bash
./hive-setup.sh
```

This script:
1. References the Terraform state to get the S3 bucket name and region
   - Requires terraform.tfstate to be present in parent directory
   - Extracts values using `terraform output` commands

2. Creates a Glue database named `taxi_hive_database`
   - Uses AWS CLI commands for creation
   - Sets up database with default parameters

3. Sets up IAM roles for Glue
   - Creates service role with trust relationship
   - Attaches AWS managed policy for Glue
   - Adds inline policy for S3 bucket access

4. Creates and runs a crawler to catalog the sample data
   - Configures crawler to scan S3 location
   - Sets appropriate IAM role and database target
   - Starts crawler and monitors progress

5. Verifies successful table creation
   - Lists tables in the Glue database
   - Outputs created table name

### Data Format Conversion Process

The TPC-DS to Iceberg conversion follows this process:

1. Source data is stored in S3 in the original format
2. Glue crawler creates metadata tables in the catalog
3. Trino reads this metadata through the Hive connector
4. Trino creates new Iceberg-format tables
5. Data is inserted into Iceberg tables with appropriate transformations
6. Queries can be executed against the Iceberg tables

### Cleaning up Hive Resources

To clean up Hive metastore resources:

```bash
./hive-cleanup.sh
```

The cleanup process:
1. Stops any running crawlers
2. Deletes the crawler configuration
3. Removes the Glue database and all its tables
4. Detaches IAM policies from the Glue service role
5. Deletes the IAM role

### Running Trino Queries

The SQL files can be executed in the Trino CLI or UI:

```bash
trino -f trino_select_query_iceberg.sql
```

For best performance:
- Ensure Trino cluster has sufficient resources
- Monitor query execution for performance issues
- Adjust the query parameters based on dataset size
- Consider partitioning strategy for large tables

## Prerequisites

- AWS CLI configured with appropriate permissions
  - Required permissions:
    - IAM: CreateRole, DeleteRole, AttachRolePolicy, DetachRolePolicy, PutRolePolicy, DeleteRolePolicy
    - Glue: CreateDatabase, CreateCrawler, StartCrawler, GetCrawler, DeleteCrawler, DeleteDatabase
    - S3: ListBucket, GetObject, PutObject

- Terraform deployment completed (for the Hive setup script)
  - EKS cluster must be running
  - Trino must be deployed on the EKS cluster
  - S3 buckets must be created

- Trino cluster up and running (for SQL query execution)
  - Coordinator and workers properly configured
  - Hive and Iceberg connectors configured
  - Proper access to AWS Glue and S3

## Data Flow Diagram

```
┌───────────────────────────────────────────────────────────────────┐
│ Data Flow                                                         │
│                                                                   │
│ ┌─────────────────┐    ┌─────────────────┐    ┌───────────────┐   │
│ │                 │    │                 │    │               │   │
│ │ S3 Bucket       │───►│ AWS Glue        │───►│ Trino Hive    │   │
│ │ (Raw Data)      │    │ (Metadata)      │    │ Connector     │   │
│ │                 │    │                 │    │               │   │
│ └─────────────────┘    └─────────────────┘    └───────┬───────┘   │
│                                                       │           │
│                                                       │           │
│                                                       ▼           │
│ ┌─────────────────┐    ┌─────────────────┐    ┌───────────────┐   │
│ │                 │    │                 │    │               │   │
│ │ S3 Bucket       │◄───┤ Trino Iceberg   │◄───┤ Trino Query   │   │
│ │ (Iceberg Data)  │    │ Connector       │    │ Engine        │   │
│ │                 │    │                 │    │               │   │
│ └─────────────────┘    └─────────────────┘    └───────────────┘   │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
``` 