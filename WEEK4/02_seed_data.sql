-- =====================================================================
--  SQL E-commerce Report  |  02_seed_data.sql
--  Sample data. Edge cases are deliberate so the queries have something
--  interesting to find:
--    * customers 9 & 10 never ordered            (anti-join)
--    * category 6 (Toys) has no products         (anti-join)
--    * product 14 never sold, product 4 out of stock
--    * product 15 has NULL supplier; supplier 5 has no products (NOT IN trap)
--    * NULL phones, NULL shipping cities, NULL payment dates
--    * orders with Cancelled / Returned / Pending status
-- =====================================================================
USE ecommerce_db;

-- ---------- customers ----------
INSERT INTO customers (customer_id, first_name, last_name, email, phone, city, state, signup_date, referred_by) VALUES
(1,  'Aarav',  'Sharma', 'aarav.sharma@example.com',  '9876500001', 'Bengaluru',  'Karnataka',   '2025-01-10', NULL),
(2,  'Diya',   'Patel',  'diya.patel@example.com',    NULL,         'Mumbai',     'Maharashtra', '2025-01-15', NULL),
(3,  'Rohan',  'Iyer',   'rohan.iyer@example.com',    '9876500003', 'Chennai',    'Tamil Nadu',  '2025-02-01', 1),
(4,  'Sneha',  'Reddy',  'sneha.reddy@example.com',   '9876500004', 'Hyderabad',  'Telangana',   '2025-02-12', 1),
(5,  'Kabir',  'Singh',  'kabir.singh@example.com',   NULL,         'Delhi',      'Delhi',       '2025-03-05', NULL),
(6,  'Ananya', 'Nair',   'ananya.nair@example.com',   '9876500006', 'Kochi',      'Kerala',      '2025-03-20', NULL),
(7,  'Vikram', 'Rao',    'vikram.rao@example.com',    '9876500007', 'Bengaluru',  'Karnataka',   '2025-04-02', 3),
(8,  'Meera',  'Joshi',  'meera.joshi@example.com',   '9876500008', 'Pune',       'Maharashtra', '2025-04-18', NULL),
(9,  'Arjun',  'Mehta',  'arjun.mehta@example.com',   '9876500009', 'Ahmedabad',  'Gujarat',     '2025-05-09', NULL),
(10, 'Isha',   'Gupta',  'isha.gupta@example.com',    NULL,         'Jaipur',     'Rajasthan',   '2025-05-25', 5);

-- ---------- categories ----------
INSERT INTO categories (category_id, category_name, description) VALUES
(1, 'Electronics',     'Phones, laptops, audio and accessories'),
(2, 'Books',           'Technical and general books'),
(3, 'Clothing',        'Men and women apparel'),
(4, 'Home & Kitchen',  'Cookware and appliances'),
(5, 'Sports',          'Fitness and sports equipment'),
(6, 'Toys',            NULL);

-- ---------- suppliers ----------
INSERT INTO suppliers (supplier_id, supplier_name, contact_email, country) VALUES
(1, 'TechNova Distributors', 'sales@technova.example',   'India'),
(2, 'PageTurner Books',      'orders@pageturner.example','India'),
(3, 'UrbanWear Apparel',     NULL,                       'India'),
(4, 'HomeEase Appliances',   'b2b@homeease.example',     'India'),
(5, 'Sparkle Toys',          'hello@sparkletoys.example','China');

-- ---------- products ----------
INSERT INTO products (product_id, product_name, category_id, supplier_id, price, cost, stock_qty) VALUES
(1,  'Wireless Earbuds',      1, 1,    2499.00,  1400.00, 120),
(2,  'Smartphone X1',         1, 1,   18999.00, 14500.00,  40),
(3,  'Laptop Pro 14',         1, 1,   54999.00, 46000.00,  15),
(4,  'Bluetooth Speaker',     1, 1,    3499.00,  2100.00,   0),
(5,  'SQL Mastery (Book)',    2, 2,     599.00,   300.00, 200),
(6,  'Data Science Handbook', 2, 2,     899.00,   450.00, 150),
(7,  'Cotton T-Shirt',        3, 3,     499.00,   220.00, 300),
(8,  'Denim Jeans',           3, 3,    1799.00,   900.00, 100),
(9,  'Running Shoes',         5, 3,    2999.00,  1700.00,  80),
(10, 'Non-stick Pan Set',     4, 4,    1999.00,  1100.00,  60),
(11, 'Air Fryer',             4, 4,    5999.00,  3900.00,  25),
(12, 'Yoga Mat',              5, 3,     799.00,   350.00,  90),
(13, 'Badminton Racket',      5, 3,    2199.00,  1200.00,  70),
(14, 'Coffee Maker',          4, 4,    3999.00,  2500.00,  30),
(15, 'USB-C Cable',           1, NULL,  299.00,    90.00, 500);

-- ---------- orders ----------
INSERT INTO orders (order_id, customer_id, order_date, status, shipping_city, discount_pct) VALUES
(1,  1, '2025-06-01', 'Delivered', 'Bengaluru',  0),
(2,  1, '2025-06-20', 'Delivered', 'Bengaluru',  10),
(3,  2, '2025-06-05', 'Delivered', 'Mumbai',     0),
(4,  3, '2025-06-12', 'Delivered', NULL,         0),
(5,  4, '2025-06-15', 'Cancelled', 'Hyderabad',  0),
(6,  5, '2025-07-02', 'Delivered', 'Delhi',      5),
(7,  6, '2025-07-10', 'Shipped',   'Kochi',      0),
(8,  7, '2025-07-18', 'Delivered', 'Bengaluru',  0),
(9,  8, '2025-07-25', 'Pending',   'Pune',       0),
(10, 1, '2025-08-03', 'Delivered', 'Bengaluru',  0),
(11, 2, '2025-08-09', 'Delivered', 'Mumbai',     15),
(12, 3, '2025-08-14', 'Returned',  'Chennai',    0),
(13, 4, '2025-08-22', 'Delivered', 'Hyderabad',  0),
(14, 5, '2025-09-01', 'Delivered', 'Delhi',      0),
(15, 6, '2025-09-07', 'Delivered', 'Kochi',      0),
(16, 7, '2025-09-15', 'Delivered', 'Bengaluru',  10),
(17, 8, '2025-09-21', 'Delivered', 'Pune',       0),
(18, 1, '2025-10-02', 'Delivered', 'Bengaluru',  0),
(19, 2, '2025-10-11', 'Shipped',   'Mumbai',     0),
(20, 3, '2025-10-19', 'Delivered', 'Chennai',    0);

-- ---------- order_items ----------
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1,  1,  1,  2499.00), (1,  5,  2,   599.00),
(2,  2,  1, 18999.00), (2,  15, 2,   299.00),
(3,  7,  3,   499.00), (3,  8,  1,  1799.00),
(4,  5,  1,   599.00), (4,  6,  1,   899.00),
(5,  9,  1,  2999.00),
(6,  11, 1,  5999.00), (6,  10, 1,  1999.00),
(7,  12, 2,   799.00), (7,  13, 1,  2199.00),
(8,  3,  1, 54999.00),
(9,  1,  2,  2499.00),
(10, 6,  2,   899.00), (10, 15, 3,   299.00),
(11, 2,  1, 18999.00), (11, 1,  1,  2499.00),
(12, 8,  2,  1799.00),
(13, 9,  1,  2999.00), (13, 12, 1,   799.00),
(14, 10, 1,  1999.00), (14, 5,  1,   599.00),
(15, 13, 1,  2199.00), (15, 7,  2,   499.00),
(16, 11, 1,  5999.00), (16, 1,  1,  2499.00),
(17, 7,  1,   499.00), (17, 9,  1,  2999.00),
(18, 4,  1,  3499.00), (18, 1,  1,  2499.00),
(19, 6,  1,   899.00), (19, 5,  1,   599.00),
(20, 15, 5,   299.00), (20, 7,  2,   499.00);

-- ---------- payments ----------
-- Amount is computed from the items (net of discount); method rotates by order id.
INSERT INTO payments (order_id, payment_method, amount, payment_date, payment_status)
SELECT  o.order_id,
        ELT(1 + MOD(o.order_id, 4), 'UPI', 'Credit Card', 'Debit Card', 'Net Banking'),
        ROUND(SUM(oi.quantity * oi.unit_price) * (1 - o.discount_pct/100), 2),
        o.order_date,
        'Completed'
FROM    orders o
JOIN    order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.order_date, o.discount_pct;

-- Edge cases: failed, pending (no date yet), refunded, cash on delivery
UPDATE payments SET payment_status = 'Failed'                                   WHERE order_id = 5;
UPDATE payments SET payment_status = 'Pending', payment_date = NULL,
                    payment_method = 'Cash on Delivery'                         WHERE order_id = 9;
UPDATE payments SET payment_status = 'Refunded'                                 WHERE order_id = 12;
UPDATE payments SET payment_status = 'Pending', payment_date = NULL,
                    payment_method = 'Cash on Delivery'                         WHERE order_id = 19;

-- ---------- reviews ----------
INSERT INTO reviews (product_id, customer_id, rating, review_text, review_date) VALUES
(1,  1, 5, 'Great sound and battery life',        '2025-06-10'),
(1,  2, 4, NULL,                                  '2025-08-20'),
(2,  1, 5, 'Fast phone, smooth camera',           '2025-07-01'),
(3,  7, 4, NULL,                                  '2025-07-30'),
(5,  1, 5, 'Best SQL book for beginners',         '2025-06-15'),
(5,  3, 4, NULL,                                  '2025-06-25'),
(6,  3, 3, 'Okay, a bit theoretical',             '2025-06-28'),
(7,  6, 4, NULL,                                  '2025-09-15'),
(8,  3, 1, 'Poor fit, had to return',             '2025-08-20'),
(9,  8, 4, 'Comfortable for daily runs',          '2025-09-30'),
(10, 5, 2, 'Coating peeled within weeks',         '2025-09-10'),
(11, 7, 5, 'Love it, cooks evenly',               '2025-09-25'),
(12, 4, 3, NULL,                                  '2025-09-02'),
(13, 6, 5, 'Light and sturdy',                    '2025-09-20'),
(15, 1, 4, NULL,                                  '2025-08-12');
