SELECT *
FROM cs.orders
LIMIT 10;


SELECT *
FROM cs.products
LIMIT 10;


SELECT customer_id, count(*)
FROM cs.orders
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY 2 DESC;

SELECT * FROM cs.orders WHERE customer_id = 74;

SELECT * FROM cs.orders WHERE total IS NULL;


-------



-- CUSTOMER_ID : 42
-- ORDER ID: 

SELECT 
      T1.customer_id,
      T2.id
FROM cs.orders T1
LEFT JOIN cs.order_items T2
  ON T1.id = T2.order_id
WHERE T1.customer_id = 42;


-------------
SELECT * FROM cs.products LIMIT 5;

SELECT
  money(usd_price) AS usd_price,
  money((usd_price * 3750)) AS cop_price_test
FROM cs.products
WHERE id = 1;

--- CREATE FUNCTION
CREATE OR REPLACE FUNCTION update_price_usd_to_cop()
RETURNS TEXT
LANGUAGE plpgsql
AS
$$
  DECLARE 
    rows_affected INT;
  BEGIN
    UPDATE cs.products
    SET cop_price = (3750 * usd_price);

    GET DIAGNOSTICS rows_affected = ROW_COUNT;

    RETURN 'Rows affected: '|| rows_affected;
  END;
$$;

SELECT update_price_usd_to_cop();

-- total = cant productos * cop_price


SELECT 
  T1.customer_id,
  T2.order_id,
  COUNT(*) AS total_records
FROM cs.orders T1
INNER JOIN cs.order_items T2
  ON T1.id = T2.order_id
GROUP BY T1.customer_id, T2.order_id
HAVING COUNT(*) > 1
ORDER BY 2 DESC
LIMIT 5;

SELECT * FROM cs.order_items WHERE order_id = 250;
-- 1.137.825.00
SELECT * FROM cs.orders WHERE id = 250;

SELECT
  F.order_id,
  SUM(F.order_payment) AS total
FROM (

SELECT
  T1.order_id,
  T1.product_id,
  T1.quantity,
  T2.cop_price,
  (T1.quantity * T2.cop_price) AS order_payment
FROM cs.order_items T1
INNER JOIN cs.products T2
  ON T1.product_id = T2.id
WHERE T1.order_id = 250
  ) F
GROUP BY F.order_id;

----
-- 35 RECORDS MISSING
SELECT COUNT(*) AS TOTAL_NULLS
FROM cs.orders WHERE total IS NULL;

SELECT id
FROM cs.orders WHERE total IS NULL
LIMIT 5;
-- 9

SELECT coalesce(total, 0) FROM cs.orders 
  WHERE id IN (9, 16, 17);

-- CHECK VALIDATION

SELECT *
FROM cs.orders T1
LEFT JOIN cs.order_items T2
  ON T1.id = T2.order_id
WHERE T1.id IN (9, 16, 17);

----------------
-- fmardell0@pen.io
SELECT 
    SPLIT_PART(email, '@', 2) AS email_domain,
    COUNT(*) as total_records
FROM cs.customers
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;