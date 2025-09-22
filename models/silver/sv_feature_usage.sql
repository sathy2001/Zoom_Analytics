-- Silver Feature Usage Model
-- Transforms bronze feature usage data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='usage_id'
) }}

WITH bronze_feature_usage AS (
    SELECT * FROM {{ source('bronze', 'bz_feature_usage') }}
),

-- Data Quality Validation Layer
feature_usage_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_feature_usage', 'usage_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN usage_id IS NULL THEN 'INVALID'
            WHEN meeting_id IS NULL THEN 'INVALID'
            WHEN feature_name IS NULL OR TRIM(feature_name) = '' THEN 'INVALID'
            WHEN usage_count IS NULL OR usage_count < 0 THEN 'INVALID'
            WHEN usage_date IS NULL THEN 'INVALID'
            WHEN usage_date > CURRENT_DATE() THEN 'WARNING'
            WHEN usage_count > 10000 THEN 'WARNING'  -- Unusually high usage
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_feature_usage
),

-- Clean and standardize data
feature_usage_cleaned AS (
    SELECT 
        usage_id,
        meeting_id,
        UPPER(TRIM(feature_name)) AS feature_name,
        usage_count,
        usage_date,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM feature_usage_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM feature_usage_cleaned