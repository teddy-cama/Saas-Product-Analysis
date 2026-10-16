SELECT * FROM usage_monthly;

SELECT SUM(mrr) FROM mrr_monthly WHERE month_start = '2026-09-01';

WITH x AS (
  SELECT customer_id, month_start, mrr,
         LAG(mrr) OVER (PARTITION BY customer_id ORDER BY month_start) AS prev_mrr,
         LEAD(month_start) OVER (PARTITION BY customer_id ORDER BY month_start) AS next_month
  FROM mrr_monthly
)
SELECT customer_id, month_start, 'New' AS movement_type, mrr AS amount
FROM x WHERE prev_mrr IS NULL
UNION ALL
SELECT customer_id, month_start, 'Expansion', mrr - prev_mrr
FROM x WHERE prev_mrr IS NOT NULL AND mrr > prev_mrr
UNION ALL
SELECT customer_id, month_start, 'Contraction', mrr - prev_mrr
FROM x WHERE prev_mrr IS NOT NULL AND mrr < prev_mrr
UNION ALL
SELECT customer_id, (month_start + INTERVAL '1 month')::date, 'Churn', -mrr
FROM x WHERE next_month IS NULL AND month_start < DATE '2026-09-01';

WITH first_paid AS (
  SELECT customer_id, MIN(month_start) AS cohort FROM mrr_monthly GROUP BY customer_id
)
SELECT f.cohort,
       ((EXTRACT(YEAR FROM m.month_start) - EXTRACT(YEAR FROM f.cohort)) * 12
        + EXTRACT(MONTH FROM m.month_start) - EXTRACT(MONTH FROM f.cohort))::int AS months_since_start,
       COUNT(DISTINCT m.customer_id) AS customers
FROM mrr_monthly m
JOIN first_paid f ON f.customer_id = m.customer_id
GROUP BY f.cohort, months_since_start
ORDER BY f.cohort, months_since_start;