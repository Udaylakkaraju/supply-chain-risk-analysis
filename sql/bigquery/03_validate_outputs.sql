-- =============================================================================
-- 03_validate_outputs.sql
-- Purpose   : Sanity-check row counts, grain, and metric quality after rebuild.
-- Input     : stg_orders, int_orders, and all mart_ tables
-- Run order : last (after 01_build_stg_orders.sql, 01c_build_int_orders.sql,
--             02_build_powerbi_marts.sql, 02b_*, 02c_*)
--
-- NOTE ON BENCHMARK VALUES
-- This script intentionally does NOT hardcode "expected" dollar or percentage
-- figures in the queries themselves. Prior versions embedded comments like
-- "Expected at order grain: ~$2.31M" -- those numbers were never independently
-- re-validated after the MAX -> SUM profit fix and should not be trusted
-- without rerunning these queries. Run every query below, record the actual
-- output, and treat THAT as the source of truth for README/Excel/Power BI.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1. Row counts — verify expected grain at each layer
--    stg_orders  : ~180,519 (item grain)
--    int_orders  : ~65,752  (order grain — one row per order_id)
--    mart_*      : one row per logical grouping (order grain aggregated)
-- ---------------------------------------------------------------------------
SELECT
  'stg_orders'                    AS table_name,
  COUNT(*)                        AS row_count,
  'item grain — expect ~180,519'  AS note
FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`

UNION ALL SELECT 'int_orders',  COUNT(*), 'order grain — expect ~65,752 (one row per order_id)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`

UNION ALL SELECT 'mart_executive_kpis',          COUNT(*), '1 row expected'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_executive_kpis`

UNION ALL SELECT 'mart_profit_priority',         COUNT(*), '4 rows expected (profit tiers)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority`

UNION ALL SELECT 'mart_shipping_mode_performance', COUNT(*), '4 rows expected (modes)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_shipping_mode_performance`

UNION ALL SELECT 'mart_lane_reliability',        COUNT(*), '14-20 rows expected (lanes)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`

UNION ALL SELECT 'mart_market_efficiency',       COUNT(*), '5 rows expected (markets)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency`

UNION ALL SELECT 'mart_sla_promise_gap',         COUNT(*), '4 rows expected (modes)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_sla_promise_gap`

UNION ALL SELECT 'mart_customer_segments',       COUNT(*), '3 rows expected (Consumer/Corporate/Home Office)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_customer_segments`

UNION ALL SELECT 'mart_opportunity_scenarios',   COUNT(*), '3 rows expected (one per scenario)'
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_opportunity_scenarios`;


-- ---------------------------------------------------------------------------
-- 2. Order grain verification
--    Confirm distinct order count and that item grain is ~2.7x order count.
-- ---------------------------------------------------------------------------
SELECT
  COUNT(*)                                      AS total_item_rows,
  COUNT(DISTINCT order_id)                      AS distinct_orders,
  ROUND(COUNT(*) / COUNT(DISTINCT order_id), 2) AS avg_items_per_order,
  COUNTIF(sla_breached IS NULL)                 AS missing_sla_flag,
  COUNTIF(sla_breached = 'Yes')                 AS breached_items,
  COUNTIF(sla_breached = 'No')                  AS non_breached_items
FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`;


-- ---------------------------------------------------------------------------
-- 3. SLA breach rate at ORDER grain (from int_orders directly — no recompute)
--    Record the actual output. Prior documented figure was ~57.33%; confirm
--    this still holds after the int_orders rebuild (it should, since the SLA
--    flag aggregation logic itself did not change, only the profit logic).
-- ---------------------------------------------------------------------------
SELECT
  COUNT(*)                                                                AS total_orders,
  COUNTIF(sla_breached = 'Yes')                                          AS sla_breached_orders,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2)  AS sla_breach_rate_pct
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`;


-- ---------------------------------------------------------------------------
-- 4. profit_at_risk quality check
--    All values must be >= 0 after applying GREATEST(order_profit, 0).
--    Negative count should be 0 in every mart.
-- ---------------------------------------------------------------------------
SELECT
  'int_orders'                     AS mart,
  COUNT(*)                         AS row_count,
  COUNTIF(profit_at_risk < 0)      AS negative_profit_at_risk_rows,
  ROUND(SUM(profit_at_risk), 2)    AS total_profit_at_risk
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`

UNION ALL
SELECT
  'mart_profit_priority',
  COUNT(*),
  COUNTIF(profit_at_risk_usd < 0),
  ROUND(SUM(profit_at_risk_usd), 2)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority`

UNION ALL
SELECT
  'mart_lane_reliability',
  COUNT(*),
  COUNTIF(profit_at_risk_usd < 0),
  ROUND(SUM(profit_at_risk_usd), 2)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`

UNION ALL
SELECT
  'mart_market_efficiency',
  COUNT(*),
  COUNTIF(profit_at_risk_usd < 0),
  ROUND(SUM(profit_at_risk_usd), 2)
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency`;


-- ---------------------------------------------------------------------------
-- 5. High-value (Q1) profit at risk cross-check
--    mart_executive_kpis.high_value_profit_at_risk_usd should match this exactly.
--    Run this and RECORD the actual figure -- do not assume it matches any
--    previously-cited number ($1.01M, $2.31M, $2.77M, etc.) until you see it
--    here. All three of those prior figures came from different (and in two
--    cases incorrect) aggregation logic.
-- ---------------------------------------------------------------------------
WITH quartiled AS (
  SELECT
    *,
    NTILE(4) OVER (ORDER BY order_profit DESC) AS profit_quartile
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
)
SELECT
  ROUND(SUM(profit_at_risk), 2)   AS q1_high_value_profit_at_risk_usd,
  COUNT(*)                        AS q1_order_count,
  'Compare to mart_executive_kpis.high_value_profit_at_risk_usd -- must match exactly' AS note
FROM quartiled
WHERE profit_quartile = 1
  AND sla_breached = 'Yes';


-- ---------------------------------------------------------------------------
-- 6. Top-5 unstable lane breach share cross-check (deterministic ranking)
--    Definition: top 5 lanes by variability_priority_rank (delay_sd DESC,
--    with explicit tiebreakers — see 02_build_powerbi_marts.sql). This is the
--    ONLY ranking that should be used for "top 5 most unstable lanes" claims.
--    Do not substitute profit_risk_rank <= 5 for this claim anywhere.
-- ---------------------------------------------------------------------------
SELECT
  ROUND(100 * SAFE_DIVIDE(
    SUM(IF(variability_priority_rank <= 5, sla_breached_orders, 0)),
    SUM(sla_breached_orders)
  ), 2)                            AS top_5_unstable_breach_share_pct,
  'Record this figure and use it consistently across README, DAX, and Power BI' AS note
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`;


-- ---------------------------------------------------------------------------
-- 7. Lane action category distribution
--    Sanity check: no lane should have NULL in key fields. First Class should
--    appear under 'Review SLA Definition', not folded into Monitor.
-- ---------------------------------------------------------------------------
SELECT
  recommended_action,
  COUNT(*)                                                                AS lane_count,
  ROUND(AVG(sla_breach_rate_pct), 2)                                      AS avg_sla_breach_rate_pct,
  ROUND(SUM(profit_at_risk_usd), 2)                                       AS total_profit_at_risk_usd,
  COUNTIF(profit_at_risk_usd IS NULL OR sla_breach_rate_pct IS NULL
          OR delivery_variability_days IS NULL)                           AS incomplete_lanes
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`
GROUP BY recommended_action
ORDER BY recommended_action;


-- ---------------------------------------------------------------------------
-- 8. mart_opportunity_scenarios sanity check
--    Confirm 3 rows, no nulls in the core numeric columns, and that the
--    caveat text is present (so the "modeled, not realized" framing survives
--    into every downstream export).
-- ---------------------------------------------------------------------------
SELECT
  scenario,
  orders_in_scope,
  modeled_breaches_addressed,
  modeled_profit_exposure_usd,
  supporting_metric_label,
  supporting_metric_value,
  caveat IS NOT NULL AND LENGTH(caveat) > 0 AS has_caveat_text
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_opportunity_scenarios`
ORDER BY scenario;


-- ---------------------------------------------------------------------------
-- 9. mart_customer_segments sanity check
-- ---------------------------------------------------------------------------
SELECT
  customer_segment,
  orders,
  sla_breach_rate_pct,
  profit_usd,
  profit_at_risk_usd,
  order_volume_share_pct,
  profit_share_pct
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_customer_segments`
ORDER BY profit_usd DESC;
