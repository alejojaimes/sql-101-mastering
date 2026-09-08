-- ADD PHONES TABLES

CREATE TABLE cs.phone_number(
    id SERIAL PRIMARY KEY,
    phone VARCHAR(50) NOT NULL,
    customer_id_number VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP  DEFAULT CURRENT_TIMESTAMP
);

-- ADD PHONE-CUSTOMER RELATIONSHIP
-- CARDINALITY-> 1:N
ALTER TABLE cs.phone_number 
ADD CONSTRAINT fk_phone_customer
FOREIGN KEY (customer_id_number) REFERENCES cs.customers (id_number);

-- ADD RELATIONSHIP: DOCUMENT TYPE
-- CARDINALITY-> 1:1
ALTER TABLE cs.customers
ADD COLUMN document_type_code VARCHAR(10) NULL;


ALTER TABLE cs.customers
ADD CONSTRAINT fk_doc_type
FOREIGN KEY (document_type_code) REFERENCES ctg.document_types (code);