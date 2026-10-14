-- ##################################################
-- #            DDL SCRIPT DOCUMENTATION            #
-- ##################################################
-- This script defines the database structure for the Coffee Cooperative system.
-- A cooperative buys parchment coffee from its member farmers. Each farmer owns farms,
-- each farm is divided into plots planted with one or more coffee varieties, and farms
-- may hold certifications. Deliveries are weighed at collection points, a quality
-- analysis is performed, and each accepted delivery is settled and paid.
-- Includes tables for DEPARTMENTS, MUNICIPALITIES, FARMERS, FARMS, PLOTS, COFFEE_VARIETIES,
-- PLOT_VARIETIES, CERTIFICATIONS, FARM_CERTIFICATIONS, COLLECTION_POINTS, DAILY_PRICES,
-- DELIVERIES, QUALITY_ANALYSES, SETTLEMENTS and PAYMENTS.
-- Primary keys, NOT NULL, UNIQUE, DEFAULT and FOREIGN KEY constraints are defined here.
-- CHECK constraints and indexes are defined in 03-alter-tables.sql.
-- Database Normalization: 4NF (Fourth Normal Form)
-- Target DBMS: PostgreSQL 16+

-- ##################################################
-- #                SCHEMA CREATION                 #
-- ##################################################

-- RUN IN coffee_coop_db - cc_admin
-- 04. Create schemas
CREATE SCHEMA IF NOT EXISTS geo  AUTHORIZATION cc_admin;
CREATE SCHEMA IF NOT EXISTS farm AUTHORIZATION cc_admin;
CREATE SCHEMA IF NOT EXISTS buy  AUTHORIZATION cc_admin;
CREATE SCHEMA IF NOT EXISTS pay  AUTHORIZATION cc_admin;

-- 05. Comment on database
COMMENT ON DATABASE coffee_coop_db IS 'Database for a coffee cooperative: farmers, farms, deliveries, quality and payments';

-- 06. Comment on schemas
COMMENT ON SCHEMA geo  IS 'Geographic catalogs: departments and municipalities';
COMMENT ON SCHEMA farm IS 'Farmers, farms, plots, coffee varieties and certifications';
COMMENT ON SCHEMA buy  IS 'Collection points, daily prices, deliveries and quality analyses';
COMMENT ON SCHEMA pay  IS 'Settlements and payments to farmers';

-- ##################################################
-- #          GEO MODULE - INDEPENDENT              #
-- ##################################################

-- Table: departments
-- Brief: Catalog of Colombian departments (DANE codes)
CREATE TABLE IF NOT EXISTS geo.departments (
    department_code VARCHAR(5)   NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_departments PRIMARY KEY (department_code),
    CONSTRAINT uq_departments_name UNIQUE (department_name)
);

COMMENT ON TABLE  geo.departments IS 'Catalog of departments (DANE)';
COMMENT ON COLUMN geo.departments.department_code IS 'DANE department code, e.g. 54';
COMMENT ON COLUMN geo.departments.department_name IS 'Department name, e.g. Norte de Santander';

-- Table: municipalities
-- Brief: Catalog of municipalities that belong to a department
CREATE TABLE IF NOT EXISTS geo.municipalities (
    municipality_code VARCHAR(10)  NOT NULL,
    municipality_name VARCHAR(100) NOT NULL,
    department_code   VARCHAR(5)   NOT NULL,
    CONSTRAINT pk_municipalities PRIMARY KEY (municipality_code),
    CONSTRAINT uq_municipalities_department_name UNIQUE (department_code, municipality_name)
);

COMMENT ON TABLE  geo.municipalities IS 'Catalog of municipalities (DANE)';
COMMENT ON COLUMN geo.municipalities.municipality_code IS 'DANE municipality code, e.g. 54518';
COMMENT ON COLUMN geo.municipalities.municipality_name IS 'Municipality name, e.g. Pamplona';
COMMENT ON COLUMN geo.municipalities.department_code   IS 'FK - Department the municipality belongs to';

-- ##################################################
-- #          FARM MODULE                           #
-- ##################################################

-- Table: farmers
-- Brief: Cooperative member farmers
CREATE TABLE IF NOT EXISTS farm.farmers (
    farmer_id         SERIAL       NOT NULL,
    document_number   VARCHAR(20)  NOT NULL,
    first_name        VARCHAR(60)  NOT NULL,
    last_name         VARCHAR(60)  NOT NULL,
    birth_date        DATE         NOT NULL,
    gender            CHAR(1)      NOT NULL,
    phone_number      VARCHAR(20)  NOT NULL,
    email             VARCHAR(120),
    membership_date   DATE         NOT NULL DEFAULT CURRENT_DATE,
    is_active         BOOLEAN      NOT NULL DEFAULT TRUE,
    municipality_code VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_farmers PRIMARY KEY (farmer_id),
    CONSTRAINT uq_farmers_document UNIQUE (document_number),
    CONSTRAINT uq_farmers_email UNIQUE (email)
);

COMMENT ON TABLE  farm.farmers IS 'Cooperative member farmers';
COMMENT ON COLUMN farm.farmers.farmer_id         IS 'Unique identifier of the farmer';
COMMENT ON COLUMN farm.farmers.document_number   IS 'National ID number (unique)';
COMMENT ON COLUMN farm.farmers.first_name        IS 'First name(s)';
COMMENT ON COLUMN farm.farmers.last_name         IS 'Last name(s)';
COMMENT ON COLUMN farm.farmers.birth_date        IS 'Date of birth';
COMMENT ON COLUMN farm.farmers.gender            IS 'Gender: M, F or O';
COMMENT ON COLUMN farm.farmers.phone_number      IS 'Contact phone number';
COMMENT ON COLUMN farm.farmers.email             IS 'Contact email (optional, unique)';
COMMENT ON COLUMN farm.farmers.membership_date   IS 'Date the farmer joined the cooperative';
COMMENT ON COLUMN farm.farmers.is_active         IS 'Indicates whether the membership is active';
COMMENT ON COLUMN farm.farmers.municipality_code IS 'FK - Municipality where the farmer lives';

-- Table: farms
-- Brief: Coffee farms owned by a farmer
CREATE TABLE IF NOT EXISTS farm.farms (
    farm_id           SERIAL        NOT NULL,
    farmer_id         INT           NOT NULL,
    municipality_code VARCHAR(10)   NOT NULL,
    farm_name         VARCHAR(100)  NOT NULL,
    rural_district    VARCHAR(100)  NOT NULL,
    total_area_ha     NUMERIC(8,2)  NOT NULL,
    altitude_masl     INT           NOT NULL,
    latitude          NUMERIC(9,6),
    longitude         NUMERIC(9,6),
    registered_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_farms PRIMARY KEY (farm_id),
    CONSTRAINT uq_farms_farmer_name UNIQUE (farmer_id, farm_name)
);

COMMENT ON TABLE  farm.farms IS 'Coffee farms owned by cooperative members';
COMMENT ON COLUMN farm.farms.farm_id           IS 'Unique identifier of the farm';
COMMENT ON COLUMN farm.farms.farmer_id         IS 'FK - Owner of the farm';
COMMENT ON COLUMN farm.farms.municipality_code IS 'FK - Municipality where the farm is located';
COMMENT ON COLUMN farm.farms.farm_name         IS 'Farm name (unique per farmer)';
COMMENT ON COLUMN farm.farms.rural_district    IS 'Rural district (vereda)';
COMMENT ON COLUMN farm.farms.total_area_ha     IS 'Total area in hectares';
COMMENT ON COLUMN farm.farms.altitude_masl     IS 'Altitude in meters above sea level';
COMMENT ON COLUMN farm.farms.latitude          IS 'Latitude (WGS84)';
COMMENT ON COLUMN farm.farms.longitude         IS 'Longitude (WGS84)';
COMMENT ON COLUMN farm.farms.registered_at     IS 'Registration timestamp';

-- Table: plots
-- Brief: Plots (lots) into which a farm is divided
CREATE TABLE IF NOT EXISTS farm.plots (
    plot_id        SERIAL        NOT NULL,
    farm_id        INT           NOT NULL,
    plot_code      VARCHAR(10)   NOT NULL,
    area_ha        NUMERIC(8,2)  NOT NULL,
    planting_year  SMALLINT      NOT NULL,
    shade_type     VARCHAR(20)   NOT NULL,
    CONSTRAINT pk_plots PRIMARY KEY (plot_id),
    CONSTRAINT uq_plots_farm_code UNIQUE (farm_id, plot_code)
);

COMMENT ON TABLE  farm.plots IS 'Plots (lots) into which a farm is divided';
COMMENT ON COLUMN farm.plots.plot_id       IS 'Unique identifier of the plot';
COMMENT ON COLUMN farm.plots.farm_id       IS 'FK - Farm the plot belongs to';
COMMENT ON COLUMN farm.plots.plot_code     IS 'Plot code inside the farm, e.g. L01 (unique per farm)';
COMMENT ON COLUMN farm.plots.area_ha       IS 'Plot area in hectares';
COMMENT ON COLUMN farm.plots.planting_year IS 'Year the plot was planted or renewed';
COMMENT ON COLUMN farm.plots.shade_type    IS 'Shade system: full_sun, partial_shade, full_shade';

-- Table: coffee_varieties
-- Brief: Catalog of coffee varieties
CREATE TABLE IF NOT EXISTS farm.coffee_varieties (
    variety_id         SERIAL       NOT NULL,
    variety_name       VARCHAR(60)  NOT NULL,
    species            VARCHAR(20)  NOT NULL,
    is_rust_resistant  BOOLEAN      NOT NULL DEFAULT FALSE,
    description        TEXT,
    CONSTRAINT pk_coffee_varieties PRIMARY KEY (variety_id),
    CONSTRAINT uq_coffee_varieties_name UNIQUE (variety_name)
);

COMMENT ON TABLE  farm.coffee_varieties IS 'Catalog of coffee varieties';
COMMENT ON COLUMN farm.coffee_varieties.variety_id        IS 'Unique identifier of the variety';
COMMENT ON COLUMN farm.coffee_varieties.variety_name      IS 'Variety name, e.g. Castillo, Caturra';
COMMENT ON COLUMN farm.coffee_varieties.species           IS 'Species: arabica or robusta';
COMMENT ON COLUMN farm.coffee_varieties.is_rust_resistant IS 'Indicates resistance to coffee leaf rust';
COMMENT ON COLUMN farm.coffee_varieties.description       IS 'Free text description';

-- Table: plot_varieties
-- Brief: N:M between plots and coffee varieties
CREATE TABLE IF NOT EXISTS farm.plot_varieties (
    plot_variety_id    SERIAL        NOT NULL,
    plot_id            INT           NOT NULL,
    variety_id         INT           NOT NULL,
    planted_percentage NUMERIC(5,2)  NOT NULL,
    tree_count         INT           NOT NULL,
    CONSTRAINT pk_plot_varieties PRIMARY KEY (plot_variety_id),
    CONSTRAINT uq_plot_varieties_plot_variety UNIQUE (plot_id, variety_id)
);

COMMENT ON TABLE  farm.plot_varieties IS 'Varieties planted in each plot (N:M)';
COMMENT ON COLUMN farm.plot_varieties.plot_variety_id    IS 'Unique identifier of the plot-variety record';
COMMENT ON COLUMN farm.plot_varieties.plot_id            IS 'FK - Plot';
COMMENT ON COLUMN farm.plot_varieties.variety_id         IS 'FK - Coffee variety';
COMMENT ON COLUMN farm.plot_varieties.planted_percentage IS 'Percentage of the plot planted with the variety';
COMMENT ON COLUMN farm.plot_varieties.tree_count         IS 'Number of trees of the variety in the plot';

-- Table: certifications
-- Brief: Catalog of certifications (Rainforest Alliance, Fairtrade, Organic, 4C...)
CREATE TABLE IF NOT EXISTS farm.certifications (
    certification_id   SERIAL         NOT NULL,
    certification_name VARCHAR(80)    NOT NULL,
    issuing_body       VARCHAR(100)   NOT NULL,
    premium_per_kg     NUMERIC(10,2)  NOT NULL DEFAULT 0,
    CONSTRAINT pk_certifications PRIMARY KEY (certification_id),
    CONSTRAINT uq_certifications_name UNIQUE (certification_name)
);

COMMENT ON TABLE  farm.certifications IS 'Catalog of farm certifications';
COMMENT ON COLUMN farm.certifications.certification_id   IS 'Unique identifier of the certification';
COMMENT ON COLUMN farm.certifications.certification_name IS 'Certification name';
COMMENT ON COLUMN farm.certifications.issuing_body       IS 'Organization that issues the certification';
COMMENT ON COLUMN farm.certifications.premium_per_kg     IS 'Price premium paid per kg (COP)';

-- Table: farm_certifications
-- Brief: N:M between farms and certifications, keeps the history of each period
CREATE TABLE IF NOT EXISTS farm.farm_certifications (
    farm_certification_id SERIAL       NOT NULL,
    farm_id               INT          NOT NULL,
    certification_id      INT          NOT NULL,
    start_date            DATE         NOT NULL,
    end_date              DATE,
    certificate_number    VARCHAR(40)  NOT NULL,
    CONSTRAINT pk_farm_certifications PRIMARY KEY (farm_certification_id),
    CONSTRAINT uq_farm_certifications_period UNIQUE (farm_id, certification_id, start_date),
    CONSTRAINT uq_farm_certifications_number UNIQUE (certificate_number)
);

COMMENT ON TABLE  farm.farm_certifications IS 'Certification periods held by each farm (N:M with history)';
COMMENT ON COLUMN farm.farm_certifications.farm_certification_id IS 'Unique identifier of the certification period';
COMMENT ON COLUMN farm.farm_certifications.farm_id            IS 'FK - Certified farm';
COMMENT ON COLUMN farm.farm_certifications.certification_id   IS 'FK - Certification';
COMMENT ON COLUMN farm.farm_certifications.start_date         IS 'Start of the certification period';
COMMENT ON COLUMN farm.farm_certifications.end_date           IS 'End of the period (NULL = still valid)';
COMMENT ON COLUMN farm.farm_certifications.certificate_number IS 'Certificate number (unique)';

-- ##################################################
-- #          BUY MODULE                            #
-- ##################################################

-- Table: collection_points
-- Brief: Places where the cooperative receives coffee
CREATE TABLE IF NOT EXISTS buy.collection_points (
    collection_point_id SERIAL        NOT NULL,
    point_name          VARCHAR(100)  NOT NULL,
    municipality_code   VARCHAR(10)   NOT NULL,
    address_line        VARCHAR(200)  NOT NULL,
    phone_number        VARCHAR(20),
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_collection_points PRIMARY KEY (collection_point_id),
    CONSTRAINT uq_collection_points_name UNIQUE (point_name)
);

COMMENT ON TABLE  buy.collection_points IS 'Coffee collection points of the cooperative';
COMMENT ON COLUMN buy.collection_points.collection_point_id IS 'Unique identifier of the collection point';
COMMENT ON COLUMN buy.collection_points.point_name          IS 'Collection point name';
COMMENT ON COLUMN buy.collection_points.municipality_code   IS 'FK - Municipality where it is located';
COMMENT ON COLUMN buy.collection_points.address_line        IS 'Street address';
COMMENT ON COLUMN buy.collection_points.phone_number        IS 'Contact phone number';
COMMENT ON COLUMN buy.collection_points.is_active           IS 'Indicates whether the point is operating';

-- Table: daily_prices
-- Brief: Purchase price published each day by each collection point
CREATE TABLE IF NOT EXISTS buy.daily_prices (
    daily_price_id         SERIAL         NOT NULL,
    collection_point_id    INT            NOT NULL,
    price_date             DATE           NOT NULL,
    price_per_kg           NUMERIC(10,2)  NOT NULL,
    reference_yield_factor NUMERIC(5,2)   NOT NULL DEFAULT 94.00,
    CONSTRAINT pk_daily_prices PRIMARY KEY (daily_price_id),
    CONSTRAINT uq_daily_prices_point_date UNIQUE (collection_point_id, price_date)
);

COMMENT ON TABLE  buy.daily_prices IS 'Daily purchase price per collection point';
COMMENT ON COLUMN buy.daily_prices.daily_price_id         IS 'Unique identifier of the price';
COMMENT ON COLUMN buy.daily_prices.collection_point_id    IS 'FK - Collection point that publishes the price';
COMMENT ON COLUMN buy.daily_prices.price_date             IS 'Date the price applies to';
COMMENT ON COLUMN buy.daily_prices.price_per_kg           IS 'Base price per kg of dry parchment coffee (COP)';
COMMENT ON COLUMN buy.daily_prices.reference_yield_factor IS 'Yield factor the base price refers to';

-- Table: deliveries
-- Brief: Coffee delivered by a farm at a collection point
CREATE TABLE IF NOT EXISTS buy.deliveries (
    delivery_id         SERIAL         NOT NULL,
    farm_id             INT            NOT NULL,
    collection_point_id INT            NOT NULL,
    delivered_at        TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    coffee_type         VARCHAR(20)    NOT NULL,
    bag_count           SMALLINT       NOT NULL,
    gross_weight_kg     NUMERIC(10,2)  NOT NULL,
    status              VARCHAR(20)    NOT NULL DEFAULT 'received',
    CONSTRAINT pk_deliveries PRIMARY KEY (delivery_id)
);

COMMENT ON TABLE  buy.deliveries IS 'Coffee deliveries received at collection points';
COMMENT ON COLUMN buy.deliveries.delivery_id         IS 'Unique identifier of the delivery';
COMMENT ON COLUMN buy.deliveries.farm_id             IS 'FK - Farm the coffee comes from';
COMMENT ON COLUMN buy.deliveries.collection_point_id IS 'FK - Collection point that receives the coffee';
COMMENT ON COLUMN buy.deliveries.delivered_at        IS 'Reception timestamp';
COMMENT ON COLUMN buy.deliveries.coffee_type         IS 'dry_parchment, wet_parchment or cherry';
COMMENT ON COLUMN buy.deliveries.bag_count           IS 'Number of bags delivered';
COMMENT ON COLUMN buy.deliveries.gross_weight_kg     IS 'Gross weight in kg';
COMMENT ON COLUMN buy.deliveries.status              IS 'received, accepted, rejected or settled';

-- Table: quality_analyses
-- Brief: Quality analysis of a delivery (1:1)
CREATE TABLE IF NOT EXISTS buy.quality_analyses (
    analysis_id   SERIAL        NOT NULL,
    delivery_id   INT           NOT NULL,
    analyzed_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    moisture_pct  NUMERIC(5,2)  NOT NULL,
    yield_factor  NUMERIC(5,2)  NOT NULL,
    defects_pct   NUMERIC(5,2)  NOT NULL DEFAULT 0,
    cup_score     NUMERIC(5,2),
    is_accepted   BOOLEAN       NOT NULL,
    analyst_name  VARCHAR(100)  NOT NULL,
    observations  TEXT,
    CONSTRAINT pk_quality_analyses PRIMARY KEY (analysis_id),
    CONSTRAINT uq_quality_analyses_delivery UNIQUE (delivery_id)
);

COMMENT ON TABLE  buy.quality_analyses IS 'Quality analysis performed on each delivery (1:1)';
COMMENT ON COLUMN buy.quality_analyses.analysis_id  IS 'Unique identifier of the analysis';
COMMENT ON COLUMN buy.quality_analyses.delivery_id  IS 'FK - Analyzed delivery (unique, enforces 1:1)';
COMMENT ON COLUMN buy.quality_analyses.analyzed_at  IS 'Analysis timestamp';
COMMENT ON COLUMN buy.quality_analyses.moisture_pct IS 'Moisture percentage';
COMMENT ON COLUMN buy.quality_analyses.yield_factor IS 'Yield factor (kg of parchment for 70 kg of green coffee)';
COMMENT ON COLUMN buy.quality_analyses.defects_pct  IS 'Percentage of defective beans';
COMMENT ON COLUMN buy.quality_analyses.cup_score    IS 'Cupping score 0-100 (optional)';
COMMENT ON COLUMN buy.quality_analyses.is_accepted  IS 'Indicates whether the delivery was accepted';
COMMENT ON COLUMN buy.quality_analyses.analyst_name IS 'Name of the analyst';
COMMENT ON COLUMN buy.quality_analyses.observations IS 'Free text observations';

-- ##################################################
-- #          PAY MODULE                            #
-- ##################################################

-- Table: settlements
-- Brief: Settlement of an accepted delivery (1:1)
CREATE TABLE IF NOT EXISTS pay.settlements (
    settlement_id        SERIAL         NOT NULL,
    delivery_id          INT            NOT NULL,
    daily_price_id       INT            NOT NULL,
    net_weight_kg        NUMERIC(10,2)  NOT NULL,
    price_per_kg_applied NUMERIC(10,2)  NOT NULL,
    deductions_amount    NUMERIC(14,2)  NOT NULL DEFAULT 0,
    gross_amount         NUMERIC(14,2)  GENERATED ALWAYS AS (ROUND(net_weight_kg * price_per_kg_applied, 2)) STORED,
    net_amount           NUMERIC(14,2)  GENERATED ALWAYS AS (ROUND(net_weight_kg * price_per_kg_applied, 2) - deductions_amount) STORED,
    settled_at           TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status               VARCHAR(20)    NOT NULL DEFAULT 'pending',
    CONSTRAINT pk_settlements PRIMARY KEY (settlement_id),
    CONSTRAINT uq_settlements_delivery UNIQUE (delivery_id)
);

COMMENT ON TABLE  pay.settlements IS 'Settlement of each accepted delivery (1:1)';
COMMENT ON COLUMN pay.settlements.settlement_id        IS 'Unique identifier of the settlement';
COMMENT ON COLUMN pay.settlements.delivery_id          IS 'FK - Settled delivery (unique, enforces 1:1)';
COMMENT ON COLUMN pay.settlements.daily_price_id       IS 'FK - Base daily price used';
COMMENT ON COLUMN pay.settlements.net_weight_kg        IS 'Net weight paid in kg';
COMMENT ON COLUMN pay.settlements.price_per_kg_applied IS 'Final price per kg after quality and premium adjustments';
COMMENT ON COLUMN pay.settlements.deductions_amount    IS 'Deductions (contributions, loans, etc.)';
COMMENT ON COLUMN pay.settlements.gross_amount         IS 'Derived: net_weight_kg * price_per_kg_applied';
COMMENT ON COLUMN pay.settlements.net_amount           IS 'Derived: gross_amount - deductions_amount';
COMMENT ON COLUMN pay.settlements.settled_at           IS 'Settlement timestamp';
COMMENT ON COLUMN pay.settlements.status               IS 'pending, partially_paid, paid or cancelled';

-- Table: payments
-- Brief: Payments made against a settlement (one settlement can be paid in parts)
CREATE TABLE IF NOT EXISTS pay.payments (
    payment_id            SERIAL         NOT NULL,
    settlement_id         INT            NOT NULL,
    payment_method        VARCHAR(20)    NOT NULL,
    amount                NUMERIC(14,2)  NOT NULL,
    paid_at               TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transaction_reference VARCHAR(60),
    CONSTRAINT pk_payments PRIMARY KEY (payment_id),
    CONSTRAINT uq_payments_reference UNIQUE (transaction_reference)
);

COMMENT ON TABLE  pay.payments IS 'Payments made to farmers';
COMMENT ON COLUMN pay.payments.payment_id            IS 'Unique identifier of the payment';
COMMENT ON COLUMN pay.payments.settlement_id         IS 'FK - Settlement being paid';
COMMENT ON COLUMN pay.payments.payment_method        IS 'cash, bank_transfer or check';
COMMENT ON COLUMN pay.payments.amount                IS 'Amount paid (COP)';
COMMENT ON COLUMN pay.payments.paid_at               IS 'Payment timestamp';
COMMENT ON COLUMN pay.payments.transaction_reference IS 'Bank or check reference (required if not cash)';

-- ##################################################
-- #          RELATIONSHIPS (FOREIGN KEYS)          #
-- ##################################################

-- Relationships for GEO

ALTER TABLE geo.municipalities ADD CONSTRAINT fk_municipalities_departments
    FOREIGN KEY (department_code) REFERENCES geo.departments (department_code)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for FARMERS

ALTER TABLE farm.farmers ADD CONSTRAINT fk_farmers_municipalities
    FOREIGN KEY (municipality_code) REFERENCES geo.municipalities (municipality_code)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for FARMS

ALTER TABLE farm.farms ADD CONSTRAINT fk_farms_farmers
    FOREIGN KEY (farmer_id) REFERENCES farm.farmers (farmer_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE farm.farms ADD CONSTRAINT fk_farms_municipalities
    FOREIGN KEY (municipality_code) REFERENCES geo.municipalities (municipality_code)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for PLOTS

ALTER TABLE farm.plots ADD CONSTRAINT fk_plots_farms
    FOREIGN KEY (farm_id) REFERENCES farm.farms (farm_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for PLOT_VARIETIES (N:M)

ALTER TABLE farm.plot_varieties ADD CONSTRAINT fk_plot_varieties_plots
    FOREIGN KEY (plot_id) REFERENCES farm.plots (plot_id)
    ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE farm.plot_varieties ADD CONSTRAINT fk_plot_varieties_coffee_varieties
    FOREIGN KEY (variety_id) REFERENCES farm.coffee_varieties (variety_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for FARM_CERTIFICATIONS (N:M)

ALTER TABLE farm.farm_certifications ADD CONSTRAINT fk_farm_certifications_farms
    FOREIGN KEY (farm_id) REFERENCES farm.farms (farm_id)
    ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE farm.farm_certifications ADD CONSTRAINT fk_farm_certifications_certifications
    FOREIGN KEY (certification_id) REFERENCES farm.certifications (certification_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for COLLECTION_POINTS

ALTER TABLE buy.collection_points ADD CONSTRAINT fk_collection_points_municipalities
    FOREIGN KEY (municipality_code) REFERENCES geo.municipalities (municipality_code)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for DAILY_PRICES

ALTER TABLE buy.daily_prices ADD CONSTRAINT fk_daily_prices_collection_points
    FOREIGN KEY (collection_point_id) REFERENCES buy.collection_points (collection_point_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for DELIVERIES

ALTER TABLE buy.deliveries ADD CONSTRAINT fk_deliveries_farms
    FOREIGN KEY (farm_id) REFERENCES farm.farms (farm_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE buy.deliveries ADD CONSTRAINT fk_deliveries_collection_points
    FOREIGN KEY (collection_point_id) REFERENCES buy.collection_points (collection_point_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for QUALITY_ANALYSES (1:1)

ALTER TABLE buy.quality_analyses ADD CONSTRAINT fk_quality_analyses_deliveries
    FOREIGN KEY (delivery_id) REFERENCES buy.deliveries (delivery_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for SETTLEMENTS (1:1)

ALTER TABLE pay.settlements ADD CONSTRAINT fk_settlements_deliveries
    FOREIGN KEY (delivery_id) REFERENCES buy.deliveries (delivery_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE pay.settlements ADD CONSTRAINT fk_settlements_daily_prices
    FOREIGN KEY (daily_price_id) REFERENCES buy.daily_prices (daily_price_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for PAYMENTS

ALTER TABLE pay.payments ADD CONSTRAINT fk_payments_settlements
    FOREIGN KEY (settlement_id) REFERENCES pay.settlements (settlement_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- ##################################################
-- #                 END OF SCRIPT                  #
-- ##################################################
