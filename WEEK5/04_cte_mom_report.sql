-- =====================================================================
-- 04_cte_mom_report.sql  |  Month-over-Month report using CTEs
-- =====================================================================
USE sales_dw;

-- Report 1: Overall MoM revenue, orders and growth %
WITH monthly AS (
    SELECT  d.yr_month,
            SUM(f.net_amount)             AS revenue,
            COUNT(DISTINCT f.order_id)    AS orders,
            SUM(f.quantity)               AS units
    FROM fact_sales f
    JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.yr_month
),
with_prev AS (
    SELECT  yr_month, revenue, orders, units,
            LAG(revenue) OVER (ORDER BY yr_month) AS prev_revenue
    FROM monthly
)
SELECT  yr_month,
        ROUND(revenue,2)                                   AS revenue,
        orders,
        units,
        ROUND(revenue - prev_revenue,2)                    AS mom_change,
        ROUND(100 * (revenue - prev_revenue) / prev_revenue, 2) AS mom_pct,
        CASE WHEN prev_revenue IS NULL        THEN 'n/a'
             WHEN revenue > prev_revenue      THEN 'UP'
             WHEN revenue < prev_revenue      THEN 'DOWN'
             ELSE 'FLAT' END                               AS trend
FROM with_prev
ORDER BY yr_month;

-- Report 2: MoM by category (partitioned LAG)
WITH cat_monthly AS (
    SELECT d.yr_month, p.category, SUM(f.net_amount) AS revenue
    FROM fact_sales f
    JOIN dim_date d    ON d.date_key    = f.date_key
    JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY d.yr_month, p.category
)
SELECT  yr_month, category,
        ROUND(revenue,2) AS revenue,
        ROUND(100 * (revenue - LAG(revenue) OVER (PARTITION BY category ORDER BY yr_month))
              / LAG(revenue) OVER (PARTITION BY category ORDER BY yr_month), 2) AS mom_pct
FROM cat_monthly
ORDER BY category, yr_month;

-- Report 3: Year-over-Year for the same month (LAG with offset 12)
WITH monthly AS (
    SELECT d.yr_month, SUM(f.net_amount) AS revenue
    FROM fact_sales f JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.yr_month
)
SELECT yr_month,
       ROUND(revenue,2) AS revenue,
       ROUND(LAG(revenue,12) OVER (ORDER BY yr_month),2) AS same_month_last_year,
       ROUND(100 * (revenue - LAG(revenue,12) OVER (ORDER BY yr_month))
             / LAG(revenue,12) OVER (ORDER BY yr_month), 2) AS yoy_pct
FROM monthly
ORDER BY yr_month;

-- Report 4: Best and worst growth months (chained CTEs)
WITH monthly AS (
    SELECT d.yr_month, SUM(f.net_amount) AS revenue
    FROM fact_sales f JOIN dim_date d ON d.date_key = f.date_key
    GROUP BY d.yr_month
),
growth AS (
    SELECT yr_month, revenue,
           100 * (revenue - LAG(revenue) OVER (ORDER BY yr_month))
               / LAG(revenue) OVER (ORDER BY yr_month) AS mom_pct
    FROM monthly
),
ranked AS (
    SELECT *, RANK() OVER (ORDER BY mom_pct DESC) AS best_rank,
              RANK() OVER (ORDER BY mom_pct ASC)  AS worst_rank
    FROM growth
    WHERE mom_pct IS NOT NULL
)
SELECT 'Best'  AS label, yr_month, ROUND(mom_pct,2) AS mom_pct FROM ranked WHERE best_rank  <= 3
UNION ALL
SELECT 'Worst' AS label, yr_month, ROUND(mom_pct,2) AS mom_pct FROM ranked WHERE worst_rank <= 3;
