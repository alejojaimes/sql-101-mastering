# Customers DB — Setup Guide

> Last updated: September 2026

## Overview

`customers_db` is a PostgreSQL database that models an e-commerce operation. It contains ~750 K rows across four schemas and is used as the hands-on dataset for SQL 101 classes.

| Schema | Responsibility |
|---|---|
| `ctg` | Catalogs — departments, municipalities, categories, products, payment methods, document types |
| `cs` | Core — customers and addresses |
| `pay` | Payments — orders and order items |
| `ship` | Shipments — shipping companies and shipment orders |

### Row counts (reference semester)

| Table | Rows |
|---|---|
| `pay.order_items` | 485,333 |
| `pay.orders` | 121,359 |
| `ship.shipment_orders` | 121,359 |
| `cs.customers` | 21,254 |
| `cs.addresses` | 21,254 |
| `ctg.municipalities` | 1,102 |
| `ctg.products` | 75 |
| `ctg.departments` | 33 |
| `ctg.categories` | 20 |
| `ctg.document_types` | 13 |
| `ctg.payment_methods` | 10 |
| `ship.ship_company` | 10 |

---

## Setup

There are two ways to get the database running. **Option A** is the recommended path for students at the start of the semester — it is the fastest. **Option B** walks through every DDL step and is used when the goal is to practice schema creation.

---

### Option A — Import from dump (recommended)

This restores the full database in one command.

**Prerequisites:** PostgreSQL 16, a running instance, and the dump file from your instructor placed at `data/dump/customers_db_YYYYMMDD.dump` (see `data/dump/README.md`).

**Step 1 — Create the database**

Connect as a superuser and run:

```sql
CREATE USER admin WITH PASSWORD 'test25**';

CREATE DATABASE customers_db WITH
    OWNER admin
    ENCODING 'UTF8'
    LC_COLLATE 'en_US.UTF-8'
    LC_CTYPE 'en_US.UTF-8'
    TEMPLATE template0;

GRANT ALL PRIVILEGES ON DATABASE customers_db TO admin;
```

**Step 2 — Restore**

```sh
pg_restore \
  -U admin \
  -h localhost \
  -p 5432 \
  -d customers_db \
  --no-owner \
  content/customers/data/dump/customers_db_YYYYMMDD.dump
```

**Step 3 — Validate**

```sql
SELECT
    schemaname,
    tablename,
    (xpath('/row/c/text()', query_to_xml(
        format('SELECT COUNT(*) AS c FROM %I.%I', schemaname, tablename),
        false, true, ''))
    )[1]::text::int AS total_rows
FROM pg_catalog.pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
```

---

### Option B — Manual setup (DDL practice)

Use this when the class objective is to build the schema from scratch.

**Step 1 — Create database, user, and schemas**

```
scripts/ddl/01-ddl-database.sql
```

**Step 2 — Create tables**

Execute in order to respect foreign key dependencies:

```
scripts/ddl/02-ddl-ctg.sql
scripts/ddl/03-ddl-cs.sql
scripts/ddl/04-ddl-pay.sql
scripts/ddl/05-ddl-ship.sql
```

**Step 3 — Create extensions**

Adds `ctg.document_types`, `cs.phone_number`, and the relationship columns:

```
scripts/ddl/06-ddl-extensions.sql
```

**Step 4 — Create functions**

Execute statements one by one to isolate any errors:

```
scripts/functions/ctg_functions.sql
scripts/functions/pay_functions.sql
```

**Step 5 — Create triggers**

```
scripts/triggers/ctg_triggers.sql
scripts/triggers/generic_triggers.sql
scripts/triggers/ship_triggers.sql
```

**Step 6 — Create indexes**

```
scripts/index/pay_orders_items.sql
```

**Step 7 — Import data**

After completing steps 1–6, restore only the data from the dump:

```sh
pg_restore \
  -U admin \
  -h localhost \
  -p 5432 \
  -d customers_db \
  --no-owner \
  --data-only \
  content/customers/data/dump/customers_db_YYYYMMDD.dump
```

**Step 8 — Validate**

```sql
SELECT COUNT(*) FROM pay.orders WHERE total IS NULL;
-- Expected: 0
```

---

## Queries — Class exercises

Practice queries are organized by class date under `queries/class/`. Open them in order:

| File | Topics |
|---|---|
| `queries/class/queries-100326.sql` | COUNT, UNION, GROUP BY, EXTRACT, FILTER |
| `queries/class/queries-130326.sql` | JOINs introduction |
| `queries/class/queries-200326.sql` | Aggregations and subqueries |
| `queries/class/queries-230326.sql` | Window functions |
| `queries/class/queries-240326.sql` | CTEs and advanced filtering |

---

## Scripts reference

```
scripts/
├── ddl/                     # Schema definition — run in numeric order
│   ├── 01-ddl-database.sql  # DB, user, schemas
│   ├── 02-ddl-ctg.sql       # Catalog tables
│   ├── 03-ddl-cs.sql        # Customer tables
│   ├── 04-ddl-pay.sql       # Payment tables
│   ├── 05-ddl-ship.sql      # Shipment tables
│   └── 06-ddl-extensions.sql# document_types + phone_number + FK columns
├── functions/               # Business logic functions
│   ├── ctg_functions.sql    # convert_usd_to_cop, update_category_id
│   └── pay_functions.sql    # update_total_orders
├── triggers/                # Automatic triggers
│   ├── ctg_triggers.sql     # Price conversion on product insert
│   ├── generic_triggers.sql # updated_at maintenance
│   └── ship_triggers.sql    # Shipment order validation
├── index/
│   └── pay_orders_items.sql # FK index on shipment_orders(order_id)
├── notebooks/
│   └── data-wrangling-basic.ipynb
├── pipelines/               # Instructor use — bulk data generation
│   └── insert-bulk-load-data/
└── python-scripts/          # Instructor use — synthetic data generators
```

---

## Notes

- `ctg.products.cop_price` is always populated via `ctg.convert_usd_to_cop()`, never manually.
- `pay.orders.total` is always populated via `pay.update_total_orders()` or the insert trigger, never manually.
- `ship.shipment_orders` validates order existence and prevents duplicate assignments through a `BEFORE INSERT` trigger.
- The `updated_at` field in `cs.addresses` and `ship.shipment_orders` is maintained automatically by `trg_set_updated_at()`.
- The index in `scripts/index/pay_orders_items.sql` is critical for bulk load performance — without it, loading 30 batches of shipment orders takes ~25 minutes instead of ~14 seconds.

---

## Legacy files

Previous versions of scripts and the original INSERT data files are preserved in `_legacy/` for historical reference. They are not part of the active setup flow.
