-- models/silver/customer_details_silver.sql

{{ config(
    materialized='incremental',
    unique_key='customer_id',
    on_schema_change='fail',
    pre_hook="{{ log('Starting Customer Details Bronze to Silver transformation', info=true) }}",
    post_hook=[
        "{{ log('Completed Customer Details Bronze to Silver transformation', info=true) }}",
        "INSERT INTO {{ ref('audit_log') }} SELECT 'customer_details_silver' as table_name, COUNT(*) as row_count, CURRENT_TIMESTAMP as process_timestamp FROM {{ this }}"
    ]
) }}

WITH source_data AS (
    SELECT *
    FROM {{ ref('customer_details_bronze') }}
    {% if is_incremental() %}
        WHERE extraction_timestamp > (SELECT MAX(extraction_timestamp) FROM {{ this }})
    {% endif %}
),

-- Data Quality Checks and Error Flagging
data_quality_checks AS (
    SELECT *,
        -- Initialize error tracking
        ARRAY_CONSTRUCT() AS dq_errors,
        FALSE AS has_errors,
        
        -- Null value checks for mandatory fields
        CASE 
            WHEN customer_id IS NULL THEN 'CUSTOMER_ID_NULL'
            ELSE NULL 
        END AS error_customer_id_null,
        
        CASE 
            WHEN customer_name IS NULL THEN 'CUSTOMER_NAME_NULL'
            ELSE NULL 
        END AS error_customer_name_null,
        
        CASE 
            WHEN email IS NULL THEN 'EMAIL_NULL'
            ELSE NULL 
        END AS error_email_null,
        
        CASE 
            WHEN created_date IS NULL THEN 'CREATED_DATE_NULL'
            ELSE NULL 
        END AS error_created_date_null,
        
        CASE 
            WHEN created_at IS NULL THEN 'CREATED_AT_NULL'
            ELSE NULL 
        END AS error_created_at_null,
        
        -- Data type and format validation
        CASE 
            WHEN customer_id IS NOT NULL AND NOT REGEXP_LIKE(customer_id, '^[a-zA-Z0-9]+$') 
            THEN 'CUSTOMER_ID_INVALID_FORMAT'
            ELSE NULL 
        END AS error_customer_id_format,
        
        CASE 
            WHEN email IS NOT NULL AND NOT REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') 
            THEN 'EMAIL_INVALID_FORMAT'
            ELSE NULL 
        END AS error_email_format,
        
        -- Range and business rule validation
        CASE 
            WHEN process_status IS NOT NULL AND process_status NOT IN ('Pending', 'Completed', 'Failed') 
            THEN 'PROCESS_STATUS_INVALID_VALUE'
            ELSE NULL 
        END AS error_process_status_invalid,
        
        CASE 
            WHEN processing_stage IS NOT NULL AND processing_stage NOT IN ('Stage1', 'Stage2', 'Stage3') 
            THEN 'PROCESSING_STAGE_INVALID_VALUE'
            ELSE NULL 
        END AS error_processing_stage_invalid,
        
        -- Timestamp consistency checks
        CASE 
            WHEN updated_at IS NOT NULL AND created_at IS NOT NULL AND updated_at < created_at 
            THEN 'UPDATED_AT_BEFORE_CREATED_AT'
            ELSE NULL 
        END AS error_timestamp_consistency,
        
        CASE 
            WHEN extraction_timestamp IS NOT NULL AND created_at IS NOT NULL AND extraction_timestamp < created_at 
            THEN 'EXTRACTION_TIMESTAMP_BEFORE_CREATED_AT'
            ELSE NULL 
        END AS error_extraction_timestamp,
        
        -- Date validation
        CASE 
            WHEN created_date IS NOT NULL AND created_date > CURRENT_DATE 
            THEN 'CREATED_DATE_FUTURE'
            ELSE NULL 
        END AS error_created_date_future,
        
        -- Date consistency check
        CASE 
            WHEN created_date IS NOT NULL AND created_at IS NOT NULL AND DATE(created_at) != created_date 
            THEN 'DATE_TIMESTAMP_MISMATCH'
            ELSE NULL 
        END AS error_date_consistency,
        
        -- Length validation
        CASE 
            WHEN LENGTH(customer_name) > 16777216 THEN 'CUSTOMER_NAME_TOO_LONG'
            ELSE NULL 
        END AS error_customer_name_length,
        
        CASE 
            WHEN LENGTH(email) > 16777216 THEN 'EMAIL_TOO_LONG'
            ELSE NULL 
        END AS error_email_length,
        
        CASE 
            WHEN LENGTH(process_status) > 20 THEN 'PROCESS_STATUS_TOO_LONG'
            ELSE NULL 
        END AS error_process_status_length,
        
        CASE 
            WHEN LENGTH(processing_stage) > 23 THEN 'PROCESSING_STAGE_TOO_LONG'
            ELSE NULL 
        END AS error_processing_stage_length
        
    FROM source_data
),

-- Aggregate all errors and create error flags
error_aggregation AS (
    SELECT *,
        ARRAY_COMPACT(ARRAY_CONSTRUCT(
            error_customer_id_null, 
            error_customer_name_null,
            error_email_null,
            error_created_date_null,
            error_created_at_null,
            error_customer_id_format,
            error_email_format,
            error_process_status_invalid,
            error_processing_stage_invalid,
            error_timestamp_consistency,
            error_extraction_timestamp,
            error_created_date_future,
            error_date_consistency,
            error_customer_name_length,
            error_email_length,
            error_process_status_length,
            error_processing_stage_length
        )) AS all_dq_errors,
        
        -- Determine if record has any errors
        CASE 
            WHEN ARRAY_SIZE(ARRAY_COMPACT(ARRAY_CONSTRUCT(
                error_customer_id_null,
                error_customer_name_null,
                error_email_null,
                error_created_date_null,
                error_created_at_null,
                error_customer_id_format,
                error_email_format,
                error_process_status_invalid,
                error_processing_stage_invalid,
                error_timestamp_consistency,
                error_extraction_timestamp,
                error_created_date_future,
                error_date_consistency,
                error_customer_name_length,
                error_email_length,
                error_process_status_length,
                error_processing_stage_length
            ))) > 0 THEN TRUE
            ELSE FALSE 
        END AS record_has_errors
        
    FROM data_quality_checks
),

-- Data cleansing and transformation
cleansed_data AS (
    SELECT 
        -- Original columns with cleansing applied
        UPPER(TRIM(customer_id)) AS customer_id,
        TRIM(customer_name) AS customer_name,
        LOWER(TRIM(email)) AS email,
        created_date,
        created_at,
        COALESCE(updated_at, created_at) AS updated_at,
        COALESCE(process_status, 'Pending') AS process_status,
        dbt_run_timestamp,
        dbt_invocation_id,
        extraction_timestamp,
        COALESCE(processing_stage, 'Stage1') AS processing_stage,
        
        -- Data Quality and Audit columns
        all_dq_errors AS dq_error_list,
        record_has_errors AS dq_error_flag,
        ARRAY_SIZE(all_dq_errors) AS dq_error_count,
        
        -- Audit information
        CURRENT_TIMESTAMP AS silver_process_timestamp,
        '{{ invocation_id }}' AS silver_dbt_invocation_id,
        '{{ run_started_at }}' AS silver_dbt_run_timestamp,
        'silver' AS current_processing_stage,
        
        -- Data lineage
        HASH(customer_id, customer_name, email, created_date) AS record_hash,
        
        -- Record status based on DQ checks
        CASE 
            WHEN record_has_errors THEN 'FAILED_DQ'
            WHEN process_status = 'Completed' THEN 'PROCESSED'
            ELSE 'PENDING_VALIDATION'
        END AS silver_record_status
        
    FROM error_aggregation
),

-- Duplicate detection and handling
duplicate_check AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY 
                CASE WHEN dq_error_flag THEN 1 ELSE 0 END,  -- Prioritize records without errors
                extraction_timestamp DESC,                   -- Most recent extraction
                silver_process_timestamp DESC               -- Most recent processing
        ) AS row_rank,
        
        COUNT(*) OVER (PARTITION BY customer_id) AS duplicate_count
        
    FROM cleansed_data
),

-- Final transformation with duplicate handling
final_transformation AS (
    SELECT 
        customer_id,
        customer_name,
        email,
        created_date,
        created_at,
        updated_at,
        process_status,
        dbt_run_timestamp,
        dbt_invocation_id,
        extraction_timestamp,
        processing_stage,
        
        -- Enhanced DQ and audit columns
        dq_error_list,
        dq_error_flag,
        dq_error_count,
        silver_process_timestamp,
        silver_dbt_invocation_id,
        silver_dbt_run_timestamp,
        current_processing_stage,
        record_hash,
        
        -- Enhanced record status with duplicate handling
        CASE 
            WHEN duplicate_count > 1 AND row_rank = 1 THEN CONCAT(silver_record_status, '_DEDUPLICATED')
            WHEN duplicate_count > 1 AND row_rank > 1 THEN 'DUPLICATE_DISCARDED'
            ELSE silver_record_status
        END AS silver_record_status,
        
        -- Duplicate information
        duplicate_count,
        CASE WHEN duplicate_count > 1 THEN TRUE ELSE FALSE END AS is_duplicate,
        
        -- Processing metadata
        CASE 
            WHEN row_rank = 1 THEN 'INCLUDED'
            ELSE 'EXCLUDED'
        END AS processing_decision
        
    FROM duplicate_check
    WHERE row_rank = 1  -- Only include the best record for each customer_id
)

SELECT * FROM final_transformation