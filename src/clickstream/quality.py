import argparse
import json
import sys
from datetime import date
from pathlib import Path

import pyarrow.compute as pc
import pyarrow.dataset as ds

REQUIRED_COLUMNS = ("ip", "event_ts", "url", "status", "event_date")


def check_reconciliation(metrics):
    accounted = (
        metrics["kept"]
        + sum(metrics["rejected"].values())
        + sum(metrics["filtered"].values())
    )
    return accounted == metrics["total"], f"total={metrics['total']} accounted={accounted}"


def check_reject_rate(metrics, max_rate):
    rejected = sum(metrics["rejected"].values())
    rate = rejected / metrics["total"] if metrics["total"] else 0.0
    return rate <= max_rate, f"reject_rate={rate:.4f} limit={max_rate}"


def check_output_count(metrics, dataset):
    rows = dataset.count_rows()
    return rows == metrics["kept"], f"parquet_rows={rows} kept={metrics['kept']}"


def check_no_nulls(dataset):
    table = dataset.to_table(columns=list(REQUIRED_COLUMNS))
    nulls = {name: table[name].null_count for name in REQUIRED_COLUMNS if table[name].null_count}
    return not nulls, f"null_counts={nulls or 'none'}"


def check_invariants(dataset):
    table = dataset.to_table(columns=["status", "url"])
    bad_status = pc.sum(pc.not_equal(table["status"], 200)).as_py() or 0
    assets = pc.sum(pc.match_substring_regex(table["url"], r"\.(css|js|png|jpg|ico)$")).as_py() or 0
    return bad_status == 0 and assets == 0, f"non_200_rows={bad_status} asset_rows={assets}"


def check_partitions(dataset, min_date, max_date):
    table = dataset.to_table(columns=["event_date"])
    dates = sorted({str(value) for value in table["event_date"].unique().to_pylist()})
    problems = []
    for value in dates:
        try:
            parsed = date.fromisoformat(value)
        except ValueError:
            problems.append(f"unparseable partition {value}")
            continue
        if min_date and parsed < min_date:
            problems.append(f"{value} before {min_date}")
        if max_date and parsed > max_date:
            problems.append(f"{value} after {max_date}")
    return bool(dates) and not problems, f"partitions={len(dates)} problems={problems or 'none'}"


def run_checks(metrics, dataset, max_reject_rate, min_date=None, max_date=None):
    results = {
        "reconciliation": check_reconciliation(metrics),
        "reject_rate": check_reject_rate(metrics, max_reject_rate),
        "output_row_count": check_output_count(metrics, dataset),
        "no_null_keys": check_no_nulls(dataset),
        "output_invariants": check_invariants(dataset),
        "partition_dates": check_partitions(dataset, min_date, max_date),
    }
    return {name: {"passed": bool(ok), "detail": detail} for name, (ok, detail) in results.items()}


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Quality gate for curated clickstream data")
    parser.add_argument("--metrics", required=True)
    parser.add_argument("--curated", required=True)
    parser.add_argument("--report", default=None)
    parser.add_argument("--max-reject-rate", type=float, default=0.05)
    parser.add_argument("--date", type=date.fromisoformat, default=None)
    parser.add_argument("--min-date", type=date.fromisoformat, default=None)
    parser.add_argument("--max-date", type=date.fromisoformat, default=None)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    metrics = json.loads(Path(args.metrics).read_text())
    dataset = ds.dataset(args.curated, format="parquet", partitioning="hive")
    if args.date:
        dataset = dataset.filter(ds.field("event_date") == args.date.isoformat())
    report = run_checks(metrics, dataset, args.max_reject_rate, args.min_date, args.max_date)
    for name, result in report.items():
        print(f"{'PASS' if result['passed'] else 'FAIL'}  {name}: {result['detail']}")
    if args.report:
        Path(args.report).write_text(json.dumps(report, indent=2) + "\n")
    if not all(result["passed"] for result in report.values()):
        sys.exit(1)


if __name__ == "__main__":
    main()
