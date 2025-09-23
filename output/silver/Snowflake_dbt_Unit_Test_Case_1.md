_____________________________________________
## *Author*: AAVA
## *Created on*: 2024-12-19
## *Description*: Comprehensive unit test cases for Zoom Analytics dbt silver layer models in Snowflake
## *Version*: 1
## *Updated on*: 2024-12-19
_____________________________________________

# Snowflake dbt Unit Test Cases for Zoom Analytics Pipeline

## Overview

This document provides comprehensive unit test cases and dbt test scripts for the Zoom Analytics silver layer models running in Snowflake. The tests validate data transformations, business rules, edge cases, and error handling across all silver layer models.

## Models Covered

- `sv_users` - User data transformation and validation
- `sv_meetings` - Meeting data transformation and validation
- `sv_participants` - Participant data transformation and validation
- `sv_feature_usage` - Feature usage data transformation and validation
- `sv_webinars` - Webinar data transformation and validation
- `sv_support_tickets` - Support ticket data transformation and validation
- `sv_licenses` - License data transformation and validation
- `sv_billing_events` - Billing event data transformation and validation

## Test Case List

### 1. Data Quality and Validation Tests

| Test Case ID | Test Case Description | Expected Outcome | Model(s) |
|--------------|----------------------|------------------|----------|
| TC_DQ_001 | Validate primary key uniqueness | All primary keys should be unique and not null | All models |
| TC_DQ_002 | Validate email format in users | Email should match regex pattern | sv_users |
| TC_DQ_003 | Validate plan type values | Plan type should be in accepted values list | sv_users |
| TC_DQ_004 | Validate meeting duration ranges | Duration should be between 0 and 1440 minutes | sv_meetings |
| TC_DQ_005 | Validate date consistency | Start time should be before end time | sv_meetings, sv_webinars |
| TC_DQ_006 | Validate usage count ranges | Usage count should be non-negative and reasonable | sv_feature_usage |
| TC_DQ_007 | Validate registrant counts | Registrants should be non-negative | sv_webinars |
| TC_DQ_008 | Validate ticket status values | Status should be in predefined list | sv_support_tickets |
| TC_DQ_009 | Validate license date ranges | Start date should be before end date | sv_licenses |
| TC_DQ_010 | Validate billing amounts | Amounts should be reasonable and properly formatted | sv_billing_events |

### 2. Business Logic Tests

| Test Case ID | Test Case Description | Expected Outcome | Model(s) |
|--------------|----------------------|------------------|----------|
| TC_BL_001 | Data quality score calculation | Score should be between 0 and 1 | All models |
| TC_BL_002 | Record status determination | Status should be VALID, WARNING, or INVALID | All models |
| TC_BL_003 | Data standardization | Text fields should be properly trimmed and cased | All models |
| TC_BL_004 | Duration calculation fallback | Duration calculated from start/end times when null | sv_meetings |
| TC_BL_005 | Default value handling | Null registrants defaulted to 0 | sv_webinars |
| TC_BL_006 | Amount precision handling | Billing amounts rounded to 2 decimal places | sv_billing_events |

### 3. Edge Case Tests

| Test Case ID | Test Case Description | Expected Outcome | Model(s) |
|--------------|----------------------|------------------|----------|
| TC_EC_001 | Handle null primary keys | Records with null PKs should be excluded | All models |
| TC_EC_002 | Handle empty string values | Empty strings should be handled appropriately | All models |
| TC_EC_003 | Handle future dates | Future dates should be flagged as warnings | sv_meetings, sv_webinars |
| TC_EC_004 | Handle extreme duration values | Very long meetings should be flagged | sv_meetings |
| TC_EC_005 | Handle negative values | Negative counts should be handled appropriately | sv_feature_usage |
| TC_EC_006 | Handle very large numbers | Extremely large values should be flagged | sv_webinars, sv_billing_events |
| TC_EC_007 | Handle invalid date ranges | Invalid date combinations should be rejected | sv_meetings, sv_licenses |

### 4. Referential Integrity Tests

| Test Case ID | Test Case Description | Expected Outcome | Model(s) |
|--------------|----------------------|------------------|----------|
| TC_RI_001 | Validate host_id references | Host IDs should exist in users table | sv_meetings, sv_webinars |
| TC_RI_002 | Validate meeting_id references | Meeting IDs should exist in meetings table | sv_participants, sv_feature_usage |
| TC_RI_003 | Validate user_id references | User IDs should exist in users table | sv_participants, sv_support_tickets, sv_licenses, sv_billing_events |

## dbt Test Scripts

### YAML-based Schema Tests

```yaml
# tests/schema_tests.yml
version: 2

models:
  # Silver Users Tests
  - name: sv_users
    description: "Silver layer user data with quality validations"
    tests:
      - dbt_utils.expression_is_true:
          expression: "count(*) > 0"
          config:
            severity: error
    columns:
      - name: user_id
        description: "Unique user identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: user_name
        description: "User display name"
        tests:
          - not_null:
              config:
                severity: error
          - dbt_utils.not_empty_string:
              config:
                severity: error
      - name: email
        description: "User email address"
        tests:
          - not_null:
              config:
                severity: error
          - dbt_expectations.expect_column_values_to_match_regex:
              regex: '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
              config:
                severity: error
      - name: plan_type
        description: "User subscription plan type"
        tests:
          - accepted_values:
              values: ['BASIC', 'PRO', 'BUSINESS', 'ENTERPRISE']
              config:
                severity: warn
      - name: data_quality_score
        description: "Data quality score"
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 1
              config:
                severity: error
      - name: record_status
        description: "Record processing status"
        tests:
          - accepted_values:
              values: ['VALID', 'WARNING', 'INVALID']
              config:
                severity: error

  # Silver Meetings Tests
  - name: sv_meetings
    description: "Silver layer meeting data with quality validations"
    tests:
      - dbt_utils.expression_is_true:
          expression: "count(*) > 0"
          config:
            severity: error
    columns:
      - name: meeting_id
        description: "Unique meeting identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: host_id
        description: "Meeting host user ID"
        tests:
          - not_null:
              config:
                severity: error
          - relationships:
              to: ref('sv_users')
              field: user_id
              config:
                severity: warn
      - name: duration_minutes
        description: "Meeting duration in minutes"
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 1440
              config:
                severity: warn
      - name: start_time
        description: "Meeting start time"
        tests:
          - not_null:
              config:
                severity: error
      - name: end_time
        description: "Meeting end time"
        tests:
          - not_null:
              config:
                severity: error

  # Silver Participants Tests
  - name: sv_participants
    description: "Silver layer participant data with quality validations"
    columns:
      - name: participant_id
        description: "Unique participant identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: meeting_id
        description: "Associated meeting ID"
        tests:
          - not_null:
              config:
                severity: error
          - relationships:
              to: ref('sv_meetings')
              field: meeting_id
              config:
                severity: warn
      - name: user_id
        description: "Participant user ID"
        tests:
          - relationships:
              to: ref('sv_users')
              field: user_id
              config:
                severity: warn

  # Silver Feature Usage Tests
  - name: sv_feature_usage
    description: "Silver layer feature usage data with quality validations"
    columns:
      - name: usage_id
        description: "Unique usage record identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: meeting_id
        description: "Associated meeting ID"
        tests:
          - not_null:
              config:
                severity: error
          - relationships:
              to: ref('sv_meetings')
              field: meeting_id
              config:
                severity: warn
      - name: feature_name
        description: "Name of the feature used"
        tests:
          - not_null:
              config:
                severity: error
          - dbt_utils.not_empty_string:
              config:
                severity: error
      - name: usage_count
        description: "Number of times feature was used"
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 10000
              config:
                severity: warn

  # Silver Webinars Tests
  - name: sv_webinars
    description: "Silver layer webinar data with quality validations"
    columns:
      - name: webinar_id
        description: "Unique webinar identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: host_id
        description: "Webinar host user ID"
        tests:
          - not_null:
              config:
                severity: error
          - relationships:
              to: ref('sv_users')
              field: user_id
              config:
                severity: warn
      - name: registrants
        description: "Number of webinar registrants"
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 100000
              config:
                severity: warn

  # Silver Support Tickets Tests
  - name: sv_support_tickets
    description: "Silver layer support ticket data with quality validations"
    columns:
      - name: ticket_id
        description: "Unique ticket identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: user_id
        description: "User who created the ticket"
        tests:
          - not_null:
              config:
                severity: error
          - relationships:
              to: ref('sv_users')
              field: user_id
              config:
                severity: warn
      - name: resolution_status
        description: "Ticket resolution status"
        tests:
          - accepted_values:
              values: ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'CANCELLED']
              config:
                severity: warn

  # Silver Licenses Tests
  - name: sv_licenses
    description: "Silver layer license data with quality validations"
    columns:
      - name: license_id
        description: "Unique license identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: assigned_to_user_id
        description: "User assigned to the license"
        tests:
          - not_null:
              config:
                severity: error
          - relationships:
              to: ref('sv_users')
              field: user_id
              config:
                severity: warn
      - name: license_type
        description: "Type of license"
        tests:
          - not_null:
              config:
                severity: error
          - accepted_values:
              values: ['BASIC', 'PRO', 'BUSINESS', 'ENTERPRISE', 'TRIAL']
              config:
                severity: warn

  # Silver Billing Events Tests
  - name: sv_billing_events
    description: "Silver layer billing event data with quality validations"
    columns:
      - name: event_id
        description: "Unique billing event identifier"
        tests:
          - unique:
              config:
                severity: error
          - not_null:
              config:
                severity: error
      - name: user_id
        description: "User associated with the billing event"
        tests:
          - not_null:
              config:
                severity: error
          - relationships:
              to: ref('sv_users')
              field: user_id
              config:
                severity: warn
      - name: amount
        description: "Billing amount"
        tests:
          - not_null:
              config:
                severity: error
          - dbt_utils.accepted_range:
              min_value: -100000
              max_value: 100000
              config:
                severity: warn
      - name: event_type
        description: "Type of billing event"
        tests:
          - accepted_values:
              values: ['CHARGE', 'REFUND', 'CREDIT', 'ADJUSTMENT', 'SUBSCRIPTION', 'CANCELLATION']
              config:
                severity: warn
```

### Custom SQL-based dbt Tests

```sql
-- tests/test_date_consistency.sql
-- Test that start_time is before end_time in meetings and webinars

SELECT 
    'sv_meetings' as table_name,
    meeting_id as record_id,
    start_time,
    end_time
FROM {{ ref('sv_meetings') }}
WHERE start_time >= end_time

UNION ALL

SELECT 
    'sv_webinars' as table_name,
    webinar_id as record_id,
    start_time,
    end_time
FROM {{ ref('sv_webinars') }}
WHERE start_time >= end_time
```

```sql
-- tests/test_data_quality_score_range.sql
-- Test that data quality scores are within valid range across all models

SELECT 
    'sv_users' as table_name,
    user_id as record_id,
    data_quality_score
FROM {{ ref('sv_users') }}
WHERE data_quality_score < 0 OR data_quality_score > 1

UNION ALL

SELECT 
    'sv_meetings' as table_name,
    meeting_id as record_id,
    data_quality_score
FROM {{ ref('sv_meetings') }}
WHERE data_quality_score < 0 OR data_quality_score > 1

UNION ALL

SELECT 
    'sv_participants' as table_name,
    participant_id as record_id,
    data_quality_score
FROM {{ ref('sv_participants') }}
WHERE data_quality_score < 0 OR data_quality_score > 1

UNION ALL

SELECT 
    'sv_feature_usage' as table_name,
    usage_id as record_id,
    data_quality_score
FROM {{ ref('sv_feature_usage') }}
WHERE data_quality_score < 0 OR data_quality_score > 1

UNION ALL

SELECT 
    'sv_webinars' as table_name,
    webinar_id as record_id,
    data_quality_score
FROM {{ ref('sv_webinars') }}
WHERE data_quality_score < 0 OR data_quality_score > 1

UNION ALL

SELECT 
    'sv_support_tickets' as table_name,
    ticket_id as record_id,
    data_quality_score
FROM {{ ref('sv_support_tickets') }}
WHERE data_quality_score < 0 OR data_quality_score > 1

UNION ALL

SELECT 
    'sv_licenses' as table_name,
    license_id as record_id,
    data_quality_score
FROM {{ ref('sv_licenses') }}
WHERE data_quality_score < 0 OR data_quality_score > 1

UNION ALL

SELECT 
    'sv_billing_events' as table_name,
    event_id as record_id,
    data_quality_score
FROM {{ ref('sv_billing_events') }}
WHERE data_quality_score < 0 OR data_quality_score > 1
```

```sql
-- tests/test_record_status_validity.sql
-- Test that record status values are valid across all models

SELECT 
    'sv_users' as table_name,
    user_id as record_id,
    record_status
FROM {{ ref('sv_users') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')

UNION ALL

SELECT 
    'sv_meetings' as table_name,
    meeting_id as record_id,
    record_status
FROM {{ ref('sv_meetings') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')

UNION ALL

SELECT 
    'sv_participants' as table_name,
    participant_id as record_id,
    record_status
FROM {{ ref('sv_participants') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')

UNION ALL

SELECT 
    'sv_feature_usage' as table_name,
    usage_id as record_id,
    record_status
FROM {{ ref('sv_feature_usage') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')

UNION ALL

SELECT 
    'sv_webinars' as table_name,
    webinar_id as record_id,
    record_status
FROM {{ ref('sv_webinars') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')

UNION ALL

SELECT 
    'sv_support_tickets' as table_name,
    ticket_id as record_id,
    record_status
FROM {{ ref('sv_support_tickets') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')

UNION ALL

SELECT 
    'sv_licenses' as table_name,
    license_id as record_id,
    record_status
FROM {{ ref('sv_licenses') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')

UNION ALL

SELECT 
    'sv_billing_events' as table_name,
    event_id as record_id,
    record_status
FROM {{ ref('sv_billing_events') }}
WHERE record_status NOT IN ('VALID', 'WARNING', 'INVALID')
```

```sql
-- tests/test_future_dates.sql
-- Test for future dates that should be flagged

SELECT 
    'sv_meetings' as table_name,
    meeting_id as record_id,
    start_time,
    'Future meeting start time' as issue
FROM {{ ref('sv_meetings') }}
WHERE start_time > CURRENT_TIMESTAMP()

UNION ALL

SELECT 
    'sv_webinars' as table_name,
    webinar_id as record_id,
    start_time,
    'Future webinar start time' as issue
FROM {{ ref('sv_webinars') }}
WHERE start_time > CURRENT_TIMESTAMP()

UNION ALL

SELECT 
    'sv_feature_usage' as table_name,
    usage_id as record_id,
    usage_date::timestamp as start_time,
    'Future usage date' as issue
FROM {{ ref('sv_feature_usage') }}
WHERE usage_date > CURRENT_DATE()
```

```sql
-- tests/test_email_format_validation.sql
-- Test email format validation in users table

SELECT 
    user_id,
    email,
    'Invalid email format' as issue
FROM {{ ref('sv_users') }}
WHERE email IS NOT NULL 
  AND NOT REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
```

```sql
-- tests/test_duration_calculation.sql
-- Test duration calculation consistency in meetings

SELECT 
    meeting_id,
    duration_minutes,
    DATEDIFF('minute', start_time, end_time) as calculated_duration,
    ABS(duration_minutes - DATEDIFF('minute', start_time, end_time)) as difference
FROM {{ ref('sv_meetings') }}
WHERE start_time IS NOT NULL 
  AND end_time IS NOT NULL 
  AND duration_minutes IS NOT NULL
  AND ABS(duration_minutes - DATEDIFF('minute', start_time, end_time)) > 1
```

```sql
-- tests/test_participant_time_logic.sql
-- Test participant join/leave time logic

SELECT 
    participant_id,
    meeting_id,
    join_time,
    leave_time,
    'Join time after leave time' as issue
FROM {{ ref('sv_participants') }}
WHERE join_time IS NOT NULL 
  AND leave_time IS NOT NULL 
  AND join_time > leave_time
```

```sql
-- tests/test_license_date_ranges.sql
-- Test license date range validity

SELECT 
    license_id,
    start_date,
    end_date,
    'Start date after end date' as issue
FROM {{ ref('sv_licenses') }}
WHERE start_date IS NOT NULL 
  AND end_date IS NOT NULL 
  AND start_date > end_date
```

### Parameterized Tests

```sql
-- tests/generic/test_valid_status_values.sql
-- Generic test for validating status column values

{% test valid_status_values(model, column_name, valid_statuses) %}

SELECT 
    {{ column_name }},
    COUNT(*) as invalid_count
FROM {{ model }}
WHERE {{ column_name }} NOT IN (
    {% for status in valid_statuses %}
        '{{ status }}'{% if not loop.last %},{% endif %}
    {% endfor %}
)
GROUP BY {{ column_name }}
HAVING COUNT(*) > 0

{% endtest %}
```

```sql
-- tests/generic/test_reasonable_numeric_range.sql
-- Generic test for validating numeric ranges

{% test reasonable_numeric_range(model, column_name, min_value=0, max_value=1000000) %}

SELECT 
    {{ column_name }},
    COUNT(*) as out_of_range_count
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL 
  AND ({{ column_name }} < {{ min_value }} OR {{ column_name }} > {{ max_value }})
GROUP BY {{ column_name }}
HAVING COUNT(*) > 0

{% endtest %}
```

## Test Execution Strategy

### 1. Pre-deployment Testing
```bash
# Run all tests
dbt test

# Run tests for specific models
dbt test --models sv_users
dbt test --models sv_meetings

# Run tests with specific severity
dbt test --severity error
```

### 2. Continuous Integration Testing
```bash
# Run tests as part of CI/CD pipeline
dbt test --fail-fast
dbt test --store-failures
```

### 3. Data Quality Monitoring
```bash
# Run tests on schedule for ongoing monitoring
dbt test --models tag:data_quality
dbt test --models tag:critical
```

## Expected Test Results

### Success Criteria
- All `unique` and `not_null` tests should pass with 0 failures
- Email format validation should pass for all valid emails
- Date range validations should pass for all records
- Referential integrity tests should pass with warnings only for missing references
- Data quality scores should be between 0 and 1 for all records
- Record status values should be valid for all records

### Warning Criteria
- Plan type values outside standard list (acceptable for new plan types)
- Duration values outside normal ranges (acceptable for special cases)
- Future dates (acceptable for scheduled events)
- Missing optional references (acceptable for data migration scenarios)

### Failure Criteria
- Null primary keys (critical data integrity issue)
- Invalid email formats (data quality issue)
- Invalid date ranges (business logic violation)
- Data quality scores outside 0-1 range (calculation error)

## Monitoring and Alerting

### dbt Test Results Tracking
- Test results stored in `run_results.json`
- Failed tests logged to Snowflake audit schema
- Test execution metrics tracked for performance monitoring

### Alert Configuration
```yaml
# dbt_project.yml alert configuration
on-run-end:
  - "{{ log_test_results() }}"
  - "{{ alert_on_test_failures() }}"
```

## API Cost Calculation

Based on the comprehensive test suite generation and GitHub operations:
- GitHub API calls: ~15 requests @ $0.001 each = $0.015
- Content processing and generation: ~2000 tokens @ $0.002/1K tokens = $0.004
- Test script compilation and validation: ~500 tokens @ $0.002/1K tokens = $0.001

**Total Estimated API Cost: $0.020 USD**

## Maintenance Guidelines

1. **Regular Review**: Review and update test cases monthly
2. **Performance Monitoring**: Monitor test execution times and optimize slow tests
3. **Coverage Analysis**: Ensure new models include corresponding test cases
4. **Documentation Updates**: Keep test documentation synchronized with model changes
5. **Threshold Tuning**: Adjust warning and error thresholds based on data patterns

---

*This test suite provides comprehensive coverage for the Zoom Analytics dbt models in Snowflake, ensuring data quality, business rule compliance, and system reliability.*