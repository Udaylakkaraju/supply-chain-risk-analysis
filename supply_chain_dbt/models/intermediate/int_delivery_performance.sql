-- Delivery KPIs aligned to delay_days, SLA, and risk flags (Chapter 1 & 3 inputs).
select
    order_item_id,
    order_id,
    customer_id,
    order_date,
    shipping_date,
    order_month,
    market,
    order_region,
    order_country,
    shipping_mode,
    delivery_status,
    days_for_shipping_real,
    days_for_shipment_scheduled,
    delay_days,
    sla_breached,
    late_delivery_risk,
    profit_at_risk,
    order_profit_per_order,
    order_item_total,
    sales_per_customer
from {{ ref('stg_orders') }}
