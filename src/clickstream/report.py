import argparse
import re
from datetime import datetime, timezone
from pathlib import Path

from .transform import build_session

QUERY_MARKER = re.compile(r"^-- name: (\w+)\s*$", re.MULTILINE)


def load_queries(sql_path):
    text = Path(sql_path).read_text()
    parts = QUERY_MARKER.split(text)
    return [(parts[i], parts[i + 1].strip().rstrip(";")) for i in range(1, len(parts), 2)]


def render(name, frame):
    rows = frame.collect()
    header = list(frame.columns)
    widths = [max(len(str(c)), *(len(str(r[i])) for r in rows)) if rows else len(str(c)) for i, c in enumerate(header)]
    lines = [f"== {name} ==", "  ".join(str(c).ljust(w) for c, w in zip(header, widths))]
    lines += ["  ".join(str(r[i]).ljust(w) for i, w in enumerate(widths)) for r in rows]
    return "\n".join(lines) + "\n"


def run(spark, curated_path, sql_path, out_path):
    spark.read.parquet(str(curated_path)).createOrReplaceTempView("clickstream")
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    blocks = [f"Clickstream analysis results ({stamp})\n"]
    for name, query in load_queries(sql_path):
        blocks.append(render(name, spark.sql(query)))
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(blocks))
    return out


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Run analytics SQL over curated Parquet")
    parser.add_argument("--curated", required=True)
    parser.add_argument("--sql", default="sql/analytics.sql")
    parser.add_argument("--out", default="results/analysis_results.txt")
    parser.add_argument("--master", default="local[*]")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    spark = build_session("clickstream-report", args.master)
    try:
        out = run(spark, args.curated, args.sql, args.out)
    finally:
        spark.stop()
    print(f"results written to {out}")


if __name__ == "__main__":
    main()
