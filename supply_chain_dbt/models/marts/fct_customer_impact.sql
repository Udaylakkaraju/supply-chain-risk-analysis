-- Customer order sequence and next-order behavior.
-- Used as a feature source for the BigQuery ML breach-risk model in Chapter 4.
-- The customer-impact signal itself is weak ($1.05 gap, 0.03pp reorder difference)
-- so this mart feeds the BQML model rather than anchoring a standalone chapter.
select
    order_item_id,
    order_id,
    customer_id,
    customer_order_seq,
    order_date,
    order_month,
    market,
    delivery_status,
    sla_breached,
    delay_days,
    next_order_id,
    next_order_date,
    days_to_next_order,
    next_order_value,
    sales_per_customer,
    order_item_total,
    order_profit_per_order
from {{ ref('int_customer_next_order') }}
