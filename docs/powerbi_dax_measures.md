# Power BI DAX Measures

> **Status note (2026-07-01):** BigQuery mart SQL, local CSV exports, and this doc all now use a single canonical field name per metric (legacy duplicate aliases have been removed from the SQL). Rebuild the BigQuery tables from `sql/bigquery/`, then refresh the PBIX and Excel workbook, and re-bind any visual still pointing at an old field name before using these measures.

All measures reference the refreshed mart tables: `mart_executive_kpis`, `mart_profit_priority`, `mart_shipping_mode_performance`, `mart_lane_reliability`, `mart_market_efficiency`, `mart_customer_segments`, and `mart_opportunity_scenarios`.

The marts use business-friendly `snake_case` field names such as `sla_breach_rate_pct`, `profit_at_risk_usd`, and `recommended_action` — one name per metric, no duplicates. If a visual shows blank or errors after refresh, it's bound to a retired legacy name; see the field-name table in `docs/SQL_POWERBI_GUIDE.md` for the current canonical name.

---

## Page 1 — Executive Overview

Pull from the single-row `mart_executive_kpis` table. Use MAX() since there is exactly one row.

```dax
[Total Orders] =
MAX(mart_executive_kpis[total_orders])
```

```dax
[Overall Breach Rate %] =
MAX(mart_executive_kpis[sla_breach_rate_pct])
```

```dax
[High Value Profit at Risk] =
MAX(mart_executive_kpis[high_value_profit_at_risk_usd])
```

```dax
[Top 5 Lane Breach Share %] =
MAX(mart_executive_kpis[top_5_priority_lane_breach_share_pct])
```

**KPI card formatting measures** — these return formatted strings for card visuals:

```dax
[High Value PAR Label] =
"$" & FORMAT(MAX(mart_executive_kpis[high_value_profit_at_risk_usd]) / 1000000, "0.00") & "M"
```

```dax
[Breach Rate Label] =
FORMAT(MAX(mart_executive_kpis[sla_breach_rate_pct]), "0.0") & "%"
```

```dax
[Top Lane Concentration Label] =
FORMAT(MAX(mart_executive_kpis[top_5_priority_lane_breach_share_pct]), "0.0") & "%"
```

---

## Page 1 Supporting Measures - Profit Priority

Use `mart_profit_priority` and `mart_shipping_mode_performance` directly — columns are already aggregated, so most visuals just bind to columns. Add these measures for callouts.

```dax
[Q1 Profit at Risk] =
CALCULATE(
    SUM(mart_profit_priority[profit_at_risk_usd]),
    mart_profit_priority[profit_quartile] = 1
)
```

```dax
[Q1 Breach Rate %] =
CALCULATE(
    MAX(mart_profit_priority[sla_breach_rate_pct]),
    mart_profit_priority[profit_quartile] = 1
)
```

```dax
[Q4 Breach Rate %] =
CALCULATE(
    MAX(mart_profit_priority[sla_breach_rate_pct]),
    mart_profit_priority[profit_quartile] = 4
)
```

-- Use this to show how small the gap is between highest and lowest profit tiers:
```dax
[Breach Rate Gap (Q1 vs Q4)] =
[Q4 Breach Rate %] - [Q1 Breach Rate %]
```

**Profit tier sort order** — add a calculated column in `mart_profit_priority` so the quartile labels sort correctly in visuals:

```dax
Quartile Sort =
mart_profit_priority[profit_quartile]
```

Then in the visual, set `profit_tier` to sort by `Quartile Sort`.

---

## Page 2 - Service, Market & Customer Performance

Use `mart_market_efficiency` for the market charts and `mart_lane_reliability` for the lane table. No cross-table relationships needed.

```dax
[Europe Efficiency Gap] =
CALCULATE(
    MAX(mart_market_efficiency[profit_vs_volume_gap_pct]),
    mart_market_efficiency[market] = "Europe"
)
```

```dax
[Pacific Asia Efficiency Gap] =
CALCULATE(
    MAX(mart_market_efficiency[profit_vs_volume_gap_pct]),
    mart_market_efficiency[market] = "Pacific Asia"
)
```

```dax
[Total Profit at Risk (All Markets)] =
SUM(mart_market_efficiency[profit_at_risk_usd])
```

-- For the lane table callout — sum breach share from the top 5 MOST UNSTABLE
-- lanes. Use variability_priority_rank (deterministic ROW_NUMBER ranking by
-- delay_sd), NOT profit_risk_rank -- profit_risk_rank ranks by dollar
-- exposure, a different question. Using profit_risk_rank here was the
-- original bug: it silently answered "top 5 by profit risk" while the label
-- claimed "top 5 by variability/instability."
```dax
[Top 5 Lane Breach Concentration] =
CALCULATE(
    SUM(mart_lane_reliability[share_of_all_lane_breaches_pct]),
    mart_lane_reliability[variability_priority_rank] <= 5
)
```

**Efficiency gap conditional color** — add a calculated column in `mart_market_efficiency` to drive bar color:

```dax
Efficiency Direction =
IF(mart_market_efficiency[profit_vs_volume_gap_pct] > 0, "Over-converts", "Under-converts")
```

Use `Efficiency Direction` as a legend in the efficiency gap bar chart to show Europe green and Pacific Asia red.

---

## Page 3 - Lane Priority & Recommendations

Use `mart_opportunity_scenarios`. Bind directly to columns; no DAX measures are needed for most visuals.

**Do not sum across the three scenario rows.** They draw from overlapping
order populations (a single order can fall inside more than one scenario's
definition), so a combined "all three scenarios" total would double-count.
Show each scenario as its own card/row instead of building a combined-total
measure.

```dax
-- Card: orders in scope for a specific scenario (slice by scenario name)
[Scenario Orders In Scope] =
CALCULATE(
    MAX(mart_opportunity_scenarios[orders_in_scope]),
    mart_opportunity_scenarios[scenario] = SELECTEDVALUE(mart_opportunity_scenarios[scenario])
)
```

```dax
-- Card: profit exposure for a specific scenario
[Scenario Profit Exposure] =
CALCULATE(
    MAX(mart_opportunity_scenarios[modeled_profit_exposure_usd]),
    mart_opportunity_scenarios[scenario] = SELECTEDVALUE(mart_opportunity_scenarios[scenario])
)
```

Always display the `caveat` column text alongside any scenario number — it
carries the "modeled opportunity requiring pilot validation" framing that
must not be dropped when these figures are shown on a slide or dashboard.

---

## Page 2 Supporting Measures - SLA Promise Gap

Use `mart_sla_promise_gap` for the promise mismatch visual and `mart_monthly_trends` for the trend line.

```dax
-- Highlight the miscalibration gap for a selected shipping mode
[Promise Gap Days] =
MAX(mart_sla_promise_gap[avg_promise_gap_days])
```

```dax
-- Card: First Class miscalibration
[First Class Promise Gap] =
CALCULATE(
    MAX(mart_sla_promise_gap[avg_promise_gap_days]),
    mart_sla_promise_gap[shipping_mode] = "First Class"
)
```

```dax
-- Monthly trend: latest month breach rate
[Latest Month Breach Rate] =
CALCULATE(
    MAX(mart_monthly_trends[sla_breach_rate_pct]),
    mart_monthly_trends[order_month] = MAX(mart_monthly_trends[order_month])
)
```

**Key visual note — monthly trend:** the breach rate is flat at ~57% for all 37 months. Display this as a line chart with a constant reference line at 57.3%. The flatness IS the finding — it shows the problem is structural, not seasonal or execution-driven.

---

## Notes

- `mart_executive_kpis` is a single-row summary table. Always use MAX() or MIN() to pull values from it, never SUM().
- `mart_profit_priority` has 4 rows (one per quartile). Bind bar charts directly to `profit_tier` and the relevant metric column.
- `mart_lane_reliability` excludes lanes with fewer than 350 orders at order grain (already filtered in SQL). No further filtering needed in Power BI.
- First Class rows in `mart_lane_reliability` will show `delivery_variability_days = 0.00` and a 100% breach rate. This is a dataset artifact where all First Class orders share the same delay value. The SQL now assigns First Class to `recommended_action = "Review SLA Definition"` instead of folding it into Protect, Stabilize, Monitor, or Maintain, and excludes it from the NTILE threshold calculation used to classify every other lane. Exclude First Class from the variability visual or add an explicit disclosure note on the page.
- `variability_priority_rank` is the only column to use for "top 5 most unstable lanes" claims. `profit_risk_rank` ranks by dollar exposure — a different question — and must not be substituted in for variability claims.
