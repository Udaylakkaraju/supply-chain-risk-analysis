-- =============================================================================
-- 03_validate_outputs.sql
-- Purpose   : Sanity-check row counts and SLA flag quality after mart rebuild.
-- Input     : All five mart_ tables
-- Run order : 3 of 3  (after 02_build_powerbi_marts.sql)
-- =============================================================================

-- Quick checks after rebuilding the staging table and Power BI marts.

SELECT
  'stg_orders' AS table_name,
  COUNT(*) AS row_count
FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`

UNION ALL
SELECT 'mart_executive_kpis', COUNT(*)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_executive_kpis`

UNION ALL
SELECT 'mart_profit_priority', COUNT(*)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority`

UNION ALL
SELECT 'mart_shipping_mode_performance', COUNT(*)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_shipping_mode_performance`

UNION ALL
SELECT 'mart_lane_reliability', COUNT(*)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`

UNION ALL
SELECT 'mart_market_efficiency', COUNT(*)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency`;

SELECT
  COUNT(*) AS total_orders,
  COUNTIF(sla_breached = 'Yes') AS breached_orders,
  COUNTIF(sla_breached = 'No') AS non_breached_orders,
  COUNTIF(sla_breached IS NULL) AS missing_sla_flag
FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`;

SELECT
  action_category,
  COUNT(*) AS lane_count,
  COUNTIF(profit_at_risk IS NULL OR breach_rate_pct IS NULL OR delay_sd IS NULL) AS incomplete_lanes
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`
GROUP BY action_category
ORDER BY action_category;
