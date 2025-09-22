-- models/audit/audit_log.sql

{{ config(
    schema = 'SILVER',
    materialized='incremental',
    unique_key=['table_name', 'process_timestamp']
) }}

SELECT 
    table_name,
    row_count,
    process_timestamp,
    '{{ invocation_id }}' AS dbt_invocation_id,
    '{{ run_started_at }}' AS dbt_run_timestamp
FROM (
    SELECT 
        'customer_details_silver' AS table_name,
        0 AS row_count,
        CURRENT_TIMESTAMP AS process_timestamp
    WHERE FALSE  -- This will be populated by post-hooks
)
