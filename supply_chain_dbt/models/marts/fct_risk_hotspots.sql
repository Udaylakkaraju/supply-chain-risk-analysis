-- Category and customer-segment risk hotspot aggregations.
-- Supporting model: key findings from this mart are incorporated as evidence
-- into the fulfillment (Chapter 1) and market efficiency (Chapter 2) analysis.
select
    category_name,
    department_name,
    customer_segment,
    shipping_mode,
    market,
    order_status,
    count(*) as order_count,
    sum(order_item_total) as revenue,
    sum(order_profit_per_order) as profit,
    sum(case when sla_breached = 'Yes' then profit_at_risk else 0 end) as profit_at_risk,
    sum(case when sla_breached = 'Yes' then 1 else 0 end) as breach_count,
    avg(case when sla_breached = 'Yes' then 1 else 0 end) as sla_breach_rate,
    avg(delay_days) as avg_delay_days
from {{ ref('stg_orders') }}
group by 1, 2, 3, 4, 5, 6
