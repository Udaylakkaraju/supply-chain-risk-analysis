-- Customer-level next-order features for Chapter 4 retention / follow-up behavior analysis.
with x as (
    select * from {{ ref('int_customer_orders') }}
)

select
    x.*,
    lead(order_date) over (
        partition by customer_id
        order by order_date, order_id, order_item_id
    ) as next_order_date,
    lead(order_id) over (
        partition by customer_id
        order by order_date, order_id, order_item_id
    ) as next_order_id,
    lead(order_item_total) over (
        partition by customer_id
        order by order_date, order_id, order_item_id
    ) as next_order_value,
    date_diff(
        lead(cast(order_date as date)) over (
            partition by customer_id
            order by order_date, order_id, order_item_id
        ),
        cast(order_date as date),
        day
    ) as days_to_next_order
from x
