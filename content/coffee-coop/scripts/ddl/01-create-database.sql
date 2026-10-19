-- ##################################################
-- #       COFFEE COOP DATABASE CREATION SCRIPT     #
-- ##################################################
-- Creates the owner user and the database for the Coffee Cooperative system.
-- Target DBMS: PostgreSQL 16+

-- RUN IN POSTGRES - POSTGRES

-- 01. Create user
CREATE USER cc_admin WITH PASSWORD '*';

-- 02. Create database (with ENCODING= 'UTF8', TEMPLATE=Template0, OWNER: cc_admin)
-- NOTE: on Windows replace the locale with 'Spanish_Colombia.1252'
--       or remove LC_COLLATE / LC_CTYPE to use the server default.
CREATE DATABASE coffee_coop_db WITH
    ENCODING='UTF8'
    LC_COLLATE='es_CO.UTF-8'
    LC_CTYPE='es_CO.UTF-8'
    TEMPLATE=template0
    OWNER = cc_admin;

-- 03. Grant privileges
GRANT ALL PRIVILEGES ON DATABASE coffee_coop_db TO cc_admin;

-- ##################################################
-- #                 END OF SCRIPT                  #
-- ##################################################
