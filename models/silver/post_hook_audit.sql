-- Post-hook to log transformation metrics
{% if execute %}
    {% set record_count_query %}
        SELECT COUNT(*) FROM {{ this }}
    {% endset %}
    
    {% set error_count_query %}
        SELECT COUNT(*) FROM {{ ref('silver_orders_errors') }}
    {% endset %}
    
    {% set record_count = run_query(record_count_query).columns[0].values()[0] %}
    {% set error_count = run_query(error_count_query).columns[0].values()[0] %}
    
    {{ audit_log('silver_orders', 'SUCCESS', record_count, error_count) }}
    
    {{ log("Silver Orders Transformation Summary:", info=True) }}
    {{ log("- Successfully processed records: " ~ record_count, info=True) }}
    {{ log("- Records with data quality issues: " ~ error_count, info=True) }}
    {{ log("- Data quality success rate: " ~ (record_count / (record_count + error_count) * 100) ~ "%", info=True) }}
{% endif %}
