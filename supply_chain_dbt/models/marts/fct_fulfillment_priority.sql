-- Chapter 1: profit quartile vs delay / SLA (refine aggregations in Power BI or BI tool).
select
    order_item_id,
    order_id,
    customer_id,
    market,
    order_region,
    shipping_mode,
    profit_quartile,
    order_profit_per_order,
    delay_days,
    sla_breached,
    profit_at_risk,
    delivery_status,
    days_for_shipping_real,
    order_item_total
from {{ ref('int_order_profitability') }}
