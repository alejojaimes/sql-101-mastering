-- DELETE TRIGGERS AND FUNCTIONS
DROP TRIGGER IF EXISTS tgg_update_price_cop_af_ins ON cs.products;
DROP FUNCTION IF EXISTS cs.update_price_cop_af_ins();
DROP FUNCTION IF EXISTS cs.update_category_id(INT, INT);
DROP FUNCTION IF EXISTS cs.convert_usd_to_cop();
DROP FUNCTION IF EXISTS cs.update_total_orders();

-- DELETE VIEWS
DROP VIEW cs.v_contacto_clientes;
DROP VIEW cs.v_expensive_products;
DROP VIEW cs.v_top_customers_with_more_orders;
DROP MATERIALIZED VIEW cs.mv_sales_by_product;
DROP VIEW cs.v_order_detail;

-- DELETE TABLES RELATED TO THE SCHEMA CS
DROP TABLE IF EXISTS cs.order_items;
DROP TABLE IF EXISTS cs.orders;
DROP TABLE IF EXISTS cs.products;
DROP TABLE IF EXISTS cs.categories;
DROP TABLE IF EXISTS cs.payment_methods;
DROP TABLE IF EXISTS cs.customers;