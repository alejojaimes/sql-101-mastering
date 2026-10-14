// ============================================
// COFFEE COOP DATABASE - Academic Version
// Database: PostgreSQL 16+
// Normalization: 4NF
// Paste this code in https://dbdiagram.io to render the physical model
// ============================================

Project coffee_coop_db {
  database_type: 'PostgreSQL'
  Note: 'Coffee cooperative: farmers, farms, plots, deliveries, quality analyses, settlements and payments'
}

// ============================================
// GEO MODULE
// ============================================

Table geo.departments {
  department_code varchar(5) [pk]
  department_name varchar(100) [not null, unique]
}

Table geo.municipalities {
  municipality_code varchar(10) [pk]
  municipality_name varchar(100) [not null]
  department_code varchar(5) [not null]

  indexes {
    (department_code, municipality_name) [unique, name: 'uq_municipalities_department_name']
  }
}

// ============================================
// FARM MODULE
// ============================================

Table farm.farmers {
  farmer_id serial [pk]
  document_number varchar(20) [not null, unique]
  first_name varchar(60) [not null]
  last_name varchar(60) [not null]
  birth_date date [not null]
  gender char(1) [not null, note: 'CHECK (M, F, O)']
  phone_number varchar(20) [not null]
  email varchar(120) [unique]
  membership_date date [not null, default: `CURRENT_DATE`]
  is_active boolean [not null, default: true]
  municipality_code varchar(10) [not null]
}

Table farm.farms {
  farm_id serial [pk]
  farmer_id int [not null]
  municipality_code varchar(10) [not null]
  farm_name varchar(100) [not null]
  rural_district varchar(100) [not null]
  total_area_ha numeric(8,2) [not null, note: 'CHECK > 0']
  altitude_masl int [not null]
  latitude numeric(9,6)
  longitude numeric(9,6)
  registered_at timestamp [not null, default: `CURRENT_TIMESTAMP`]

  indexes {
    (farmer_id, farm_name) [unique, name: 'uq_farms_farmer_name']
  }
}

Table farm.plots {
  plot_id serial [pk]
  farm_id int [not null]
  plot_code varchar(10) [not null]
  area_ha numeric(8,2) [not null, note: 'CHECK > 0']
  planting_year smallint [not null]
  shade_type varchar(20) [not null, note: 'CHECK (full_sun, partial_shade, full_shade)']

  indexes {
    (farm_id, plot_code) [unique, name: 'uq_plots_farm_code']
  }
}

Table farm.coffee_varieties {
  variety_id serial [pk]
  variety_name varchar(60) [not null, unique]
  species varchar(20) [not null, note: 'CHECK (arabica, robusta)']
  is_rust_resistant boolean [not null, default: false]
  description text
}

Table farm.plot_varieties {
  plot_variety_id serial [pk]
  plot_id int [not null]
  variety_id int [not null]
  planted_percentage numeric(5,2) [not null, note: 'CHECK > 0 AND <= 100']
  tree_count int [not null]

  indexes {
    (plot_id, variety_id) [unique, name: 'uq_plot_varieties_plot_variety']
  }
}

Table farm.certifications {
  certification_id serial [pk]
  certification_name varchar(80) [not null, unique]
  issuing_body varchar(100) [not null]
  premium_per_kg numeric(10,2) [not null, default: 0, note: 'CHECK >= 0']
}

Table farm.farm_certifications {
  farm_certification_id serial [pk]
  farm_id int [not null]
  certification_id int [not null]
  start_date date [not null]
  end_date date [note: 'CHECK end_date > start_date']
  certificate_number varchar(40) [not null, unique]

  indexes {
    (farm_id, certification_id, start_date) [unique, name: 'uq_farm_certifications_period']
  }
}

// ============================================
// BUY MODULE
// ============================================

Table buy.collection_points {
  collection_point_id serial [pk]
  point_name varchar(100) [not null, unique]
  municipality_code varchar(10) [not null]
  address_line varchar(200) [not null]
  phone_number varchar(20)
  is_active boolean [not null, default: true]
}

Table buy.daily_prices {
  daily_price_id serial [pk]
  collection_point_id int [not null]
  price_date date [not null]
  price_per_kg numeric(10,2) [not null, note: 'CHECK > 0']
  reference_yield_factor numeric(5,2) [not null, default: 94.00]

  indexes {
    (collection_point_id, price_date) [unique, name: 'uq_daily_prices_point_date']
  }
}

Table buy.deliveries {
  delivery_id varchar(30) [pk, note: 'DLV-YYYYMMDD-NNNNNN']
  farm_id int [not null]
  collection_point_id int [not null]
  delivered_at timestamp [not null, default: `CURRENT_TIMESTAMP`]
  coffee_type varchar(20) [not null, note: 'CHECK (dry_parchment, wet_parchment, cherry)']
  bag_count smallint [not null, note: 'CHECK > 0']
  gross_weight_kg numeric(10,2) [not null, note: 'CHECK > 0']
  status varchar(20) [not null, default: 'received', note: 'CHECK (received, accepted, rejected, settled)']
}

Table buy.quality_analyses {
  analysis_id varchar(30) [pk, note: 'QA-YYYYMMDD-NNNNNN']
  delivery_id varchar(30) [not null, unique]
  analyzed_at timestamp [not null, default: `CURRENT_TIMESTAMP`]
  moisture_pct numeric(5,2) [not null, note: 'CHECK 0-100']
  yield_factor numeric(5,2) [not null]
  defects_pct numeric(5,2) [not null, default: 0]
  cup_score numeric(5,2)
  is_accepted boolean [not null]
  analyst_name varchar(100) [not null]
  observations text
}

// ============================================
// PAY MODULE
// ============================================

Table pay.settlements {
  settlement_id varchar(30) [pk, note: 'STL-YYYYMMDD-NNNNNN']
  delivery_id varchar(30) [not null, unique]
  daily_price_id int [not null]
  net_weight_kg numeric(10,2) [not null, note: 'CHECK > 0']
  price_per_kg_applied numeric(10,2) [not null, note: 'CHECK > 0']
  deductions_amount numeric(14,2) [not null, default: 0, note: 'CHECK >= 0']
  gross_amount numeric(14,2) [note: 'GENERATED: net_weight_kg * price_per_kg_applied']
  net_amount numeric(14,2) [note: 'GENERATED: gross_amount - deductions_amount']
  settled_at timestamp [not null, default: `CURRENT_TIMESTAMP`]
  status varchar(20) [not null, default: 'pending', note: 'CHECK (pending, partially_paid, paid, cancelled)']
}

Table pay.payments {
  payment_id varchar(30) [pk, note: 'PAY-YYYYMMDD-NNNNNN']
  settlement_id varchar(30) [not null]
  payment_method varchar(20) [not null, note: 'CHECK (cash, bank_transfer, check)']
  amount numeric(14,2) [not null, note: 'CHECK > 0']
  paid_at timestamp [not null, default: `CURRENT_TIMESTAMP`]
  transaction_reference varchar(60) [unique]
}

// ============================================
// RELATIONSHIPS
// ============================================

Ref: geo.municipalities.department_code > geo.departments.department_code [delete: restrict, update: cascade]

Ref: farm.farmers.municipality_code > geo.municipalities.municipality_code [delete: restrict, update: cascade]

Ref: farm.farms.farmer_id > farm.farmers.farmer_id [delete: restrict, update: cascade]

Ref: farm.farms.municipality_code > geo.municipalities.municipality_code [delete: restrict, update: cascade]

Ref: farm.plots.farm_id > farm.farms.farm_id [delete: restrict, update: cascade]

Ref: farm.plot_varieties.plot_id > farm.plots.plot_id [delete: cascade, update: cascade]

Ref: farm.plot_varieties.variety_id > farm.coffee_varieties.variety_id [delete: restrict, update: cascade]

Ref: farm.farm_certifications.farm_id > farm.farms.farm_id [delete: cascade, update: cascade]

Ref: farm.farm_certifications.certification_id > farm.certifications.certification_id [delete: restrict, update: cascade]

Ref: buy.collection_points.municipality_code > geo.municipalities.municipality_code [delete: restrict, update: cascade]

Ref: buy.daily_prices.collection_point_id > buy.collection_points.collection_point_id [delete: restrict, update: cascade]

Ref: buy.deliveries.farm_id > farm.farms.farm_id [delete: restrict, update: cascade]

Ref: buy.deliveries.collection_point_id > buy.collection_points.collection_point_id [delete: restrict, update: cascade]

Ref: buy.quality_analyses.delivery_id - buy.deliveries.delivery_id [delete: restrict, update: cascade]

Ref: pay.settlements.delivery_id - buy.deliveries.delivery_id [delete: restrict, update: cascade]

Ref: pay.settlements.daily_price_id > buy.daily_prices.daily_price_id [delete: restrict, update: cascade]

Ref: pay.payments.settlement_id > pay.settlements.settlement_id [delete: restrict, update: cascade]
