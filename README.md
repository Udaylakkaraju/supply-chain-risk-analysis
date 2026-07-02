# Supply Chain SLA Risk & Profit Protection Analytics

![BigQuery](https://img.shields.io/badge/SQL-BigQuery-4285F4?style=flat&logo=googlecloud&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Excel](https://img.shields.io/badge/Excel-217346?style=flat&logo=microsoftexcel&logoColor=white)

**A 65,752-order supply chain analysis that finds where SLA failures are hurting profit most, and where to intervene first.**

Built end-to-end: raw data → BigQuery SQL data model → Power BI report → Excel workbook.

---

## 30-Second Summary

Over half of all orders in this dataset miss their delivery promise. That's expensive — but not evenly expensive. This project answers one question:

> **Which orders, shipping modes, markets, and lanes should get fixed first to cut SLA failures and protect profit?**

The headline finding: **the network treats every order the same, regardless of how much profit is riding on it.** High-value orders get delivered just as unreliably as low-value ones. That's a fixable, prioritizable problem — and this project quantifies exactly where to start.

| Metric | Result |
|---|---:|
| Orders analyzed | 65,752 |
| SLA-breached orders | 37,698 (**57.3%**) |
| Total profit | $3.97M |
| Profit sitting on breached orders | $3.75M |
| Profit at risk in high-value breached orders | $2.31M |
| Breach share held by the worst 5 lanes | 41.2% |
| Second Class breach rate | 79.9% |

---

## The Story, in Three Findings

**1. The network is value-blind.** Orders were split into profit quartiles — the top 25% most profitable orders vs. the bottom 25%. If fulfillment were value-aware, the top quartile should see noticeably fewer breaches. It doesn't: breach rates sit within **1 percentage point of each other across every quartile** (56.8%–57.8%). $2.31M in profit from high-value orders is exposed to breaches that better routing could have avoided.

![High-profit orders get no fulfillment advantage](outputs/profit_quartile_breach.png)

**2. Second Class is the clearest fixable failure.** Every shipping mode was compared on what it *promises* vs. what it *actually delivers*. First Class technically shows a 100% breach rate, but that's a structural artifact of how its SLA is defined in the data (flagged separately, not treated as a real operational problem). Second Class is the real story: it promises 2 days, actually takes 4, and breaches **79.9%** of the time — while carrying real profit exposure ($1.01M).

![Second Class carries the clearest service-promise gap](outputs/shipping_mode_sla_gap.png)

**3. A small number of lanes cause most of the damage.** Every `market × shipping mode` combination ("operational lane") was ranked by breach rate, profit at risk, and delivery-time variability, then sorted into an action category: Protect, Stabilize, Monitor, Maintain, or Review SLA Definition. The **top 5 least stable lanes account for 41.2% of all grouped SLA breaches** — a small, addressable target instead of a vague "fix everything" mandate.

![Operational lane priority scatter](outputs/lane_priority_scatter.png)

**Bonus check — is this a recent problem or a long-standing one?** The breach rate has held steady in the 55–65% range for three straight years — this isn't a one-off bad quarter, it's a structural pattern.

![Monthly breach rate and profit-at-risk trend](outputs/monthly_trend.png)

---

## Quantified Opportunities

These are **modeled scenarios that require pilot validation** — not realized savings. They're presented that way on purpose: overclaiming certainty on a public dataset is a bigger credibility risk than being precise about what's proven vs. estimated.

| Scenario | Population | Modeled operational impact | Financial exposure |
|---|---:|---:|---:|
| One-day Second Class recovery | 12,778 orders | 2,531 breaches addressed, 2,531 delivery-days recovered | $253K addressed |
| High-value routing guardrail | 3,159 Q1 Second Class orders | 1,256 modeled avoidable breaches | $627K current exposure pool |
| Top-five lane stabilization | 30,150 orders | 3,097 breaches addressed at a 20% relative improvement | $309K addressed |

*An "operational lane" means a `market × shipping_mode` segment — the dataset doesn't include carrier-level physical routes.*

---

## How It Was Built

```text
Excel source / CSV
        |
        v
BigQuery raw table (order-item grain)
        |
        v
stg_orders  ->  int_orders (one row per order)
        |
        v
Power BI marts + opportunity scenarios
        |                     |
        v                     v
Excel analysis workbook    Power BI report
```

In plain terms: the raw data is one row per *order item* (multiple rows can belong to one order). SQL in BigQuery cleans and types the raw data (`stg_orders`), collapses it to one row per *order* (`int_orders`), then aggregates it into purpose-built summary tables ("marts") — one for executive KPIs, one for profit-tier analysis, one for lane reliability, and so on. Power BI and Excel both read from these same marts, so the numbers in the report, the workbook, and this README always agree.

**Why BigQuery + SQL instead of just Excel or Python?** The 180,519-row source is order-*item* grain, and profit/revenue values repeat across item rows within the same order — summing naively would overstate both. Getting the order-grain math right (using `SUM()` correctly instead of `MAX()`, using `NTILE()` for quartiles, `ROW_NUMBER()` for tie-broken lane rankings) is exactly the kind of correctness problem SQL is built to solve reliably and repeatably.

---

## What's in This Repo

| Deliverable | What it's for |
|---|---|
| `Supply_Chain_Operational_Analysis.xlsx` | Management-ready Excel workbook (Executive Summary, Profit Priority, Lanes, Market, Customer Segments, Opportunity Scenarios, Data Dictionary) |
| `supply chain.pbix` | The active Power BI report (3 pages, described below) |
| `sql/bigquery/` | Full transformation, analysis, and validation SQL, numbered in run order |
| `data/` | Refreshed mart exports (CSV) — one clean file per business question |
| `analysis/` | Query-by-query analytical log: exact SQL, result, and business interpretation for every material finding |
| `outputs/` | Chart images used in this README |
| `docs/` | Power BI DAX measures and the SQL → Power BI build guide |

## Power BI Report

Three pages, in a deliberate narrative order:

1. **Executive Summary & Profit Protection** — top-line KPIs and the value-blind thesis
2. **Service, Market & Customer Performance** — shipping mode SLA gaps and market/customer context
3. **Operational-Lane Priority & Recommendations** — the lane scatter and action-category recommendations

The signature visual is the lane-priority scatter (shown above): profit exposure × breach rate × order volume × recommended action, all in one view. Any "top 5 unstable" calculation uses `variability_priority_rank`, never `profit_risk_rank` — they answer different questions and aren't interchangeable.

## Excel Workbook

A compact workbook built from the corrected mart exports (not a duplicate of the 89MB raw source): Executive Summary, Data Quality & Reconciliation, Profit Priority, Shipping Modes, Operational Lanes, Market Analysis, Customer Segments, Opportunity Scenarios, Monthly Trends, SLA Promise Gap, and a Data Dictionary.

---

## BigQuery Data Model

Project: `supply-chain-analysis-492322` · Dataset: `supply_chain_analytics`

| Table | Grain | Purpose |
|---|---|---|
| `stg_orders` | Order item | Typed, cleaned source data |
| `int_orders` | Order | One row per order, additive profit/revenue |
| `mart_executive_kpis` | One row | Executive KPI cards |
| `mart_profit_priority` | Profit quartile | Value-protection analysis by profit tier |
| `mart_shipping_mode_performance` | Shipping mode | SLA and profit exposure by mode |
| `mart_lane_reliability` | Market-mode segment | Reliability ranking + recommended action |
| `mart_market_efficiency` | Market | Volume, profit, margin, efficiency |
| `mart_sla_promise_gap` | Shipping mode | Scheduled vs. actual delivery |
| `mart_monthly_trends` | Month | Breach-rate and exposure trend over time |
| `mart_customer_segments` | Customer segment | Commercial drill-down |
| `mart_opportunity_scenarios` | Scenario | The three quantified opportunities above |

**SQL techniques used** (kept concise and interview-explainable): `SAFE_CAST` + `CASE` + null guards for staging; `COUNTIF` and `SAFE_DIVIDE` for safe rate calculations; CTEs for readable multi-step transforms; `NTILE` for profit quartiles; `ROW_NUMBER` with deterministic tie-breakers for lane ranking; `SUM() OVER` for contribution shares; `STDDEV_POP` for delivery variability; `LAG` for month-over-month movement.

The order model uses `SUM(order_profit_per_order)` rather than `MAX()`, because profit values vary across the item rows within an order — `MAX()` would distort both total profit and value-tier exposure.

### Rebuild from scratch

```bash
bq query --use_legacy_sql=false < sql/bigquery/00_create_datasets.sql
bq query --use_legacy_sql=false < sql/bigquery/01_build_stg_orders.sql
bq query --use_legacy_sql=false < sql/bigquery/01c_build_int_orders.sql
bq query --use_legacy_sql=false < sql/bigquery/02_build_powerbi_marts.sql
bq query --use_legacy_sql=false < sql/bigquery/02b_build_mart_customer_segments.sql
bq query --use_legacy_sql=false < sql/bigquery/02c_build_mart_opportunity_scenarios.sql
bq query --use_legacy_sql=false < sql/bigquery/03_validate_outputs.sql
```

Run after loading the source CSV into `supply_chain_raw.orders`. `00b_prepare_table_rebuild.sql` is only needed if a legacy view conflicts with a table name. `sql/bigquery/maintenance/` holds one-off scripts (legacy-object cleanup, freshness checks, quick validation) that aren't part of the main rebuild sequence.

---

## Limitations

- Scenario results are estimates, not realized savings — every one is labeled as requiring pilot validation.
- First Class has a structural fixed-delay pattern in this dataset and is disclosed separately rather than folded into "normal" variability.
- Operational lanes are `market × shipping_mode` segments, not physical carrier routes — the dataset has no carrier-level routing data.
- The dataset doesn't include intervention costs, carrier contracts, or actual post-pilot outcomes, so financial exposure numbers are upper bounds on opportunity, not guaranteed savings.
- This analysis uses the public DataCo Supply Chain dataset (Kaggle) framed as a retailer's operational data — it's a self-directed analytics project, not a live deployment against a company's production data.
