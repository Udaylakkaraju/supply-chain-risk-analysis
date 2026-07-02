# Chapter 3: Service Recovery and Lane Prioritization

## Business Question

Which service modes and operational lanes should receive intervention first?

An operational lane is defined as a `market x shipping_mode` segment, not a physical carrier route.

## Service-Mode Finding

```sql
SELECT
  shipping_mode,
  orders,
  sla_breached_orders,
  sla_breach_rate_pct,
  avg_promised_delivery_days,
  avg_actual_delivery_days,
  avg_days_late,
  profit_at_risk_usd
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_shipping_mode_performance`
ORDER BY sla_breach_rate_pct DESC;
```

Second Class records **10,213 breaches across 12,778 orders**, a 79.93% breach rate, and approximately $1.01M in positive profit exposure. A modeled one-day actual-delivery improvement would return 2,531 orders to SLA and address $253K in exposure.

First Class is handled separately because every order has the same one-day delay. This structural pattern is labeled `Review SLA Definition` rather than treated as operational variability.

## Priority Lanes

```sql
SELECT
  market,
  shipping_mode,
  orders,
  sla_breached_orders,
  sla_breach_rate_pct,
  delivery_variability_days,
  profit_at_risk_usd,
  variability_priority_rank,
  recommended_action
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_lane_reliability`
ORDER BY variability_priority_rank;
```

| Rank | Operational lane | Orders | Breaches | Breach rate | Exposure |
|---:|---|---:|---:|---:|---:|
| 1 | Europe x Standard Class | 11,075 | 4,417 | 39.88% | $465K |
| 2 | Europe x Second Class | 3,609 | 2,886 | 79.97% | $304K |
| 3 | LATAM x Second Class | 3,307 | 2,624 | 79.35% | $277K |
| 4 | Pacific Asia x Standard Class | 10,481 | 4,219 | 40.25% | $355K |
| 5 | USCA x Second Class | 1,678 | 1,341 | 79.92% | $144K |

Together, these five segments account for **41.21% of grouped breaches**, with 15,487 breaches and approximately $1.54M in positive profit exposure.

## Decision

Pilot lane-specific stabilization with named operational owners, weekly variability review, and carrier or fulfillment root-cause investigation. A 20% relative improvement across these lanes models 3,097 fewer breaches and $309K in exposure addressed.

The ranking uses deterministic tie-breakers because several lanes have similar delay standard deviation:

```sql
ROW_NUMBER() OVER (
  ORDER BY delay_sd DESC, breach_count DESC, profit_at_risk DESC,
           market, shipping_mode
)
```
