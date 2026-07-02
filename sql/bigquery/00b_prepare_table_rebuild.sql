-- Prepare known output names for a table-based rebuild.
-- BigQuery cannot CREATE OR REPLACE TABLE over an existing VIEW.
-- This script only removes legacy views with the exact final table names.

DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.int_orders`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_executive_kpis`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_shipping_mode_performance`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_sla_promise_gap`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_monthly_trends`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_customer_segments`;
DROP VIEW IF EXISTS `supply-chain-analysis-492322.supply_chain_analytics.mart_opportunity_scenarios`;
