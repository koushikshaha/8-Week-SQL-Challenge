# Case Study #1 — Danny's Diner
### 8 Week SQL Challenge by Danny Ma

## Table of Contents
- [Problem Statement](#problem-statement)
- [Entity Relationship Diagram](#entity-relationship-diagram)
- [Data Exploration](#data-exploration)
- [Questions & Solutions](#questions--solutions)
- [Bonus Questions](#bonus-questions)
- [Key Learnings](#key-learnings)

---

## Problem Statement

Danny seriously loves Japanese food so at the beginning of 2021, he decided to open a cute little restaurant that sells his 3 favourite foods: **sushi**, **curry**, and **ramen**.

Danny wants to use the data to answer a few simple questions about his customers — their visiting patterns, how much money they've spent, and which menu items are their favourite. He plans to use these insights to deliver a better and more personalised experience for his loyal customers.

---

## Entity Relationship Diagram

![ERD](https://user-images.githubusercontent.com/81607668/127271130-dca9aedd-4ca9-4ed8-b6ec-1e1920dca4a8.png)

---

## Data Exploration

Before writing any business queries, I explored the raw tables to understand the data structure.

```sql
DESCRIBE sales;
DESCRIBE menu;
DESCRIBE members;

SELECT * FROM sales;
SELECT * FROM menu;
SELECT * FROM members;
```

**Findings:**
- All 3 tables are clean with no NULL values in key columns
- `order_date` and `join_date` are stored as DATE type — no casting needed
- No duplicate records found
- `sales` table has 15 rows, `menu` has 3 items, `members` has 2 customers

---

## Questions & Solutions

---

### Q1. What is the total amount each customer spent at the restaurant?

```sql
SELECT
    s.customer_id,
    SUM(m.price) AS total_spent
FROM sales s
INNER JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;
```

**Result:**

| customer_id | total_spent |
|---|---|
| A | 76 |
| B | 74 |
| C | 36 |

**Insight:** Customer A spent the most at $76, closely followed by B at $74. Customer C spent significantly less at $36.

---

### Q2. How many days has each customer visited the restaurant?

```sql
SELECT
    customer_id,
    COUNT(DISTINCT order_date) AS total_days
FROM sales
GROUP BY customer_id;
```

> `DISTINCT` is used on `order_date` because a customer can place multiple orders on the same day — we want unique visit days, not total orders.

**Result:**

| customer_id | total_days |
|---|---|
| A | 4 |
| B | 6 |
| C | 2 |

**Insight:** Customer B is the most frequent visitor with 6 unique visit days. Customer C visited only twice.

---

### Q3. What was the first item from the menu purchased by each customer?

```sql
WITH cte_sales AS (
    SELECT
        customer_id,
        product_id,
        DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS ranks
    FROM sales
)
SELECT
    s.customer_id,
    m.product_name
FROM cte_sales s
INNER JOIN menu m ON s.product_id = m.product_id
WHERE ranks = 1;
```

> `DENSE_RANK()` is used instead of `ROW_NUMBER()` because Customer A ordered two items on the same first date — using `ROW_NUMBER` would randomly drop one of them.

**Result:**

| customer_id | product_name |
|---|---|
| A | curry |
| A | sushi |
| B | curry |
| C | ramen |

**Insight:** Customer A ordered both curry and sushi on their very first visit. Customer B and C started with curry and ramen respectively.

---

### Q4. What is the most purchased item on the menu and how many times was it purchased by all customers?

```sql
SELECT
    m.product_name,
    COUNT(s.customer_id) AS total_orders
FROM sales s
INNER JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY total_orders DESC
LIMIT 1;
```

**Result:**

| product_name | total_orders |
|---|---|
| ramen | 8 |

**Insight:** Ramen is the most popular item on the menu, purchased 8 times across all customers.

---

### Q5. Which item was the most popular for each customer?

```sql
WITH item_count AS (
    SELECT
        s.customer_id,
        m.product_name,
        COUNT(*) AS total_orders
    FROM sales s
    JOIN menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
),
ranked AS (
    SELECT *,
           RANK() OVER(
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
```

> Two CTEs are chained here — first to count orders per customer per item, then to rank them. `RANK()` is used so tied items both appear (e.g. Customer B who likes all 3 equally).

**Result:**

| customer_id | product_name | total_orders |
|---|---|---|
| A | ramen | 3 |
| B | sushi | 2 |
| B | curry | 2 |
| B | ramen | 2 |
| C | ramen | 3 |

**Insight:** Ramen is the favourite for both A and C. Customer B enjoys all 3 menu items equally with 2 orders each — a true fan of everything!

---

### Q6. Which item was purchased first by the customer after they became a member?

```sql
WITH cte AS (
    SELECT
        s.customer_id,
        s.product_id,
        s.order_date,
        mn.product_name
    FROM sales s
    INNER JOIN members m ON m.customer_id = s.customer_id
    INNER JOIN menu mn ON s.product_id = mn.product_id
    WHERE s.order_date >= m.join_date
),
cte_ranks AS (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS rankss
    FROM cte
)
SELECT
    customer_id,
    product_name
FROM cte_ranks
WHERE rankss = 1;
```

> Filtered for orders on or after the join date, then ranked to get the very first one. Only members (A and B) appear since Customer C never joined.

**Result:**

| customer_id | product_name |
|---|---|
| A | curry |
| B | sushi |

**Insight:** After joining the loyalty program, Customer A first ordered curry and Customer B first ordered sushi.

---

### Q7. Which item was purchased just before the customer became a member?

```sql
WITH cte AS (
    SELECT
        s.customer_id,
        s.product_id,
        s.order_date,
        mn.product_name
    FROM sales s
    INNER JOIN members m ON m.customer_id = s.customer_id
    INNER JOIN menu mn ON s.product_id = mn.product_id
    WHERE s.order_date < m.join_date
),
cte_ranks AS (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS rankss
    FROM cte
)
SELECT
    customer_id,
    product_name
FROM cte_ranks
WHERE rankss = 1;
```

> Strict `<` is used (not `<=`) to exclude the join date itself. Orders are ranked in descending date order so `rankss = 1` gives the most recent order before membership.

**Result:**

| customer_id | product_name |
|---|---|
| A | sushi |
| B | sushi |

**Insight:** Both customers had sushi as their last order before joining — possibly what convinced them to become members!

---

### Q8. What is the total items and amount spent for each member before they became a member?

```sql
SELECT
    s.customer_id,
    COUNT(s.product_id) AS total_items,
    SUM(m.price) AS total_amount
FROM sales s
INNER JOIN menu m ON s.product_id = m.product_id
INNER JOIN members me ON me.customer_id = s.customer_id
WHERE s.order_date < me.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;
```

**Result:**

| customer_id | total_items | total_amount |
|---|---|---|
| A | 2 | 25 |
| B | 3 | 40 |

**Insight:** Before joining the program, Customer A made 2 purchases worth $25 and Customer B made 3 purchases worth $40.

---

### Q9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier — how many points would each customer have?

```sql
WITH cte_points AS (
    SELECT
        s.customer_id,
        m.product_name,
        SUM(price) AS total_spent,
        SUM(CASE m.product_name
                WHEN 'sushi' THEN price * 10 * 2
                ELSE price * 10
            END) AS points
    FROM sales s
    INNER JOIN menu m ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
)
SELECT
    customer_id,
    SUM(points) AS points
FROM cte_points
GROUP BY customer_id;
```

> `CASE WHEN` inside `SUM()` applies the 2x multiplier conditionally for sushi only. All other items earn the base 10 points per dollar.

**Result:**

| customer_id | points |
|---|---|
| A | 860 |
| B | 940 |
| C | 360 |

**Insight:** Customer B leads in points at 940 despite spending slightly less than A — because B purchased more sushi which earns double points.

---

### Q10. In the first week after joining (including join date), customers earn 2x points on all items — how many points do A and B have at end of January?

```sql
WITH cte_points AS (
    SELECT
        s.customer_id,
        m.product_name,
        SUM(price) AS total_spent,
        SUM(CASE
                WHEN s.order_date BETWEEN me.join_date
                     AND DATE_ADD(me.join_date, INTERVAL 6 DAY)
                THEN price * 10 * 2
                ELSE
                    CASE m.product_name
                        WHEN 'sushi' THEN price * 10 * 2
                        ELSE price * 10
                    END
            END) AS points
    FROM sales s
    INNER JOIN menu m ON s.product_id = m.product_id
    INNER JOIN members me ON s.customer_id = me.customer_id
    WHERE s.order_date BETWEEN '2021-01-01' AND '2021-01-31'
    GROUP BY s.customer_id, m.product_name
)
SELECT
    customer_id,
    SUM(points) AS points
FROM cte_points
GROUP BY customer_id;
```

> A nested `CASE` handles three tiers of logic:
> - **First week after joining** → all items earn `price * 10 * 2`
> - **Outside first week, sushi** → `price * 10 * 2`
> - **Outside first week, other items** → `price * 10`
>
> `DATE_ADD(join_date, INTERVAL 6 DAY)` gives a 7-day window including the join date itself. The `WHERE` clause limits results to January only.

**Result:**

| customer_id | points |
|---|---|
| A | 1370 |
| B | 820 |

**Insight:** Customer A earns significantly more points (1370 vs 820) in January thanks to more purchases falling within the first week 2x bonus window.

---

## Bonus Questions

### Join All The Things — Recreate the full customer journey table

```sql
SELECT
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN s.order_date < mb.join_date THEN 'N'
        WHEN s.order_date >= mb.join_date THEN 'Y'
        ELSE 'N'
    END AS member
FROM sales s
LEFT JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id;
```

> `LEFT JOIN` is used for both joins so Customer C (who is not a member) still appears in the output. The `ELSE 'N'` handles customers with no membership record at all.

**Result (sample):**

| customer_id | order_date | product_name | price | member |
|---|---|---|---|---|
| A | 2021-01-01 | sushi | 10 | N |
| A | 2021-01-01 | curry | 15 | N |
| A | 2021-01-07 | curry | 15 | Y |
| A | 2021-01-10 | ramen | 12 | Y |
| B | 2021-01-01 | curry | 15 | N |
| B | 2021-01-11 | sushi | 10 | Y |
| C | 2021-01-01 | ramen | 12 | N |

---

### Rank All The Things — Add ranking for member purchases only

```sql
WITH cte_combine AS (
    SELECT
        s.customer_id,
        s.order_date,
        m.product_name,
        m.price,
        CASE
            WHEN s.order_date < mb.join_date THEN 'N'
            WHEN s.order_date >= mb.join_date THEN 'Y'
            ELSE 'N'
        END AS member
    FROM sales s
    LEFT JOIN menu m ON s.product_id = m.product_id
    LEFT JOIN members mb ON s.customer_id = mb.customer_id
),
cte_ranks AS (
    SELECT *,
        CASE member
            WHEN 'Y' THEN ROW_NUMBER() OVER(
                            PARTITION BY customer_id, member
                            ORDER BY order_date)
            WHEN 'N' THEN NULL
        END AS ranking
    FROM cte_combine
)
SELECT * FROM cte_ranks;
```

> The CTE wrapper is necessary because MySQL does not allow window functions directly inside a `CASE WHEN`. The ranking is `NULL` for non-members and sequential for member purchases only.

**Result (sample):**

| customer_id | order_date | product_name | price | member | ranking |
|---|---|---|---|---|---|
| A | 2021-01-01 | sushi | 10 | N | NULL |
| A | 2021-01-01 | curry | 15 | N | NULL |
| A | 2021-01-07 | curry | 15 | Y | 1 |
| A | 2021-01-10 | ramen | 12 | Y | 2 |
| B | 2021-01-01 | curry | 15 | N | NULL |
| B | 2021-01-11 | sushi | 10 | Y | 1 |
| C | 2021-01-01 | ramen | 12 | N | NULL |

---

## Key Learnings

- Used **DENSE_RANK** over ROW_NUMBER when multiple items share the same earliest date (Q3)
- Chained **multiple CTEs** to break complex logic into readable steps (Q5, Q10, Bonus 2)
- Applied **nested CASE WHEN** inside SUM() for multi-tier conditional point calculations (Q10)
- Used **LEFT JOIN** to retain non-member customers in the full output (Bonus questions)
- Used strict `<` vs `>=` carefully when filtering around membership join dates (Q6 vs Q7)
- `DATE_ADD(join_date, INTERVAL 6 DAY)` gives a 7-day window including the start date (Q10)

---

*Solution by Koushik Sarker | [LinkedIn](https://www.linkedin.com/in/your-linkedin-url) | [GitHub](https://github.com/koushikshaha)*

*Case study by Danny Ma — [8weeksqlchallenge.com](https://8weeksqlchallenge.com/case-study-1/)*
