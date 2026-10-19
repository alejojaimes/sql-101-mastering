-- ##################################################
-- #        COFFEE COOP ALTER TABLE SCRIPT          #
-- ##################################################
-- This script adds all the constraints of the Coffee Cooperative database:
--   1. FOREIGN KEY  relationships between tables
--   2. UNIQUE       values that cannot be repeated
--   3. CHECK        valid values for some columns
-- Naming convention:
--   fk_<table>_<referenced table>
--   uq_<table>_<column(s)>
--   chk_<table>_<column>
-- RUN IN coffee_coop_db - cc_admin, after 02-create-tables.sql

-- ##################################################
-- #          1. FOREIGN KEYS                       #
-- ##################################################

-- Relationships for MUNICIPALITIES

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

-- Relationships for QUALITY_ANALYSES (1:1 with DELIVERIES)

ALTER TABLE buy.quality_analyses ADD CONSTRAINT fk_quality_analyses_deliveries
    FOREIGN KEY (delivery_id) REFERENCES buy.deliveries (delivery_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

-- Relationships for SETTLEMENTS (1:1 with DELIVERIES)

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
-- #          2. UNIQUE CONSTRAINTS                 #
-- ##################################################

-- ============================================
-- GEO
-- ============================================

-- Two departments cannot have the same name
ALTER TABLE geo.departments
ADD CONSTRAINT uq_departments_name UNIQUE (department_name);

-- A municipality name cannot be repeated inside the same department
ALTER TABLE geo.municipalities
ADD CONSTRAINT uq_municipalities_department_name UNIQUE (department_code, municipality_name);

-- ============================================
-- FARM
-- ============================================

ALTER TABLE farm.farmers
ADD CONSTRAINT uq_farmers_document_number UNIQUE (document_number);

ALTER TABLE farm.farmers
ADD CONSTRAINT uq_farmers_email UNIQUE (email);

-- A farmer cannot have two farms with the same name
ALTER TABLE farm.farms
ADD CONSTRAINT uq_farms_farmer_name UNIQUE (farmer_id, farm_name);

-- A plot code cannot be repeated inside the same farm
ALTER TABLE farm.plots
ADD CONSTRAINT uq_plots_farm_code UNIQUE (farm_id, plot_code);

ALTER TABLE farm.coffee_varieties
ADD CONSTRAINT uq_coffee_varieties_name UNIQUE (variety_name);

-- A variety cannot be registered twice in the same plot
ALTER TABLE farm.plot_varieties
ADD CONSTRAINT uq_plot_varieties_plot_variety UNIQUE (plot_id, variety_id);

ALTER TABLE farm.certifications
ADD CONSTRAINT uq_certifications_name UNIQUE (certification_name);

-- A farm cannot start the same certification twice on the same date
ALTER TABLE farm.farm_certifications
ADD CONSTRAINT uq_farm_certifications_period UNIQUE (farm_id, certification_id, start_date);

ALTER TABLE farm.farm_certifications
ADD CONSTRAINT uq_farm_certifications_number UNIQUE (certificate_number);

-- ============================================
-- BUY
-- ============================================

ALTER TABLE buy.collection_points
ADD CONSTRAINT uq_collection_points_name UNIQUE (point_name);

-- A collection point publishes only one price per day
ALTER TABLE buy.daily_prices
ADD CONSTRAINT uq_daily_prices_point_date UNIQUE (collection_point_id, price_date);

-- Only one quality analysis per delivery (1:1)
ALTER TABLE buy.quality_analyses
ADD CONSTRAINT uq_quality_analyses_delivery UNIQUE (delivery_id);

-- ============================================
-- PAY
-- ============================================

-- Only one settlement per delivery (1:1)
ALTER TABLE pay.settlements
ADD CONSTRAINT uq_settlements_delivery UNIQUE (delivery_id);

ALTER TABLE pay.payments
ADD CONSTRAINT uq_payments_transaction_reference UNIQUE (transaction_reference);

-- ##################################################
-- #          3. CHECK CONSTRAINTS                  #
-- ##################################################

-- ============================================
-- FARM
-- ============================================

ALTER TABLE farm.farmers
ADD CONSTRAINT chk_farmers_gender
CHECK (gender IN ('M', 'F', 'O'));

ALTER TABLE farm.farms
ADD CONSTRAINT chk_farms_total_area
CHECK (total_area_ha > 0);

ALTER TABLE farm.plots
ADD CONSTRAINT chk_plots_area
CHECK (area_ha > 0);

ALTER TABLE farm.plots
ADD CONSTRAINT chk_plots_shade_type
CHECK (shade_type IN ('full_sun', 'partial_shade', 'full_shade'));

ALTER TABLE farm.coffee_varieties
ADD CONSTRAINT chk_coffee_varieties_species
CHECK (species IN ('arabica', 'robusta'));

ALTER TABLE farm.plot_varieties
ADD CONSTRAINT chk_plot_varieties_percentage
CHECK (planted_percentage > 0 AND planted_percentage <= 100);

ALTER TABLE farm.certifications
ADD CONSTRAINT chk_certifications_premium
CHECK (premium_per_kg >= 0);

-- The end date must be after the start date (NULL means the certification is still valid)
ALTER TABLE farm.farm_certifications
ADD CONSTRAINT chk_farm_certifications_dates
CHECK (end_date > start_date);

-- ============================================
-- BUY
-- ============================================

ALTER TABLE buy.daily_prices
ADD CONSTRAINT chk_daily_prices_price
CHECK (price_per_kg > 0);

ALTER TABLE buy.deliveries
ADD CONSTRAINT chk_deliveries_coffee_type
CHECK (coffee_type IN ('dry_parchment', 'wet_parchment', 'cherry'));

ALTER TABLE buy.deliveries
ADD CONSTRAINT chk_deliveries_status
CHECK (status IN ('received', 'accepted', 'rejected', 'settled'));

ALTER TABLE buy.deliveries
ADD CONSTRAINT chk_deliveries_bag_count
CHECK (bag_count > 0);

ALTER TABLE buy.deliveries
ADD CONSTRAINT chk_deliveries_gross_weight
CHECK (gross_weight_kg > 0);

ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_moisture
CHECK (moisture_pct BETWEEN 0 AND 100);

-- ============================================
-- PAY
-- ============================================

ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_net_weight
CHECK (net_weight_kg > 0);

ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_price
CHECK (price_per_kg_applied > 0);

ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_deductions
CHECK (deductions_amount >= 0);

ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_status
CHECK (status IN ('pending', 'partially_paid', 'paid', 'cancelled'));

ALTER TABLE pay.payments
ADD CONSTRAINT chk_payments_amount
CHECK (amount > 0);

ALTER TABLE pay.payments
ADD CONSTRAINT chk_payments_method
CHECK (payment_method IN ('cash', 'bank_transfer', 'check'));

-- ##################################################
-- #                 END OF SCRIPT                  #
-- ##################################################
