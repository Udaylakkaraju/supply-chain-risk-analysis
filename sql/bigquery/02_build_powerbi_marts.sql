-- =============================================================================
-- 02_build_powerbi_marts.sql
-- Purpose   : Build the analytics tables that Power BI connects to directly.
-- Input     : supply_chain_analytics.int_orders  (order grain, built by
--             01c_build_int_orders.sql -- run that script first)
-- Outputs   : mart_executive_kpis, mart_profit_priority,
--             mart_shipping_mode_performance, mart_lane_reliability,
--             mart_market_efficiency, mart_sla_promise_gap,
--             mart_monthly_trends
-- Techniques: NTILE (profit quartiling + 2-dimension lane classification),
--             STDDEV_POP (delay variability), RANK()/ROW_NUMBER() OVER,
--             SUM() OVER (share calculations), SAFE_DIVIDE, COUNTIF,
--             CASE classification.
-- Run order : 2 of pipeline (after 01_build_stg_orders.sql AND
--             01c_build_int_orders.sql)
--
-- MODEL CHANGE FROM PRIOR VERSION
-- Every mart previously repeated its own order_grain CTE with
-- MAX(order_profit_per_order). That was the bug: order_profit_per_order is
-- additive across an order's item rows, not a repeated constant, so MAX()
-- silently discarded profit for any order where the source data carries
-- per-item profit splits. All marts now read from int_orders (built once, in
-- 01c_build_int_orders.sql), which uses SUM(order_profit_per_order) per
-- order. Fixing it once upstream means every mart is correct by construction
-- instead of needing the same fix repeated seven times.
--
-- PROFIT AT RISK DEFINITION (unchanged, now computed once in int_orders)
--   IF(sla_breached = 'Yes', GREATEST(order_profit, 0), 0)
-- Only positive-profit orders that missed SLA are counted as recoverable
-- exposure. Loss orders that breach SLA are an operational problem but not
-- "profit at risk" in the sense of recoverable value.
--
-- DETERMINISTIC LANE RANKING
-- delay_sd ties are common across lanes (several lanes share very similar
-- delivery variability), so a bare RANK()/ORDER BY delay_sd DESC is not
-- reproducible run-to-run if BigQuery's tie-breaking order shifts. Every lane
-- ranking below uses ROW_NUMBER() with an explicit, fully-deterministic
-- tiebreak chain: delay_sd DESC, breach_count DESC, profit_at_risk DESC,
-- market, shipping_mode. variability_priority_rank is the column to use for
-- any "top 5 most unstable lanes" claim -- profit_risk_rank measures a
-- different thing (dollar exposure) and must not be used interchangeably.
--
-- COLUMN NAMING (migrated 2026-07-01)
-- Earlier versions of this file exposed both a legacy field name and a
-- business-friendly alias for every metric, to avoid breaking a PBIX that
-- was still bound to the old names. That migration is now complete: every
-- mart below exposes ONE canonical, business-readable name per metric
-- (matching docs/powerbi_dax_measures.md), and the legacy duplicates have
-- been dropped. If you rebuild from this file, refresh the PBIX and Excel
-- workbook, then re-bind any visual/formula still pointing at an old field
-- name (see the migration table in README.md / docs/SQL_POWERBI_GUIDE.md).
-- =============================================================================


-- =============================================================================
-- 1. mart_executive_kpis  (1 row — headline KPIs for Power BI cards)
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_executive_kpis` AS
WITH profit_quartiles AS (
  SELECT
    *,
    NTILE(4) OVER (ORDER BY order_profit DESC) AS profit_quartile
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
),
lane_summary AS (
  -- Market x shipping-mode lanes with enough volume to be meaningful.
  SELECT
    market,
    shipping_mode,
    COUNT(*)                                AS order_count,
    COUNTIF(sla_breached = 'Yes')           AS breach_count,
    SUM(profit_at_risk)                     AS profit_at_risk,
    STDDEV_POP(delay_days)                  AS delay_sd
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  GROUP BY market, shipping_mode
  HAVING COUNT(*) >= 350
),
ranked_lanes AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      ORDER BY delay_sd DESC, breach_count DESC, profit_at_risk DESC,
               market, shipping_mode
    ) AS variability_priority_rank
  FROM lane_summary
),
top_unstable_lanes AS (
  SELECT breach_count
  FROM ranked_lanes
  WHERE variability_priority_rank <= 5
)
SELECT
  COUNT(*)                                                                      AS total_orders,
  COUNTIF(sla_breached = 'Yes')                                                 AS sla_breached_orders,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2)          AS sla_breach_rate_pct,
  ROUND(SUM(order_profit), 2)                                                   AS total_profit_usd,
  ROUND(SUM(profit_at_risk), 2)                                                 AS profit_at_risk_usd,
  ROUND((
    SELECT SUM(profit_at_risk)
    FROM profit_quartiles
    WHERE profit_quartile = 1
      AND sla_breached = 'Yes'
  ), 2)                                                                          AS high_value_profit_at_risk_usd,
  ROUND(100 * SAFE_DIVIDE(
    (SELECT SUM(breach_count) FROM top_unstable_lanes),
    (SELECT SUM(breach_count) FROM lane_summary)
  ), 2)                                                                          AS top_5_priority_lane_breach_share_pct
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`;


-- =============================================================================
-- 2. mart_profit_priority  (4 rows — one per profit quartile)
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority` AS
WITH scored_orders AS (
  SELECT
    *,
    NTILE(4) OVER (ORDER BY order_profit DESC) AS profit_quartile
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
),
quartile_summary AS (
  SELECT
    profit_quartile,
    COUNT(*)                                AS order_count,
    COUNTIF(sla_breached = 'Yes')           AS breach_count,
    AVG(delay_days)                         AS avg_delay_days,
    SUM(order_profit)                       AS total_profit,
    SUM(profit_at_risk)                     AS profit_at_risk
  FROM scored_orders
  GROUP BY profit_quartile
)
SELECT
  profit_quartile,
  CASE
    WHEN profit_quartile = 1 THEN 'Highest profit'
    WHEN profit_quartile = 2 THEN 'Upper-middle profit'
    WHEN profit_quartile = 3 THEN 'Lower-middle profit'
    WHEN profit_quartile = 4 THEN 'Lowest profit'
  END                                                                           AS profit_tier,
  order_count                                                                    AS orders,
  breach_count                                                                   AS sla_breached_orders,
  ROUND(100 * SAFE_DIVIDE(breach_count, order_count), 2)                       AS sla_breach_rate_pct,
  ROUND(avg_delay_days, 2)                                                      AS avg_days_late,
  ROUND(total_profit, 2)                                                        AS total_profit_usd,
  ROUND(profit_at_risk, 2)                                                      AS profit_at_risk_usd
FROM quartile_summary
ORDER BY profit_quartile;


-- =============================================================================
-- 3. mart_shipping_mode_performance  (4 rows — one per shipping mode)
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_shipping_mode_performance` AS
SELECT
  shipping_mode,
  COUNT(*)                                                                      AS orders,
  COUNTIF(sla_breached = 'Yes')                                                 AS sla_breached_orders,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2)          AS sla_breach_rate_pct,
  ROUND(AVG(scheduled_days), 2)                                                 AS avg_promised_delivery_days,
  ROUND(AVG(actual_days), 2)                                                    AS avg_actual_delivery_days,
  ROUND(AVG(delay_days), 2)                                                     AS avg_days_late,
  ROUND(SUM(profit_at_risk), 2)                                                 AS profit_at_risk_usd,
  CASE
    WHEN SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)) >= 0.70 THEN 'High risk'
    WHEN SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)) >= 0.50 THEN 'Watch'
    ELSE 'Stable'
  END                                                                           AS service_risk_level,
  CASE
    WHEN shipping_mode = 'First Class'   THEN 'Structural SLA artifact - disclose separately; do not treat as operational variability'
    WHEN shipping_mode = 'Second Class'  THEN 'Primary service-promise concern'
    ELSE                                      'Operational comparison'
  END                                                                           AS business_note
FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
GROUP BY shipping_mode
ORDER BY sla_breach_rate_pct DESC;


-- =============================================================================
-- 4. mart_lane_reliability  (~14–20 rows — market × shipping-mode lanes)
--    action_category logic excludes First Class from the threshold bands
--    (NTILE) because its 100% breach rate and zero delay_sd are a dataset/
--    promise-definition artifact, not a genuine operational signal. Including
--    it would mechanically force every other lane's NTILE banding to shift
--    around an artifact. First Class is labelled "Review SLA Definition"
--    instead of being folded into Monitor/Protect/Stabilize/Maintain.
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability` AS
WITH lane_summary AS (
  SELECT
    market,
    shipping_mode,
    COUNT(*)                                AS order_count,
    COUNTIF(sla_breached = 'Yes')           AS breach_count,
    AVG(delay_days)                         AS avg_delay_days,
    STDDEV_POP(delay_days)                  AS delay_sd,
    SUM(profit_at_risk)                     AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  GROUP BY market, shipping_mode
  HAVING COUNT(*) >= 350
),
ranked_lanes AS (
  SELECT
    *,
    SAFE_DIVIDE(breach_count, order_count)                                    AS breach_rate,
    SAFE_DIVIDE(breach_count, SUM(breach_count) OVER ())                      AS breach_share,
    -- profit_risk_rank: lanes most exposed by absolute profit dollars (ties broken deterministically)
    ROW_NUMBER() OVER (
      ORDER BY profit_at_risk DESC, breach_count DESC, market, shipping_mode
    )                                                                          AS profit_risk_rank,
    -- variability_priority_rank: THE definitive ranking for "most unstable lane" claims.
    -- Use this column, not profit_risk_rank, whenever a claim is about variability/instability.
    ROW_NUMBER() OVER (
      ORDER BY delay_sd DESC, breach_count DESC, profit_at_risk DESC, market, shipping_mode
    )                                                                          AS variability_priority_rank
  FROM lane_summary
),
-- NTILE banding excludes First Class so its artifact values don't distort
-- the thresholds used to classify every other lane.
non_artifact_lanes AS (
  SELECT * FROM ranked_lanes WHERE shipping_mode != 'First Class'
),
priority_bands AS (
  SELECT
    order_count, breach_count, market, shipping_mode,  -- join keys / passthrough
    NTILE(2) OVER (ORDER BY profit_at_risk DESC)  AS profit_risk_band,
    NTILE(2) OVER (ORDER BY breach_rate DESC)     AS breach_rate_band,
    NTILE(2) OVER (ORDER BY delay_sd DESC)        AS variability_band
  FROM non_artifact_lanes
)
SELECT
  r.market,
  r.shipping_mode,
  CONCAT(r.market, ' | ', r.shipping_mode)                                     AS operational_lane,
  r.order_count                                                                 AS orders,
  r.breach_count                                                                AS sla_breached_orders,
  ROUND(100 * r.breach_rate, 2)                                                AS sla_breach_rate_pct,
  ROUND(100 * r.breach_share, 2)                                               AS share_of_all_lane_breaches_pct,
  ROUND(r.avg_delay_days, 2)                                                   AS avg_days_late,
  ROUND(r.delay_sd, 2)                                                         AS delivery_variability_days,
  ROUND(r.profit_at_risk, 2)                                                   AS profit_at_risk_usd,
  r.profit_risk_rank,
  r.variability_priority_rank,
  CASE
    WHEN r.shipping_mode = 'First Class'                              THEN 'Review SLA Definition'
    WHEN b.profit_risk_band = 1 AND b.breach_rate_band = 1            THEN 'Protect'
    WHEN b.variability_band = 1                                        THEN 'Stabilize'
    WHEN b.profit_risk_band = 1 OR b.breach_rate_band = 1             THEN 'Monitor'
    ELSE                                                                    'Maintain'
  END                                                                          AS recommended_action
FROM ranked_lanes r
LEFT JOIN priority_bands b
  ON r.market = b.market AND r.shipping_mode = b.shipping_mode
ORDER BY r.variability_priority_rank;


-- =============================================================================
-- 5. mart_market_efficiency  (5 rows — one per market)
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency` AS
WITH market_summary AS (
  SELECT
    market,
    COUNT(*)                                AS order_count,
    SUM(order_revenue)                      AS revenue,
    SUM(order_profit)                       AS profit,
    COUNTIF(sla_breached = 'Yes')           AS breach_count,
    SUM(profit_at_risk)                     AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  GROUP BY market
)
SELECT
  market,
  order_count                                                                    AS orders,
  ROUND(revenue, 2)                                                            AS revenue_usd,
  ROUND(profit, 2)                                                             AS profit_usd,
  ROUND(100 * SAFE_DIVIDE(profit, revenue), 2)                                 AS profit_margin_pct,
  ROUND(100 * SAFE_DIVIDE(breach_count, order_count), 2)                       AS sla_breach_rate_pct,
  ROUND(100 * SAFE_DIVIDE(order_count, SUM(order_count) OVER ()), 2)           AS order_volume_share_pct,
  ROUND(100 * SAFE_DIVIDE(profit, SUM(profit) OVER ()), 2)                     AS profit_share_pct,
  ROUND(
    100 * SAFE_DIVIDE(profit,       SUM(profit)       OVER ())
    - 100 * SAFE_DIVIDE(order_count, SUM(order_count) OVER ()),
    2
  )                                                                            AS profit_vs_volume_gap_pct,
  ROUND(profit_at_risk, 2)                                                     AS profit_at_risk_usd
FROM market_summary
ORDER BY profit_vs_volume_gap_pct DESC;


-- =============================================================================
-- 6. mart_sla_promise_gap  (4 rows — one per shipping mode)
--    Root cause: compares promised vs actual delivery days to identify whether
--    breaches stem from miscalibrated SLA commitments or operational variability.
-- Techniques: APPROX_QUANTILES (p50/p90 actual days), CASE root cause classification
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_sla_promise_gap` AS
WITH mode_stats AS (
  SELECT
    shipping_mode,
    COUNT(*)                                                   AS order_count,
    COUNTIF(sla_breached = 'Yes')                              AS breach_count,
    ROUND(AVG(scheduled_days), 2)                              AS avg_scheduled_days,
    ROUND(AVG(actual_days), 2)                                 AS avg_actual_days,
    ROUND(APPROX_QUANTILES(actual_days, 100)[OFFSET(50)], 1)  AS p50_actual_days,
    ROUND(APPROX_QUANTILES(actual_days, 100)[OFFSET(90)], 1)  AS p90_actual_days,
    ROUND(AVG(delay_days), 2)                                  AS avg_promise_gap,
    ROUND(SUM(profit_at_risk), 2)                              AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  GROUP BY shipping_mode
)
SELECT
  shipping_mode,
  order_count                                                 AS orders,
  breach_count                                                AS sla_breached_orders,
  ROUND(100 * SAFE_DIVIDE(breach_count, order_count), 2)      AS sla_breach_rate_pct,
  avg_scheduled_days                                          AS avg_promised_delivery_days,
  avg_actual_days                                             AS avg_actual_delivery_days,
  p50_actual_days                                             AS median_actual_delivery_days,
  p90_actual_days                                             AS p90_actual_delivery_days,
  avg_promise_gap                                             AS avg_promise_gap_days,
  -- Realigned SLA target: CEIL(p90) gives a promise achievable ~90% of the time.
  -- NOTE: this is a promise-alignment number only. Realigning the promised days
  -- changes the REPORTED breach rate, not actual delivery performance, and must
  -- never be described as "breaches eliminated" or "profit saved" -- see
  -- mart_opportunity_scenarios for operationally grounded scenarios.
  CAST(CEIL(p90_actual_days) AS INT64)                        AS suggested_sla_days,
  profit_at_risk                                              AS profit_at_risk_usd,
  CASE
    WHEN avg_actual_days - avg_scheduled_days >= 0.8
      THEN 'Promise miscalibration - SLA commitment is systematically too aggressive'
    WHEN 100 * SAFE_DIVIDE(breach_count, order_count) >= 40
      THEN 'Operational variability - delivery times vary widely around the promise'
    ELSE 'Acceptable performance'
  END                                                         AS root_cause_summary
FROM mode_stats
ORDER BY sla_breach_rate_pct DESC;


-- =============================================================================
-- 7. mart_monthly_trends  (one row per calendar month)
--    Time-series: breach rate and PAR by month with LAG period-over-period.
-- Techniques: DATE_TRUNC (monthly bucketing), LAG() OVER (MoM change)
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_monthly_trends` AS
WITH monthly_agg AS (
  SELECT
    DATE_TRUNC(CAST(order_date AS DATE), MONTH)                  AS order_month,
    COUNT(*)                                                     AS order_count,
    COUNTIF(sla_breached = 'Yes')                               AS breach_count,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)), 2) AS breach_rate_pct,
    ROUND(SUM(profit_at_risk), 2)                               AS profit_at_risk
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  WHERE order_date IS NOT NULL
  GROUP BY order_month
)
SELECT
  order_month,
  order_count                                                  AS orders,
  breach_count                                                 AS sla_breached_orders,
  breach_rate_pct                                              AS sla_breach_rate_pct,
  profit_at_risk                                               AS profit_at_risk_usd,
  -- MoM change: positive = getting worse, negative = improving
  ROUND(breach_rate_pct
    - LAG(breach_rate_pct) OVER (ORDER BY order_month), 2)     AS sla_breach_rate_mom_change_pct,
  ROUND(profit_at_risk
    - LAG(profit_at_risk)  OVER (ORDER BY order_month), 2)     AS profit_at_risk_mom_change_usd
FROM monthly_agg
ORDER BY order_month;
