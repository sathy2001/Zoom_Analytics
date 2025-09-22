-- Silver Licenses Model
-- Transforms bronze licenses data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='license_id'
) }}

WITH bronze_licenses AS (
    SELECT * FROM {{ source('bronze', 'bz_licenses') }}
),

-- Data Quality Validation Layer
licenses_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_licenses', 'license_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN license_id IS NULL THEN 'INVALID'
            WHEN license_type IS NULL OR TRIM(license_type) = '' THEN 'INVALID'
            WHEN assigned_to_user_id IS NULL THEN 'INVALID'
            WHEN start_date IS NULL THEN 'INVALID'
            WHEN end_date IS NULL THEN 'WARNING'
            WHEN start_date > end_date THEN 'INVALID'
            WHEN start_date > CURRENT_DATE() THEN 'WARNING'
            WHEN license_type NOT IN ('BASIC', 'PRO', 'BUSINESS', 'ENTERPRISE', 'TRIAL') THEN 'WARNING'
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_licenses
),

-- Clean and standardize data
licenses_cleaned AS (
    SELECT 
        license_id,
        UPPER(TRIM(license_type)) AS license_type,
        assigned_to_user_id,
        start_date,
        end_date,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM licenses_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM licenses_cleaned