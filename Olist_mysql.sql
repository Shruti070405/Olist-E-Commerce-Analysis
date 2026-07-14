use olist_store_analysis;

ALTER TABLE olist_sellers_dataset
RENAME COLUMN `ï»¿seller_id` TO seller_id;
ALTER TABLE product_category_name_translat
RENAME COLUMN `ï»¿product_category_name` TO product_category_name;
ALTER TABLE olist_products_dataset
RENAME COLUMN `ï»¿product_id` TO product_id;
ALTER TABLE olist_orders_dataset
RENAME COLUMN `ï»¿order_id` TO order_id;
ALTER TABLE olist_order_reviews_dataset
RENAME COLUMN `ï»¿review_id` TO review_id;
ALTER TABLE olist_order_payments_dataset
RENAME COLUMN `ï»¿order_id` TO order_id;
ALTER TABLE olist_customers_dataset
RENAME COLUMN `ï»¿customer_id` TO customer_id;
ALTER TABLE olist_order_items_dataset
RENAME COLUMN `ï»¿order_id` TO order_id;

ALTER TABLE olist_orders_dataset
ADD COLUMN order_purchase_date DATE;
SET SQL_SAFE_UPDATES = 1;
UPDATE olist_orders_dataset
SET order_purchase_date = STR_TO_DATE(order_purchase_timestamp, '%d/%m/%Y');
UPDATE olist_orders_dataset
SET order_delivered_customer_date = STR_TO_DATE(order_delivered_customer_date, '%d/%m/%Y %H:%i')
WHERE order_delivered_customer_date IS NOT NULL;

## 1-Total Orders
SELECT COUNT(DISTINCT order_id) AS total_orders FROM olist_orders_dataset;

## 2-Total Revenue
SELECT 
    concat(ROUND(SUM(p.payment_value) / 1000000, 2),'M') AS total_revenue_million
FROM olist_order_payments_dataset p
JOIN olist_orders_dataset o
    ON p.order_id = o.order_id
WHERE o.order_status = 'delivered';

## 3-Orders Month-wise
SELECT 
    YEAR(order_purchase_date) AS year,
    MONTH(order_purchase_date) AS month,
    COUNT(order_id) as Total_Orders
FROM olist_orders_dataset
GROUP BY year, month;

## 4-Weekday vs Weekend Orders (CASE)
SELECT 
    CASE 
        WHEN DAYOFWEEK(order_purchase_date) IN (1,7)
        THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
	CONCAT(Round(COUNT(order_id) / 1000,2),'K') AS total_orders
FROM olist_orders_dataset
GROUP BY day_type;

## 5 Order Revenue(View)
CREATE VIEW ord_revenue AS
SELECT 
    o.order_id,
    ROUND(SUM(p.payment_value) / 1000, 2) AS order_revenue  
FROM olist_orders_dataset o
JOIN olist_order_payments_dataset p ON o.order_id = p.order_id
GROUP BY o.order_id;

SELECT order_id,CONCAT(order_revenue, 'K') AS order_revenue
FROM ord_revenue
ORDER BY order_revenue DESC
LIMIT 10;

## 6-Above Average Orders
SELECT 
    order_id,
    concat((order_revenue),'K') AS order_revenue_display
FROM ord_revenue
WHERE order_revenue > (SELECT AVG(order_revenue) FROM ord_revenue)
ORDER BY order_revenue DESC;

## 7-Top 10 Product Categories by Sales
SELECT 
    pct.product_category_name_english AS category,
    CONCAT(ROUND(SUM(oi.price)/1000000, 2), 'M') AS revenue_display
FROM olist_order_items_dataset oi
JOIN olist_products_dataset p ON oi.product_id = p.product_id
JOIN product_category_name_translat pct
    ON p.product_category_name = pct.product_category_name
GROUP BY category
ORDER BY SUM(oi.price) DESC
LIMIT 10;

## 8-Average Delivery Time (Days)
SELECT 
     ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_date)), 2) AS avg_delivery_days
FROM olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL;

## 9-Late Delivery Percentage
SELECT 
    ROUND(
        SUM(
            CASE 
                WHEN order_delivered_customer_date > order_estimated_delivery_date
                THEN 1 ELSE 0
            END
        ) * 100 / COUNT(*), 2
    ) AS late_delivery_pct
FROM olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

## 10-Seller Performance
WITH seller_sales AS (
    SELECT 
        seller_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(price) AS revenue
    FROM olist_order_items_dataset
    GROUP BY seller_id )
SELECT *
FROM seller_sales
ORDER BY revenue DESC
LIMIT 10;

#11-Store Procedure
CALL sp_revenue_by_date('2016-11-01','2017-11-30');

#12-Total Orders Paid by Credit Card with 5-Star Reviews
SELECT 
    COUNT(order_id) AS total_orders
FROM olist_order_payments_dataset
WHERE payment_type = 'credit_card'
AND order_id IN
(
    SELECT order_id
    FROM olist_order_reviews_dataset
    WHERE review_score = 5
);

#13  Auto Delivery Status Trigger
SELECT order_id
FROM olist_order_reviews_dataset
WHERE review_score = 5;
describe olist_orders_dataset;

SHOW TRIGGERS LIKE 'olist_orders_dataset';

INSERT INTO olist_orders_dataset (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    order_purchase_date
)
VALUES (
    'test123',                      
    'cust001',                       
    NULL,                       -- order_status (trigger will set 'created')
    NOW(),                          
    NOW(),                            
    DATE_ADD(NOW(), INTERVAL 5 DAY),   
    DATE_ADD(NOW(), INTERVAL 7 DAY),   
    CURDATE()                           
);

SELECT order_id, order_status FROM olist_orders_dataset WHERE order_id = 'test123';
DELETE FROM olist_orders_dataset WHERE order_id = 'test123';

#14-On-Time vs Late Delivered Orders Count
SELECT
    CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date
        THEN 'On-Time Delivery'
        ELSE 'Late Delivery'
    END AS delivery_status,
    CONCAT(ROUND(COUNT(order_id)/1000, 2), 'K') AS total_orders
FROM olist_orders_dataset
WHERE order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status;


