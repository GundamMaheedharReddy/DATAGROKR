-- =====================================================================
--  SQL E-commerce Report  |  01_schema.sql
--  Target: MySQL 8.0.16+ (CHECK constraints are enforced from 8.0.16)
--  Covers: PK, FK (CASCADE / RESTRICT / SET NULL), UNIQUE, NOT NULL,
--          DEFAULT, CHECK, ENUM, INDEX, VIEW
-- =====================================================================

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE ecommerce_db;

-- ---------------------------------------------------------------------
-- 1. customers  (self-referencing FK for the referral programme)
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    first_name   VARCHAR(50)   NOT NULL,
    last_name    VARCHAR(50)   NOT NULL,
    email        VARCHAR(100)  NOT NULL,
    phone        VARCHAR(15)   NULL,                       -- optional -> NULLs
    city         VARCHAR(50)   NOT NULL,
    state        VARCHAR(50)   NOT NULL,
    signup_date  DATE          NOT NULL DEFAULT (CURRENT_DATE),
    referred_by  INT UNSIGNED  NULL,                       -- NULL = organic signup
    CONSTRAINT pk_customers          PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_email    UNIQUE (email),
    CONSTRAINT chk_customers_email   CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT chk_customers_phone   CHECK (phone IS NULL OR phone REGEXP '^[0-9]{10}$'),
    CONSTRAINT fk_customers_referrer FOREIGN KEY (referred_by)
        REFERENCES customers (customer_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. categories
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    category_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    category_name  VARCHAR(60)  NOT NULL,
    description    VARCHAR(255) NULL,
    CONSTRAINT pk_categories      PRIMARY KEY (category_id),
    CONSTRAINT uq_category_name   UNIQUE (category_name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. suppliers
-- ---------------------------------------------------------------------
CREATE TABLE suppliers (
    supplier_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    supplier_name  VARCHAR(100) NOT NULL,
    contact_email  VARCHAR(100) NULL,
    country        VARCHAR(50)  NOT NULL DEFAULT 'India',
    CONSTRAINT pk_suppliers        PRIMARY KEY (supplier_id),
    CONSTRAINT uq_supplier_email   UNIQUE (contact_email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. products
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id    INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    product_name  VARCHAR(120)  NOT NULL,
    category_id   INT UNSIGNED  NOT NULL,
    supplier_id   INT UNSIGNED  NULL,                      -- some products have no supplier
    price         DECIMAL(10,2) NOT NULL,
    cost          DECIMAL(10,2) NOT NULL,
    stock_qty     INT           NOT NULL DEFAULT 0,
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_products          PRIMARY KEY (product_id),
    CONSTRAINT chk_products_price   CHECK (price > 0),
    CONSTRAINT chk_products_cost    CHECK (cost >= 0),
    CONSTRAINT chk_products_margin  CHECK (cost <= price),
    CONSTRAINT chk_products_stock   CHECK (stock_qty >= 0),
    CONSTRAINT fk_products_category FOREIGN KEY (category_id)
        REFERENCES categories (category_id) ON DELETE RESTRICT,
    CONSTRAINT fk_products_supplier FOREIGN KEY (supplier_id)
        REFERENCES suppliers (supplier_id)  ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. orders
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    customer_id    INT UNSIGNED  NOT NULL,
    order_date     DATE          NOT NULL,
    status         ENUM('Pending','Shipped','Delivered','Cancelled','Returned')
                                 NOT NULL DEFAULT 'Pending',
    shipping_city  VARCHAR(50)   NULL,
    discount_pct   DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
    CONSTRAINT pk_orders           PRIMARY KEY (order_id),
    CONSTRAINT chk_orders_discount CHECK (discount_pct BETWEEN 0 AND 50),
    CONSTRAINT fk_orders_customer  FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. order_items  (junction table: orders <-> products)
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id  INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    order_id       INT UNSIGNED  NOT NULL,
    product_id     INT UNSIGNED  NOT NULL,
    quantity       INT           NOT NULL,
    unit_price     DECIMAL(10,2) NOT NULL,                 -- price frozen at purchase time
    CONSTRAINT pk_order_items       PRIMARY KEY (order_item_id),
    CONSTRAINT uq_order_product     UNIQUE (order_id, product_id),
    CONSTRAINT chk_items_quantity   CHECK (quantity > 0),
    CONSTRAINT chk_items_unit_price CHECK (unit_price > 0),
    CONSTRAINT fk_items_order       FOREIGN KEY (order_id)
        REFERENCES orders (order_id)     ON DELETE CASCADE,
    CONSTRAINT fk_items_product     FOREIGN KEY (product_id)
        REFERENCES products (product_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. payments  (1 order : 1 payment)
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    payment_id      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    order_id        INT UNSIGNED  NOT NULL,
    payment_method  ENUM('UPI','Credit Card','Debit Card','Net Banking','Cash on Delivery')
                                  NOT NULL,
    amount          DECIMAL(12,2) NOT NULL,
    payment_date    DATE          NULL,                    -- NULL until money is received
    payment_status  ENUM('Pending','Completed','Failed','Refunded')
                                  NOT NULL DEFAULT 'Pending',
    CONSTRAINT pk_payments        PRIMARY KEY (payment_id),
    CONSTRAINT uq_payments_order  UNIQUE (order_id),
    CONSTRAINT chk_payments_amt   CHECK (amount >= 0),
    CONSTRAINT fk_payments_order  FOREIGN KEY (order_id)
        REFERENCES orders (order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. reviews
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    review_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id   INT UNSIGNED NOT NULL,
    customer_id  INT UNSIGNED NOT NULL,
    rating       TINYINT      NOT NULL,
    review_text  VARCHAR(500) NULL,
    review_date  DATE         NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT pk_reviews          PRIMARY KEY (review_id),
    CONSTRAINT uq_review_once      UNIQUE (product_id, customer_id),
    CONSTRAINT chk_reviews_rating  CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT fk_reviews_product  FOREIGN KEY (product_id)
        REFERENCES products (product_id)   ON DELETE CASCADE,
    CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Indexes (FK columns already get one automatically in InnoDB)
-- ---------------------------------------------------------------------
CREATE INDEX idx_orders_date      ON orders (order_date);
CREATE INDEX idx_orders_status    ON orders (status);
CREATE INDEX idx_customers_state  ON customers (state, city);
CREATE INDEX idx_products_price   ON products (price);

-- ---------------------------------------------------------------------
-- Helper view: one row per order with gross and net (after discount) value
-- ---------------------------------------------------------------------
CREATE VIEW v_order_summary AS
SELECT  o.order_id,
        o.customer_id,
        o.order_date,
        o.status,
        o.shipping_city,
        o.discount_pct,
        SUM(oi.quantity * oi.unit_price)                                   AS gross_amount,
        ROUND(SUM(oi.quantity * oi.unit_price) * (1 - o.discount_pct/100), 2) AS net_amount
FROM    orders o
JOIN    order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.status, o.shipping_city, o.discount_pct;
