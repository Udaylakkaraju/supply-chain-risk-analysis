# Supply Chain Analysis Query Log

This is the index for the project analysis log.

Each chapter has its own file with the exact SQL, result snapshot, business reading, and conclusion for every meaningful query.

## Conventions

- `profit_quartile = 1` means the highest-profit quartile because `ntile(4)` is assigned on `order_profit_per_order desc`
- record exact SQL, result snapshot, business reading, and conclusion for every meaningful query
- add findings to the chapter file where they belong

## Chapter Files

- `analysis/01_chapter_fulfillment_prioritization.md` — profit-at-risk concentration and fulfillment gaps
- `analysis/02_chapter_market_misallocation.md` — market efficiency ranking
- `analysis/03_chapter_variability.md` — lead time variability and SLA breach concentration
- `analysis/04_chapter_bqml_prediction.md` — BigQuery ML breach-risk model

## Current Status

- Chapter 1: complete
- Chapter 2: complete
- Chapter 3: complete
- Chapter 4: complete — real BQML model trained, evaluation and feature importance logged

## Recommended workflow

1. Run a query in BigQuery.
2. Capture the result table or headline number.
3. Add the SQL and interpretation to the matching chapter file.
4. Update `PROJECT_CONTEXT.md` only after findings are stable enough to become part of the final narrative.
