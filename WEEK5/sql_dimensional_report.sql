/* =====================================================================
   05 · SQL DIMENSIONAL REPORT  (SQL — Week 5)
   Star schema · Window-function rankings · CTE MoM report · ROLLUP · EXPLAIN
   Target: MySQL 8.0+  (uses WITH ROLLUP, GROUPING(), CTEs, window functions)
   Run   : mysql -u root -p < sql_dimensional_report.sql
   ===================================================================== */

/* ---------------------------------------------------------------------
   PART 0 · DATABASE SETUP
   --------------------------------------------------------------------- */
DROP DATABASE IF EXISTS retail_dw;
CREATE DATABASE retail_dw CHARACTER SET utf8mb4;
USE retail_dw;

/* ---------------------------------------------------------------------
   PART 1 · STAR SCHEMA — DIMENSION TABLES
   Surrogate integer keys, descriptive attributes, one row per member.
   --------------------------------------------------------------------- */
CREATE TABLE dim_date (
    date_key         INT          PRIMARY KEY,          -- YYYYMMDD
    full_date        DATE         NOT NULL UNIQUE,
    day_of_month     TINYINT      NOT NULL,
    day_name         VARCHAR(10)  NOT NULL,
    week_of_year     TINYINT      NOT NULL,
    month_num        TINYINT      NOT NULL,
    month_name       VARCHAR(10)  NOT NULL,
    year_month_label CHAR(7)      NOT NULL,             -- e.g. 2026-03
    quarter_num      TINYINT      NOT NULL,
    year_num         SMALLINT     NOT NULL,
    is_weekend       TINYINT(1)   NOT NULL
) ENGINE=InnoDB;

CREATE TABLE dim_customer (
    customer_key   INT AUTO_INCREMENT PRIMARY KEY,
    customer_name  VARCHAR(60) NOT NULL,
    gender         CHAR(1)     NOT NULL CHECK (gender IN ('M','F')),
    city           VARCHAR(40) NOT NULL,
    state          VARCHAR(40) NOT NULL,
    segment        VARCHAR(20) NOT NULL CHECK (segment IN ('Consumer','Corporate','Home Office')),
    signup_date    DATE        NOT NULL
) ENGINE=InnoDB;

CREATE TABLE dim_product (
    product_key   INT AUTO_INCREMENT PRIMARY KEY,
    sku           VARCHAR(12)   NOT NULL UNIQUE,
    product_name  VARCHAR(60)   NOT NULL,
    category      VARCHAR(30)   NOT NULL,
    subcategory   VARCHAR(30)   NOT NULL,
    brand         VARCHAR(30)   NOT NULL,
    unit_cost     DECIMAL(10,2) NOT NULL CHECK (unit_cost >= 0),
    list_price    DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_price_above_cost CHECK (list_price >= unit_cost)   -- table-level: compares two columns
) ENGINE=InnoDB;

CREATE TABLE dim_store (
    store_key   INT AUTO_INCREMENT PRIMARY KEY,
    store_name  VARCHAR(60) NOT NULL,
    city        VARCHAR(40) NOT NULL,
    state       VARCHAR(40) NOT NULL,
    region      VARCHAR(10) NOT NULL CHECK (region IN ('South','West','North','East','Online')),
    store_type  VARCHAR(10) NOT NULL CHECK (store_type IN ('Flagship','Mall','Outlet','Online'))
) ENGINE=InnoDB;

/* ---------------------------------------------------------------------
   PART 2 · STAR SCHEMA — FACT TABLE
   Grain: one row per product line sold in an order.
   Measures are STORED generated columns, so they can never drift.
   --------------------------------------------------------------------- */
CREATE TABLE fact_sales (
    sales_key       INT AUTO_INCREMENT PRIMARY KEY,
    order_no        VARCHAR(12)   NOT NULL,
    date_key        INT           NOT NULL,
    customer_key    INT           NOT NULL,
    product_key     INT           NOT NULL,
    store_key       INT           NOT NULL,
    quantity        INT           NOT NULL CHECK (quantity > 0),
    unit_price      DECIMAL(10,2) NOT NULL,
    unit_cost       DECIMAL(10,2) NOT NULL,
    discount_pct    DECIMAL(5,2)  NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100),
    gross_amount    DECIMAL(12,2) AS (quantity * unit_price) STORED,
    discount_amount DECIMAL(12,2) AS (ROUND(quantity * unit_price * discount_pct / 100, 2)) STORED,
    net_amount      DECIMAL(12,2) AS (gross_amount - discount_amount) STORED,
    cost_amount     DECIMAL(12,2) AS (quantity * unit_cost) STORED,
    profit_amount   DECIMAL(12,2) AS (net_amount - cost_amount) STORED,
    INDEX idx_fact_date     (date_key),
    INDEX idx_fact_customer (customer_key),
    INDEX idx_fact_product  (product_key),
    INDEX idx_fact_store    (store_key),
    CONSTRAINT fk_fact_date     FOREIGN KEY (date_key)     REFERENCES dim_date(date_key),
    CONSTRAINT fk_fact_customer FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_fact_product  FOREIGN KEY (product_key)  REFERENCES dim_product(product_key),
    CONSTRAINT fk_fact_store    FOREIGN KEY (store_key)    REFERENCES dim_store(store_key)
) ENGINE=InnoDB;

/* ---------------------------------------------------------------------
   PART 3 · LOAD DIMENSIONS
   --------------------------------------------------------------------- */

-- 3.1 dim_date : 181 rows (2026-01-01 .. 2026-06-30) generated with a recursive CTE
INSERT INTO dim_date (date_key, full_date, day_of_month, day_name, week_of_year,
                      month_num, month_name, year_month_label, quarter_num, year_num, is_weekend)
WITH RECURSIVE d AS (
    SELECT DATE('2026-01-01') AS dt
    UNION ALL
    SELECT DATE_ADD(dt, INTERVAL 1 DAY) FROM d WHERE dt < DATE('2026-06-30')
)
SELECT CAST(DATE_FORMAT(dt, '%Y%m%d') AS UNSIGNED), dt, DAY(dt), DAYNAME(dt), WEEK(dt, 3),
       MONTH(dt), MONTHNAME(dt), DATE_FORMAT(dt, '%Y-%m'), QUARTER(dt), YEAR(dt),
       IF(DAYOFWEEK(dt) IN (1, 7), 1, 0)
FROM d;

-- 3.2 dim_customer : 24 rows
INSERT INTO dim_customer (customer_name, gender, city, state, segment, signup_date) VALUES
('Aarav Sharma',      'M', 'Bengaluru',         'Karnataka',     'Consumer',    '2024-03-12'),
('Diya Nair',         'F', 'Kochi',             'Kerala',        'Consumer',    '2024-05-20'),
('Rohan Mehta',       'M', 'Mumbai',            'Maharashtra',   'Corporate',   '2023-11-02'),
('Ananya Iyer',       'F', 'Chennai',           'Tamil Nadu',    'Consumer',    '2024-01-15'),
('Karthik Reddy',     'M', 'Hyderabad',         'Telangana',     'Home Office', '2023-08-09'),
('Sneha Patil',       'F', 'Pune',              'Maharashtra',   'Consumer',    '2024-07-04'),
('Vikram Singh',      'M', 'Delhi',             'Delhi',         'Corporate',   '2023-06-18'),
('Priya Das',         'F', 'Kolkata',           'West Bengal',   'Consumer',    '2024-02-27'),
('Arjun Gowda',       'M', 'Mysuru',            'Karnataka',     'Home Office', '2024-09-10'),
('Meera Joshi',       'F', 'Ahmedabad',         'Gujarat',       'Consumer',    '2023-12-05'),
('Siddharth Rao',     'M', 'Bengaluru',         'Karnataka',     'Corporate',   '2022-10-21'),
('Kavya Menon',       'F', 'Thiruvananthapuram','Kerala',        'Consumer',    '2025-01-08'),
('Rahul Verma',       'M', 'Lucknow',           'Uttar Pradesh', 'Consumer',    '2024-04-30'),
('Ishita Banerjee',   'F', 'Kolkata',           'West Bengal',   'Home Office', '2025-02-14'),
('Aditya Kulkarni',   'M', 'Pune',              'Maharashtra',   'Corporate',   '2023-03-25'),
('Nisha Kapoor',      'F', 'Delhi',             'Delhi',         'Consumer',    '2024-08-19'),
('Manoj Pillai',      'M', 'Chennai',           'Tamil Nadu',    'Corporate',   '2022-12-11'),
('Tanvi Shah',        'F', 'Surat',             'Gujarat',       'Consumer',    '2025-03-03'),
('Harsha Naik',       'M', 'Mangaluru',         'Karnataka',     'Consumer',    '2024-06-22'),
('Pooja Choudhary',   'F', 'Jaipur',            'Rajasthan',     'Home Office', '2023-09-14'),
('Naveen Kumar',      'M', 'Bengaluru',         'Karnataka',     'Consumer',    '2025-04-17'),
('Lakshmi Venkatesh', 'F', 'Hyderabad',         'Telangana',     'Corporate',   '2022-07-29'),
('Imran Sheikh',      'M', 'Mumbai',            'Maharashtra',   'Consumer',    '2024-10-06'),
('Divya Hegde',       'F', 'Hubballi',          'Karnataka',     'Home Office', '2025-05-21');

-- 3.3 dim_product : 24 rows
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_cost, list_price) VALUES
('ELE-LAP-001', 'Laptop Pro 14',         'Electronics',     'Laptops',        'Zenith',     52000.00, 68000.00),
('ELE-LAP-002', 'Laptop Air 13',         'Electronics',     'Laptops',        'Zenith',     41000.00, 54000.00),
('ELE-MOB-001', 'Smartphone X5',         'Electronics',     'Mobiles',        'Nova',       24000.00, 32000.00),
('ELE-MOB-002', 'Smartphone Lite',       'Electronics',     'Mobiles',        'Nova',       11000.00, 14500.00),
('ELE-AUD-001', 'Wireless Earbuds',      'Electronics',     'Audio',          'SoundWave',   1800.00,  3200.00),
('ELE-AUD-002', 'Bluetooth Speaker',     'Electronics',     'Audio',          'SoundWave',   1500.00,  2800.00),
('ELE-WER-001', 'Smart Watch S2',        'Electronics',     'Wearables',      'Nova',        5200.00,  8500.00),
('ELE-WER-002', 'Fitness Band',          'Electronics',     'Wearables',      'FitPulse',     900.00,  1800.00),
('FUR-SEA-001', 'Office Chair Ergo',     'Furniture',       'Seating',        'ComfortCo',   4800.00,  8200.00),
('FUR-DSK-001', 'Study Desk',            'Furniture',       'Desks',          'ComfortCo',   3600.00,  6400.00),
('FUR-STO-001', 'Bookshelf 5-Tier',      'Furniture',       'Storage',        'ComfortCo',   2400.00,  4300.00),
('FAS-FTW-001', 'Running Shoes',         'Fashion',         'Footwear',       'StrideX',     1400.00,  3200.00),
('FAS-FTW-002', 'Casual Sneakers',       'Fashion',         'Footwear',       'StrideX',     1200.00,  2700.00),
('FAS-APP-001', 'Denim Jacket',          'Fashion',         'Apparel',        'UrbanThread', 1100.00,  2600.00),
('FAS-APP-002', 'Cotton T-Shirt',        'Fashion',         'Apparel',        'UrbanThread',  220.00,   699.00),
('FAS-ACC-001', 'Backpack 30L',          'Fashion',         'Accessories',    'TrekMate',     700.00,  1900.00),
('HOM-KIT-001', 'Mixer Grinder',         'Home Appliances', 'Kitchen',        'HomeEase',    2100.00,  3900.00),
('HOM-KIT-002', 'Air Fryer',             'Home Appliances', 'Kitchen',        'HomeEase',    3000.00,  5500.00),
('HOM-CLN-001', 'Vacuum Cleaner',        'Home Appliances', 'Cleaning',       'HomeEase',    4200.00,  7400.00),
('HOM-KIT-003', 'Microwave Oven',        'Home Appliances', 'Kitchen',        'HomeEase',    6200.00,  9800.00),
('SPO-RAC-001', 'Badminton Racket Pro',  'Sports',          'Racquet Sports', 'SmashPro',    1700.00,  3600.00),
('SPO-FIT-001', 'Yoga Mat',              'Sports',          'Fitness',        'FitPulse',     250.00,   799.00),
('SPO-FIT-002', 'Dumbbell Set 20kg',     'Sports',          'Fitness',        'FitPulse',    1500.00,  2900.00),
('STA-PAP-001', 'Notebook Pack (5)',     'Stationery',      'Paper',          'PageCraft',    180.00,   450.00);

-- 3.4 dim_store : 20 rows
INSERT INTO dim_store (store_name, city, state, region, store_type) VALUES
('Bengaluru Indiranagar',   'Bengaluru',  'Karnataka',     'South',  'Flagship'),
('Bengaluru Whitefield Mall','Bengaluru', 'Karnataka',     'South',  'Mall'),
('Mysuru Central',          'Mysuru',     'Karnataka',     'South',  'Outlet'),
('Chennai T Nagar',         'Chennai',    'Tamil Nadu',    'South',  'Flagship'),
('Hyderabad Banjara Hills', 'Hyderabad',  'Telangana',     'South',  'Mall'),
('Kochi Marine Drive',      'Kochi',      'Kerala',        'South',  'Outlet'),
('Mumbai Andheri',          'Mumbai',     'Maharashtra',   'West',   'Flagship'),
('Mumbai Bandra Mall',      'Mumbai',     'Maharashtra',   'West',   'Mall'),
('Pune Koregaon Park',      'Pune',       'Maharashtra',   'West',   'Outlet'),
('Ahmedabad CG Road',       'Ahmedabad',  'Gujarat',       'West',   'Mall'),
('Surat City Centre',       'Surat',      'Gujarat',       'West',   'Outlet'),
('Delhi Connaught Place',   'Delhi',      'Delhi',         'North',  'Flagship'),
('Delhi Saket Mall',        'Delhi',      'Delhi',         'North',  'Mall'),
('Gurugram Cyber Hub',      'Gurugram',   'Haryana',       'North',  'Mall'),
('Jaipur MI Road',          'Jaipur',     'Rajasthan',     'North',  'Outlet'),
('Lucknow Hazratganj',      'Lucknow',    'Uttar Pradesh', 'North',  'Outlet'),
('Kolkata Park Street',     'Kolkata',    'West Bengal',   'East',   'Flagship'),
('Kolkata Salt Lake',       'Kolkata',    'West Bengal',   'East',   'Mall'),
('Online Store - Web',      'Bengaluru',  'Karnataka',     'Online', 'Online'),
('Online Store - App',      'Bengaluru',  'Karnataka',     'Online', 'Online');

/* ---------------------------------------------------------------------
   PART 4 · LOAD FACT TABLE (60 rows) through a staging table
   Staging holds the raw feed; the INSERT..SELECT looks up unit_cost from
   dim_product and assigns order numbers (a mini ETL step).
   --------------------------------------------------------------------- */
CREATE TABLE stg_sales (
    stg_id       INT AUTO_INCREMENT PRIMARY KEY,
    date_key     INT, customer_key INT, product_key INT, store_key INT,
    quantity     INT, unit_price DECIMAL(10,2), discount_pct DECIMAL(5,2)
);

INSERT INTO stg_sales (date_key, customer_key, product_key, store_key, quantity, unit_price, discount_pct) VALUES
-- January
(20260105, 1, 1, 1, 1, 68000.00,  5.00),
(20260108, 2, 5, 2, 2,  3200.00,  0.00),
(20260112, 3,12, 3, 1,  3200.00, 10.00),
(20260115, 4,17, 4, 1,  3900.00,  0.00),
(20260118, 5, 9, 5, 2,  8200.00,  5.00),
(20260122, 6,22, 6, 3,   799.00,  0.00),
(20260126, 7, 3, 7, 1, 32000.00,  7.50),
(20260129, 8,15, 8, 4,   699.00, 15.00),
-- February
(20260202, 9, 2, 9, 1, 54000.00,  0.00),
(20260205,10, 7,10, 1,  8500.00, 10.00),
(20260209,11,19,11, 1,  7400.00,  5.00),
(20260212,12,21,12, 2,  3600.00,  0.00),
(20260214,13,14,13, 2,  2600.00, 10.00),
(20260217,14, 6,14, 1,  2800.00,  0.00),
(20260220,15,10,15, 1,  6400.00,  5.00),
(20260223,16,18,16, 1,  5500.00, 12.00),
(20260226,17,24,17,10,   450.00,  0.00),
-- March
(20260303,18, 4,18, 2, 14500.00,  5.00),
(20260306,19, 1,19, 1, 68000.00,  8.00),
(20260309,20,16,20, 2,  1900.00,  0.00),
(20260312,21, 8, 1, 3,  1800.00, 10.00),
(20260315,22,20, 2, 1,  9800.00,  0.00),
(20260318,23,13, 3, 2,  2700.00,  5.00),
(20260321,24,23, 4, 2,  2900.00,  0.00),
(20260324, 1, 5, 5, 1,  3200.00,  0.00),
(20260327, 2,11, 6, 1,  4300.00,  5.00),
(20260330, 3, 3, 7, 2, 32000.00, 10.00),
-- April
(20260402, 4, 2, 8, 1, 54000.00,  5.00),
(20260405, 5,12, 9, 2,  3200.00,  0.00),
(20260408, 6,17,10, 2,  3900.00,  8.00),
(20260411, 7, 9,11, 1,  8200.00,  0.00),
(20260414, 8, 7,12, 2,  8500.00,  5.00),
(20260417, 9,21,13, 1,  3600.00, 10.00),
(20260420,10,15,14, 6,   699.00, 20.00),
(20260423,11,19,15, 1,  7400.00,  0.00),
(20260426,12,22,16, 4,   799.00,  5.00),
(20260429,13, 1,17, 1, 68000.00, 10.00),
-- May
(20260503,14, 3,18, 1, 32000.00,  0.00),
(20260506,15,18,19, 2,  5500.00,  5.00),
(20260509,16, 5,20, 3,  3200.00, 10.00),
(20260512,17,10, 1, 2,  6400.00,  0.00),
(20260515,18,20, 2, 1,  9800.00,  5.00),
(20260518,19,14, 3, 3,  2600.00,  0.00),
(20260520,20, 2, 4, 2, 54000.00, 10.00),
(20260523,21,23, 5, 1,  2900.00,  0.00),
(20260525,22, 6, 6, 2,  2800.00,  5.00),
(20260527,23,16, 7, 3,  1900.00, 10.00),
(20260529,24, 4, 8, 1, 14500.00,  0.00),
-- June
(20260602, 1, 1, 9, 2, 68000.00,  5.00),
(20260604, 2, 7,10, 1,  8500.00,  0.00),
(20260606, 3, 9,11, 2,  8200.00, 10.00),
(20260609, 4,12,12, 3,  3200.00,  5.00),
(20260611, 5, 3,13, 1, 32000.00,  0.00),
(20260614, 6,19,14, 2,  7400.00,  8.00),
(20260617, 7,21,15, 2,  3600.00,  0.00),
(20260619, 8,13,16, 2,  2700.00, 10.00),
(20260622, 9,17,17, 1,  3900.00,  0.00),
(20260625,10, 8,18, 4,  1800.00,  5.00),
(20260627,11,11,19, 2,  4300.00,  0.00),
(20260629,12, 2,20, 1, 54000.00,  5.00);

INSERT INTO fact_sales (order_no, date_key, customer_key, product_key, store_key,
                        quantity, unit_price, unit_cost, discount_pct)
SELECT CONCAT('ORD-', 1000 + ROW_NUMBER() OVER (ORDER BY s.stg_id)),
       s.date_key, s.customer_key, s.product_key, s.store_key,
       s.quantity, s.unit_price, p.unit_cost, s.discount_pct
FROM stg_sales s
JOIN dim_product p ON p.product_key = s.product_key
ORDER BY s.stg_id;

DROP TABLE stg_sales;

/* ---------------------------------------------------------------------
   PART 5 · DATA VALIDATION
   --------------------------------------------------------------------- */
-- 5.1 Row counts (every table has 20+ rows)
SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product',  COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_store',    COUNT(*) FROM dim_store
UNION ALL SELECT 'fact_sales',   COUNT(*) FROM fact_sales;

-- 5.2 Orphan check: fact rows with no matching dimension row (expect 0)
SELECT COUNT(*) AS orphan_rows
FROM fact_sales f
LEFT JOIN dim_date     d ON d.date_key     = f.date_key
LEFT JOIN dim_customer c ON c.customer_key = f.customer_key
LEFT JOIN dim_product  p ON p.product_key  = f.product_key
LEFT JOIN dim_store    s ON s.store_key    = f.store_key
WHERE d.date_key IS NULL OR c.customer_key IS NULL OR p.product_key IS NULL OR s.store_key IS NULL;

-- 5.3 Reconciliation: gross - discount = net, net - cost = profit (expect 0 and 0)
SELECT ROUND(SUM(gross_amount) - SUM(discount_amount) - SUM(net_amount), 2) AS net_diff,
       ROUND(SUM(net_amount)   - SUM(cost_amount)     - SUM(profit_amount), 2) AS profit_diff
FROM fact_sales;

-- 5.4 Price check: sold price vs list price (shows which lines carry a discount)
SELECT f.order_no, p.product_name, f.unit_price, p.list_price, f.discount_pct
FROM fact_sales f JOIN dim_product p ON p.product_key = f.product_key
WHERE f.unit_price <> p.list_price;     -- expect 0 rows (discounts are in discount_pct)

/* ---------------------------------------------------------------------
   PART 6 · REPORTING VIEW (flattened star)
   --------------------------------------------------------------------- */
CREATE VIEW vw_sales_star AS
SELECT f.sales_key, f.order_no,
       d.full_date, d.year_month_label, d.year_num, d.quarter_num, d.month_num,
       d.month_name, d.day_name, d.is_weekend,
       c.customer_key, c.customer_name, c.segment, c.city AS customer_city, c.state AS customer_state,
       p.product_key, p.product_name, p.category, p.subcategory, p.brand,
       s.store_key, s.store_name, s.city AS store_city, s.state AS store_state, s.region, s.store_type,
       f.quantity, f.unit_price, f.discount_pct,
       f.gross_amount, f.discount_amount, f.net_amount, f.cost_amount, f.profit_amount
FROM fact_sales f
JOIN dim_date     d ON d.date_key     = f.date_key
JOIN dim_customer c ON c.customer_key = f.customer_key
JOIN dim_product  p ON p.product_key  = f.product_key
JOIN dim_store    s ON s.store_key    = f.store_key;

/* ---------------------------------------------------------------------
   PART 7 · BASIC STAR-SCHEMA QUERIES (slice & dice)
   --------------------------------------------------------------------- */
-- 7.1 Monthly revenue by category (pivot using conditional aggregation)
SELECT p.category,
       SUM(CASE WHEN d.month_num = 1 THEN f.net_amount ELSE 0 END) AS jan,
       SUM(CASE WHEN d.month_num = 2 THEN f.net_amount ELSE 0 END) AS feb,
       SUM(CASE WHEN d.month_num = 3 THEN f.net_amount ELSE 0 END) AS mar,
       SUM(CASE WHEN d.month_num = 4 THEN f.net_amount ELSE 0 END) AS apr,
       SUM(CASE WHEN d.month_num = 5 THEN f.net_amount ELSE 0 END) AS may,
       SUM(CASE WHEN d.month_num = 6 THEN f.net_amount ELSE 0 END) AS jun,
       SUM(f.net_amount) AS h1_total
FROM fact_sales f
JOIN dim_date d    ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY h1_total DESC;

-- 7.2 Revenue and profit by region and store type
SELECT s.region, s.store_type,
       COUNT(*)                AS lines_sold,
       SUM(f.net_amount)       AS revenue,
       SUM(f.profit_amount)    AS profit,
       ROUND(100 * SUM(f.profit_amount) / SUM(f.net_amount), 2) AS margin_pct
FROM fact_sales f JOIN dim_store s ON s.store_key = f.store_key
GROUP BY s.region, s.store_type
ORDER BY s.region, revenue DESC;

-- 7.3 Customer segment performance
SELECT c.segment,
       COUNT(DISTINCT c.customer_key) AS customers,
       SUM(f.net_amount)              AS revenue,
       ROUND(AVG(f.net_amount), 2)    AS avg_line_value,
       ROUND(100 * SUM(f.profit_amount) / SUM(f.net_amount), 2) AS margin_pct
FROM fact_sales f JOIN dim_customer c ON c.customer_key = f.customer_key
GROUP BY c.segment
ORDER BY revenue DESC;

-- 7.4 Weekend vs weekday sales
SELECT IF(d.is_weekend = 1, 'Weekend', 'Weekday') AS day_type,
       COUNT(*) AS lines_sold, SUM(f.net_amount) AS revenue,
       ROUND(AVG(f.discount_pct), 2) AS avg_discount_pct
FROM fact_sales f JOIN dim_date d ON d.date_key = f.date_key
GROUP BY day_type;

-- 7.5 Brand performance (units, revenue, margin)
SELECT p.brand, SUM(f.quantity) AS units, SUM(f.net_amount) AS revenue,
       ROUND(100 * SUM(f.profit_amount) / SUM(f.net_amount), 2) AS margin_pct
FROM fact_sales f JOIN dim_product p ON p.product_key = f.product_key
GROUP BY p.brand
ORDER BY revenue DESC;

/* ---------------------------------------------------------------------
   PART 8 · WINDOW FUNCTION RANKINGS
   --------------------------------------------------------------------- */
-- 8.1 RANK vs DENSE_RANK vs ROW_NUMBER vs PERCENT_RANK on product revenue
WITH product_rev AS (
    SELECT product_name, category, SUM(net_amount) AS revenue
    FROM vw_sales_star
    GROUP BY product_name, category
)
SELECT product_name, category, revenue,
       RANK()         OVER w AS rnk,
       DENSE_RANK()   OVER w AS dense_rnk,
       ROW_NUMBER()   OVER w AS row_num,
       ROUND(100 * PERCENT_RANK() OVER w, 1) AS pct_rank
FROM product_rev
WINDOW w AS (ORDER BY revenue DESC);

-- 8.1b Ties: rank products by UNITS sold (RANK leaves gaps, DENSE_RANK does not)
WITH product_units AS (
    SELECT product_name, SUM(quantity) AS units
    FROM vw_sales_star GROUP BY product_name
)
SELECT product_name, units,
       RANK()       OVER (ORDER BY units DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY units DESC) AS dense_rnk,
       ROW_NUMBER() OVER (ORDER BY units DESC, product_name) AS row_num
FROM product_units;

-- 8.2 Top 3 products inside every category (PARTITION BY)
WITH product_rev AS (
    SELECT category, product_name, SUM(net_amount) AS revenue
    FROM vw_sales_star GROUP BY category, product_name
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) AS rn
    FROM product_rev
)
SELECT category, rn AS rank_in_category, product_name, revenue
FROM ranked
WHERE rn <= 3
ORDER BY category, rn;

-- 8.3 Customer spend quartiles (NTILE) and rank within segment
WITH cust AS (
    SELECT customer_name, segment, SUM(net_amount) AS total_spend, COUNT(DISTINCT order_no) AS orders
    FROM vw_sales_star GROUP BY customer_name, segment
)
SELECT customer_name, segment, orders, total_spend,
       NTILE(4)    OVER (ORDER BY total_spend DESC)                       AS spend_quartile,
       RANK()      OVER (PARTITION BY segment ORDER BY total_spend DESC)  AS rank_in_segment,
       RANK()      OVER (ORDER BY total_spend DESC)                       AS overall_rank
FROM cust
ORDER BY overall_rank;

-- 8.4 Store ranking inside each region + gap to the regional leader
WITH store_profit AS (
    SELECT region, store_name, SUM(profit_amount) AS profit
    FROM vw_sales_star GROUP BY region, store_name
)
SELECT region, store_name, profit,
       RANK() OVER (PARTITION BY region ORDER BY profit DESC) AS rank_in_region,
       MAX(profit) OVER (PARTITION BY region) - profit        AS gap_to_leader
FROM store_profit
ORDER BY region, rank_in_region;

-- 8.5 Running total and 3-sale moving average of revenue (frame clauses)
SELECT full_date, order_no, net_amount,
       SUM(net_amount) OVER (ORDER BY full_date, sales_key
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
       ROUND(AVG(net_amount) OVER (ORDER BY full_date, sales_key
                             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)     AS moving_avg_3
FROM vw_sales_star
ORDER BY full_date, sales_key;

-- 8.6 Share of total and Pareto (cumulative %) by product
WITH product_rev AS (
    SELECT product_name, SUM(net_amount) AS revenue FROM vw_sales_star GROUP BY product_name
)
SELECT product_name, revenue,
       ROUND(100 * revenue / SUM(revenue) OVER (), 2)                                   AS pct_of_total,
       ROUND(100 * SUM(revenue) OVER (ORDER BY revenue DESC
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                 / SUM(revenue) OVER (), 2)                                             AS cumulative_pct
FROM product_rev
ORDER BY revenue DESC;

-- 8.7 Days between a customer's purchases (LAG)
SELECT customer_name, full_date, order_no, net_amount,
       LAG(full_date) OVER (PARTITION BY customer_key ORDER BY full_date)                        AS previous_purchase,
       DATEDIFF(full_date, LAG(full_date) OVER (PARTITION BY customer_key ORDER BY full_date))   AS days_since_previous
FROM vw_sales_star
ORDER BY customer_name, full_date;

-- 8.8 Best-selling product of each month (ROW_NUMBER + filter)
WITH monthly_product AS (
    SELECT year_month_label AS ym, product_name, SUM(net_amount) AS revenue
    FROM vw_sales_star GROUP BY year_month_label, product_name
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY ym ORDER BY revenue DESC) AS rn
    FROM monthly_product
)
SELECT ym, product_name AS top_product, revenue
FROM ranked WHERE rn = 1 ORDER BY ym;

-- 8.9 First and latest purchase value per customer (FIRST_VALUE / LAST_VALUE)
SELECT DISTINCT customer_name,
       FIRST_VALUE(net_amount) OVER w AS first_purchase_value,
       LAST_VALUE(net_amount)  OVER w AS latest_purchase_value
FROM vw_sales_star
WINDOW w AS (PARTITION BY customer_key ORDER BY full_date, sales_key
             ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
ORDER BY customer_name;

/* ---------------------------------------------------------------------
   PART 9 · CTE MONTH-OVER-MONTH (MoM) REPORT
   --------------------------------------------------------------------- */
-- 9.1 Company-level MoM with growth/decline flag and YTD
WITH monthly AS (
    SELECT year_month_label AS ym,
           COUNT(DISTINCT order_no) AS orders,
           SUM(net_amount)          AS revenue,
           SUM(profit_amount)       AS profit
    FROM vw_sales_star
    GROUP BY year_month_label
), mom AS (
    SELECT m.*, LAG(revenue) OVER (ORDER BY ym) AS prev_revenue
    FROM monthly m
)
SELECT ym, orders, revenue, prev_revenue,
       revenue - prev_revenue                                         AS mom_change,
       ROUND(100 * (revenue - prev_revenue) / prev_revenue, 2)        AS mom_pct,
       ROUND(100 * profit / revenue, 2)                               AS margin_pct,
       SUM(revenue) OVER (ORDER BY ym)                                AS ytd_revenue,
       CASE WHEN prev_revenue IS NULL    THEN 'Baseline'
            WHEN revenue > prev_revenue  THEN 'Growth'
            WHEN revenue < prev_revenue  THEN 'Decline'
            ELSE 'Flat' END                                           AS trend
FROM mom
ORDER BY ym;

-- 9.2 MoM by category (LAG with PARTITION BY)
WITH cat_month AS (
    SELECT category, year_month_label AS ym, SUM(net_amount) AS revenue
    FROM vw_sales_star GROUP BY category, year_month_label
)
SELECT category, ym, revenue,
       LAG(revenue) OVER (PARTITION BY category ORDER BY ym) AS prev_revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (PARTITION BY category ORDER BY ym))
                 / LAG(revenue) OVER (PARTITION BY category ORDER BY ym), 2) AS mom_pct
FROM cat_month
ORDER BY category, ym;

-- 9.3 Chained CTEs: best and worst month flagged
WITH monthly AS (
    SELECT year_month_label AS ym, SUM(net_amount) AS revenue
    FROM vw_sales_star GROUP BY year_month_label
), growth AS (
    SELECT ym, revenue,
           ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY ym)) / LAG(revenue) OVER (ORDER BY ym), 2) AS mom_pct
    FROM monthly
)
SELECT ym, revenue, mom_pct,
       CASE WHEN revenue = MAX(revenue) OVER () THEN 'Best month'
            WHEN revenue = MIN(revenue) OVER () THEN 'Weakest month'
            ELSE '' END AS flag
FROM growth
ORDER BY ym;

-- 9.4 Complete category x month grid (zero-filled) built with CTEs + CROSS JOIN
WITH months AS (SELECT DISTINCT year_month_label AS ym FROM dim_date),
     cats   AS (SELECT DISTINCT category FROM dim_product),
     actual AS (SELECT category, year_month_label AS ym, SUM(net_amount) AS revenue
                FROM vw_sales_star GROUP BY category, year_month_label)
SELECT c.category, m.ym, COALESCE(a.revenue, 0) AS revenue
FROM cats c
CROSS JOIN months m
LEFT JOIN actual a ON a.category = c.category AND a.ym = m.ym
ORDER BY c.category, m.ym;

/* ---------------------------------------------------------------------
   PART 10 · ROLLUP (subtotals and grand totals)
   GROUPING(col) = 1 marks a super-aggregate row, so it can be labelled.
   --------------------------------------------------------------------- */
-- 10.1 Time hierarchy: year > quarter > month
SELECT year_num,
       IF(GROUPING(quarter_num) = 1, 'All quarters', CONCAT('Q', quarter_num))      AS quarter_label,
       IF(GROUPING(month_num)   = 1, 'All months',   LPAD(month_num, 2, '0'))       AS month_label,
       SUM(net_amount) AS revenue, SUM(profit_amount) AS profit
FROM vw_sales_star
GROUP BY year_num, quarter_num, month_num WITH ROLLUP;

-- 10.2 Product hierarchy: category > subcategory
SELECT IF(GROUPING(category)    = 1, 'GRAND TOTAL',   category)    AS category,
       IF(GROUPING(subcategory) = 1, 'Category total', subcategory) AS subcategory,
       SUM(quantity) AS units, SUM(net_amount) AS revenue
FROM vw_sales_star
GROUP BY category, subcategory WITH ROLLUP;

-- 10.3 Geography hierarchy: region > state > store
SELECT IF(GROUPING(region)     = 1, 'GRAND TOTAL',  region)       AS region,
       IF(GROUPING(store_state)= 1, 'Region total', store_state)  AS state,
       IF(GROUPING(store_name) = 1, 'State total',  store_name)   AS store,
       SUM(net_amount) AS revenue, SUM(profit_amount) AS profit
FROM vw_sales_star
GROUP BY region, store_state, store_name WITH ROLLUP;

-- 10.4 Report-level labelling with GROUPING() (category x region)
--      Note: ROLLUP(category, region) gives category subtotals + grand total,
--      but NOT region subtotals across categories (reverse the order for that).
SELECT category, region,
       CASE WHEN GROUPING(category) = 1 AND GROUPING(region) = 1 THEN 'Grand total'
            WHEN GROUPING(region)   = 1                          THEN 'Category subtotal'
            ELSE 'Detail' END AS report_level,
       SUM(net_amount) AS revenue
FROM vw_sales_star
GROUP BY category, region WITH ROLLUP;

-- 10.5 Keep only subtotals and grand total (hide detail rows)
SELECT IF(GROUPING(category) = 1, 'GRAND TOTAL', category) AS category,
       SUM(net_amount) AS revenue
FROM vw_sales_star
GROUP BY category WITH ROLLUP;

/* ---------------------------------------------------------------------
   PART 11 · EXPLAIN OPTIMIZATION
   With only 60 rows the optimizer will happily scan everything, so we first
   build fact_sales_big (100,000 rows) to make plans meaningful.
   --------------------------------------------------------------------- */
SET SESSION cte_max_recursion_depth = 100000;

CREATE TABLE fact_sales_big (
    sales_key       BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_no        VARCHAR(16)   NOT NULL,
    date_key        INT           NOT NULL,
    customer_key    INT           NOT NULL,
    product_key     INT           NOT NULL,
    store_key       INT           NOT NULL,
    quantity        INT           NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    unit_cost       DECIMAL(10,2) NOT NULL,
    discount_pct    DECIMAL(5,2)  NOT NULL DEFAULT 0,
    gross_amount    DECIMAL(12,2) AS (quantity * unit_price) STORED,
    discount_amount DECIMAL(12,2) AS (ROUND(quantity * unit_price * discount_pct / 100, 2)) STORED,
    net_amount      DECIMAL(12,2) AS (gross_amount - discount_amount) STORED,
    cost_amount     DECIMAL(12,2) AS (quantity * unit_cost) STORED,
    profit_amount   DECIMAL(12,2) AS (net_amount - cost_amount) STORED
) ENGINE=InnoDB;                       -- deliberately NO secondary indexes yet

INSERT INTO fact_sales_big (order_no, date_key, customer_key, product_key, store_key,
                            quantity, unit_price, unit_cost, discount_pct)
WITH RECURSIVE n AS (
    SELECT 1 AS i UNION ALL SELECT i + 1 FROM n WHERE i < 100000
)
SELECT CONCAT('BIG-', n.i),
       CAST(DATE_FORMAT(DATE_ADD('2026-01-01', INTERVAL (n.i MOD 181) DAY), '%Y%m%d') AS UNSIGNED),
       1 + ((n.i * 7) MOD 24),
       p.product_key,
       1 + ((n.i * 3) MOD 20),
       1 + (n.i MOD 5),
       p.list_price, p.unit_cost,
       (n.i MOD 4) * 5
FROM n
JOIN dim_product p ON p.product_key = 1 + (n.i MOD 24);

ANALYZE TABLE fact_sales_big;
SELECT COUNT(*) AS big_rows FROM fact_sales_big;

-- 11.1 BASELINE: no index → expect type=ALL, rows ≈ 100000, Using where
EXPLAIN
SELECT SUM(net_amount) AS revenue
FROM fact_sales_big
WHERE store_key = 5 AND date_key BETWEEN 20260301 AND 20260331;

-- 11.2 FIX: composite (equality column first, range column second) + measure = covering index
CREATE INDEX idx_big_store_date_amt ON fact_sales_big (store_key, date_key, net_amount);

EXPLAIN
SELECT SUM(net_amount) AS revenue
FROM fact_sales_big
WHERE store_key = 5 AND date_key BETWEEN 20260301 AND 20260331;
-- expect: type=range, key=idx_big_store_date_amt, Extra=Using where; Using index (no table access)

-- 11.3 SARGABLE vs NON-SARGABLE predicate (function on a column kills the index)
CREATE INDEX idx_big_date ON fact_sales_big (date_key);

EXPLAIN SELECT COUNT(*) FROM fact_sales_big WHERE LEFT(date_key, 6) = '202603';
-- non-sargable: type=index, rows ≈ 99,000 → every index entry is read and tested
EXPLAIN SELECT COUNT(*) FROM fact_sales_big WHERE date_key BETWEEN 20260301 AND 20260331;
-- sargable: type=range, rows ≈ 11,000 → only the March slice of the index is read

-- 11.4 STAR JOIN: read the plan, then measure with EXPLAIN ANALYZE (actual rows + timing)
--      Before: fact is reached through idx_big_date, then the table rows are fetched for net_amount.
--      After : covering index (date_key, product_key, net_amount) → "Covering index lookup", no table access.
EXPLAIN
SELECT d.month_name, p.category, SUM(f.net_amount) AS revenue
FROM fact_sales_big f
JOIN dim_date    d ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
WHERE d.year_month_label = '2026-03'
GROUP BY d.month_name, p.category;

CREATE INDEX idx_big_date_prod_amt ON fact_sales_big (date_key, product_key, net_amount);

EXPLAIN ANALYZE
SELECT d.month_name, p.category, SUM(f.net_amount) AS revenue
FROM fact_sales_big f
JOIN dim_date    d ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
WHERE d.year_month_label = '2026-03'
GROUP BY d.month_name, p.category;

-- 11.5 SUMMARY (aggregate) TABLE: pre-compute what dashboards ask for every day
CREATE TABLE agg_monthly_category AS
SELECT d.year_month_label AS ym, p.category,
       SUM(f.quantity) AS units, SUM(f.net_amount) AS revenue, SUM(f.profit_amount) AS profit
FROM fact_sales_big f
JOIN dim_date d    ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY d.year_month_label, p.category;

ALTER TABLE agg_monthly_category ADD PRIMARY KEY (ym, category);

EXPLAIN ANALYZE SELECT ym, SUM(revenue) FROM agg_monthly_category GROUP BY ym;   -- ~36 rows instead of 100000

-- 11.6 Inspect and clean up indexes
SHOW INDEX FROM fact_sales_big;
-- Unused/duplicate indexes slow every INSERT, so drop what the plans above do not need:
-- DROP INDEX idx_big_date ON fact_sales_big;

/* ---------------------------------------------------------------------
   PART 12 · OPTIONAL CLEANUP
   --------------------------------------------------------------------- */
-- DROP TABLE agg_monthly_category, fact_sales_big;
-- DROP DATABASE retail_dw;
