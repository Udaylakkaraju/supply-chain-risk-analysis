-- Profit quartiles (1 = highest profit) for Chapter 1 prioritization analysis.
with stg as (
    select * from {{ ref('stg_orders') }}
),

quartiles as (
    select
        stg.*,
        ntile(4) over (
            order by order_profit_per_order desc
        ) as profit_quartile
    from stg
)

select * from quartiles
