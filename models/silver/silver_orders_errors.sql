{{ config(
    materialized='table',
    tags=['silver', 'orders', 'data_quality', 'errors']
) }}

-- Capture and log all records that failed data quality checks
WITH bronze_data AS (
    SELECT 
        order_id,
        customer_id,
        product_name,
        quantity,
        price,
        order_date,
        CURRENT_TIMESTAMP() AS extraction_timestamp,
        '{{ run_started_at }}' AS dbt_run_timestamp
    FROM {{ ref('brz_orders') }}
),

data_quality_checks AS (
    SELECT 
        *,
        -- Comprehensive error categorization
        CASE 
            WHEN order_id IS NULL THEN 'ORDER_ID_NULL'
            WHEN customer_id IS NULL THEN 'CUSTOMER_ID_NULL'
            WHEN quantity IS NULL THEN 'QUANTITY_NULL'
            WHEN price IS NULL THEN 'PRICE_NULL'
            WHEN order_date IS NULL THEN 'ORDER_DATE_NULL'
            WHEN product_name IS NULL OR TRIM(product_name) = '' THEN 'PRODUCT_NAME_NULL_OR_EMPTY'
            WHEN quantity <= 0 THEN 'INVALID_QUANTITY'
            WHEN price < 0 THEN 'NEGATIVE_PRICE'
            WHEN price > 1000000 THEN 'PRICE_TOO_HIGH'
            WHEN order_date > CURRENT_DATE() THEN 'FUTURE_ORDER_DATE'
            WHEN order_date < '2020-01-01' THEN 'ORDER_DATE_TOO_OLD'
            ELSE 'VALID'
        END AS error_type,
        
        CASE 
            WHEN order_id IS NULL 
                OR customer_id IS NULL 
                OR quantity IS NULL 
                OR price IS NULL 
                OR order_date IS NULL 
                OR product_name IS NULL 
                OR TRIM(product_name) = ''
                OR quantity <= 0 
                OR price < 0 
                OR price > 1000000
                OR order_date > CURRENT_DATE()
                OR order_date < '2020-01-01'
            THEN TRUE 
            ELSE FALSE 
        END AS has_errors
    FROM bronze_data
)

SELECT 
    order_id,
    customer_id,
    product_name,
    quantity,
    price,
    order_date,
    error_type,
    extraction_timestamp,
    dbt_run_timestamp,
    CURRENT_TIMESTAMP() AS error_logged_timestamp,
    '{{ var("pipeline_version", "v1.0") }}' AS pipeline_version
FROM data_quality_checks
WHERE has_errors = TRUE