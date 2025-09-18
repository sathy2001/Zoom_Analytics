-- models/silver/customer_silver.sql
{{ config(
    materialized='incremental',
    unique_key='customer_id',
    on_schema_change='fail',
    tags=['silver', 'customer', 'core']
) }}

WITH source_data AS (
    SELECT 
        customer_id,
        customer_name,
        email,
        created_date,
        -- Add source metadata
        CURRENT_TIMESTAMP() AS process_timestamp,
        'CUSTOMER_BRZ' AS source_table
    FROM {{ ref('customer_brz') }}
    {% if is_incremental() %}
        WHERE created_date > (SELECT MAX(created_date) FROM {{ this }})
    {% endif %}
),

-- Data Quality Checks and Transformations
data_quality_checks AS (
    SELECT 
        *,
        -- Completeness Checks
        CASE 
            WHEN customer_id IS NULL THEN 'CUSTOMER_ID_NULL'
            WHEN customer_name IS NULL OR TRIM(customer_name) = '' THEN 'CUSTOMER_NAME_MISSING'
            ELSE NULL 
        END AS completeness_error,
        
        -- Validity Checks
        CASE 
            WHEN email IS NOT NULL AND NOT REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') 
                THEN 'INVALID_EMAIL_FORMAT'
            WHEN created_date > CURRENT_DATE() THEN 'FUTURE_CREATED_DATE'
            WHEN created_date < '1900-01-01' THEN 'INVALID_CREATED_DATE'
            ELSE NULL 
        END AS validity_error,
        
        -- Consistency Checks
        CASE 
            WHEN LENGTH(TRIM(customer_name)) < 2 THEN 'CUSTOMER_NAME_TOO_SHORT'
            WHEN LENGTH(customer_name) > 100 THEN 'CUSTOMER_NAME_TOO_LONG'
            ELSE NULL 
        END AS consistency_error
    FROM source_data
),

-- Combine all error flags
error_flagging AS (
    SELECT 
        *,
        CONCAT_WS('|', 
            completeness_error, 
            validity_error, 
            consistency_error
        ) AS combined_errors,
        
        CASE 
            WHEN completeness_error IS NOT NULL 
                OR validity_error IS NOT NULL 
                OR consistency_error IS NOT NULL 
            THEN TRUE 
            ELSE FALSE 
        END AS has_error_flag
    FROM data_quality_checks
),

-- Clean and standardize data
cleaned_data AS (
    SELECT 
        customer_id,
        TRIM(UPPER(customer_name)) AS customer_name,
        CASE 
            WHEN email IS NOT NULL AND REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
            THEN LOWER(TRIM(email))
            ELSE NULL 
        END AS email,
        created_date,
        process_timestamp,
        source_table,
        combined_errors,
        has_error_flag,
        -- Audit fields
        {{ dbt_utils.generate_surrogate_key(['customer_id', 'process_timestamp']) }} AS record_hash,
        'BRONZE_TO_SILVER' AS transformation_type,
        '{{ var("pipeline_run_id", "UNKNOWN") }}' AS pipeline_run_id
    FROM error_flagging
)

SELECT * FROM cleaned_data

-- Log data quality issues
{% if execute %}
    {% set error_count_query %}
        SELECT COUNT(*) as error_count 
        FROM ({{ this.sql }}) 
        WHERE has_error_flag = TRUE
    {% endset %}
    
    {% if error_count_query %}
        {{ log("Data Quality Check: Found errors in customer transformation", info=True) }}
    {% endif %}
{% endif %}
