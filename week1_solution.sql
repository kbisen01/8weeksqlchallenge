-- 1. What is the total amount each customer spent at the restaurant?
SELECT 
    customer_id, SUM(price)
FROM
    (SELECT 
        sales.customer_id, sales.product_id, menu.price
    FROM
        sales
    LEFT JOIN menu ON sales.product_id = menu.product_id) x
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT 
    customer_id, COUNT(DISTINCT (order_date))
FROM
    sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT 
    customer_id, product_id
FROM
    sales
GROUP BY customer_id
ORDER BY order_date;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT 
    product_id, product_name, total_sales
FROM
    (SELECT 
        sales.product_id,
            menu.product_name,
            COUNT(sales.product_id) AS total_sales
    FROM
        sales
    INNER JOIN menu ON sales.product_id = menu.product_id
    GROUP BY product_id) x
WHERE
    total_sales = (SELECT 
            MAX(total_sales)
        FROM
            (SELECT 
                sales.product_id,
                    menu.product_name,
                    COUNT(sales.product_id) AS total_sales
            FROM
                sales
            INNER JOIN menu ON sales.product_id = menu.product_id
            GROUP BY product_id) x);
            
-- 5. Which item was the most popular for each customer?
CREATE VIEW count_product AS
    (SELECT 
        customer_id, product_id, COUNT(product_id) AS quantity_sold
    FROM
        sales
    GROUP BY customer_id , product_id);
SELECT 
    s1.*
FROM
    count_product s1
        LEFT JOIN
    count_product s2 ON s1.customer_id = s2.customer_id
        AND s1.quantity_sold < s2.quantity_sold
WHERE
    s2.quantity_sold IS NULL;
    
-- 6. Which item was purchased first by the customer after they became a member?
SELECT 
    s1.customer_id,
    s1.join_date,
    s2.order_date,
    s2.product_id,
    s3.product_name
FROM
    members s1
        INNER JOIN
    sales s2 ON s1.customer_id = s2.customer_id
        AND s1.join_date <= s2.order_date
        LEFT JOIN
    menu s3 ON s2.product_id = s3.product_id
GROUP BY customer_id
ORDER BY order_date;

-- 7. Which item was purchased just before the customer became a member?
WITH before_joining AS
(SELECT 
    s1.customer_id,
    s1.join_date,
    s2.order_date,
    s2.product_id,
    s3.product_name,
    RANK() OVER(PARTITION BY customer_id ORDER BY order_date DESC) as ranking
FROM
    members s1
        INNER JOIN
    sales s2 ON s1.customer_id = s2.customer_id
        AND s1.join_date > s2.order_date
        LEFT JOIN
    menu s3 ON s2.product_id = s3.product_id)
SELECT customer_id, join_date, order_date, product_name  FROM before_joining
WHERE ranking = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
WITH temp_table AS
(SELECT s1.customer_id, s1.product_id, s1.order_date, s2.join_date, s3.price, 
count(s1.product_id) OVER(PARTITION BY customer_id) AS quantity_purchased,
 sum(s3.price) OVER(PARTITION BY customer_id) AS cumulative_amount
 FROM sales s1 JOIN members s2 ON s1.customer_id = s2.customer_id 
 AND s1.order_date < s2.join_date 
 JOIN menu s3 ON s1.product_id = s3.product_id)
 SELECT customer_id, quantity_purchased, cumulative_amount FROM temp_table
 GROUP BY customer_id;
 
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
 WITH point_table AS
(SELECT 
    s1.customer_id,
    s1.product_id,
    s2.product_name,
    s2.price,
    (IF(s2.product_name = 'sushi',
        s2.price * 20,
        s2.price * 10)) AS points
FROM
    sales s1
        JOIN
    menu s2 ON s1.product_id = s2.product_id)
SELECT 
	customer_id,
	sum(points) 
 FROM
	point_table
GROUP BY 
	customer_id;
    
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH point_table AS
(SELECT 
    s1.customer_id,
    s1.product_id,
    s1.order_date,
    s2.join_date,
    s3.product_name,
    s3.price,
    IF(s2.join_date <= s1.order_date
        AND s1.order_date <= DATE_ADD(s2.join_date, INTERVAL 1 WEEK)
            OR s3.product_name = 'sushi',
        s3.price * 20,
        s3.price * 10) AS points
FROM
    sales s1
        JOIN
    members s2 ON s1.customer_id = s2.customer_id
        JOIN
    menu s3 ON s1.product_id = s3.product_id
    WHERE order_date < '2021-02-01')
    SELECT 
		customer_id, 
		join_date, 
		sum(points)
    FROM
		point_table
    GROUP BY 
		customer_id;
        
-- Bonus Query 1:
-- Creating View for further use:
CREATE VIEW member_sales AS
SELECT 
    s1.customer_id,
    s1.order_date,
    s2.product_name,
    s2.price,
    IF(s1.customer_id IN (SELECT 
                customer_id
            FROM
                members) AND s1.order_date >= s3.join_date,
        'Y',
        'N') AS member
FROM
    sales s1
        JOIN
    menu s2 ON s1.product_id = s2.product_id
		LEFT JOIN
	members s3 ON s1.customer_id = s3.customer_id
    ORDER BY customer_id, order_date;
    
-- Run this for Bonus Query 1 result table:
SELECT 
    *
FROM
    member_sales;
    
-- Bonus Query 2:
SELECT *, IF(member = 'Y',
	DENSE_RANK() 
	OVER(PARTITION BY member,customer_id ORDER BY order_date), NULL) as ranking 
FROM 
	member_sales
ORDER BY 
	customer_id, order_date;