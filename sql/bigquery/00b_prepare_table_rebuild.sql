-- Prepare known output names for a table-based rebuild.
-- BigQuery cannot CREATE OR REPLACE TABLE over an existing VIEW.
-- This script only removes legacy views with the exact final table names.

DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_executive_kpis`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_shipping_mode_performance`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency`;
