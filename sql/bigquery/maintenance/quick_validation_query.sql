-- =============================================================================
-- quick_validation_query.sql
-- Purpose : One-shot validation query for the corrected (SUM-based) profit
--           logic. Run this directly in the BigQuery console against
--           stg_orders. Returns a single row with the real, current numbers
--           needed for the final business recommendations -- total profit,
--           Q1 high-value profit at risk, and top-5 lane breach concentration.
-- =============================================================================

WITH order_grain AS (
  SELECT
    order_id,
    MAX(sla_breached)            AS sla_breached,
    MAX(market)                  AS market,
    MAX(shipping_mode)           AS shipping_mode,
    MAX(delay_days)              AS delay_days,
    SUM(order_profit_per_order)  AS order_profit,          -- corrected: SUM not MAX
    IF(MAX(sla_breached) = 'Yes',
       GREATEST(SUM(order_profit_per_order), 0), 0)        AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
  WHERE sla_breached IN ('Yes', 'No')
  GROUP BY order_id
),
quartiled AS (
  SELECT *, NTILE(4) OVER (ORDER BY order_profit DESC) AS profit_quartile
  FROM order_grain
),
lane_summary AS (
  SELECT
    market, shipping_mode,
    COUNT(*)                      AS order_count,
    COUNTIF(sla_breached='Yes')   AS breach_count,
    SUM(profit_at_risk)           AS profit_at_risk,
    STDDEV_POP(delay_days)        AS delay_sd
  FROM order_grain
  GROUP BY market, shipping_mode
  HAVING COUNT(*) >= 350
),
ranked_lanes AS (
  SELECT *,
    ROW_NUMBER() OVER (
      ORDER BY delay_sd DESC, breach_count DESC, profit_at_risk DESC, market, shipping_mode
    ) AS variability_priority_rank
  FROM lane_summary
)
SELECT
  (SELECT COUNT(*) FROM order_grain)                                   AS total_orders,
  (SELECT COUNTIF(sla_breached='Yes') FROM order_grain)                AS breached_orders,
  (SELECT ROUND(100*SAFE_DIVIDE(COUNTIF(sla_breached='Yes'),COUNT(*)),2) FROM order_grain) AS breach_rate_pct,
  (SELECT ROUND(SUM(order_profit),2) FROM order_grain)                 AS total_profit,
  (SELECT ROUND(SUM(profit_at_risk),2) FROM order_grain)               AS total_profit_at_risk,
  (SELECT ROUND(SUM(profit_at_risk),2) FROM quartiled WHERE profit_quartile=1 AND sla_breached='Yes') AS q1_high_value_profit_at_risk,
  (SELECT COUNT(*) FROM quartiled WHERE profit_quartile=1 AND sla_breached='Yes') AS q1_breached_order_count,
  (SELECT ROUND(100*SAFE_DIVIDE(SUM(IF(variability_priority_rank<=5,breach_count,0)),SUM(breach_count)),2) FROM ranked_lanes) AS top_5_lane_breach_share_pct;
