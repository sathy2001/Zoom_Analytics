{% macro handle_dq_errors(table_name) %}
    
    {% set error_summary_query %}
        SELECT 
            dq_error_list,
            COUNT(*) as error_count
        FROM {{ ref(table_name) }}
        WHERE dq_error_flag = TRUE
        GROUP BY dq_error_list
    {% endset %}
    
    {% if execute %}
        {% set results = run_query(error_summary_query) %}
        {% if results.rows %}
            {{ log("Data Quality Issues Found in " ~ table_name ~ ":", info=true) }}
            {% for row in results.rows %}
                {{ log("Error Types: " ~ row[0] ~ " | Count: " ~ row[1], info=true) }}
            {% endfor %}
        {% endif %}
    {% endif %}
    
{% endmacro %}