from clickstream.transform import run

SAMPLE = [
    '10.0.0.1 - - [06/Apr/2026:10:00:01 +0000] "GET /products/laptop HTTP/1.1" 200 5234',
    '10.0.0.1 - - [06/Apr/2026:10:00:02 +0000] "GET /cart?x=1 HTTP/1.1" 200 900',
    '10.0.0.2 - - [07/Apr/2026:23:59:59 +0000] "POST /checkout HTTP/1.1" 200 120',
    '10.0.0.3 - - [06/Apr/2026:10:00:03 +0000] "GET /admin/login.php HTTP/1.1" 404 0',
    '10.0.0.3 - - [06/Apr/2026:10:00:04 +0000] "GET /missing HTTP/1.1" 500 10',
    '10.0.0.4 - - [06/Apr/2026:10:00:05 +0000] "GET /css/style.css HTTP/1.1" 200 4000',
    '10.0.0.4 - - [06/Apr/2026:10:00:06 +0000] "GET /data.json HTTP/1.1" 200 4000',
    '10.0.0.5 - - [not-a-date] "GET /cart HTTP/1.1" 200 5',
    "totally broken line",
]


def execute(spark, tmp_path):
    raw = tmp_path / "raw"
    raw.mkdir()
    (raw / "access.log").write_text("\n".join(SAMPLE) + "\n")
    metrics = run(spark, raw, tmp_path / "curated", tmp_path / "quarantine", tmp_path / "metrics.json")
    return metrics


def test_counts_reconcile(spark, tmp_path):
    metrics = execute(spark, tmp_path)
    accounted = metrics["kept"] + sum(metrics["rejected"].values()) + sum(metrics["filtered"].values())
    assert metrics["total"] == accounted == len(SAMPLE)


def test_reasons(spark, tmp_path):
    metrics = execute(spark, tmp_path)
    assert metrics["kept"] == 4
    assert metrics["rejected"] == {"unparseable": 1, "bad_timestamp": 1}
    assert metrics["filtered"] == {"non_success_status": 2, "static_asset": 1}


def test_json_is_not_treated_as_asset(spark, tmp_path):
    execute(spark, tmp_path)
    urls = {r["url"] for r in spark.read.parquet(str(tmp_path / "curated")).collect()}
    assert "/data.json" in urls
    assert "/cart" in urls


def test_partitioned_by_event_date(spark, tmp_path):
    execute(spark, tmp_path)
    partitions = sorted(p.name for p in (tmp_path / "curated").iterdir() if p.name.startswith("event_date="))
    assert partitions == ["event_date=2026-04-06", "event_date=2026-04-07"]


def test_quarantine_keeps_original_line(spark, tmp_path):
    execute(spark, tmp_path)
    rows = spark.read.parquet(str(tmp_path / "quarantine")).collect()
    assert {r["reason"] for r in rows} == {"unparseable", "bad_timestamp"}
    assert "totally broken line" in {r["line"] for r in rows}


def test_rerun_is_idempotent(spark, tmp_path):
    execute(spark, tmp_path)
    run(spark, tmp_path / "raw", tmp_path / "curated", tmp_path / "quarantine", tmp_path / "metrics.json")
    assert spark.read.parquet(str(tmp_path / "curated")).count() == 4
