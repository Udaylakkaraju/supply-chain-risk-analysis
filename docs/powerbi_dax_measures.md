# Power BI DAX Measures

All measures assume the five BigQuery mart tables are connected directly in Power BI with no relationships between them (each mart is self-contained and pre-aggregated).

---

## Page 1 — Executive Overview

Pull from the single-row `mart_executive_kpis` table. Use MAX() since there is exactly one row.

```dax
[Total Orders] =
MAX(mart_executive_kpis[total_orders])
```

```dax
[Overall Breach Rate %] =
MAX(mart_executive_kpis[breach_rate_pct])
```

```dax
[High Value Profit at Risk] =
MAX(mart_executive_kpis[high_value_profit_at_risk])
```

```dax
[Top 5 Lane Breach Share %] =
MAX(mart_executive_kpis[top_5_unstable_lane_breach_share_pct])
```

**KPI card formatting measures** — these return formatted strings for card visuals:

```dax
[High Value PAR Label] =
"$" & FORMAT(MAX(mart_executive_kpis[high_value_profit_at_risk]) / 1000000, "0.00") & "M"
```

```dax
[Breach Rate Label] =
FORMAT(MAX(mart_executive_kpis[breach_rate_pct]), "0.0") & "%"
```

```dax
[Top Lane Concentration Label] =
FORMAT(MAX(mart_executive_kpis[top_5_unstable_lane_breach_share_pct]), "0.0") & "%"
```

---

## Page 2 — Fulfillment Priority Failure

Use `mart_profit_priority` and `mart_shipping_mode_performance` directly — columns are already aggregated, so most visuals just bind to columns. Add these measures for callouts.

```dax
[Q1 Profit at Risk] =
CALCULATE(
    SUM(mart_profit_priority[profit_at_risk]),
    mart_profit_priority[profit_quartile] = 1
)
```

```dax
[Q1 Breach Rate %] =
CALCULATE(
    MAX(mart_profit_priority[breach_rate_pct]),
    mart_profit_priority[profit_quartile] = 1
)
```

```dax
[Q4 Breach Rate %] =
CALCULATE(
    MAX(mart_profit_priority[breach_rate_pct]),
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

## Page 3 — Market Efficiency & Lane Risk

Use `mart_market_efficiency` for the market charts and `mart_lane_reliability` for the lane table. No cross-table relationships needed.

```dax
[Europe Efficiency Gap] =
CALCULATE(
    MAX(mart_market_efficiency[efficiency_gap_pct]),
    mart_market_efficiency[market] = "Europe"
)
```

```dax
[Pacific Asia Efficiency Gap] =
CALCULATE(
    MAX(mart_market_efficiency[efficiency_gap_pct]),
    mart_market_efficiency[market] = "Pacific Asia"
)
```

```dax
[Total Profit at Risk (All Markets)] =
SUM(mart_market_efficiency[profit_at_risk])
```

-- For the lane table callout — sum breach share from the top 5 lanes by profit_risk_rank:
```dax
[Top 5 Lane Breach Concentration] =
CALCULATE(
    SUM(mart_lane_reliability[breach_share_pct]),
    mart_lane_reliability[profit_risk_rank] <= 5
)
```

**Efficiency gap conditional color** — add a calculated column in `mart_market_efficiency` to drive bar color:

```dax
Efficiency Direction =
IF(mart_market_efficiency[efficiency_gap_pct] > 0, "Over-converts", "Under-converts")
```

Use `Efficiency Direction` as a legend in the efficiency gap bar chart to show Europe green and Pacific Asia red.

---

## Page 4 — Recommendations

No DAX needed. Use text boxes or card visuals with static content from `DASHBOARD_COPY_AND_METRICS.md`.

---

## Notes

- `mart_executive_kpis` is a single-row summary table. Always use MAX() or MIN() to pull values from it, never SUM().
- `mart_profit_priority` has 4 rows (one per quartile). Bind bar charts directly to `profit_tier` and the relevant metric column.
- `mart_lane_reliability` excludes lanes with fewer than 1000 orders (already filtered in SQL). No further filtering needed in Power BI.
- First Class rows in `mart_lane_reliability` will show `delay_sd = 0.00` and very high breach rates — this is a dataset artifact where all First Class orders share the same delay value. Exclude First Class from the variability visual or add a note on the page.
