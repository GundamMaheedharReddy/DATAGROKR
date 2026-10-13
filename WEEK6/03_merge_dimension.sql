-- 03_merge_dimension.sql : upsert staging -> dim_customer using MERGE (PG 15+)
SET search_path = shop;

MERGE INTO dim_customer AS d
USING (
    -- de-duplicate staging: keep one row per business key
    SELECT DISTINCT ON (customer_id) *
    FROM stg_customers
    ORDER BY customer_id
) AS s
ON d.customer_id = s.customer_id
WHEN MATCHED AND (d.full_name, d.email, d.city, d.segment)
              IS DISTINCT FROM (s.full_name, s.email, s.city, s.segment) THEN
    UPDATE SET full_name  = s.full_name,
               email      = s.email,
               city       = s.city,
               segment    = s.segment,
               updated_at = now()
WHEN NOT MATCHED THEN
    INSERT (customer_id, full_name, email, city, segment)
    VALUES (s.customer_id, s.full_name, s.email, s.city, s.segment);

-- Rows unchanged are skipped thanks to the IS DISTINCT FROM guard.
-- (PG 17+ bonus: add  WHEN NOT MATCHED BY SOURCE THEN UPDATE SET is_active = false
--  to soft-delete customers missing from the feed.)
SELECT count(*) AS dim_rows, count(*) FILTER (WHERE updated_at > created_at) AS updated_rows
FROM dim_customer;
