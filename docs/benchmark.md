# Benchmark results

Measured 2026-11-17 on Linux with 12 CPUs, Spark 4.3.0, local mode, warm OS cache.
Reproduce with `make benchmark ROWS=50000`; numbers depend on your machine.

| Metric | Value |
| --- | --- |
| Raw log lines | 50,000 over 30 days |
| Rows kept after cleaning | 33,637 |
| Raw log size | 4.0 MB |
| Curated as CSV text (legacy format) | 2.7 MB |
| Curated as partitioned Parquet | 0.9 MB (67% smaller than CSV) |
| ETL wall time (parse, clean, write) | 7.3 s |
| One-day query, CSV text (legacy format) | 0.17 s (median of 5) |
| One-day query, unpartitioned Parquet | 0.15 s (median of 5) |
| One-day query, partitioned Parquet | 0.16 s (median of 5) |
| Partition pruning in query plan | yes |
| Speedup, partitioned Parquet vs CSV text | 1.1x |
| Speedup, partitioned vs unpartitioned Parquet | 0.9x |

The unpartitioned copy keeps rows in time order, so Parquet min/max statistics already let Spark skip most row groups on a date filter. Expect partitioning to matter more with many files, unordered writes, or remote storage than in this small local run.
