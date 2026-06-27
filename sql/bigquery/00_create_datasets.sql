-- Create the BigQuery datasets used by the analyst SQL pipeline.
-- Run in BigQuery SQL workspace for project `supply-chain-analysis-492322`.

-- Raw landing table lives here after the CSV upload.
CREATE SCHEMA IF NOT EXISTS `supply-chain-analysis-492322.supply_chain_raw`
OPTIONS (location = 'US');

-- Clean staging table and final Power BI marts live here.
CREATE SCHEMA IF NOT EXISTS `supply-chain-analysis-492322.supply_chain_analytics`
OPTIONS (location = 'US');
