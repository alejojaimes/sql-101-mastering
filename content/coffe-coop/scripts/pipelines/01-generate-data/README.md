# 01 — Generate synthetic data

Generates the `INSERT` scripts that populate `coffee_coop_db`. With the default configuration it produces **~5.1 million rows** in about one minute (≈ 415 MB of SQL, ≈ 2 GB of RAM).

## Requirements

- Python 3.10 or later
- `pandas`, `numpy`, `openpyxl`

```sh
pip install -r ../requirements.txt
```

## Inputs and outputs

```
data/
├── source/                     # Input catalogs (built by scripts/notebooks/01-build-source.ipynb)
│   ├── CatalogoDatos.xlsx      # DIVIPOLA, coffee departments, varieties, certifications, texts
│   ├── people.xlsx             # first names, surnames, email domains, mobile prefixes
│   └── addresses.xlsx          # rural districts (veredas) per municipality
└── sql/                        # Output (not versioned in git)
    ├── 01-INSERT-DEPARTMENTS.sql
    ├── ...
    ├── 12-INSERT-DELIVERIES-part-001.sql
    ├── ...
    └── 99-RESET-SEQUENCES.sql
```

## Usage

From this folder:

```sh
# Default volume (~5.1M rows)
python coffee_data_generator.py

# 10 % of the volume, for a quick test (~515k rows)
python coffee_data_generator.py --scale 0.1

# More deliveries and a different seed
python coffee_data_generator.py --deliveries 1000000 --seed 7
```

| Argument | Default | Description |
|---|---|---|
| `--scale` | `1.0` | Multiplies every volume |
| `--farmers` | `150000` | Base number of farmers (farms, plots and varieties grow with it) |
| `--deliveries` | `650000` | Base number of deliveries (analyses, settlements and payments grow with it) |
| `--collection-points` | `180` | Base number of collection points |
| `--start-date` / `--end-date` | `2022-01-01` / `2026-09-30` | Period of daily prices and deliveries |
| `--seed` | `42` | Same seed = same data |
| `--rows-per-statement` | `1000` | Rows per `INSERT` |
| `--rows-per-file` | `250000` | Rows per `.sql` file (bigger tables are split in `part-NNN`) |
| `--source` / `--output` | `data/source` / `data/sql` | Input and output folders |

The notebook `scripts/notebooks/02-generate-synthetic-data.ipynb` runs the same functions step by step and produces exactly the same files with the same seed.

## Volumes with the default configuration

| Table | Rows |
|---|---:|
| `geo.departments` | 33 |
| `geo.municipalities` | 1,102 |
| `farm.coffee_varieties` | 12 |
| `farm.certifications` | 7 |
| `buy.collection_points` | 180 |
| `buy.daily_prices` | 312,120 |
| `farm.farmers` | 150,000 |
| `farm.farms` | 232,394 |
| `farm.plots` | 651,793 |
| `farm.plot_varieties` | 1,107,253 |
| `farm.farm_certifications` | 109,425 |
| `buy.deliveries` | 650,000 |
| `buy.quality_analyses` | 648,938 |
| `pay.settlements` | 587,871 |
| `pay.payments` | 692,151 |
| **Total** | **5,143,279** |

## Data rules

Every row respects the PK, FK, UNIQUE and CHECK constraints. The data also follows the business rules that are not enforced by the DDL (they are left for the triggers unit), so they can be used in queries:

- A farmer is at least 18 years old on the membership date.
- The plots of a farm never add up to more than its total area.
- The planted percentages of a plot add up to exactly 100.
- Certification periods of the same farm and certification never overlap; `end_date` is `NULL` while it is valid.
- Accepted deliveries have moisture between 10 % and 12.5 %; only accepted deliveries are settled.
- A settlement uses the daily price of the same collection point and date, and is created after the quality analysis.
- `paid` settlements: payments add up exactly to `net_amount`. `partially_paid`: less. `pending` and `cancelled`: no payments.
- Non-cash payments always have `transaction_reference`.
- Delivery status matches the analysis and settlement: `received`, `rejected`, `accepted` or `settled`.

## Notes

- `SERIAL` tables are inserted with explicit ids so the foreign keys are known while generating. `99-RESET-SEQUENCES.sql` moves each sequence after the last id.
- Load the files into an **empty** database created with `scripts/ddl/01`, `02` and `03`.
- Prices, premiums and weights are synthetic: realistic in shape, not official statistics.
