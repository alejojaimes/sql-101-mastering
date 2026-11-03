# Coffee Coop DB — Guía de configuración

> Creado: 14 de octubre de 2026

## Historial de versiones

| Autor | Descripción | Fecha |
|---|---|---|
| Juan Alejandro Carrillo Jaimes | Primera versión: MER, modelo relacional, modelo físico y DDL | 14 oct 2026 |
| Juan Alejandro Carrillo Jaimes | Modelo sin entidades débiles; cardinalidad junto a cada relación en el MER | 14 oct 2026 |
| Juan Alejandro Carrillo Jaimes | Documento del caso de estudio en `docs/` | 14 oct 2026 |
| Juan Alejandro Carrillo Jaimes | `02` solo con tablas y PK; FK, UNIQUE y CHECK en `03`; sin índices; CHECK simplificados | 14 oct 2026 |
| Juan Alejandro Carrillo Jaimes | Llaves de entregas, análisis, liquidaciones y pagos como códigos `VARCHAR` (prefijo + fecha + consecutivo) | 14 oct 2026 |
| Juan Alejandro Carrillo Jaimes | Generador de datos sintéticos, notebooks y pipeline de carga (`data/`, `scripts/pipelines/`, `scripts/notebooks/`) | 18 oct 2026 |
| Juan Alejandro Carrillo Jaimes | Carpeta renombrada de `coffe-coop` a `coffee-coop` | 18 oct 2026 |
| Juan Alejandro Carrillo Jaimes | Guía de carga para Linux (`README-linux.md`) y cargador multiplataforma `load_data.py` | 20 oct 2026 |
| Juan Alejandro Carrillo Jaimes | Primer ejercicio del taller de SQL básico (`scripts/querys/01-sql-basic/`) | 27 oct 2026 |
| Juan Alejandro Carrillo Jaimes | `04-alter-tables-checks.sql` con 5 CHECK nuevos (altitud, árboles, factor de rendimiento, defectos y puntaje de taza); README con datos y estructura completa | 2 nov 2026 |

---

## ¿Qué es esta base de datos?

`coffee_coop_db` es una base de datos PostgreSQL que modela una **cooperativa cafetera**: asociados, fincas, lotes, entregas de café, análisis de calidad, liquidaciones y pagos. Tiene **15 tablas** distribuidas en cuatro esquemas.

La descripción completa del caso (contexto, requerimientos y casos de uso) está en [`docs/Coffee_Coop.pdf`](docs/Coffee_Coop.pdf).

> Todos los nombres de la estructura (esquemas, tablas, columnas y constraints) están en **inglés**. La documentación está en español.

| Esquema | Responsabilidad |
|---|---|
| `geo` | Geografía — departamentos y municipios (códigos DANE) |
| `farm` | Producción — caficultores, fincas, lotes, variedades y certificaciones |
| `buy` | Compras — puntos de compra, precio del día, entregas y análisis de calidad |
| `pay` | Pagos — liquidaciones y pagos |

### Tablas

| Tabla | Significado |
|---|---|
| `geo.departments` | Departamentos |
| `geo.municipalities` | Municipios |
| `farm.farmers` | Caficultores (asociados) |
| `farm.farms` | Fincas |
| `farm.plots` | Lotes |
| `farm.coffee_varieties` | Variedades de café |
| `farm.plot_varieties` | Variedades sembradas por lote (N:M) |
| `farm.certifications` | Certificaciones |
| `farm.farm_certifications` | Certificaciones por finca, con vigencia (N:M) |
| `buy.collection_points` | Puntos de compra (acopio) |
| `buy.daily_prices` | Precio del día por punto de compra |
| `buy.deliveries` | Entregas de café |
| `buy.quality_analyses` | Análisis de calidad (1:1 con la entrega) |
| `pay.settlements` | Liquidaciones (1:1 con la entrega) |
| `pay.payments` | Pagos de una liquidación |

### Conteo de objetos

| Objeto | Cantidad |
|---|---|
| Esquemas | 4 |
| Tablas | 15 |
| PRIMARY KEY | 15 |
| FOREIGN KEY | 17 |
| UNIQUE | 16 |
| CHECK | 25 |
| Columnas calculadas (`GENERATED`) | 2 |

### Datos

Los scripts DDL crean la base **vacía**. Los datos sintéticos vienen comprimidos en `data/sql/coffee_coop_sql.zip` (31 archivos `.sql`, ≈ 415 MB descomprimidos) y se cargan con el pipeline de [`scripts/pipelines/02-insert-data`](scripts/pipelines/02-insert-data/README.md).

| Esquema | Tabla | Registros |
|---|---|---:|
| `farm` | `plot_varieties` | 1.107.253 |
| `pay` | `payments` | 692.151 |
| `farm` | `plots` | 651.793 |
| `buy` | `deliveries` | 650.000 |
| `buy` | `quality_analyses` | 648.938 |
| `pay` | `settlements` | 587.871 |
| `buy` | `daily_prices` | 312.120 |
| `farm` | `farms` | 232.394 |
| `farm` | `farmers` | 150.000 |
| `farm` | `farm_certifications` | 109.425 |
| `geo` | `municipalities` | 1.102 |
| `buy` | `collection_points` | 180 |
| `geo` | `departments` | 33 |
| `farm` | `coffee_varieties` | 12 |
| `farm` | `certifications` | 7 |
| | **Total** | **5.143.279** |

Las entregas cubren del 1 de enero de 2022 al 30 de septiembre de 2026.

---

## Requisitos previos

- **PostgreSQL 16** o superior
- Un cliente SQL: [pgAdmin](https://www.pgadmin.org/) o [DBeaver](https://dbeaver.io/)

---

## Tutorial — Cómo montar la base de datos en tu máquina

Ejecuta los scripts en orden numérico.

### Paso 1 — Crea el usuario y la base de datos

Como superusuario (`postgres`). Antes, cambia la contraseña `'*'` del script:

```sh
psql -U postgres -h localhost -f scripts/ddl/01-create-database.sql
```

> **Windows:** el locale `es_CO.UTF-8` no existe. Cámbialo por `'Spanish_Colombia.1252'` o borra las líneas `LC_COLLATE` y `LC_CTYPE`.

### Paso 2 — Crea los esquemas y las tablas

Conectado a `coffee_coop_db` con el usuario `cc_admin`:

```sh
psql -U cc_admin -h localhost -d coffee_coop_db -f scripts/ddl/02-create-tables.sql
```

### Paso 3 — Agrega las restricciones (FK, UNIQUE y CHECK)

```sh
psql -U cc_admin -h localhost -d coffee_coop_db -f scripts/ddl/03-alter-tables.sql
```

> En pgAdmin o DBeaver: abre cada archivo en una ventana de consultas conectada a la base y con el usuario indicado, y ejecútalo con F5.

### Paso 4 — Agrega los CHECK adicionales

```sh
psql -U cc_admin -h localhost -d coffee_coop_db -f scripts/ddl/04-alter-tables-checks.sql
```

> ¿Ya tenías la base montada y con datos? Ejecuta solo este script: los datos cargados ya cumplen las 5 reglas.

### Paso 5 — Valida

Tablas por esquema:

```sql
SELECT table_schema, COUNT(*) AS total_tables
FROM information_schema.tables
WHERE table_schema IN ('geo', 'farm', 'buy', 'pay')
GROUP BY table_schema
ORDER BY table_schema;
-- Esperado: buy 4 · farm 7 · geo 2 · pay 2
```

Constraints por tipo:

```sql
SELECT
    CASE c.contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'c' THEN 'CHECK'
    END AS constraint_type,
    COUNT(*) AS total
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname IN ('geo', 'farm', 'buy', 'pay')
GROUP BY c.contype
ORDER BY c.contype;
-- Esperado: CHECK 25 · FOREIGN KEY 17 · PRIMARY KEY 15 · UNIQUE 16
```

Registros por tabla (útil después de cargar datos):

```sql
SELECT
    schemaname,
    tablename,
    (xpath('/row/c/text()', query_to_xml(
        format('SELECT COUNT(*) AS c FROM %I.%I', schemaname, tablename),
        false, true, ''))
    )[1]::text::int AS total_rows
FROM pg_catalog.pg_tables
WHERE schemaname IN ('geo', 'farm', 'buy', 'pay')
ORDER BY schemaname, tablename;
```

### Paso 6 — Carga los datos

Sigue la guía de tu sistema operativo:

- Windows: [`scripts/pipelines/02-insert-data/README.md`](scripts/pipelines/02-insert-data/README.md)
- Linux / macOS: [`scripts/pipelines/02-insert-data/README-linux.md`](scripts/pipelines/02-insert-data/README-linux.md)

Al terminar, la consulta "Registros por tabla" del paso 5 debe devolver los valores de la sección [Datos](#datos).

### Empezar de nuevo

```sql
-- Como postgres
DROP DATABASE IF EXISTS coffee_coop_db;
DROP USER IF EXISTS cc_admin;
```

---

## Modelos

| Modelo | Archivo | Cómo abrirlo |
|---|---|---|
| MER (notación Chen, sin FKs) | `models/ERD/ERD_coffee_coop.drawio` (+ `.png`) | [diagrams.net](https://app.diagrams.net) o extensión Draw.io de VS Code |
| Modelo relacional | `models/LDM/mermaid-code.txt` (+ `.png`) | [mermaid.live](https://mermaid.live) |
| Modelo físico | `models/PDM/PDM-CoffeeCoop-dbdiagram.sh` (+ `.png`) | [dbdiagram.io](https://dbdiagram.io) |

---

## Referencia de scripts

```
coffee-coop/
├── README.md
├── data/
│   ├── source/                       # Catálogos de entrada del generador
│   │   ├── CatalogoDatos.xlsx        # DIVIPOLA, departamentos cafeteros, variedades, certificaciones
│   │   ├── people.xlsx               # Nombres, apellidos, dominios de correo, prefijos celulares
│   │   └── addresses.xlsx            # Veredas por municipio
│   └── sql/
│       └── coffee_coop_sql.zip       # INSERT generados (~5,1 M filas) — descomprimir antes de cargar
├── docs/
│   └── Coffee_Coop.pdf               # Caso de estudio: contexto, requerimientos y casos de uso
├── models/
│   ├── ERD/                          # MER en notación Chen
│   ├── LDM/                          # Modelo relacional (Mermaid)
│   └── PDM/                          # Modelo físico (DBML)
└── scripts/
    ├── ddl/                          # Definición del esquema — ejecutar en orden numérico
    │   ├── 01-create-database.sql    # Usuario cc_admin y BD coffee_coop_db (como postgres)
    │   ├── 02-create-tables.sql      # Esquemas y tablas: columnas, tipos, NOT NULL, DEFAULT y PK
    │   ├── 03-alter-tables.sql       # Restricciones: FOREIGN KEY, UNIQUE y CHECK
    │   └── 04-alter-tables-checks.sql  # 5 CHECK adicionales (rangos de valores)
    ├── notebooks/
    │   ├── 01-build-source.ipynb             # Construye los Excel de data/source
    │   └── 02-generate-synthetic-data.ipynb  # Mismo generador, paso a paso
    ├── pipelines/
    │   ├── requirements.txt          # Dependencias de Python
    │   ├── 01-generate-data/         # coffee_data_generator.py → archivos INSERT
    │   └── 02-insert-data/           # Carga: load_data.ps1 (Windows) y load_data.py (multiplataforma)
    └── querys/
        └── 01-sql-basic/             # Ejercicios del taller de SQL básico
```

---

## Notas técnicas

- `pay.settlements.gross_amount` y `net_amount` son columnas `GENERATED ALWAYS AS … STORED`: se calculan solas y nunca se insertan manualmente.
- Las relaciones 1:1 (`deliveries` → `quality_analyses` y `deliveries` → `settlements`) se garantizan con `UNIQUE (delivery_id)`.
- Las tablas N:M (`plot_varieties`, `farm_certifications`) tienen llave primaria propia y un `UNIQUE` que evita duplicados, igual que `patient_addresses` en `smart_health`.
- El modelo no usa entidades débiles: `farm.plots` tiene `plot_id` como PK y la regla del código de lote se controla con `UNIQUE (farm_id, plot_code)`.
- Las tablas de catálogo y maestras usan llaves `SERIAL`. Los documentos transaccionales usan un código `VARCHAR(30)` con prefijo, fecha y consecutivo, que se asigna al insertar:

  | Tabla | Llave | Ejemplo |
  |---|---|---|
  | `buy.deliveries` | `delivery_id` | `DLV-20261013-000001` |
  | `buy.quality_analyses` | `analysis_id` | `QA-20261013-000001` |
  | `pay.settlements` | `settlement_id` | `STL-20261013-000001` |
  | `pay.payments` | `payment_id` | `PAY-20261014-000001` |

- `02-create-tables.sql` solo define las tablas con su llave primaria. Todas las demás restricciones (FK, UNIQUE y CHECK) se agregan con `ALTER TABLE` en `03-alter-tables.sql`, y `04-alter-tables-checks.sql` completa 5 CHECK de rango (20 + 5 = 25).
- Las FK usan `ON UPDATE CASCADE` y `ON DELETE RESTRICT`. Solo las tablas N:M usan `ON DELETE CASCADE` desde su tabla dueña.
- Los CHECK solo validan valores simples de una columna: listas de valores permitidos (`IN`), números positivos y rangos. Las reglas que comparan varias tablas (por ejemplo, que la suma de los pagos no supere la liquidación) quedan para la unidad de triggers.
