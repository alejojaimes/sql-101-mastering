# Customers DB — Guía de configuración

> Creado: 14 de marzo de 2026

## Historial de versiones

| Autor | Descripción | Fecha |
|---|---|---|
| Juan Alejandro Carrillo Jaimes | Primera versión del documento | 14 mar 2026 |
| Juan Alejandro Carrillo Jaimes | Actualización con esquemas separados e información real | 20 mar 2026 |
| Juan Alejandro Carrillo Jaimes | Datos adicionales: clientes, direcciones, órdenes, items y envíos | 22 mar 2026 |
| Juan Alejandro Carrillo Jaimes | Datos adicionales: órdenes, items y envíos | 23 mar 2026 |
| Juan Alejandro Carrillo Jaimes | Datos adicionales: órdenes, items y envíos. Proceso de carga masiva | 28 mar 2026 |
| Juan Alejandro Carrillo Jaimes | Reorganización del repositorio. Migración a dump para replicabilidad semestral | 08 sep 2026 |

---

## ¿Qué es esta base de datos?

`customers_db` es una base de datos PostgreSQL que modela una operación de e-commerce. Tiene más de **750.000 filas** distribuidas en cuatro esquemas y es el dataset principal de las clases de SQL 101.

| Esquema | Responsabilidad |
|---|---|
| `ctg` | Catálogos — departamentos, municipios, categorías, productos, métodos de pago, tipos de documento |
| `cs` | Core — clientes y direcciones |
| `pay` | Pagos — órdenes e ítems de orden |
| `ship` | Envíos — empresas de transporte y órdenes de envío |

### Conteo de registros

| Tabla | Registros |
|---|---|
| `pay.order_items` | 485.333 |
| `pay.orders` | 121.359 |
| `ship.shipment_orders` | 121.359 |
| `cs.customers` | 21.254 |
| `cs.addresses` | 21.254 |
| `ctg.municipalities` | 1.102 |
| `ctg.products` | 75 |
| `ctg.departments` | 33 |
| `ctg.categories` | 20 |
| `ctg.document_types` | 13 |
| `ctg.payment_methods` | 10 |
| `ship.ship_company` | 10 |

---

## Requisitos previos

Antes de empezar, asegúrate de tener instalado:

- **PostgreSQL 16** o superior
- Un cliente SQL: [pgAdmin](https://www.pgadmin.org/) o [DBeaver](https://dbeaver.io/)
- El archivo dump proporcionado por el profesor (ver sección siguiente)

---

## Tutorial — Cómo montar la base de datos en tu máquina

Hay dos rutas. La **Opción A** es la recomendada para comenzar el semestre rápidamente. La **Opción B** es para cuando el objetivo de la clase es practicar creación de esquemas desde cero.

---

### Opción A — Importar desde dump (recomendada)

Esta opción restaura la base de datos completa en pocos minutos.

#### Paso 1 — Descarga el dump

Descarga el archivo `customers_db_20260908.dump` desde el enlace compartido por el profesor y colócalo en:

```
content/customers/data/dump/customers_db_20260908.dump
```

#### Paso 2 — Crea el usuario y la base de datos

Conéctate a PostgreSQL como superusuario (`postgres`) y ejecuta:

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

> En pgAdmin: clic derecho en **Login/Group Roles → Create** para el usuario, y en **Databases → Create** para la base de datos.

#### Paso 3 — Restaura el dump

Abre una terminal y ejecuta:

```sh
pg_restore \
  -U admin \
  -h localhost \
  -p 5432 \
  -d customers_db \
  --no-owner \
  content/customers/data/dump/customers_db_20260908.dump
```

> Te pedirá la contraseña: `test25**`

#### Paso 4 — Valida la carga

Conéctate a `customers_db` y ejecuta:

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

Deberías ver las mismas cantidades de la tabla de conteo de registros de arriba.

---

### Opción B — Configuración manual (práctica de DDL)

Usa esta ruta cuando el objetivo de clase es construir el esquema desde cero.

#### Paso 1 — Crea la base de datos, usuario y esquemas

```
scripts/ddl/01-ddl-database.sql
```

#### Paso 2 — Crea las tablas

Ejecuta en orden para respetar las dependencias de llaves foráneas:

```
scripts/ddl/02-ddl-ctg.sql
scripts/ddl/03-ddl-cs.sql
scripts/ddl/04-ddl-pay.sql
scripts/ddl/05-ddl-ship.sql
```

Verifica la creación de tablas:

```sql
SELECT tablename
FROM pg_catalog.pg_tables
WHERE schemaname IN ('ctg', 'cs', 'pay', 'ship')
ORDER BY schemaname, tablename;
```

#### Paso 3 — Crea las extensiones

Agrega la tabla `ctg.document_types`, `cs.phone_number` y las columnas de relación:

```
scripts/ddl/06-ddl-extensions.sql
```

#### Paso 4 — Crea las funciones

Ejecuta sentencia por sentencia para aislar errores:

```
scripts/functions/ctg_functions.sql
scripts/functions/pay_functions.sql
```

#### Paso 5 — Crea los triggers

```
scripts/triggers/ctg_triggers.sql
scripts/triggers/generic_triggers.sql
scripts/triggers/ship_triggers.sql
```

#### Paso 6 — Crea los índices

```
scripts/index/pay_orders_items.sql
```

#### Paso 7 — Importa los datos

Con el esquema creado, restaura solo los datos del dump:

```sh
pg_restore \
  -U admin \
  -h localhost \
  -p 5432 \
  -d customers_db \
  --no-owner \
  --data-only \
  content/customers/data/dump/customers_db_20260908.dump
```

#### Paso 8 — Valida

```sql
SELECT COUNT(*) FROM pay.orders WHERE total IS NULL;
-- Esperado: 0
```

---

## Queries — Ejercicios de clase

Los queries de práctica están organizados por fecha de clase en `queries/class/`. Ábrelos en orden:

| Archivo | Temas |
|---|---|
| `queries/class/queries-100326.sql` | COUNT, UNION, GROUP BY, EXTRACT, FILTER |
| `queries/class/queries-130326.sql` | Introducción a JOINs |
| `queries/class/queries-200326.sql` | Agregaciones y subconsultas |
| `queries/class/queries-230326.sql` | Window functions |
| `queries/class/queries-240326.sql` | CTEs y filtros avanzados |

---

## Referencia de scripts

```
scripts/
├── ddl/                        # Definición del esquema — ejecutar en orden numérico
│   ├── 01-ddl-database.sql     # BD, usuario y esquemas
│   ├── 02-ddl-ctg.sql          # Tablas de catálogo
│   ├── 03-ddl-cs.sql           # Tablas de clientes
│   ├── 04-ddl-pay.sql          # Tablas de pagos
│   ├── 05-ddl-ship.sql         # Tablas de envíos
│   └── 06-ddl-extensions.sql   # document_types + phone_number + columnas FK
├── functions/                  # Funciones de negocio
│   ├── ctg_functions.sql       # convert_usd_to_cop, update_category_id
│   └── pay_functions.sql       # update_total_orders
├── triggers/                   # Triggers automáticos
│   ├── ctg_triggers.sql        # Conversión de precio al insertar producto
│   ├── generic_triggers.sql    # Mantenimiento de updated_at
│   └── ship_triggers.sql       # Validación de órdenes de envío
├── index/
│   └── pay_orders_items.sql    # Índice FK en shipment_orders(order_id)
├── notebooks/
│   └── data-wrangling-basic.ipynb
├── pipelines/                  # Solo para el profesor — generación masiva de datos
│   └── insert-bulk-load-data/
└── python-scripts/             # Solo para el profesor — generadores de datos sintéticos
```

---

## Notas técnicas

- `ctg.products.cop_price` siempre se llena via `ctg.convert_usd_to_cop()`, nunca manualmente.
- `pay.orders.total` siempre se llena via `pay.update_total_orders()` o el trigger de inserción, nunca manualmente.
- `ship.shipment_orders` valida la existencia de la orden y previene asignaciones duplicadas a través de un trigger `BEFORE INSERT`.
- El campo `updated_at` en `cs.addresses` y `ship.shipment_orders` se mantiene automáticamente por `trg_set_updated_at()`.
- El índice en `scripts/index/pay_orders_items.sql` es crítico para el rendimiento en cargas masivas — sin él, cargar 30 lotes de envíos toma ~25 minutos en lugar de ~14 segundos.

---

## Archivos legacy

Versiones anteriores de los scripts y los archivos INSERT originales están preservados en `_legacy/` como referencia histórica. No hacen parte del flujo de configuración activo.
