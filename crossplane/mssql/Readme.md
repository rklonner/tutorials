# Crossplane - Provision a MSSQL database and user in a local MSSQL server

**Demonstrate**:
* How to simulate a local mssql server
* How to configure a crossplane provider for mssql
* How to create a database, users and permissions (grant)
* How to verify the permissions

**Prerequisites**:
* Crossplane is setup in your cluster (see [Installation](../Readme.md#install-helm-chart-in-kind-cluster))

## Prepare environment

```bash
# Start local mssql server with docker-compose
docker-compose up -d

# Connect mssql docker container to docker network of kind
# Special Step for Kind on Linux, Kind clusters often run on their own Docker network (named kind).
# If your MSSQL container is on the default bridge network, they might not see each other.
# Connect your MSSQL container to the Kind network: 

docker network connect kind mssql-test
# After connecting, your MSSQL container can be reached by its container name (e.g., mssql-test) from inside the cluster.

# Install and configure the crossplane sql provider which supports mssql
kubectl apply -f crossplane-provider-config.yaml
```

## Create database
```bash
## Provision database
kubectl apply -f crossplane-database.yaml

# Verify
kubectl -n crossplane-system get databases.mssql.sql.crossplane.io test-db
```

## Create users and permissions
There will be 2 users, readonly-user and readwrite-user, where only the second one has permissions to create a table in the new db.

```bash
# Create secrests for db users
kubectl create secret generic ro-user-password -n crossplane-system --from-literal=password='Read0nly!Pass'
kubectl create secret generic rw-user-password -n crossplane-system --from-literal=password='ReadWr1te!Pass'

# Create users
kubectl apply -f crossplane-db-users.yaml

# Create permissions
kubectl apply -f crossplane-db-grant.yaml
```

## Test DB access

We will use the sqlcmd binary from the local mssql server docker container to do some queries.

```bash
# Try to read a sys table (should work)
docker exec -it mssql-test /opt/mssql-tools18/bin/sqlcmd -S localhost,1433 -U readonly-user -P 'Read0nly!Pass' -d test-db -C -Q "SELECT name FROM sys.tables"

# Try to create a table with RO user (should fail)
docker exec -it mssql-test /opt/mssql-tools18/bin/sqlcmd  -S localhost,1433 -U readonly-user -P 'Read0nly!Pass' -d test-db -C -Q "CREATE TABLE UnauthorizedTable (ID INT PRIMARY KEY, Data NVARCHAR(50))"
# --> CREATE TABLE permission denied in database 'test-db'.

# Try to create table with RW user (should work)
docker exec -it mssql-test /opt/mssql-tools18/bin/sqlcmd  -S localhost,1433 -U readwrite-user -P 'ReadWr1te!Pass' -d test-db -C -Q "CREATE TABLE UnauthorizedTable (ID INT PRIMARY KEY, Data NVARCHAR(50))"

# Read from new table
docker exec -it mssql-test /opt/mssql-tools18/bin/sqlcmd  -S localhost,1433 -U readonly-user -P 'Read0nly!Pass' -d test-db -C -Q "SELECT * FROM UnauthorizedTable;"
```