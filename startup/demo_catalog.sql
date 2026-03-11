INSTALL arrow FROM community;
LOAD arrow;
INSTALL ducklake;
LOAD ducklake;
INSTALL postgres;
LOAD postgres;

-- Attach DuckLake demo_catalog (read-only consumer)
ATTACH 'ducklake:/workspace/warehouse/metadata/demo_catalog.duckdb' AS demo_catalog (DATA_PATH '/workspace/warehouse/data/demo_catalog', READ_ONLY, OVERRIDE_DATA_PATH TRUE);

-- Attach PostgreSQL catalog (configuration table)
ATTACH 'host=postgres port=5432 dbname=demo user=demo password=demo' AS pg_catalog (TYPE postgres, READ_ONLY);
