{% macro pre_audit_log() %}
  {% if this.name != 'sv_audit_log' %}
    INSERT INTO {{ ref('sv_audit_log') }} (
      process_id, table_name, process_start_time, status, records_processed
    )
    VALUES (
      '{{ invocation_id }}', '{{ this.name }}', CURRENT_TIMESTAMP(), 'STARTED', 0
    )
  {% endif %}
{% endmacro %}

{% macro post_audit_log() %}
  {% if this.name != 'sv_audit_log' %}
    UPDATE {{ ref('sv_audit_log') }}
    SET process_end_time = CURRENT_TIMESTAMP(),
        status = 'COMPLETED',
        records_processed = (SELECT COUNT(*) FROM {{ this }})
    WHERE process_id = '{{ invocation_id }}' AND table_name = '{{ this.name }}'
  {% endif %}
{% endmacro %}
