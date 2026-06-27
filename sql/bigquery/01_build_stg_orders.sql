-- =============================================================================
-- 01_build_stg_orders.sql
-- Purpose   : Clean and type the raw DataCo orders into a stable staging table.
-- Input     : supply_chain_raw.orders  (loaded from raw/cleaned_dataco_supplychain.csv)
-- Output    : supply_chain_analytics.stg_orders
-- Techniques: SAFE_CAST on 40+ columns, CASE boolean normalisation,
--             WHERE null-guard on three key identity columns.
-- Run order : 1 of 3  (after 00_create_datasets.sql)
-- =============================================================================

CREATE OR REPLACE TABLE `supply-chain-analysis-492322.supply_chain_analytics.stg_orders` AS
SELECT
  payment_type,
  SAFE_CAST(days_for_shipping_real AS INT64) AS days_for_shipping_real,
  SAFE_CAST(days_for_shipment_scheduled AS INT64) AS days_for_shipment_scheduled,
  SAFE_CAST(benefit_per_order AS FLOAT64) AS benefit_per_order,
  SAFE_CAST(sales_per_customer AS FLOAT64) AS sales_per_customer,
  delivery_status,
  SAFE_CAST(late_delivery_risk AS INT64) AS late_delivery_risk,
  SAFE_CAST(category_id AS INT64) AS category_id,
  category_name,
  customer_city,
  customer_country,
  SAFE_CAST(customer_id AS INT64) AS customer_id,
  customer_segment,
  customer_state,
  SAFE_CAST(department_id AS INT64) AS department_id,
  department_name,
  market,
  order_city,
  order_country,
  SAFE_CAST(order_customer_id AS INT64) AS order_customer_id,
  SAFE_CAST(order_id AS INT64) AS order_id,
  SAFE_CAST(order_item_id AS INT64) AS order_item_id,
  SAFE_CAST(order_item_discount AS FLOAT64) AS order_item_discount,
  SAFE_CAST(order_item_discount_rate AS FLOAT64) AS order_item_discount_rate,
  SAFE_CAST(order_item_product_price AS FLOAT64) AS order_item_product_price,
  SAFE_CAST(order_item_profit_ratio AS FLOAT64) AS order_item_profit_ratio,
  SAFE_CAST(order_item_quantity AS INT64) AS order_item_quantity,
  SAFE_CAST(order_item_total AS FLOAT64) AS order_item_total,
  SAFE_CAST(order_profit_per_order AS FLOAT64) AS order_profit_per_order,
  order_region,
  order_state,
  order_status,
  SAFE_CAST(product_card_id AS INT64) AS product_card_id,
  SAFE_CAST(product_category_id AS INT64) AS product_category_id,
  product_name,
  SAFE_CAST(product_price AS FLOAT64) AS product_price,
  shipping_mode,
  SAFE_CAST(order_date AS TIMESTAMP) AS order_date,
  SAFE_CAST(shipping_date AS TIMESTAMP) AS shipping_date,
  SAFE_CAST(delay_days AS INT64) AS delay_days,
  CASE
    WHEN LOWER(TRIM(CAST(sla_breached AS STRING))) IN ('true', 'yes', '1') THEN 'Yes'
    WHEN LOWER(TRIM(CAST(sla_breached AS STRING))) IN ('false', 'no', '0') THEN 'No'
    ELSE NULL
  END AS sla_breached,
  SAFE_CAST(profit_at_risk AS FLOAT64) AS profit_at_risk,
  SAFE_CAST(order_month AS TIMESTAMP) AS order_month
FROM `supply-chain-analysis-492322.supply_chain_raw.orders`
WHERE SAFE_CAST(order_item_id AS INT64) IS NOT NULL
  AND SAFE_CAST(customer_id AS INT64) IS NOT NULL
  AND SAFE_CAST(order_profit_per_order AS FLOAT64) IS NOT NULL;
