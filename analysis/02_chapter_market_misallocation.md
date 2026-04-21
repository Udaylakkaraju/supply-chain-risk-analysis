# Chapter 2: Market Misallocation

## Current chapter takeaway

This chapter is not a zombie-market story. It is a **market efficiency ranking** story. The hotspot evidence later reinforces that the biggest exposed pools sit in the largest markets and in Consumer-heavy combinations.

What the evidence shows:
- all five markets are profitable
- margin differences are fairly narrow across markets
- Europe over-converts volume into profit
- Pacific Asia under-converts volume into profit
- profit-at-risk is concentrated in the largest markets rather than in clearly broken ones

Best business framing right now:

> The market portfolio looks broadly profitable, but not equally efficient. The stronger signal is relative market quality, not obvious loss-making geographies.

## Purpose

This file will hold the market-level evidence for whether the network is allocating volume and operational attention to the wrong geographies.

## Planned analysis items

- revenue vs net profit by market
- order volume share vs profit contribution share
- zombie market identification
- SLA breach rate by market
- market-level profit margin
- market classification: invest / monitor / exit

## Working hypotheses

- some markets may carry high volume without contributing proportionate profit
- low-margin or negative-margin markets may still absorb fulfillment capacity
- markets with weak economics may also show weak service performance

---

### C2-Q1: Revenue, profit, margin, and SLA by market

**Question**

Which markets are strongest or weakest on revenue, profit, margin, and service performance?

**SQL**

```sql
SELECT
  market,
  ROUND(SUM(order_item_total), 2) revenue,
  ROUND(SUM(order_profit_per_order), 2) profit,
  ROUND(100 * SAFE_DIVIDE(SUM(order_profit_per_order), SUM(order_item_total)), 2) margin_pct,
  COUNT(*) order_count,
  ROUND(100 * AVG(IF(sla_breached = 'Yes', 1, 0)), 2) sla_breach_pct
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_market_performance`
GROUP BY market
ORDER BY profit;
```

**Result**

| market | revenue | profit | margin_pct | order_count | sla_breach_pct |
|---|---:|---:|---:|---:|---:|
| Africa | 2061679.39 | 252071.18 | 12.23 | 11614 | 56.81 |
| USCA | 4553499.92 | 564313.78 | 12.39 | 25799 | 57.15 |
| Pacific Asia | 7434262.65 | 857753.44 | 11.54 | 41260 | 57.32 |
| LATAM | 9235762.09 | 1123321.61 | 12.16 | 51594 | 57.02 |
| Europe | 9769198.32 | 1169442.96 | 11.97 | 50252 | 57.69 |

**Business reading**

- All markets are profitable; none is immediately identifiable as a negative-margin zombie market.
- Margin differences are relatively small, ranging from **11.54%** to **12.39%**.
- Europe and LATAM are the largest absolute profit contributors.
- Pacific Asia has the weakest margin in the group.
- SLA performance is also tightly clustered, so poor service is not isolated to one market.

**Conclusion**

This result pushes Chapter 2 away from a failure narrative and toward **relative market efficiency**.

---

### C2-Q2: Volume share vs profit share

**Question**

Do some markets contribute less profit than their share of order volume would suggest?

**SQL**

```sql
WITH m AS (
  SELECT
    market,
    COUNT(*) order_count,
    SUM(order_profit_per_order) profit
  FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_market_performance`
  GROUP BY market
)
SELECT
  market,
  order_count,
  ROUND(100 * SAFE_DIVIDE(order_count, SUM(order_count) OVER ()), 2) volume_pct,
  ROUND(profit, 2) profit,
  ROUND(100 * SAFE_DIVIDE(profit, SUM(profit) OVER ()), 2) profit_pct
FROM m
ORDER BY profit;
```

**Result**

| market | order_count | volume_pct | profit | profit_pct |
|---|---:|---:|---:|---:|
| Africa | 11614 | 6.43 | 252071.18 | 6.35 |
| USCA | 25799 | 14.29 | 564313.78 | 14.23 |
| Pacific Asia | 41260 | 22.86 | 857753.44 | 21.62 |
| LATAM | 51594 | 28.58 | 1123321.61 | 28.32 |
| Europe | 50252 | 27.84 | 1169442.96 | 29.48 |

**Business reading**

- Europe is the clearest outperformer: **27.84%** of volume but **29.48%** of profit.
- Pacific Asia is the clearest underperformer: **22.86%** of volume but only **21.62%** of profit.
- LATAM, USCA, and Africa are close to neutral.
- This is the strongest Chapter 2 signal so far because it reveals **portfolio efficiency differences** even when all markets are profitable.

**Conclusion**

The market story is better framed as **uneven portfolio efficiency** rather than market failure. Pacific Asia is the first market to scrutinize more closely.

---

### C2-Q3: Positive profit at risk by market

**Question**

Which markets expose the most positive profit through breached SLA orders?

**SQL**

```sql
SELECT
  market,
  ROUND(SUM(IF(sla_breached = 'Yes' AND profit_at_risk > 0, profit_at_risk, 0)), 2) profit_at_risk,
  ROUND(AVG(delay_days), 2) avg_delay_days,
  ROUND(100 * AVG(IF(sla_breached = 'Yes', 1, 0)), 2) sla_breach_pct,
  COUNT(*) order_count
FROM `supply-chain-analysis-492322.supply_chain_analytics.fct_market_performance`
GROUP BY market
ORDER BY profit_at_risk DESC;
```

**Result**

| market | profit_at_risk | avg_delay_days | sla_breach_pct | order_count |
|---|---:|---:|---:|---:|
| Europe | 1333537.61 | 0.57 | 57.69 | 50252 |
| LATAM | 1249464.96 | 0.56 | 57.02 | 51594 |
| Pacific Asia | 1005568.76 | 0.57 | 57.32 | 41260 |
| USCA | 619960.71 | 0.57 | 57.15 | 25799 |
| Africa | 275890.91 | 0.56 | 56.81 | 11614 |

**Business reading**

- Profit-at-risk exposure is concentrated in the largest markets, especially Europe and LATAM.
- This appears driven more by scale than by dramatically worse service.
- Europe remains economically attractive, but it also carries the largest exposed profit pool.
- Pacific Asia remains worth watching because it combines weaker relative profitability with a large at-risk profit base.

**Conclusion**

Operational exposure is concentrated in the biggest markets. The stronger Chapter 2 message is **where value is most exposed**, not that one market is clearly broken.

---

## Chapter 2 final working statement

Use this wording unless later analysis changes the story materially:

> Chapter 2 does not reveal classic zombie markets, since all five markets are profitable and margins are relatively tight. The stronger signal is uneven portfolio efficiency: Europe contributes more profit than its volume share would imply, while Pacific Asia contributes less, and profit-at-risk exposure is concentrated in the largest markets rather than in clearly loss-making geographies. Hotspot views later show that this exposure is amplified in Consumer-heavy and category-specific lanes.

## Entry template

```md
### C2-Qx: Short title

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

