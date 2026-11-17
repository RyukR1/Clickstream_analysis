CREATE EXTERNAL TABLE IF NOT EXISTS clickstream (
  ip STRING,
  event_ts TIMESTAMP,
  method STRING,
  url STRING,
  protocol STRING,
  status INT,
  bytes BIGINT,
  section STRING
)
PARTITIONED BY (event_date STRING)
STORED AS PARQUET
LOCATION '${hivevar:curated_location}';

MSCK REPAIR TABLE clickstream;
