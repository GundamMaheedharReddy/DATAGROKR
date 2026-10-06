-- =====================================================================
-- 03_window_rankings.sql  |  Window function rankings
-- =====================================================================
USE sales_dw;

-- Q1. RANK vs DENSE_RANK vs ROW_NUMBER: product revenue overall
SELECT  p.product_name,
        p.category,
        ROUND(SUM(f.net_amount),2)                              AS revenue,
        RANK()       OVER (ORDER BY SUM(f.net_amount) DESC)     AS rnk,
        DENSE_RANK() OVER (ORDER BY SUM(f.net_amount) DESC)     AS dense_rnk,
        ROW_NUMBER() OVER (ORDER BY SUM(f.net_amount) DESC)     AS row_num
FROM fact_sales f
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.product_key, p.product_name, p.category
ORDER BY rnk;

-- Q2. Top 2 products in EACH category (PARTITION BY)
WITH product_rev AS (
    SELECT p.category, p.product_name, SUM(f.net_amount) AS revenue
    FROM fact_sales f
    JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT category, product_name, ROUND(revenue,2) AS revenue,
           RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
    FROM product_rev
)
SELECT * FROM ranked
WHERE rank_in_category <= 2
ORDER BY category, rank_in_category;

-- Q3. Top 3 customers per region + share of regional revenue
WITH cust_rev AS (
    SELECT c.region, c.customer_name, SUM(f.net_amount) AS revenue
    FROM fact_sales f
    JOIN dim_customer c ON c.customer_key = f.customer_key
    GROUP BY c.region, c.customer_key, c.customer_name
)
SELECT region, customer_name, ROUND(revenue,2) AS revenue, rn,
       ROUND(100 * revenue / region_total, 2) AS pct_of_region
FROM (
    SELECT region, customer_name, revenue,
           ROW_NUMBER() OVER (PARTITION BY region ORDER BY revenue DESC) AS rn,
           SUM(revenue)  OVER (PARTITION BY region)                      AS region_total
    FROM cust_rev
) t
WHERE rn <= 3
ORDER BY region, rn;

-- Q4. Customer quartiles with NTILE (1 = top 25% spenders)
SELECT customer_name, ROUND(revenue,2) AS revenue,
       NTILE(4) OVER (ORDER BY revenue DESC) AS spend_quartile
FROM (
    SELECT c.customer_name, SUM(f.net_amount) AS revenue
    FROM fact_sales f
    JOIN dim_customer c ON c.customer_key = f.customer_key
    GROUP BY c.customer_key, c.customer_name
) x
ORDER BY revenue DESC;

-- Q5. Running total + 3-month moving average + share of year
SELECT  yr_month,
        ROUND(monthly_rev,2) AS monthly_rev,
        ROUND(SUM(monthly_rev) OVER (ORDER BY yr_month
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) AS running_total,
        ROUND(AVG(monthly_rev) OVER (ORDER BY yr_month
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2)         AS moving_avg_3m
FROM (
    SELECT d.yr_month, SUM(f.net_amount) AS monthly_rev
    FROM fact_sales f
    JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.yr_month
) m
ORDER BY yr_month;

-- Q6. LAG / LEAD: compare each month with previous and next month
SELECT  yr_month,
        ROUND(monthly_rev,2)                        AS revenue,
        ROUND(LAG(monthly_rev)  OVER w,2)           AS prev_month,
        ROUND(LEAD(monthly_rev) OVER w,2)           AS next_month
FROM (
    SELECT d.yr_month, SUM(f.net_amount) AS monthly_rev
    FROM fact_sales f JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.yr_month
) m
WINDOW w AS (ORDER BY yr_month)
ORDER BY yr_month;

-- Q7. Best-selling product of each month (rank inside month)
WITH monthly_product AS (
    SELECT d.yr_month, p.product_name, SUM(f.net_amount) AS revenue
    FROM fact_sales f
    JOIN dim_date d    ON d.date_key    = f.date_key
    JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY d.yr_month, p.product_name
)
SELECT yr_month, product_name, ROUND(revenue,2) AS revenue
FROM (
    SELECT *, RANK() OVER (PARTITION BY yr_month ORDER BY revenue DESC) AS rnk
    FROM monthly_product
) r
WHERE rnk = 1
ORDER BY yr_month;
