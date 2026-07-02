# Chapter 1: Value-Blind Fulfillment

## Business Question

Do high-value orders receive better SLA protection than lower-value orders?

## Method

Orders are ranked by summed order profit and divided into four equal-sized groups using `NTILE(4)`. Service outcomes and positive profit exposure are then compared across quartiles.

```sql
SELECT
  profit_quartile,
  profit_tier,
  orders,
  sla_breached_orders,
  sla_breach_rate_pct,
  avg_days_late,
  total_profit_usd,
  profit_at_risk_usd
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_profit_priority`
ORDER BY profit_quartile;
```

## Results

| Profit tier | Orders | Breach rate | Average delay | Total profit | Positive profit exposure |
|---|---:|---:|---:|---:|---:|
| Highest profit | 16,438 | 56.81% | 0.55 days | $4.09M | $2.31M |
| Upper-middle profit | 16,438 | 57.76% | 0.58 days | $1.85M | $1.07M |
| Lower-middle profit | 16,438 | 57.11% | 0.55 days | $636K | $364K |
| Lowest profit | 16,438 | 57.65% | 0.58 days | -$2.61M | $5K |

## Interpretation

Breach rates vary by less than one percentage point across value tiers. The highest-profit quartile therefore receives no meaningful service advantage despite carrying **$2.31M of positive profit exposure across 9,339 breached orders**.

## Decision

Introduce a value-aware routing guardrail for high-profit orders, beginning with the 3,159 Q1 orders currently using Second Class. This is a modeled intervention that requires pilot validation.
