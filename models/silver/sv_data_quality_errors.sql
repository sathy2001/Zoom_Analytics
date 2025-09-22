-- Silver Data Quality Errors Model
-- This model captures all data quality violations across silver tables

{{ config(
    materialized='table',
    unique_key='error_id'
) }}

WITH error_base AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['source_table', 'source_column', 'record_identifier', 'error_timestamp']) }} AS error_id,
        source_table,
        source_column,
        error_type,
        error_description,
        error_value,
        expected_format,
        record_identifier,
        error_timestamp,
        severity_level,
        'OPEN' AS resolution_status,
        CAST(NULL AS STRING) AS resolved_by,
        CAST(NULL AS TIMESTAMP_NTZ) AS resolution_timestamp,
        CURRENT_DATE() AS load_date,
        CURRENT_DATE() AS update_date,
        'DBT_PIPELINE' AS source_system,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM (
        SELECT 
            CAST(NULL AS STRING) AS source_table,
            CAST(NULL AS STRING) AS source_column,
            CAST(NULL AS STRING) AS error_type,
            CAST(NULL AS STRING) AS error_description,
            CAST(NULL AS STRING) AS error_value,
            CAST(NULL AS STRING) AS expected_format,
            CAST(NULL AS STRING) AS record_identifier,
            CAST(NULL AS TIMESTAMP_NTZ) AS error_timestamp,
            CAST(NULL AS STRING) AS severity_level
        WHERE 1=0  -- This ensures no rows are selected initially
    )
)

SELECT * FROM error_base