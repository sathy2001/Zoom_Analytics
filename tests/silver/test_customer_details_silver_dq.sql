-- tests/silver/test_customer_details_silver_dq.sql

-- Test for critical null values
SELECT 'Critical Null Check' AS test_name,
       COUNT(*) AS failed_records
FROM {{ ref('customer_details_silver') }}
WHERE customer_id IS NULL 
   OR customer_name IS NULL 
   OR email IS NULL
HAVING COUNT(*) > 0

UNION ALL

-- Test for invalid email formats
SELECT 'Email Format Check' AS test_name,
       COUNT(*) AS failed_records
FROM {{ ref('customer_details_silver') }}
WHERE NOT REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$')
   AND dq_error_flag = FALSE
HAVING COUNT(*) > 0

UNION ALL

-- Test for timestamp consistency
SELECT 'Timestamp Consistency Check' AS test_name,
       COUNT(*) AS failed_records
FROM {{ ref('customer_details_silver') }}
WHERE updated_at < created_at
   AND dq_error_flag = FALSE
HAVING COUNT(*) > 0

UNION ALL

-- Test for duplicate customer IDs
SELECT 'Duplicate Customer ID Check' AS test_name,
       COUNT(*) AS failed_records
FROM (
    SELECT customer_id, COUNT(*) as cnt
    FROM {{ ref('customer_details_silver') }}
    WHERE processing_decision = 'INCLUDED'
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)
HAVING COUNT(*) > 0

