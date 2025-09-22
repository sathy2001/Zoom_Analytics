{% macro data_quality_check(table_name, check_type, column_name, condition) %}
    {% set query %}
        SELECT COUNT(*) as failed_records
        FROM {{ ref(table_name) }}
        WHERE {{ condition }}
    {% endset %}
    
    {% set results = run_query(query) %}
    {% if results %}
        {% set failed_count = results.columns[0].values()[0] %}
        {% if failed_count > 0 %}
            {{ log("Data Quality Check FAILED: " ~ check_type ~ " on " ~ column_name ~ " - " ~ failed_count ~ " records failed", info=True) }}
        {% else %}
            {{ log("Data Quality Check PASSED: " ~ check_type ~ " on " ~ column_name, info=True) }}
        {% endif %}
    {% endif %}
{% endmacro %}
