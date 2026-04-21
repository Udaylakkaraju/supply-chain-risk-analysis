# Chapter 4: BigQuery ML Risk Prediction

## Current chapter takeaway

This chapter now ends the story with a real prediction model.

What the evidence shows:
- the customer-behavior angle remained weak and did not support the ending
- operational features are strong enough to predict SLA breach risk directly
- the BigQuery ML model reached **0.741 ROC AUC**, **0.695 accuracy**, and **0.553 recall**
- the strongest model drivers are service promise and shipping design, especially `days_for_shipment_scheduled` and `shipping_mode`

Best business framing:

> The last chapter should not force a churn story that the data does not support. Instead, it should turn the operational findings from the earlier layers into a breach-risk model that helps prioritize which orders and lanes deserve earlier intervention.

## Purpose

This file documents the real BigQuery ML implementation used to close the project with prediction rather than with a weak customer-impact claim.

---

### C4-Q1: Can operational features predict SLA breach risk?

**Question**

Can the operational signals from the earlier chapters predict whether an order will breach SLA?

**SQL**

```sql
CREATE OR REPLACE MODEL `supply-chain-analysis-492322.supply_chain_analytics.sla_breach_risk_model_v2`
OPTIONS(
  model_type = 'BOOSTED_TREE_CLASSIFIER',
  input_label_cols = ['label'],
  data_split_method = 'AUTO_SPLIT',
  enable_global_explain = TRUE,
  max_iterations = 25,
  subsample = 0.8
) AS
SELECT
  market,
  order_region,
  shipping_mode,
  customer_segment,
  category_name,
  department_name,
  CAST(order_item_quantity AS FLOAT64) AS order_item_quantity,
  order_item_total,
  order_item_product_price,
  order_item_discount_rate,
  order_item_profit_ratio,
  order_profit_per_order,
  CAST(days_for_shipment_scheduled AS FLOAT64) AS days_for_shipment_scheduled,
  CASE WHEN sla_breached = 'Yes' THEN 1 ELSE 0 END AS label
FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
WHERE sla_breached IN ('Yes', 'No');
```

**Business reading**

- The model uses the exact kinds of operational inputs surfaced across the first three sections.
- That makes the final chapter a practical extension of the main story, rather than a detached technical add-on.
- The target is direct and useful: predict SLA breach risk before the failure happens.

**Conclusion**

Chapter 4 should predict delivery failure risk directly from operational design choices and lane context.

---

### C4-Q2: How well does the model perform?

**Question**

Does the model have enough signal to justify a real prediction chapter?

**SQL**

```sql
SELECT *
FROM ML.EVALUATE(
  MODEL `supply-chain-analysis-492322.supply_chain_analytics.sla_breach_risk_model_v2`
);
```

**Result**

| precision | recall | accuracy | f1_score | log_loss | roc_auc |
| --------- | ------ | -------- | -------- | -------- | ------- |
| 0.8751    | 0.5525 | 0.6954   | 0.6774   | 0.5474   | 0.7415  |

**Business reading**

- A **0.741 ROC AUC** means the model has useful ranking power and can separate higher-risk orders from lower-risk ones.
- **0.695 accuracy** shows the model performs materially better than a random or purely narrative ending to the project.
- **0.553 recall** means the model catches more than half of breached orders on holdout data, which is enough to support a prioritization use case.

**Conclusion**

The model is strong enough to justify a predictive final chapter and gives the project a real technical close.

---

### C4-Q3: Which features matter most?

**Question**

Which operational features contribute the most to predicted breach risk?

**SQL**

```sql
SELECT *
FROM ML.FEATURE_IMPORTANCE(
  MODEL `supply-chain-analysis-492322.supply_chain_analytics.sla_breach_risk_model_v2`
)
ORDER BY importance_gain DESC;
```

**Result**

| feature | importance_gain |
| ------- | --------------- |
| days_for_shipment_scheduled | 2132.75 |
| shipping_mode | 1942.70 |
| order_region | 3.49 |
| market | 3.37 |
| order_item_product_price | 2.55 |
| order_item_profit_ratio | 2.49 |
| order_profit_per_order | 2.49 |
| department_name | 2.47 |

**Business reading**

- `days_for_shipment_scheduled` dominates the model, which means the service promise itself is a major determinant of breach risk.
- `shipping_mode` is the second-biggest driver, reinforcing the earlier finding that service design decisions matter more than downstream customer behavior.
- Geography still matters, but it sits behind the shipping-policy variables rather than replacing them.

**Conclusion**

The model confirms that breach risk is primarily operational and policy-driven.

---

### C4-Q4: Which lanes are predicted to be riskiest?

**Question**

Where does the model rank the highest average breach risk after scoring the order base?

**SQL**

```sql
WITH scored AS (
  SELECT
    market,
    shipping_mode,
    (
      SELECT prob
      FROM UNNEST(predicted_label_probs)
      WHERE CAST(label AS STRING) = '1'
    ) AS breach_probability
  FROM ML.PREDICT(
    MODEL `supply-chain-analysis-492322.supply_chain_analytics.sla_breach_risk_model_v2`,
    (
      SELECT
        market,
        order_region,
        shipping_mode,
        customer_segment,
        category_name,
        department_name,
        CAST(order_item_quantity AS FLOAT64) AS order_item_quantity,
        order_item_total,
        order_item_product_price,
        order_item_discount_rate,
        order_item_profit_ratio,
        order_profit_per_order,
        CAST(days_for_shipment_scheduled AS FLOAT64) AS days_for_shipment_scheduled
      FROM `supply-chain-analysis-492322.supply_chain_analytics.stg_orders`
      WHERE sla_breached IN ('Yes', 'No')
    )
  )
)
SELECT
  market,
  shipping_mode,
  COUNT(*) AS order_count,
  ROUND(AVG(breach_probability), 4) AS predicted_breach_risk
FROM scored
GROUP BY 1, 2
HAVING order_count >= 1000
ORDER BY predicted_breach_risk DESC, order_count DESC
LIMIT 10;
```

**Result**

| market | shipping_mode | order_count | predicted_breach_risk |
| ------ | ------------- | ----------: | --------------------: |
| Europe | First Class   | 7892        | 0.9254 |
| LATAM  | First Class   | 7886        | 0.9254 |
| Pacific Asia | First Class | 6301     | 0.9254 |
| USCA   | First Class   | 4008        | 0.9254 |
| Africa | First Class   | 1727        | 0.9254 |
| Europe | Second Class  | 9861        | 0.7620 |
| USCA   | Second Class  | 5105        | 0.7603 |
| Pacific Asia | Second Class | 8147    | 0.7597 |

**Business reading**

- The highest-risk ranking is dominated by **First Class** and **Second Class** combinations, not by a broad mix of customer segments.
- That reinforces the feature-importance result: service policy and scheduled promise design drive most of the model's signal.
- The lane ranking turns the chapter into an action list, because it shows exactly where earlier intervention should be targeted first.

**Conclusion**

The final chapter now ends with a practical prioritization layer: predict the riskiest lanes, then intervene where the model says breach risk is highest.

---

## Chapter 4 final working statement

> The customer-impact signal stayed weak, so the project closes with BigQuery ML instead of forcing a churn narrative. A boosted-tree model trained on operational features reached 0.741 ROC AUC, with scheduled shipping days and shipping mode emerging as the dominant risk drivers. That gives the final chapter a real predictive outcome and turns the earlier operational analysis into a practical prioritization tool.
