#!/usr/bin/env python3
"""
Coffee Coop - Carga los INSERT de data/sql en coffee_coop_db usando psycopg2.
Equivalente multiplataforma (Linux/macOS/Windows) de load_data.ps1 - no necesita psql.

Ejecuta en orden todos los archivos .sql generados por 01-generate-data:
    01-INSERT-DEPARTMENTS.sql ... 15-INSERT-PAYMENTS-part-003.sql, 99-RESET-SEQUENCES.sql
Cada archivo trae su propio BEGIN/COMMIT: si uno falla, ese archivo se revierte,
el script se detiene y dice desde cual retomar (--start-from).

Ejemplos:
    python load_data.py --password "*"
    python load_data.py --password "*" --start-from 12-INSERT-DELIVERIES-part-002.sql
    python load_data.py --password "*" --only FARMERS
    python load_data.py --password "*" --dry-run
"""
import argparse
import getpass
import logging
import os
import sys
import time
from pathlib import Path

import psycopg2
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(levelname)s %(message)s', datefmt='%H:%M:%S')
logger = logging.getLogger('load_data')

SCHEMAS = ['geo', 'farm', 'buy', 'pay']

TABLES = [
    'geo.departments', 'geo.municipalities', 'farm.coffee_varieties', 'farm.certifications',
    'buy.collection_points', 'buy.daily_prices', 'farm.farmers', 'farm.farms', 'farm.plots',
    'farm.plot_varieties', 'farm.farm_certifications', 'buy.deliveries', 'buy.quality_analyses',
    'pay.settlements', 'pay.payments',
]

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SQL_DIR = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'data', 'sql'))


def parse_arguments():
    parser = argparse.ArgumentParser(description='Carga los archivos .sql de coffee_coop_db')
    parser.add_argument('--host', default='localhost')
    parser.add_argument('--port', type=int, default=5432)
    parser.add_argument('--user', default='cc_admin')
    parser.add_argument('--password', default=None, help='Si se omite, se pide por teclado (oculta)')
    parser.add_argument('--database', default='coffee_coop_db')
    parser.add_argument('--sql-dir', default=DEFAULT_SQL_DIR)
    parser.add_argument('--start-from', default=None, help='Nombre (o prefijo) del archivo por el que retomar')
    parser.add_argument('--only', default=None, help='Carga solo los archivos cuyo nombre contenga este texto')
    parser.add_argument('--force', action='store_true', help='Carga aunque las tablas ya tengan datos')
    parser.add_argument('--dry-run', action='store_true', help='Solo lista los archivos que se ejecutarian')
    return parser.parse_args()


def connect(args):
    try:
        conn = psycopg2.connect(host=args.host, port=args.port, user=args.user,
                                 password=args.password, dbname=args.database, connect_timeout=10)
        conn.autocommit = True
        return conn
    except psycopg2.OperationalError as e:
        logger.error(f"No fue posible conectarse a {args.database} en {args.host}:{args.port}: {e}")
        sys.exit(1)


def scalar(conn, sql):
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchone()[0]


def check_schemas(conn):
    placeholders = ', '.join(f"'{s}'" for s in SCHEMAS)
    n = scalar(conn, f"SELECT COUNT(*) FROM pg_namespace WHERE nspname IN ({placeholders})")
    if n != len(SCHEMAS):
        logger.error(f"Faltan esquemas (encontrados {n} de {len(SCHEMAS)}). "
                     f"Ejecuta primero scripts/ddl/02-create-tables.sql y 03-alter-tables.sql.")
        sys.exit(1)
    logger.info(f"Conectado. Esquemas encontrados: {', '.join(SCHEMAS)}")


def collect_files(args):
    sql_dir = Path(args.sql_dir)
    if not sql_dir.is_dir():
        logger.error(f"No existe la carpeta {sql_dir}. Descomprime antes data/sql/coffee_coop_sql.zip.")
        sys.exit(1)
    files = sorted(sql_dir.glob('*.sql'))
    if args.start_from:
        files = [f for f in files if f.name >= args.start_from]
    if args.only:
        files = [f for f in files if args.only in f.name]
    if not files:
        logger.error(f"No hay archivos .sql para ejecutar en {sql_dir}")
        sys.exit(1)
    return files


def execute_file(conn, path: Path):
    try:
        sql_text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        sql_text = path.read_text(encoding='latin-1')

    with conn.cursor() as cur:
        try:
            cur.execute(sql_text)
        except Exception as e:
            try:
                cur.execute('ROLLBACK;')
            except Exception:
                pass
            logger.error(f"Fallo {path.name}: {e}")
            logger.warning("Ese archivo se revirtio; los anteriores quedaron guardados.")
            logger.warning(f"Corrige el problema y retoma con: --start-from {path.name}")
            sys.exit(1)


def print_counts(conn):
    parts = ' UNION ALL '.join(f"SELECT '{t}' AS t, COUNT(*) AS c FROM {t}" for t in TABLES)
    with conn.cursor() as cur:
        cur.execute(parts)
        rows = cur.fetchall()
    total = 0
    logger.info("Registros por tabla:")
    for t, c in rows:
        total += c
        print(f"   {t:<28} {c:>12,}")
    print(f"   {'TOTAL':<28} {total:>12,}")


def main():
    args = parse_arguments()
    files = collect_files(args)

    logger.info(f"Carpeta:  {args.sql_dir}")
    logger.info(f"Destino:  {args.user}@{args.host}:{args.port}/{args.database}")
    logger.info(f"{len(files)} archivo(s) para ejecutar")

    if args.dry_run:
        for f in files:
            print(f"   {f.name}")
        return

    if args.password is None:
        args.password = getpass.getpass(f"Contrasena de {args.user}: ")

    conn = connect(args)
    try:
        check_schemas(conn)

        full_load = not args.start_from and not args.only
        if full_load and not args.force:
            has_data = scalar(conn, "SELECT EXISTS (SELECT 1 FROM farm.farmers) "
                                     "OR EXISTS (SELECT 1 FROM geo.departments)")
            if has_data:
                logger.error("Las tablas ya tienen datos. Recrea la base, usa --start-from para "
                             "retomar o --force para cargar igual.")
                sys.exit(1)

        t0 = time.time()
        with tqdm(files, desc="Cargando coffee_coop_db") as pbar:
            for f in pbar:
                pbar.set_postfix(file=f.name[:30])
                t = time.time()
                execute_file(conn, f)
                mb = f.stat().st_size / 1024 ** 2
                logger.info(f"{f.name:<42} {mb:6.1f} MB {time.time() - t:6.1f} s")
        logger.info(f"Carga terminada en {(time.time() - t0) / 60:.1f} minutos")

        print_counts(conn)
    finally:
        conn.close()


if __name__ == '__main__':
    main()
