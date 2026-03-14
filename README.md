# DazzleDuck Security Demo

Demonstrates row-level security using JWT claims with DazzleDuck SQL Server.
Tenants can only see their own data — the filter is embedded in the JWT token
at login time and enforced server-side on every query.

## Data Model

| Table         | Description                          |
|---------------|--------------------------------------|
| `tenant`      | 3 tenants: A Inc, B Inc, C Inc       |
| `user`        | 10 users across 3 tenants            |
| `transaction` | 47 web log transactions (fact table) |

## Prerequisites

- Docker and Docker Compose installed
- [DuckDB](https://duckdb.org/) installed (`duckdb` in PATH) — **required only for Option B (DuckDB CLI)**
- The DazzleDuck DuckDB extension — **required only for Option B (DuckDB CLI)**

Download the extension for your platform and place it at a known path:

```bash
# macOS
curl -L -o /tmp/dazzleduck.duckdb_extension \
  https://github.com/dazzleduck-web/dazzleduck-sql-duckdb/releases/download/v0.0.6/dazzleduck.osx_amd64.duckdb_extension

# Linux
curl -L -o /tmp/dazzleduck.duckdb_extension \
  https://github.com/dazzleduck-web/dazzleduck-sql-duckdb/releases/download/v0.0.6/dazzleduck.linux_amd64.duckdb_extension
```

Update the `LOAD` path in `open_demo.sql` and `dazzleduck_restricted_demo.sql` to match where you saved it.

## Setup

### Step 1 — Start Postgres

```bash
docker-compose up -d postgres
```

Wait until healthy:

```bash
docker-compose ps postgres   # Status should be "healthy"
```

### Step 2 — Create demo data

Run once to initialize the DuckLake catalog in Postgres and seed all tables:

```bash
duckdb -init setup_ducklake.sql /dev/null
```

Expected output:
```
┌─────────────┬───────┐
│     tbl     │ rows  │
├─────────────┼───────┤
│ tenant      │     3 │
│ user        │    10 │
│ transaction │    47 │
└─────────────┴───────┘
```

### Step 3 — Start the servers

```bash
docker-compose up -d dazzleduck-server-restricted dazzleduck-server-complete
```

Wait for both to be ready:

```bash
curl -sf http://localhost:8082/health && echo "Restricted ready"
curl -sf http://localhost:8081/health && echo "Complete ready"
```

## Querying

### Option A — DazzleDuck UI (no local tools required)

Open [https://dazzleduck-ui.netlify.app/](https://dazzleduck-ui.netlify.app/) in your browser and connect to the complete server:

- **URL**: `http://localhost:8081`
- **Username**: `admin`
- **Password**: `admin`

Once connected you can query any table directly:

```sql
SELECT * FROM ducklake_catalog.main.transaction;
```

```sql
SELECT tenant_id, COUNT(*) AS total_transactions
FROM ducklake_catalog.main.transaction
GROUP BY tenant_id
ORDER BY tenant_id;
```

```sql
SELECT t.time::DATE AS date, COUNT(*) AS requests, AVG(t.response_ms) AS avg_ms
FROM ducklake_catalog.main.transaction t
GROUP BY date
ORDER BY date;
```

Query results are displayed as a table and can be visualized as charts and graphs directly in the UI.

### Option B — DuckDB CLI with Row-Level Security

Run DuckDB in unsigned mode (required to load the local extension):

```bash
duckdb -unsigned -init local_ducklake_catalog.sql
```

Then load the demo session (sets `tenant_id = 1` by default and creates views):

```sql
.read dazzleduck_restricted_demo.sql
```

This script:
1. Loads the local DazzleDuck extension
2. Sets `tenant_id = 1`
3. Calls `dd_login` per table with a JWT embedding the filter claim `tenant_id = 1`
4. Creates views (`tenant`, `user`, `transaction`) backed by `dd_read_arrow`

#### Switch tenants

To query as a different tenant, change the variable before reading the script:

```sql
SET VARIABLE tenant_id = 2;
.read dazzleduck_restricted_demo.sql
```

#### Example Queries

##### List all users (filtered to current tenant)

```sql
SELECT * FROM "user";
```

##### Count transactions by username

```sql
SELECT u.username, COUNT(*) AS total_transactions
FROM "transaction" t
JOIN "user" u ON t.user_id = u.user_id
GROUP BY u.username
ORDER BY total_transactions DESC;
```

##### Transactions for a specific user on a specific date

```sql
SELECT t.transaction_id, t.method, t.path, t.status_code, t.response_ms, t.time
FROM "transaction" t
JOIN "user" u ON t.user_id = u.user_id
WHERE u.username = 'bob'
AND t.time::DATE = '2026-03-01';
```

##### Transactions in the last N days

```sql
SELECT t.transaction_id, u.username, t.method, t.path, t.status_code, t.time
FROM "transaction" t
JOIN "user" u ON t.user_id = u.user_id
WHERE t.time >= current_date - INTERVAL 2 DAY;
```

##### Transaction count by tenant (only current tenant visible)

```sql
SELECT COUNT(*), tenant_id FROM "transaction" GROUP BY tenant_id;
```

## HTTP Ingestion

Push new rows into `ducklake_catalog.main.transaction` via the complete server:

```bash
./ingest_transaction.sh
```

This script:
1. Gets a JWT token via `POST /v1/login`
2. Generates Arrow IPC data using Python/pyarrow
3. Pushes to `POST http://localhost:8081/v1/ingest?ingestion_queue=transaction`

The ingested rows are immediately visible from the restricted server (port 8082)
because both servers share the same Postgres-backed DuckLake catalog.

## Architecture

```
                        ┌─────────────────────────────────────┐
                        │           PostgreSQL :5432           │
                        │                                      │
                        │  DuckLake metadata tables            │
                        │  (ducklake_schema, ducklake_table,   │
                        │   ducklake_data_file, ...)           │
                        │                                      │
                        │  configuration table                 │
                        │  (multi-tenant config per tenant)    │
                        └──────────┬──────────────────────────┘
                                   │ shared metadata
                      ┌────────────┴────────────┐
                      ▼                         ▼
            ┌─────────────────┐       ┌──────────────────┐
            │  Port 8082      │       │  Port 8081        │
            │  RESTRICTED     │       │  COMPLETE         │
            │  READ_ONLY      │       │  READ_WRITE       │
            │                 │       │                   │
            │  JWT filter     │       │  HTTP ingestion   │
            │  claims         │       │  (Arrow IPC push) │
            │  enforced       │       │                   │
            └────────┬────────┘       └────────┬──────────┘
                     │                         │
                     └──────────┬──────────────┘
                                ▼
                    warehouse/data/ducklake_catalog/
                    (shared Parquet data files)
```

**Port 8082 — Restricted server** enforces row-level security via JWT filter claims.
Every query is rewritten server-side with a `WHERE` clause extracted from the token.

**Port 8081 — Complete server** accepts Arrow IPC data pushed over HTTP to the
`/v1/ingest` endpoint and commits it to the shared DuckLake catalog via
`DuckLakeIngestionTaskFactoryProvider`. Also used for unrestricted querying via the UI.

**PostgreSQL** stores all DuckLake catalog metadata, enabling both servers to share
the same catalog with concurrent read/write access (no file locking).

## How Row-Level Security Works

```
  CLIENT (DuckDB)                         SERVER (DazzleDuck :8082)
  ───────────────                         ─────────────────────────

  dd_login(url, user, pass, claims)
    claims = {                            POST /v1/login
      "database": "ducklake_catalog",  ──────────────────────────►  LoginService
      "schema":   "main",                                           │
      "table":    "transaction",                                     │ validate user
      "filter":   "tenant_id = 1"                                    │ embed claims in JWT
    }                                     ◄──────────────────────  │
  JWT token (contains filter claim)                              JWT { filter: "tenant_id = 1" }


  dd_read_arrow(url,
    source_table := '...transaction',     GET /v1/query?q=SELECT * FROM transaction
    auth_token   := <JWT>)        ────────────────────────────►  QueryService
                                            Authorization: Bearer <JWT>    │
                                                                           │
                                                                   JwtAuthenticationFilter
                                                                       extract claims
                                                                           │
                                                                   JwtClaimBasedAuthorizer
                                                                       inject WHERE clause
                                                                           │
                                                               SQL rewritten to:
                                                               SELECT * FROM transaction
                                                               WHERE (tenant_id = 1)
                                                                           │
                                                                       DuckDB
                                                                    (DuckLake catalog)
                                                                           │
                                          ◄────────────────────────────── │
  only tenant_id = 1 rows returned               Arrow IPC stream
```

1. **Login**: `dd_login` POSTs to `/v1/login` with a claims JSON including a `filter` field:
   ```json
   {"database":"ducklake_catalog","schema":"main","table":"transaction","filter":"tenant_id = 1"}
   ```
2. **JWT issued**: The server embeds the `filter` claim in the JWT token.
3. **Query**: `dd_read_arrow` sends the JWT as `Authorization: Bearer <token>` on every request.
4. **Server enforcement**: `JwtClaimBasedAuthorizer` extracts the `filter` claim and injects
   it as a `WHERE` clause into the SQL before execution. The client never sees other tenants' data.

## File Reference

| File | Description |
|------|-------------|
| `setup_ducklake.sql` | Initializes DuckLake catalog in Postgres and seeds all tables (run once) |
| `startup/ducklake_catalog.sql` | Restricted server startup: attaches DuckLake (READ_ONLY) + pg_catalog |
| `startup/ducklake_catalog_writable.sql` | Complete server startup: attaches DuckLake (READ_WRITE) + pg_catalog |
| `startup/postgres_init.sql` | Postgres init: creates multi-tenant `configuration` table |
| `local_ducklake_catalog.sql` | Local DuckDB init: attaches DuckLake via Postgres metadata |
| `dazzleduck_restricted_demo.sql` | Client session: login, create views with JWT filter claims |
| `open_demo.sql` | Client session: login without filter claims (all tenants visible) |
| `ingest_transaction.sh` | Demo HTTP ingestion: pushes Arrow IPC rows to port 8081 |
| `docker-compose.yml` | Postgres + restricted server (8082) + complete server (8081) |

## Quick Reference

### Infrastructure

```bash
# Start Postgres only
docker-compose up -d postgres

# Check Postgres health
docker-compose ps postgres

# Start all services
docker-compose up -d

# Start servers after Postgres is healthy
docker-compose up -d dazzleduck-server-restricted dazzleduck-server-complete

# Check server health
curl -sf http://localhost:8082/health && echo "Restricted ready"
curl -sf http://localhost:8081/health && echo "Complete ready"

# Stop all services
docker-compose down

# Full reset (wipes Postgres data and Parquet files)
docker-compose down -v
rm -rf warehouse/data/ducklake_catalog
```

### Data Setup

```bash
# Seed DuckLake catalog and tables (run once after Postgres is healthy)
duckdb -init setup_ducklake.sql /dev/null
```

### DazzleDuck UI

Open [https://dazzleduck-ui.netlify.app/](https://dazzleduck-ui.netlify.app/) and connect to the complete server:
- **URL**: `http://localhost:8081`, **Username**: `admin`, **Password**: `admin`

### Local DuckDB Session (Row-Level Security)

```bash
# Open DuckDB with DuckLake attached (unsigned mode required for extension)
duckdb -unsigned -init local_ducklake_catalog.sql

# Open persistent demo database with views pre-created
# (update LOAD path in open_demo.sql to your downloaded extension location first)
duckdb -unsigned demo.duckdb -init open_demo.sql
```

```sql
-- Inside DuckDB: load demo session (login + create views for tenant 1)
.read dazzleduck_restricted_demo.sql

-- Switch to a different tenant and reload
SET VARIABLE tenant_id = 2;
.read dazzleduck_restricted_demo.sql
```

### Ingestion

```bash
# Push new transaction rows via Arrow IPC to the complete server (port 8081)
./ingest_transaction.sh
```
