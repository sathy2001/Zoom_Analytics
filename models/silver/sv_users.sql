-- Silver Users Model
-- Transforms bronze users data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='user_id'
) }}

WITH bronze_users AS (
    SELECT * FROM {{ source('bronze', 'bz_users') }}
),

-- Data Quality Validation Layer
users_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_users', 'user_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN user_id IS NULL THEN 'INVALID'
            WHEN email IS NULL OR NOT REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN 'INVALID'
            WHEN user_name IS NULL OR TRIM(user_name) = '' THEN 'INVALID'
            WHEN plan_type NOT IN ('BASIC', 'PRO', 'BUSINESS', 'ENTERPRISE') THEN 'WARNING'
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_users
),

-- Clean and standardize data
users_cleaned AS (
    SELECT 
        user_id,
        UPPER(TRIM(user_name)) AS user_name,
        LOWER(TRIM(email)) AS email,
        UPPER(TRIM(company)) AS company,
        UPPER(TRIM(plan_type)) AS plan_type,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM users_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM users_cleaned
