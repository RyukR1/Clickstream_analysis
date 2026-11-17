import argparse
import os
import platform
import shutil
import statistics
import time
from datetime import datetime, timezone
from pathlib import Path

from . import generate as gen
from . import transform as tf

QUERY = (
    "SELECT url, COUNT(*) AS clicks FROM {view} "
    "WHERE event_date = '{day}' GROUP BY url ORDER BY clicks DESC LIMIT 10"
)


def dir_size(path):
    return sum(p.stat().st_size for p in Path(path).rglob("*") if p.is_file())


def megabytes(size):
    return round(size / 1_048_576, 1)


def timed(fn):
    start = time.perf_counter()
    result = fn()
    return time.perf_counter() - start, result


def time_query(spark, path, day, runs):
    samples = []
    for _ in range(runs + 1):
        spark.catalog.clearCache()
        frame = spark.read.parquet(str(path))
        frame.createOrReplaceTempView("bench_view")
        seconds, _ = timed(lambda: spark.sql(QUERY.format(view="bench_view", day=day)).collect())
        samples.append(seconds)
    return statistics.median(samples[1:])


CSV_SCHEMA = "ip STRING, event_ts TIMESTAMP, method STRING, url STRING, protocol STRING, status INT, bytes LONG, section STRING"
CSV_QUERY = (
    "SELECT url, COUNT(*) AS clicks FROM csv_view "
    "WHERE date_format(event_ts, 'yyyy-MM-dd') = '{day}' GROUP BY url ORDER BY clicks DESC LIMIT 10"
)


def time_csv_query(spark, path, day, runs):
    samples = []
    for _ in range(runs + 1):
        spark.catalog.clearCache()
        spark.read.schema(CSV_SCHEMA).csv(str(path)).createOrReplaceTempView("csv_view")
        seconds, _ = timed(lambda: spark.sql(CSV_QUERY.format(day=day)).collect())
        samples.append(seconds)
    return statistics.median(samples[1:])


def pruned_partitions(spark, path, day):
    frame = spark.read.parquet(str(path))
    frame.createOrReplaceTempView("plan_view")
    plan = spark.sql(QUERY.format(view="plan_view", day=day))._jdf.queryExecution().executedPlan().toString()
    return "PartitionFilters: [isnotnull(event_date" in plan


def run(workdir, rows, days, runs, seed):
    work = Path(workdir)
    shutil.rmtree(work, ignore_errors=True)
    work.mkdir(parents=True)
    raw = work / "raw" / "access.log"
    gen_seconds, _ = timed(lambda: gen.generate(raw, rows, days, gen.date(2026, 4, 6), seed, 0.01, 0.03, 5000))
    spark = tf.build_session("clickstream-benchmark", "local[*]")
    try:
        partitioned = work / "curated_partitioned"
        etl_seconds, metrics = timed(
            lambda: tf.run(spark, raw, partitioned, work / "quarantine", work / "metrics.json")
        )
        unpartitioned = work / "curated_flat"
        spark.read.parquet(str(partitioned)).write.mode("overwrite").parquet(str(unpartitioned))
        csv_dir = work / "curated_csv"
        spark.read.parquet(str(partitioned)).drop("event_date").write.mode("overwrite").csv(str(csv_dir))
        day = gen.date(2026, 4, 6).isoformat()
        part_seconds = time_query(spark, partitioned, day, runs)
        flat_seconds = time_query(spark, unpartitioned, day, runs)
        csv_seconds = time_csv_query(spark, csv_dir, day, runs)
        pruned = pruned_partitions(spark, partitioned, day)
        spark_version = spark.version
    finally:
        spark.stop()
    return {
        "rows": rows,
        "days": days,
        "kept": metrics["kept"],
        "spark": spark_version,
        "cpus": os.cpu_count(),
        "generate_s": gen_seconds,
        "etl_s": etl_seconds,
        "raw_mb": megabytes(dir_size(work / "raw")),
        "csv_mb": megabytes(dir_size(csv_dir)),
        "parquet_mb": megabytes(dir_size(partitioned)),
        "csv_query_s": csv_seconds,
        "flat_query_s": flat_seconds,
        "part_query_s": part_seconds,
        "pruned": pruned,
        "runs": runs,
    }


def to_markdown(r):
    vs_csv = r["csv_query_s"] / r["part_query_s"] if r["part_query_s"] else float("nan")
    vs_flat = r["flat_query_s"] / r["part_query_s"] if r["part_query_s"] else float("nan")
    saving = 100 * (1 - r["parquet_mb"] / r["csv_mb"]) if r["csv_mb"] else float("nan")
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return f"""# Benchmark results

Measured {stamp} on {platform.system()} with {r['cpus']} CPUs, Spark {r['spark']}, local mode, warm OS cache.
Reproduce with `make benchmark ROWS={r['rows']}`; numbers depend on your machine.

| Metric | Value |
| --- | --- |
| Raw log lines | {r['rows']:,} over {r['days']} days |
| Rows kept after cleaning | {r['kept']:,} |
| Raw log size | {r['raw_mb']} MB |
| Curated as CSV text (legacy format) | {r['csv_mb']} MB |
| Curated as partitioned Parquet | {r['parquet_mb']} MB ({saving:.0f}% smaller than CSV) |
| ETL wall time (parse, clean, write) | {r['etl_s']:.1f} s |
| One-day query, CSV text (legacy format) | {r['csv_query_s']:.2f} s (median of {r['runs']}) |
| One-day query, unpartitioned Parquet | {r['flat_query_s']:.2f} s (median of {r['runs']}) |
| One-day query, partitioned Parquet | {r['part_query_s']:.2f} s (median of {r['runs']}) |
| Partition pruning in query plan | {'yes' if r['pruned'] else 'no'} |
| Speedup, partitioned Parquet vs CSV text | {vs_csv:.1f}x |
| Speedup, partitioned vs unpartitioned Parquet | {vs_flat:.1f}x |

The unpartitioned copy keeps rows in time order, so Parquet min/max statistics already let Spark skip most row groups on a date filter. Expect partitioning to matter more with many files, unordered writes, or remote storage than in this small local run.
"""


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Benchmark Parquet and partitioning")
    parser.add_argument("--workdir", default="data/benchmark")
    parser.add_argument("--rows", type=int, default=2_000_000)
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", default="docs/benchmark.md")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    result = run(args.workdir, args.rows, args.days, args.runs, args.seed)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(to_markdown(result))
    print(out.read_text())


if __name__ == "__main__":
    main()
