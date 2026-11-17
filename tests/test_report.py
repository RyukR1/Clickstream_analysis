from clickstream.report import load_queries, run
from clickstream.transform import run as transform_run

LOGS = [
    '10.0.0.1 - - [06/Apr/2026:10:00:01 +0000] "GET /products/laptop HTTP/1.1" 200 100',
    '10.0.0.2 - - [06/Apr/2026:10:05:01 +0000] "GET /products/phone HTTP/1.1" 200 100',
    '10.0.0.1 - - [06/Apr/2026:11:00:01 +0000] "GET /cart HTTP/1.1" 200 100',
    '10.0.0.1 - - [07/Apr/2026:12:00:01 +0000] "POST /checkout HTTP/1.1" 200 100',
    '10.0.0.3 - - [07/Apr/2026:12:00:02 +0000] "GET /payment HTTP/1.1" 200 100',
]


def test_every_query_has_a_name():
    names = [name for name, _ in load_queries("sql/analytics.sql")]
    assert len(names) == len(set(names)) >= 7


def test_all_queries_execute(spark, tmp_path):
    raw = tmp_path / "raw"
    raw.mkdir()
    (raw / "access.log").write_text("\n".join(LOGS) + "\n")
    transform_run(spark, raw, tmp_path / "curated", tmp_path / "q", tmp_path / "m.json")
    out = run(spark, tmp_path / "curated", "sql/analytics.sql", tmp_path / "results.txt")
    text = out.read_text()
    for name, _ in load_queries("sql/analytics.sql"):
        assert f"== {name} ==" in text
    assert "/products/laptop" in text
