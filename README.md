# my-cost-of-living

How do fuel price changes relate to staple grocery prices in Malaysia? This project builds a small analytics pipeline on open government data to explore that question: raw files are loaded into DuckDB, modelled with dbt, and prepared for a one-page dashboard.

Findings will be framed as "moves with / does not move with, at lag X", not as cause and effect.

> **Status:** ingestion and the staging layer are built and tested. Intermediate models, marts and the dashboard are in progress. See [Status](#status).

## Data sources

All data comes from Malaysia's open data portals (OpenDOSM / data.gov.my).

| Dataset | What it holds | Grain | Loaded as |
|---|---|---|---|
| PriceCatcher price observations | Retail prices of items at premises, one file per month | item, premise, date | `raw.pricecatcher_YYYY_MM` |
| PriceCatcher item lookup | Item name, unit, group, category | item | `raw.lookup_item` |
| PriceCatcher premise lookup | Premise name, address, type, state, district | premise | `raw.lookup_premise` |
| Weekly fuel prices | RON95, RON97, diesel and subsidised variants (RM per litre) | week, series type | `raw.fuelprice` |

Source files are Parquet, read directly over HTTPS from `storage.data.gov.my`. Price files cover January 2022 to the current month, roughly 2 to 3 million rows per month, and the latest month is partial until it closes. The data-quality checks below were run on January 2022 to October 2026.

## Architecture

```
OpenDOSM Parquet files
  -> Python ingestion (Jupyter notebook)
  -> DuckDB file (schema `raw`)
  -> dbt: staging -> intermediate -> marts
  -> marts exported to Parquet
  -> one-page dashboard
```

- **Ingestion:** Python and DuckDB. Each raw table gets two lineage columns at load time, `_loaded_at` and `_source_url`.
- **Transformation:** dbt with the dbt-duckdb adapter.
- **Staging:** light cleaning only (renames, union of monthly tables). Every row is kept.
- **Intermediate and marts:** judgement calls such as filtering fuel series, handling unknown keys, deduplication and unit parsing happen here, not in staging.

## Repository layout

```
my-cost-of-living/
  ingestion/
    ingestion_working.ipynb     load notebook
  dbt_project/
    models/staging/
      sources.yml               raw tables declared as dbt sources
      schema.yml                tests on staging models
      stg_fuelprice.sql
      stg_lookup_item.sql
      stg_lookup_premise.sql
      stg_pricecatcher.sql      union of all monthly price tables
    tests/
      assert_pricecatcher_grain_unique.sql   duplicate check on the price grain
    profiles.yml                local DuckDB profile
  raw_data/                     DuckDB file (not committed)
  requirements.txt
```

## How to run

Windows PowerShell, from the repository root:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

**1. Load the raw data.** Run the load cell in `ingestion/ingestion_working.ipynb`. The month range is set at the top of that cell.

**2. Build and test the staging layer.** Run dbt from inside `dbt_project` and always pass `--profiles-dir .` so dbt uses the project profile rather than a global one:

```powershell
cd dbt_project
dbt run --select staging --profiles-dir .
dbt test --select staging --profiles-dir .
```

DuckDB allows one read-write connection at a time. Close any open notebook connection before running dbt.

## How the load works

The load is incremental and safe to re-run.

- **Closed months are skipped** if their table already exists, so a re-run does not download them again.
- **The latest loaded month is always reloaded**, because it may have been partial at the time of the previous run.
- **Lookup tables and fuel prices are reloaded on every run**, because they are small snapshots that change over time.
- **A month that is not published yet** (HTTP 404) is skipped. Any other error stops the run.
- A `FORCE_RELOAD` switch reloads every month, for the case where a past file is revised at the source.

`stg_pricecatcher` finds the monthly raw tables at run time and unions them, so a new month needs no change to the model. Each new month does need an entry in `sources.yml`.

## Data quality notes

These were found while loading and testing the staging layer. Staging keeps all rows; the handling below applies in later layers.

**Placeholder keys (`-1`).** Both lookup tables contain a `-1` row ("Unknown Premise" and an item with no attributes), with null state, district and category fields. Across January 2022 to October 2026, PriceCatcher uses `-1` in 157 rows: 1 unknown item (June 2022) and 156 unknown premises (October 2022 to August 2023). These rows are valid prices without a known premise, so they stay in the data. In the dimension models, null attributes will be shown as `Unknown`, so unknown-premise prices group under an "Unknown" state instead of disappearing.

**Item codes missing from the item lookup.** 44 item codes that appear in price data are absent from `lookup_item`, even though the lookup covers codes up to 2115 and lists items on both sides of the gaps. They account for about 1.4 million price rows (roughly 1% of all rows), all from late December 2023 onward. Some of these items are still being priced in the latest data. The gap is in the published lookup, not in this pipeline. Until names and categories are available, these rows are kept and labelled by code (`Unknown item <code>`), so they remain traceable. Any analysis by item or category from 2024 onward excludes the category detail for these rows.

**Premise code missing from the premise lookup.** One code (20927) is missing, in 273 rows between 5 and 19 February 2024.

**Missing days in PriceCatcher.** 44 of the 58 months from January 2022 to October 2026 have at least one calendar day with no price rows: about 102 missing days out of roughly 1,765, or 6%. Most months miss one to three days. The largest gaps are October 2026 (the file starts on 10 October, so 1 to 9 October are missing), May 2023 and December 2023 (7 days each) and March 2026 (6 days). Some gaps fall in public holiday periods, but this has not been checked against a holiday calendar. The gaps are in the published files, so they are not filled in. Intended handling in the marts: average prices over the days observed, and keep the number of days observed next to each weekly or monthly figure so partial periods are visible.

**Duplicate rows.** 20,613 combinations of date, premise and item appear twice in PriceCatcher (41,226 rows, about 0.03% of the data). In every case the two rows are exact repeats: the same price, from the same monthly file. Staging keeps them. The intermediate layer is planned to keep one row per combination.

**Fuel price grain.** `fuelprice` holds two series per date, `level` and `change_weekly`, so every date appears twice. Models that need prices must filter to `level`. Subsidised price columns are null in earlier years, so comparisons use the market `diesel` and `ron95` columns.

**Text fields.** Item names are uppercase Malay with some stray symbols. `unit` is free text such as `1kg`. State names are not spelled consistently between `state` and `district` (for example `W.P. Putrajaya` and `Wp Putrajaya`), so distinct values need checking before grouping by state.

## Tests

Staging models are covered by dbt tests (`dbt_project/models/staging/schema.yml`):

- **Not null** on keys, dates, prices and the lineage columns.
- **Unique** on `premise_code` and `item_code` in the lookups.
- **Accepted values** on the fuel `series_type`.
- **Relationships** from price rows to the item and premise lookups, excluding `-1`.
- **Grain:** a singular test (`tests/assert_pricecatcher_grain_unique.sql`) reports duplicate date, premise and item combinations.

The two relationship tests and the grain test are set to warn, not fail. They report the known lookup gaps and duplicates described above, so that these stay visible without blocking the build. A sudden increase in any of the three counts would be worth investigating.

## Status

- [x] Raw load into DuckDB for PriceCatcher (January 2022 to November 2026, latest month partial), lookups and fuel prices
- [x] Incremental load with lineage columns
- [x] Staging models and sources
- [x] dbt tests on staging
- [ ] Intermediate models: fuel `level` series, daily fuel price in effect, deduplication, outlier rule, unit parsing
- [ ] Marts and reconciliation tests, export to Parquet
- [ ] Dashboard
- [ ] Lineage graph and data model diagram in this README
- [ ] Source names for the missing item codes
- [ ] Orchestration with Airflow, after the first version is complete
- [ ] State-level cost of living (CPI, wages, income), as a second phase

## Data credits

Price, lookup and fuel price data are published by the Department of Statistics Malaysia (OpenDOSM) and Malaysia's open data portal, data.gov.my. See each dataset's page on those sites for licence terms.