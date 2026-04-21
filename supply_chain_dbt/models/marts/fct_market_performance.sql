-- Chapter 2: market-level revenue, profit, SLA (aggregate in BI or add SQL rollups later).
select
    order_item_id,
    order_id,
    market,
    order_region,
    order_country,
    order_month,
    order_item_total,
    order_profit_per_order,
    order_item_profit_ratio,
    sla_breached,
    profit_at_risk,
    delay_days
from {{ ref('stg_orders') }}
