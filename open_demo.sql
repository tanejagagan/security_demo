-- Load DazzleDuck extension
--INSTALL dazzleduck FROM community;
LOAD '/tmp/dazzleduck.duckdb_extension';
 

-- Set tenant context (change this to switch tenants)
SET VARIABLE tenant_id = 1;

-- Refresh JWT tokens (they expire, so re-login each session)
SET VARIABLE tenant_token = (
    SELECT dd_login(
        'http://localhost:8082', 'admin', 'admin',
        '{"database":"ducklake_catalog","schema":"main","table":"tenant","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);

SET VARIABLE user_token = (
    SELECT dd_login(
        'http://localhost:8082', 'admin', 'admin',
        '{"database":"ducklake_catalog","schema":"main","table":"user","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);

SET VARIABLE transaction_token = (
    SELECT dd_login(
        'http://localhost:8082', 'admin', 'admin',
        '{"database":"ducklake_catalog","schema":"main","table":"transaction","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);

SET VARIABLE configuration_token = (
    SELECT dd_login(
        'http://localhost:8082', 'admin', 'admin',
        '{"database":"pg_catalog","schema":"public","table":"configuration","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);
