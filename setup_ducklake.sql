INSTALL ducklake;
LOAD ducklake;

-- Attach local DuckLake catalog (replace with s3://bucket/metadata/catalog.duckdb in production)
ATTACH 'ducklake:warehouse/metadata/demo_catalog.duckdb' AS demo_catalog (DATA_PATH 'warehouse/data/demo_catalog');

-- ---------------------------------------------------------------------------
-- Table 1: tenant
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS demo_catalog.main.tenant (
    tenant_id   INTEGER,
    tenant_name VARCHAR,
    region      VARCHAR,
    created_at  TIMESTAMP
);

INSERT INTO demo_catalog.main.tenant (tenant_id, tenant_name, region) VALUES
    (1, 'A Inc', 'eu-west-1'),
    (2, 'B Inc', 'us-east-1'),
    (3, 'C Inc', 'eu-central-1');

-- ---------------------------------------------------------------------------
-- Table 2: user (multi-tenant)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS demo_catalog.main."user" (
    user_id    INTEGER,
    tenant_id  INTEGER,
    username   VARCHAR,
    email      VARCHAR,
    created_at TIMESTAMP
);

INSERT INTO demo_catalog.main."user" (user_id, tenant_id, username, email) VALUES
    (101, 1, 'alice',  'alice@ainc.com'),
    (102, 1, 'bob',    'bob@ainc.com'),
    (103, 1, 'carol',  'carol@ainc.com'),
    (104, 1, 'dave',   'dave@ainc.com'),
    (201, 2, 'eve',    'eve@binc.com'),
    (202, 2, 'frank',  'frank@binc.com'),
    (203, 2, 'grace',  'grace@binc.com'),
    (301, 3, 'heidi',  'heidi@cinc.com'),
    (302, 3, 'ivan',   'ivan@cinc.com'),
    (303, 3, 'judy',   'judy@cinc.com');

-- ---------------------------------------------------------------------------
-- Table 3: transaction (multi-tenant web log fact table)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS demo_catalog.main."transaction" (
    transaction_id  INTEGER,
    tenant_id       INTEGER ,
    user_id         INTEGER ,
    method          VARCHAR ,
    path            VARCHAR ,
    status_code     SMALLINT,
    response_ms     INTEGER ,
    bytes_sent      INTEGER ,
    ip_address      VARCHAR ,
    user_agent      VARCHAR,
    time            TIMESTAMP
);

INSERT INTO demo_catalog.main."transaction"
    (transaction_id, tenant_id, user_id, method, path, status_code, response_ms, bytes_sent, ip_address, user_agent, time)
VALUES
    -- A Inc (tenant 1)
    (1001, 1, 101, 'GET',    '/api/products',              200,  45,  1024, '10.0.1.10', 'Mozilla/5.0 Chrome/120',  '2026-03-01 08:01:00'),
    (1002, 1, 101, 'POST',   '/api/orders',                201, 120,   512, '10.0.1.10', 'Mozilla/5.0 Chrome/120',  '2026-03-01 08:02:30'),
    (1003, 1, 102, 'GET',    '/api/orders/1002',           200,  30,  2048, '10.0.1.11', 'Mozilla/5.0 Firefox/121', '2026-03-01 08:05:00'),
    (1004, 1, 102, 'PUT',    '/api/orders/1002/status',    200,  88,   256, '10.0.1.11', 'Mozilla/5.0 Firefox/121', '2026-03-01 08:06:15'),
    (1005, 1, 103, 'GET',    '/api/dashboard',             200,  60,  8192, '10.0.1.12', 'Mozilla/5.0 Safari/17',   '2026-03-01 08:10:00'),
    (1006, 1, 103, 'DELETE', '/api/orders/990',            204,  95,     0, '10.0.1.12', 'Mozilla/5.0 Safari/17',   '2026-03-01 08:11:00'),
    (1007, 1, 104, 'GET',    '/api/products?page=2',       200,  50,  2048, '10.0.1.13', 'Mozilla/5.0 Chrome/120',  '2026-03-01 08:15:00'),
    (1008, 1, 104, 'POST',   '/api/products',              400,  35,   128, '10.0.1.13', 'Mozilla/5.0 Chrome/120',  '2026-03-01 08:16:00'),
    (1009, 1, 101, 'GET',    '/api/reports/monthly',       200, 340, 16384, '10.0.1.10', 'Mozilla/5.0 Chrome/120',  '2026-03-01 09:00:00'),
    (1010, 1, 102, 'POST',   '/api/auth/logout',           200,  20,    64, '10.0.1.11', 'Mozilla/5.0 Firefox/121', '2026-03-01 09:30:00'),
    (1011, 1, 103, 'GET',    '/api/products',              200,  48,  1024, '10.0.1.12', 'Mozilla/5.0 Safari/17',   '2026-03-01 10:00:00'),
    (1012, 1, 104, 'PUT',    '/api/users/104',             200,  75,   512, '10.0.1.13', 'Mozilla/5.0 Chrome/120',  '2026-03-01 10:15:00'),
    (1013, 1, 101, 'GET',    '/api/orders?status=open',    200,  90,  4096, '10.0.1.10', 'Mozilla/5.0 Chrome/120',  '2026-03-02 08:00:00'),
    (1014, 1, 102, 'POST',   '/api/orders',                201, 130,   512, '10.0.1.11', 'Mozilla/5.0 Firefox/121', '2026-03-02 08:30:00'),
    (1015, 1, 103, 'GET',    '/api/dashboard',             500, 200,   256, '10.0.1.12', 'Mozilla/5.0 Safari/17',   '2026-03-02 09:00:00'),
    (1016, 1, 104, 'GET',    '/api/reports/daily',         200, 280, 12288, '10.0.1.13', 'Mozilla/5.0 Chrome/120',  '2026-03-02 09:15:00'),
    (1017, 1, 101, 'DELETE', '/api/orders/1014',           204, 110,     0, '10.0.1.10', 'Mozilla/5.0 Chrome/120',  '2026-03-02 10:00:00'),
    -- B Inc (tenant 2)
    (2001, 2, 201, 'GET',    '/api/inventory',             200,  55,  3072, '10.1.1.20', 'Mozilla/5.0 Edge/120',    '2026-03-01 08:00:00'),
    (2002, 2, 201, 'POST',   '/api/inventory/restock',     201, 200,   512, '10.1.1.20', 'Mozilla/5.0 Edge/120',    '2026-03-01 08:05:00'),
    (2003, 2, 202, 'GET',    '/api/sales',                 200,  70,  4096, '10.1.1.21', 'Mozilla/5.0 Chrome/120',  '2026-03-01 08:10:00'),
    (2004, 2, 202, 'PUT',    '/api/sales/2003/close',      200, 115,   256, '10.1.1.21', 'Mozilla/5.0 Chrome/120',  '2026-03-01 08:15:00'),
    (2005, 2, 203, 'GET',    '/api/customers',             200,  40,  2048, '10.1.1.22', 'Mozilla/5.0 Firefox/121', '2026-03-01 08:20:00'),
    (2006, 2, 203, 'POST',   '/api/customers',             201, 160,   512, '10.1.1.22', 'Mozilla/5.0 Firefox/121', '2026-03-01 08:25:00'),
    (2007, 2, 201, 'GET',    '/api/reports/weekly',        200, 420, 20480, '10.1.1.20', 'Mozilla/5.0 Edge/120',    '2026-03-01 09:00:00'),
    (2008, 2, 202, 'DELETE', '/api/inventory/expired',     204, 180,     0, '10.1.1.21', 'Mozilla/5.0 Chrome/120',  '2026-03-01 09:30:00'),
    (2009, 2, 203, 'GET',    '/api/customers?page=3',      200,  45,  2048, '10.1.1.22', 'Mozilla/5.0 Firefox/121', '2026-03-01 10:00:00'),
    (2010, 2, 201, 'PUT',    '/api/inventory/101',         200,  95,   256, '10.1.1.20', 'Mozilla/5.0 Edge/120',    '2026-03-01 10:30:00'),
    (2011, 2, 202, 'POST',   '/api/sales',                 400,  30,   128, '10.1.1.21', 'Mozilla/5.0 Chrome/120',  '2026-03-02 08:00:00'),
    (2012, 2, 203, 'GET',    '/api/reports/monthly',       200, 510, 24576, '10.1.1.22', 'Mozilla/5.0 Firefox/121', '2026-03-02 08:30:00'),
    (2013, 2, 201, 'POST',   '/api/auth/logout',           200,  18,    64, '10.1.1.20', 'Mozilla/5.0 Edge/120',    '2026-03-02 09:00:00'),
    (2014, 2, 202, 'GET',    '/api/sales?status=open',     200,  80,  3072, '10.1.1.21', 'Mozilla/5.0 Chrome/120',  '2026-03-02 09:30:00'),
    -- C Inc (tenant 3)
    (3001, 3, 301, 'GET',    '/api/tickets',               200,  65,  4096, '10.2.1.30', 'Mozilla/5.0 Chrome/120',  '2026-03-01 07:00:00'),
    (3002, 3, 301, 'POST',   '/api/tickets',               201, 140,   512, '10.2.1.30', 'Mozilla/5.0 Chrome/120',  '2026-03-01 07:05:00'),
    (3003, 3, 302, 'GET',    '/api/tickets/3002',          200,  35,  1024, '10.2.1.31', 'Mozilla/5.0 Safari/17',   '2026-03-01 07:10:00'),
    (3004, 3, 302, 'PUT',    '/api/tickets/3002',          200, 105,   512, '10.2.1.31', 'Mozilla/5.0 Safari/17',   '2026-03-01 07:15:00'),
    (3005, 3, 303, 'GET',    '/api/dashboard',             200,  55,  8192, '10.2.1.32', 'Mozilla/5.0 Firefox/121', '2026-03-01 07:20:00'),
    (3006, 3, 303, 'POST',   '/api/tickets/3002/notes',    201,  90,   256, '10.2.1.32', 'Mozilla/5.0 Firefox/121', '2026-03-01 07:25:00'),
    (3007, 3, 301, 'GET',    '/api/reports/sla',           200, 380, 16384, '10.2.1.30', 'Mozilla/5.0 Chrome/120',  '2026-03-01 08:00:00'),
    (3008, 3, 302, 'DELETE', '/api/tickets/3000',          204, 120,     0, '10.2.1.31', 'Mozilla/5.0 Safari/17',   '2026-03-01 08:30:00'),
    (3009, 3, 303, 'GET',    '/api/tickets?status=open',   200,  75,  3072, '10.2.1.32', 'Mozilla/5.0 Firefox/121', '2026-03-01 09:00:00'),
    (3010, 3, 301, 'PUT',    '/api/users/301',             200,  85,   512, '10.2.1.30', 'Mozilla/5.0 Chrome/120',  '2026-03-01 09:30:00'),
    (3011, 3, 302, 'POST',   '/api/tickets',               201, 155,   512, '10.2.1.31', 'Mozilla/5.0 Safari/17',   '2026-03-02 07:00:00'),
    (3012, 3, 303, 'GET',    '/api/reports/monthly',       200, 490, 20480, '10.2.1.32', 'Mozilla/5.0 Firefox/121', '2026-03-02 07:30:00'),
    (3013, 3, 301, 'GET',    '/api/tickets?priority=high', 200,  95,  4096, '10.2.1.30', 'Mozilla/5.0 Chrome/120',  '2026-03-02 08:00:00'),
    (3014, 3, 302, 'POST',   '/api/auth/logout',           200,  22,    64, '10.2.1.31', 'Mozilla/5.0 Safari/17',   '2026-03-02 08:30:00'),
    (3015, 3, 303, 'GET',    '/api/dashboard',             503, 180,   128, '10.2.1.32', 'Mozilla/5.0 Firefox/121', '2026-03-02 09:00:00'),
    (3016, 3, 301, 'PUT',    '/api/tickets/3011',          200, 100,   512, '10.2.1.30', 'Mozilla/5.0 Chrome/120',  '2026-03-02 09:30:00');

-- ---------------------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------------------
SELECT 'tenant'      AS tbl, COUNT(*) AS rows FROM demo_catalog.main.tenant
UNION ALL
SELECT 'user',              COUNT(*) FROM demo_catalog.main."user"
UNION ALL
SELECT 'transaction',       COUNT(*) FROM demo_catalog.main."transaction";
