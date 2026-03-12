-- INSTALL dazzleduck FROM community;
-- LOAD dazzleduck;
LOAD '/Users/tanejagagan/git/dazzleduck-sql-duckdb/build/release/extension/dazzleduck/dazzleduck.duckdb_extension';

-- Set tenant_id to filter data -- change this value to switch tenant context
SET VARIABLE tenant_id = 1;

-- Per-table JWT tokens with tenant_id filter embedded in claims
SET VARIABLE tenant_token = (
    SELECT dd_login(
        'http://localhost:8081',
        'admin',
        'admin',
        '{"database":"ducklake_catalog","schema":"main","table":"tenant","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);

SET VARIABLE user_token = (
    SELECT dd_login(
        'http://localhost:8081',
        'admin',
        'admin',
        '{"database":"ducklake_catalog","schema":"main","table":"user","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);

SET VARIABLE transaction_token = (
    SELECT dd_login(
        'http://localhost:8081',
        'admin',
        'admin',
        '{"database":"ducklake_catalog","schema":"main","table":"transaction","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);

SET VARIABLE configuration_token = (
    SELECT dd_login(
        'http://localhost:8081',
        'admin',
        'admin',
        '{"database":"pg_catalog","schema":"public","table":"configuration","filter":"tenant_id = ' || CAST(getvariable('tenant_id') AS VARCHAR) || '"}'
    )
);

CREATE OR REPLACE VIEW tenant AS
    SELECT * FROM dd_read_arrow(
        'http://localhost:8081',
        source_table := 'ducklake_catalog.main.tenant',
        auth_token := getvariable('tenant_token')
    );

CREATE OR REPLACE VIEW "user" AS
    SELECT * FROM dd_read_arrow(
        'http://localhost:8081',
        source_table := 'ducklake_catalog.main.user',
        auth_token := getvariable('user_token')
    );

CREATE OR REPLACE VIEW "transaction" AS
    SELECT * FROM dd_read_arrow(
        'http://localhost:8081',
        source_table := 'ducklake_catalog.main.transaction',
        auth_token := getvariable('transaction_token')
    );

CREATE OR REPLACE VIEW configuration AS
    SELECT * FROM dd_read_arrow(
        'http://localhost:8081',
        source_table := 'pg_catalog.public.configuration',
        auth_token := getvariable('configuration_token')
    );
