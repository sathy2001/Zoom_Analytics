-- tests/silver/test_customer_silver_dq.sql

-- Test 1: Completeness - No null customer_id
SELECT 'completeness_customer_id' as test_name, COUNT(*) as failure_count
FROM {{ ref('customer_silver') }}
WHERE customer_id IS NULL

UNION ALL

-- Test 2: Completeness - No null customer_name
SELECT 'completeness_customer_name' as test_name, COUNT(*) as failure_count
FROM {{ ref('customer_silver') }}
WHERE customer_name IS NULL OR TRIM(customer_name) = ''

UNION ALL

-- Test 3: Validity - Email format validation
SELECT 'validity_email_format' as test_name, COUNT(*) as failure_count
FROM {{ ref('customer_silver') }}
WHERE email IS NOT NULL 
  AND NOT REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')

UNION ALL

-- Test 4: Consistency - Customer name length
SELECT 'consistency_name_length' as test_name, COUNT(*) as failure_count
FROM {{ ref('customer_silver') }}
WHERE LENGTH(TRIM(customer_name)) < 2 OR LENGTH(customer_name) > 100

UNION ALL

-- Test 5: Uniqueness - Customer ID uniqueness
SELECT 'uniqueness_customer_id' as test_name, COUNT(*) - COUNT(DISTINCT customer_id) as failure_count
FROM {{ ref('customer_silver') }}

UNION ALL

-- Test 6: Timeliness - Created date validation
SELECT 'timeliness_created_date' as test_name, COUNT(*) as failure_count
FROM {{ ref('customer_silver') }}
WHERE created_date > CURRENT_DATE() OR created_date < '1900-01-01'

UNION ALL

-- Test 7: Integrity - Process timestamp validation
SELECT 'integrity_process_timestamp' as test_name, COUNT(*) as failure_count
FROM {{ ref('customer_silver') }}
WHERE process_timestamp IS NULL