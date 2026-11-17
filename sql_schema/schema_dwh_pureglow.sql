-- =============================================================================
-- SCRIPT DDL DATA WAREHOUSE (GALAXY SCHEMA) - PT PUREGLOW BEAUTY INDONESIA
-- Studi Kasus: D2C Skincare E-Commerce Business Intelligence (MTI ULM 2026)
-- Database Engine: MySQL 8.0+ / MariaDB
-- Structure: 3 Fact Tables, 6 Conformed Dimension Tables
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `dwh_pureglow` 
DEFAULT CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `dwh_pureglow`;

-- -----------------------------------------------------------------------------
-- 1. TABEL DIMENSI TERKONFORMASI (CONFORMED DIMENSION TABLES)
-- -----------------------------------------------------------------------------

-- 1.1 Dimensi Produk (dim_product)
DROP TABLE IF EXISTS `fact_sales`;
DROP TABLE IF EXISTS `fact_returns`;
DROP TABLE IF EXISTS `fact_reviews`;
DROP TABLE IF EXISTS `dim_product`;

CREATE TABLE `dim_product` (
    `product_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_sk_code` VARCHAR(50) NOT NULL UNIQUE,
    `product_name` VARCHAR(150) NOT NULL,
    `category` VARCHAR(50) NOT NULL,
    `subcategory` VARCHAR(50),
    `brand_name` VARCHAR(50) DEFAULT 'PureGlow',
    `unit_price_idr` DECIMAL(15,2) NOT NULL,
    `cogs_idr` DECIMAL(15,2) NOT NULL,
    `key_ingredients` TEXT,
    `skin_type_target` VARCHAR(100),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_product_category` (`category`),
    INDEX `idx_product_sk` (`product_sk_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensi Katalog Produk PureGlow & Pengayaan Dataset';

-- 1.2 Dimensi Pelanggan (dim_customer) - Mengakomodasi SCD Type 2
DROP TABLE IF EXISTS `dim_customer`;

CREATE TABLE `dim_customer` (
    `customer_id` INT AUTO_INCREMENT PRIMARY KEY,
    `customer_sk_code` VARCHAR(50) NOT NULL,
    `customer_name` VARCHAR(100) NOT NULL,
    `email` VARCHAR(100),
    `gender` ENUM('F', 'M', 'Other') DEFAULT 'F',
    `age` INT,
    `occupation` VARCHAR(100) COMMENT 'Pengayaan Demografi',
    `city` VARCHAR(100),
    `province` VARCHAR(100),
    `acquisition_channel` VARCHAR(50),
    `scd_start_date` DATE NOT NULL,
    `scd_end_date` DATE DEFAULT NULL,
    `is_current` TINYINT(1) DEFAULT 1,
    INDEX `idx_customer_sk` (`customer_sk_code`),
    INDEX `idx_customer_city` (`city`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensi Pelanggan dengan SCD Type 2';

-- 1.3 Dimensi Waktu / Waktu Transaksi (dim_date)
DROP TABLE IF EXISTS `dim_date`;

CREATE TABLE `dim_date` (
    `date_key` INT PRIMARY KEY COMMENT 'Format YYYYMMDD (Contoh: 20261015)',
    `full_date` DATE NOT NULL UNIQUE,
    `day_of_month` INT NOT NULL,
    `month_number` INT NOT NULL,
    `month_name` VARCHAR(20) NOT NULL,
    `quarter` VARCHAR(5) NOT NULL,
    `year_number` INT NOT NULL,
    `day_name` VARCHAR(20) NOT NULL,
    `is_weekend` TINYINT(1) DEFAULT 0,
    `is_holiday` TINYINT(1) DEFAULT 0,
    INDEX `idx_date_year_month` (`year_number`, `month_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensi Waktu Kalender OLAP';

-- 1.4 Dimensi Saluran Penjualan (dim_sales_channel)
DROP TABLE IF EXISTS `dim_sales_channel`;

CREATE TABLE `dim_sales_channel` (
    `channel_id` INT AUTO_INCREMENT PRIMARY KEY,
    `channel_code` VARCHAR(20) NOT NULL UNIQUE,
    `channel_name` VARCHAR(50) NOT NULL COMMENT 'Website D2C, Shopee, Tokopedia, TikTok Shop',
    `channel_type` ENUM('Direct D2C', 'Marketplace', 'Social Commerce') NOT NULL,
    `commission_rate` DECIMAL(5,2) DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensi Channel Penjualan E-Commerce';

-- 1.5 Dimensi Metode Pembayaran (dim_payment_method)
DROP TABLE IF EXISTS `dim_payment_method`;

CREATE TABLE `dim_payment_method` (
    `payment_method_id` INT AUTO_INCREMENT PRIMARY KEY,
    `payment_code` VARCHAR(20) NOT NULL UNIQUE,
    `payment_name` VARCHAR(50) NOT NULL COMMENT 'BCA Virtual Account, GoPay, QRIS, COD',
    `payment_category` ENUM('Virtual Account', 'E-Wallet', 'QRIS', 'COD', 'Credit Card') NOT NULL,
    `admin_fee_idr` DECIMAL(10,2) DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensi Kanal Pembayaran Transaksi';

-- 1.6 Dimensi Alasan Retur / Return Reason (dim_return_reason)
DROP TABLE IF EXISTS `dim_return_reason`;

CREATE TABLE `dim_return_reason` (
    `return_reason_id` INT AUTO_INCREMENT PRIMARY KEY,
    `reason_code` VARCHAR(20) NOT NULL UNIQUE,
    `reason_category` VARCHAR(50) NOT NULL COMMENT 'Produk Rusak, Salah Kategori, Kemasan Bocor, Iritasi Kulit',
    `severity_level` ENUM('Low', 'Medium', 'High', 'Critical') DEFAULT 'Medium'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Dimensi Alasan Retur Barang';


-- -----------------------------------------------------------------------------
-- 2. TABEL FAKTA (FACT TABLES) - GALAXY SCHEMA
-- -----------------------------------------------------------------------------

-- 2.1 Tabel Fakta Penjualan & Profitability (fact_sales)
CREATE TABLE `fact_sales` (
    `sales_fact_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `order_id` VARCHAR(50) NOT NULL,
    `order_item_id` VARCHAR(50) NOT NULL,
    
    -- Foreign Keys ke Conformed Dimensions
    `date_key` INT NOT NULL,
    `product_id` INT NOT NULL,
    `customer_id` INT NOT NULL,
    `channel_id` INT NOT NULL,
    `payment_method_id` INT NOT NULL,
    
    -- Ukuran / Metrics Penjualan & Finansial (IDR)
    `quantity` INT NOT NULL DEFAULT 1,
    `gross_sales_idr` DECIMAL(15,2) NOT NULL,
    `discount_amount_idr` DECIMAL(15,2) DEFAULT 0.00,
    `net_sales_idr` DECIMAL(15,2) NOT NULL,
    `total_cogs_idr` DECIMAL(15,2) NOT NULL,
    `shipping_fee_idr` DECIMAL(15,2) DEFAULT 0.00,
    `channel_commission_idr` DECIMAL(15,2) DEFAULT 0.00,
    `net_profit_idr` DECIMAL(15,2) NOT NULL COMMENT 'Net Sales - Total COGS - Commission',
    
    -- Constraints & Indexes
    CONSTRAINT `fk_sales_date` FOREIGN KEY (`date_key`) REFERENCES `dim_date` (`date_key`),
    CONSTRAINT `fk_sales_product` FOREIGN KEY (`product_id`) REFERENCES `dim_product` (`product_id`),
    CONSTRAINT `fk_sales_customer` FOREIGN KEY (`customer_id`) REFERENCES `dim_customer` (`customer_id`),
    CONSTRAINT `fk_sales_channel` FOREIGN KEY (`channel_id`) REFERENCES `dim_sales_channel` (`channel_id`),
    CONSTRAINT `fk_sales_payment` FOREIGN KEY (`payment_method_id`) REFERENCES `dim_payment_method` (`payment_method_id`),
    
    INDEX `idx_sales_order` (`order_id`),
    INDEX `idx_sales_date` (`date_key`),
    INDEX `idx_sales_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tabel Fakta Transaksi Penjualan & Margin Keuntungan';


-- 2.2 Tabel Fakta Retur Produk (fact_returns)
CREATE TABLE `fact_returns` (
    `return_fact_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `return_id` VARCHAR(50) NOT NULL,
    `order_id` VARCHAR(50) NOT NULL,
    
    -- Foreign Keys ke Conformed Dimensions
    `return_date_key` INT NOT NULL,
    `product_id` INT NOT NULL,
    `customer_id` INT NOT NULL,
    `channel_id` INT NOT NULL,
    `return_reason_id` INT NOT NULL,
    
    -- Ukuran / Metrics Retur
    `returned_quantity` INT NOT NULL DEFAULT 1,
    `refund_amount_idr` DECIMAL(15,2) NOT NULL,
    `restocking_cost_idr` DECIMAL(15,2) DEFAULT 0.00,
    `is_resellable` TINYINT(1) DEFAULT 0,
    
    -- Constraints & Indexes
    CONSTRAINT `fk_returns_date` FOREIGN KEY (`return_date_key`) REFERENCES `dim_date` (`date_key`),
    CONSTRAINT `fk_returns_product` FOREIGN KEY (`product_id`) REFERENCES `dim_product` (`product_id`),
    CONSTRAINT `fk_returns_customer` FOREIGN KEY (`customer_id`) REFERENCES `dim_customer` (`customer_id`),
    CONSTRAINT `fk_returns_channel` FOREIGN KEY (`channel_id`) REFERENCES `dim_sales_channel` (`channel_id`),
    CONSTRAINT `fk_returns_reason` FOREIGN KEY (`return_reason_id`) REFERENCES `dim_return_reason` (`return_reason_id`),
    
    INDEX `idx_returns_date` (`return_date_key`),
    INDEX `idx_returns_reason` (`return_reason_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tabel Fakta Retur dan Pengembalian Barang';


-- 2.3 Tabel Fakta Ulasan Pelanggan (fact_reviews)
CREATE TABLE `fact_reviews` (
    `review_fact_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `review_id` VARCHAR(50) NOT NULL,
    
    -- Foreign Keys ke Conformed Dimensions
    `review_date_key` INT NOT NULL,
    `product_id` INT NOT NULL,
    `customer_id` INT NOT NULL,
    `channel_id` INT NOT NULL,
    
    -- Ukuran / Metrics Sentiment & Rating
    `rating_score` TINYINT NOT NULL COMMENT 'Skala 1 - 5 Star Rating',
    `review_text` TEXT,
    `sentiment_score` DECIMAL(4,3) COMMENT 'Skala -1.000 s.d +1.000 (NLP Sentiment)',
    `sentiment_category` ENUM('Positive', 'Neutral', 'Negative') DEFAULT 'Neutral',
    
    -- Constraints & Indexes
    CONSTRAINT `fk_reviews_date` FOREIGN KEY (`review_date_key`) REFERENCES `dim_date` (`date_key`),
    CONSTRAINT `fk_reviews_product` FOREIGN KEY (`product_id`) REFERENCES `dim_product` (`product_id`),
    CONSTRAINT `fk_reviews_customer` FOREIGN KEY (`customer_id`) REFERENCES `dim_customer` (`customer_id`),
    CONSTRAINT `fk_reviews_channel` FOREIGN KEY (`channel_id`) REFERENCES `dim_sales_channel` (`channel_id`),
    
    INDEX `idx_reviews_rating` (`rating_score`),
    INDEX `idx_reviews_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tabel Fakta Rating dan Sentimen Ulasan Produk';

-- =============================================================================
-- SELESAI: GALAXY SCHEMA DWH PT PUREGLOW BEAUTY INDONESIA
-- =============================================================================
