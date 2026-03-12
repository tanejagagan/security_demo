INSTALL ducklake;
LOAD ducklake;
INSTALL postgres;
LOAD postgres;

-- Attach DuckLake with Postgres metadata backend
-- Requires: docker-compose up (postgres on localhost:5432)
ATTACH 'ducklake:postgres:host=localhost port=5432 dbname=ducklake_catalog user=demo password=demo' AS ducklake_catalog
    (DATA_PATH 'warehouse/data/ducklake_catalog');
