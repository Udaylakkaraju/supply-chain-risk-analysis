-- Run in BigQuery (SQL workspace) for project `supply-chain-analysis-492322`.

-- Raw landing (GCS → BigQuery load target)
CREATE SCHEMA IF NOT EXISTS `supply-chain-analysis-492322.supply_chain_raw`
OPTIONS (location = 'US');

-- dbt outputs (staging / intermediate / marts views & tables)
CREATE SCHEMA IF NOT EXISTS `supply-chain-analysis-492322.supply_chain_analytics`
OPTIONS (location = 'US');
