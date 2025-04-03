# Lab 5: Security and Governance in Trino

This lab guides you through implementing security and governance features in your Trino deployment.

## Theory: Trino Security Model

Trino's security model consists of several layers that work together to provide comprehensive protection:

### Authentication Mechanisms

Authentication in Trino verifies the identity of users connecting to the cluster:

1. **Password Authentication**: Simple username/password verification
2. **LDAP Authentication**: Integration with directory services
3. **Kerberos Authentication**: Strong authentication using tickets
4. **JWT Authentication**: Token-based authentication for web services
5. **Certificate Authentication**: Using X.509 certificates
6. **OAuth2 Authentication**: Delegating authentication to OAuth providers

Each mechanism has different security properties:

| Authentication Method | Security Level | Integration Complexity | Use Cases |
|----------------------|----------------|------------------------|-----------|
| Password | Basic | Low | Development, simple deployments |
| LDAP | Medium | Medium | Enterprise environments with directory services |
| Kerberos | High | High | Secure enterprise deployments, Hadoop integration |
| JWT | Medium | Medium | Microservices, web applications |
| Certificate | High | Medium | Machine-to-machine communications |
| OAuth2 | Medium-High | Medium-High | Web applications, cloud deployments |

### Authorization Architecture

Once authenticated, Trino determines what actions users can perform through several authorization systems:

1. **File-Based Access Control**: Rules defined in configuration files
2. **SQL-Based Access Control**: Privileges managed through SQL commands
3. **Ranger-Based Access Control**: Integration with Apache Ranger
4. **Custom Plugins**: Custom authorization implementations

The authorization model covers:
- **Catalog Access**: Which catalogs a user can access
- **Schema Access**: Which schemas within catalogs are accessible
- **Table Access**: Permissions on tables (SELECT, INSERT, etc.)
- **Column-Level Security**: Restricting access to specific columns
- **Row-Level Security**: Filtering rows based on user context

### Data Protection

Beyond access control, Trino provides mechanisms to protect data:

1. **Transport Layer Security (TLS)**: Encrypts all network traffic
2. **Data Masking**: Obscuring sensitive data for unauthorized users
3. **Query Auditing**: Logging access patterns and violations
4. **Query Limits**: Preventing excessive resource usage

## Prerequisites

- A running Trino cluster (See Lab 2: Docker Setup)
- Access to modify Trino's configuration files
- (Optional) LDAP server for directory integration
- (Optional) Kerberos KDC for ticket-based authentication

## Part 1: Implementing Password Authentication

### Theory: Password Authentication

Password authentication in Trino works through these components:

1. **Authentication Handler**: Processes incoming credentials
2. **Password File**: Contains hashed passwords for verification
3. **Password Hashing**: Secures stored passwords with bcrypt

The authentication flow consists of:
1. Client sends username and password
2. Server hashes the password
3. Server compares with stored hash
4. Access granted if hashes match

This method is simple but has limitations:
- Passwords may be exposed if TLS isn't used
- Password files must be distributed to all coordinators
- Does not integrate with enterprise identity systems

### Step 1: Password Authentication

#### a. Create a password file

Create a file named `password.db` with the following content:

```
admin:admin
analyst:analyst
datascientist:datascientist
```

#### b. Configure Trino to use password authentication

Update your `config.properties` file:

```properties
http-server.authentication.type=PASSWORD
```

Create a file named `password-authenticator.properties`:

```properties
password-authenticator.name=file
file.password-file=/etc/trino/password.db
```

### Step 2: LDAP Authentication

For production environments, LDAP is often used:

```properties
http-server.authentication.type=LDAP
ldap.url=ldaps://ldap-server:636
ldap.user-bind-pattern=uid=${USER},ou=people,dc=example,dc=com
```

### Step 3: OAuth/OIDC Authentication

For modern authentication with SSO:

```properties
http-server.authentication.type=OAUTH2
http-server.authentication.oauth2.issuer=https://auth.example.com
http-server.authentication.oauth2.auth-url=https://auth.example.com/oauth2/authorize
http-server.authentication.oauth2.token-url=https://auth.example.com/oauth2/token
http-server.authentication.oauth2.jwks-url=https://auth.example.com/oauth2/v1/keys
http-server.authentication.oauth2.client-id=trino-client
http-server.authentication.oauth2.client-secret=trino-secret
```

## Part 2: Authorization

Trino supports several authorization models to control access to resources.

### Step 1: File-based Access Control

#### a. Create the rules file

Create a file named `rules.json`:

```json
{
  "catalogs": [
    {
      "user": "admin",
      "catalog": ".*",
      "allow": true
    },
    {
      "user": "analyst",
      "catalog": "mysql",
      "allow": true
    },
    {
      "user": "datascientist",
      "catalog": "hive",
      "schema": "default",
      "allow": true
    }
  ]
}
```

#### b. Configure Trino to use file-based access control

Update your `config.properties` file:

```properties
access-control.name=file
security.config-file=/etc/trino/rules.json
```

### Step 2: SQL Standard Access Control

For more granular control using SQL GRANT/REVOKE statements:

```properties
access-control.name=sql-standard
```

With this configuration, you can use SQL commands to manage permissions:

```sql
-- Grant privileges to a user
GRANT SELECT ON mysql.example.customers TO analyst;

-- Revoke privileges from a user
REVOKE SELECT ON mysql.example.customers FROM datascientist;
```

## Part 3: Encryption

### Step 1: Enable HTTPS

#### a. Generate a keystore

```bash
keytool -genkeypair -alias trino -keyalg RSA -keystore keystore.jks -storepass password -dname "CN=trino"
```

#### b. Configure Trino to use HTTPS

Update your `config.properties` file:

```properties
http-server.https.enabled=true
http-server.https.port=8443
http-server.https.keystore.path=/etc/trino/keystore.jks
http-server.https.keystore.key=password
```

### Step 2: Internal Communication Encryption

For securing coordinator-worker communication:

```properties
internal-communication.https.required=true
internal-communication.https.keystore.path=/etc/trino/keystore.jks
internal-communication.https.keystore.key=password
```

## Part 4: Data Governance

### Step 1: Query Auditing

To track who is running what queries, configure a query event listener:

```properties
event-listener.name=query-event-logger
query-event-logger.log-path=/var/log/trino/query-events.log
```

### Step 2: Column-level Access Control

For certain connectors, you can implement column-level security:

```sql
-- Grant access to specific columns
GRANT SELECT(id, name) ON mysql.example.customers TO analyst;
```

### Step 3: Row-level Filtering

You can create views with row filters:

```sql
-- Create a row-filtered view
CREATE VIEW mysql.example.filtered_customers AS
SELECT * FROM mysql.example.customers
WHERE region = current_user;
```

### Step 4: Data Masking

You can mask sensitive data using views:

```sql
-- Create a view with masked data
CREATE VIEW mysql.example.masked_customers AS
SELECT 
  id,
  name,
  CASE 
    WHEN current_user = 'admin' THEN email
    ELSE CONCAT(SUBSTRING(email, 1, 2), '***@***', SUBSTRING(email, -4))
  END AS email,
  created_at
FROM mysql.example.customers;
```

## Part 5: Implementing in Kubernetes

### Step 1: Create Secrets for Sensitive Configuration

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: trino-auth-secrets
  namespace: trino
type: Opaque
data:
  password.db: YWRtaW46YWRtaW4KYW5hbHlzdDphbmFseXN0CmRhdGFzY2llbnRpc3Q6ZGF0YXNjaWVudGlzdAo=
  keystore.jks: <base64-encoded-keystore>
```

### Step 2: Update Helm Values for Security

Update your `trino-values.yaml` file:

```yaml
server:
  # ... previous configuration ...
  
  config:
    http-server.authentication.type: PASSWORD
    access-control.name: file
    http-server.https.enabled: true
    http-server.https.port: 8443
    event-listener.name: query-event-logger
  
  additionalConfigFiles:
    password-authenticator.properties: |
      password-authenticator.name=file
      file.password-file=/etc/trino/auth/password.db
    
    rules.json: |
      {
        "catalogs": [
          {
            "user": "admin",
            "catalog": ".*",
            "allow": true
          },
          {
            "user": "analyst",
            "catalog": "mysql",
            "allow": true
          }
        ]
      }
  
  additionalVolumes:
    # ... previous volumes ...
    - name: trino-auth-secrets
      secret:
        secretName: trino-auth-secrets
  
  additionalVolumeMounts:
    # ... previous mounts ...
    - name: trino-auth-secrets
      mountPath: /etc/trino/auth
      readOnly: true
```

### Step 3: Apply the Changes

```bash
kubectl apply -f trino-auth-secrets.yaml
helm upgrade trino trino/trino -n trino -f trino-values.yaml
```

## Next Steps

In the next lab, you'll learn about monitoring Trino and optimizing its performance. 