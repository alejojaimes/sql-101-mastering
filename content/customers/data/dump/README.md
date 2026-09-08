# Database Dump

This directory holds the `pg_dump` export of `customers_db`. The dump file is not stored in git (excluded by `.gitignore` due to size). Download it from the shared link provided by your instructor and place it here before following the import step in the main README.

## Expected file

```
data/dump/customers_db_YYYYMMDD.dump
```

## Generate a new dump (instructors only)

```sh
pg_dump \
  -U admin \
  -h localhost \
  -p 5432 \
  -d customers_db \
  --no-owner \
  --no-privileges \
  -Fc \
  -f content/customers/data/dump/customers_db_$(date +%Y%m%d).dump
```

## Restore

```sh
pg_restore \
  -U admin \
  -h localhost \
  -p 5432 \
  -d customers_db \
  --no-owner \
  content/customers/data/dump/customers_db_YYYYMMDD.dump
```
