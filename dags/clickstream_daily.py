import os
from datetime import datetime, timedelta, timezone

from airflow import DAG

try:
    from airflow.providers.standard.operators.bash import BashOperator
except ImportError:
    from airflow.operators.bash import BashOperator

HOME = os.environ.get("CLICKSTREAM_HOME", "/opt/clickstream")
RAW = f"{HOME}/data/raw/dt={{{{ ds }}}}"
CURATED = f"{HOME}/data/curated"
RUN_DIR = f"{HOME}/data/runs/{{{{ ds }}}}"
ENV = {"PYTHONPATH": f"{HOME}/src"}

with DAG(
    dag_id="clickstream_daily",
    description="Generate, clean, validate and report daily clickstream data",
    start_date=datetime(2026, 4, 6, tzinfo=timezone.utc),
    schedule="@daily",
    catchup=True,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=2), "execution_timeout": timedelta(minutes=30)},
    tags=["clickstream", "batch"],
) as dag:
    ingest = BashOperator(
        task_id="ingest_raw_logs",
        bash_command=(
            f"python -m clickstream.generate --out {RAW}/access.log "
            "--rows 200000 --days 1 --start-date {{ ds }} --seed {{ ds_nodash }}"
        ),
        env=ENV,
        append_env=True,
    )
    transform = BashOperator(
        task_id="transform_to_parquet",
        bash_command=(
            f"python -m clickstream.transform --input {RAW} --output {CURATED} "
            f"--quarantine {RUN_DIR}/quarantine --metrics {RUN_DIR}/metrics.json"
        ),
        env=ENV,
        append_env=True,
    )
    quality = BashOperator(
        task_id="quality_gate",
        bash_command=(
            f"python -m clickstream.quality --metrics {RUN_DIR}/metrics.json --curated {CURATED} "
            f"--report {RUN_DIR}/quality.json --date {{{{ ds }}}}"
        ),
        env=ENV,
        append_env=True,
    )
    report = BashOperator(
        task_id="publish_report",
        bash_command=(
            f"python -m clickstream.report --curated {CURATED} "
            f"--sql {HOME}/sql/analytics.sql --out {RUN_DIR}/analysis_results.txt"
        ),
        env=ENV,
        append_env=True,
    )
    ingest >> transform >> quality >> report
