# Chapter 1: Fulfillment Prioritization Failure

## Current chapter takeaway

The strongest signal in this chapter is not that high-profit orders are heavily mistreated. It is that the network is **not meaningfully prioritizing value at all**. The hotspot evidence later reinforces that the most exposed value is concentrated in specific product and segment combinations.

What the evidence shows:
- profit-at-risk is highly concentrated in the top profit tier
- shipping mode allocation stays almost flat across value tiers
- the highest-value orders do not receive a clear service advantage

Best business framing right now:

> The network is value-blind rather than value-aware. High-profit orders are not clearly mistreated, but they are also not meaningfully protected despite carrying disproportionate profit exposure.

---

### C1-Q1: Average delay by profit quartile

**Question**

Are higher-profit orders delayed more or less than lower-profit orders?

**SQL**

```sql
SELECT
  profit_quartile,
  ROUND(AVG(delay_days), 2) AS avg_delay_days,
  COUNT(*) AS order_count
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_fulfillment_priority`
GROUP BY profit_quartile
ORDER BY profit_quartile;
```

**Result**

| profit_quartile | avg_delay_days | order_count |
|---|---:|---:|
| 1 | 0.56 | 45130 |
| 2 | 0.56 | 45130 |
| 3 | 0.57 | 45130 |
| 4 | 0.57 | 45129 |

**Business reading**

- Delay performance is nearly identical across profit tiers.
- The highest-profit quartile is only marginally better than the lowest-profit quartile.
- This does **not** support a strong claim that high-profit orders are being served last.

**Conclusion**

The delay metric is too flat to support a dramatic failure claim. Chapter 1 should be framed as **missing prioritization**, not severe anti-value bias.

---

### C1-Q2: SLA breach rate by profit quartile

**Question**

Do higher-profit orders breach SLA more or less often than lower-profit orders?

**SQL**

```sql
SELECT
  profit_quartile,
  COUNT(*) AS order_count,
  ROUND(100 * AVG(CASE WHEN sla_breached = 'Yes' THEN 1 ELSE 0 END), 2) AS sla_breach_rate_pct
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_fulfillment_priority`
GROUP BY profit_quartile
ORDER BY profit_quartile;
```

**Result**

| profit_quartile | order_count | sla_breach_rate_pct |
|---|---:|---:|
| 1 | 45130 | 57.08 |
| 2 | 45130 | 57.20 |
| 3 | 45130 | 57.25 |
| 4 | 45129 | 57.59 |

**Business reading**

- High-profit orders do slightly better than low-profit orders, but only by about half a percentage point.
- Operationally, this is too small to call a meaningful fulfillment priority advantage.
- The business implication is not "high-value orders are being ignored more"; it is "high-value orders are not being protected much better."

**Conclusion**

The system appears **value-neutral**, not value-prioritized.

---

### C1-Q3: Profit at risk in breached high-profit orders

**Question**

How much profit is exposed among the highest-profit quartile when those orders breach SLA?

**SQL**

```sql
SELECT
  ROUND(SUM(profit_at_risk), 2) AS total_profit_at_risk_high_value
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_fulfillment_priority`
WHERE profit_quartile = 1
  AND sla_breached = 'Yes';
```

**Result**

| total_profit_at_risk_high_value |
|---:|
| 2770884.62 |

**Business reading**

- Even without a dramatic prioritization gap, breached high-profit orders still expose **$2.77M** in profit at risk.
- This is the strongest Chapter 1 number so far because it quantifies why value-aware fulfillment should matter.

**Conclusion**

This is the clearest justification for a value-aware routing rule: the service logic is flat, but the exposure is not.

---

### C1-Q4: Market-level performance by profit quartile

**Question**

Does the prioritization signal appear within specific markets, even if it is weak globally?

**SQL**

```sql
SELECT
  market,
  profit_quartile,
  ROUND(AVG(delay_days), 2) AS avg_delay_days,
  ROUND(100 * AVG(CASE WHEN sla_breached = 'Yes' THEN 1 ELSE 0 END), 2) AS sla_breach_rate_pct,
  COUNT(*) AS order_count
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_fulfillment_priority`
GROUP BY market, profit_quartile
HAVING COUNT(*) > 1000
ORDER BY market, profit_quartile;
```

**Result**

| market | profit_quartile | avg_delay_days | sla_breach_rate_pct | order_count |
|---|---:|---:|---:|---:|
| Africa | 1 | 0.54 | 56.10 | 2806 |
| Africa | 2 | 0.58 | 56.55 | 2992 |
| Africa | 3 | 0.52 | 56.13 | 2959 |
| Africa | 4 | 0.59 | 58.42 | 2857 |
| Europe | 1 | 0.57 | 57.83 | 13288 |
| Europe | 2 | 0.56 | 57.35 | 12444 |
| Europe | 3 | 0.57 | 57.54 | 12149 |
| Europe | 4 | 0.58 | 58.01 | 12371 |
| LATAM | 1 | 0.55 | 56.65 | 12663 |
| LATAM | 2 | 0.54 | 56.45 | 13386 |
| LATAM | 3 | 0.59 | 57.62 | 12981 |
| LATAM | 4 | 0.55 | 57.39 | 12564 |
| Pacific Asia | 1 | 0.56 | 57.19 | 10102 |
| Pacific Asia | 2 | 0.58 | 57.88 | 9706 |
| Pacific Asia | 3 | 0.56 | 56.97 | 10444 |
| Pacific Asia | 4 | 0.58 | 57.27 | 11008 |
| USCA | 1 | 0.57 | 56.61 | 6271 |
| USCA | 2 | 0.58 | 57.72 | 6602 |
| USCA | 3 | 0.55 | 56.90 | 6597 |
| USCA | 4 | 0.57 | 57.34 | 6329 |

**Business reading**

- The global pattern remains mostly flat inside major markets.
- Africa shows a somewhat larger spread, but it is still not large enough to turn Chapter 1 into a dramatic "high-profit orders are served last" claim.
- Europe, LATAM, Pacific Asia, and USCA show mostly small and inconsistent differences across quartiles.

**Conclusion**

The prioritization gap does **not** look like a strong cross-market structural failure. Chapter 1 should stay focused on **lack of value-based prioritization**.

---

### C1-Q5: Shipping mode mix by profit quartile

**Question**

Are higher-profit orders getting premium shipping more often than lower-profit orders?

**SQL**

```sql
SELECT
  shipping_mode,
  profit_quartile,
  COUNT(*) AS order_count
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_fulfillment_priority`
GROUP BY shipping_mode, profit_quartile
ORDER BY shipping_mode, profit_quartile;
```

**Result**

| shipping_mode | profit_quartile | order_count |
|---|---:|---:|
| First Class | 1 | 7028 |
| First Class | 2 | 6925 |
| First Class | 3 | 6978 |
| First Class | 4 | 6883 |
| Same Day | 1 | 2378 |
| Same Day | 2 | 2418 |
| Same Day | 3 | 2499 |
| Same Day | 4 | 2442 |
| Second Class | 1 | 8723 |
| Second Class | 2 | 8872 |
| Second Class | 3 | 8849 |
| Second Class | 4 | 8772 |
| Standard Class | 1 | 27001 |
| Standard Class | 2 | 26915 |
| Standard Class | 3 | 26804 |
| Standard Class | 4 | 27032 |

**Business reading**

- Shipping mode distribution is nearly flat across all profit quartiles.
- High-profit orders are **not** being meaningfully routed to faster shipping tiers.
- This is one of the cleanest indicators that the current network is not using order value as a routing signal.

**Conclusion**

Shipping mode allocation appears **value-blind**.

---

## Chapter 1 final working statement

Use this wording unless later chapters change the story materially:

> Chapter 1 shows a lack of value-based prioritization. High-profit orders receive almost no measurable fulfillment advantage over low-profit orders, shipping mode allocation is nearly identical across value tiers, and breached high-value orders expose $2.77M in profit at risk. The hotspot evidence reinforces that the most exposed value is concentrated in Fishing, Cleats, and Consumer-heavy combinations.

