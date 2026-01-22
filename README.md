# yahoo-finance-sql-dq
SQL data quality audit and cleaning pipeline for a Yahoo Finance business dataset, producing a cleaned ‘investable universe’ with issue flags and summary reporting.
## Obective
Evaluate dataset reliability, define hard vs soft data quality rules, and produce outputs suitable for downstream market screening.
## Dataset
Table: `bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business`  
Key fields: `STOCK_TICKER`, `EXCHANGE`, `CLOSING_PRICE`, `BID`, `ASK`, `VOLUME`, `WEEK_RANGE`, `DAY_RANGE`, `CURRENCY`
## Methods
- Dataset snapshot (rows, unique tickers, top exchanges/currencies)
- Quality scorecard (missing identifiers, invalid prices, invalid quotes, duplicates)
- Cleaning rules:
  - Drop: missing ticker/exchange, invalid close price
  - Keep but flag: invalid bid/ask, missing/invalid volume, malformed ranges
## Outputs
- Cleaned universe row count
- Issue flag counts for soft-fail conditions
## How to run
Run queries in: 
