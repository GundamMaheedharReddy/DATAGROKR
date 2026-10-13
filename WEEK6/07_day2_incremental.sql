-- 07_day2_incremental.sql : simulate the next day's feed (5 city changes, 3 email changes, 5 new)
SET search_path = shop;

TRUNCATE stg_customers;
\copy stg_customers FROM 'data/customers_day2.csv' WITH (FORMAT csv, HEADER true)

\i sql/03_merge_dimension.sql

-- Verify changes
SELECT customer_id, full_name, city, email, updated_at > created_at AS was_updated
FROM dim_customer WHERE customer_id <= 8 OR customer_id > 20 ORDER BY customer_id;
