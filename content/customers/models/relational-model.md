# Modelo Relacional — Customers DB

> Base de datos: `customers_db` | Motor: PostgreSQL 16

El modelo está organizado en cuatro esquemas. Las entidades se nombran con el prefijo del esquema para dejar clara la separación de responsabilidades.

---

## Diagrama

```mermaid
erDiagram

    %% ── CTG: Catálogos ──────────────────────────────────────
    ctg_departments {
        varchar code PK
        varchar name
    }
    ctg_municipalities {
        varchar code PK
        varchar name
        varchar department_code FK
    }
    ctg_categories {
        int     id         PK
        varchar name
        timestamp created_at
    }
    ctg_products {
        int     id         PK
        varchar name
        decimal usd_price
        decimal cop_price
        int     category_id FK
    }
    ctg_payment_methods {
        int     id    PK
        varchar name
        timestamp create_at
    }
    ctg_document_types {
        varchar code         PK
        varchar description
        varchar abbreviation
    }

    %% ── CS: Clientes ─────────────────────────────────────────
    cs_customers {
        int     id                  PK
        varchar id_number           UK
        date    birth_date
        varchar phone_number
        varchar name
        varchar email               UK
        varchar document_type_code  FK
        timestamp created_at
    }
    cs_addresses {
        int     id                   PK
        varchar customer_id_number   FK
        varchar municipality_code    FK
        varchar street
        varchar detail
        varchar postal_code
        varchar additional_comments
        timestamp created_at
        timestamp updated_at
    }
    cs_phone_number {
        int     id                  PK
        varchar phone
        varchar customer_id_number  FK
        timestamp created_at
        timestamp updated_at
    }

    %% ── PAY: Pagos ───────────────────────────────────────────
    pay_orders {
        varchar id                  PK
        varchar customer_id_number  FK
        timestamp order_date
        decimal total
        int     payment_method_id   FK
    }
    pay_order_items {
        int     id         PK
        varchar order_id   FK
        int     product_id FK
        int     quantity
    }

    %% ── SHIP: Envíos ─────────────────────────────────────────
    ship_ship_company {
        int     id      PK
        varchar name    UK
        varchar nit     UK
        varchar address
        varchar phone
        varchar email
        timestamp created_at
    }
    ship_shipment_orders {
        varchar id              PK
        int     ship_company_id FK
        varchar order_id        FK
        varchar tracking_code   UK
        varchar status
        timestamp shipped_at
        timestamp delivered_at
        timestamp created_at
        timestamp updated_at
    }

    %% ── Relaciones ───────────────────────────────────────────
    ctg_departments     ||--o{ ctg_municipalities   : "tiene"
    ctg_categories      ||--o{ ctg_products         : "clasifica"
    ctg_document_types  ||--o{ cs_customers         : "identifica"
    ctg_municipalities  ||--o{ cs_addresses         : "ubica"
    ctg_payment_methods ||--o{ pay_orders           : "se paga con"
    ctg_products        ||--o{ pay_order_items      : "incluye"

    cs_customers ||--o{ cs_addresses    : "tiene"
    cs_customers ||--o{ cs_phone_number : "tiene"
    cs_customers ||--o{ pay_orders      : "realiza"

    pay_orders ||--|{ pay_order_items      : "contiene"
    pay_orders ||--o| ship_shipment_orders : "se envía en"

    ship_ship_company ||--o{ ship_shipment_orders : "gestiona"
```

---

## Descripción de esquemas

### `ctg` — Catálogos

Tablas de referencia estáticas que alimentan a los demás esquemas.

| Tabla | Descripción |
|---|---|
| `ctg.departments` | Departamentos de Colombia |
| `ctg.municipalities` | Municipios, referenciados por `department_code` |
| `ctg.categories` | Categorías de productos |
| `ctg.products` | Productos con precio en USD y COP |
| `ctg.payment_methods` | Métodos de pago disponibles |
| `ctg.document_types` | Tipos de documento de identidad |

### `cs` — Core (Clientes)

| Tabla | Descripción |
|---|---|
| `cs.customers` | Clientes registrados |
| `cs.addresses` | Direcciones de envío por cliente |
| `cs.phone_number` | Teléfonos adicionales por cliente |

### `pay` — Pagos

| Tabla | Descripción |
|---|---|
| `pay.orders` | Órdenes de compra |
| `pay.order_items` | Ítems dentro de cada orden |

### `ship` — Envíos

| Tabla | Descripción |
|---|---|
| `ship.ship_company` | Empresas de transporte |
| `ship.shipment_orders` | Órdenes de envío asociadas a órdenes de pago |

---

## Convenciones

| Símbolo | Significado |
|---|---|
| `PK` | Llave primaria |
| `FK` | Llave foránea |
| `UK` | Restricción única |
| `\|\|--o{` | Uno a muchos (obligatorio — opcional) |
| `\|\|--\|\|` | Uno a uno |
| `\|\|--\|{` | Uno a muchos (obligatorio — obligatorio) |
| `\|\|--o\|` | Uno a cero o uno |
