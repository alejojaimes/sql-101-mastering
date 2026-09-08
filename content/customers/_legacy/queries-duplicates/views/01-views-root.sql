-- view of top 5 with clients with more orders
CREATE VIEW cs.v_top_customers_with_more_orders AS
WITH
customers_orders AS (
 	 SELECT
      customer_id,
      count(*) total_orders
   FROM cs.orders
   GROUP BY customer_id
),
top_customers AS (
	SELECT
  	t1.name AS customer,	
  	t1.id_number,
  	EXTRACT( YEAR FROM AGE(CURRENT_DATE, t1.birth_date)) AS Age,
  	t2.total_orders
  FROM cs.customers T1
  INNER JOIN customers_orders T2
  	ON T1.id = T2.customer_id
  ORDER BY 4 DESC
)
SELECT * 
FROM top_customers
LIMIT 5;

-- query: SELECT * FROM cs.v_top_customers_with_more_orders; 

-- view of order detail sorted by cop_price

CREATE VIEW cs.v_order_detail AS
SELECT 
	c.name AS customer, 
  o.id AS order_id, 
  p.name AS product,
  oi.quantity,
  MONEY(p.cop_price) as cop_price
FROM cs.customers c
JOIN cs.orders o ON o.customer_id = c.id
JOIN cs.order_items oi ON oi.order_id = o.id
JOIN cs.products p ON p.id = oi.product_id
ORDER BY 5 DESC;

-- query: SELECT * FROM cs.v_order_detail;


CREATE VIEW v_contacto_clientes AS
SELECT name, email, phone_number
FROM cs.customers;

-- Crear una vista
CREATE VIEW cs.v_customer_summary AS
SELECT
    c.id,
    c.name,
    c.email,
    COUNT(o.id)        AS total_ordenes,
    SUM(o.total)       AS gasto_total_usd
FROM cs.customers c
LEFT JOIN cs.orders o ON o.customer_id = c.id
GROUP BY c.id, c.name, c.email;

-- Consultar la vista igual que una tabla
SELECT * FROM cs.v_customer_summary
ORDER BY gasto_total_usd DESC;

-- Reemplazar sin eliminar
CREATE OR REPLACE VIEW cs.v_customer_summary AS
SELECT ...;


-- Eliminar una vista
DROP VIEW cs.v_customer_summary;

-- Eliminar solo si existe (no lanza error si no existe)
DROP VIEW IF EXISTS cs.v_customer_summary;

-- Eliminar múltiples vistas a la vez
DROP VIEW IF EXISTS
    cs.v_customer_summary,
    cs.v_order_detail;


CREATE MATERIALIZED VIEW cs.mv_sales_by_product AS
SELECT
    p.name                          AS product,
    SUM(oi.quantity)                AS sold_units,
    MONEY(SUM(oi.quantity * p.usd_price))  AS usd_incomes,
    MONEY(SUM(oi.quantity * p.cop_price))  AS cop_incomes
FROM  cs.order_items oi
JOIN  cs.products    p ON p.id = oi.product_id
GROUP BY p.id, p.name;

-- Los datos NO se actualizan solos, hay que refrescar manualmente
REFRESH MATERIALIZED VIEW cs.mv_sales_by_product;

-- Eliminarla
DROP MATERIALIZED VIEW IF EXISTS cs.mv_sales_by_product;


CREATE VIEW cs.v_expensive_products AS
SELECT id, name, usd_price
FROM cs.products
WHERE usd_price > 100
WITH CHECK OPTION;