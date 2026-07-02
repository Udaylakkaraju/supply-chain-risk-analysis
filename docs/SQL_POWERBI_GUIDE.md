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
| `mart_sla_promise_gap` | Is the SLA promise itself miscalibrated? | Scheduled vs. actual days by mode |
| `mart_monthly_trends` | Is the breach rate seasonal or structural? | Line chart with a 57.3% reference line |
| `mart_customer_segments` | Do Consumer / Corporate / Home Office differ in risk? | Segment comparison |
| `mart_opportunity_scenarios` | What quantified, modeled actions could reduce exposure? | Scenario cards (never summed across rows — see DAX doc) |

> All tables above are built from `int_orders` (see `sql/bigquery/01c_build_int_orders.sql`), the single order-grain table that fixes the historical `MAX` vs `SUM` profit bug. As of 2026-07-01 every mart SQL script exposes exactly one canonical field name per metric (the legacy backward-compatibility aliases have been removed). **Before refreshing**, rerun the full `sql/bigquery/` sequence in BigQuery, then refresh both the `.pbix` and the Excel workbook and re-bind any visual, slicer, or formula still pointing at an old field name (see the field list below).

## Analytical Story

1. **Value-Blind Fulfillment:** high-profit order lines receive no meaningful SLA advantage.
2. **Service-Promise Mismatch:** Second Class is the primary operational concern; First Class's fixed one-day delay is disclosed as a structural dataset artifact.
3. **Lane Reliability and Concentration:** market-mode lanes are prioritized using profit exposure, breach rate, and delivery variability.

## Operations Priority Matrix

Build a scatter plot from `mart_lane_reliability`:

- X-axis: `profit_at_risk_usd`
- Y-axis: `sla_breach_rate_pct`
- bubble size: `orders`
- legend: `recommended_action`
- details: `market` and `shipping_mode`
- tooltip: `delivery_variability_days`, `sla_breached_orders`, `profit_risk_rank`, and `variability_priority_rank`

Add median reference lines for profit at risk and breach rate. The SQL recommendation categories also incorporate delivery variability, so the color is a three-factor intervention recommendation rather than a two-axis label.

| Action | Meaning |
|---|---|
| Protect | High profit exposure and high breach rate |
| Stabilize | Elevated delivery variability |
| Monitor | Elevated profit exposure or breach rate |
| Maintain | Lower relative exposure and variability |
| Review SLA Definition | First Class only — see note below |

First Class lanes are assigned to **Review SLA Definition**, not Monitor. Their fixed one-day delay produces a structural 100% breach rate and `delivery_variability_days = 0.00` in this dataset, a promise-definition artifact rather than genuine operational instability. Folding First Class into Monitor would mechanically distort the NTILE thresholds used to classify every other lane, so it is excluded from that calculation entirely and given its own category. Disclose it separately; never present it as evidence of operational underperformance.

**Ranking note:** `profit_risk_rank` ranks lanes by dollar exposure. `variability_priority_rank` ranks lanes by delay variability, with a fully deterministic tiebreak chain (`delivery_variability_days` -> breach count -> profit at risk -> market -> shipping mode) since several lanes have nearly identical variability. Any "top 5 most unstable lanes" claim must use `variability_priority_rank`, not `profit_risk_rank`; they answer different questions and are not interchangeable.

## Business-Friendly Field Names

The final marts keep `snake_case` because it refreshes cleanly in BigQuery, Power BI, and Excel, but the field names are intentionally more readable than raw warehouse names.

| Table | Key fields to use in Power BI |
|---|---|
| `mart_executive_kpis` | `total_orders`, `sla_breached_orders`, `sla_breach_rate_pct`, `profit_at_risk_usd`, `high_value_profit_at_risk_usd`, `top_5_priority_lane_breach_share_pct` |
| `mart_profit_priority` | `profit_tier`, `orders`, `sla_breach_rate_pct`, `avg_days_late`, `total_profit_usd`, `profit_at_risk_usd` |
| `mart_shipping_mode_performance` | `orders`, `sla_breach_rate_pct`, `avg_promised_delivery_days`, `avg_actual_delivery_days`, `avg_days_late`, `profit_at_risk_usd`, `service_risk_level`, `business_note` |
| `mart_lane_reliability` | `operational_lane`, `orders`, `sla_breach_rate_pct`, `share_of_all_lane_breaches_pct`, `delivery_variability_days`, `profit_at_risk_usd`, `recommended_action` |
| `mart_market_efficiency` | `orders`, `revenue_usd`, `profit_usd`, `profit_margin_pct`, `sla_breach_rate_pct`, `profit_vs_volume_gap_pct`, `profit_at_risk_usd` |
| `mart_sla_promise_gap` | `avg_promised_delivery_days`, `avg_actual_delivery_days`, `avg_promise_gap_days`, `suggested_sla_days`, `profit_at_risk_usd`, `root_cause_summary` |
| `mart_monthly_trends` | `orders`, `sla_breached_orders`, `sla_breach_rate_pct`, `profit_at_risk_usd`, `sla_breach_rate_mom_change_pct`, `profit_at_risk_mom_change_usd` |
| `mart_customer_segments` | `orders`, `sla_breach_rate_pct`, `revenue_usd`, `profit_usd`, `profit_at_risk_usd`, `order_volume_share_pct` |
| `mart_opportunity_scenarios` | `orders_in_scope`, `modeled_breaches_addressed`, `modeled_profit_exposure_usd`, `supporting_metric_label`, `supporting_metric_value` |

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

4. Build the shared order model:
   `sql/bigquery/01c_build_int_orders.sql`

5. Build the Power BI marts:
   - `sql/bigquery/02_build_powerbi_marts.sql`
   - `sql/bigquery/02b_build_mart_customer_segments.sql`
   - `sql/bigquery/02c_build_mart_opportunity_scenarios.sql`

6. Validate:
   `sql/bigquery/03_validate_outputs.sql`

## Run with bq CLI

From the repo root:

```bash
bq query --use_legacy_sql=false < sql/bigquery/00_create_datasets.sql
bq query --use_legacy_sql=false < sql/bigquery/00b_prepare_table_rebuild.sql
bq query --use_legacy_sql=false < sql/bigquery/01_build_stg_orders.sql
bq query --use_legacy_sql=false < sql/bigquery/01c_build_int_orders.sql
bq query --use_legacy_sql=false < sql/bigquery/02_build_powerbi_marts.sql
bq query --use_legacy_sql=false < sql/bigquery/02b_build_mart_customer_segments.sql
bq query --use_legacy_sql=false < sql/bigquery/02c_build_mart_opportunity_scenarios.sql
bq query --use_legacy_sql=false < sql/bigquery/03_validate_outputs.sql
```

## Cleanup Rule

Do not delete BigQuery objects blindly. Use:

`sql/bigquery/maintenance/99_review_cleanup_old_objects.sql`

That script lists current tables first and keeps all `DROP` statements comm