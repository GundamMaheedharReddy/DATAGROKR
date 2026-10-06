-- =====================================================================
-- 01_schema.sql  |  Star schema for the SQL Dimensional Report (Week 5)
-- Engine: MySQL 8.0+
-- =====================================================================
DROP DATABASE IF EXISTS sales_dw;
CREATE DATABASE sales_dw CHARACTER SET utf8mb4;
USE sales_dw;

-- ---------- DIMENSION: DATE ----------
CREATE TABLE dim_date (
    date_key      INT          NOT NULL PRIMARY KEY,   -- surrogate key: YYYYMMDD
    full_date     DATE         NOT NULL,
    day_of_month  TINYINT      NOT NULL,
    day_name      VARCHAR(10)  NOT NULL,
    is_weekend    TINYINT(1)   NOT NULL,
    month_num     TINYINT      NOT NULL,
    month_name    VARCHAR(10)  NOT NULL,
    quarter_num   TINYINT      NOT NULL,
    year_num      SMALLINT     NOT NULL,
    yr_month    CHAR(7)      NOT NULL,               -- 'YYYY-MM'
    UNIQUE KEY uq_full_date (full_date),
    KEY idx_yr_month (yr_month)
) ENGINE=InnoDB;

-- ---------- DIMENSION: CUSTOMER ----------
CREATE TABLE dim_customer (
    customer_key   INT AUTO_INCREMENT PRIMARY KEY,     -- surrogate key
    customer_id    VARCHAR(10)  NOT NULL,              -- business key
    customer_name  VARCHAR(80)  NOT NULL,
    segment        ENUM('Consumer','Corporate','Home Office') NOT NULL,
    city           VARCHAR(50)  NOT NULL,
    state          VARCHAR(50)  NOT NULL,
    region         VARCHAR(20)  NOT NULL,
    UNIQUE KEY uq_customer_id (customer_id)
) ENGINE=InnoDB;

-- ---------- DIMENSION: PRODUCT ----------
CREATE TABLE dim_product (
    product_key   INT AUTO_INCREMENT PRIMARY KEY,
    sku           VARCHAR(15)   NOT NULL,
    product_name  VARCHAR(80)   NOT NULL,
    category      VARCHAR(40)   NOT NULL,
    subcategory   VARCHAR(40)   NOT NULL,
    brand         VARCHAR(40)   NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    UNIQUE KEY uq_sku (sku),
    KEY idx_category (category)
) ENGINE=InnoDB;

-- ---------- DIMENSION: STORE ----------
CREATE TABLE dim_store (
    store_key   INT AUTO_INCREMENT PRIMARY KEY,
    store_name  VARCHAR(60) NOT NULL,
    city        VARCHAR(50) NOT NULL,
    state       VARCHAR(50) NOT NULL,
    region      VARCHAR(20) NOT NULL,
    channel     ENUM('Online','Retail') NOT NULL
) ENGINE=InnoDB;

-- ---------- FACT: SALES (grain = one product line on one order) ----------
CREATE TABLE fact_sales (
    sales_key       BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_key        INT           NOT NULL,
    customer_key    INT           NOT NULL,
    product_key     INT           NOT NULL,
    store_key       INT           NOT NULL,
    order_id        VARCHAR(15)   NOT NULL,            -- degenerate dimension
    quantity        INT           NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    discount_pct    DECIMAL(5,2)  NOT NULL DEFAULT 0,
    gross_amount    DECIMAL(12,2) NOT NULL,            -- quantity * unit_price
    discount_amount DECIMAL(12,2) NOT NULL,
    net_amount      DECIMAL(12,2) NOT NULL,            -- gross - discount
    CONSTRAINT fk_fs_date     FOREIGN KEY (date_key)     REFERENCES dim_date (date_key),
    CONSTRAINT fk_fs_customer FOREIGN KEY (customer_key) REFERENCES dim_customer (customer_key),
    CONSTRAINT fk_fs_product  FOREIGN KEY (product_key)  REFERENCES dim_product (product_key),
    CONSTRAINT fk_fs_store    FOREIGN KEY (store_key)    REFERENCES dim_store (store_key)
) ENGINE=InnoDB;
