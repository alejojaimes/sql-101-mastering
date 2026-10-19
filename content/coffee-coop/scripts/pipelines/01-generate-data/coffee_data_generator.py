#!/usr/bin/env python3
"""
Coffee Coop - Synthetic data generator
======================================

Generates INSERT scripts for every table of coffee_coop_db (around 5 million rows
with the default configuration) from the catalogs in data/source.

* Generation is vectorized with numpy/pandas, so a full run takes a few minutes.
* Every row respects the PK, FK, UNIQUE and CHECK constraints of 03-alter-tables.sql.
* SERIAL tables are inserted with explicit ids, so the foreign keys are known while
  generating. The last script (99-RESET-SEQUENCES.sql) moves the sequences forward.
* Big tables are split into files of ROWS_PER_FILE rows, each one wrapped in
  BEGIN/COMMIT and written as multi-row INSERTs of ROWS_PER_STATEMENT rows.

Usage (from this folder):

    python coffee_data_generator.py                      # default volumes (~5M rows)
    python coffee_data_generator.py --scale 0.1          # 10 % of the volume, for testing
    python coffee_data_generator.py --deliveries 1000000 # change one volume

The same functions are used step by step in scripts/notebooks/02-generate-synthetic-data.ipynb.
"""

import argparse
import math
import os
import time
from dataclasses import dataclass, field, asdict
from typing import Dict, List, Optional

import numpy as np
import pandas as pd

# ##################################################
# #                 CONFIGURATION                  #
# ##################################################

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SOURCE = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'data', 'source'))
DEFAULT_OUTPUT = os.path.abspath(os.path.join(HERE, '..', '..', '..', 'data', 'sql'))


@dataclass
class Config:
    """Volumes and parameters of the generation. Volumes are multiplied by `scale`."""
    seed: int = 42
    scale: float = 1.0

    # Base volumes (scale = 1.0)
    farmers: int = 150_000
    collection_points: int = 180
    deliveries: int = 650_000

    # Probabilities that control the derived volumes
    farms_per_farmer: Dict[int, float] = field(default_factory=lambda: {1: 0.60, 2: 0.28, 3: 0.09, 4: 0.03})
    varieties_per_plot: Dict[int, float] = field(default_factory=lambda: {1: 0.45, 2: 0.40, 3: 0.15})
    certified_farms_pct: float = 0.22

    # Dates of the operation (daily prices, deliveries, settlements, payments)
    start_date: str = '2022-01-01'
    end_date: str = '2026-09-30'

    # Output
    rows_per_statement: int = 1_000
    rows_per_file: int = 250_000

    def volume(self, name: str) -> int:
        return max(1, int(round(getattr(self, name) * self.scale)))


# ##################################################
# #                 SOURCE LOADING                 #
# ##################################################

def load_source(source_path: str = DEFAULT_SOURCE) -> Dict[str, pd.DataFrame]:
    """Reads the Excel catalogs of data/source."""
    catalog = os.path.join(source_path, 'CatalogoDatos.xlsx')
    people = os.path.join(source_path, 'people.xlsx')
    addresses = os.path.join(source_path, 'addresses.xlsx')

    src = {
        'departments': pd.read_excel(catalog, sheet_name='DIVIPOLA-Departamentos', dtype='string'),
        'municipalities': pd.read_excel(catalog, sheet_name='DIVIPOLA-Municipios', dtype='string'),
        'coffee_departments': pd.read_excel(catalog, sheet_name='DEPARTAMENTOS-CAFETEROS',
                                            dtype={'department_code': str}),
        'varieties': pd.read_excel(catalog, sheet_name='VARIEDADES'),
        'certifications': pd.read_excel(catalog, sheet_name='CERTIFICACIONES'),
        'farm_names': pd.read_excel(catalog, sheet_name='NOMBRES-FINCAS'),
        'observations': pd.read_excel(catalog, sheet_name='OBSERVACIONES'),
        'names': pd.read_excel(people, sheet_name='NOMBRES'),
        'surnames': pd.read_excel(people, sheet_name='APELLIDOS'),
        'domains': pd.read_excel(people, sheet_name='DOMINIOS-CORREO'),
        'prefixes': pd.read_excel(people, sheet_name='PREFIJOS-CELULAR', dtype={'prefix': str}),
        'addresses': pd.read_excel(addresses, sheet_name='CODIGOS_POSTALES_BARRIOS_VEREDA', dtype='string'),
    }
    src['coffee_departments']['department_code'] = src['coffee_departments']['department_code'].str.zfill(2)
    return src


def _clean_title(s: pd.Series) -> pd.Series:
    return s.astype(str).str.strip().str.title()


def _ascii_lower(s: pd.Series) -> pd.Series:
    return (s.str.normalize('NFKD').str.encode('ascii', 'ignore').str.decode('ascii')
            .str.lower().str.replace(r'[^a-z]', '', regex=True))


def coffee_municipalities(src) -> pd.DataFrame:
    """Municipalities of the coffee departments, with a sampling weight.
    The department weight is split evenly among its municipalities."""
    m = src['municipalities'].rename(columns={'CODIGO_MUNICIPIO': 'municipality_code',
                                              'NOMBRE_MUNICIPIO': 'municipality_name',
                                              'CODIGO_DEPTO': 'department_code'})
    cd = src['coffee_departments'][['department_code', 'weight', 'latitude', 'longitude']]
    m = m.merge(cd, on='department_code', how='inner')
    m['weight'] = m['weight'] / m.groupby('department_code')['municipality_code'].transform('count')
    m['p'] = m['weight'] / m['weight'].sum()
    return m.reset_index(drop=True)


def veredas_by_municipality(src) -> Dict[str, np.ndarray]:
    """Rural districts (veredas) per municipality, taken from addresses.xlsx."""
    a = src['addresses']
    col = 'VEREDAS CONTENIDAS EN EL CODIGO POSTAL'
    a = a[a[col].notna() & (a[col].str.lower().str.strip() != 'sin informacion de veredas')]
    out: Dict[str, set] = {}
    for code, txt in zip(a['CODIGO MUNICIPIO'], a[col]):
        for v in str(txt).split(','):
            v = v.strip().title()
            if 2 < len(v) <= 100:
                out.setdefault(code, set()).add(v)
    return {k: np.array(sorted(v)) for k, v in out.items()}


GENERIC_VEREDAS = np.array(['El Carmen', 'La Esperanza', 'San Isidro', 'El Rosario', 'La Palma', 'Santa Cruz',
                            'El Retiro', 'La Laguna', 'San Antonio', 'El Tablazo', 'La Florida', 'Alto Bonito',
                            'El Salado', 'La María', 'Buenos Aires', 'El Diviso', 'La Cuchilla', 'Guayabal'])


# ##################################################
# #                   HELPERS                      #
# ##################################################

def weighted_choice(rng, values, p, size):
    p = np.asarray(p, dtype=float)
    return np.asarray(values)[rng.choice(len(values), size=size, p=p / p.sum())]


def random_dates(rng, start, end, size) -> pd.Series:
    start, end = pd.Timestamp(start), pd.Timestamp(end)
    days = (end - start).days
    return pd.Series(start + pd.to_timedelta(rng.integers(0, days + 1, size), unit='D'))


def daily_codes(prefix: str, ts: pd.Series) -> pd.Series:
    """PREFIX-YYYYMMDD-NNNNNN codes; the sequence restarts every day, in time order."""
    order = ts.sort_values(kind='stable').index
    day = ts.dt.strftime('%Y%m%d')
    seq = pd.Series(0, index=ts.index)
    seq.loc[order] = day.loc[order].groupby(day.loc[order]).cumcount().to_numpy() + 1
    return prefix + '-' + day + '-' + seq.astype(str).str.zfill(6)


def fmt_ts(ts: pd.Series) -> pd.Series:
    return ts.dt.strftime('%Y-%m-%d %H:%M:%S')


def fmt_date(ts: pd.Series) -> pd.Series:
    return ts.dt.strftime('%Y-%m-%d')


def cents_to_str(c) -> pd.Series:
    c = pd.Series(c).astype('int64')
    return (c // 100).astype(str) + '.' + (c % 100).astype(str).str.zfill(2)


def split_cents(rng, total_cents: np.ndarray, parts: np.ndarray, min_share=0.1):
    """Splits each total into `parts` positive integer amounts (in cents) that add up exactly."""
    rep_total = np.repeat(total_cents, parts)
    rep_parts = np.repeat(parts, parts)
    g = rng.gamma(2.0, 1.0, size=rep_total.size)
    grp = np.repeat(np.arange(total_cents.size), parts)
    gsum = np.bincount(grp, weights=g)[grp]
    share = min_share + (1 - min_share * rep_parts) * (g / gsum)
    amounts = np.floor(rep_total * share).astype('int64')
    # last part of each group takes the remainder
    last = np.cumsum(parts) - 1
    first = last - parts + 1
    sums = np.add.reduceat(amounts, first)
    amounts[last] += total_cents - sums
    return grp, amounts


# ##################################################
# #              CATALOG TABLES                    #
# ##################################################

def gen_departments(src) -> pd.DataFrame:
    d = src['departments']
    return pd.DataFrame({'department_code': d['CODIGO_DEPTO'],
                         'department_name': _clean_title(d['NOMBRE_DEPTO'])})


def gen_municipalities(src) -> pd.DataFrame:
    m = src['municipalities']
    df = pd.DataFrame({'municipality_code': m['CODIGO_MUNICIPIO'],
                       'municipality_name': _clean_title(m['NOMBRE_MUNICIPIO']),
                       'department_code': m['CODIGO_DEPTO']})
    return df.drop_duplicates(subset=['department_code', 'municipality_name'])


def gen_coffee_varieties(src) -> pd.DataFrame:
    v = src['varieties'].reset_index(drop=True)
    return pd.DataFrame({'variety_id': np.arange(1, len(v) + 1),
                         'variety_name': v['variety_name'],
                         'species': v['species'],
                         'is_rust_resistant': v['is_rust_resistant'].astype(bool),
                         'description': v['description'],
                         '_weight': v['weight'].astype(float)})


def gen_certifications(src) -> pd.DataFrame:
    c = src['certifications'].reset_index(drop=True)
    return pd.DataFrame({'certification_id': np.arange(1, len(c) + 1),
                         'certification_name': c['certification_name'],
                         'issuing_body': c['issuing_body'],
                         'premium_per_kg': c['premium_per_kg'].astype(float),
                         '_weight': c['weight'].astype(float)})


# ##################################################
# #                 BUY - POINTS & PRICES          #
# ##################################################

def gen_collection_points(cfg: Config, src, rng, munis: pd.DataFrame) -> pd.DataFrame:
    n = max(cfg.volume('collection_points'), munis['department_code'].nunique())
    # one point per coffee department, the rest by weight
    keys = np.log(munis['p'].to_numpy()) + rng.gumbel(size=len(munis))
    first = munis.iloc[np.argsort(-keys)].drop_duplicates('department_code')
    rest = munis.iloc[rng.choice(len(munis), n - len(first), p=munis['p'].to_numpy())]
    pts = pd.concat([first, rest]).reset_index(drop=True)
    # numbered by name: some municipalities share the same name (e.g. Palestina in Huila and Caldas)
    name_title = pts['municipality_name'].str.title()
    pts['k'] = name_title.groupby(name_title).cumcount() + 1
    via = weighted_choice(rng, ['Calle', 'Carrera', 'Avenida', 'Diagonal', 'Transversal'], [5, 5, 1, 1, 1], n)
    a, b, c = rng.integers(1, 40, n), rng.integers(1, 60, n), rng.integers(1, 99, n)
    df = pd.DataFrame({
        'collection_point_id': np.arange(1, n + 1),
        'point_name': 'Punto de Compra ' + name_title + ' ' + pts['k'].astype(str),
        'municipality_code': pts['municipality_code'],
        'address_line': [f'{v} {x} # {y}-{z}' for v, x, y, z in zip(via, a, b, c)],
        'phone_number': np.where(rng.random(n) < 0.85,
                                 '60' + rng.integers(1, 9, n).astype(str) + rng.integers(1_000_000, 9_999_999, n).astype(str),
                                 None),
        'is_active': rng.random(n) < 0.95,
        '_department_code': pts['department_code'],
    })
    return df


def price_trend(dates: pd.DatetimeIndex) -> np.ndarray:
    """Synthetic base price (COP per kg of dry parchment) with a smooth trend."""
    knots = pd.to_datetime(['2022-01-01', '2022-09-01', '2023-06-01', '2024-03-01', '2024-12-01', '2025-06-01', '2026-12-31'])
    values = np.array([11_800, 12_600, 10_400, 12_300, 19_800, 21_500, 20_800], dtype=float)
    to_days = lambda d: np.asarray(d, dtype='datetime64[D]').astype('int64')
    return np.interp(to_days(dates), to_days(knots), values)


def gen_daily_prices(cfg: Config, rng, points: pd.DataFrame) -> pd.DataFrame:
    dates = pd.date_range(cfg.start_date, cfg.end_date, freq='D')
    nd, npnt = len(dates), len(points)
    dev = np.zeros(nd)
    eps = rng.normal(0, 0.012, nd)
    for i in range(1, nd):
        dev[i] = 0.97 * dev[i - 1] + eps[i]
    national = price_trend(dates) * np.exp(dev)
    point_factor = rng.normal(1.0, 0.015, npnt)
    price = national[:, None] * point_factor[None, :] * np.exp(rng.normal(0, 0.004, (nd, npnt)))
    price = np.round(price / 10) * 10
    df = pd.DataFrame({
        'daily_price_id': np.arange(1, nd * npnt + 1),
        'collection_point_id': np.tile(points['collection_point_id'].to_numpy(), nd),
        'price_date': np.repeat(dates.strftime('%Y-%m-%d').to_numpy(), npnt),
        'price_per_kg': price.ravel(),
        'reference_yield_factor': 94.0,
    })
    return df


# ##################################################
# #                 FARM MODULE                    #
# ##################################################

def gen_farmers(cfg: Config, src, rng, munis: pd.DataFrame) -> pd.DataFrame:
    n = cfg.volume('farmers')
    names = src['names']
    m_names = names.loc[names['gender'] == 'M', 'first_name'].to_numpy()
    f_names = names.loc[names['gender'] == 'F', 'first_name'].to_numpy()
    surnames = src['surnames']['surname'].to_numpy()

    gender = weighted_choice(rng, ['M', 'F', 'O'], [0.55, 0.43, 0.02], n)
    first = np.where(gender == 'M', rng.choice(m_names, n),
                     np.where(gender == 'F', rng.choice(f_names, n),
                              np.where(rng.random(n) < 0.5, rng.choice(m_names, n), rng.choice(f_names, n))))
    # 25 % have a second given name
    second = np.where(gender == 'F', rng.choice(f_names, n), rng.choice(m_names, n))
    has_second = (rng.random(n) < 0.25) & (second != first)
    first_name = np.where(has_second, np.char.add(np.char.add(first.astype(str), ' '), second.astype(str)), first)
    s1, s2 = rng.choice(surnames, n), rng.choice(surnames, n)
    last_name = np.char.add(np.char.add(s1.astype(str), ' '), s2.astype(str))

    birth = random_dates(rng, '1950-01-01', '2000-12-31', n)
    earliest = (birth + pd.DateOffset(years=18)).clip(lower=pd.Timestamp('1995-01-01'))
    latest = pd.Timestamp('2021-06-30')
    span = (latest - earliest).dt.days.clip(lower=0)
    membership = earliest + pd.to_timedelta((rng.random(n) * (span + 1)).astype(int), unit='D')

    docs = np.unique(rng.integers(10_000_000, 1_200_000_000, int(n * 1.05) + 100))
    docs = rng.permutation(docs)[:n]

    farmer_id = np.arange(1, n + 1)
    has_email = rng.random(n) < 0.70
    user = _ascii_lower(pd.Series(first)) + '.' + _ascii_lower(pd.Series(s1)) + pd.Series(farmer_id).astype(str)
    domain = rng.choice(src['domains']['domain'].to_numpy(), n)
    email = np.where(has_email, user + '@' + domain, None)

    prefix = rng.choice(src['prefixes']['prefix'].to_numpy(), n)
    phone = np.char.add(prefix.astype(str), rng.integers(1_000_000, 9_999_999, n).astype(str))

    return pd.DataFrame({
        'farmer_id': farmer_id,
        'document_number': docs.astype(str),
        'first_name': first_name,
        'last_name': last_name,
        'birth_date': fmt_date(birth),
        'gender': gender,
        'phone_number': phone,
        'email': email,
        'membership_date': fmt_date(membership),
        'is_active': rng.random(n) < 0.92,
        'municipality_code': weighted_choice(rng, munis['municipality_code'], munis['p'], n),
        '_membership': membership,
    })


def gen_farms(cfg: Config, src, rng, farmers: pd.DataFrame, munis: pd.DataFrame,
              veredas: Dict[str, np.ndarray]) -> pd.DataFrame:
    k = weighted_choice(rng, list(cfg.farms_per_farmer), list(cfg.farms_per_farmer.values()), len(farmers))
    owner = np.repeat(farmers['farmer_id'].to_numpy(), k)
    n = owner.size
    j = np.concatenate([np.arange(x) for x in k]) if n else np.array([], int)

    farm_names = src['farm_names']['farm_name'].to_numpy()
    base = np.repeat(rng.integers(0, len(farm_names), len(farmers)), k)
    name = farm_names[(base + j * 7) % len(farm_names)]          # different names for the same farmer

    owner_idx = owner - 1
    own_muni = farmers['municipality_code'].to_numpy()[owner_idx]
    other_muni = weighted_choice(rng, munis['municipality_code'], munis['p'], n)
    muni = np.where(rng.random(n) < 0.75, own_muni, other_muni)

    vereda = np.empty(n, dtype=object)
    s = pd.Series(np.arange(n)).groupby(muni)
    for code, idx in s:
        pool = veredas.get(code, GENERIC_VEREDAS)
        vereda[idx.to_numpy()] = rng.choice(pool, len(idx))

    area = np.clip(np.round(np.exp(rng.normal(0.7, 0.8, n)), 2), 0.30, 60.0)
    altitude = np.clip(rng.normal(1650, 250, n), 900, 2300).astype(int)
    # coordinates around the coffee zone of the farm's department
    center = munis.set_index('municipality_code')[['latitude', 'longitude']].reindex(muni).to_numpy(dtype=float)
    has_coords = rng.random(n) < 0.55
    lat = np.where(has_coords, np.round(center[:, 0] + rng.normal(0, 0.25, n), 6), np.nan)
    lon = np.where(has_coords, np.round(center[:, 1] + rng.normal(0, 0.25, n), 6), np.nan)

    membership = farmers['_membership'].to_numpy()[owner_idx]
    limit = np.datetime64('2021-12-31')
    span = ((limit - membership) / np.timedelta64(1, 'D')).astype(int).clip(min=0)
    reg = (pd.Series(membership) + pd.to_timedelta((rng.random(n) * (span + 1)).astype(int), unit='D')
           + pd.to_timedelta(rng.integers(7 * 3600, 18 * 3600, n), unit='s'))

    return pd.DataFrame({
        'farm_id': np.arange(1, n + 1),
        'farmer_id': owner,
        'municipality_code': muni,
        'farm_name': name,
        'rural_district': vereda,
        'total_area_ha': area,
        'altitude_masl': altitude,
        'latitude': lat,
        'longitude': lon,
        'registered_at': fmt_ts(reg),
    })


def gen_plots(cfg: Config, rng, farms: pd.DataFrame) -> pd.DataFrame:
    area = farms['total_area_ha'].to_numpy()
    k = np.clip(1 + rng.poisson(area / 1.5), 1, 10)
    farm_id = np.repeat(farms['farm_id'].to_numpy(), k)
    n = farm_id.size
    j = np.concatenate([np.arange(x) for x in k])
    g = rng.gamma(2.0, 1.0, n)
    grp = np.repeat(np.arange(len(farms)), k)
    share = g / np.bincount(grp, weights=g)[grp]
    plot_area = np.maximum(np.floor(np.repeat(area, k) * 0.92 * share * 100) / 100, 0.01)
    return pd.DataFrame({
        'plot_id': np.arange(1, n + 1),
        'farm_id': farm_id,
        'plot_code': 'L' + pd.Series(j + 1).astype(str).str.zfill(2),
        'area_ha': plot_area,
        'planting_year': rng.integers(1995, 2026, n),
        'shade_type': weighted_choice(rng, ['full_sun', 'partial_shade', 'full_shade'], [0.45, 0.45, 0.10], n),
    })


def gen_plot_varieties(cfg: Config, rng, plots: pd.DataFrame, varieties: pd.DataFrame) -> pd.DataFrame:
    n_plots = len(plots)
    k = weighted_choice(rng, list(cfg.varieties_per_plot), list(cfg.varieties_per_plot.values()), n_plots)
    # weighted sampling without replacement (Gumbel top-k)
    w = varieties['_weight'].to_numpy()
    keys = np.log(w)[None, :] + rng.gumbel(size=(n_plots, len(w)))
    order = np.argsort(-keys, axis=1)
    rows = np.repeat(np.arange(n_plots), k)
    pos = np.concatenate([np.arange(x) for x in k])
    variety_idx = order[rows, pos]
    n = rows.size

    # percentages that add up to exactly 100.00 per plot (minimum 5 %)
    g = rng.gamma(2.0, 1.0, n)
    gsum = np.bincount(rows, weights=g)[rows]
    kk = np.repeat(k, k)
    share = 0.05 + (1 - 0.05 * kk) * g / gsum
    hund = np.floor(share * 10_000).astype('int64')
    last = np.cumsum(k) - 1
    first = last - k + 1
    hund[last] += 10_000 - np.add.reduceat(hund, first)

    density = np.repeat(rng.uniform(4_000, 7_000, n_plots), k)
    plot_area = plots['area_ha'].to_numpy()[rows]
    trees = np.maximum(1, np.round(plot_area * hund / 10_000 * density)).astype(int)
    return pd.DataFrame({
        'plot_variety_id': np.arange(1, n + 1),
        'plot_id': plots['plot_id'].to_numpy()[rows],
        'variety_id': varieties['variety_id'].to_numpy()[variety_idx],
        'planted_percentage': cents_to_str(hund).to_numpy(),
        'tree_count': trees,
    })


def gen_farm_certifications(cfg: Config, rng, farms: pd.DataFrame, certs: pd.DataFrame) -> pd.DataFrame:
    end = pd.Timestamp(cfg.end_date)
    certified = farms['farm_id'].to_numpy()[rng.random(len(farms)) < cfg.certified_farms_pct]
    nf = certified.size
    k = np.where(rng.random(nf) < 0.8, 1, 2)
    w = certs['_weight'].to_numpy()
    keys = np.log(w)[None, :] + rng.gumbel(size=(nf, len(w)))
    order = np.argsort(-keys, axis=1)
    rows = np.repeat(np.arange(nf), k)
    pos = np.concatenate([np.arange(x) for x in k])
    farm_id = certified[rows]
    cert_id = certs['certification_id'].to_numpy()[order[rows, pos]]

    periods = []
    start = random_dates(rng, '2014-01-01', '2025-06-30', farm_id.size)
    active = np.ones(farm_id.size, bool)
    for _ in range(4):                                  # up to 4 renewals
        stop = start + pd.DateOffset(years=3)
        end_date = stop.where(stop <= end)            # NULL when still valid
        periods.append(pd.DataFrame({'farm_id': farm_id[active], 'certification_id': cert_id[active],
                                     'start_date': start[active].to_numpy(), 'end_date': end_date[active].to_numpy()}))
        renew = active & end_date.notna().to_numpy() & (rng.random(farm_id.size) < 0.6)
        start = stop + pd.to_timedelta(rng.integers(1, 60, farm_id.size), unit='D')
        renew &= (start <= end).to_numpy()
        active = renew
        if not active.any():
            break
    df = pd.concat(periods, ignore_index=True).sort_values(['start_date', 'farm_id']).reset_index(drop=True)
    abbrev = {1: 'RA', 2: 'FT', 3: '4C', 4: 'ORG', 5: 'CAFE', 6: 'AAA', 7: 'BF'}
    pref = df['certification_id'].map(abbrev).fillna('CRT')
    df['certificate_number'] = (pref + '-' + df['start_date'].dt.year.astype(str) + '-'
                                + pd.Series(np.arange(1, len(df) + 1)).astype(str).str.zfill(7))
    df['farm_certification_id'] = np.arange(1, len(df) + 1)
    df['_start'] = df['start_date']
    df['_end'] = df['end_date']
    df['start_date'] = fmt_date(df['start_date'])
    df['end_date'] = df['end_date'].dt.strftime('%Y-%m-%d').where(df['end_date'].notna(), None)
    return df[['farm_certification_id', 'farm_id', 'certification_id', 'start_date', 'end_date',
               'certificate_number', '_start', '_end']]


# ##################################################
# #                 BUY - DELIVERIES               #
# ##################################################

MONTH_WEIGHT = np.array([0.9, 0.6, 0.7, 1.1, 1.3, 1.1, 0.7, 0.6, 0.8, 1.3, 1.5, 1.3])  # harvest seasonality


def gen_deliveries(cfg: Config, rng, farms: pd.DataFrame, points: pd.DataFrame,
                   munis: pd.DataFrame) -> pd.DataFrame:
    n = cfg.volume('deliveries')
    # farm (bigger farms deliver more)
    w = farms['total_area_ha'].to_numpy() ** 0.8
    farm_idx = rng.choice(len(farms), n, p=w / w.sum())

    # date with harvest seasonality + time of the day
    dates = pd.date_range(cfg.start_date, cfg.end_date, freq='D')
    dw = MONTH_WEIGHT[dates.month - 1]
    day = dates[rng.choice(len(dates), n, p=dw / dw.sum())]
    delivered_at = pd.Series(day) + pd.to_timedelta(rng.integers(6 * 3600, 17 * 3600, n), unit='s')

    # collection point: the farm's usual point (85 %) or another one in the same department
    muni_dept = dict(zip(munis['municipality_code'], munis['department_code']))
    pts_by_muni = points.groupby('municipality_code')['collection_point_id'].apply(np.array).to_dict()
    pts_by_dept = points.groupby('_department_code')['collection_point_id'].apply(np.array).to_dict()
    all_pts = points['collection_point_id'].to_numpy()
    farm_muni = farms['municipality_code'].to_numpy()
    home = np.empty(len(farms), dtype=int)
    farm_dept = np.array([muni_dept.get(m, '') for m in farm_muni])
    for code, idx in pd.Series(np.arange(len(farms))).groupby(farm_muni):
        pool = pts_by_muni.get(code)
        if pool is None:
            pool = pts_by_dept.get(muni_dept.get(code), all_pts)
        home[idx.to_numpy()] = rng.choice(pool, len(idx))
    point = home[farm_idx]
    other = rng.random(n) < 0.15
    d_dept = farm_dept[farm_idx]
    for dept, idx in pd.Series(np.flatnonzero(other)).groupby(d_dept[other]):
        point[idx.to_numpy()] = rng.choice(pts_by_dept.get(dept, all_pts), len(idx))

    coffee_type = weighted_choice(rng, ['dry_parchment', 'wet_parchment', 'cherry'], [0.90, 0.06, 0.04], n)
    bags = np.clip(1 + rng.poisson(2.5, n), 1, 20)
    kg_bag = np.where(coffee_type == 'dry_parchment', rng.uniform(38, 62.5, n),
                      np.where(coffee_type == 'wet_parchment', rng.uniform(45, 70, n), rng.uniform(40, 65, n)))
    gross = np.round(bags * kg_bag, 2)

    df = pd.DataFrame({
        'farm_id': farms['farm_id'].to_numpy()[farm_idx],
        'collection_point_id': point,
        '_ts': delivered_at,
        'coffee_type': coffee_type,
        'bag_count': bags,
        'gross_weight_kg': gross,
    })
    df = df.sort_values('_ts', kind='stable').reset_index(drop=True)
    df.insert(0, 'delivery_id', daily_codes('DLV', df['_ts']))
    df['delivered_at'] = fmt_ts(df['_ts'])
    return df


def gen_quality_analyses(cfg: Config, src, rng, deliveries: pd.DataFrame) -> pd.DataFrame:
    n = len(deliveries)
    end = pd.Timestamp(cfg.end_date)
    recent = deliveries['_ts'] >= end - pd.Timedelta(days=6)
    analyzed = ~(recent & (rng.random(n) < 0.5)).to_numpy()
    d = deliveries.loc[analyzed, ['delivery_id', '_ts', 'coffee_type']].reset_index(drop=True)
    m = len(d)

    p_ok = d['coffee_type'].map({'dry_parchment': 0.93, 'wet_parchment': 0.75, 'cherry': 0.85}).to_numpy()
    ok = rng.random(m) < p_ok
    moisture = np.where(ok, rng.uniform(10.0, 12.5, m),
                        np.where(rng.random(m) < 0.7, rng.uniform(12.6, 18.0, m), rng.uniform(7.0, 9.9, m)))
    yield_f = np.where(ok, np.clip(rng.normal(92, 2.5, m), 86, 99.5), np.clip(rng.normal(100, 4, m), 90, 115))
    defects = np.where(ok, rng.uniform(0, 6, m), rng.uniform(4, 20, m))
    cup = np.where(rng.random(m) < 0.35, np.clip(rng.normal(83, 2.5, m), 75, 90), np.nan)

    names = src['names']['first_name'].to_numpy()
    surn = src['surnames']['surname'].to_numpy()
    analysts = np.char.add(np.char.add(rng.choice(names, 40).astype(str), ' '), rng.choice(surn, 40).astype(str))

    obs = src['observations']
    obs_ok = obs.loc[obs['applies_to'].isin(['accepted', 'any']), 'observation'].to_numpy()
    obs_bad = obs.loc[obs['applies_to'].isin(['rejected', 'any']), 'observation'].to_numpy()
    has_obs = rng.random(m) < np.where(ok, 0.25, 0.85)
    observation = np.where(has_obs, np.where(ok, rng.choice(obs_ok, m), rng.choice(obs_bad, m)), None)

    ts = d['_ts'] + pd.to_timedelta(rng.integers(15 * 60, 5 * 3600, m), unit='s')
    df = pd.DataFrame({
        'delivery_id': d['delivery_id'],
        '_ts': ts,
        'moisture_pct': np.round(moisture, 2),
        'yield_factor': np.round(yield_f, 2),
        'defects_pct': np.round(defects, 2),
        'cup_score': np.round(cup, 2),
        'is_accepted': ok,
        'analyst_name': rng.choice(analysts, m),
        'observations': observation,
    })
    df.insert(0, 'analysis_id', daily_codes('QA', df['_ts']))
    df['analyzed_at'] = fmt_ts(df['_ts'])
    return df


# ##################################################
# #                 PAY MODULE                     #
# ##################################################

def gen_settlements(cfg: Config, rng, deliveries: pd.DataFrame, analyses: pd.DataFrame,
                    prices: pd.DataFrame, points: pd.DataFrame, farm_certs: pd.DataFrame,
                    certs: pd.DataFrame) -> pd.DataFrame:
    end = pd.Timestamp(cfg.end_date)
    acc = analyses.loc[analyses['is_accepted'], ['delivery_id', 'yield_factor', '_ts']].rename(columns={'_ts': '_analyzed'})
    d = deliveries.merge(acc, on='delivery_id', how='inner')
    old = (d['_ts'] < end - pd.Timedelta(days=10)).to_numpy()
    settle = rng.random(len(d)) < np.where(old, 0.99, 0.5)
    d = d.loc[settle].reset_index(drop=True)
    m = len(d)

    # daily price of that point on the delivery date (ids are date-major)
    start = pd.Timestamp(cfg.start_date)
    day_idx = (d['_ts'].dt.normalize() - start).dt.days.to_numpy()
    point_pos = pd.Series(np.arange(len(points)), index=points['collection_point_id'])[d['collection_point_id']].to_numpy()
    price_id = day_idx * len(points) + point_pos + 1
    base_price = prices['price_per_kg'].to_numpy()[price_id - 1]

    # certification premium valid on the delivery date (highest one)
    fc = farm_certs.merge(certs[['certification_id', 'premium_per_kg']], on='certification_id')
    x = d[['farm_id', '_ts']].reset_index().merge(fc[['farm_id', '_start', '_end', 'premium_per_kg']], on='farm_id')
    valid = (x['_ts'] >= x['_start']) & (x['_end'].isna() | (x['_ts'] <= x['_end']))
    premium = x.loc[valid].groupby('index')['premium_per_kg'].max().reindex(range(m), fill_value=0).to_numpy()

    gross_kg = d['gross_weight_kg'].to_numpy()
    net_w_c = np.round(gross_kg * rng.uniform(0.975, 0.995, m) * 100).astype('int64')      # kg in cents
    price_c = (np.round(base_price * 94.0 / d['yield_factor'].to_numpy() + premium) * 100).astype('int64')
    gross_c = (net_w_c * price_c + 50) // 100                                              # numeric(14,2)
    has_ded = rng.random(m) < 0.45
    ded_c = np.where(has_ded, np.floor(gross_c * rng.uniform(0.005, 0.06, m)), 0).astype('int64')
    net_c = gross_c - ded_c

    settled_ts = d['_analyzed'] + pd.to_timedelta(rng.integers(3600, 72 * 3600, m), unit='s')
    age = (end - settled_ts).dt.days.to_numpy()
    r = rng.random(m)
    status = np.where(age > 30,
                      np.select([r < 0.94, r < 0.97, r < 0.99], ['paid', 'partially_paid', 'pending'], 'cancelled'),
                      np.select([r < 0.55, r < 0.65, r < 0.98], ['paid', 'partially_paid', 'pending'], 'cancelled'))

    df = pd.DataFrame({
        'delivery_id': d['delivery_id'],
        'daily_price_id': price_id,
        'net_weight_kg': cents_to_str(net_w_c).to_numpy(),
        'price_per_kg_applied': cents_to_str(price_c).to_numpy(),
        'deductions_amount': cents_to_str(ded_c).to_numpy(),
        '_ts': settled_ts,
        'status': status,
        '_net_c': net_c,
    })
    df.insert(0, 'settlement_id', daily_codes('STL', df['_ts']))
    df['settled_at'] = fmt_ts(df['_ts'])
    return df


def gen_payments(cfg: Config, rng, settlements: pd.DataFrame) -> pd.DataFrame:
    s = settlements[settlements['status'].isin(['paid', 'partially_paid'])].reset_index(drop=True)
    paid = (s['status'] == 'paid').to_numpy()
    parts = np.where(paid, weighted_choice(rng, [1, 2, 3], [0.82, 0.14, 0.04], len(s)),
                     weighted_choice(rng, [1, 2], [0.8, 0.2], len(s)))
    # partially paid settlements only receive 30 % - 80 % of the net amount
    total = np.where(paid, s['_net_c'].to_numpy(),
                     np.floor(s['_net_c'].to_numpy() * rng.uniform(0.3, 0.8, len(s)))).astype('int64')
    grp, amount = split_cents(rng, total, parts)

    n = grp.size
    pos = np.concatenate([np.arange(x) for x in parts])
    delay = rng.integers(2 * 3600, 7 * 24 * 3600, n) * (pos + 1)
    ts = s['_ts'].to_numpy()[grp] + pd.to_timedelta(delay, unit='s').to_numpy()
    method = weighted_choice(rng, ['cash', 'bank_transfer', 'check'], [0.30, 0.60, 0.10], n)
    seq = pd.Series(np.arange(1, n + 1)).astype(str).str.zfill(9).to_numpy()
    ref = np.where(method == 'bank_transfer', np.char.add('TRX-', seq.astype(str)),
                   np.where(method == 'check', np.char.add('CHK-', seq.astype(str)),
                            np.where(rng.random(n) < 0.1, np.char.add('REC-', seq.astype(str)), None)))
    df = pd.DataFrame({
        'settlement_id': s['settlement_id'].to_numpy()[grp],
        'payment_method': method,
        'amount': cents_to_str(amount).to_numpy(),
        '_ts': pd.Series(ts),
        'transaction_reference': ref,
    })
    df.insert(0, 'payment_id', daily_codes('PAY', df['_ts']))
    df['paid_at'] = fmt_ts(df['_ts'])
    return df


def finalize_delivery_status(deliveries, analyses, settlements) -> pd.DataFrame:
    status = np.full(len(deliveries), 'received', dtype=object)
    acc = analyses.set_index('delivery_id')['is_accepted']
    is_acc = deliveries['delivery_id'].map(acc)
    status[(is_acc == True).to_numpy()] = 'accepted'          # noqa: E712
    status[(is_acc == False).to_numpy()] = 'rejected'         # noqa: E712
    status[deliveries['delivery_id'].isin(settlements['delivery_id']).to_numpy()] = 'settled'
    deliveries['status'] = status
    return deliveries


# ##################################################
# #                 SQL WRITER                     #
# ##################################################

def _literal(col: pd.Series, decimals: Optional[int] = None) -> pd.Series:
    """Converts a column into SQL literals (vectorized)."""
    if pd.api.types.is_bool_dtype(col):
        return np.where(col, 'TRUE', 'FALSE')
    if pd.api.types.is_integer_dtype(col):
        return col.astype(str)
    if pd.api.types.is_float_dtype(col):
        fmt = f'{{:.{decimals if decimals is not None else 2}f}}'
        out = col.map(lambda v: fmt.format(v) if not math.isnan(v) else 'NULL')
        return out
    # strings / objects
    isnull = col.isna()
    s = col.astype(str).str.replace("'", "''", regex=False)
    out = "'" + s + "'"
    out[isnull] = 'NULL'
    return out


TABLES = [
    # order, schema.table, file label, dataframe key, columns
    (1, 'geo.departments', 'DEPARTMENTS', 'departments', ['department_code', 'department_name']),
    (2, 'geo.municipalities', 'MUNICIPALITIES', 'municipalities', ['municipality_code', 'municipality_name', 'department_code']),
    (3, 'farm.coffee_varieties', 'COFFEE-VARIETIES', 'coffee_varieties',
     ['variety_id', 'variety_name', 'species', 'is_rust_resistant', 'description']),
    (4, 'farm.certifications', 'CERTIFICATIONS', 'certifications',
     ['certification_id', 'certification_name', 'issuing_body', 'premium_per_kg']),
    (5, 'buy.collection_points', 'COLLECTION-POINTS', 'collection_points',
     ['collection_point_id', 'point_name', 'municipality_code', 'address_line', 'phone_number', 'is_active']),
    (6, 'buy.daily_prices', 'DAILY-PRICES', 'daily_prices',
     ['daily_price_id', 'collection_point_id', 'price_date', 'price_per_kg', 'reference_yield_factor']),
    (7, 'farm.farmers', 'FARMERS', 'farmers',
     ['farmer_id', 'document_number', 'first_name', 'last_name', 'birth_date', 'gender', 'phone_number',
      'email', 'membership_date', 'is_active', 'municipality_code']),
    (8, 'farm.farms', 'FARMS', 'farms',
     ['farm_id', 'farmer_id', 'municipality_code', 'farm_name', 'rural_district', 'total_area_ha',
      'altitude_masl', 'latitude', 'longitude', 'registered_at']),
    (9, 'farm.plots', 'PLOTS', 'plots', ['plot_id', 'farm_id', 'plot_code', 'area_ha', 'planting_year', 'shade_type']),
    (10, 'farm.plot_varieties', 'PLOT-VARIETIES', 'plot_varieties',
     ['plot_variety_id', 'plot_id', 'variety_id', 'planted_percentage', 'tree_count']),
    (11, 'farm.farm_certifications', 'FARM-CERTIFICATIONS', 'farm_certifications',
     ['farm_certification_id', 'farm_id', 'certification_id', 'start_date', 'end_date', 'certificate_number']),
    (12, 'buy.deliveries', 'DELIVERIES', 'deliveries',
     ['delivery_id', 'farm_id', 'collection_point_id', 'delivered_at', 'coffee_type', 'bag_count',
      'gross_weight_kg', 'status']),
    (13, 'buy.quality_analyses', 'QUALITY-ANALYSES', 'quality_analyses',
     ['analysis_id', 'delivery_id', 'analyzed_at', 'moisture_pct', 'yield_factor', 'defects_pct', 'cup_score',
      'is_accepted', 'analyst_name', 'observations']),
    (14, 'pay.settlements', 'SETTLEMENTS', 'settlements',
     ['settlement_id', 'delivery_id', 'daily_price_id', 'net_weight_kg', 'price_per_kg_applied',
      'deductions_amount', 'settled_at', 'status']),
    (15, 'pay.payments', 'PAYMENTS', 'payments',
     ['payment_id', 'settlement_id', 'payment_method', 'amount', 'paid_at', 'transaction_reference']),
]

DECIMALS = {'latitude': 6, 'longitude': 6}

# numeric columns that are already formatted as strings (exact cents) must not be quoted
UNQUOTED_STRINGS = {'planted_percentage', 'net_weight_kg', 'price_per_kg_applied', 'deductions_amount', 'amount'}


def write_inserts(df: pd.DataFrame, order: int, table: str, label: str, columns: List[str],
                  output_dir: str, rows_per_statement: int = 1_000, rows_per_file: int = 250_000) -> List[str]:
    """Writes multi-row INSERT files. Returns the list of written files."""
    os.makedirs(output_dir, exist_ok=True)
    lits = []
    for c in columns:
        if c in UNQUOTED_STRINGS:
            lits.append(df[c].astype(str))
        else:
            lits.append(pd.Series(_literal(df[c], DECIMALS.get(c)), index=df.index))
    rows = '(' + lits[0]
    for lit in lits[1:]:
        rows = rows + ', ' + lit
    rows = (rows + ')').to_numpy()

    n = len(rows)
    n_files = max(1, math.ceil(n / rows_per_file))
    header = f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n"
    files = []
    for f in range(n_files):
        chunk = rows[f * rows_per_file:(f + 1) * rows_per_file]
        suffix = f'-part-{f + 1:03d}' if n_files > 1 else ''
        name = f'{order:02d}-INSERT-{label}{suffix}.sql'
        path = os.path.join(output_dir, name)
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(f'-- {table}: rows {f * rows_per_file + 1} to {f * rows_per_file + len(chunk)} of {n}\n')
            fh.write('BEGIN;\n')
            for i in range(0, len(chunk), rows_per_statement):
                fh.write(header)
                fh.write(',\n'.join(chunk[i:i + rows_per_statement]))
                fh.write(';\n')
            fh.write('COMMIT;\n')
        files.append(path)
    return files


SERIAL_COLUMNS = [
    ('farm.coffee_varieties', 'variety_id'), ('farm.certifications', 'certification_id'),
    ('buy.collection_points', 'collection_point_id'), ('buy.daily_prices', 'daily_price_id'),
    ('farm.farmers', 'farmer_id'), ('farm.farms', 'farm_id'), ('farm.plots', 'plot_id'),
    ('farm.plot_varieties', 'plot_variety_id'), ('farm.farm_certifications', 'farm_certification_id'),
]


def write_reset_sequences(output_dir: str) -> str:
    path = os.path.join(output_dir, '99-RESET-SEQUENCES.sql')
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write('-- Moves every SERIAL sequence after the last inserted id\n')
        for table, col in SERIAL_COLUMNS:
            fh.write(f"SELECT setval(pg_get_serial_sequence('{table}', '{col}'), "
                     f"(SELECT COALESCE(MAX({col}), 1) FROM {table}));\n")
    return path


# ##################################################
# #                 FULL RUN                       #
# ##################################################

def generate_all(cfg: Config, source_path: str = DEFAULT_SOURCE, verbose: bool = True) -> Dict[str, pd.DataFrame]:
    """Generates every table in memory, in dependency order."""
    t0 = time.time()
    rng = np.random.default_rng(cfg.seed)

    def log(msg):
        if verbose:
            print(f'[{time.time() - t0:6.1f}s] {msg}')

    src = load_source(source_path)
    munis = coffee_municipalities(src)
    veredas = veredas_by_municipality(src)
    log(f'source loaded: {len(munis)} coffee municipalities, {len(veredas)} with veredas')

    data = {}
    data['departments'] = gen_departments(src)
    data['municipalities'] = gen_municipalities(src)
    data['coffee_varieties'] = gen_coffee_varieties(src)
    data['certifications'] = gen_certifications(src)
    data['collection_points'] = gen_collection_points(cfg, src, rng, munis)
    data['daily_prices'] = gen_daily_prices(cfg, rng, data['collection_points'])
    log(f"catalogs, {len(data['collection_points'])} points, {len(data['daily_prices']):,} daily prices")
    data['farmers'] = gen_farmers(cfg, src, rng, munis)
    data['farms'] = gen_farms(cfg, src, rng, data['farmers'], munis, veredas)
    log(f"{len(data['farmers']):,} farmers, {len(data['farms']):,} farms")
    data['plots'] = gen_plots(cfg, rng, data['farms'])
    data['plot_varieties'] = gen_plot_varieties(cfg, rng, data['plots'], data['coffee_varieties'])
    data['farm_certifications'] = gen_farm_certifications(cfg, rng, data['farms'], data['certifications'])
    log(f"{len(data['plots']):,} plots, {len(data['plot_varieties']):,} plot varieties, "
        f"{len(data['farm_certifications']):,} farm certifications")
    data['deliveries'] = gen_deliveries(cfg, rng, data['farms'], data['collection_points'], munis)
    data['quality_analyses'] = gen_quality_analyses(cfg, src, rng, data['deliveries'])
    data['settlements'] = gen_settlements(cfg, rng, data['deliveries'], data['quality_analyses'],
                                          data['daily_prices'], data['collection_points'],
                                          data['farm_certifications'], data['certifications'])
    data['payments'] = gen_payments(cfg, rng, data['settlements'])
    finalize_delivery_status(data['deliveries'], data['quality_analyses'], data['settlements'])
    log(f"{len(data['deliveries']):,} deliveries, {len(data['quality_analyses']):,} analyses, "
        f"{len(data['settlements']):,} settlements, {len(data['payments']):,} payments")
    total = sum(len(data[k]) for _, _, _, k, _ in TABLES)
    log(f'TOTAL rows: {total:,}')
    return data


def write_all(cfg: Config, data: Dict[str, pd.DataFrame], output_dir: str = DEFAULT_OUTPUT,
              clean: bool = True, verbose: bool = True) -> pd.DataFrame:
    """Writes every table to SQL files and returns a summary."""
    os.makedirs(output_dir, exist_ok=True)
    if clean:
        for f in os.listdir(output_dir):
            if f.endswith('.sql'):
                os.remove(os.path.join(output_dir, f))
    summary = []
    for order, table, label, key, cols in TABLES:
        t = time.time()
        files = write_inserts(data[key], order, table, label, cols, output_dir,
                              cfg.rows_per_statement, cfg.rows_per_file)
        size = sum(os.path.getsize(f) for f in files) / 1024 ** 2
        summary.append({'table': table, 'rows': len(data[key]), 'files': len(files), 'size_mb': round(size, 1)})
        if verbose:
            print(f'  {table:<28} {len(data[key]):>10,} rows  {len(files):>3} file(s)  {size:8.1f} MB  ({time.time() - t:.1f}s)')
    write_reset_sequences(output_dir)
    df = pd.DataFrame(summary)
    if verbose:
        print(f"  {'TOTAL':<28} {df['rows'].sum():>10,} rows  {df['files'].sum():>3} files     {df['size_mb'].sum():8.1f} MB")
    return df


def main():
    parser = argparse.ArgumentParser(description='Coffee Coop synthetic data generator')
    parser.add_argument('--source', default=DEFAULT_SOURCE, help='Folder with the Excel catalogs (data/source)')
    parser.add_argument('--output', default=DEFAULT_OUTPUT, help='Folder for the SQL files (data/sql)')
    parser.add_argument('--scale', type=float, default=1.0, help='Multiplier of every volume (default 1.0 ~ 5M rows)')
    parser.add_argument('--seed', type=int, default=42, help='Random seed (same seed = same data)')
    parser.add_argument('--farmers', type=int, help='Base number of farmers (default 150000)')
    parser.add_argument('--deliveries', type=int, help='Base number of deliveries (default 650000)')
    parser.add_argument('--collection-points', type=int, help='Base number of collection points (default 180)')
    parser.add_argument('--start-date', help='First day of operation (default 2022-01-01)')
    parser.add_argument('--end-date', help='Last day of operation (default 2026-09-30)')
    parser.add_argument('--rows-per-statement', type=int, help='Rows per INSERT statement (default 1000)')
    parser.add_argument('--rows-per-file', type=int, help='Rows per SQL file (default 250000)')
    args = parser.parse_args()

    cfg = Config(seed=args.seed, scale=args.scale)
    for name in ['farmers', 'deliveries', 'collection_points', 'start_date', 'end_date',
                 'rows_per_statement', 'rows_per_file']:
        value = getattr(args, name)
        if value is not None:
            setattr(cfg, name, value)

    print('Config:', {k: v for k, v in asdict(cfg).items() if not isinstance(v, dict)})
    data = generate_all(cfg, args.source)
    print(f'Writing SQL files to {args.output}')
    write_all(cfg, data, args.output)
    print('✅ Done')


if __name__ == '__main__':
    main()
