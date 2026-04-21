# Supply Chain Prioritization & Risk Analysis
## Supply Chain Analytics Project — Full Context Document
**Last Updated:** April 2026 | **Status:** Core Build Complete → Final BQML Polishing
**Stack:** GCP (BigQuery + GCS) + dbt + Streamlit

---

## 1. WHO THIS PROJECT IS FOR

**Analyst:** Uday (MS Information Systems, Stevens Institute of Technology, Graduating May 2026)
**Target Role:** Entry-Level Data Analyst / BI Analyst
**Visa Status:** F1 (will require H1B)
**Goal:** Land a job by July 2026
**Project Purpose:** Portfolio project to demonstrate end-to-end analytical thinking, cloud data stack experience, and business impact — differentiated from typical entry-level portfolio work

---

## 2. THE ONE BUSINESS PROBLEM

> **"This supply chain is losing measurable profit and customers — but standard reports say performance is acceptable. The root cause is that operations are optimized for volume and averages, not value and consistency."**

Everything in this project serves this single thesis. This is not a collection of analyses — it is one argument with four pieces of evidence.

---

## 3. PROJECT TITLE

**Full Title:** "Supply Chain Prioritization & Risk Analysis"

**Short Title (for resume):** "Supply Chain SLA & Profit Risk Analytics"

**Why this title works:** It is specific, non-obvious, and signals that the analyst questions how metrics are defined — not just reports them. Recruiters rarely see this level of framing at entry level.

---

## 4. DATASET

**Name:** DataCo Supply Chain Dataset (Kaggle)
**File:** Cleaned_DataCo_SupplyChain.xlsx
**Size:** ~180,000 rows, 51 columns
**Time Period:** 2018 (order and shipping dates)

**Key Columns Used:**
- `Order Profit Per Order` — dollar profit per order (core metric)
- `Profit at Risk` — pre-calculated dollar column for delayed/at-risk orders
- `delay_Days` — calculated: actual shipping days minus scheduled
- `SLA_Breached` — Yes/No flag (pre-calculated)
- `Days for shipping (real)` vs `Days for shipment (scheduled)` — shipping promise gap
- `Delivery Status` — Late delivery, Advance shipping, Shipping on time, Canceled
- `Late_delivery_risk` — binary 0/1
- `Order Item Total` / `Sales per customer` — revenue metrics
- `Order Item Profit Ratio` — margin metric
- `Shipping Mode` — Standard Class, Second Class, First Class, Same Day
- `Market` / `Order Region` / `Order Country` — geographic segmentation
- `Customer Segment` — Consumer, Corporate, Home Office
- `Category Name` / `Department Name` / `Product Name` — product segmentation
- `Customer Id` + `Order Date` — for cohort/repeat purchase analysis
- `Order Status` — COMPLETE, PENDING, CANCELED, CLOSED
- `Type` — DEBIT, TRANSFER, CASH (payment type)
- `Order Month` — for time series analysis

**Columns already added during Excel work (keep these):**
- `delay_Days`
- `SLA_Breached`
- `Profit at Risk`
- `Order Month`

---

## 5. TECH STACK (FULLY LOCKED)

```
Google Cloud Storage / GCS (raw CSV storage)
    ↓
BigQuery (serverless SQL + data warehouse)
    ↓
dbt (transformation layer)
    ↓
Streamlit + Plotly (portfolio dashboard)
    ↓
GitHub (project code + README)
```

**Why this stack:**
- User has prior GCP experience — less setup friction
- BigQuery free tier: 10GB storage + 1TB queries/month — permanent, no trial expiry
- dbt with BigQuery is the most documented combination in the industry
- Streamlit keeps the project fully code-native and easy to publish
- BigQuery appears more in DA/BI job postings than Athena
- Streamlit Community Cloud gives a simple public portfolio deploy path
- GitHub = public repo that recruiters actually click on

**Why BigQuery beats Athena for this project:**
- Better web query editor (BigQuery console vs Athena console)
- dbt + BigQuery is the most documented combination in the industry
- No IAM complexity — GCP service account setup is simpler
- Permanent free tier vs Athena's pay-per-query model
- More commonly seen on DA/BI resumes and job descriptions

**Resume Skills Added:** `Google Cloud Storage · BigQuery · dbt · Streamlit · SQL`

---

## 6. PROJECT STRUCTURE — 4 CHAPTERS

The flow is a single logical progression:

```
DIAGNOSE → EXPAND → EXPLAIN → QUANTIFY + RECOMMEND
```

### Chapter 1 — DIAGNOSE: Fulfillment Prioritization Failure
**Core Question:** Are high-value orders being meaningfully prioritized?
**Thesis Contribution:** The system is not value-aware at the order level

**Analysis Layers:**
1. Profit-at-risk concentration by profit quartile
2. SLA breach rate: by order profit segment
3. Distribution of `Profit at Risk` across profit quartiles
4. Shipping mode usage: are high-profit orders getting premium shipping?
5. Segment breakdown: which markets/categories show the strongest hotspot pattern?

**Expected Outputs:**
- "High-value orders receive no meaningful fulfillment advantage"
- "High-value orders breach at nearly the same rate as low-value orders"
- "$[sum of Profit at Risk for breached high-value orders] in profit exposed due to fulfillment misalignment"
- Bar chart: Profit at risk by profit quartile
- Heatmap: profit quartile × shipping mode

---

### Chapter 2 — EXPAND: Market Misallocation
**Core Question:** Which markets convert volume into profit most efficiently?
**Thesis Contribution:** The market portfolio is broadly profitable, but efficiency is uneven

**Analysis Layers:**
1. Revenue vs net profit by market
2. Order volume % vs profit contribution % by market
3. SLA breach rate by market
4. Profit margin trend by market over Order Month
5. Market efficiency ranking

**Expected Outputs:**
- "Europe over-converts volume into profit"
- "Pacific Asia under-converts volume into profit"
- "Profit-at-risk is concentrated in the largest markets"
- Ranked table: volume share vs profit share
- Bar chart: profit-at-risk by market

---

### Chapter 3 — EXPLAIN: Variability Is The Hidden Driver
**Core Question:** Why do chapters 1 and 2 persist despite acceptable average metrics?
**Thesis Contribution:** The system reports averages — but variability is what's actually breaking operations

**Analysis Layers:**
1. Standard deviation of `delay_Days` by market and shipping mode
2. Average lead time vs std deviation — where the gap is largest
3. Coefficient of Variation (CV = std dev / mean) — identifying high-variance zones
4. High-variance market-mode combinations vs SLA breach rate
5. Lead time distribution: normal vs outlier-heavy markets

**Expected Outputs:**
- "Average delay looks acceptable at X days — but top 10% of delayed orders average Y days"
- "Market X has Xσ lead time variability — 3x higher than the global average"
- "XX% of SLA breaches come from just 4 market-mode combinations"
- Box plot / violin chart: Lead time distribution by market
- Heat map: Variability (std dev) by Market × Shipping Mode

---

### Chapter 4 — QUANTIFY + CONNECT: BigQuery ML Risk Prediction
**Core Question:** Can operational features predict SLA breach risk?
**Thesis Contribution:** The final chapter becomes predictive rather than inferentially weak and gives the story a practical close

**Analysis Layers:**
1. Use fulfillment features from Chapter 1 as model inputs
2. Use market efficiency signals from Chapter 2 as model inputs
3. Use variability signals from Chapter 3 as model inputs
4. Train a BigQuery ML boosted-tree classifier to predict SLA breach / late delivery
5. Evaluate predictive performance and feature importance

**Expected Outputs:**
- "The model reaches 0.741 ROC AUC on holdout data"
- "Scheduled shipping days and shipping mode are the strongest risk drivers"
- "BigQuery ML provides a technical differentiator inside the final chapter"
- "The chapter turns the earlier story into an actionable prediction model"
- Model evaluation metrics and feature importance

---

## 7. THREE CONCRETE RECOMMENDATIONS

Each recommendation has: a trigger, a specific action, and a measurable expected outcome.

### Recommendation 1 — Value-Based Fulfillment Routing
**Trigger:** Top 25% profit orders currently have no fulfillment priority advantage over low-value orders
**Action:** Implement routing rule — all orders above $[X profit threshold] automatically assigned Second Class or higher shipping mode
**Expected Outcome:** Protects a slice of the current $2.77M high-value profit-at-risk exposure. Even a 10% reduction in breached high-value profit would protect about $277K; larger reductions scale directly from that base.
**Who acts on this:** Head of Operations / Fulfillment Manager

### Recommendation 2 — Market Portfolio Rebalancing
**Trigger:** Market efficiency is uneven: Europe converts volume into profit better than expected (+1.64pp profit-share lift), while Pacific Asia under-converts volume (-1.24pp profit-share gap)
**Action:** Reduce order commitment in the weakest-converting lanes and reallocate capacity toward the best-converting regions
**Expected Outcome:** Improves portfolio mix by pushing volume toward higher-converting markets rather than chasing scale alone
**Who acts on this:** VP of Supply Chain / Commercial Strategy

### Recommendation 3 — Consistency-First SLA Management
**Trigger:** The top 5 highest-variance market-mode combinations account for 40.67% of grouped SLA breaches
**Action:** Cap Standard Class usage in the most unstable lanes and route high-risk combinations into more consistent service tiers
**Expected Outcome:** Lowers breach concentration in the most unstable routes and protects the highest share of operational reliability risk
**Who acts on this:** Logistics Manager / Regional Operations Lead

---

## 8. EXECUTIVE SUMMARY (THE ONE NUMBER)

> "Across fulfillment misalignment, market misallocation, and lead time variability — this analysis identifies $2.77M in high-value profit at risk, 40.67% breach concentration in the most unstable lanes, and a BigQuery ML model with 0.741 ROC AUC for breach-risk prediction."

This sentence is the project's closing statement and the core of the resume bullet.

---

## 9. RESUME BULLET (FILL IN X'S AFTER ANALYSIS)

> "Built an end-to-end supply chain analytics pipeline on GCP (Cloud Storage + BigQuery) with dbt transformation models and a Streamlit dashboard — identified $2.77M in high-value profit-at-risk, 40.67% SLA-breach concentration in unstable lanes, and a 0.741 ROC AUC breach-risk model across 180K+ orders"

---

## 10. EXECUTION PHASES

### Phase 1 — GCP Setup
- Open GCP Console → Create new project (e.g., `supplychain-analytics`)
- Enable APIs: BigQuery API, Cloud Storage API
- Create GCS bucket (e.g., `supplychain-raw-uday`) — region: us-central1
- Upload cleaned CSV to GCS bucket under `/raw/` folder
- Create a GCP Service Account with roles: BigQuery Admin + Storage Object Viewer
- Download service account JSON key (needed for dbt Cloud connection)

### Phase 2 — BigQuery Setup
- Open BigQuery console
- Create dataset: `supply_chain_raw` (for raw data)
- Create dataset: `supply_chain_analytics` (for dbt output models)
- Load CSV from GCS into BigQuery table: `supply_chain_raw.orders`
  - Use auto-detect schema OR manually define column types
- Validate with: `SELECT COUNT(*) FROM supply_chain_raw.orders` → expect ~180,000

### Phase 3 — dbt Cloud Setup
- Sign up: cloud.getdbt.com (free Developer tier)
- Create new project → select BigQuery as connection
- Upload service account JSON key
- Set dataset to `supply_chain_analytics`
- Connect to GitHub repo for version control
- Initialize project structure

### Phase 4 — dbt Models
Build in this order:
```
models/
├── staging/
│   └── stg_orders.sql              ← clean column names, cast types, filter nulls
├── intermediate/
│   ├── int_order_profitability.sql  ← profit quartile classification
│   ├── int_delivery_performance.sql ← delay metrics, SLA flags
│   └── int_customer_orders.sql      ← customer order sequencing (window functions)
└── marts/
    ├── fct_fulfillment_priority.sql ← Chapter 1: profit vs delay analysis
    ├── fct_market_performance.sql   ← Chapter 2: zombie market identification
    ├── fct_lead_time_variability.sql← Chapter 3: std dev, CV by market+mode
    └── fct_customer_impact.sql      ← Chapter 4: repeat purchase behavior
```

### Phase 5 — Streamlit Dashboard
**Page 1 — Executive Overview**
KPI cards: Total Orders, $2.77M High-Value Profit at Risk, 40.67% Breach Concentration in Top 5 Lanes, Europe vs Pacific Asia efficiency gap
Key visual: Thesis strip with the three strongest numbers; trend line of SLA breach rate over Order Month

**Page 2 — Fulfillment Priority Failure**
- Bar chart: Profit at risk by profit quartile
- Heatmap: profit quartile × shipping mode
- KPI: value-blind routing callout with high-profit breach exposure

**Page 3 — Market Misallocation**
- Grouped bars: volume share vs profit share
- Market efficiency ranking table, highlighting Europe (+1.64pp) and Pacific Asia (-1.24pp)

**Page 4 — Variability Analysis**
- Heat map: Lead time std dev by Market × Shipping Mode
- Box plot / distribution: Delay days by market
- KPI: Top 5 unstable lanes account for 40.67% of grouped SLA breaches

**Page 5 — Predicting Breach Risk**
- KPI cards: ROC AUC, accuracy, recall
- Feature-importance chart highlighting scheduled shipping days and shipping mode
- Top predicted-risk lane ranking table

**Page 6 — Recommendations**
Three recommendation cards with: problem → action → expected outcome → dollar/scenario impact

### Phase 6 — GitHub + Documentation
- Public repo: `supply-chain-prioritization-paradox`
- README.md: Project title, thesis, tech stack, key findings, Streamlit link, dataset source
- Include dbt lineage graph screenshot
- Include Streamlit dashboard screenshots

---

## 11. DBT PROJECT KEY DETAILS

**Adapter:** dbt-bigquery (official, first-class support)
**Target:** Google BigQuery
**Project:** supplychain-analytics (GCP project ID)
**Dataset:** supply_chain_analytics (for mart models)
**File format:** Native BigQuery tables
**Partitioning:** By order_date on fact tables (BigQuery partitioned tables)

**BigQuery-specific SQL notes:**
- Use `STDDEV_POP()` for variability analysis (supported natively)
- Use `DATE_DIFF()` for date calculations
- Use `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date)` for customer sequencing
- BigQuery is case-insensitive for column names but use snake_case consistently

**Data Quality Tests to add in schema.yml:**
- `not_null` on order_id, customer_id, order_profit_per_order
- `accepted_values` on sla_breached (Yes, No)
- `unique` on order_item_id

---

## 12. IMPORTANT CONSTRAINTS AND CAUTIONS

1. **Don't over-claim on numbers** — fill in X's with actual query results. A real "$47K" is more credible than a fabricated "$2M"
2. **Customer churn is inferred, not directly measured** — frame as "observed repeat purchase behavior" not "churn rate"
3. **Payment Type analysis was dropped** — signal may not be reliable enough to build a chapter around
4. **Demand-Supply Mismatch was dropped** — dataset has no supply/inventory data, cannot be built honestly
5. **Variability chapter requires std dev calculation** — this is a SQL aggregation, not Python; use `STDDEV_POP()` in BigQuery
6. **BigQuery column names** — use auto-detect schema when loading CSV, then rename columns to snake_case in the `stg_orders.sql` staging model using aliases
7. **Streamlit deployment** — use Streamlit Community Cloud or a similar public host; keep the app code-native and easy to share
8. **Public share link** — create a public portfolio link that recruiters can open without setup
9. **GCP free tier** — BigQuery: 10GB storage + 1TB queries/month free forever. GCS: 5GB free. More than enough for this project.

---

## 13. WHAT MAKES THIS STAND OUT

- Single clear thesis (not a collection of analyses)
- Non-obvious finding (profitable orders served last is counterintuitive)
- Modern cloud stack used by real companies (GCS + BigQuery + dbt)
- Dollar-backed recommendations (decision-ready, not just descriptive)
- Logical cause-effect chain across all four chapters
- dbt lineage graph + documentation = portfolio-grade engineering discipline
- Streamlit shareable link = recruiter can click and view immediately

---

## 14. SESSION HANDOFF NOTES

**Planning is 100% complete.** Do not re-plan. Move directly to execution.

Next immediate steps:
1. Open GCP Console → Create GCS bucket → Upload CSV to `/raw/`
2. BigQuery → Create datasets → Load `supply_chain_raw.orders` from GCS
3. Sign up for dbt Cloud → Connect to BigQuery (service account) → Link GitHub repo
4. Build dbt models in order: staging → intermediate → marts
5. Build the Streamlit app from the exported CSVs
6. Push to GitHub → Write README → Share the public Streamlit link

**Do not add more analyses. Do not change the project title. Do not re-scope.**
The plan is strong. Execution is what matters now.
