
{{ config(
    schema= 'silver'
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='fail',
    tags=['silver', 'orders', 'core']
) }}

WITH bronze_data AS (
    SELECT 
        order_id,
        customer_id,
        product_name,
        quantity,
        price,
        order_date,
        -- Add source metadata for audit purposes
        CURRENT_TIMESTAMP() AS extraction_timestamp,
        '{{ run_started_at }}' AS dbt_run_timestamp
    FROM {{ source('brz_orders', 'silver_orders') }}
    {% if is_incremental() %}
        -- Only process new or updated records in incremental runs
        WHERE order_date >= (SELECT COALESCE(MAX(order_date), '1900-01-01') FROM {{ this }})
    {% endif %}
),

data_quality_checks AS (
    SELECT 
        *,
        -- Completeness checks
        CASE 
            WHEN order_id IS NULL THEN 'ORDER_ID_NULL'
            WHEN customer_id IS NULL THEN 'CUSTOMER_ID_NULL'
            WHEN quantity IS NULL THEN 'QUANTITY_NULL'
            WHEN price IS NULL THEN 'PRICE_NULL'
            WHEN order_date IS NULL THEN 'ORDER_DATE_NULL'
            WHEN product_name IS NULL OR TRIM(product_name) = '' THEN 'PRODUCT_NAME_NULL_OR_EMPTY'
            -- Validity and range checks
            WHEN quantity <= 0 THEN 'INVALID_QUANTITY'
            WHEN price < 0 THEN 'NEGATIVE_PRICE'
            WHEN price > 1000000 THEN 'PRICE_TOO_HIGH'
            -- Date validation checks
            WHEN order_date > CURRENT_DATE() THEN 'FUTURE_ORDER_DATE'
            WHEN order_date < '2020-01-01' THEN 'ORDER_DATE_TOO_OLD'
            ELSE 'VALID'
        END AS data_quality_status,
        
        -- Create error flags for easier filtering
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
        END AS has_data_quality_issues
    FROM bronze_data
),

cleaned_and_transformed AS (
    SELECT 
        order_id,
        customer_id,
        -- Standardize product name formatting
        UPPER(TRIM(product_name)) AS product_name,
        quantity,
        ROUND(price, 2) AS price, -- Ensure price has exactly 2 decimal places
        order_date,
        -- Calculate derived fields
        ROUND(quantity * price, 2) AS total_amount,
        -- Add audit and quality information
        data_quality_status,
        has_data_quality_issues,
        extraction_timestamp,
        dbt_run_timestamp,
        CURRENT_TIMESTAMP() AS processed_timestamp,
        '{{ var("pipeline_version", "v1.0") }}' AS pipeline_version
    FROM data_quality_checks
    -- Only include valid records in the silver layer
    WHERE has_data_quality_issues = FALSE
)

SELECT * FROM cleaned_and_transformed