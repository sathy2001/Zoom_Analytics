-- Silver Participants Model
-- Transforms bronze participants data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='participant_id'
) }}

WITH bronze_participants AS (
    SELECT * FROM {{ source('bronze', 'bz_participants') }}
),

-- Data Quality Validation Layer
participants_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_participants', 'participant_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN participant_id IS NULL THEN 'INVALID'
            WHEN meeting_id IS NULL THEN 'INVALID'
            WHEN user_id IS NULL THEN 'INVALID'
            WHEN join_time IS NULL THEN 'INVALID'
            WHEN leave_time IS NULL THEN 'WARNING'
            WHEN join_time > leave_time THEN 'INVALID'
            WHEN join_time > CURRENT_TIMESTAMP() THEN 'WARNING'
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_participants
),

-- Clean and standardize data
participants_cleaned AS (
    SELECT 
        participant_id,
        meeting_id,
        user_id,
        join_time,
        leave_time,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM participants_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM participants_cleaned
