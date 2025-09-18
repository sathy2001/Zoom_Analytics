-- models/audit/customer_transformation_audit.sql
{{ config(
    materialized='table',
    tags=['audit', 'monitoring']
) }}

WITH transformation_summary AS (
    SELECT 
        DATE(process_timestamp) AS transformation_date,
        COUNT(*) AS total_records_processed,
        COUNT(CASE WHEN has_error_flag = FALSE THEN 1 END) AS clean_records,
        COUNT(CASE WHEN has_error_flag = TRUE THEN 1 END) AS error_records,
        COUNT(CASE WHEN combined_errors LIKE '%CUSTOMER_ID_NULL%' THEN 1 END) AS null_customer_id_count,
        COUNT(CASE WHEN combined_errors LIKE '%CUSTOMER_NAME_MISSING%' THEN 1 END) AS missing_name_count,
        COUNT(CASE WHEN combined_errors LIKE '%INVALID_EMAIL_FORMAT%' THEN 1 END) AS invalid_email_count,
        COUNT(CASE WHEN combined_errors LIKE '%FUTURE_CREATED_DATE%' THEN 1 END) AS future_date_count,
        MIN(process_timestamp) AS batch_start_time,
        MAX(process_timestamp) AS batch_end_time,
        pipeline_run_id
    FROM {{ ref('customer_silver') }}
    GROUP BY DATE(process_timestamp), pipeline_run_id
)

SELECT 
    *,
    ROUND((clean_records * 100.0 / total_records_processed), 2) AS data_quality_score,
    CASE 
        WHEN (clean_records * 100.0 / total_records_processed) >= 95 THEN 'EXCELLENT'
        WHEN (clean_records * 100.0 / total_records_processed) >= 90 THEN 'GOOD'
        WHEN (clean_records * 100.0 / total_records_processed) >= 80 THEN 'FAIR'
        ELSE 'POOR'
    END AS quality_grade,
    {{ audit_columns() }}
FROM transformation_summary
