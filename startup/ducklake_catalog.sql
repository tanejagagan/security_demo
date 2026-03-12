INSTALL arrow FROM community;
LOAD arrow;
INSTALL ducklake;
LOAD ducklake;
INSTALL postgres;
LOAD postgres;

-- Attach DuckLake ducklake_catalog with Postgres metadata backend (READ_ONLY)
ATTACH 'ducklake:postgres:host=postgres port=5432 dbname=ducklake_catalog user=demo password=demo' AS ducklake_catalog
    (DATA_PATH 'warehouse/data/ducklake_catalog', READ_ONLY);

-- Attach PostgreSQL catalog (configuration table)
ATTACH 'host=postgres port=5432 dbname=demo user=demo password=demo' AS pg_catalog (TYPE postgres, READ_ONLY);
