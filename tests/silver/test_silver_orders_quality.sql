-- Test to ensure no duplicate order_ids in silver layer
SELECT 
    order_id,
    COUNT(*) as duplicate_count
FROM {{ ref('silver_orders') }}
GROUP BY order_id
HAVING COUNT(*) > 1

SELECT *
FROM {{ ref('silver_orders') }}
WHERE quantity <= 0 
   OR price < 0 
   OR price > 1000000
   OR order_date > CURRENT_DATE()
   OR order_date < '2020-01-01'


SELECT *
FROM {{ ref('silver_orders') }}
WHERE order_id IS NULL 
   OR customer_id IS NULL 
   OR quantity IS NULL 
   OR price IS NULL 
   OR order_date IS NULL
   OR product_name IS NULL
