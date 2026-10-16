# FlowDesk: SaaS Product Analytics (Excel, PostgreSQL, Power BI)

An end-to-end analytics project for a fictional SaaS company, built to **learn SaaS product analysis**. I used synthetic data and a step-by-step project guide, both created with Claude (Anthropic's AI assistant), and worked through the database, data model, measures and dashboards myself in the tools listed below.

**Headline:** monthly recurring revenue (MRR) grew from about $288K at the end of 2024 to $875K by September 2026, but almost all of that growth comes from new customers. Net revenue retention is below 100%, so existing customers shrink slightly each month.

> The data is synthetic. Treat the findings as practice in method, not as real business results.

![Executive Overview](Saas Product Analysis\screenshots and recordings\01_Executive Overview.png)

---

## The scenario

FlowDesk is a fictional project-management app. People start a free 14-day trial, and some convert to a paid plan (Starter, Pro or Business) billed per seat, monthly or annually. The data covers **Jan 2024 to Sep 2026**.

I played the company's first data analyst. The CEO's questions:

1. **Growth:** how much recurring revenue do we have, and how fast is it growing?
2. **Acquisition:** which channels bring customers who pay and stay, and what does each cost?
3. **Funnel:** where do trial users drop off before paying?
4. **Retention:** who leaves, when, and what do they have in common?
5. **Support:** does support quality relate to churn?

## Tools and skills

| Tool | What I used it for |
|---|---|
| **Excel** | Exploring the CSVs, pivot-table cross-checks of totals |
| **PostgreSQL + pgAdmin** | Table design, CSV import, SQL analysis (CTEs, window functions) |
| **Power BI (Power Query, DAX)** | Cleaning, data model, measures, five-page dashboard |

Skills practised: data cleaning, relational modelling, window functions (`LAG`, `LEAD`), DAX (`CALCULATE`, `DATEADD`, `USERELATIONSHIP`, `KEEPFILTERS`), SaaS metrics (MRR, NRR, churn, CAC, cohorts), dashboard design, and writing findings with a clear recommendation.

## Dataset

Seven CSV files in `data/`:

| File | One row is | Rows |
|---|---|---|
| `customers.csv` | a trial signup (company) | 3,683 |
| `mrr_monthly.csv` | a paying customer in one month | 11,159 |
| `subscriptions.csv` | a plan period | 1,431 |
| `usage_monthly.csv` | a customer in one month (seats, active users, sessions, projects) | 13,895 |
| `support_tickets.csv` | a support ticket | 5,684 |
| `marketing_spend.csv` | a channel in one month | 198 |
| `plans.csv` | a plan and its price per seat | 3 |

## How I built it

### 1. Excel: explore and sanity-check
- Opened each CSV, checked column types and obvious oddities.
- Built a pivot table of `mrr` by month and used it as an independent check on the later SQL and Power BI totals (Sep 2026 MRR should be **$875,203**).

### 2. PostgreSQL: load and transform
- Created a fresh `flowdesk` database, created the seven tables, imported the CSVs with pgAdmin, and verified row counts and total MRR.
- Wrote **MRR movements** (new, expansion, contraction, churn) with `LAG`/`LEAD` window functions, turning monthly snapshots into events.
- Wrote a **cohort retention** query by billing cycle (how many customers from each starting month are still paying n months later).

<details>
<summary>MRR movements query</summary>

```sql
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
```
</details>

### 3. Power BI: clean, model, measure, visualise
**Cleaning (Power Query)**

| Issue | Rows | Fix |
|---|---|---|
| Country spelled inconsistently (`USA`, `united states`, `UK`) | 78 | Standardised to `United States` and `United Kingdom` |
| Blank industry | 110 | Replaced with `Unknown` (kept the rows) |
| Duplicate customer IDs, orphan IDs | 0 | Checked, none found |

Added `signup_month`, `paid_month`, `Activation Status` and a sort-order column for company size. Created a small `Channels` table so `customers` and `marketing_spend` can filter by the same channel.

**Model**
- One Date table, marked as the date table, related to the monthly fact tables.
- The customer signup date relationship is inactive, switched on inside measures with `USERELATIONSHIP`. This avoids ambiguous filter paths and keeps funnel counts consistent.
- Calculated columns: `Churned Next Month` (for churn by segment) and `Customer Status` (Retained, Churned, Never paid).

**Measures:** MRR, ARR, ARPA, New / Expansion / Contraction / Churned MRR, NRR, GRR, logo churn, monthly churn rate, trial-to-paid, CAC and payback, adoption, retention curve, support metrics. "Latest month" versions drive the cards.

## The dashboard (5 pages)

| Page | Question it answers |
|---|---|
| Executive Overview | How big is revenue, how fast is it growing, and where does growth come from? |
| Acquisition and Funnel | Which channels convert best and cost least? Where do trials drop off? |
| Retention | When and why do customers leave? |
| Product Usage and Customer Health | Do customers use what they pay for, and does usage predict churn? |
| Customer Support | Is support steady, and do churned customers raise more tickets? |

| | |
|---|---|
| ![Acquisition](screenshots/02_acquisition_funnel.png) | ![Retention](screenshots/03_retention.png) |
| ![Usage](screenshots/04_product_usage.png) | ![Support](screenshots/05_customer_support.png) |

> Slicers change the charts but not the text boxes. The text on each page describes the period shown in the screenshot.

## Key findings

**1. Growth comes from new customers, not existing ones.** MRR was $288,445 (Dec 2024), $613,688 (Dec 2025) and $875,203 (Sep 2026), with 694 paying customers and about $1,261 per customer. In Sep 2026 new customers added $44,251 and existing customers added only $1,007, while $20,777 was lost to cancellations and downgrades. NRR was 97.7% and logo churn 2.1%.
*Recommendation:* focus on retention and on getting existing customers to add seats.

**2. Paid Ads is the most expensive and least sticky channel.**

| Channel | Trial to paid | CAC | Monthly churn |
|---|---|---|---|
| Referral | 33.9% | $1,047 | 1.5% |
| Content/Blog | 30.1% | $1,837 | 2.2% |
| Partner | 28.7% | $2,473 | 1.4% |
| Organic Search | 25.8% | $1,598 | 2.6% |
| Social Media | 22.4% | $3,730 | 2.7% |
| Paid Ads | 19.2% | $7,471 | 3.9% |

*Recommendation:* test moving part of the paid budget to referrals and content, and track CAC and six-month retention for a quarter.

**3. Activation in the first week matters most.** 41.3% of activated trials pay, against 6.3% of non-activated trials, and the gap holds in every company size. *Recommendation:* A/B test an improved onboarding flow.

**4. A few Business customers carry the revenue.** Business is 24% of customers but 79% of MRR; Starter is 35% of customers and 2% of MRR.

**5. Annual plans delay churn rather than prevent it.** Annual customers lose nobody until renewal, then about 17% leave at month 12. Monthly churn averages 3.2% for monthly plans and 1.0% for annual.

**6. Usage and support are early warning signs.** Churned customers used 66% of their paid seats against 80% for retained customers, and raised about 17% more tickets per customer-month (57.7 vs 49.2 per 100).

## Metrics at a glance

| Term | Meaning |
|---|---|
| MRR / ARR | Monthly recurring revenue / MRR x 12 |
| NRR | Revenue kept from last month's customers, including upgrades. Below 100% means existing customers shrink |
| Logo churn | Share of customers lost in a month |
| CAC | Marketing spend / new paying customers |
| Activation | Key action done in the first 7 days of the trial |
| Cohort retention | Share of a starting-month group still paying n months later |

## Assumptions and limitations

- **Synthetic data**, generated for this project.
- CAC counts marketing spend only (no salaries or tools). Payback assumes an 80% gross margin.
- Findings show **association, not cause**. For example, activated users may be more motivated to begin with. Only an A/B test could show whether onboarding changes help.
- Cohorts are small (about 260 customers per year), so differences of a few points can be noise. Channel rankings other than Paid Ads shift from year to year.
- Larger companies choose annual plans more often, so part of the monthly vs annual gap may be company size.
- Recent signups have had less time to convert, so conversion for the latest months is understated.

## Repository structure

```
├── README.md
├── data/          # the seven CSV files
├── sql/           # table creation, MRR movements, cohort retention
├── pbix/          # Power BI report
└── screenshots/   # dashboard images used above
```

## Reproducing it
1. Create a PostgreSQL database and run the table-creation script in `sql/`.
2. Import the CSVs from `data/`.
3. Run the SQL queries to produce `mrr_movements` and `cohort_retention`.
4. Open the `.pbix` file in Power BI Desktop and point the data sources to your files or database.

## What I learned
- How SaaS businesses measure growth: MRR bridges, NRR, churn, CAC and cohorts.
- Why a data model matters: relationships, inactive relationships and filter context decide whether numbers are right (I fixed several rate-above-100% and merged-year bugs this way).
- How to turn a chart into a finding with a recommendation and a caution.

## Next steps
- Rebuild the analysis on real data.
- Add an A/B test design for the onboarding recommendation.
- Add a customer health score using usage and ticket trends.

---

Built by Chris. Write-up and more projects: [LinkedIn link] | [Twitter/X link]
