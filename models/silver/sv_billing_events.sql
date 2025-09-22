-- Silver Billing Events Model
-- Transforms bronze billing events data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='event_id'
) }}

WITH bronze_billing_events AS (
    SELECT * FROM {{ source('bronze', 'bz_billing_events') }}
),

-- Data Quality Validation Layer
billing_events_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_billing_events', 'event_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN event_id IS NULL THEN 'INVALID'
            WHEN user_id IS NULL THEN 'INVALID'
            WHEN event_type IS NULL OR TRIM(event_type) = '' THEN 'INVALID'
            WHEN amount IS NULL THEN 'INVALID'
            WHEN amount < 0 THEN 'WARNING'  -- Negative amounts might be refunds
            WHEN amount > 100000 THEN 'WARNING'  -- Unusually high amounts
            WHEN event_date IS NULL THEN 'INVALID'
            WHEN event_date > CURRENT_DATE() THEN 'WARNING'
            WHEN event_type NOT IN ('CHARGE', 'REFUND', 'CREDIT', 'ADJUSTMENT', 'SUBSCRIPTION', 'CANCELLATION') THEN 'WARNING'
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_billing_events
),

-- Clean and standardize data
billing_events_cleaned AS (
    SELECT 
        event_id,
        user_id,
        UPPER(TRIM(event_type)) AS event_type,
        ROUND(amount, 2) AS amount,
        event_date,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM billing_events_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM billing_events_cleaned