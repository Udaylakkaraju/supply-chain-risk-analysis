-- =============================================================================
-- 02_build_powerbi_marts.sql
-- Purpose   : Build five analytics tables that Power BI connects to directly.
-- Input     : supply_chain_analytics.stg_orders
-- Outputs   : mart_executive_kpis, mart_profit_priority,
--             mart_shipping_mode_performance, mart_lane_reliability,
--             mart_market_efficiency
-- Techniques: CTEs, NTILE (profit quartiling + 3-dimension lane classification),
--             STDDEV_POP (delay variability), RANK() OVER, SUM() OVER
--             (share calculations), SAFE_DIVIDE, COUNTIF, CASE classification.
-- Run order : 2 of 3  (after 01_build_stg_orders.sql)
-- =============================================================================

CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_executive_kpis` AS
WITH orders AS (
  SELECT *
  FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
  WHERE sla_breached IN ('Yes', 'No')
),
profit_quartiles AS (
  SELECT
    *,
    NTILE(4) OVER (ORDER BY order_profit_per_order DESC) AS profit_quartile
  FROM orders
),
lane_summary AS (
  SELECT
    market,
    shipping_mode,
    COUNT(*) AS order_count,
    COUNTIF(sla_breached = 'Yes') AS breach_count,
    STDDEV_POP(delay_days) AS delay_sd
  FROM orders
  GROUP BY market, shipping_mode
  HAVING order_count >= 1000
),
top_unstable_lanes AS (
  SELECT breach_count
  FROM lane_summary
  ORDER BY delay_sd DESC
  LIMIT 5
)
SELECT
  COUNT(*) AS total_orders,
  COUNTIF(sla_breached = 'Yes') AS breached_orders,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2) AS breach_rate_pct,
  ROUND(SUM(order_profit_per_order), 2) AS total_profit,
  ROUND(SUM(IF(sla_breached = 'Yes', profit_at_risk, 0)), 2) AS total_profit_at_risk,
  ROUND((
    SELECT SUM(profit_at_risk)
    FROM profit_quartiles
    WHERE profit_quartile = 1
      AND sla_breached = 'Yes'
  ), 2) AS high_value_profit_at_risk,
  ROUND(100 * SAFE_DIVIDE(
    (SELECT SUM(breach_count) FROM top_unstable_lanes),
    (SELECT SUM(breach_count) FROM lane_summary)
  ), 2) AS top_5_unstable_lane_breach_share_pct
FROM orders;

CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority` AS
WITH scored_orders AS (
  SELECT
    order_item_id,
    order_profit_per_order,
    delay_days,
    sla_breached,
    profit_at_risk,
    NTILE(4) OVER (ORDER BY order_profit_per_order DESC) AS profit_quartile
  FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
  WHERE sla_breached IN ('Yes', 'No')
),
quartile_summary AS (
  SELECT
    profit_quartile,
    COUNT(*) AS order_count,
    COUNTIF(sla_breached = 'Yes') AS breach_count,
    AVG(delay_days) AS avg_delay_days,
    SUM(order_profit_per_order) AS total_profit,
    SUM(IF(sla_breached = 'Yes', profit_at_risk, 0)) AS profit_at_risk
  FROM scored_orders
  GROUP BY profit_quartile
)
SELECT
  profit_quartile,
  CASE
    WHEN profit_quartile = 1 THEN 'Highest profit'
    WHEN profit_quartile = 4 THEN 'Lowest profit'
    ELSE 'Middle profit'
  END AS profit_tier,
  order_count,
  breach_count,
  ROUND(100 * SAFE_DIVIDE(breach_count, order_count), 2) AS breach_rate_pct,
  ROUND(avg_delay_days, 2) AS avg_delay_days,
  ROUND(total_profit, 2) AS total_profit,
  ROUND(profit_at_risk, 2) AS profit_at_risk
FROM quartile_summary
ORDER BY profit_quartile;

CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_shipping_mode_performance` AS
SELECT
  shipping_mode,
  COUNT(*) AS order_count,
  COUNTIF(sla_breached = 'Yes') AS breach_count,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2) AS breach_rate_pct,
  ROUND(AVG(days_for_shipment_scheduled), 2) AS avg_scheduled_days,
  ROUND(AVG(days_for_shipping_real), 2) AS avg_actual_days,
  ROUND(AVG(delay_days), 2) AS avg_delay_days,
  ROUND(SUM(IF(sla_breached = 'Yes', profit_at_risk, 0)), 2) AS profit_at_risk,
  CASE
    WHEN SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)) >= 0.70 THEN 'High risk'
    WHEN SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)) >= 0.50 THEN 'Watch'
    ELSE 'Stable'
  END AS performance_band,
  CASE
    WHEN shipping_mode = 'First Class' THEN 'Structural SLA artifact - disclose separately'
    WHEN shipping_mode = 'Second Class' THEN 'Primary service-promise concern'
    ELSE 'Operational comparison'
  END AS interpretation_note
FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
WHERE sla_breached IN ('Yes', 'No')
GROUP BY shipping_mode
ORDER BY breach_rate_pct DESC;

CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability` AS
WITH lane_summary AS (
  SELECT
    market,
    shipping_mode,
    COUNT(*) AS order_count,
    COUNTIF(sla_breached = 'Yes') AS breach_count,
    AVG(delay_days) AS avg_delay_days,
    STDDEV_POP(delay_days) AS delay_sd,
    SUM(IF(sla_breached = 'Yes', profit_at_risk, 0)) AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
  WHERE sla_breached IN ('Yes', 'No')
  GROUP BY market, shipping_mode
),
ranked_lanes AS (
  SELECT
    *,
    SAFE_DIVIDE(breach_count, order_count) AS breach_rate,
    SAFE_DIVIDE(breach_count, SUM(breach_count) OVER ()) AS breach_share,
    RANK() OVER (ORDER BY profit_at_risk DESC, breach_count DESC) AS profit_risk_rank
  FROM lane_summary
  WHERE order_count >= 1000
),
priority_bands AS (
  SELECT
    *,
    NTILE(2) OVER (ORDER BY profit_at_risk DESC) AS profit_risk_band,
    NTILE(2) OVER (ORDER BY breach_rate DESC) AS breach_rate_band,
    NTILE(2) OVER (ORDER BY delay_sd DESC) AS variability_band
  FROM ranked_lanes
)
SELECT
  market,
  shipping_mode,
  order_count,
  breach_count,
  ROUND(100 * breach_rate, 2) AS breach_rate_pct,
  ROUND(100 * breach_share, 2) AS breach_share_pct,
  ROUND(avg_delay_days, 2) AS avg_delay_days,
  ROUND(delay_sd, 2) AS delay_sd,
  ROUND(profit_at_risk, 2) AS profit_at_risk,
  profit_risk_rank,
  CASE
    WHEN shipping_mode = 'First Class' THEN 'Monitor'
    WHEN profit_risk_band = 1 AND breach_rate_band = 1 THEN 'Protect'
    WHEN variability_band = 1 THEN 'Stabilize'
    WHEN profit_risk_band = 1 OR breach_rate_band = 1 THEN 'Monitor'
    ELSE 'Maintain'
  END AS action_category
FROM priority_bands
ORDER BY profit_risk_rank;

CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency` AS
WITH market_summary AS (
  SELECT
    market,
    COUNT(*) AS order_count,
    SUM(order_item_total) AS revenue,
    SUM(order_profit_per_order) AS profit,
    COUNTIF(sla_breached = 'Yes') AS breach_count,
    SUM(IF(sla_breached = 'Yes', profit_at_risk, 0)) AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
  WHERE sla_breached IN ('Yes', 'No')
  GROUP BY market
)
SELECT
  market,
  order_count,
  ROUND(revenue, 2) AS revenue,
  ROUND(profit, 2) AS profit,
  ROUND(100 * SAFE_DIVIDE(profit, revenue), 2) AS margin_pct,
  ROUND(100 * SAFE_DIVIDE(breach_count, order_count), 2) AS breach_rate_pct,
  ROUND(100 * SAFE_DIVIDE(order_count, SUM(order_count) OVER ()), 2) AS volume_share_pct,
  ROUND(100 * SAFE_DIVIDE(profit, SUM(profit) OVER ()), 2) AS profit_share_pct,
  ROUND(
    100 * SAFE_DIVIDE(profit, SUM(profit) OVER ())
    - 100 * SAFE_DIVIDE(order_count, SUM(order_count) OVER ()),
    2
  ) AS efficiency_gap_pct,
  ROUND(profit_at_risk, 2) AS profit_at_risk
FROM market_summary
ORDER BY efficiency_gap_pct DESC;
