{% macro data_quality_summary(table_name) %}
SELECT
'{{ table_name }}' as table_name,
process_status,
COUNT(*) as record_count,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM {{ table_name }}
GROUP BY process_status
ORDER BY record_count DESC
{% endmacro %}