# Supply Chain Prioritization & Risk Analysis

**$2.77M in high-value profit at risk. 40.67% of SLA breaches concentrated in 5 lanes. A machine learning model that predicts delivery failure before it happens.**

This project analyzes 180,000+ supply chain orders to find where the network is losing value it does not need to lose — and turns those findings into a prioritized set of operational actions.

---

## The core finding

Standard supply chain reporting focuses on averages. Average delay, average SLA compliance, average profit per market. Averages hide the real problem.

This analysis shows that:
- The most profitable orders receive no meaningful delivery advantage over the least profitable ones
- Most SLA failures are not spread evenly — they cluster in a small number of specific shipping lanes
- Market efficiency varies in ways that are not visible from top-line revenue numbers alone
- Operational patterns are strong enough to predict breach risk before an order ships

---

## Key results

| Finding | Number |
|---|---|
| High-value profit at risk | **$2.77M** |
| SLA breach concentration in top 5 lanes | **40.67%** |
| Europe profit-share lift above volume share | **+1.64 pp** |
| Pacific Asia profit-share gap below volume share | **−1.24 pp** |
| BigQuery ML breach-risk model ROC AUC | **0.741** |
| Model accuracy on holdout data | **69.5%** |

---

## What the project recommends

**1. Value-based routing**
Route the highest-profit orders into more consistent shipping tiers automatically. A 10% reduction in breached high-value orders protects roughly **$277K** from that exposed base.

**2. Portfolio rebalancing**
Europe converts volume into profit more efficiently than Pacific Asia. Shifting capacity toward stronger-converting markets improves the portfolio mix without requiring new revenue.

**3. Variability control**
40.67% of all SLA breaches sit in just 5 unstable lane combinations. Fixing those five routes has an outsized impact on overall network reliability.

**4. Early intervention using the prediction model**
The BigQuery ML model flags high-risk orders before dispatch using operational signals that already exist in the data. At 0.741 ROC AUC it can meaningfully rank orders by breach likelihood, enabling earlier action rather than after-the-fact reporting.

---

## How it is built

```
Raw data (180K orders, CSV)
    ↓
Google Cloud Storage — raw file storage
    ↓
BigQuery — data warehouse and SQL engine
    ↓
dbt — transformation layer (staging → intermediate → marts)
    ↓
BigQuery ML — breach-risk prediction model (boosted tree classifier)
    ↓
Streamlit + Plotly — interactive dashboard
```

### dbt model structure

```
models/
├── staging/
│   └── stg_orders.sql               ← type casting, null filtering, SLA normalization
├── intermediate/
│   ├── int_order_profitability.sql   ← profit quartile classification
│   ├── int_delivery_performance.sql  ← delay metrics and SLA flags
│   ├── int_customer_orders.sql       ← customer order sequencing
│   └── int_customer_next_order.sql   ← next order value and timing
└── marts/
    ├── fct_fulfillment_priority.sql  ← profit vs delivery analysis
    ├── fct_market_performance.sql    ← market efficiency ranking
    └── fct_lead_time_variability.sql ← variability by market and shipping mode
```

### BigQuery ML model

- Model type: boosted tree classifier
- Target: SLA breach (Yes / No)
- Features: shipping mode, scheduled days, market, region, order value, discount rate, profit ratio
- Top drivers: `days_for_shipment_scheduled`, `shipping_mode`
- Evaluation: 0.741 ROC AUC, 0.695 accuracy, 0.553 recall on holdout data

---

## Project structure

```
supply-chain/
├── app.py                          ← Streamlit dashboard
├── requirements_streamlit.txt      ← app dependencies
├── supply_chain_dbt/               ← dbt project (models, config, tests)
├── exports/                        ← mart CSVs and BQML output CSVs
├── analysis/                       ← chapter-by-chapter query logs with SQL and results
│   ├── 01_chapter_fulfillment_prioritization.md
│   ├── 02_chapter_market_misallocation.md
│   ├── 03_chapter_variability.md
│   └── 04_chapter_bqml_prediction.md
├── scripts/                        ← raw data conversion script
├── sql/bigquery/                   ← BigQuery dataset setup DDL
├── PROJECT_CONTEXT.md              ← full project reference document
└── ANALYSIS_QUERY_LOG.md           ← index of all chapter query logs
```

---

## Dataset

**DataCo Supply Chain Dataset** — publicly available on Kaggle  
180,519 rows, 51 columns, covering global order and shipping data from 2018  
Source: [Kaggle — DataCo Smart Supply Chain](https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis)

---

## Stack

`Google Cloud Storage` · `BigQuery` · `dbt Core` · `BigQuery ML` · `Python` · `Streamlit` · `Plotly` · `pandas`

---

## How to run locally

**1. Clone the repo**
```bash
git clone https://github.com/your-username/supply-chain-analysis.git
cd supply-chain-analysis
```

**2. Install app dependencies**
```bash
pip install -r requirements_streamlit.txt
```

**3. Run the dashboard**
```bash
streamlit run app.py
```

The app reads from the `exports/` folder. The mart CSVs are pre-exported so no BigQuery connection is needed to view the dashboard.

**To rebuild the pipeline from scratch:**
- Load raw CSV into BigQuery (`supply_chain_raw.orders`)
- Run `dbt run` inside `supply_chain_dbt/`
- Export mart tables to `exports/` as CSV
- Re-run the BQML training script to regenerate `bqml_evaluation.csv`, `bqml_feature_importance.csv`, `bqml_top_risk_lanes.csv`
