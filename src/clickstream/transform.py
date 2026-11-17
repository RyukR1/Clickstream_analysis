import argparse
import json
from pathlib import Path

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

LOG_PATTERN = r'^(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+) (\S+)" (\d{3}) (\d+|-)$'
ASSET_PATTERN = r"\.(css|js|png|jpg|jpeg|gif|ico|svg|woff2?)(\?.*)?$"
TIMESTAMP_FORMAT = "dd/MMM/yyyy:HH:mm:ss Z"
REJECT_REASONS = ("unparseable", "bad_timestamp")
FILTER_REASONS = ("non_success_status", "static_asset")


def build_session(name="clickstream-transform", master=None, shuffle_partitions=8):
    builder = (
        SparkSession.builder.appName(name)
        .config("spark.sql.session.timeZone", "UTC")
        .config("spark.sql.ansi.enabled", "false")
        .config("spark.sql.shuffle.partitions", str(shuffle_partitions))
        .config("spark.sql.sources.partitionOverwriteMode", "dynamic")
        .config("spark.ui.showConsoleProgress", "false")
    )
    if master:
        builder = builder.master(master)
    return builder.getOrCreate()


def parse_logs(raw):
    matched = F.col("line").rlike(LOG_PATTERN)
    parsed = (
        raw.withColumn("matched", matched)
        .withColumn("ip", F.regexp_extract("line", LOG_PATTERN, 1))
        .withColumn("ts_raw", F.regexp_extract("line", LOG_PATTERN, 2))
        .withColumn("method", F.regexp_extract("line", LOG_PATTERN, 3))
        .withColumn("url", F.regexp_extract("line", LOG_PATTERN, 4))
        .withColumn("protocol", F.regexp_extract("line", LOG_PATTERN, 5))
        .withColumn("status", F.regexp_extract("line", LOG_PATTERN, 6).cast("int"))
        .withColumn("bytes_raw", F.regexp_extract("line", LOG_PATTERN, 7))
        .withColumn("event_ts", F.to_timestamp("ts_raw", TIMESTAMP_FORMAT))
    )
    path = F.regexp_replace("url", r"\?.*$", "")
    reason = (
        F.when(~F.col("matched"), "unparseable")
        .when(F.col("event_ts").isNull(), "bad_timestamp")
        .when(F.col("status") != 200, "non_success_status")
        .when(path.rlike(ASSET_PATTERN), "static_asset")
    )
    return (
        parsed.withColumn("reason", reason)
        .withColumn("bytes", F.when(F.col("bytes_raw") == "-", 0).otherwise(F.col("bytes_raw")).cast("long"))
        .withColumn("url", path)
        .withColumn("event_date", F.date_format("event_ts", "yyyy-MM-dd"))
        .withColumn("section", F.regexp_extract("url", r"^/([^/]*)", 1))
    )


def curated_columns(df):
    return df.filter(F.col("reason").isNull()).select(
        "ip", "event_ts", "method", "url", "protocol", "status", "bytes", "section", "event_date"
    )


def collect_metrics(df):
    counts = {row["reason"]: row["count"] for row in df.groupBy("reason").count().collect()}
    kept = counts.get(None, 0)
    metrics = {
        "total": sum(counts.values()),
        "kept": kept,
        "rejected": {r: counts.get(r, 0) for r in REJECT_REASONS},
        "filtered": {r: counts.get(r, 0) for r in FILTER_REASONS},
    }
    return metrics


def run(spark, input_path, output_path, quarantine_path, metrics_path):
    raw = spark.read.text(str(input_path)).withColumnRenamed("value", "line")
    df = parse_logs(raw).cache()
    metrics = collect_metrics(df)
    curated_columns(df).write.mode("overwrite").partitionBy("event_date").parquet(str(output_path))
    rejected = df.filter(F.col("reason").isin(*REJECT_REASONS)).select("reason", "line")
    rejected.write.mode("overwrite").parquet(str(quarantine_path))
    df.unpersist()
    metrics_file = Path(metrics_path)
    metrics_file.parent.mkdir(parents=True, exist_ok=True)
    metrics_file.write_text(json.dumps(metrics, indent=2) + "\n")
    return metrics


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Parse raw access logs into partitioned Parquet")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--quarantine", required=True)
    parser.add_argument("--metrics", required=True)
    parser.add_argument("--master", default="local[*]")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    spark = build_session(master=args.master)
    try:
        metrics = run(spark, args.input, args.output, args.quarantine, args.metrics)
    finally:
        spark.stop()
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
