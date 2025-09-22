-- Macro for standardized data quality checks
{% macro calculate_dq_score(table_name, primary_key) %}
    CASE 
        WHEN {{ primary_key }} IS NULL THEN 0.0
        ELSE 
            (
                CASE WHEN {{ primary_key }} IS NOT NULL THEN 0.2 ELSE 0.0 END +
                CASE WHEN load_timestamp IS NOT NULL THEN 0.2 ELSE 0.0 END +
                CASE WHEN source_system IS NOT NULL THEN 0.2 ELSE 0.0 END +
                CASE WHEN update_timestamp IS NOT NULL THEN 0.2 ELSE 0.0 END +
                0.2  -- Base score for record existence
            )
    END
{% endmacro %}

{% macro log_dq_error(source_table, source_column, error_type, error_description, record_id, severity='WARNING') %}
    INSERT INTO {{ ref('sv_data_quality_errors') }} (
        error_id, source_table, source_column, error_type, error_description, 
        record_identifier, error_timestamp, severity_level, resolution_status,
        load_date, update_date, source_system, created_at, updated_at
    ) VALUES (
        {{ dbt_utils.generate_surrogate_key([source_table, source_column, record_id, 'CURRENT_TIMESTAMP()']) }},
        '{{ source_table }}',
        '{{ source_column }}',
        '{{ error_type }}',
        '{{ error_description }}',
        '{{ record_id }}',
        CURRENT_TIMESTAMP(),
        '{{ severity }}',
        'OPEN',
        CURRENT_DATE(),
        CURRENT_DATE(),
        'DBT_PIPELINE',
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    )
{% endmacro %}