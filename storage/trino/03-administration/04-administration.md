# Lab 04: Trino Administration

In this lab, you will learn how to perform essential administration tasks in Trino, including:
- Setting up and using the Trino Web UI
- Configuring authentication
- Managing logs
- Implementing observability with OpenTelemetry

## Prerequisites
- A running Trino cluster
- Administrator access to the Trino configuration

## Part 1: Trino Web UI

### Activating the Web UI

By default, the Trino Web UI is enabled and accessible at port 8080. Check your configuration in `etc/config.properties`:

```properties
http-server.http.port=8080
```

If you need to change settings, update the following properties:

```properties
web-ui.enabled=true               # Enable the web interface (default: true)
web-ui.authentication.type=form   # Authentication type (options: form, fixed, certificate)
```

### Accessing the Web UI

1. Open your browser and navigate to `http://<trino-coordinator>:8080`
2. You should see the Trino UI dashboard showing:
   - Running queries
   - Query history
   - Worker nodes
   - Cluster metrics

### Configuring Authentication

Trino supports several authentication types. Let's configure form-based authentication:

1. Edit `etc/config.properties` on the coordinator:

```properties
http-server.authentication.type=form
http-server.https.enabled=true
http-server.https.port=8443
http-server.https.keystore.path=/etc/trino/keystore.jks
http-server.https.keystore.key=keystore_password
```

2. Set up a password file (`etc/password-authenticator.properties`):

```properties
password-authenticator.name=file
file.password-file=/etc/trino/password.db
```

3. Create a password file with username:password entries:
```
$ echo "admin:admin" > /etc/trino/password.db
$ chmod 600 /etc/trino/password.db
```

4. Restart Trino coordinator to apply changes.

## Part 2: Logging in Trino

Trino uses Java's logging framework to output logs. The logs provide essential information for debugging and monitoring.

### Log Configuration

1. Edit `etc/log.properties` to configure logging:

```properties
io.trino=INFO
com.sun.jersey.guice.spi.container.GuiceComponentProviderFactory=WARN
com.ning.http.client=WARN
io.trino.server.PluginManager=DEBUG
```

2. Logs are written to the following locations by default:
   - `var/log/server.log`: Main server log
   - `var/log/http-request.log`: HTTP request log
   - `var/log/launcher.log`: Launcher log

3. To change the log file location, edit `etc/jvm.config`:

```
-Dlog.levels-file=etc/log.properties
-Dlog.output-file=/path/to/custom/log/file
```

### Log Analysis Tasks

1. Check the log for query failures:
```bash
grep "FAILED" var/log/server.log
```

2. Monitor long-running queries:
```bash
grep "Query" var/log/server.log | grep -v "FINISHED"
```

## Part 3: Observability with OpenTelemetry

OpenTelemetry provides a unified way to capture metrics, logs, and traces.

### Setting Up OpenTelemetry

1. Add the required dependencies by placing the OpenTelemetry plugin in the `plugin` directory.

2. Configure OpenTelemetry in `etc/config.properties`:

```properties
# Enable OpenTelemetry
tracing.enabled=true

# Configure the exporter (Jaeger in this example)
opentelemetry.metrics.exporter=otlp
opentelemetry.traces.exporter=otlp
opentelemetry.logs.exporter=otlp

# OTLP exporter configuration
opentelemetry.otlp.endpoint=http://jaeger:4317
opentelemetry.otlp.protocol=grpc
```

3. Restart Trino to apply the changes.

### Monitoring with Jaeger

1. Deploy Jaeger using Docker:

```bash
docker run -d --name jaeger \
  -e COLLECTOR_OTLP_ENABLED=true \
  -p 16686:16686 \
  -p 4317:4317 \
  jaegertracing/all-in-one:latest
```

2. Access the Jaeger UI at `http://localhost:16686`

3. Run a test query in Trino and check the traces in Jaeger UI.

## Exercise

1. Configure form-based authentication for your Trino Web UI
2. Set DEBUG log level for `io.trino.execution` package and analyze a query execution
3. Set up OpenTelemetry with Jaeger and trace a complex query execution

## Conclusion

In this lab, you've learned how to:
- Configure and use the Trino Web UI with authentication
- Manage Trino logging for better troubleshooting
- Implement observability using OpenTelemetry

These skills are essential for maintaining and monitoring a production Trino deployment.

## References
- [Trino Web UI Documentation](https://trino.io/docs/current/admin/web-interface.html)
- [Trino Security Documentation](https://trino.io/docs/current/security.html)
- [OpenTelemetry in Trino](https://trino.io/docs/current/admin/opentelemetry.html)