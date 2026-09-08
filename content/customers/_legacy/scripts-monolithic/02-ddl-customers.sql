-- CREATE DATABASE customers;

CREATE USER admin WITH PASSWORD 'test25**';

CREATE DATABASE customers_db WITH
    OWNER admin
    ENCODING 'UTF8'
    LC_COLLATE 'en_US.UTF-8'
    LC_CTYPE 'en_US.UTF-8'
    TEMPLATE template0;

GRANT ALL PRIVILEGES ON DATABASE customers_db TO admin;

-- CREATE SCHEMA
CREATE SCHEMA cs AUTHORIZATION admin;



-- CREATE TABLES;

CREATE TABLE cs.customers (
    id SERIAL PRIMARY KEY,
    id_number VARCHAR(50) UNIQUE NOT NULL,
    birth_date DATE NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cs.orders (
    id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10, 2) NULL,
    payment_method_id INT NULL

);

CREATE TABLE cs.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    usd_price DECIMAL(10, 2) NOT NULL,
    cop_price DECIMAL(10, 2) NULL,
    category_id INT NULL
);

CREATE TABLE cs.order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL
);

CREATE TABLE cs.categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cs.payment_methods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    create_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- RELATIONSHIPS;
ALTER TABLE cs.orders
ADD CONSTRAINT fk_customer
FOREIGN KEY (customer_id) REFERENCES cs.customers(id);

ALTER TABLE cs.order_items
ADD CONSTRAINT fk_order
FOREIGN KEY (order_id) REFERENCES cs.orders(id);

ALTER TABLE cs.order_items
ADD CONSTRAINT fk_product
FOREIGN KEY (product_id) REFERENCES cs.products(id);

ALTER TABLE cs.products
ADD CONSTRAINT fk_categories_id
FOREIGN KEY (category_id) REFERENCES cs.categories(id);

ALTER TABLE cs.orders
ADD CONSTRAINT fk_payment_method_id
FOREIGN KEY (payment_method_id) REFERENCES cs.payment_methods(id);

-- CONSTRAINTS
ALTER TABLE cs.customers
ADD CONSTRAINT chk_birth_date CHECK (birth_date < CURRENT_DATE);

ALTER TABLE cs.order_items
ADD CONSTRAINT chk_quantity CHECK (quantity > 0);