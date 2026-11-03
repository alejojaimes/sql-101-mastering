-- ##################################################
-- #   COFFEE COOP ALTER TABLE SCRIPT - EXTRA CHECKS #
-- ##################################################
-- This script adds 5 CHECK constraints that complete the value rules
-- documented for farms, plot varieties and quality analyses:
--   1. chk_farms_altitude                  altitude_masl > 0
--   2. chk_plot_varieties_tree_count       tree_count > 0
--   3. chk_quality_analyses_yield_factor   yield_factor > 0
--   4. chk_quality_analyses_defects        defects_pct BETWEEN 0 AND 100
--   5. chk_quality_analyses_cup_score      cup_score BETWEEN 0 AND 100
-- Naming convention: chk_<table>_<column>
-- The loaded data (data/sql/coffee_coop_sql.zip) already satisfies all of them,
-- so this script can also be run on a database that already has data.
-- RUN IN coffee_coop_db - cc_admin, after 03-alter-tables.sql

-- ##################################################
-- #          CHECK CONSTRAINTS                     #
-- ##################################################

-- ============================================
-- FARM
-- ============================================

ALTER TABLE farm.farms
ADD CONSTRAINT chk_farms_altitude
CHECK (altitude_masl > 0);

ALTER TABLE farm.plot_varieties
ADD CONSTRAINT chk_plot_varieties_tree_count
CHECK (tree_count > 0);

-- ============================================
-- BUY
-- ============================================

ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_yield_factor
CHECK (yield_factor > 0);

ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_defects
CHECK (defects_pct BETWEEN 0 AND 100);

-- NULL means the delivery was not cupped
ALTER TABLE buy.quality_analyses
ADD CONSTRAINT chk_quality_analyses_cup_score
CHECK (cup_score BETWEEN 0 AND 100);

-- ##################################################
-- #                 END OF SCRIPT                  #
-- ##################################################
