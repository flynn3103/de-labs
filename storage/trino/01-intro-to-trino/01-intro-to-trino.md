# Lab 1: Introduction to Trino

## Theory: What is Trino?

Trino (formerly known as PrestoSQL) is a distributed SQL query engine designed to query large data sets distributed across multiple heterogeneous data sources. It's built for high-performance, interactive analytics and can process petabytes of data.

Unlike traditional databases, Trino doesn't store data itself but connects to various data sources through its connector architecture. This allows you to query data where it resides without complex ETL processes.

### Key Characteristics of Trino

1. **Distributed Processing**: Trino processes queries in parallel across a cluster of machines, enabling fast performance on large datasets.

2. **In-Memory Processing**: Trino primarily operates in memory, with the ability to spill to disk when needed, optimizing for speed.

3. **Federation**: Trino can query multiple data sources simultaneously and even join data across different sources (e.g., joining a MySQL table with Hive data).

4. **ANSI SQL Compatibility**: Trino supports standard SQL syntax, making it accessible to analysts and data engineers without learning new query languages.

5. **Separation of Storage and Compute**: Trino decouples compute resources from storage, allowing independent scaling of each component.

## Detailed Architecture Overview

Trino follows a coordinator-worker architecture:

### Coordinator
The coordinator is the brain of the Trino cluster, responsible for:
- Receiving and parsing SQL queries
- Creating and optimizing query execution plans
- Distributing query execution across workers
- Managing worker nodes (tracking their state, load, etc.)
- Returning results to clients

In production deployments, you might have multiple coordinators for high availability, with a discovery service for coordination.

### Workers
Workers are the compute nodes that execute tasks assigned by the coordinator:
- Process data in parallel
- Exchange intermediate results with other workers
- Execute joins, aggregations, and other operations
- Communicate with external data sources through connectors

### Connectors
Connectors are Trino's interface to external data sources:
- Each connector implements APIs to translate between Trino and the external system
- Connectors handle schema discovery, data reading, and sometimes writes
- Each connector appears as a catalog in Trino's namespace

Common connectors include:
- Hive (for data lakes in HDFS or S3)
- MySQL, PostgreSQL, SQL Server (for RDBMS)
- Kafka (for streaming data)
- MongoDB, Cassandra (for NoSQL stores)
- Elasticsearch (for search indices)

## Theory: Internal Architecture Components

Beyond the high-level architecture, Trino consists of several key internal components:

### 1. SQL Parser and Analyzer

The SQL processing pipeline starts with:
- **Lexical Analysis**: Converts SQL text into tokens
- **Syntax Analysis**: Builds an abstract syntax tree (AST)
- **Semantic Analysis**: Resolves names, validates types, and checks permissions
- **Binding**: Links identifiers to actual catalog/schema/table/column references

### 2. Query Planning and Optimization

Once parsed, the query goes through:
- **Logical Planning**: Creates a tree of logical operations
- **Cost-Based Optimization**: Estimates execution costs and rearranges operations
- **Rule-Based Optimization**: Applies transformation rules like predicate pushdown
- **Join Reordering**: Finds optimal join order based on statistics
- **Predicate Inference**: Derives additional filter conditions

Trino's optimizer includes sophisticated techniques:
- **Statistics Collection**: Gathers table and column statistics for better planning
- **Dynamic Filtering**: Creates filters on-the-fly based on join keys
- **Join Distribution Selection**: Chooses between broadcast, partitioned, and other join strategies

### 3. Distributed Execution Model

Trino's execution model has several components:
- **Stages**: Units of work that can execute in parallel
- **Tasks**: Stage instances running on specific workers
- **Splits**: Data partitions processed by tasks
- **Drivers**: Processing threads within a task
- **Operators**: Building blocks that implement SQL operations

Data flows through a pipeline of operators that handle:
- **Scanning**: Reading data from source systems
- **Filtering**: Eliminating rows that don't match conditions
- **Projection**: Selecting and computing columns
- **Aggregation**: Grouping and computing aggregates
- **Joining**: Combining data from multiple tables
- **Sorting**: Ordering result sets
- **Limiting**: Restricting result size

### 4. Memory Management

Trino has a sophisticated memory management system:
- **Memory Pools**: Reserves memory for different operations
- **Memory Tracking**: Accounts for memory usage by query, task, and operator
- **Spill to Disk**: Moves data to disk when memory pressure is high
- **Memory-Based Admission Control**: Rejects or queues queries when memory is tight

Memory is managed at multiple levels:
- **Node Level**: Overall memory available to Trino on each machine
- **Query Level**: Memory allocated to a specific query
- **Task Level**: Memory used by specific tasks within a query

### Query Execution Model

When a query is submitted to Trino:

1. **SQL Parsing**: The coordinator parses the SQL statement
2. **Planning**: The query is converted to a logical plan, then optimized into a distributed physical plan
3. **Scheduling**: The plan is split into stages and tasks, then distributed to workers
4. **Execution**: Workers execute their tasks in parallel, exchanging data when needed
5. **Result Collection**: The coordinator collects and potentially processes final results
6. **Client Response**: Results are streamed back to the client

## Theory: Data Locality and Exchange

A key concept in Trino's performance is how it handles data locality and exchange:

### Data Locality

Trino optimizes performance by considering data location:
- **Local Processing**: Tries to process data on the node where it resides
- **Locality Awareness**: Can be network-aware in multi-rack environments
- **Split Assignment**: Assigns data splits to workers based on locality
- **Connector Pushdown**: Pushes operations to source systems when beneficial

### Data Exchange

During query execution, Trino workers exchange data through several patterns:
- **Broadcast**: Sends complete datasets to all participating nodes (for small tables)
- **Hash Distribution**: Partitions data based on join or grouping keys
- **Range Distribution**: Splits data based on value ranges (for ordered operations)
- **Gather**: Collects results from multiple nodes to a single node

Exchange operations are often the most expensive part of distributed queries, so Trino's optimizer works to minimize them.

## Trino vs. Other Technologies

### Trino vs. Hadoop/MapReduce
- Trino is designed for interactive queries (seconds to minutes), while MapReduce is better for batch processing (minutes to hours)
- Trino operates primarily in memory, while MapReduce uses disk heavily
- Trino has a more user-friendly SQL interface compared to MapReduce's programming model

### Trino vs. Apache Spark
- Trino is specialized for SQL analytics, while Spark is a general-purpose processing engine
- Trino typically has lower query latency for SQL operations
- Spark has broader support for machine learning and streaming
- Spark maintains its own memory management, while Trino relies on the JVM

### Trino vs. Traditional Data Warehouses
- Trino queries data in-place, while warehouses typically ingest data first
- Trino separates storage and compute, allowing for more flexible scaling
- Trino can federate queries across diverse sources, while warehouses usually operate on internal storage
- Traditional warehouses often provide better performance for heavily optimized workloads

## Theory: Query Processing Optimizations

Trino implements several advanced optimizations:

### 1. Predicate Pushdown

- **Purpose**: Move filter conditions closer to data sources
- **Benefit**: Reduces data read and transferred
- **Example**: Pushing WHERE clauses into connectors like Hive or RDBMS

### 2. Projection Pushdown

- **Purpose**: Only read columns needed for the query
- **Benefit**: Reduces I/O and memory requirements
- **Example**: Scanning only required columns from Parquet files

### 3. Dynamic Filtering

- **Purpose**: Create runtime filters based on joined data
- **Benefit**: Dramatically reduces rows processed in joins
- **Example**: In "SELECT * FROM orders JOIN small_table WHERE small_table.id = 5", filter orders before joining

### 4. Adaptive Query Execution

- **Purpose**: Adjust query plans during execution
- **Benefit**: Responds to data characteristics discovered at runtime
- **Example**: Changing join strategy based on actual table sizes

### 5. Partition Pruning

- **Purpose**: Skip reading irrelevant partitions
- **Benefit**: Avoids scanning unnecessary data
- **Example**: Only reading January partitions for a query filtered to January

## Use Cases

Trino excels in these common scenarios:

### Interactive Analytics
- Ad-hoc exploration of large datasets
- Business intelligence dashboards requiring low-latency queries
- Self-service analytics platforms

### Data Lake Queries
- Querying data stored in S3, HDFS, or other distributed file systems
- Analyzing data in various formats (Parquet, ORC, Avro, JSON, etc.)
- Providing SQL access to semi-structured data

### Federated Queries
- Joining data across multiple databases or storage systems
- Creating unified views across disparate data sources
- Migrating between data platforms incrementally

### ETL and Data Transformation
- Transforming data using SQL before loading into analytics systems
- Performing complex data joins and aggregations
- Creating derived datasets from raw data

## Theory: Connectors Deep Dive

Connectors are the foundation of Trino's flexibility:

### Connector Architecture

Each connector implements several interfaces:
- **Metadata Provider**: Exposes schema information
- **Data Provider**: Retrieves actual data
- **Transaction Manager**: Handles transactions (for writable connectors)
- **Statistics Provider**: Provides data statistics for query optimization

### Common Connectors

1. **Hive Connector**:
   - Purpose: Access data lakes in S3, HDFS, etc.
   - Formats: Parquet, ORC, Avro, Text, JSON
   - Features: Partition pruning, schema evolution, predicate pushdown

2. **RDBMS Connectors** (MySQL, PostgreSQL, etc.):
   - Purpose: Query relational databases
   - Features: Connection pooling, predicate pushdown, data type mapping
   - Limitations: Performance depends on source database

3. **Memory Connector**:
   - Purpose: Temporary in-memory tables
   - Features: Fast for small datasets, useful for testing
   - Limitations: Size constrained by memory, data lost on restart

4. **Kafka Connector**:
   - Purpose: Query streaming data
   - Features: Topic subscription, schema registry integration
   - Use Cases: Real-time analytics, streaming ETL

5. **Iceberg Connector**:
   - Purpose: Support for Iceberg table format
   - Features: ACID transactions, schema evolution, time travel
   - Benefits: Combines data lake flexibility with RDBMS features

## Next Steps

In the following labs, you'll learn how to:
1. Set up a basic Trino environment
2. Connect to different data sources
3. Deploy Trino in production environments
4. Implement security and governance
5. Apply monitoring and troubleshooting techniques 