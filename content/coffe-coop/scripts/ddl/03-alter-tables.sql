-- ##################################################
-- #        COFFEE COOP ALTER TABLE SCRIPT          #
-- ##################################################
-- This script adds the CHECK constraints (domain and business rules) and the
-- indexes on foreign keys for the Coffee Cooperative database.
-- Naming convention:
--   chk_<table>_<rule>   CHECK constraint
--   idx_<table>_<column> index
-- RUN IN coffee_coop_db - cc_admin, after 02-create-tables.sql

-- ##################################################
-- #          CHECK CONSTRAINTS - FARM MODULE       #
-- ##################################################

-- ============================================
-- FARMERS
-- ============================================

ALTER TABLE farm.farmers
ADD CONSTRAINT chk_farmers_gender
CHECK (gender IN ('M', 'F', 'O'));

-- A farmer must be at least 18 years old when joining the cooperative
ALTER TABLE farm.farmers
ADD CONSTRAINT chk_farmers_adult_member
CHECK (membership_date >= birth_date + INTERVAL '18 years');

ALTER TABLE farm.farmers
ADD CONSTRAINT chk_farmers_email_format
CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE farm.farmers
ADD CONSTRAINT chk_farmers_document_digits
CHECK (document_number ~ '^[0-9]{6,12}$');

-- ============================================
-- FARMS
-- ============================================

ALTER TABLE farm.farms
ADD CONSTRAINT chk_farms_total_area
CHECK (total_area_ha > 0);

ALTER TABLE farm.farms
ADD CONSTRAINT chk_farms_altitude
CHECK (altitude_masl BETWEEN 0 AND 3500);

-- Coordinates must fall inside the bounding box of Colombia
ALTER TABLE farm.farms
ADD CONSTRAINT chk_farms_latitude
CHECK (latitude IS NULL OR latitude BETWEEN -4.30 AND 13.50);

ALTER TABLE farm.farms
ADD CONSTRAINT chk_farms_longitude
CHECK (longitude IS NULL OR longitude BETWEEN -82.00 AND -66.80);

-- Latitude and longitude are registered together or not at all
ALTER TABLE farm.farms
ADD CONSTRAINT chk_farms_coordinates_pair
CHECK ((latitude IS NULL) = (longitude IS NULL));

-- ============================================
-- PLOTS
-- ============================================

ALTER TABLE farm.plots
ADD CONSTRAINT chk_plots_area
CHECK (area_ha > 0);

ALTER TABLE farm.plots
ADD CONSTRAINT chk_plots_planting_year
CHECK (planting_year >= 1950);

ALTER TABLE farm.plots
ADD CONSTRAINT chk_plots_shade_type
CHECK (shade_type IN ('full_sun', 'partial_shade', 'full_shade'));

-- ============================================
-- COFFEE VARIETIES
-- ============================================

ALTER TABLE farm.coffee_varieties
ADD CONSTRAINT chk_coffee_varieties_species
CHECK (species IN ('arabica', 'robusta'));

-- ============================================
-- PLOT VARIETIES
-- ============================================

ALTER TABLE farm.plot_varieties
ADD CONSTRAINT chk_plot_varieties_percentage
CHECK (planted_percentage > 0 AND planted_percentage <= 100);

ALTER TABLE farm.plot_varieties
ADD CONSTRAINT chk_plot_varieties_tree_count
CHECK (tree_count > 0);

-- ============================================
-- CERTIFICATIONS
-- ============================================

ALTER TABLE farm.certifications
ADD CONSTRAINT chk_certifications_premium
CHECK (premium_per_kg >= 0);

ALTER TABLE farm.farm_certifications
ADD CONSTRAINT chk_farm_certifications_period
CHECK (end_date IS NULL OR end_date > start_date);

-- ##################################################
-- #          CHECK CONSTRAINTS - BUY MODULE        #
-- ##################################################

-- ============================================
-- DAILY PRICES
-- ============================================

ALTER TABLE buy.daily_prices
ADD CONSTRAINT chk_daily_prices_price
CHECK (price_per_kg > 0);

ALTER TABLE buy.daily_prices
ADD CONSTRAINT chk_daily_prices_yield_factor
CHECK (reference_yield_factor BETWEEN 70 AND 120);

-- ============================================
-- DELIVERIES
-- ============================================

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

-- ============================================
-- QUALITY ANALYSES
-- ============================================

ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_moisture
CHECK (moisture_pct BETWEEN 0 AND 100);

ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_yield_factor
CHECK (yield_factor BETWEEN 70 AND 120);

ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_defects
CHECK (defects_pct BETWEEN 0 AND 100);

ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_cup_score
CHECK (cup_score IS NULL OR cup_score BETWEEN 0 AND 100);

-- Business rule: an accepted delivery must have moisture between 10% and 12.5%
ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_accepted_moisture
CHECK (NOT is_accepted OR moisture_pct BETWEEN 10 AND 12.5);

-- ##################################################
-- #          CHECK CONSTRAINTS - PAY MODULE        #
-- ##################################################

-- ============================================
-- SETTLEMENTS
-- ============================================

ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_net_weight
CHECK (net_weight_kg > 0);

ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_price
CHECK (price_per_kg_applied > 0);

-- Deductions cannot be negative nor exceed the gross amount
ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_deductions
CHECK (deductions_amount >= 0 AND deductions_amount <= ROUND(net_weight_kg * price_per_kg_applied, 2));

ALTER TABLE pay.settlements
ADD CONSTRAINT chk_settlements_status
CHECK (status IN ('pending', 'partially_paid', 'paid', 'cancelled'));

-- ============================================
-- PAYMENTS
-- ============================================

ALTER TABLE pay.payments
ADD CONSTRAINT chk_payments_amount
CHECK (amount > 0);

ALTER TABLE pay.payments
ADD CONSTRAINT chk_payments_method
CHECK (payment_method IN ('cash', 'bank_transfer', 'check'));

-- Non-cash payments must carry a bank or check reference
ALTER TABLE pay.payments
ADD CONSTRAINT chk_payments_reference_required
CHECK (payment_method = 'cash' OR transaction_reference IS NOT NULL);

-- ##################################################
-- #          INDEXES ON FOREIGN KEYS               #
-- ##################################################
-- PostgreSQL does not index foreign keys automatically.
-- FKs that are already the first column of a PK or UNIQUE constraint are skipped.

CREATE INDEX IF NOT EXISTS idx_municipalities_department_code ON geo.municipalities (department_code);
CREATE INDEX IF NOT EXISTS idx_farmers_municipality_code     ON farm.farmers (municipality_code);
CREATE INDEX IF NOT EXISTS idx_farms_municipality_code       ON farm.farms (municipality_code);
CREATE INDEX IF NOT EXISTS idx_plot_varieties_variety_id     ON farm.plot_varieties (variety_id);
CREATE INDEX IF NOT EXISTS idx_farm_certifications_cert_id   ON farm.farm_certifications (certification_id);
CREATE INDEX IF NOT EXISTS idx_collection_points_municipality ON buy.collection_points (municipality_code);
CREATE INDEX IF NOT EXISTS idx_deliveries_farm_id            ON buy.deliveries (farm_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_collection_point   ON buy.deliveries (collection_point_id, delivered_at);
CREATE INDEX IF NOT EXISTS idx_settlements_daily_price_id    ON pay.settlements (daily_price_id);
CREATE INDEX IF NOT EXISTS idx_payments_settlement_id        ON pay.payments (settlement_id);

-- ##################################################
-- #   BUSINESS RULES PENDING (REQUIRE TRIGGERS)    #
-- ##################################################
-- These rules involve more than one row or table, so a CHECK cannot enforce them:
--   1. The sum of plots.area_ha of a farm must not exceed farms.total_area_ha.
--   2. The sum of plot_varieties.planted_percentage of a plot must not exceed 100.
--   3. settlements.net_weight_kg must not exceed deliveries.gross_weight_kg.
--   4. A settlement can only exist for a delivery whose quality analysis is accepted.
--   5. The sum of payments.amount must not exceed settlements.net_amount.
--   6. A farm cannot have two overlapping periods for the same certification.

-- ##################################################
-- #                 END OF SCRIPT                  #
-- ##################################################
