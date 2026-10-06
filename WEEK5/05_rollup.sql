-- =====================================================================
-- 05_rollup.sql  |  Subtotals & grand totals with GROUP BY ... WITH ROLLUP
-- GROUPING(col) = 1 when the NULL in that column is a rollup subtotal
-- =====================================================================
USE sales_dw;

-- R1. Year > Quarter > Category with subtotals and grand total
SELECT  CASE WHEN GROUPING(year_num)    = 1 THEN 'ALL YEARS'    ELSE year_num            END AS yr,
        CASE WHEN GROUPING(quarter_num) = 1 THEN 'All Quarters' ELSE CONCAT('Q',quarter_num) END AS qtr,
        CASE WHEN GROUPING(category)    = 1 THEN 'All Categories' ELSE category          END AS category,
        ROUND(SUM(net_amount),2) AS revenue
FROM (
    SELECT d.year_num, d.quarter_num, p.category, f.net_amount
    FROM fact_sales f
    JOIN dim_date d    ON d.date_key    = f.date_key
    JOIN dim_product p ON p.product_key = f.product_key
) s
GROUP BY year_num, quarter_num, category WITH ROLLUP
ORDER BY GROUPING(year_num), year_num,
         GROUPING(quarter_num), quarter_num,
         GROUPING(category), category;

-- R2. Region > State sales with subtotals (customer geography)
SELECT  IF(GROUPING(c.region)=1,'GRAND TOTAL',c.region)      AS region,
        IF(GROUPING(c.state)=1 AND GROUPING(c.region)=0,'Region subtotal',c.state) AS state,
        COUNT(DISTINCT f.order_id)                           AS orders,
        ROUND(SUM(f.net_amount),2)                           AS revenue
FROM fact_sales f
JOIN dim_customer c ON c.customer_key = f.customer_key
GROUP BY c.region, c.state WITH ROLLUP
ORDER BY GROUPING(c.region), c.region, GROUPING(c.state), c.state;

-- R3. Channel > Store with subtotals
SELECT  IF(GROUPING(s.channel)=1,'ALL CHANNELS',s.channel)   AS channel,
        IF(GROUPING(s.store_name)=1,'Channel subtotal',s.store_name) AS store,
        ROUND(SUM(f.net_amount),2)                           AS revenue,
        ROUND(SUM(f.discount_amount),2)                      AS discounts
FROM fact_sales f
JOIN dim_store s ON s.store_key = f.store_key
GROUP BY s.channel, s.store_name WITH ROLLUP
ORDER BY GROUPING(s.channel), s.channel, GROUPING(s.store_name), s.store_name;

-- R4. Percent-of-total using ROLLUP + window function
WITH cat AS (
    SELECT p.category, SUM(f.net_amount) AS revenue
    FROM fact_sales f JOIN dim_product p ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT category, ROUND(revenue,2) AS revenue,
       ROUND(100 * revenue / SUM(revenue) OVER (), 2) AS pct_of_total
FROM cat
ORDER BY revenue DESC;
