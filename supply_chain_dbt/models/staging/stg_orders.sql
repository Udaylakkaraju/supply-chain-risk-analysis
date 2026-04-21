with source as (
    select * from {{ source('supply_chain', 'orders') }}
),

typed as (
    select
        payment_type,
        cast(days_for_shipping_real as int64) as days_for_shipping_real,
        cast(days_for_shipment_scheduled as int64) as days_for_shipment_scheduled,
        cast(benefit_per_order as float64) as benefit_per_order,
        cast(sales_per_customer as float64) as sales_per_customer,
        delivery_status,
        cast(late_delivery_risk as int64) as late_delivery_risk,
        cast(category_id as int64) as category_id,
        category_name,
        customer_city,
        customer_country,
        customer_fname,
        cast(customer_id as int64) as customer_id,
        customer_lname,
        customer_segment,
        customer_state,
        customer_street,
        cast(department_id as int64) as department_id,
        department_name,
        cast(latitude as float64) as latitude,
        cast(longitude as float64) as longitude,
        market,
        order_city,
        order_country,
        cast(order_customer_id as int64) as order_customer_id,
        order_date_text,
        cast(order_id as int64) as order_id,
        cast(order_item_cardprod_id as int64) as order_item_cardprod_id,
        cast(order_item_discount as float64) as order_item_discount,
        cast(order_item_discount_rate as float64) as order_item_discount_rate,
        cast(order_item_id as int64) as order_item_id,
        cast(order_item_product_price as float64) as order_item_product_price,
        cast(order_item_profit_ratio as float64) as order_item_profit_ratio,
        cast(order_item_quantity as int64) as order_item_quantity,
        cast(order_item_total as float64) as order_item_total,
        cast(order_profit_per_order as float64) as order_profit_per_order,
        order_region,
        order_state,
        order_status,
        cast(product_card_id as int64) as product_card_id,
        cast(product_category_id as int64) as product_category_id,
        product_name,
        cast(product_price as float64) as product_price,
        shipping_date_text,
        shipping_mode,
        safe_cast(order_date as timestamp) as order_date,
        safe_cast(shipping_date as timestamp) as shipping_date,
        cast(delay_days as int64) as delay_days,
        case
            when lower(trim(cast(sla_breached as string))) in ('true', 'yes', '1') then 'Yes'
            when lower(trim(cast(sla_breached as string))) in ('false', 'no', '0') then 'No'
            else cast(sla_breached as string)
        end as sla_breached,
        cast(profit_at_risk as float64) as profit_at_risk,
        safe_cast(order_month as timestamp) as order_month
    from source
)

select * from typed
where order_item_id is not null
  and customer_id is not null
  and order_profit_per_order is not null
