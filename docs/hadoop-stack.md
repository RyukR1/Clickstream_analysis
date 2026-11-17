# Legacy Hadoop stack (Pig and Hive)

The first version of this project ran on a Hadoop container: Pig cleaned the logs and Hive queried the result as CSV text. It is kept as a working comparison against the Spark and Parquet pipeline, not as the recommended path.

## Run it

```bash
./start_docker.sh              # host: pull image, open a shell in the container (arm: ./start_docker.sh arm)
./start_services.sh            # container: start HDFS, YARN and the Hive metastore
./run_pipeline.sh              # container: generate logs, put to HDFS, run Pig, create table, run queries
./run_pipeline.sh --analyze    # container: re-run only the Hive queries
./start_multinode.sh up        # host: optional 1 NameNode + 3 DataNodes (replication 3)
```

Results are written to `results/analysis_results.txt`. Web UIs: NameNode `localhost:9870`, ResourceManager `localhost:8088`.

## What differs from the Spark pipeline

| | Hadoop stack | Spark pipeline |
| --- | --- | --- |
| Ingest | `hdfs dfs -put` of one file | Reads a directory of logs |
| Clean | Pig, drops bad rows silently | PySpark, quarantines bad rows with a reason |
| Storage | CSV text, unpartitioned | Parquet, partitioned by date |
| Checks | Row count printed | Reconciliation, null and invariant checks |
| Orchestration | Shell script | Airflow DAG |

The Flume config in `phase1_ingestion/` is not wired into either path. It documents a streaming ingestion design, but nothing runs it.

## Troubleshooting

- `permission denied while trying to connect to Docker`: run `sudo usermod -aG docker $USER`, then log out and back in.
- `DataNode: Unknown host: namenode`: the container needs `--hostname namenode`. Remove it with `docker rm -f clickstream` and rerun `./start_docker.sh`.
- `Unable to instantiate SessionHiveMetaStoreClient`: the metastore is down. Check `nc -zv localhost 9083`, start it with `nohup hive --service metastore > /tmp/metastore.log 2>&1 &`, wait 30 seconds, then run `./run_pipeline.sh --analyze`.
- Pig output missing: check `hdfs dfs -ls /user/root/clickstream/processed/`. Pig will not overwrite an existing output directory, and the pipeline removes it first.
