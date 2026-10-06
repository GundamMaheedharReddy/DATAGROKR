-- =====================================================================
-- 06_explain_optimization.sql  |  Reading EXPLAIN and tuning queries
-- Run each block, compare: type, key, rows, Extra (and EXPLAIN ANALYZE timings)
-- =====================================================================
USE sales_dw;
ANALYZE TABLE fact_sales, dim_date, dim_product, dim_customer, dim_store;

-- ---------------------------------------------------------------------
-- STEP 1: BAD query  (function on indexed column => non-sargable)
-- ---------------------------------------------------------------------
EXPLAIN
SELECT p.category, SUM(f.net_amount) AS revenue
FROM fact_sales f
JOIN dim_date d    ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
WHERE YEAR(d.full_date) = 2026 AND MONTH(d.full_date) BETWEEN 1 AND 3
GROUP BY p.category;

-- ---------------------------------------------------------------------
-- STEP 2: GOOD query (range predicate => index on full_date usable)
-- ---------------------------------------------------------------------
EXPLAIN
SELECT p.category, SUM(f.net_amount) AS revenue
FROM fact_sales f
JOIN dim_date d    ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
WHERE d.full_date >= '2026-01-01' AND d.full_date < '2026-04-01'
GROUP BY p.category;

-- ---------------------------------------------------------------------
-- STEP 3: Filter on a column with NO index (order_id) => full table scan
-- ---------------------------------------------------------------------
EXPLAIN SELECT * FROM fact_sales WHERE order_id = 'ORD-002500';   -- type = ALL

CREATE INDEX idx_fact_order ON fact_sales (order_id);

EXPLAIN SELECT * FROM fact_sales WHERE order_id = 'ORD-002500';   -- type = ref

-- ---------------------------------------------------------------------
-- STEP 4: Covering composite index (index-only scan, "Using index")
-- ---------------------------------------------------------------------
EXPLAIN
SELECT product_key, SUM(net_amount) AS revenue, SUM(quantity) AS units
FROM fact_sales
WHERE date_key BETWEEN 20260101 AND 20260331
GROUP BY product_key;

CREATE INDEX idx_fact_cover ON fact_sales (date_key, product_key, net_amount, quantity);

EXPLAIN
SELECT product_key, SUM(net_amount) AS revenue, SUM(quantity) AS units
FROM fact_sales
WHERE date_key BETWEEN 20260101 AND 20260331
GROUP BY product_key;

-- ---------------------------------------------------------------------
-- STEP 5: EXPLAIN ANALYZE / FORMAT=TREE (actual timings + row counts)
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT d.yr_month, p.category, SUM(f.net_amount) AS revenue
FROM fact_sales f
JOIN dim_date d    ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
WHERE d.year_num = 2026
GROUP BY d.yr_month, p.category;

EXPLAIN FORMAT=TREE
SELECT c.region, SUM(f.net_amount)
FROM fact_sales f JOIN dim_customer c ON c.customer_key = f.customer_key
GROUP BY c.region;

-- ---------------------------------------------------------------------
-- STEP 6: Pre-aggregated summary table for dashboards
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS agg_monthly_category;
CREATE TABLE agg_monthly_category AS
SELECT d.yr_month, p.category,
       SUM(f.net_amount) AS revenue,
       SUM(f.quantity)   AS units,
       COUNT(DISTINCT f.order_id) AS orders
FROM fact_sales f
JOIN dim_date d    ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY d.yr_month, p.category;

ALTER TABLE agg_monthly_category ADD PRIMARY KEY (yr_month, category);

EXPLAIN SELECT * FROM agg_monthly_category WHERE yr_month = '2026-03';

-- ---------------------------------------------------------------------
-- Cleanup (optional): remove demo indexes
-- ---------------------------------------------------------------------
-- DROP INDEX idx_fact_order ON fact_sales;
-- DROP INDEX idx_fact_cover ON fact_sales;
