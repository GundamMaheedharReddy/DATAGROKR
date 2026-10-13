-- 06_queries_explain.sql : prove partition pruning + index usage
SET search_path = shop;
SET enable_seqscan = off;   -- tiny demo data: nudge planner so indexes show up

-- 1) PARTITION PRUNING: look for only fact_sales_2026_09 in the plan
EXPLAIN (COSTS OFF)
SELECT sum(amount) FROM fact_sales
WHERE order_date >= '2026-09-01' AND order_date < '2026-10-01';

-- 2) COMPOSITE INDEX: customer + date range
EXPLAIN (COSTS OFF)
SELECT order_id, order_date, amount FROM fact_sales
WHERE customer_key = 3 AND order_date >= '2026-08-01'
ORDER BY order_date DESC;

-- 3) PARTIAL INDEX: predicate must match the index WHERE clause
EXPLAIN (COSTS OFF)
SELECT order_id, amount FROM fact_sales
WHERE status = 'RETURNED' AND order_date >= '2026-10-01';

-- 4) Business query: revenue by city & category (completed only)
RESET enable_seqscan;
SELECT c.city, p.category, sum(f.amount) AS revenue, count(*) AS orders
FROM fact_sales f
JOIN dim_customer c USING (customer_key)
JOIN dim_product  p USING (product_id)
WHERE f.status = 'COMPLETED'
GROUP BY c.city, p.category
ORDER BY revenue DESC
LIMIT 10;
