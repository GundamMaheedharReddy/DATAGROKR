-- =====================================================================
--  SQL E-commerce Report  |  04_ddl_constraints_demo.sql
--  Part A: constraint violation tests. Each statement is commented out
--          because it is EXPECTED TO FAIL. Un-comment one at a time.
--  Part B: ALTER / INDEX / VIEW / DROP demonstrations (safe to run).
-- =====================================================================
USE ecommerce_db;

-- =====================================================================
-- PART A: CONSTRAINT TESTS (expected errors in comments)
-- =====================================================================

-- A1. PRIMARY KEY / UNIQUE: duplicate email
-- INSERT INTO customers (first_name, last_name, email, city, state)
-- VALUES ('Test', 'User', 'aarav.sharma@example.com', 'Goa', 'Goa');
-- ERROR 1062 (23000): Duplicate entry ... for key 'customers.uq_customers_email'

-- A2. NOT NULL: missing mandatory column
-- INSERT INTO customers (first_name, email, city, state)
-- VALUES ('NoLastName', 'nln@example.com', 'Goa', 'Goa');
-- ERROR 1364 (HY000): Field 'last_name' doesn't have a default value

-- A3. CHECK: negative product price
-- INSERT INTO products (product_name, category_id, price, cost)
-- VALUES ('Bad Product', 1, -50, 10);
-- ERROR 3819 (HY000): Check constraint 'chk_products_price' is violated.

-- A4. CHECK: cost higher than selling price
-- INSERT INTO products (product_name, category_id, price, cost)
-- VALUES ('Loss Maker', 1, 100, 250);
-- ERROR 3819 (HY000): Check constraint 'chk_products_margin' is violated.

-- A5. CHECK: rating outside 1-5
-- INSERT INTO reviews (product_id, customer_id, rating) VALUES (4, 1, 6);
-- ERROR 3819 (HY000): Check constraint 'chk_reviews_rating' is violated.

-- A6. CHECK: phone number is not 10 digits
-- INSERT INTO customers (first_name, last_name, email, phone, city, state)
-- VALUES ('Bad', 'Phone', 'bad.phone@example.com', '12345', 'Goa', 'Goa');
-- ERROR 3819 (HY000): Check constraint 'chk_customers_phone' is violated.

-- A7. CHECK: discount above the 50 percent cap
-- INSERT INTO orders (customer_id, order_date, discount_pct) VALUES (1, CURDATE(), 75);
-- ERROR 3819 (HY000): Check constraint 'chk_orders_discount' is violated.

-- A8. FOREIGN KEY (child side): order for a customer that does not exist
-- INSERT INTO orders (customer_id, order_date) VALUES (999, CURDATE());
-- ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails

-- A9. FOREIGN KEY (parent side, RESTRICT): delete a customer who has orders
-- DELETE FROM customers WHERE customer_id = 1;
-- ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails

-- A10. Composite UNIQUE: same product twice in one order
-- INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (1, 1, 1, 2499);
-- ERROR 1062 (23000): Duplicate entry '1-1' for key 'order_items.uq_order_product'

-- A11. CHECK: zero quantity
-- INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (1, 7, 0, 499);
-- ERROR 3819 (HY000): Check constraint 'chk_items_quantity' is violated.

-- A12. ENUM: invalid status value
-- INSERT INTO orders (customer_id, order_date, status) VALUES (1, CURDATE(), 'Lost');
-- ERROR 1265 (01000): Data truncated for column 'status'   (error in strict mode)

-- =====================================================================
-- PART B: DDL IN ACTION (safe to run)
-- =====================================================================

-- B1. DEFAULT values at work: only mandatory columns supplied
INSERT INTO products (product_name, category_id, price, cost)
VALUES ('Demo Product', 6, 100.00, 40.00);
SELECT product_id, product_name, stock_qty, is_active, created_at
FROM   products WHERE product_name = 'Demo Product';     -- stock_qty=0, is_active=1

-- B2. ALTER TABLE: add a column with DEFAULT and a CHECK
ALTER TABLE customers
    ADD COLUMN loyalty_points INT NOT NULL DEFAULT 0,
    ADD CONSTRAINT chk_customers_points CHECK (loyalty_points >= 0);

-- B3. ALTER TABLE: add a new constraint to an existing column
ALTER TABLE products
    ADD CONSTRAINT chk_products_name_len CHECK (CHAR_LENGTH(product_name) >= 3);

-- B4. ALTER TABLE: modify a column definition
ALTER TABLE customers MODIFY COLUMN city VARCHAR(80) NOT NULL;

-- B5. Add a composite index and verify the optimizer can use it
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);
EXPLAIN SELECT * FROM orders WHERE customer_id = 1 AND order_date >= '2025-07-01';

-- B6. Inspect constraints from the data dictionary
SELECT table_name, constraint_name, constraint_type
FROM   information_schema.table_constraints
WHERE  table_schema = 'ecommerce_db'
ORDER  BY table_name, constraint_type, constraint_name;

SELECT table_name, constraint_name, check_clause
FROM   information_schema.check_constraints
WHERE  constraint_schema = 'ecommerce_db';

-- B7. Show full DDL of a table
SHOW CREATE TABLE order_items;

-- B8. Drop what we added (DROP CONSTRAINT / INDEX / COLUMN)
ALTER TABLE products  DROP CHECK chk_products_name_len;
ALTER TABLE customers DROP CHECK chk_customers_points;
ALTER TABLE customers DROP COLUMN loyalty_points;
DROP INDEX idx_orders_customer_date ON orders;
DELETE FROM products WHERE product_name = 'Demo Product';

-- B9. TRUNCATE vs DELETE (shown on a scratch table)
CREATE TABLE scratch_log (id INT AUTO_INCREMENT PRIMARY KEY, note VARCHAR(50));
INSERT INTO scratch_log (note) VALUES ('a'), ('b'), ('c');
DELETE FROM scratch_log;                          -- row by row, AUTO_INCREMENT keeps counting
INSERT INTO scratch_log (note) VALUES ('d');      -- id = 4
TRUNCATE TABLE scratch_log;                       -- DDL: resets AUTO_INCREMENT to 1
INSERT INTO scratch_log (note) VALUES ('e');      -- id = 1
DROP TABLE scratch_log;
