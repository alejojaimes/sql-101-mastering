<div align="center">

# sql-101 · mastering 🐘

**Bases de datos relacionales, del modelo a la consulta.**

[![Blog](https://img.shields.io/badge/blog-ajteaches.dev-4F46E5?style=flat-square&logo=hashnode&logoColor=white)](https://www.ajteaches.dev)
[![PostgreSQL](https://img.shields.io/badge/postgresql-16+-4F46E5?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Cursos](https://img.shields.io/badge/cursos-bases_de_datos_I_y_II-4F46E5?style=flat-square)](#qué-se-aprende)

</div>

---

Material de los cursos **Bases de Datos I** y **Bases de Datos II**. Aquí está todo lo que se trabaja en clase: modelos, scripts, datos y ejercicios, para acompañar el contenido publicado en [ajteaches.dev](https://www.ajteaches.dev).

El curso recorre el camino completo de una base de datos relacional: entender un negocio, modelarlo, crearlo en PostgreSQL, llenarlo de datos y consultarlo con SQL hasta optimizarlo y automatizar sus reglas. Cada tema se practica sobre un caso de estudio con miles o millones de registros, no sobre tablas de ejemplo.

---

## Qué se aprende

```
Caso de negocio → Modelo E-R → Modelo relacional → Modelo físico → DDL → Carga de datos → Consultas → Optimización y reglas
```

Bases de Datos I cubre la primera mitad del camino: diseñar y construir la base. Bases de Datos II cubre la segunda: consultarla a fondo, programarla y hacerla rápida.

### Bases de Datos I · Diseño y construcción

| Unidad | Temas | Lo que se entrega |
|--------|-------|-------------------|
| Fundamentos | Qué es una base de datos y un SGBD, modelo relacional, tablas, filas, columnas, llaves | — |
| Modelo entidad-relación | Entidades, atributos, relaciones y cardinalidades en notación Chen; relaciones 1:1, 1:N y N:M | Diagrama E-R del caso |
| Modelo relacional | Paso del modelo E-R a tablas, llaves primarias y foráneas, tablas puente | Modelo relacional |
| Normalización | Dependencias funcionales; primera a cuarta forma normal | Modelo en 3FN o 4FN |
| Modelo físico | Tipos de dato de PostgreSQL, tamaños, valores por defecto, esquemas | Modelo físico y diccionario de datos |
| DDL | `CREATE`, `ALTER` y `DROP`; restricciones `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK` y `NOT NULL`; columnas calculadas | Scripts DDL en orden numérico |
| DML | `INSERT`, `UPDATE` y `DELETE`; carga masiva de datos | Base de datos con datos |
| Consultas básicas | `SELECT`, `WHERE`, `ORDER BY`, `LIMIT`, operadores y manejo de `NULL` | Primeros ejercicios del caso |

### Bases de Datos II · Consultas, programación y rendimiento

| Unidad | Temas | Lo que se entrega |
|--------|-------|-------------------|
| Combinación de tablas | `INNER`, `LEFT`, `RIGHT` y `FULL JOIN`; combinaciones de varias tablas | Ejercicios de JOIN |
| Agregación | `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`; `GROUP BY` y `HAVING` | Reportes del negocio |
| Funciones de fecha y texto | Extracción y cálculo con fechas, formato y limpieza de cadenas | Ejercicios de funciones |
| Operaciones de conjunto | `UNION`, `INTERSECT` y `EXCEPT` | Ejercicios de conjuntos |
| Subconsultas y CTE | Subconsultas en `WHERE`, `FROM` y `SELECT`; `EXISTS`; consultas con `WITH` | Consultas de varios pasos |
| Funciones de ventana | `OVER`, `PARTITION BY`, `ROW_NUMBER`, `RANK`, acumulados | Rankings y tendencias |
| Programación en PL/pgSQL | Funciones y procedimientos almacenados | Funciones del caso |
| Triggers | Reglas del negocio que un `CHECK` no puede validar; auditoría | Triggers del caso |
| Rendimiento | Índices y lectura de planes de ejecución con `EXPLAIN` | Consultas optimizadas |
| Transacciones | `BEGIN`, `COMMIT`, `ROLLBACK` y `SAVEPOINT`; integridad ante errores | — |

---

## Cómo se trabaja

Cada semestre tiene un caso de estudio principal. En Bases de Datos I se construye desde el documento de requerimientos hasta la base cargada; en Bases de Datos II esa misma base se consulta, se programa y se optimiza.

Cada caso vive en `content/` y sigue la misma organización:

```
nombre-del-caso/
├── README.md        ← guía para montar la base, cargar los datos y validarla
├── docs/            ← caso de estudio: contexto, requerimientos y casos de uso
├── models/          ← modelo entidad-relación, relacional y físico
├── data/            ← catálogos fuente y datos para cargar
└── scripts/
    ├── ddl/         ← creación de la base, tablas y restricciones, en orden numérico
    ├── pipelines/   ← generación y carga de los datos
    └── querys/      ← ejercicios de consultas por tema
```

Los casos más recientes tienen todas las carpetas; los primeros, solo las básicas.

---

## Herramientas

En [`tools/sql-graph-analyzer`](./tools/sql-graph-analyzer) hay un visualizador de planes de ejecución: pegas la salida de `EXPLAIN` de PostgreSQL y lo muestra como un árbol, con el costo de cada nodo. Es un solo `index.html` que se abre en el navegador y se usa en la unidad de rendimiento.

---

## Cómo empezar

```bash
git clone https://github.com/alejojaimes/sql-101-mastering.git
cd sql-101-mastering/content/<nombre-del-caso>
```

Necesitas PostgreSQL 16 o superior y un cliente SQL como pgAdmin o DBeaver. Cada caso documenta sus propios requisitos y su paso a paso en su README local. El contexto teórico de cada tema está en [ajteaches.dev](https://www.ajteaches.dev).

---

## Casos disponibles

| # | Caso | Dominio | Esquemas |
|---|------|---------|----------|
| 01 | [Fintech Accelerator](./content/fintech-accelator) | Tarjetas de crédito: clientes, emisores, franquicias y transacciones | `fintech` |
| 02 | [Smart Health](./content/smart-health) | Hospital: pacientes, médicos, citas e historia clínica | `smart_health` |
| 03 | [Customers](./content/customers) | E-commerce: clientes, órdenes, pagos y envíos | `ctg` · `cs` · `pay` · `ship` |
| 04 | [University](./content/university) | Universidad: facultades, programas, cursos y matrículas | `university` |
| 05 | [Coffee Coop](./content/coffee-coop) | Cooperativa cafetera: asociados, fincas, entregas, calidad y pagos | `geo` · `farm` · `buy` · `pay` |

> Cada semestre se agrega un caso nuevo. El caso actual es **Coffee Coop**: 15 tablas en 4 esquemas, normalizadas a 4FN, con caso de estudio, modelos, diccionario de datos y 5,1 millones de filas para cargar.

---

## Sobre ajteaches

Soy un ingeniero que enseña. Publico el contenido explicativo: el contexto, la teoría y el paso a paso comentado de cada tema. Pero te lo cuento mejor en [ajteaches.dev](https://www.ajteaches.dev/u/ajteaches).
