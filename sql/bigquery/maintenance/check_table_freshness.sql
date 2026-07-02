-- =============================================================================
-- check_table_freshness.sql
-- Purpose : See when each table in supply_chain_analytics was last actually
--           built in BigQuery (creation_time), vs. relying on assumptions
--           about whether the .sql files in this repo have been run yet.
--           Run this in the BigQuery console.
-- =============================================================================
SELECT
  table_name,
  creation_time AS last_built_at,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), creation_time, HOUR) AS hours_ago
FROM `supply-chain-analysis-492322.supply_chain_analytics.INFORMATION_SCHEMA.TABLES`
ORDER BY creation_time DESC;
