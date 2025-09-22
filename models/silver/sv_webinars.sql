-- Silver Webinars Model
-- Transforms bronze webinars data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='webinar_id'
) }}

WITH bronze_webinars AS (
    SELECT * FROM {{ source('bronze', 'bz_webinars') }}
),

-- Data Quality Validation Layer
webinars_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_webinars', 'webinar_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN webinar_id IS NULL THEN 'INVALID'
            WHEN host_id IS NULL THEN 'INVALID'
            WHEN start_time IS NULL THEN 'INVALID'
            WHEN end_time IS NULL THEN 'INVALID'
            WHEN start_time > end_time THEN 'INVALID'
            WHEN registrants IS NULL OR registrants < 0 THEN 'WARNING'
            WHEN registrants > 100000 THEN 'WARNING'  -- Unusually high registrants
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_webinars
),

-- Clean and standardize data
webinars_cleaned AS (
    SELECT 
        webinar_id,
        host_id,
        TRIM(webinar_topic) AS webinar_topic,
        start_time,
        end_time,
        COALESCE(registrants, 0) AS registrants,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM webinars_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM webinars_cleaned

