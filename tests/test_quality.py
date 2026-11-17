import pyarrow as pa
import pyarrow.dataset as ds
import pyarrow.parquet as pq

from clickstream.quality import run_checks


def build_dataset(tmp_path, rows):
    day = tmp_path / "event_date=2026-04-06"
    day.mkdir(parents=True)
    table = pa.table({
        "ip": [r[0] for r in rows],
        "event_ts": [r[1] for r in rows],
        "url": [r[2] for r in rows],
        "status": [r[3] for r in rows],
    })
    pq.write_table(table, day / "part-0.parquet")
    return ds.dataset(tmp_path, format="parquet", partitioning="hive")


GOOD_ROWS = [("1.1.1.1", "2026-04-06T10:00:00", "/cart", 200), ("1.1.1.2", "2026-04-06T10:00:01", "/blog", 200)]
GOOD_METRICS = {"total": 4, "kept": 2, "rejected": {"unparseable": 1, "bad_timestamp": 0}, "filtered": {"non_success_status": 1, "static_asset": 0}}


def test_all_checks_pass(tmp_path):
    report = run_checks(GOOD_METRICS, build_dataset(tmp_path, GOOD_ROWS), 0.5)
    assert all(r["passed"] for r in report.values())


def test_reconciliation_failure(tmp_path):
    metrics = {**GOOD_METRICS, "total": 10}
    report = run_checks(metrics, build_dataset(tmp_path, GOOD_ROWS), 0.5)
    assert not report["reconciliation"]["passed"]


def test_reject_rate_failure(tmp_path):
    report = run_checks(GOOD_METRICS, build_dataset(tmp_path, GOOD_ROWS), 0.1)
    assert not report["reject_rate"]["passed"]


def test_null_key_failure(tmp_path):
    rows = [("1.1.1.1", None, "/cart", 200), GOOD_ROWS[1]]
    report = run_checks(GOOD_METRICS, build_dataset(tmp_path, rows), 0.5)
    assert not report["no_null_keys"]["passed"]


def test_invariant_failure_on_non_200(tmp_path):
    rows = [("1.1.1.1", "2026-04-06T10:00:00", "/cart", 404), GOOD_ROWS[1]]
    report = run_checks(GOOD_METRICS, build_dataset(tmp_path, rows), 0.5)
    assert not report["output_invariants"]["passed"]
