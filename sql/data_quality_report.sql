-- Dataset Snapshot

SELECT COUNT(*) AS rows_scanned
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business;
-- Rows scanned

SELECT COUNT(DISTINCT STOCK_TICKER) AS unique_tickers
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE STOCK_TICKER IS NOT NULL;
-- Unique stock tickers

SELECT EXCHANGE, COUNT(*) AS rows_count
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE EXCHANGE IS NOT NULL
GROUP BY EXCHANGE
ORDER BY rows_count DESC
LIMIT 3;
-- Top 3 exchanges by rows

SELECT CURRENCY, COUNT(*) AS rows_count
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE CURRENCY IS NOT NULL
GROUP BY CURRENCY
ORDER BY rows_count DESC
LIMIT 3;
-- Top 3 currencies by rows

-- Quality Scorecard

SELECT COUNT(*) AS missing_stock_ticker
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE STOCK_TICKER IS NULL;
-- Missing stock ticker

SELECT COUNT(*) AS missing_exchange
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE EXCHANGE IS NULL;
-- Missing exchange

SELECT COUNT(*) AS missing_closing_price
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE CLOSING_PRICE IS NULL OR try_cast(CLOSING_PRICE AS DECIMAL(10, 3)) < 0;
-- Invalid closing price

SELECT COUNT(*) AS invalid_bid_ask_rows
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE
  (BID IS NOT NULL AND (
      TRY_CAST(BID AS DECIMAL(18,6)) IS NULL
      OR TRY_CAST(BID AS DECIMAL(18,6)) <= 0
  )) 
  OR
  (ASK IS NOT NULL AND (
      TRY_CAST(ASK AS DECIMAL(18,6)) IS NULL
      OR TRY_CAST(ASK AS DECIMAL(18,6)) <= 0
  ))
  OR
   (
    BID IS NOT NULL AND ASK IS NOT NULL
    AND TRY_CAST(BID AS DECIMAL(18,6)) IS NOT NULL
    AND TRY_CAST(ASK AS DECIMAL(18,6)) IS NOT NULL
    AND TRY_CAST(ASK AS DECIMAL(18,6)) < TRY_CAST(BID AS DECIMAL(18,6))
  );
-- Invalid bid/ask

SELECT COUNT(*) AS duplicate_pairs
FROM (
  SELECT STOCK_TICKER, EXCHANGE, COUNT(*) AS ct
  FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
  WHERE STOCK_TICKER IS NOT NULL AND EXCHANGE IS NOT NULL
  GROUP BY STOCK_TICKER, EXCHANGE
  HAVING COUNT(*) > 1
) d;
-- Duplicate stock ticker + exchange pairs

-- Cleaning Rules

SELECT *
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE STOCK_TICKER IS NOT NULL
  AND EXCHANGE IS NOT NULL
  AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) IS NOT NULL
  AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) > 0;
-- Drops (hard fails)

WITH base AS (
  SELECT
    *,
    TRY_CAST(BID AS DECIMAL(18,6))        AS bid_num,
    TRY_CAST(ASK AS DECIMAL(18,6))        AS ask_num,
    TRY_CAST(VOLUME AS BIGINT)            AS volume_num
  FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
  WHERE STOCK_TICKER IS NOT NULL
    AND EXCHANGE IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) > 0
)
SELECT
  *,
  CASE
    WHEN BID IS NULL OR ASK IS NULL THEN 0
    WHEN bid_num IS NULL OR ask_num IS NULL THEN 1
    WHEN bid_num <= 0 OR ask_num <= 0 THEN 1
    WHEN ask_num < bid_num THEN 1
    ELSE 0
  END AS flag_invalid_bid_ask,

  CASE WHEN VOLUME IS NULL THEN 1 ELSE 0 END AS flag_missing_volume,
  CASE
    WHEN VOLUME IS NULL THEN 0
    WHEN volume_num IS NULL THEN 1
    WHEN volume_num < 0 THEN 1
    ELSE 0
  END AS flag_invalid_volume,
  CASE
    WHEN WEEK_RANGE IS NULL THEN 0
    WHEN WEEK_RANGE NOT LIKE '%-%' THEN 1
    ELSE 0
  END AS flag_malformed_week_range,

  CASE
    WHEN DAY_RANGE IS NULL THEN 0
    WHEN DAY_RANGE NOT LIKE '%-%' THEN 1
    ELSE 0
  END AS flag_malformed_day_range

FROM base;
-- Keep but flag (soft fails)

-- Resulting "Clean" Output + Next Use

SELECT COUNT(*) AS cleaned_universe_rows
FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
WHERE STOCK_TICKER IS NOT NULL
  AND EXCHANGE IS NOT NULL
  AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) IS NOT NULL
  AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) > 0;
-- Cleaned universe rows (after hard drops)

WITH kept AS (
  SELECT
    *,
    TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) AS close_num,
    TRY_CAST(BID AS DECIMAL(18,6))           AS bid_num,
    TRY_CAST(ASK AS DECIMAL(18,6))           AS ask_num,
    TRY_CAST(VOLUME AS BIGINT)               AS volume_num
  FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
  WHERE STOCK_TICKER IS NOT NULL
    AND EXCHANGE IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) > 0
)
SELECT
  *,

  CASE
    WHEN BID IS NULL OR ASK IS NULL THEN 0
    WHEN bid_num IS NULL OR ask_num IS NULL THEN 1
    WHEN bid_num <= 0 OR ask_num <= 0 THEN 1
    WHEN ask_num < bid_num THEN 1
    ELSE 0
  END AS flag_invalid_bid_ask,

  CASE WHEN VOLUME IS NULL THEN 1 ELSE 0 END AS flag_missing_volume,

  CASE
    WHEN VOLUME IS NULL THEN 0
    WHEN volume_num IS NULL THEN 1
    WHEN volume_num < 0 THEN 1
    ELSE 0
  END AS flag_invalid_volume,

  CASE
    WHEN WEEK_RANGE IS NULL THEN 0
    WHEN WEEK_RANGE NOT LIKE '%-%' THEN 1
    ELSE 0
  END AS flag_malformed_week_range,

  CASE
    WHEN DAY_RANGE IS NULL THEN 0
    WHEN DAY_RANGE NOT LIKE '%-%' THEN 1
    ELSE 0
  END AS flag_malformed_day_range

FROM kept;
-- Cleaned universe + added issue flags (this returns the cleaned rows with flags)

WITH kept AS (
  SELECT
    *,
    TRY_CAST(BID AS DECIMAL(18,6))   AS bid_num,
    TRY_CAST(ASK AS DECIMAL(18,6))   AS ask_num,
    TRY_CAST(VOLUME AS BIGINT)       AS volume_num
  FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
  WHERE STOCK_TICKER IS NOT NULL
    AND EXCHANGE IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) > 0
),
flags AS (
  SELECT
    CASE
      WHEN BID IS NULL OR ASK IS NULL THEN 0
      WHEN bid_num IS NULL OR ask_num IS NULL THEN 1
      WHEN bid_num <= 0 OR ask_num <= 0 THEN 1
      WHEN ask_num < bid_num THEN 1
      ELSE 0
    END AS flag_invalid_bid_ask,

    CASE WHEN VOLUME IS NULL THEN 1 ELSE 0 END AS flag_missing_volume,

    CASE
      WHEN VOLUME IS NULL THEN 0
      WHEN volume_num IS NULL THEN 1
      WHEN volume_num < 0 THEN 1
      ELSE 0
    END AS flag_invalid_volume,

    CASE
      WHEN WEEK_RANGE IS NULL THEN 0
      WHEN WEEK_RANGE NOT LIKE '%-%' THEN 1
      ELSE 0
    END AS flag_malformed_week_range,

    CASE
      WHEN DAY_RANGE IS NULL THEN 0
      WHEN DAY_RANGE NOT LIKE '%-%' THEN 1
      ELSE 0
    END AS flag_malformed_day_range
  FROM kept
)
SELECT
  COUNT(*) AS cleaned_universe_rows,
  SUM(
    CASE WHEN flag_invalid_bid_ask = 1
           OR flag_missing_volume = 1
           OR flag_invalid_volume = 1
           OR flag_malformed_week_range = 1
           OR flag_malformed_day_range = 1
         THEN 1 ELSE 0 END
  ) AS flagged_rows
FROM flags;
-- How many cleaned rows have any issue flag (count only)

WITH kept AS (
  SELECT
    *,
    TRY_CAST(BID AS DECIMAL(18,6))   AS bid_num,
    TRY_CAST(ASK AS DECIMAL(18,6))   AS ask_num,
    TRY_CAST(VOLUME AS BIGINT)       AS volume_num
  FROM bright_data_yahoo_finance_business_dataset.datasets.yahoo_finance_business
  WHERE STOCK_TICKER IS NOT NULL
    AND EXCHANGE IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) IS NOT NULL
    AND TRY_CAST(CLOSING_PRICE AS DECIMAL(18,6)) > 0
),
flags AS (
  SELECT
    CASE
      WHEN BID IS NULL OR ASK IS NULL THEN 0
      WHEN bid_num IS NULL OR ask_num IS NULL THEN 1
      WHEN bid_num <= 0 OR ask_num <= 0 THEN 1
      WHEN ask_num < bid_num THEN 1
      ELSE 0
    END AS flag_invalid_bid_ask,

    CASE WHEN VOLUME IS NULL THEN 1 ELSE 0 END AS flag_missing_volume,

    CASE
      WHEN VOLUME IS NULL THEN 0
      WHEN volume_num IS NULL THEN 1
      WHEN volume_num < 0 THEN 1
      ELSE 0
    END AS flag_invalid_volume,

    CASE
      WHEN WEEK_RANGE IS NULL THEN 0
      WHEN WEEK_RANGE NOT LIKE '%-%' THEN 1
      ELSE 0
    END AS flag_malformed_week_range,

    CASE
      WHEN DAY_RANGE IS NULL THEN 0
      WHEN DAY_RANGE NOT LIKE '%-%' THEN 1
      ELSE 0
    END AS flag_malformed_day_range
  FROM kept
)
SELECT
  SUM(CASE WHEN flag_invalid_bid_ask = 1 THEN 1 ELSE 0 END) AS invalid_bid_ask_rows,
  SUM(CASE WHEN flag_missing_volume = 1 THEN 1 ELSE 0 END) AS missing_volume_rows,
  SUM(CASE WHEN flag_invalid_volume = 1 THEN 1 ELSE 0 END) AS invalid_volume_rows,
  SUM(CASE WHEN flag_malformed_week_range = 1 THEN 1 ELSE 0 END) AS malformed_week_range_rows,
  SUM(CASE WHEN flag_malformed_day_range = 1 THEN 1 ELSE 0 END) AS malformed_day_range_rows
FROM flags;
-- Breakdown: how many rows per issue (inside cleaned universe)


  
  
  
  
  
  
  






  
