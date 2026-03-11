INSTALL arrow FROM community;
LOAD arrow;
INSTALL ducklake;
LOAD ducklake;

-- Attach demo_catalog (read-only consumer)
ATTACH 'ducklake:warehouse/metadata/demo_catalog.duckdb' AS demo_catalog (DATA_PATH 'warehouse/data/demo_catalog',  OVERRIDE_DATA_PATH TRUE);
