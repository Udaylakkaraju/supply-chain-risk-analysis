-- Chapter 3: grain suitable for std dev / CV by market + shipping mode (compute in BI or SQL).
select
    order_item_id,
    market,
    order_region,
    shipping_mode,
    delay_days,
    days_for_shipping_real,
    days_for_shipment_scheduled,
    sla_breached,
    order_month
from {{ ref('int_delivery_performance') }}
