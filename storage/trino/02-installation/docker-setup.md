# Lab 2: Setting Up Trino with Docker

This lab guides you through setting up a basic Trino environment using Docker.

## Theory: Docker Deployment Architecture

Docker provides an excellent platform for Trino deployment for several reasons:

1. **Isolation**: Docker containers encapsulate Trino and its dependencies, preventing conflicts with other applications and ensuring consistent environments across development, testing, and production.

2. **Portability**: Containerized Trino can run on any system with Docker, simplifying setup and ensuring consistent behavior across different environments.

3. **Resource Management**: Docker allows precise control over CPU, memory, and network resources allocated to Trino.

4. **Orchestration**: For multi-node setups, container orchestration tools like Docker Compose or Kubernetes can manage Trino clusters effectively.

### Container Resource Allocation Principles

Resource allocation in containerized Trino deployments follows several important principles:

1. **Memory Allocation**:
   - **JVM Heap**: Typically 70-80% of container memory to avoid OOM issues
   - **Container Limits**: Should match the JVM heap plus overhead
   - **Swap Disabled**: Containers should run without swap for predictable performance

2. **CPU Allocation**:
   - **CPU Shares**: Controls the relative CPU priority between containers
   - **CPU Sets**: Can pin Trino processes to specific CPU cores for consistent performance
   - **CPU Limits**: Prevents a single container from consuming all host resources

3. **Storage Considerations**:
   - **Volume Mounts**: Used for configuration, spill directories, and logs
   - **Storage Drivers**: Overlay2 preferred for better performance
   - **I/O Constraints**: Can be configured using cgroups to prevent I/O contention

### Networking Architecture in Docker

Trino containers require specific networking considerations:

1. **Service Discovery**: Containers need to discover and communicate with each other
2. **Port Mapping**: External exposure of coordinator HTTP and HTTPS ports
3. **Network Modes**:
   - Bridge: Default isolated network
   - Host: Direct access to host network (better performance, less isolation)
   - User-defined networks: Preferred for multi-container deployments

### Trino Components in Docker

In a Docker setup, Trino's components are organized as follows:

1. **Trino Container**: Runs the Trino server process (coordinator or worker)
2. **Configuration Volume**: Mounts configuration files from the host to the container
3. **Data Source Connections**: Network connections to external databases or storage systems

For production deployments, you would typically have multiple containers:
- One or more coordinator containers
- Multiple worker containers
- Additional containers for monitoring, logging, and management

## Prerequisites

- Docker and Docker Compose installed
- Basic understanding of SQL
- Basic knowledge of containerization concepts

## Theory: Trino Configuration Files

Trino uses several key configuration files that control its behavior:

### node.properties

This file identifies a node in the Trino cluster with these essential properties:

- `node.environment`: Designates the environment (e.g., development, production)
- `node.id`: A unique identifier for each node
- `node.data-dir`: Location for storing local data

### config.properties

This file configures the core Trino server behavior:

- `coordinator`: Boolean indicating whether this node is a coordinator (true) or worker (false)
- `node-scheduler.include-coordinator`: Controls whether the coordinator participates in query processing
- `http-server.http.port`: The port for the HTTP server
- `discovery.uri`: The URI for discovery service communication between nodes

### jvm.config

This file contains JVM-specific options:

- Memory settings (e.g., `-Xmx4G` for maximum heap size)
- Garbage collection configuration
- Performance tuning parameters

### Theory: JVM Tuning for Trino

The JVM settings significantly impact Trino's performance:

1. **Memory Settings**:
   - **-Xms**: Initial heap size (should match -Xmx for predictable performance)
   - **-Xmx**: Maximum heap size (typically 70-80% of container memory)
   - **-XX:G1HeapRegionSize**: G1 collector region size (32M is recommended)

2. **Garbage Collection**:
   - **G1GC**: Default and recommended collector for Trino
   - **-XX:+UseG1GC**: Enables the G1 garbage collector
   - **-XX:G1HeapRegionSize=32M**: Sets region size for large heaps
   - **-XX:+ExplicitGCInvokesConcurrent**: Makes System.gc() calls concurrent
   - **-XX:+HeapDumpOnOutOfMemoryError**: Generates heap dumps on OOM for debugging

3. **Performance Flags**:
   - **-server**: Optimizes JVM for server applications
   - **-XX:+UseGCOverheadLimit**: Prevents spending too much time in GC
   - **-XX:+ExitOnOutOfMemoryError**: Terminates JVM on OOM to allow container orchestration to restart

### Catalog Properties Files

Each connector is configured in a separate properties file in the `catalog` directory:

- The filename (without extension) becomes the catalog name in Trino
- Each file contains connector-specific configuration

## Step 1: Create a Docker Compose Configuration

Create a file named `docker-compose.yml` with the following content:

```yaml
version: '3'
services:
  trino:
    image: trinodb/trino:latest
    ports:
      - "8080:8080"
    volumes:
      - ./etc:/etc/trino
```

**Configuration Explained**:
- `image: trinodb/trino:latest`: Uses the official Trino image from Docker Hub. In production, you should pin to a specific version for stability.
- `ports: - "8080:8080"`: Maps the container's internal port 8080 to the host's port 8080, allowing access to Trino's UI and API.
- `volumes: - ./etc:/etc/trino`: Mounts the local `./etc` directory to the container's `/etc/trino` directory, facilitating configuration without rebuilding the image.

### Theory: Container Image Selection

When selecting a container image for Trino, consider:

1. **Image Sourcing**:
   - **Official Images**: Maintained by the Trino team, typically more secure and up-to-date
   - **Custom Images**: Built with specific configurations or additional tools

2. **Versioning Strategy**:
   - **Latest Tag**: Always points to the newest version but can cause unexpected changes
   - **Specific Versions**: Pin to exact version for reproducibility (e.g., `trinodb/trino:396`)
   - **LTS Versions**: For greater stability in production environments

3. **Image Size Considerations**:
   - **Base Image**: Alpine-based images are smaller but may have compatibility issues
   - **Included Tools**: Images with more tools are larger but more convenient for debugging
   - **Layer Caching**: Fewer layers improve build and pull efficiency

## Step 2: Set Up Configuration Files

Create the following directory structure:

```
etc/
├── catalog/
│   ├── memory.properties
├── config.properties
├── jvm.config
└── node.properties
```

### a. Create basic configuration files

Create `etc/config.properties`:
```properties
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery.uri=http://localhost:8080
```

**Configuration Explained**:
- `coordinator=true`: This node will act as a coordinator (parsing queries, creating execution plans, etc.)
- `node-scheduler.include-coordinator=true`: The coordinator will also participate in query processing. For a single-node setup, this should be true; in production clusters, it's often set to false.
- `http-server.http.port=8080`: The HTTP server will listen on port 8080
- `discovery.uri=http://localhost:8080`: The discovery service URI, which nodes use to find each other. For a single-node setup, this points to localhost.

Create `etc/node.properties`:
```properties
node.environment=development
node.id=trino-dev-node
```

**Configuration Explained**:
- `node.environment=development`: Identifies this as a development environment
- `node.id=trino-dev-node`: A unique identifier for this node. In multi-node setups, each node must have a different ID.

Create `etc/jvm.config`:
```properties
-server
-Xmx4G
-XX:-UseBiasedLocking
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:+ExitOnOutOfMemoryError
-XX:+UseGCOverheadLimit
```

**Configuration Explained**:
- `-server`: Optimizes the JVM for server applications
- `-Xmx4G`: Sets maximum heap size to 4GB. Adjust based on your machine's available memory. For production, this should be 70-80% of available RAM.
- `-XX:+UseG1GC`: Uses the G1 garbage collector, which is better for large heaps with low pause time requirements
- `-XX:+HeapDumpOnOutOfMemoryError`: Creates a heap dump if an OutOfMemoryError occurs, useful for diagnosing memory issues
- `-XX:+ExitOnOutOfMemoryError`: Forces the JVM to exit on OutOfMemoryError, allowing container orchestration to restart it

### b. Set up a memory connector for testing

Create `etc/catalog/memory.properties`:
```properties
connector.name=memory
memory.max-data-per-node=1GB
```

**Configuration Explained**:
- `connector.name=memory`: Specifies that this is a memory connector, which stores data in memory
- `memory.max-data-per-node=1GB`: Limits the amount of data stored by the memory connector to 1GB per node

## Theory: The Memory Connector

The memory connector is a special connector that stores all data in RAM. It's useful for:

1. **Testing**: Verifying Trino functionality without external dependencies
2. **Learning**: Exploring Trino's SQL capabilities with a simple setup
3. **Development**: Testing queries before running them on production data sources

Data in the memory connector persists only for the duration of the Trino server process. When Trino restarts, all data is lost. In production, you would use connectors like Hive, MySQL, or PostgreSQL to query persistent data sources.

### Memory Connector Internals

The memory connector works by:

1. **In-Memory Storage**: Creating heap-allocated data structures for tables and data
2. **Schema Management**: Maintaining schema information in memory
3. **Query Processing**: Processing queries entirely in memory without external I/O

Memory connector limitations include:
- **Size Constraints**: Limited by available heap memory
- **Durability**: No persistence across restarts
- **Concurrency**: Limited by single-node processing

## Step 3: Start Trino

Run the following command to start Trino:

```bash
docker-compose up -d
```

**Command Explained**:
- `up`: Creates and starts the containers defined in docker-compose.yml
- `-d`: Runs in detached mode (background)

Verify that Trino is running:

```bash
docker ps
```

You should see output like:
```
CONTAINER ID   IMAGE                 COMMAND   CREATED         STATUS         PORTS                    NAMES
abcd1234efgh   trinodb/trino:latest   ...      30 seconds ago  Up 28 seconds  0.0.0.0:8080->8080/tcp   trino_trino_1
```

### Theory: Docker Container Lifecycle

Understanding the Docker container lifecycle is important for managing Trino deployments:

1. **Container States**:
   - **Created**: Container initialized but not started
   - **Running**: Container processes are active
   - **Paused**: Container processes temporarily suspended
   - **Stopped**: Container processes terminated but state preserved
   - **Removed**: Container completely deleted including state

2. **Restart Policies**:
   - **no**: Never automatically restart (default)
   - **always**: Always restart if container stops
   - **on-failure**: Restart only on non-zero exit code
   - **unless-stopped**: Always restart unless manually stopped

3. **Health Checks**:
   - **Command-based**: Execute command inside container
   - **HTTP checks**: Check HTTP endpoint (ideal for Trino)
   - **TCP checks**: Verify port availability

Example Docker Compose restart policy:
```yaml
services:
  trino:
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/v1/info"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Step 4: Connect to Trino

### Using the CLI

You can connect to Trino using the CLI within the container:

```bash
docker exec -it trino_trino_1 trino
```

**Command Explained**:
- `docker exec`: Executes a command inside a running container
- `-it`: Provides an interactive terminal
- `trino_trino_1`: The container name (may vary based on your directory name)
- `trino`: The command to run inside the container, which starts the Trino CLI

### Using the Web UI

Access the Trino Web UI at [http://localhost:8080](http://localhost:8080)

The Web UI provides:
- A view of active, completed, and failed queries
- Query details, including execution plans and statistics
- Worker node status
- Cluster resource utilization

### Theory: Trino Client Connectivity

Trino supports various client connection methods, each with different characteristics:

1. **CLI Client**:
   - **Authentication**: Supports username/password, Kerberos, JWT
   - **Transport**: HTTPS with certificate validation
   - **Features**: Command history, query file execution, output formatting

2. **JDBC Driver**:
   - **Connection String**: `jdbc:trino://host:port/catalog/schema`
   - **Authentication**: Multiple methods via connection properties
   - **Features**: Connection pooling, prepared statements

3. **Web UI**:
   - **Access**: HTTP/HTTPS via browser
   - **Authentication**: Same as configured server authentication
   - **Features**: Query monitoring, execution visualization, cluster status

4. **HTTP API**:
   - **Endpoint**: `/v1/statement` for queries
   - **Authentication**: HTTP headers for credentials
   - **Format**: JSON request/response format

## Step 5: Run Your First Query

Once connected with the CLI, try running some queries:

```sql
-- List catalogs
SHOW CATALOGS;

-- Use the memory connector
USE memory.default;

-- Create a table
CREATE TABLE nation AS
SELECT * FROM tpch.tiny.nation;

-- Query the table
SELECT * FROM nation;
```

**Query Explanation**:
1. `SHOW CATALOGS`: Lists all available catalogs (data sources) configured in Trino
2. `USE memory.default`: Sets the current schema to `memory.default` (catalog.schema)
3. `CREATE TABLE nation AS...`: Creates a table in the memory connector by copying data from the built-in TPC-H connector's "tiny" nation table
4. `SELECT * FROM nation`: Queries all columns and rows from the nation table

### Theory: Trino Query Execution Flow

Understanding how Trino executes queries helps in troubleshooting and optimization:

1. **Query Submission**: Client submits SQL to the coordinator
2. **Parsing**: SQL text is parsed into a syntax tree
3. **Analysis**: Names are resolved and types are assigned
4. **Logical Planning**: Creates a logical execution plan
5. **Optimization**: Applies rule-based and cost-based optimizations
6. **Physical Planning**: Converts to physical execution plan
7. **Scheduling**: Divides plan into stages and tasks
8. **Execution**: Workers execute tasks in parallel
9. **Result Collection**: Coordinator gathers results
10. **Result Return**: Data streamed back to client

The execution engine employs:
- **Pipeline Parallelism**: Different stages run in parallel
- **Data Parallelism**: Same processing on different data segments
- **Exchange Operators**: Allow data movement between stages
- **Adaptive Execution**: Some plans adapt based on statistics gathered during execution

## Step 6: Stop Trino

To stop the Trino container:

```bash
docker-compose down
```

**Command Explained**:
- `down`: Stops and removes containers, networks, and volumes defined in docker-compose.yml

## Theory: Scaling Beyond a Single Node

While this lab sets up a single-node Trino instance, production deployments typically involve multiple nodes:

### Coordinator Configuration

For a coordinator-only node:
```properties
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=8080
discovery.uri=http://coordinator:8080
```

### Worker Configuration

For worker nodes:
```properties
coordinator=false
http-server.http.port=8080
discovery.uri=http://coordinator:8080
```

### Discovery Service Architecture

In multi-node setups, the discovery service is crucial:

1. **Purpose**: Enables nodes to discover and communicate with each other
2. **Implementation Options**:
   - **Embedded**: Each Trino node can run its own discovery server
   - **Standalone**: Separate discovery service for large clusters
   - **Third-party**: Integration with Kubernetes, Consul, or ZooKeeper

3. **Communication Flow**:
   - Workers register with discovery service on startup
   - Coordinator polls discovery service for active workers
   - Heartbeats maintain node status
   - Dead node detection removes unavailable workers

### Docker Compose for Multi-Node

A multi-node setup would have a docker-compose.yml like:

```yaml
version: '3'
services:
  coordinator:
    image: trinodb/trino:latest
    ports:
      - "8080:8080"
    volumes:
      - ./coordinator/etc:/etc/trino
    networks:
      - trino-network

  worker1:
    image: trinodb/trino:latest
    volumes:
      - ./worker1/etc:/etc/trino
    networks:
      - trino-network
    depends_on:
      - coordinator

  worker2:
    image: trinodb/trino:latest
    volumes:
      - ./worker2/etc:/etc/trino
    networks:
      - trino-network
    depends_on:
      - coordinator

networks:
  trino-network:
```

### Theory: Resource Planning for Multi-Node Clusters

When scaling to multiple nodes, consider these resource allocation principles:

1. **Coordinator Sizing**:
   - **CPU**: 4-8 cores for query planning and coordination
   - **Memory**: 16-32GB for handling concurrent requests
   - **Disk**: Minimal requirements (mostly configuration)
   - **Network**: High bandwidth for client and worker communication

2. **Worker Sizing**:
   - **CPU**: 8-16 cores for parallel query processing
   - **Memory**: 32-64GB per worker, sized for typical query workloads
   - **Disk**: Sufficient for spill-to-disk operations
   - **Network**: High bandwidth for data exchange

3. **Scaling Strategies**:
   - **Vertical Scaling**: Larger nodes for memory-intensive operations
   - **Horizontal Scaling**: More nodes for higher query concurrency
   - **Specialized Nodes**: Different hardware for different workloads

4. **Rule of Thumb Calculations**:
   - Memory per worker = (Largest join size × 1.5) / number of workers
   - Number of workers = (Peak concurrent queries × average splits per query) / (splits per worker)

## Theory: Production Deployment Considerations

Moving beyond development to production requires additional considerations:

1. **Security**:
   - **TLS Encryption**: Enable HTTPS with valid certificates
   - **Authentication**: Configure password, LDAP, or Kerberos auth
   - **Authorization**: Implement access control rules

2. **Monitoring**:
   - **JMX Metrics**: Enable JMX metrics for monitoring
   - **Prometheus Integration**: Add Prometheus endpoint
   - **Log Management**: Configure centralized logging

3. **Resource Management**:
   - **Memory Limits**: Set appropriate per-query memory limits
   - **Query Queues**: Configure resource groups for workload management
   - **Spill to Disk**: Enable for memory-intensive operations

4. **Reliability**:
   - **Automatic Restart**: Configure restart policies
   - **Health Checks**: Add Docker health checks
   - **Backup/Restore**: Plan for catalog metadata backups

Example production docker-compose.yml excerpt:
```yaml
services:
  coordinator:
    image: trinodb/trino:396
    restart: unless-stopped
    ports:
      - "8443:8443"
    volumes:
      - ./coordinator/etc:/etc/trino
      - ./logs:/var/trino/logs
    environment:
      - JAVA_TOOL_OPTIONS=-Xmx16G -XX:+UseG1GC
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 20G
    healthcheck:
      test: ["CMD", "curl", "-f", "https://localhost:8443/v1/info"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Next Steps

In the next lab, you'll learn how to configure Trino with additional connectors to query real data sources. 