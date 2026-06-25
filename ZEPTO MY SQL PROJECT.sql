-- ============================================================
--        ZEPTO E-COMMERCE SQL PROJECT
--        Based on Real Zepto Dataset (3732 rows)
--        Skills Covered: DDL, DML, DQL, Aggregations,
--        Subqueries, Window Functions, Views,
--        Stored Procedures, Indexes
-- ============================================================


-- ============================================================
-- PHASE 1: DATABASE & TABLE SETUP
-- ============================================================


DROP DATABASE IF EXISTS zepto_db;
CREATE DATABASE zepto_db;
USE zepto_db;

--  products table
CREATE TABLE products (
    product_id              INT AUTO_INCREMENT PRIMARY KEY,
    category                VARCHAR(100)   NOT NULL,
    name                    VARCHAR(255)   NOT NULL,
    mrp                     DECIMAL(10,2)  NOT NULL,
    discount_percent        INT            DEFAULT 0,
    available_quantity      INT            DEFAULT 0,
    discounted_price        DECIMAL(10,2)  NOT NULL,
    weight_in_gms           DECIMAL(10,2)  DEFAULT 0,
    out_of_stock            BOOLEAN        DEFAULT FALSE,
    quantity                INT            DEFAULT 1
);



LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/zepto_v1.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(category, name, mrp, discount_percent, available_quantity,
 discounted_price, weight_in_gms, @out_of_stock, quantity)
SET out_of_stock = IF(@out_of_stock = 'True', TRUE, FALSE);

-- Verifying data loaded correctly
SELECT COUNT(*) AS total_rows FROM products;
-- Expected output: 3732


-- ============================================================
-- PHASE 2: DATA QUALITY CHECKS
-- ============================================================

--  Looking for NULL values in all columns
SELECT 
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END)             AS null_names,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END)         AS null_category,
    SUM(CASE WHEN mrp IS NULL THEN 1 ELSE 0 END)              AS null_mrp,
    SUM(CASE WHEN discount_percent IS NULL THEN 1 ELSE 0 END) AS null_discount,
    SUM(CASE WHEN discounted_price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN out_of_stock IS NULL THEN 1 ELSE 0 END)     AS null_stock
FROM products;

--  Finding zero MRP records (invalid data)
SELECT COUNT(*) AS zero_mrp_count 
FROM products 
WHERE mrp = 0;


SET SQL_SAFE_UPDATES = 0;

--  deleting zero MRP records
DELETE FROM products 
WHERE mrp = 0;

SET SQL_SAFE_UPDATES = 1;

--  Verification
SELECT COUNT(*) AS total_after_cleaning FROM products;

-- Verifying row count after cleaning
SELECT COUNT(*) AS total_after_cleaning 
FROM products;

--  Data Preview (prices in rupees)
SELECT 
    product_id,
    category,
    name,
    ROUND(mrp / 100, 2)              AS mrp_rupees,
    discount_percent,
    ROUND(discounted_price / 100, 2) AS selling_price_rupees,
    weight_in_gms,
    out_of_stock
FROM products
LIMIT 10;


-- ============================================================
-- PHASE 3: DATA EXPLORATION
-- ============================================================

-- Explore 1: All distinct categories
SELECT DISTINCT category 
FROM products 
ORDER BY category;

-- Explore 2: Total products per category
SELECT 
    category,
    COUNT(*) AS total_products
FROM products
GROUP BY category
ORDER BY total_products DESC;

-- Explore 3: In stock vs Out of stock count
SELECT 
    out_of_stock,
    COUNT(*) AS total
FROM products
GROUP BY out_of_stock;

-- Explore 4: Products listed multiple times (multiple SKUs)
SELECT 
    name,
    COUNT(*) AS sku_count
FROM products
GROUP BY name
HAVING COUNT(*) > 1
ORDER BY sku_count DESC
LIMIT 10;


-- ============================================================
-- PHASE 4: BUSINESS ANALYSIS QUERIES
-- ============================================================

-- Q1: Top 10 products with highest discount percentage
SELECT 
    name,
    category,
    discount_percent,
    ROUND(mrp / 100, 2)              AS mrp_rupees,
    ROUND(discounted_price / 100, 2) AS selling_price_rupees,
    ROUND((mrp - discounted_price) / 100, 2) AS savings_rupees
FROM products
WHERE out_of_stock = FALSE
ORDER BY discount_percent DESC
LIMIT 10;

-- Q2: Expensive products (>₹300) that are Out of Stock (missed revenue)
SELECT 
    name,
    category,
    ROUND(mrp / 100, 2)              AS mrp_rupees,
    ROUND(discounted_price / 100, 2) AS selling_price_rupees,
    discount_percent
FROM products
WHERE out_of_stock = TRUE
AND discounted_price > 30000
ORDER BY discounted_price DESC;

-- Q3: Estimated total revenue per category
SELECT 
    category,
    COUNT(*)                                              AS total_products,
    ROUND(SUM(
        (discounted_price / 100) * available_quantity
    ), 2)                                                 AS estimated_revenue_rupees
FROM products
WHERE out_of_stock = FALSE
GROUP BY category
ORDER BY estimated_revenue_rupees DESC;

-- Q4: Popular products - High price but low discount (sell without promotions)
SELECT 
    name,
    category,
    ROUND(mrp / 100, 2)   AS mrp_rupees,
    discount_percent
FROM products
WHERE discounted_price > 30000
AND discount_percent < 5
AND out_of_stock = FALSE
ORDER BY mrp DESC
LIMIT 10;

-- Q5: Category with best average discount percentage
SELECT 
    category,
    ROUND(AVG(discount_percent), 2)       AS avg_discount,
    ROUND(AVG(mrp / 100), 2)             AS avg_mrp_rupees,
    ROUND(AVG(discounted_price / 100), 2) AS avg_selling_price
FROM products
GROUP BY category
ORDER BY avg_discount DESC;

-- Q6: Price per gram - Best value for money products
SELECT 
    name,
    category,
    ROUND(discounted_price / 100, 2)      AS price_rupees,
    weight_in_gms,
    ROUND((discounted_price / 100) 
          / weight_in_gms, 4)             AS price_per_gram
FROM products
WHERE weight_in_gms > 100
AND out_of_stock = FALSE
ORDER BY price_per_gram ASC
LIMIT 10;

-- Q7: Weight segmentation using CASE (for logistics & delivery)
SELECT 
    name,
    category,
    weight_in_gms,
    CASE
        WHEN weight_in_gms < 1000  THEN 'Low Weight'
        WHEN weight_in_gms < 5000  THEN 'Medium Weight'
        ELSE                            'Bulk'
    END                               AS weight_category
FROM products
ORDER BY weight_in_gms DESC;

-- Q8: Total inventory weight per category (warehouse planning)
SELECT 
    category,
    ROUND(SUM(weight_in_gms * available_quantity) 
          / 1000, 2)                  AS total_weight_kg,
    COUNT(*)                          AS total_products
FROM products
WHERE out_of_stock = FALSE
GROUP BY category
ORDER BY total_weight_kg DESC;

-- Q9: Stock summary per category with out-of-stock percentage
SELECT 
    category,
    COUNT(*)                                           AS total_products,
    SUM(out_of_stock = FALSE)                          AS in_stock,
    SUM(out_of_stock = TRUE)                           AS out_of_stock,
    ROUND(SUM(out_of_stock = TRUE) * 100.0 
          / COUNT(*), 2)                               AS out_of_stock_pct
FROM products
GROUP BY category
ORDER BY out_of_stock_pct DESC;

-- Q10: Price range buckets
SELECT 
    CASE
        WHEN discounted_price < 5000   THEN 'Under ₹50'
        WHEN discounted_price < 10000  THEN '₹50 - ₹100'
        WHEN discounted_price < 50000  THEN '₹100 - ₹500'
        ELSE                                'Above ₹500'
    END                AS price_range,
    COUNT(*)           AS total_products
FROM products
WHERE out_of_stock = FALSE
GROUP BY price_range
ORDER BY total_products DESC;

-- Q11: Most expensive product in each category (Subquery)
SELECT 
    category,
    name,
    ROUND(mrp / 100, 2) AS mrp_rupees
FROM products p1
WHERE mrp = (
    SELECT MAX(mrp)
    FROM products p2
    WHERE p2.category = p1.category
)
ORDER BY mrp DESC;

-- Q12: Total savings available per category
SELECT 
    category,
    ROUND(SUM((mrp - discounted_price) / 100), 2) AS total_savings_rupees,
    ROUND(SUM(mrp / 100), 2)                       AS total_mrp_rupees,
    ROUND(SUM(discounted_price / 100), 2)          AS total_selling_rupees
FROM products
WHERE out_of_stock = FALSE
GROUP BY category
ORDER BY total_savings_rupees DESC;


-- ============================================================
-- PHASE 5: ADVANCED QUERIES
-- ============================================================

-- A1: Rank products by price within each category (Window Function)
SELECT 
    category,
    name,
    ROUND(discounted_price / 100, 2)   AS selling_price_rupees,
    RANK() OVER (
        PARTITION BY category 
        ORDER BY discounted_price ASC
    )                                   AS price_rank
FROM products
WHERE out_of_stock = FALSE;

-- A2: Products with above average discount in their category
SELECT 
    name,
    category,
    discount_percent,
    ROUND(AVG(discount_percent) 
        OVER (PARTITION BY category), 2) AS category_avg_discount
FROM products
WHERE discount_percent > (
    SELECT AVG(discount_percent)
    FROM products p2
    WHERE p2.category = products.category
)
ORDER BY category, discount_percent DESC;

-- A3: Running total revenue by category (Window Function)
SELECT 
    category,
    name,
    ROUND(discounted_price / 100, 2) AS price,
    ROUND(SUM(discounted_price / 100) OVER (
        PARTITION BY category
        ORDER BY discounted_price
    ), 2)                             AS running_total
FROM products
WHERE out_of_stock = FALSE;

-- A4: Category health report (Complete summary)
SELECT 
    category,
    COUNT(*)                                          AS total_skus,
    SUM(out_of_stock = FALSE)                         AS available,
    SUM(out_of_stock = TRUE)                          AS unavailable,
    ROUND(AVG(discount_percent), 1)                   AS avg_discount,
    ROUND(MIN(discounted_price / 100), 2)             AS cheapest_rupees,
    ROUND(MAX(discounted_price / 100), 2)             AS costliest_rupees,
    ROUND(SUM((discounted_price/100) * available_quantity), 2) AS est_revenue
FROM products
GROUP BY category
ORDER BY est_revenue DESC;


-- ============================================================
-- PHASE 6: VIEWS
-- ============================================================

-- View 1: Product dashboard (reusable summary view)
CREATE VIEW product_dashboard AS
SELECT
    product_id,
    category,
    name,
    ROUND(mrp / 100, 2)              AS mrp_rupees,
    ROUND(discounted_price / 100, 2) AS selling_price,
    discount_percent,
    ROUND((mrp - discounted_price) / 100, 2) AS savings,
    weight_in_gms,
    CASE 
        WHEN out_of_stock = TRUE       THEN 'Out of Stock'
        WHEN available_quantity < 5    THEN 'Low Stock'
        ELSE                                'Available'
    END                              AS stock_status,
    CASE
        WHEN weight_in_gms < 1000     THEN 'Low Weight'
        WHEN weight_in_gms < 5000     THEN 'Medium Weight'
        ELSE                               'Bulk'
    END                              AS weight_category
FROM products;

-- Use the view:
SELECT * FROM product_dashboard;
SELECT * FROM product_dashboard WHERE stock_status = 'Out of Stock';
SELECT * FROM product_dashboard WHERE weight_category = 'Bulk';

-- View 2: Category revenue view
CREATE VIEW category_revenue AS
SELECT 
    category,
    COUNT(*)                                              AS total_products,
    ROUND(AVG(discount_percent), 2)                       AS avg_discount,
    ROUND(SUM((discounted_price/100) * available_quantity), 2) AS estimated_revenue
FROM products
WHERE out_of_stock = FALSE
GROUP BY category;

-- Use the view:
SELECT * FROM category_revenue ORDER BY estimated_revenue DESC;


-- ============================================================
-- PHASE 7: STORED PROCEDURES
-- ============================================================

-- SP1:  all products by category
DELIMITER //
CREATE PROCEDURE GetProductsByCategory(IN cat_name VARCHAR(100))
BEGIN
    SELECT 
        name,
        ROUND(mrp / 100, 2)              AS mrp_rupees,
        ROUND(discounted_price / 100, 2) AS selling_price,
        discount_percent,
        available_quantity,
        out_of_stock
    FROM products
    WHERE category = cat_name
    ORDER BY discounted_price ASC;
END //
DELIMITER ;

-- Use it:
CALL GetProductsByCategory('Beverages');
CALL GetProductsByCategory('Munchies');
CALL GetProductsByCategory('Fruits & Vegetables');

-- SP2:  top deals above a minimum discount
DELIMITER //
CREATE PROCEDURE GetTopDeals(IN min_discount INT)
BEGIN
    SELECT 
        name,
        category,
        discount_percent,
        ROUND(mrp / 100, 2)                      AS mrp_rupees,
        ROUND(discounted_price / 100, 2)          AS selling_price,
        ROUND((mrp - discounted_price) / 100, 2)  AS savings
    FROM products
    WHERE discount_percent >= min_discount
    AND out_of_stock = FALSE
    ORDER BY discount_percent DESC;
END //
DELIMITER ;

-- Use it:
CALL GetTopDeals(20);
CALL GetTopDeals(30);
CALL GetTopDeals(40);

-- SP3:  products within a price range
DELIMITER //
CREATE PROCEDURE GetProductsByPriceRange(
    IN min_price DECIMAL(10,2),
    IN max_price DECIMAL(10,2)
)
BEGIN
    SELECT 
        name,
        category,
        ROUND(discounted_price / 100, 2) AS selling_price_rupees,
        discount_percent,
        weight_in_gms
    FROM products
    WHERE (discounted_price / 100) BETWEEN min_price AND max_price
    AND out_of_stock = FALSE
    ORDER BY discounted_price ASC;
END //
DELIMITER ;

-- Use it (find products between ₹50 and ₹200):
CALL GetProductsByPriceRange(50, 200);


-- ============================================================
-- PHASE 8: INDEXES (Performance Optimization)
-- ============================================================

-- Index on category (speeds up category-based queries)
CREATE INDEX idx_category 
ON products(category);

-- Index on discount_percent (speeds up discount filtering)
CREATE INDEX idx_discount 
ON products(discount_percent);

-- Index on out_of_stock (speeds up stock filtering)
CREATE INDEX idx_stock 
ON products(out_of_stock);

-- Index on discounted_price (speeds up price range queries)
CREATE INDEX idx_price 
ON products(discounted_price);

-- Verify all indexes
SHOW INDEXES FROM products;


-- ============================================================
-- BONUS: FINAL COMPLETE BUSINESS REPORT
-- ============================================================

-- Complete snapshot of the entire dataset
SELECT 
    'Total Products'        AS metric, COUNT(*)              AS value FROM products
UNION ALL
SELECT 
    'In Stock',                         SUM(out_of_stock = FALSE) FROM products
UNION ALL
SELECT 
    'Out of Stock',                     SUM(out_of_stock = TRUE)  FROM products
UNION ALL
SELECT 
    'Total Categories',                 COUNT(DISTINCT category)  FROM products
UNION ALL
SELECT 
    'Avg Discount %',                   ROUND(AVG(discount_percent), 2) FROM products
UNION ALL
SELECT 
    'Max Discount %',                   MAX(discount_percent)     FROM products
UNION ALL
SELECT 
    'Avg Price (Rupees)',               ROUND(AVG(discounted_price/100), 2) FROM products;

-- ============================================================
-- END OF ZEPTO SQL PROJECT
-- ============================================================