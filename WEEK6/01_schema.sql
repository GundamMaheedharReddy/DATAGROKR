-- 01_schema.sql : tables, range-partitioned fact table
DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;
SET search_path = shop;

-- ---------- Staging (landing zone, no constraints = fast COPY) ----------
CREATE TABLE stg_customers (
    customer_id int, full_name text, email text, city text, segment text
);
CREATE TABLE stg_sales (
    order_id int, order_date date, customer_id int,
    product_id int, quantity int, amount numeric(12,2), status text
);

-- ---------- Dimensions ----------
CREATE TABLE dim_customer (
    customer_key  int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   int  NOT NULL UNIQUE,          -- business key (MERGE joins on this)
    full_name     text NOT NULL,
    email         text,
    city          text,
    segment       text,
    is_active     boolean     NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE dim_product (
    product_id   int PRIMARY KEY,
    product_name text NOT NULL,
    category     text NOT NULL,
    unit_price   numeric(10,2) NOT NULL
);

-- ---------- Fact table: RANGE partitioned by month ----------
-- NOTE: PK on a partitioned table MUST include the partition key.
CREATE TABLE fact_sales (
    order_id     int           NOT NULL,
    order_date   date          NOT NULL,
    customer_key int           NOT NULL REFERENCES dim_customer(customer_key),
    product_id   int           NOT NULL REFERENCES dim_product(product_id),
    quantity     int           NOT NULL,
    amount       numeric(12,2) NOT NULL,
    status       text          NOT NULL,
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);

CREATE TABLE fact_sales_2026_07 PARTITION OF fact_sales FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE fact_sales_2026_08 PARTITION OF fact_sales FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE fact_sales_2026_09 PARTITION OF fact_sales FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE fact_sales_2026_10 PARTITION OF fact_sales FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE fact_sales_2026_11 PARTITION OF fact_sales FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
-- Catch-all so out-of-range rows never fail the load
CREATE TABLE fact_sales_default PARTITION OF fact_sales DEFAULT;
