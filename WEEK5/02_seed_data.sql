-- =====================================================================
-- 02_seed_data.sql  |  Deterministic sample data (no RAND(), repeatable)
-- Date range: 2025-01-01 .. 2026-09-30  |  5,000 fact rows
-- =====================================================================
USE sales_dw;
SET SESSION cte_max_recursion_depth = 10000;

-- ---------- dim_date ----------
INSERT INTO dim_date
WITH RECURSIVE d AS (
    SELECT DATE('2025-01-01') AS dt
    UNION ALL
    SELECT dt + INTERVAL 1 DAY FROM d WHERE dt < '2026-09-30'
)
SELECT  CAST(DATE_FORMAT(dt,'%Y%m%d') AS UNSIGNED),
        dt,
        DAY(dt),
        DAYNAME(dt),
        IF(DAYOFWEEK(dt) IN (1,7),1,0),
        MONTH(dt),
        MONTHNAME(dt),
        QUARTER(dt),
        YEAR(dt),
        DATE_FORMAT(dt,'%Y-%m')
FROM d;

-- ---------- dim_customer (20) ----------
INSERT INTO dim_customer (customer_id, customer_name, segment, city, state, region) VALUES
('C001','Aarav Sharma','Consumer','Delhi','Delhi','North'),
('C002','Priya Nair','Corporate','Kochi','Kerala','South'),
('C003','Rohan Mehta','Home Office','Mumbai','Maharashtra','West'),
('C004','Ananya Iyer','Consumer','Chennai','Tamil Nadu','South'),
('C005','Vikram Singh','Corporate','Jaipur','Rajasthan','North'),
('C006','Sneha Reddy','Consumer','Hyderabad','Telangana','South'),
('C007','Karan Malhotra','Home Office','Chandigarh','Punjab','North'),
('C008','Divya Patel','Consumer','Ahmedabad','Gujarat','West'),
('C009','Arjun Das','Corporate','Kolkata','West Bengal','East'),
('C010','Meera Joshi','Consumer','Pune','Maharashtra','West'),
('C011','Rahul Verma','Home Office','Lucknow','Uttar Pradesh','North'),
('C012','Pooja Kulkarni','Corporate','Bengaluru','Karnataka','South'),
('C013','Sanjay Gupta','Consumer','Patna','Bihar','East'),
('C014','Neha Bansal','Consumer','Gurugram','Haryana','North'),
('C015','Aditya Rao','Corporate','Bengaluru','Karnataka','South'),
('C016','Ishita Roy','Home Office','Bhubaneswar','Odisha','East'),
('C017','Manish Tiwari','Consumer','Indore','Madhya Pradesh','West'),
('C018','Kavya Menon','Corporate','Thiruvananthapuram','Kerala','South'),
('C019','Harsh Vora','Consumer','Surat','Gujarat','West'),
('C020','Tanvi Ghosh','Home Office','Guwahati','Assam','East');

-- ---------- dim_product (12) ----------
INSERT INTO dim_product (sku, product_name, category, subcategory, brand, unit_price) VALUES
('ELE-001','Noise-Cancelling Headphones','Electronics','Audio','SonicWave',7999.00),
('ELE-002','Bluetooth Speaker','Electronics','Audio','SonicWave',2999.00),
('ELE-003','Smart Watch','Electronics','Wearables','TimeTech',5499.00),
('ELE-004','Wireless Mouse','Electronics','Accessories','ClickPro',899.00),
('FUR-001','Ergonomic Office Chair','Furniture','Chairs','SitWell',12999.00),
('FUR-002','Standing Desk','Furniture','Desks','SitWell',18999.00),
('FUR-003','Bookshelf','Furniture','Storage','HomeNest',6499.00),
('STA-001','A4 Paper Ream (500)','Stationery','Paper','PaperPlus',349.00),
('STA-002','Gel Pen Pack (10)','Stationery','Writing','InkFlow',199.00),
('STA-003','Desk Organizer','Stationery','Organization','HomeNest',799.00),
('CLO-001','Cotton T-Shirt','Clothing','Tops','UrbanFit',699.00),
('CLO-002','Running Shoes','Clothing','Footwear','UrbanFit',3499.00);

-- ---------- dim_store (5) ----------
INSERT INTO dim_store (store_name, city, state, region, channel) VALUES
('Online Store','Bengaluru','Karnataka','South','Online'),
('Delhi Flagship','Delhi','Delhi','North','Retail'),
('Mumbai Central','Mumbai','Maharashtra','West','Retail'),
('Chennai Mall','Chennai','Tamil Nadu','South','Retail'),
('Kolkata Hub','Kolkata','West Bengal','East','Retail');

-- ---------- fact_sales (5,000 rows, deterministic pseudo-random) ----------
INSERT INTO fact_sales
    (date_key, customer_key, product_key, store_key, order_id,
     quantity, unit_price, discount_pct, gross_amount, discount_amount, net_amount)
WITH RECURSIVE n AS (
    SELECT 1 AS i
    UNION ALL
    SELECT i + 1 FROM n WHERE i < 5000
),
base AS (
    SELECT  i,
            DATE_ADD('2025-01-01', INTERVAL MOD(i*37, 638) DAY) AS dt,
            1 + MOD(i*13, 20) AS ck,
            1 + MOD(i*11, 12) AS pk,
            1 + MOD(i + FLOOR(i/7), 5) AS sk,
            1 + MOD(i*3 , 5 ) AS qty,
            MOD(i, 4) * 5     AS disc
    FROM n
)
SELECT  d.date_key, b.ck, b.pk, b.sk,
        CONCAT('ORD-', LPAD(b.i, 6, '0')),
        b.qty, p.unit_price, b.disc,
        b.qty * p.unit_price,
        ROUND(b.qty * p.unit_price * b.disc / 100, 2),
        ROUND(b.qty * p.unit_price * (1 - b.disc / 100), 2)
FROM base b
JOIN dim_date    d ON d.full_date   = b.dt
JOIN dim_product p ON p.product_key = b.pk;

-- Sanity checks
SELECT 'dim_date' t, COUNT(*) c FROM dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product',  COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_store',    COUNT(*) FROM dim_store
UNION ALL SELECT 'fact_sales',   COUNT(*) FROM fact_sales;
