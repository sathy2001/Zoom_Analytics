-- models/quarantine/customer_error_records.sql
{{ config(
    materialized='incremental',
    unique_key=['customer_id', 'process_timestamp'],
    tags=['quarantine', 'error_handling']
) }}

SELECT 
    customer_id,
    customer_name,
    email,
    created_date,
    combined_errors AS error_description,
    process_timestamp,
    source_table,
    record_hash,
    'QUARANTINED' AS record_status,
    {{ audit_columns() }}
FROM {{ ref('customer_silver') }}
WHERE has_error_flag = TRUE

{% if is_incremental() %}
    AND process_timestamp > (SELECT MAX(process_timestamp) FROM {{ this }})
{% endif %}
```

## DBT Project Configuration

```yaml
# dbt_project.yml (relevant sections)
models:
  your_project:
    silver:
      +materialized: table
      +tags: ["silver"]
    audit:
      +materialized: table
      +tags: ["audit"]
    quarantine:
      +materialized: incremental
      +tags: ["quarantine"]

tests:
  +store_failures: true
  +severity: warn

vars:
  pipeline_run_id: "{{ run_started_at.strftime('%Y%m%d_%H%M%S') }}"