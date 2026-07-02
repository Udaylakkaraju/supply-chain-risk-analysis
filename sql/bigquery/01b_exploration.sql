-- Exploratory analysis from basic validation to intermediate prioritization.
-- Run after 01c_build_int_orders.sql.

-- 1. Confirm source and analytical grain.
SELECT
  COUNT(*) AS order_item_rows,
  COUNT(DISTINCT order_id) AS distinct_orders,
  COUNT(DISTINCT order_item_id) AS distinct_order_items
FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`;

SELECT
  COUNT(*) AS total_orders,
  COUNTIF(sla_breached = 'Yes') AS breached_orders,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2) AS breach_rate_pct,
  ROUND(SUM(order_profit), 2) AS total_profit,
  ROUND(SUM(profit_at_risk), 2) AS positive_profit_exposure
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`;

-- 2. Compare promised and actual performance by shipping mode.
SELECT
  shipping_mode,
  COUNT(*) AS order_count,
  COUNTIF(sla_breached = 'Yes') AS breach_count,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2) AS breach_rate_pct,
  ROUND(AVG(scheduled_days), 2) AS avg_scheduled_days,
  ROUND(AVG(actual_days), 2) AS avg_actual_days,
  ROUND(AVG(delay_days), 2) AS avg_delay_days,
  ROUND(SUM(profit_at_risk), 2) AS profit_at_risk
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
GROUP BY shipping_mode
ORDER BY breach_rate_pct DESC;

-- 3. Test whether high-value orders receive better protection.
WITH scored_orders AS (
  SELECT
    *,
    NTILE(4) OVER (ORDER BY order_profit DESC) AS profit_quartile
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
)
SELECT
  profit_quartile,
  COUNT(*) AS order_count,
  COUNTIF(sla_breached = 'Yes') AS breach_count,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2) AS breach_rate_pct,
  ROUND(AVG(delay_days), 2) AS avg_delay_days,
  ROUND(SUM(order_profit), 2) AS total_profit,
  ROUND(SUM(profit_at_risk), 2) AS profit_at_risk
FROM scored_orders
GROUP BY profit_quartile
ORDER BY profit_quartile;

-- 4. Compare market volume, economics, and service performance.
WITH market_summary AS (
  SELECT
    market,
    COUNT(*) AS order_count,
    SUM(order_revenue) AS revenue,
    SUM(order_profit) AS profit,
    COUNTIF(sla_breached = 'Yes') AS breach_count,
    SUM(profit_at_risk) AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  GROUP BY market
)
SELECT
  market,
  order_count,
  ROUND(profit, 2) AS profit,
  ROUND(100 * SAFE_DIVIDE(profit, revenue), 2) AS margin_pct,
  ROUND(100 * SAFE_DIVIDE(breach_count, order_count), 2) AS breach_rate_pct,
  ROUND(100 * SAFE_DIVIDE(order_count, SUM(order_count) OVER ()), 2) AS volume_share_pct,
  ROUND(100 * SAFE_DIVIDE(profit, SUM(profit) OVER ()), 2) AS profit_share_pct,
  ROUND(profit_at_risk, 2) AS profit_at_risk
FROM market_summary
ORDER BY profit DESC;

-- 5. Rank operational lanes by delivery variability.
WITH lane_summary AS (
  SELECT
    market,
    shipping_mode,
    COUNT(*) AS order_count,
    COUNTIF(sla_breached = 'Yes') AS breach_count,
    STDDEV_POP(delay_days) AS delay_sd,
    SUM(profit_at_risk) AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  GROUP BY market, shipping_mode
  HAVING COUNT(*) >= 350
)
SELECT
  *,
  ROUND(100 * SAFE_DIVIDE(breach_count, order_count), 2) AS breach_rate_pct,
  ROW_NUMBER() OVER (
    ORDER BY delay_sd DESC, breach_count DESC, profit_at_risk DESC,
             market, shipping_mode
  ) AS variability_priority_rank
FROM lane_summary
ORDER BY variability_priority_rank;

-- 6. Customer segments are a supporting drill-down.
SELECT
  customer_segment,
  COUNT(*) AS order_count,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2) AS breach_rate_pct,
  ROUND(SUM(order_profit), 2) AS profit,
  ROUND(SUM(profit_at_risk), 2) AS profit_at_risk
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
GROUP BY customer_segment
ORDER BY profit DESC;
