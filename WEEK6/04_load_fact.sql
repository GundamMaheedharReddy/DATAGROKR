-- 04_load_fact.sql : staging -> partitioned fact (rows auto-route to partitions)
SET search_path = shop;

INSERT INTO fact_sales (order_id, order_date, customer_key, product_id, quantity, amount, status)
SELECT s.order_id, s.order_date, c.customer_key, s.product_id, s.quantity, s.amount, s.status
FROM stg_sales s
JOIN dim_customer c USING (customer_id)
ON CONFLICT (order_id, order_date) DO NOTHING;     -- safe to re-run

-- Rows per partition
SELECT tableoid::regclass AS partition, count(*) AS row_count, sum(amount) AS revenue
FROM fact_sales GROUP BY 1 ORDER BY 1;
