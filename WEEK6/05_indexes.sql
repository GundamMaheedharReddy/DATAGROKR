-- 05_indexes.sql : composite + partial indexes
SET search_path = shop;

-- Composite: customer history queries (equality on customer, range/sort on date).
-- Column order matters: equality column FIRST, range/sort column SECOND.
CREATE INDEX idx_fact_cust_date ON fact_sales (customer_key, order_date DESC);

-- Partial: only index the small "problem" subset (~8% of rows).
CREATE INDEX idx_fact_returned ON fact_sales (order_date) WHERE status = 'RETURNED';
CREATE INDEX idx_fact_pending  ON fact_sales (customer_key) WHERE status = 'PENDING';

-- Partial on dimension: fast lookup of active customers by email.
CREATE UNIQUE INDEX idx_dim_cust_email_active ON dim_customer (email) WHERE is_active;

ANALYZE;

-- List what we created (parent indexes on a partitioned table are "virtual";
-- each partition gets its own physical child index).
SELECT tablename, indexname FROM pg_indexes
WHERE schemaname = 'shop' AND tablename IN ('fact_sales', 'dim_customer')
ORDER BY tablename, indexname;
