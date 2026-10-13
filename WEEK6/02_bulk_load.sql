-- 02_bulk_load.sql : COPY (client-side \copy) CSV -> staging / dimension
-- Run from the project ROOT so relative paths resolve.
SET search_path = shop;

\copy dim_product(product_id, product_name, category, unit_price) FROM 'data/products.csv' WITH (FORMAT csv, HEADER true)
\copy stg_sales FROM 'data/sales.csv' WITH (FORMAT csv, HEADER true)

-- Day 1 customers
TRUNCATE stg_customers;
\copy stg_customers FROM 'data/customers_day1.csv' WITH (FORMAT csv, HEADER true)

SELECT 'stg_customers' AS tbl, count(*) FROM stg_customers
UNION ALL SELECT 'stg_sales', count(*) FROM stg_sales
UNION ALL SELECT 'dim_product', count(*) FROM dim_product;
