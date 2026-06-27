# SQL and Power BI Build Guide

## Project Positioning

**Supply Chain SLA Risk & Profit Protection Analytics** is an analyst-friendly portfolio project built around SQL, BigQuery, Power BI, and Excel. Python is optional and only used as a light helper for CSV preparation or exports.

The main business question is:

> Which orders and lanes should operations prioritize to reduce SLA failures and protect profit?

## Final BigQuery Tables for Power BI

Use these tables from `supply_chain_analytics` in Power BI:

| Table | What it answers | Good Power BI visuals |
|---|---|---|
| `mart_executive_kpis` | What is the overall SLA and profit risk picture? | KPI cards |
| `mart_profit_priority` | Are high-profit orders being protected differently? | Bar chart by profit tier |
| `mart_shipping_mode_performance` | Where does the service promise break down? | Scheduled vs actual days, profit exposure by mode |
| `mart_lane_reliability` | Which market-mode lanes need intervention first? | Priority scatter, Pareto chart, heatmap |
| `mart_market_efficiency` | Which markets convert volume into profit efficiently? | Supporting market comparison |

## Analytical Story

1. **Value-Blind Fulfillment:** high-profit order lines receive no meaningful SLA advantage.
2. **Service-Promise Mismatch:** Second Class is the primary operational concern; First Class's fixed one-day delay is disclosed as a structural dataset artifact.
3. **Lane Reliability and Concentration:** market-mode lanes are prioritized using profit exposure, breach rate, and delivery variability.

## Operations Priority Matrix

Build a scatter plot from `mart_lane_reliability`:

- X-axis: `profit_at_risk`
- Y-axis: `breach_rate_pct`
- bubble size: `order_count`
- legend: `action_category`
- details: `market` and `shipping_mode`
- tooltip: `delay_sd`, `breach_count`, and `profit_risk_rank`

Add median reference lines for profit at risk and breach rate. The SQL action categories also incorporate `delay_sd`, so the color is a three-factor intervention recommendation rather than a two-axis label.

| Action | Meaning |
|---|---|
| Protect | High profit exposure and high breach rate |
| Stabilize | Elevated delivery variability |
| Monitor | Elevated profit exposure or breach rate |
| Maintain | Lower relative exposure and variability |

First Class lanes are assigned to Monitor because their fixed one-day delay produces a structural 100% breach rate in this dataset. They should be disclosed, not presented as evidence of operational underperformance.

## SQL Concepts Demonstrated

| Concept | Where it appears | Why it matters |
|---|---|---|
| `CREATE OR REPLACE TABLE` | Rebuild scripts | Makes tables easy to refresh |
| `SAFE_CAST` | `01_build_stg_orders.sql` | Handles messy raw data without breaking the query |
| `CASE` | Staging and labels | Turns raw fields into business-readable categories |
| `COUNTIF` | SLA breach counts | Counts only rows that match a condition |
| `SAFE_DIVIDE` | Rates and shares | Avoids divide-by-zero errors |
| `NTILE` | Profit quartiles | Segments orders by business value |
| `RANK` | Lane priority | Creates an operations priority list |
| `SUM() OVER` | Market and breach shares | Compares each segment to the total |
| `STDDEV_POP` | Lane reliability | Measures variability, not just averages |

## Run Order in BigQuery

1. Run:
   `sql/bigquery/00_create_datasets.sql`

2. Load `raw/cleaned_dataco_supplychain.csv` into:
   `supply-chain-analysis-492322.supply_chain_raw.orders`

3. Run:
   `sql/bigquery/01_build_stg_orders.sql`

   If BigQuery says `stg_orders` or a mart is currently a view, run:
   `sql/bigquery/00b_prepare_table_rebuild.sql`

4. Run:
   `sql/bigquery/02_build_powerbi_marts.sql`

5. Run:
   `sql/bigquery/03_validate_outputs.sql`

## Run with bq CLI

From the repo root:

```bash
bq query --use_legacy_sql=false < sql/bigquery/00_create_datasets.sql
bq query --use_legacy_sql=false < sql/bigquery/00b_prepare_table_rebuild.sql
bq query --use_legacy_sql=false < sql/bigquery/01_build_stg_orders.sql
bq query --use_legacy_sql=false < sql/bigquery/02_build_powerbi_marts.sql
bq query --use_legacy_sql=false < sql/bigquery/03_validate_outputs.sql
```

## Cleanup Rule

Do not delete BigQuery objects blindly. Use:

`sql/bigquery/99_review_cleanup_old_objects.sql`

That script lists current tables first and keeps all `DROP` statements commented out until you manually confirm what is safe to remove.

## Optional Python

Python is not part of the main analytics story. Keep it limited to small helper tasks such as converting the original Excel file to CSV before loading into BigQuery.
