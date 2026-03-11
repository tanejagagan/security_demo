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

- [DuckDB](https://duckdb.org/) installed (`duckdb` in PATH)
- Docker and Docker Compose installed
- The DazzleDuck DuckDB extension built locally at:
  `../dazzleduck-sql-duckdb/build/release/extension/dazzleduck/dazzleduck.duckdb_extension`

## Setup

### Step 1 — Create demo data

Run once to create the DuckLake catalog and seed all tables:

```bash
duckdb -c ".read setup_ducklake.sql"
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

### Step 2 — Start the server

```bash
docker-compose up -d
```

Wait for the server to be ready:

```bash
curl -sf http://localhost:8081/health && echo "Ready"
```

Stop the server when done:

```bash
docker-compose down
```

## Querying with Row-Level Security

Run DuckDB in unsigned mode (required to load the local extension):

```bash
duckdb -unsigned -init local_demo_catalog.sql
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

### Switch tenants

To query as a different tenant, change the variable before reading the script:

```sql
SET VARIABLE tenant_id = 2;
.read dazzleduck_restricted_demo.sql
```

## Example Queries

### List all users (filtered to current tenant)

```sql
SELECT * FROM "user";
```

### Count transactions by username

```sql
SELECT u.username, COUNT(*) AS total_transactions
FROM "transaction" t
JOIN "user" u ON t.user_id = u.user_id
GROUP BY u.username
ORDER BY total_transactions DESC;
```

### Transactions for a specific user on a specific date

```sql
SELECT t.transaction_id, t.method, t.path, t.status_code, t.response_ms, t.time
FROM "transaction" t
JOIN "user" u ON t.user_id = u.user_id
WHERE u.username = 'bob'
AND t.time::DATE = '2026-03-01';
```

### Transactions in the last N days

```sql
SELECT t.transaction_id, u.username, t.method, t.path, t.status_code, t.time
FROM "transaction" t
JOIN "user" u ON t.user_id = u.user_id
WHERE t.time >= current_date - INTERVAL 2 DAY;
```

### Transaction count by tenant (only current tenant visible)

```sql
SELECT COUNT(*), tenant_id FROM "transaction" GROUP BY tenant_id;
```

## How Row-Level Security Works

```
  CLIENT (DuckDB)                         SERVER (DazzleDuck :8081)
  ───────────────                         ─────────────────────────

  dd_login(url, user, pass, claims)
    claims = {                            POST /v1/login
      "database": "demo_catalog",  ──────────────────────────►  LoginService
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
   {"database":"demo_catalog","schema":"main","table":"transaction","filter":"tenant_id = 1"}
   ```
2. **JWT issued**: The server embeds the `filter` claim in the JWT token.
3. **Query**: `dd_read_arrow` sends the JWT as `Authorization: Bearer <token>` on every request.
4. **Server enforcement**: `JwtClaimBasedAuthorizer` extracts the `filter` claim and injects
   it as a `WHERE` clause into the SQL before execution. The client never sees other tenants' data.

## File Reference

| File | Description |
|------|-------------|
| `setup_ducklake.sql` | Creates DuckLake catalog and seeds all tables (run once) |
| `startup/demo_catalog.sql` | Server startup script (attaches catalog in read-only mode) |
| `local_demo_catalog.sql` | Client-side init: installs arrow/ducklake and attaches catalog |
| `dazzleduck_restricted_demo.sql` | Client session: login, create views with JWT filter claims |
| `docker-compose.yml` | Starts DazzleDuck server in RESTRICTED mode on port 8081 |
