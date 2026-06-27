-- Review old BigQuery objects before deleting anything.
-- Step 1: Run this query and inspect the output.

SELECT
  table_schema,
  table_name,
  table_type,
  creation_time
FROM `supply-chain-analysis-492322.region-us`.INFORMATION_SCHEMA.TABLES
WHERE table_schema IN ('supply_chain_raw', 'supply_chain_analytics')
ORDER BY table_schema, table_name;

-- Step 2: Delete only confirmed old objects.
-- Keep these final tables:
--   supply_chain_raw.orders
--   supply_chain_analytics.stg_orders
--   supply_chain_analytics.mart_executive_kpis
--   supply_chain_analytics.mart_profit_priority
--   supply_chain_analytics.mart_shipping_mode_performance
--   supply_chain_analytics.mart_lane_reliability
--   supply_chain_analytics.mart_market_efficiency
--   supply_chain_analytics.sla_breach_risk_model_v2
--
-- Note:
-- `00b_prepare_table_rebuild.sql` only drops legacy views with these exact final
-- output names so CREATE OR REPLACE TABLE can rebuild them as tables.
--
-- Example cleanup commands. Uncomment only after confirming the table/model is old:
--
-- DROP TABLE IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.old_table_name`;
-- DROP MODEL IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.old_model_name`;
