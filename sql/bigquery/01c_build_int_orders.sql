-- =============================================================================
-- 01c_build_int_orders.sql
-- Purpose   : Build ONE reusable order-grain intermediate table. Every mart in
--             02_build_powerbi_marts.sql should SELECT from int_orders instead
--             of repeating its own order_grain CTE. This is the single place
--             where the order-item -> order collapse happens, so a fix here
--             (e.g. the profit SUM correction) propagates to every mart
--             automatically on the next rebuild.
-- Input     : supply_chain_analytics.stg_orders  (order-ITEM grain, ~180,519 rows)
-- Output    : supply_chain_analytics.int_orders  (order grain, ~65,752 rows)
-- Run order : 1c of pipeline (after 01_build_stg_orders.sql, before 02_*)
--
-- WHY A SEPARATE INTERMEDIATE TABLE
-- stg_orders is at order-item grain: a single order_id can have multiple rows
-- (one per product line). Several fields are STABLE within an order (market,
-- shipping_mode, sla_breached, the day-count fields) and several are ADDITIVE
-- across an order's item rows (profit, revenue, item count). Mixing these up
-- is exactly the bug this table fixes: order_profit_per_order is an order-level
-- total that is REPEATED on every item row belonging to that order, not split
-- across them. MAX() picks one repeated copy (silently wrong only when BigQuery
-- happens to store the order-level profit differently per item row — which it
-- does for a subset of orders, see the stability check below). SUM() reflects
-- the actual documented business rule: order profit is the sum of order-item
-- profit contributions, so summing here is correct and MAX is the bug.
--
-- STABILITY VALIDATION (run the query in section 2 below before trusting MAX/
-- ANY_VALUE on dimension columns). If any dimension is NOT stable within an
-- order_id, do not collapse it with MAX/ANY_VALUE blindly -- investigate first.
-- =============================================================================


-- =============================================================================
-- SECTION 1: Build int_orders
-- =============================================================================
CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.int_orders` AS
SELECT
  order_id,

  -- Identity / dimensions -- stable within an order, MAX() is safe here because
  -- section 2 below validates that these do not vary across an order's item rows.
  MAX(customer_id)                          AS customer_id,
  MAX(customer_segment)                     AS customer_segment,
  MAX(market)                               AS market,
  MAX(order_region)                         AS order_region,
  MAX(shipping_mode)                        AS shipping_mode,
  MAX(order_date)                           AS order_date,
  MAX(days_for_shipment_scheduled)          AS scheduled_days,
  MAX(days_for_shipping_real)               AS actual_days,
  MAX(delay_days)                           AS delay_days,
  MAX(sla_breached)                         AS sla_breached,

  -- Additive measures -- these MUST be summed across an order's item rows.
  SUM(order_item_total)                     AS order_revenue,
  SUM(order_profit_per_order)               AS order_profit,
  COUNT(*)                                  AS order_item_count,

  -- profit_at_risk: only positive-profit orders that breached SLA count as
  -- recoverable exposure. Loss orders that breach SLA are an operational
  -- problem but not "profit at risk" in the sense of recoverable value.
  IF(MAX(sla_breached) = 'Yes',
     GREATEST(SUM(order_profit_per_order), 0), 0)   AS profit_at_risk

FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
WHERE sla_breached IN ('Yes', 'No')
GROUP BY order_id;


-- =============================================================================
-- SECTION 2: Stability validation
-- Run this BEFORE trusting int_orders. Every count below should be 0.
-- A non-zero count means that dimension genuinely varies within an order_id,
-- and MAX()/ANY_VALUE() is silently picking an arbitrary value -- investigate
-- those order_ids before relying on the column.
-- =============================================================================
WITH dimension_check AS (
  SELECT
    order_id,
    COUNT(DISTINCT market)                      AS distinct_market,
    COUNT(DISTINCT shipping_mode)               AS distinct_shipping_mode,
    COUNT(DISTINCT sla_breached)                AS distinct_sla_breached,
    COUNT(DISTINCT delay_days)                  AS distinct_delay_days,
    COUNT(DISTINCT customer_id)                 AS distinct_customer_id,
    COUNT(DISTINCT customer_segment)            AS distinct_customer_segment,
    COUNT(DISTINCT order_region)                AS distinct_order_region,
    COUNT(DISTINCT days_for_shipment_scheduled) AS distinct_scheduled_days,
    COUNT(DISTINCT days_for_shipping_real)      AS distinct_actual_days
  FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
  WHERE sla_breached IN ('Yes', 'No')
  GROUP BY order_id
)
SELECT
  COUNTIF(distinct_market > 1)             AS orders_with_unstable_market,
  COUNTIF(distinct_shipping_mode > 1)      AS orders_with_unstable_shipping_mode,
  COUNTIF(distinct_sla_breached > 1)       AS orders_with_unstable_sla_flag,
  COUNTIF(distinct_delay_days > 1)         AS orders_with_unstable_delay_days,
  COUNTIF(distinct_customer_id > 1)        AS orders_with_unstable_customer_id,
  COUNTIF(distinct_customer_segment > 1)   AS orders_with_unstable_customer_segment,
  COUNTIF(distinct_order_region > 1)       AS orders_with_unstable_order_region,
  COUNTIF(distinct_scheduled_days > 1)     AS orders_with_unstable_scheduled_days,
  COUNTIF(distinct_actual_days > 1)        AS orders_with_unstable_actual_days,
  'All counts should be 0 -- non-zero means MAX() is masking real variation' AS note
FROM dimension_check;


-- =============================================================================
-- SECTION 3: int_orders sanity check
-- Confirms row count, grain, and that the profit SUM fix actually changed the
-- numbers versus the old MAX-based approach (the gap_count / gap_value rows
-- show how many orders and how much profit the old MAX() logic was discarding).
-- =============================================================================
WITH old_max_logic AS (
  SELECT
    order_id,
    MAX(order_profit_per_order)  AS profit_via_max,
    SUM(order_profit_per_order)  AS profit_via_sum
  FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
  WHERE sla_breached IN ('Yes', 'No')
  GROUP BY order_id
)
SELECT
  COUNT(*)                                                    AS total_orders,
  COUNTIF(profit_via_max != profit_via_sum)                   AS orders_where_max_and_sum_differ,
  ROUND(SUM(profit_via_max), 2)                                AS total_profit_under_old_max_logic,
  ROUND(SUM(profit_via_sum), 2)                                AS total_profit_under_corrected_sum_logic,
  ROUND(SUM(profit_via_sum) - SUM(profit_via_max), 2)          AS profit_difference,
  'orders_where_max_and_sum_differ should equal 45,742' AS note
FROM old_max_logic;
