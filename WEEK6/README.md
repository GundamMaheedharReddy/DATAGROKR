# SQL DE Pipeline — Week 6 Mini Project

A small **retail data-warehouse pipeline** in PostgreSQL that practises the four Week 6 topics:

| Topic | Where it is used |
|---|---|
| **MERGE on a dimension table** | `sql/03_merge_dimension.sql` – upserts `dim_customer` from a daily feed |
| **Range partitioning** | `sql/01_schema.sql` – `fact_sales` partitioned by month on `order_date` |
| **COPY bulk load** | `sql/02_bulk_load.sql` – CSV → staging via `\copy` |
| **Composite & partial indexes** | `sql/05_indexes.sql` – tuned for the common queries |

## Architecture

```
 CSV files ──\copy──▶ stg_customers ──MERGE──▶ dim_customer ─┐
 (data/)                                                      ├──▶ fact_sales (partitioned by month)
 CSV files ──\copy──▶ stg_sales ───────INSERT…SELECT────────┘        ├─ 2026_07 … 2026_11
                                                dim_product ◀─COPY    └─ default
```

## Requirements

* PostgreSQL **15 or newer** (`MERGE` was added in 15)
* `psql` client

## Quick start

```bash
createdb de_pipeline
psql -d de_pipeline -f run_all.sql      # run from the project root
```

Run from the project root — the `\copy` paths (`data/…`) are relative.

Or step by step:

```bash
psql -d de_pipeline -f sql/01_schema.sql
psql -d de_pipeline -f sql/02_bulk_load.sql
psql -d de_pipeline -f sql/03_merge_dimension.sql
psql -d de_pipeline -f sql/04_load_fact.sql
psql -d de_pipeline -f sql/05_indexes.sql
psql -d de_pipeline -f sql/06_queries_explain.sql
psql -d de_pipeline -f sql/07_day2_incremental.sql
```

## Project structure

```
sql-de-pipeline/
├── README.md
├── run_all.sql
├── data/
│   ├── products.csv          8 products
│   ├── customers_day1.csv    20 customers (initial load)
│   ├── customers_day2.csv    25 customers (8 changed + 5 new)
│   └── sales.csv             400 orders, Jul–Oct 2026 (+5 in 2027)
└── sql/
    ├── 01_schema.sql         schema, staging, dims, partitioned fact
    ├── 02_bulk_load.sql      COPY into staging
    ├── 03_merge_dimension.sql MERGE upsert
    ├── 04_load_fact.sql      staging → fact (auto-routed to partitions)
    ├── 05_indexes.sql        composite + partial indexes
    ├── 06_queries_explain.sql EXPLAIN proofs + business query
    └── 07_day2_incremental.sql second-day feed to test MERGE
```

## Concepts explained

### 1. COPY bulk load
`COPY` is far faster than row-by-row `INSERT`. We load into **unconstrained staging tables** first, so a bad row never blocks the load and cleansing can happen in SQL. `\copy` is the client-side version (reads the file on your machine); plain `COPY` reads from the *server's* filesystem and needs privileges.

### 2. MERGE on a dimension
```sql
MERGE INTO dim_customer d USING (...) s ON d.customer_id = s.customer_id
WHEN MATCHED AND (…) IS DISTINCT FROM (…) THEN UPDATE …
WHEN NOT MATCHED THEN INSERT …
```
* Matches on the **business key** (`customer_id`), not the surrogate key.
* The `IS DISTINCT FROM` guard (NULL-safe) skips unchanged rows, so `updated_at` only changes when data really changed.
* The source is de-duplicated with `DISTINCT ON` — `MERGE` errors if two source rows match one target row.

### 3. Range partitioning
`fact_sales` is split into monthly partitions by `order_date`.
* **Partition pruning:** a query for September scans only `fact_sales_2026_09`.
* **Maintenance:** drop or archive an old month instantly with `DROP TABLE` / `DETACH PARTITION` instead of a huge `DELETE`.
* A **DEFAULT partition** catches out-of-range dates (the five 2027 rows land there).
* The primary key must include the partition key → `(order_id, order_date)`.

### 4. Composite & partial indexes
| Index | Type | Serves |
|---|---|---|
| `(customer_key, order_date DESC)` | Composite | "orders for customer X since date Y, newest first" — equality column first, range/sort column second |
| `(order_date) WHERE status='RETURNED'` | Partial | returns analysis; index covers only ~8 % of rows |
| `(customer_key) WHERE status='PENDING'` | Partial | open-order follow-ups |
| `UNIQUE (email) WHERE is_active` | Partial unique | one active customer per email, while inactive rows may repeat |

A partial index is only used when the query's `WHERE` implies the index predicate.

## Expected results

* After day 1: `MERGE 20`, 400 fact rows → 95 / 102 / 95 / 103 across Jul–Oct partitions, 5 in `default`.
* After day 2: `MERGE 13` (8 updates + 5 inserts), `dim_customer` has 25 rows.
* `EXPLAIN` output in `06` shows only the relevant partitions scanned and the new indexes used.

## Try it yourself (extensions)

1. Add a **Type-2 SCD** (`valid_from`, `valid_to`, `is_current`) instead of overwriting history.
2. On PG 17+, add `WHEN NOT MATCHED BY SOURCE THEN UPDATE SET is_active = false` to soft-delete missing customers.
3. Create a `2026_12` partition, then `DETACH` and archive `2026_07`.
4. Compare `EXPLAIN ANALYZE` for a query with and without each index; compare `COPY` vs. 400 single `INSERT`s using `\timing`.
5. Add a `v_monthly_revenue` view or materialized view and a `CHECK` constraint on `status`.
