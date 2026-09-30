-- =====================================================================
--  SQL E-commerce Report  |  03_queries.sql   (50 queries)
--  Business rule: "valid sales" = orders with status Shipped or Delivered.
--  Cancelled, Returned and Pending orders are excluded from revenue.
--  Net revenue = SUM(quantity * unit_price) * (1 - discount_pct/100)
--  (available through the view v_order_summary).
-- =====================================================================
USE ecommerce_db;

-- #####################################################################
-- SECTION 1: BASIC SELECT, FILTERING, SORTING  (Q1 - Q5)
-- #####################################################################

-- Q1. All active products, most expensive first
SELECT product_id, product_name, price
FROM   products
WHERE  is_active = 1
ORDER  BY price DESC;

-- Q2. Customers from Karnataka or Maharashtra who signed up in Q1 2025
SELECT customer_id, CONCAT(first_name, ' ', last_name) AS customer_name, state, signup_date
FROM   customers
WHERE  state IN ('Karnataka', 'Maharashtra')
  AND  signup_date BETWEEN '2025-01-01' AND '2025-03-31';

-- Q3. Pattern matching: products with 'Book' or 'Shoes' in the name
SELECT product_id, product_name, price
FROM   products
WHERE  product_name LIKE '%Book%' OR product_name LIKE '%Shoes%';

-- Q4. Top 5 most expensive products (LIMIT)
SELECT product_name, price
FROM   products
ORDER  BY price DESC
LIMIT  5;

-- Q5. Distinct state / city combinations our customers come from
SELECT DISTINCT state, city
FROM   customers
ORDER  BY state, city;

-- #####################################################################
-- SECTION 2: NULL HANDLING  (Q6 - Q13)
-- #####################################################################

-- Q6. Customers who have not given a phone number (IS NULL, never = NULL)
SELECT customer_id, first_name, last_name, email
FROM   customers
WHERE  phone IS NULL;

-- Q7. COALESCE: show a readable placeholder instead of NULL
SELECT customer_id,
       CONCAT(first_name, ' ', last_name) AS customer_name,
       COALESCE(phone, 'Not provided')    AS phone_display
FROM   customers;

-- Q8. IFNULL on shipping city, flagging incomplete orders
SELECT order_id, customer_id, status,
       IFNULL(shipping_city, 'ADDRESS MISSING') AS ship_to
FROM   orders
ORDER  BY (shipping_city IS NULL) DESC, order_id;

-- Q9. Products with no supplier (NULL FK) next to their supplier name otherwise
SELECT p.product_id, p.product_name,
       COALESCE(s.supplier_name, 'No supplier assigned') AS supplier
FROM   products p
LEFT   JOIN suppliers s ON s.supplier_id = p.supplier_id
ORDER  BY (p.supplier_id IS NULL) DESC, p.product_id;

-- Q10. COUNT(*) counts rows, COUNT(col) ignores NULLs
SELECT COUNT(*)                 AS total_customers,
       COUNT(phone)             AS with_phone,
       COUNT(*) - COUNT(phone)  AS without_phone
FROM   customers;

-- Q11. NULLIF avoids divide-by-zero: profit margin % per product
SELECT product_name, price, cost,
       ROUND((price - cost) / NULLIF(price, 0) * 100, 2) AS margin_pct
FROM   products
ORDER  BY margin_pct DESC;

-- Q12. The NOT IN + NULL trap: suppliers that supply no products
--      (a) WRONG: returns 0 rows, because products.supplier_id contains a NULL
SELECT supplier_id, supplier_name
FROM   suppliers
WHERE  supplier_id NOT IN (SELECT supplier_id FROM products);

--      (b) RIGHT: NOT EXISTS is NULL-safe and finds 'Sparkle Toys'
SELECT s.supplier_id, s.supplier_name
FROM   suppliers s
WHERE  NOT EXISTS (SELECT 1 FROM products p WHERE p.supplier_id = s.supplier_id);

-- Q13. CASE + NULL: label payments by whether money has been received
SELECT payment_id, order_id, payment_method, payment_status,
       CASE WHEN payment_date IS NULL THEN 'Awaiting payment'
            ELSE CONCAT('Paid on ', payment_date)
       END AS payment_note
FROM   payments;

-- #####################################################################
-- SECTION 3: AGGREGATION, GROUP BY, HAVING  (Q14 - Q21)
-- #####################################################################

-- Q14. Total net revenue from valid sales
SELECT ROUND(SUM(net_amount), 2) AS total_revenue,
       COUNT(*)                  AS orders_counted,
       ROUND(AVG(net_amount), 2) AS avg_order_value
FROM   v_order_summary
WHERE  status IN ('Shipped', 'Delivered');

-- Q15. Monthly revenue trend
SELECT DATE_FORMAT(order_date, '%Y-%m') AS order_month,
       COUNT(*)                         AS orders,
       ROUND(SUM(net_amount), 2)        AS revenue
FROM   v_order_summary
WHERE  status IN ('Shipped', 'Delivered')
GROUP  BY DATE_FORMAT(order_date, '%Y-%m')
ORDER  BY order_month;

-- Q16. Orders by status
SELECT status, COUNT(*) AS order_count
FROM   orders
GROUP  BY status
ORDER  BY order_count DESC;

-- Q17. Average order value by customer city
SELECT c.city,
       COUNT(*)                    AS orders,
       ROUND(AVG(s.net_amount), 2) AS avg_order_value
FROM   v_order_summary s
JOIN   customers c ON c.customer_id = s.customer_id
WHERE  s.status IN ('Shipped', 'Delivered')
GROUP  BY c.city
ORDER  BY avg_order_value DESC;

-- Q18. Revenue by product category (line-level, before order discount)
SELECT cat.category_name,
       SUM(oi.quantity)                     AS units_sold,
       SUM(oi.quantity * oi.unit_price)     AS gross_revenue
FROM   order_items oi
JOIN   orders     o   ON o.order_id    = oi.order_id
JOIN   products   p   ON p.product_id  = oi.product_id
JOIN   categories cat ON cat.category_id = p.category_id
WHERE  o.status IN ('Shipped', 'Delivered')
GROUP  BY cat.category_id, cat.category_name
ORDER  BY gross_revenue DESC;

-- Q19. Payment method popularity and value
SELECT payment_method,
       COUNT(*)              AS payments,
       SUM(amount)           AS total_amount,
       ROUND(AVG(amount), 2) AS avg_amount
FROM   payments
WHERE  payment_status = 'Completed'
GROUP  BY payment_method
ORDER  BY total_amount DESC;

-- Q20. HAVING: only categories with more than Rs. 10,000 gross revenue
SELECT cat.category_name, SUM(oi.quantity * oi.unit_price) AS gross_revenue
FROM   order_items oi
JOIN   orders     o   ON o.order_id    = oi.order_id
JOIN   products   p   ON p.product_id  = oi.product_id
JOIN   categories cat ON cat.category_id = p.category_id
WHERE  o.status IN ('Shipped', 'Delivered')
GROUP  BY cat.category_id, cat.category_name
HAVING SUM(oi.quantity * oi.unit_price) > 10000;

-- Q21. Cancellation + return rate (boolean expressions sum to 1/0 in MySQL)
SELECT COUNT(*)                                                   AS total_orders,
       SUM(status IN ('Cancelled', 'Returned'))                   AS lost_orders,
       ROUND(SUM(status IN ('Cancelled', 'Returned')) / COUNT(*) * 100, 2) AS lost_pct
FROM   orders;

-- #####################################################################
-- SECTION 4: JOINS  (Q22 - Q30)
-- #####################################################################

-- Q22. INNER JOIN: full order detail (customer, product, line total)
SELECT o.order_id, o.order_date,
       CONCAT(c.first_name, ' ', c.last_name) AS customer,
       p.product_name, oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price            AS line_total
FROM   orders o
JOIN   customers   c  ON c.customer_id = o.customer_id
JOIN   order_items oi ON oi.order_id   = o.order_id
JOIN   products    p  ON p.product_id  = oi.product_id
ORDER  BY o.order_id, p.product_name;

-- Q23. LEFT JOIN anti-join: customers who never placed an order
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer, c.signup_date
FROM   customers c
LEFT   JOIN orders o ON o.customer_id = c.customer_id
WHERE  o.order_id IS NULL;

-- Q24. Products that have never been ordered
SELECT p.product_id, p.product_name, p.stock_qty
FROM   products p
LEFT   JOIN order_items oi ON oi.product_id = p.product_id
WHERE  oi.order_item_id IS NULL;

-- Q25. Categories with no products
SELECT cat.category_id, cat.category_name
FROM   categories cat
LEFT   JOIN products p ON p.category_id = cat.category_id
WHERE  p.product_id IS NULL;

-- Q26. Product catalogue with category and supplier (two LEFT JOINs)
SELECT p.product_name, cat.category_name,
       COALESCE(s.supplier_name, '-') AS supplier, p.price
FROM   products p
JOIN   categories cat ON cat.category_id = p.category_id
LEFT   JOIN suppliers s ON s.supplier_id = p.supplier_id
ORDER  BY cat.category_name, p.product_name;

-- Q27. SELF JOIN: who referred whom
SELECT CONCAT(c.first_name, ' ', c.last_name) AS customer,
       COALESCE(CONCAT(r.first_name, ' ', r.last_name), 'Organic signup') AS referred_by
FROM   customers c
LEFT   JOIN customers r ON r.customer_id = c.referred_by
ORDER  BY c.customer_id;

-- Q28. Multi-table join: what each customer bought, by category
SELECT CONCAT(c.first_name, ' ', c.last_name) AS customer,
       cat.category_name,
       SUM(oi.quantity)                        AS units,
       SUM(oi.quantity * oi.unit_price)        AS spend
FROM   customers c
JOIN   orders      o   ON o.customer_id  = c.customer_id
JOIN   order_items oi  ON oi.order_id    = o.order_id
JOIN   products    p   ON p.product_id   = oi.product_id
JOIN   categories  cat ON cat.category_id = p.category_id
WHERE  o.status IN ('Shipped', 'Delivered')
GROUP  BY c.customer_id, customer, cat.category_id, cat.category_name
ORDER  BY customer, spend DESC;

-- Q29. Market-basket: products most often bought together (self join on order_items)
SELECT p1.product_name AS product_a,
       p2.product_name AS product_b,
       COUNT(*)        AS times_bought_together
FROM   order_items a
JOIN   order_items b  ON b.order_id = a.order_id AND a.product_id < b.product_id
JOIN   products p1    ON p1.product_id = a.product_id
JOIN   products p2    ON p2.product_id = b.product_id
GROUP  BY p1.product_id, p1.product_name, p2.product_id, p2.product_name
ORDER  BY times_bought_together DESC, product_a;

-- Q30. FULL OUTER JOIN emulation (MySQL has none): LEFT JOIN UNION RIGHT JOIN
SELECT c.customer_id, c.first_name, o.order_id, o.order_date
FROM   customers c LEFT JOIN orders o ON o.customer_id = c.customer_id
UNION
SELECT c.customer_id, c.first_name, o.order_id, o.order_date
FROM   customers c RIGHT JOIN orders o ON o.customer_id = c.customer_id;

-- #####################################################################
-- SECTION 5: TOP PRODUCTS  (Q31 - Q36)
-- #####################################################################

-- Q31. Top 5 products by revenue
SELECT p.product_name,
       SUM(oi.quantity)                 AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM   order_items oi
JOIN   orders   o ON o.order_id   = oi.order_id
JOIN   products p ON p.product_id = oi.product_id
WHERE  o.status IN ('Shipped', 'Delivered')
GROUP  BY p.product_id, p.product_name
ORDER  BY revenue DESC
LIMIT  5;

-- Q32. Top 5 products by units sold
SELECT p.product_name, SUM(oi.quantity) AS units_sold
FROM   order_items oi
JOIN   orders   o ON o.order_id   = oi.order_id
JOIN   products p ON p.product_id = oi.product_id
WHERE  o.status IN ('Shipped', 'Delivered')
GROUP  BY p.product_id, p.product_name
ORDER  BY units_sold DESC, p.product_name
LIMIT  5;

-- Q33. Best-selling product in each category (window function RANK)
WITH category_sales AS (
    SELECT cat.category_name, p.product_name,
           SUM(oi.quantity) AS units_sold,
           RANK() OVER (PARTITION BY cat.category_id ORDER BY SUM(oi.quantity) DESC) AS rnk
    FROM   order_items oi
    JOIN   orders     o   ON o.order_id     = oi.order_id
    JOIN   products   p   ON p.product_id   = oi.product_id
    JOIN   categories cat ON cat.category_id = p.category_id
    WHERE  o.status IN ('Shipped', 'Delivered')
    GROUP  BY cat.category_id, cat.category_name, p.product_id, p.product_name
)
SELECT category_name, product_name, units_sold
FROM   category_sales
WHERE  rnk = 1;

-- Q34. Total profit per product = (unit_price - cost) * quantity
SELECT p.product_name,
       SUM(oi.quantity)                          AS units_sold,
       SUM((oi.unit_price - p.cost) * oi.quantity) AS total_profit
FROM   order_items oi
JOIN   orders   o ON o.order_id   = oi.order_id
JOIN   products p ON p.product_id = oi.product_id
WHERE  o.status IN ('Shipped', 'Delivered')
GROUP  BY p.product_id, p.product_name
ORDER  BY total_profit DESC;

-- Q35. Average rating and review count per product (products with no reviews kept)
SELECT p.product_name,
       COUNT(r.review_id)                               AS review_count,
       IFNULL(CAST(ROUND(AVG(r.rating), 2) AS CHAR), 'No reviews') AS avg_rating
FROM   products p
LEFT   JOIN reviews r ON r.product_id = p.product_id
GROUP  BY p.product_id, p.product_name
ORDER  BY AVG(r.rating) DESC, review_count DESC;

-- Q36. Products rated above the overall average rating (scalar subquery)
SELECT p.product_name, ROUND(AVG(r.rating), 2) AS avg_rating
FROM   products p
JOIN   reviews r ON r.product_id = p.product_id
GROUP  BY p.product_id, p.product_name
HAVING AVG(r.rating) > (SELECT AVG(rating) FROM reviews)
ORDER  BY avg_rating DESC;

-- #####################################################################
-- SECTION 6: CUSTOMER SPEND ANALYSIS  (Q37 - Q43)
-- #####################################################################

-- Q37. Top 3 customers by lifetime spend
SELECT CONCAT(c.first_name, ' ', c.last_name) AS customer,
       COUNT(*)                               AS orders,
       ROUND(SUM(s.net_amount), 2)            AS total_spent
FROM   customers c
JOIN   v_order_summary s ON s.customer_id = c.customer_id
WHERE  s.status IN ('Shipped', 'Delivered')
GROUP  BY c.customer_id, customer
ORDER  BY total_spent DESC
LIMIT  3;

-- Q38. Spend summary for EVERY customer, including those with zero orders
SELECT c.customer_id,
       CONCAT(c.first_name, ' ', c.last_name)        AS customer,
       COUNT(s.order_id)                             AS orders,
       COALESCE(ROUND(SUM(s.net_amount), 2), 0)      AS total_spent
FROM   customers c
LEFT   JOIN v_order_summary s
       ON s.customer_id = c.customer_id AND s.status IN ('Shipped', 'Delivered')
GROUP  BY c.customer_id, customer
ORDER  BY total_spent DESC;

-- Q39. Customers who spent more than the average customer (nested subquery)
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer,
       ROUND(SUM(s.net_amount), 2) AS total_spent
FROM   customers c
JOIN   v_order_summary s ON s.customer_id = c.customer_id
WHERE  s.status IN ('Shipped', 'Delivered')
GROUP  BY c.customer_id, customer
HAVING SUM(s.net_amount) > (
        SELECT AVG(t.total)
        FROM  (SELECT SUM(net_amount) AS total
               FROM   v_order_summary
               WHERE  status IN ('Shipped', 'Delivered')
               GROUP  BY customer_id) AS t);

-- Q40. Repeat customers (2 or more valid orders)
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer,
       COUNT(*) AS orders
FROM   customers c
JOIN   orders o ON o.customer_id = c.customer_id
WHERE  o.status IN ('Shipped', 'Delivered')
GROUP  BY c.customer_id, customer
HAVING COUNT(*) >= 2
ORDER  BY orders DESC;

-- Q41. Customer segmentation with CASE (Gold / Silver / Bronze / No purchases)
SELECT CONCAT(c.first_name, ' ', c.last_name) AS customer,
       COALESCE(SUM(s.net_amount), 0)         AS total_spent,
       CASE
           WHEN SUM(s.net_amount) IS NULL     THEN 'No purchases'
           WHEN SUM(s.net_amount) >= 50000    THEN 'Gold'
           WHEN SUM(s.net_amount) >= 15000    THEN 'Silver'
           ELSE 'Bronze'
       END AS segment
FROM   customers c
LEFT   JOIN v_order_summary s
       ON s.customer_id = c.customer_id AND s.status IN ('Shipped', 'Delivered')
GROUP  BY c.customer_id, customer
ORDER  BY total_spent DESC;

-- Q42. Rank customers by spend within their state (DENSE_RANK, PARTITION BY)
SELECT c.state,
       CONCAT(c.first_name, ' ', c.last_name) AS customer,
       ROUND(SUM(s.net_amount), 2)            AS total_spent,
       DENSE_RANK() OVER (PARTITION BY c.state ORDER BY SUM(s.net_amount) DESC) AS state_rank
FROM   customers c
JOIN   v_order_summary s ON s.customer_id = c.customer_id
WHERE  s.status IN ('Shipped', 'Delivered')
GROUP  BY c.state, c.customer_id, customer
ORDER  BY c.state, state_rank;

-- Q43. Customer lifetime value card (CTE)
WITH clv AS (
    SELECT customer_id,
           COUNT(*)                 AS orders,
           SUM(net_amount)          AS total_spent,
           AVG(net_amount)          AS avg_order_value,
           MIN(order_date)          AS first_order,
           MAX(order_date)          AS last_order
    FROM   v_order_summary
    WHERE  status IN ('Shipped', 'Delivered')
    GROUP  BY customer_id
)
SELECT CONCAT(c.first_name, ' ', c.last_name) AS customer,
       clv.orders,
       ROUND(clv.total_spent, 2)     AS total_spent,
       ROUND(clv.avg_order_value, 2) AS avg_order_value,
       clv.first_order, clv.last_order,
       DATEDIFF(clv.last_order, clv.first_order) AS days_active
FROM   clv
JOIN   customers c ON c.customer_id = clv.customer_id
ORDER  BY clv.total_spent DESC;

-- #####################################################################
-- SECTION 7: TIME SERIES & GEOGRAPHY  (Q44 - Q46)
-- #####################################################################

-- Q44. Running (cumulative) revenue by month
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, SUM(net_amount) AS revenue
    FROM   v_order_summary
    WHERE  status IN ('Shipped', 'Delivered')
    GROUP  BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT ym, ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY ym), 2) AS running_total
FROM   monthly;

-- Q45. Month-over-month growth % with LAG
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, SUM(net_amount) AS revenue
    FROM   v_order_summary
    WHERE  status IN ('Shipped', 'Delivered')
    GROUP  BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT ym,
       ROUND(revenue, 2)                                   AS revenue,
       ROUND(LAG(revenue) OVER (ORDER BY ym), 2)           AS prev_month,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY ym))
             / NULLIF(LAG(revenue) OVER (ORDER BY ym), 0) * 100, 2) AS growth_pct
FROM   monthly;

-- Q46. Revenue and customer count by state
SELECT c.state,
       COUNT(DISTINCT c.customer_id) AS buying_customers,
       COUNT(s.order_id)             AS orders,
       ROUND(SUM(s.net_amount), 2)   AS revenue
FROM   customers c
JOIN   v_order_summary s ON s.customer_id = c.customer_id
WHERE  s.status IN ('Shipped', 'Delivered')
GROUP  BY c.state
ORDER  BY revenue DESC;

-- #####################################################################
-- SECTION 8: SUBQUERIES & OPERATIONAL CHECKS  (Q47 - Q50)
-- #####################################################################

-- Q47. Products bought by at least one Bengaluru customer (IN subquery)
SELECT product_id, product_name
FROM   products
WHERE  product_id IN (
        SELECT oi.product_id
        FROM   order_items oi
        JOIN   orders    o ON o.order_id    = oi.order_id
        JOIN   customers c ON c.customer_id = o.customer_id
        WHERE  c.city = 'Bengaluru');

-- Q48. Orders without a completed payment (anti-join with a condition in ON)
SELECT o.order_id, o.status, o.order_date,
       COALESCE(p.payment_status, 'No payment row') AS payment_state
FROM   orders o
LEFT   JOIN payments p
       ON p.order_id = o.order_id AND p.payment_status = 'Completed'
WHERE  p.payment_id IS NULL;

-- Q49. Low-stock alert (fewer than 50 units), with a recommended action
SELECT product_id, product_name, stock_qty,
       CASE WHEN stock_qty = 0 THEN 'OUT OF STOCK - reorder now'
            ELSE 'Low stock - reorder soon' END AS action
FROM   products
WHERE  stock_qty < 50
ORDER  BY stock_qty;

-- Q50. Customers who bought from BOTH Electronics and Books (relational division)
SELECT c.customer_id, CONCAT(c.first_name, ' ', c.last_name) AS customer
FROM   customers c
JOIN   orders      o   ON o.customer_id  = c.customer_id
JOIN   order_items oi  ON oi.order_id    = o.order_id
JOIN   products    p   ON p.product_id   = oi.product_id
JOIN   categories  cat ON cat.category_id = p.category_id
WHERE  o.status IN ('Shipped', 'Delivered')
  AND  cat.category_name IN ('Electronics', 'Books')
GROUP  BY c.customer_id, customer
HAVING COUNT(DISTINCT cat.category_id) = 2;
