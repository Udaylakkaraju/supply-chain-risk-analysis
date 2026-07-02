-- =============================================================================
-- 02c_build_mart_opportunity_scenarios.sql
-- Purpose   : Three quantified, defensible operational scenarios. Replaces the
--             prior mart_scenario_model, which is removed because it was not
--             reproducible from committed SQL (README referenced it, but no
--             script built it).
-- Input     : supply_chain_analytics.int_orders
-- Output    : supply_chain_analytics.mart_opportunity_scenarios  (3 rows)
-- Run order : after 01c_build_int_orders.sql and 02_build_powerbi_marts.sql
--             (lane ranking reuses the same variability_priority_rank logic)
--
-- IMPORTANT — THESE SCENARIOS OVERLAP
-- Scenario 1 (Second Class recovery), Scenario 2 (high-value routing), and
-- Scenario 3 (top-5 lane stabilization) all draw from overlapping order
-- populations (e.g. a Q1-profit Second Class order in a top-5 lane could be
-- counted in all three). DO NOT SUM the breach counts or dollar values across
-- scenarios in any downstream document, DAX measure, or chart. Each scenario
-- must be presented independently. mart_opportunity_scenarios intentionally
-- keeps them as separate rows rather than a single blended "combined" row to
-- make double-counting harder to do by accident.
--
-- IMPORTANT — MODELED, NOT REALIZED
-- Every number in this table is a modeled opportunity under a stated
-- assumption (e.g. "if actual Second Class delivery were 1 day faster").
-- None of it is a proven, realized saving. Label it that way everywhere this
-- mart is surfaced (Power BI, Excel, README): "modeled opportunity requiring
-- pilot validation," never "savings achieved" or "breaches eliminated."
-- =============================================================================


-- =============================================================================
-- Scenario 1: One-Day Second Class Recovery
-- If actual Second Class delivery time were reduced by exactly one day, how
-- many currently-breached Second Class orders would now meet SLA (i.e. their
-- adjusted delay_days drops to <= 0), and what positive profit exposure do
-- those orders represent?
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.mart_opportunity_scenarios` AS
WITH second_class_orders AS (
  SELECT
    order_id,
    delay_days,
    sla_breached,
    profit_at_risk,
    delay_days - 1 AS adjusted_delay_days
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  WHERE shipping_mode = 'Second Class'
),
scenario_1 AS (
  SELECT
    'Scenario 1: One-Day Second Class Recovery'                         AS scenario,
    COUNT(*)                                                            AS orders_in_scope,
    COUNTIF(sla_breached = 'Yes' AND adjusted_delay_days <= 0)          AS breaches_addressed,
    ROUND(SUM(IF(sla_breached = 'Yes' AND adjusted_delay_days <= 0,
                 profit_at_risk, 0)), 2)                                AS profit_exposure_addressed,
    COUNTIF(sla_breached = 'Yes' AND adjusted_delay_days <= 0)          AS cumulative_delivery_days_recovered,
    'Modeled: reduce actual Second Class delivery time by 1 day. Requires operational pilot validation -- not a realized saving.' AS caveat
  FROM second_class_orders
),

-- =============================================================================
-- Scenario 2: High-Value Routing Guardrail
-- Among the highest profit quartile (Q1), how many orders currently ship
-- Second Class, what is their current breached positive-profit exposure, and
-- how many of those breaches might be avoided if this population matched
-- Standard Class's breach rate? This is a MODELED ROUTING SCENARIO, not
-- proven savings -- it assumes Q1 Second Class orders would behave like
-- Standard Class orders if rerouted, which has not been tested.
-- =============================================================================
profit_quartiles AS (
  SELECT
    *,
    NTILE(4) OVER (ORDER BY order_profit DESC) AS profit_quartile
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
),
standard_class_benchmark AS (
  SELECT
    SAFE_DIVIDE(COUNTIF(sla_breached = 'Yes'), COUNT(*)) AS standard_class_breach_rate
  FROM `supply-chain-analysis-492322.supply_chain_analytics.int_orders`
  WHERE shipping_mode = 'Standard Class'
),
q1_second_class AS (
  SELECT *
  FROM profit_quartiles
  WHERE profit_quartile = 1
    AND shipping_mode = 'Second Class'
),
scenario_2 AS (
  SELECT
    'Scenario 2: High-Value Routing Guardrail'                          AS scenario,
    COUNT(*)                                                            AS orders_in_scope,
    COUNTIF(sla_breached = 'Yes')                                       AS current_breaches,
    ROUND(SUM(IF(sla_breached = 'Yes', profit_at_risk, 0)), 2)          AS current_profit_exposure,
    ROUND(COUNTIF(sla_breached = 'Yes')
      - COUNT(*) * (SELECT standard_class_breach_rate FROM standard_class_benchmark), 0)
                                                                         AS modeled_breaches_avoidable,
    'Modeled routing scenario: assumes Q1 Second Class orders would match Standard Class breach rate if rerouted. Not proven savings -- requires pilot validation.' AS caveat
  FROM q1_second_class
),

-- =============================================================================
-- Scenario 3: Top-Five Operational-Lane Stabilization
-- A 20% RELATIVE reduction in breach count across the five highest-variability
-- lanes (ranked by variability_priority_rank, the deterministic ranking
-- defined in 02_build_powerbi_marts.sql -- NOT profit_risk_rank).
-- =============================================================================
lane_summary AS (
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
top_5_lanes AS (
  SELECT * FROM ranked_lanes WHERE variability_priority_rank <= 5
),
scenario_3 AS (
  SELECT
    'Scenario 3: Top-Five Operational-Lane Stabilization'               AS scenario,
    SUM(order_count)                                                    AS orders_in_scope,
    ROUND(SUM(breach_count) * 0.20, 0)                                  AS breaches_addressed_at_20pct_reduction,
    ROUND(SUM(profit_at_risk) * 0.20, 2)                                AS profit_exposure_addressed_at_20pct_reduction,
    'Modeled: 20% relative breach reduction across the 5 lanes ranked highest by variability_priority_rank. Requires pilot validation -- not a realized saving.' AS caveat
  FROM top_5_lanes
)

SELECT
  scenario,
  orders_in_scope,
  breaches_addressed                          AS modeled_breaches_addressed,
  profit_exposure_addressed                   AS modeled_profit_exposure_usd,
  cumulative_delivery_days_recovered          AS supporting_metric,
  'Delivery days recovered'                   AS supporting_metric_label,
  cumulative_delivery_days_recovered          AS supporting_metric_value,
  caveat
FROM scenario_1

UNION ALL

SELECT
  scenario,
  orders_in_scope,
  CAST(modeled_breaches_avoidable AS INT64)    AS modeled_breaches_addressed,
  current_profit_exposure                      AS modeled_profit_exposure_usd,
  current_breaches                             AS supporting_metric,
  'Current breached orders in scope'           AS supporting_metric_label,
  current_breaches                             AS supporting_metric_value,
  caveat
FROM scenario_2

UNION ALL

SELECT
  scenario,
  orders_in_scope,
  CAST(breaches_addressed_at_20pct_reduction AS INT64) AS modeled_breaches_addressed,
  profit_exposure_addressed_at_20pct_reduction         AS modeled_profit_exposure_usd,
  NULL                                                 AS supporting_metric,
  'Relative breach reduction (%)'                      AS supporting_metric_label,
  20                                                   AS supporting_metric_value,
  caveat
FROM scenario_3;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            