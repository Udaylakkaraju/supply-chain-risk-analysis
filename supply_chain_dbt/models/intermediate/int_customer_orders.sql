-- Per line item: sequence orders per customer for Chapter 4 repeat behavior.
with stg as (
    select * from {{ ref('stg_orders') }}
),

sequenced as (
    select
        stg.*,
        row_number() over (
            partition by customer_id
            order by order_date, order_id, order_item_id
        ) as customer_order_seq
    from stg
)

select * from sequenced
