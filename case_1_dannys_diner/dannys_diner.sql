/* --------------------
   Case Study Questions
   --------------------*/

 use dannys_diner;

 DESCRIBE sales;
DESCRIBE menu;
DESCRIBE members;

SELECT * FROM sales;
SELECT * FROM menu;
SELECT * FROM members;

-- 1. What is the total amount each customer spent at the restaurant?

select
	s.customer_id,
	sum(m.price) as total_spent
from sales s
inner join menu m on s.product_id = m.product_id
group by 
	s.customer_id;

-- 2. How many days has each customer visited the restaurant?

select 
	customer_id,
	count(distinct order_date) as total_days
from sales
group by 
	customer_id;

-- 3. What was the first item from the menu purchased by each customer?

with cte_sales as 
	(select 
		customer_id, 
		product_id,
	 dense_rank() over(partition by customer_id order by order_date ) as ranks
	 from sales)

select 
	s.customer_id,
	m. product_name
from cte_sales s
inner join menu m on s.product_id = m. product_id
where ranks = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select 
	m.product_name,
	count(s.customer_id) as total_orders
from sales s
inner join menu m on s.product_id = m.product_id
group by
	m.product_name
order by
	total_orders desc
limit 1;

-- 5. Which item was the most popular for each customer?

WITH item_count AS (
    SELECT 
        s.customer_id,
        m.product_name,
        COUNT(*) AS total_orders
    FROM sales s
    JOIN menu m 
        ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
),
ranked AS (
    SELECT *,
           RANK() OVER (
               PARTITION BY customer_id 
               ORDER BY total_orders DESC
           ) AS rnk
    FROM item_count
)
SELECT 
    customer_id,
    product_name,
    total_orders
FROM ranked
 WHERE rnk = 1;

-- 6. Which item was purchased first by the customer after they became a member?

with cte as (
	select
		s.customer_id ,
		s.product_id,
		s.order_date,
		mn.product_name
	from sales s
	inner join members m on m.customer_id = s.customer_id
	inner join menu mn on s.product_id = mn.product_id
	where s.order_date >= m.join_date 
),
cte_ranks as (
	select 
		*,
		row_number() over(partition by customer_id order by order_date) as rankss
	from cte
)
select 
	customer_id,
	product_name
from cte_ranks
where rankss = 1 ;

-- 7. Which item was purchased just before the customer became a member?

with cte as (
	select
		s.customer_id ,
		s.product_id,
		s.order_date,
		mn.product_name
	from sales s
	inner join members m on m.customer_id = s.customer_id
	inner join menu mn on s.product_id = mn.product_id
	where s.order_date < m.join_date 
),

cte_ranks as (
	select 
		*,
		row_number() over(partition by customer_id order by order_date desc) as rankss
	from cte
)

select 
	customer_id,
	product_name

from cte_ranks
where rankss = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
select 
	s.customer_id,
	count(s.product_id) as total_item,
	sum(price) as total_amount
from sales s
inner join menu m on s.product_id = m.product_id 
inner join members me on me.customer_id = s.customer_id
where s.order_date< me.join_date
group by s.customer_id
order by s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier -how many points would each customer have?

with cte_points as 
(
	select 
		s.customer_id,
		m.product_name,
		sum(price) as total_spent,
		sum(case m.product_name
			 when "sushi" then price * 10*2
			 else price* 10
		 end) as points
	from sales s 
	inner join menu m on s.product_id = m.product_id
	group by 
		s.customer_id, 
		m.product_name
)

select 
	customer_id,
	sum(points) as point 
from cte_points
group by 
	customer_id;
    
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
with cte_points as 
(
	select 
		s.customer_id,
		m.product_name,
		sum(price) as total_spent,
		sum(case
               when s.order_date between me.join_date and date_add(join_date,interval 6 day) 
               then price *10*2
               else case m.product_name
					   when "sushi" then price * 10*2
			           else price* 10 
                       end
            end) as points
	from sales s 
	inner join menu m on s.product_id = m.product_id
    inner join members me on s.customer_id = me.customer_id
    where s.order_date between "2021-01-01" and "2021-01-31"
	group by 
		s.customer_id, 
		m.product_name
)

select 
	customer_id,
	sum(points) as point 
from cte_points
group by 
	customer_id;

-- ------------------------- bonus questions----------------------------
  -- JOIN ALL THE THINGS 
select 
	s.customer_id,
	s.order_date,
	m.product_name,
	m.price,
	case 
	when s.order_date < mb.join_date then 'N'
	when s.order_date >= mb.join_date then 'Y'
	else 'N'
	end as member
from sales s 
left join menu m on s.product_id = m. product_id
left join members mb on s.customer_id = mb.customer_id;

-- bouns questions rank all the things

with cte_combine as 
(
	select 
		s.customer_id,
		s.order_date,
		m.product_name,
		m.price,
		case 
		when s.order_date < mb.join_date then 'N'
		when s.order_date >= mb.join_date then 'Y'
		else 'N'
		end as member
	 from sales s 
	left join menu m on s.product_id = m. product_id
	left join members mb on s.customer_id = mb.customer_id

),

 cte_ranks as 
 (
	  select 
		  *,
		  case member
		  when "Y" then row_number() over(partition by customer_id,member order by order_date)  
		  when "N" then null
		  end as ranking
	  from cte_combine
 )
select * from cte_ranks
