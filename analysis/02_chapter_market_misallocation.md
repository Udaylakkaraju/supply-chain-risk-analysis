# Chapter 2: Market Efficiency

## Business Question

Which markets convert order volume into profit efficiently, and where is financial exposure concentrated?

## Method

Market performance is compared using volume share, profit share, margin, SLA breach rate, and positive profit exposure. The efficiency gap is profit share minus volume share.

```sql
SELECT
  market,
  orders,
  revenue_usd,
  profit_usd,
  profit_margin_pct,
  sla_breach_rate_pct,
  order_volume_share_pct,
  profit_share_pct,
  profit_vs_volume_gap_pct,
  profit_at_risk_usd
FROM `supply-chain-analysis-492322.supply_chain_analytics.mart_market_efficiency`
ORDER BY profit_vs_volume_gap_pct DESC;
```

## Results

| Market | Orders | Margin | Breach rate | Efficiency gap | Positive profit exposure |
|---|---:|---:|---:|---:|---:|
| LATAM | 17,181 | 12.16% | 57.06% | +2.19 pp | $1.03M |
| Europe | 18,561 | 11.97% | 57.44% | +1.25 pp | $1.13M |
| USCA | 8,579 | 12.39% | 57.34% | +1.18 pp | $512K |
| Africa | 3,854 | 12.23% | 56.62% | +0.49 pp | $227K |
| Pacific Asia | 17,577 | 11.54% | 57.64% | -5.11 pp | $856K |

## Interpretation

All markets remain profitable and breach rates are tightly clustered. The meaningful finding is relative efficiency: Pacific Asia contributes substantially less profit share than volume share, while LATAM and Europe over-convert volume into profit.

## Decision

Use market efficiency as a supporting capacity-allocation view, not as a market-exit recommendation. Operational action should still be taken at the more specific market-mode level.
