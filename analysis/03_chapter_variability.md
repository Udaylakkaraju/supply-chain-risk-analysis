# Chapter 3: Variability Is The Hidden Driver

## Current chapter takeaway

This chapter now has a credible core finding after validation.

What the validated results show:
- delay variability is concentrated in **Standard Class** and **Second Class**
- the top 5 highest-variance market-mode combinations account for about **40.67%** of grouped SLA breaches
- using **positive lateness only** makes the variability story much cleaner and avoids misleading CV values
- `Second Class` is the clearest high-instability tier across markets

Important interpretation note:
- `First Class` is deterministic in this dataset: every row has `delay_days = 1`, so it should not be used as evidence of operational variability
- `Standard Class` still matters, but it should be discussed using **positive lateness** rather than signed average delay

Best business framing right now:

> Variability is concentrated in a small set of market and shipping-mode combinations, especially in Second Class and parts of Standard Class. Average performance masks that concentration, and a few unstable combinations appear to drive a disproportionate share of SLA failures.

## Purpose

This file will capture the evidence that average metrics hide unstable operational performance and that variability is a more useful signal than central tendency alone.

## Planned analysis items

- standard deviation of delay by market and shipping mode
- coefficient of variation
- average lead time vs variability gap
- concentration of SLA breaches in high-variance market-mode combinations
- outlier-heavy market or route distributions

## Working hypotheses

- a small number of unstable routes may drive a disproportionate share of SLA failures
- averages may look acceptable while variability remains operationally costly
- variability may explain why market and fulfillment problems persist despite stable top-line summaries

---

### C3-Q1: Delay variability by market and shipping mode

**Question**

Which market and shipping-mode combinations show the highest delay variability and breach rates?

**SQL**

```sql
SELECT
  market,
  shipping_mode,
  COUNT(*) order_count,
  ROUND(AVG(delay_days), 2) avg_delay,
  ROUND(STDDEV_POP(delay_days), 2) delay_sd,
  ROUND(100 * AVG(IF(sla_breached = 'Yes', 1, 0)), 2) sla_breach_pct
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_lead_time_variability`
GROUP BY market, shipping_mode
HAVING order_count >= 1000
ORDER BY delay_sd DESC, order_count DESC;
```

**Result highlights**

| market | shipping_mode | order_count | avg_delay | delay_sd | sla_breach_pct |
|---|---|---:|---:|---:|---:|
| LATAM | Second Class | 9939 | 1.98 | 1.43 | 78.94 |
| LATAM | Standard Class | 31119 | -0.01 | 1.42 | 39.63 |
| Europe | Standard Class | 29740 | -0.01 | 1.42 | 39.91 |
| Pacific Asia | Standard Class | 24586 | -0.00 | 1.42 | 39.85 |
| Europe | Second Class | 9861 | 2.00 | 1.42 | 79.98 |
| USCA | Second Class | 5105 | 1.98 | 1.42 | 79.55 |
| Africa | Second Class | 2164 | 1.98 | 1.41 | 80.04 |
| Pacific Asia | Second Class | 8147 | 2.00 | 1.39 | 80.42 |
| Europe | First Class | 7892 | 1.00 | 0.00 | 100.00 |
| LATAM | First Class | 7886 | 1.00 | 0.00 | 100.00 |

**Business reading**

- The highest variability is concentrated in **Second Class** and **Standard Class**, not in Same Day.
- `Second Class` shows both high variability and extremely high breach rates, typically around **79% to 80%**.
- `Standard Class` shows similarly high variability with much lower average delay, suggesting a wider spread around zero rather than consistently late delivery.
- `First Class` is suspicious: every major market shows **1.00 avg delay**, **0.00 sd**, and **100% breach**, which looks more like a data-definition artifact than a believable operational pattern.

**Conclusion**

The chapter's core idea is viable: variability is concentrated in a small subset of market-mode combinations. However, some combinations appear too deterministic to accept without checking the underlying business logic of `delay_days` and `sla_breached`.

---

### C3-Q2: Coefficient of variation by market and shipping mode

**Question**

How unstable is each combination relative to its average delay?

**SQL**

```sql
SELECT
  market,
  shipping_mode,
  COUNT(*) order_count,
  ROUND(AVG(delay_days), 2) avg_delay,
  ROUND(STDDEV_POP(delay_days), 2) delay_sd,
  ROUND(SAFE_DIVIDE(STDDEV_POP(delay_days), NULLIF(AVG(delay_days), 0)), 2) cv
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_lead_time_variability`
GROUP BY market, shipping_mode
HAVING order_count >= 1000
ORDER BY cv DESC, delay_sd DESC;
```

**Result highlights**

| market | shipping_mode | order_count | avg_delay | delay_sd | cv |
|---|---|---:|---:|---:|---:|
| Africa | Standard Class | 7055 | 0.02 | 1.40 | 57.91 |
| Pacific Asia | Same Day | 2226 | 0.45 | 0.50 | 1.11 |
| USCA | Same Day | 1434 | 0.45 | 0.50 | 1.10 |
| Europe | Same Day | 2759 | 0.49 | 0.50 | 1.03 |
| LATAM | Same Day | 2650 | 0.51 | 0.50 | 0.98 |
| LATAM | Second Class | 9939 | 1.98 | 1.43 | 0.72 |
| Europe | Standard Class | 29740 | -0.01 | 1.42 | -139.71 |
| LATAM | Standard Class | 31119 | -0.01 | 1.42 | -280.57 |
| USCA | Standard Class | 15252 | -0.00 | 1.41 | -342.36 |
| Pacific Asia | Standard Class | 24586 | -0.00 | 1.42 | -396.75 |

**Business reading**

- Raw CV is **not reliable** when average delay is very close to zero or slightly negative.
- That is why Standard Class produces huge or negative CV values; the denominator is too small to support a stable interpretation.
- `Same Day` and `Second Class` CV values are more interpretable because their averages are meaningfully above zero.

**Conclusion**

Do **not** use the raw CV ranking in the final story without redefining the denominator. For final reporting, prefer:
- `delay_sd` alone, or
- CV on a non-signed lateness metric such as `GREATEST(delay_days, 0)`, or
- CV only where average delay is materially above zero

---

### C3-Q3: Share of SLA breaches from top-variance combinations

**Question**

How much of the grouped breach volume comes from the highest-variance market-mode combinations?

**SQL**

```sql
WITH x AS (
  SELECT
    market,
    shipping_mode,
    COUNT(*) order_count,
    STDDEV_POP(delay_days) delay_sd,
    SUM(IF(sla_breached = 'Yes', 1, 0)) breaches
  FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_lead_time_variability`
  GROUP BY market, shipping_mode
  HAVING order_count >= 1000
)
SELECT
  market,
  shipping_mode,
  order_count,
  ROUND(delay_sd, 2) delay_sd,
  breaches,
  ROUND(100 * SAFE_DIVIDE(breaches, SUM(breaches) OVER ()), 2) breach_share_pct
FROM x
QUALIFY ROW_NUMBER() OVER (ORDER BY delay_sd DESC) <= 5
ORDER BY delay_sd DESC;
```

**Result**

| market | shipping_mode | order_count | delay_sd | breaches | breach_share_pct |
|---|---|---:|---:|---:|---:|
| LATAM | Second Class | 9939 | 1.43 | 7846 | 7.61 |
| USCA | Second Class | 5105 | 1.42 | 4061 | 3.94 |
| Europe | Second Class | 9861 | 1.42 | 7887 | 7.65 |
| LATAM | Standard Class | 31119 | 1.42 | 12334 | 11.97 |
| Pacific Asia | Standard Class | 24586 | 1.42 | 9798 | 9.50 |

**Business reading**

- The top 5 highest-variance combinations contribute about **40.67%** of grouped SLA breaches.
- That concentration is meaningful and supports the idea that a relatively small set of operational lanes may drive a large share of disruption.
- The result is especially notable because both **Standard Class** and **Second Class** appear repeatedly in the top 5.

**Conclusion**

This is the strongest Chapter 3 result so far. Even with the metric caveat, it supports the central argument that variability is concentrated rather than evenly distributed.

---

### C3-V1: Distribution check by shipping mode

**Question**

Does the raw `delay_days` distribution explain the suspicious `First Class` and `Standard Class` results?

**SQL**

```sql
SELECT
  shipping_mode,
  MIN(delay_days) min_delay,
  ROUND(APPROX_QUANTILES(delay_days, 4)[OFFSET(1)], 2) q1,
  ROUND(APPROX_QUANTILES(delay_days, 4)[OFFSET(2)], 2) median,
  ROUND(APPROX_QUANTILES(delay_days, 4)[OFFSET(3)], 2) q3,
  MAX(delay_days) max_delay,
  ROUND(AVG(delay_days), 2) avg_delay,
  ROUND(STDDEV_POP(delay_days), 2) delay_sd,
  COUNT(*) order_count
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_lead_time_variability`
GROUP BY shipping_mode
ORDER BY shipping_mode;
```

**Result**

| shipping_mode | min_delay | q1 | median | q3 | max_delay | avg_delay | delay_sd | order_count |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| First Class | 1 | 1.00 | 1.00 | 1.00 | 1 | 1.00 | 0.00 | 27814 |
| Same Day | 0 | 0.00 | 0.00 | 1.00 | 1 | 0.48 | 0.50 | 9737 |
| Second Class | 0 | 1.00 | 2.00 | 3.00 | 4 | 1.99 | 1.42 | 35216 |
| Standard Class | -2 | -1.00 | 0.00 | 1.00 | 2 | -0.00 | 1.42 | 107752 |

**Business reading**

- `First Class` is fully deterministic in this dataset: every record has `delay_days = 1`.
- `Second Class` has a broad positive-delay spread from **0 to 4**, which explains its high average lateness and high variability.
- `Standard Class` is spread symmetrically around zero, which explains why signed average delay is near zero even though variation is large.

**Conclusion**

This validates the earlier caveat. `First Class` should be treated as a dataset rule artifact for variability purposes, and `Standard Class` should be analyzed with **positive lateness only**.

---

### C3-V2: Positive-lateness variability by market and shipping mode

**Question**

What does the variability story look like when we measure lateness only and avoid signed-delay distortion?

**SQL**

```sql
SELECT
  market,
  shipping_mode,
  COUNT(*) order_count,
  ROUND(AVG(GREATEST(delay_days, 0)), 2) avg_late_days,
  ROUND(STDDEV_POP(GREATEST(delay_days, 0)), 2) late_sd,
  ROUND(
    SAFE_DIVIDE(
      STDDEV_POP(GREATEST(delay_days, 0)),
      NULLIF(AVG(GREATEST(delay_days, 0)), 0)
    ),
    2
  ) cv_late
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_lead_time_variability`
GROUP BY market, shipping_mode
HAVING order_count >= 1000
ORDER BY late_sd DESC, cv_late DESC;
```

**Result highlights**

| market | shipping_mode | order_count | avg_late_days | late_sd | cv_late |
|---|---|---:|---:|---:|---:|
| LATAM | Second Class | 9939 | 1.98 | 1.43 | 0.72 |
| USCA | Second Class | 5105 | 1.98 | 1.42 | 0.72 |
| Europe | Second Class | 9861 | 2.00 | 1.42 | 0.71 |
| Africa | Second Class | 2164 | 1.98 | 1.41 | 0.71 |
| Pacific Asia | Second Class | 8147 | 2.00 | 1.39 | 0.70 |
| USCA | Standard Class | 15252 | 0.60 | 0.80 | 1.34 |
| LATAM | Standard Class | 31119 | 0.60 | 0.80 | 1.34 |
| Pacific Asia | Standard Class | 24586 | 0.60 | 0.80 | 1.34 |
| Africa | Standard Class | 7055 | 0.60 | 0.80 | 1.33 |
| Europe | Standard Class | 29740 | 0.60 | 0.80 | 1.33 |

**Business reading**

- The positive-lateness version makes the chapter much cleaner.
- `Second Class` is the most consistently unstable tier in absolute terms, with around **2 late days** on average and **~1.4** standard deviation across all major markets.
- `Standard Class` shows lower absolute late days but higher relative instability once lateness occurs.
- `Same Day` is less severe, and `First Class` remains deterministic rather than variable.

**Conclusion**

This is the better final metric set for Chapter 3. It preserves the concentration story while removing the distortion caused by negative or near-zero signed delay averages.

---

## Validation note before final presentation

Validated decisions for final use:

1. Treat `First Class` as deterministic in this dataset and exclude it from variability storytelling.
2. Use **positive lateness only** for CV-style discussion.
3. Use `delay_sd` and grouped breach concentration as the primary Chapter 3 evidence.

---

## Chapter 3 final working statement

Use this wording for now:

> Chapter 3 shows that operational instability is concentrated rather than evenly distributed. The top 5 highest-variance market-mode combinations account for about 40.67% of grouped SLA breaches, and the strongest instability appears in Second Class across multiple markets. When lateness is measured cleanly, Standard Class also shows meaningful relative instability, confirming that average performance masks a concentrated reliability problem.

## Entry template

```md
### C3-Qx: Short title

**Question**

...

**SQL**

```sql
...
```

**Result**

| col | value |
|---|---:|
| ... | ... |

**Business reading**

- ...

**Conclusion**

...
```

