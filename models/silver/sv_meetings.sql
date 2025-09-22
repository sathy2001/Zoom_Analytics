-- Silver Meetings Model
-- Transforms bronze meetings data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='meeting_id'
) }}

WITH bronze_meetings AS (
    SELECT * FROM {{ source('bronze', 'bz_meetings') }}
),

-- Data Quality Validation Layer
meetings_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_meetings', 'meeting_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN meeting_id IS NULL THEN 'INVALID'
            WHEN host_id IS NULL THEN 'INVALID'
            WHEN start_time IS NULL THEN 'INVALID'
            WHEN end_time IS NULL THEN 'INVALID'
            WHEN start_time > end_time THEN 'INVALID'
            WHEN start_time > CURRENT_TIMESTAMP() THEN 'WARNING'
            WHEN duration_minutes IS NULL OR duration_minutes < 0 THEN 'WARNING'
            WHEN duration_minutes > 1440 THEN 'WARNING'  -- More than 24 hours
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_meetings
),

-- Clean and standardize data
meetings_cleaned AS (
    SELECT 
        meeting_id,
        host_id,
        TRIM(meeting_topic) AS meeting_topic,
        start_time,
        end_time,
        COALESCE(duration_minutes, DATEDIFF('minute', start_time, end_time)) AS duration_minutes,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM meetings_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM meetings_cleaned
