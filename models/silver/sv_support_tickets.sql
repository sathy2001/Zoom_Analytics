-- Silver Support Tickets Model
-- Transforms bronze support tickets data with data quality checks and audit information

{{ config(
    materialized='table',
    unique_key='ticket_id'
) }}

WITH bronze_support_tickets AS (
    SELECT * FROM {{ source('bronze', 'bz_support_tickets') }}
),

-- Data Quality Validation Layer
support_tickets_with_dq AS (
    SELECT 
        *,
        -- Data Quality Score Calculation
        {{ calculate_dq_score('sv_support_tickets', 'ticket_id') }} AS data_quality_score,
        
        -- Record Status based on data quality
        CASE 
            WHEN ticket_id IS NULL THEN 'INVALID'
            WHEN user_id IS NULL THEN 'INVALID'
            WHEN ticket_type IS NULL OR TRIM(ticket_type) = '' THEN 'INVALID'
            WHEN resolution_status NOT IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'CANCELLED') THEN 'WARNING'
            WHEN open_date IS NULL THEN 'INVALID'
            WHEN open_date > CURRENT_DATE() THEN 'WARNING'
            ELSE 'VALID'
        END AS record_status,
        
        -- Audit columns
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM bronze_support_tickets
),

-- Clean and standardize data
support_tickets_cleaned AS (
    SELECT 
        ticket_id,
        user_id,
        UPPER(TRIM(ticket_type)) AS ticket_type,
        UPPER(TRIM(resolution_status)) AS resolution_status,
        open_date,
        load_timestamp,
        update_timestamp,
        source_system,
        load_date,
        update_date,
        data_quality_score,
        record_status,
        created_at,
        updated_at
    FROM support_tickets_with_dq
    WHERE record_status IN ('VALID', 'WARNING')  -- Exclude invalid records
)

SELECT * FROM support_tickets_cleaned
