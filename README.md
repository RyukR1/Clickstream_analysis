# Website Clickstream Trend Analysis 📊

> A complete big data pipeline that ingests, cleans, and analyzes website clickstream logs using Apache Pig and Hive — all running inside Docker with a pre-built Hadoop ecosystem.

[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Docker Hub](https://img.shields.io/docker/pulls/ryukr1/clickstream-pipeline?label=Docker%20Hub)](https://hub.docker.com/r/ryukr1/clickstream-pipeline)
[![Hadoop](https://img.shields.io/badge/Hadoop-3.3.6-yellow.svg)](https://hadoop.apache.org/)
[![Hive](https://img.shields.io/badge/Hive-3.1.3-orange.svg)](https://hive.apache.org/)
[![Pig](https://img.shields.io/badge/Pig-0.17.0-pink.svg)](https://pig.apache.org/)

---

## 🎯 What This Project Does

This pipeline processes raw Apache web server logs through 3 phases:

```
Raw Logs (100,000 entries)
  ──[Pig ETL]──▶ Cleaned Data (~79,000 records, 404s & assets removed)
  ──[Hive SQL]──▶ 8 Analytics Reports (top pages, trends, visitors)
```

**Result**: Saves query results to `results/analysis_results.txt` — readable from VS Code or terminal.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Docker Container (namenode)                 │
│                                                             │
│  Python Script ──▶ HDFS /raw/ ──▶ Apache Pig ──▶ HDFS /processed/
│  (generates logs)                  (ETL clean)              │
│                                        │                    │
│                                   Apache Hive               │
│                                   (8 SQL queries)           │
│                                        │                    │
│                              results/analysis_results.txt   │
└─────────────────────────────────────────────────────────────┘
```

### Tech Stack

| Phase | Tool | Role |
|-------|------|------|
| Storage | Hadoop HDFS | Distributed filesystem for logs |
| Compute | Apache YARN | Job scheduler for MapReduce |
| ETL | Apache Pig | Cleans raw logs via MapReduce |
| Analytics | Apache Hive | SQL queries on clean data |
| Deployment | Docker | Self-contained environment |

---

## 📁 Project Structure

```
Clickstream_analysis/
│
├── Dockerfile                    ← Builds Hadoop+Hive+Pig image
├── docker-compose.yml            ← Multi-node cluster (3 DataNodes)
│
├── start_docker.sh               ← ⭐ START HERE  (single-node, recommended)
├── start_services.sh             ← Run INSIDE container to start Hadoop+Hive
├── run_pipeline.sh               ← Run INSIDE container to execute pipeline
├── start_multinode.sh            ← Optional: 3-node cluster via docker-compose
│
├── hadoop_config/
│   ├── core-site.xml             ← HDFS default URI (namenode:9000)
│   ├── hdfs-site.xml             ← Replication=1 (single node)
│   ├── hdfs-site-multinode.xml   ← Replication=3 (multi node)
│   └── yarn-site.xml             ← ResourceManager config
│
├── phase1_ingestion/
│   └── flume-conf.properties     ← Apache Flume config (production ingestion)
│
├── phase2_cleaning/
│   └── clean_logs.pig            ← Pig ETL: parse, filter, transform logs
│
├── phase3_analysis/
│   ├── create_table.hql          ← Hive external table definition
│   └── trend_queries.hql         ← 8 analytics queries
│
├── logs/                         ← Generated raw logs (created at runtime)
└── results/                      ← ✅ Query results saved here (created at runtime)
```

---

## 🚀 Quick Start — Run from Scratch

### Prerequisites

- **Docker** installed and running
- **4 GB RAM** minimum available to Docker
- **Linux or macOS** (or WSL2 on Windows)

> **No need to build locally!** The image is pre-built and published on Docker Hub.
> `./start_docker.sh` pulls it automatically.
> 🐳 Docker Hub: [hub.docker.com/r/ryukr1/clickstream-pipeline](https://hub.docker.com/r/ryukr1/clickstream-pipeline)

---

### Step 0 — Fix Docker Permissions (one-time only)

> Skip this if you can already run `docker ps` without `sudo`.

```bash
sudo usermod -aG docker $USER
```

**Then log out and log back in** for the group change to take effect.

---

### Step 1 — Clone and Enter the Project

```bash
git clone <your-repo-url>
cd Clickstream_analysis
```

---

### Step 2 — Build Image & Start Container (host terminal)

```bash
./start_docker.sh
```

What this does:
- Pulls `silicoflare/hadoop:amd` base image (Hadoop + Hive + Pig pre-installed)
- Builds `clickstream-pipeline:latest` with your custom configs
- Creates a container named `clickstream` with hostname `namenode`
- Drops you into a bash shell **inside the container**

> **Apple M1/M2 Mac:** run `./start_docker.sh arm` instead
>
> **First time:** downloading the base image takes **2–5 minutes**. Subsequent runs are instant.

Your prompt will change to:
```
root@namenode:/clickstream#
```

---

### Step 3 — Start All Hadoop & Hive Services (inside container)

```bash
./start_services.sh
```

This starts all 5 services in order:

```
Step 1: NameNode format  (skipped if already formatted — data is preserved)
Step 2: NameNode         (HDFS master — manages file locations)
Step 3: DataNode         (HDFS worker — stores actual data blocks)
Step 4: ResourceManager  (YARN — schedules compute jobs)
Step 5: NodeManager      (YARN worker — runs Pig/MapReduce tasks)
Step 6: Hive MetaStore   (waits up to 90s until port 9083 is open ✓)
Step 7: HDFS directories (creates /user/root/clickstream/raw + /processed)
Step 8: Verify with jps  (shows all running Java processes)
```

Wait until you see:
```
✓ All services started!
```

---

### Step 4 — Run the Full Pipeline (inside container)

```bash
./run_pipeline.sh
```

Pipeline progress:

```
STEP 1 — Generate Logs     → Creates 100,000 Apache log entries
STEP 2 — Upload to HDFS    → Puts logs into distributed storage
STEP 3 — Clean Old Data    → Removes previous Pig output
STEP 4 — Pig ETL           → Filters 404s & static assets (~3 min)
STEP 5 — Create Hive Table → Points Hive at the clean HDFS data
STEP 6 — Run 8 Queries     → Saves results to file
```

> ⏳ **Step 4 (Pig ETL) takes ~3 minutes** — this is normal. Pig runs a MapReduce job.

---

### Step 5 — View Your Results

Results are saved to a file **visible both inside the container and on your host machine**:

```bash
# Inside the container:
cat /clickstream/results/analysis_results.txt

# On your HOST machine (VS Code, terminal, etc.):
cat ~/Clickstream_analysis/results/analysis_results.txt
```

---

## 📊 What the Queries Show

The `results/analysis_results.txt` file contains output from 8 queries:

| Query | Question answered |
|-------|------------------|
| 1 | Top 5 most clicked pages |
| 2 | Top 10 most clicked pages |
| 3 | Daily traffic count by date |
| 4 | Most popular pages per day |
| 5 | Total unique visitors (distinct IPs) |
| 6 | Unique visitors per page |
| 7 | Top IPs by page visits (bot detection) |
| 8 | Traffic by category (Products, Cart, Checkout, etc.) |

---

## 🌐 Web UIs

While the container is running, open these in your browser:

| UI | URL | What you can see |
|----|-----|-----------------|
| HDFS NameNode | http://localhost:9870 | Files in HDFS, storage usage |
| YARN ResourceManager | http://localhost:8088 | Pig MapReduce job status |
| DataNode | http://localhost:9864 | Block-level storage info |

---

## 🔁 Subsequent Runs

When you come back after closing the terminal:

```bash
# On host — reconnect to existing container (no rebuild)
./start_docker.sh

# Inside container — restart all services (needed every container restart)
./start_services.sh

# Re-run the pipeline
./run_pipeline.sh

# OR re-run only the Hive queries (if Pig data is already in HDFS)
./run_pipeline.sh --analyze
```

---

## 🧩 Optional: 3-Node Cluster (Multi-Node)

To run with 1 NameNode + 3 DataNodes (closer to production):

```bash
# On host machine (no need to enter container)
./start_multinode.sh up         # Build + start all 4 containers
./start_multinode.sh status     # Check cluster health
./start_multinode.sh pipeline   # Run the ETL pipeline
./start_multinode.sh down       # Stop everything
```

---

## 🚨 Troubleshooting

### `permission denied while trying to connect to Docker`
```bash
sudo usermod -aG docker $USER
# Then log out and log back in
```

### `DataNode: Unknown host: namenode`
The container was started without the correct hostname. Fix:
```bash
sudo docker rm -f clickstream
./start_docker.sh    # recreates with --hostname namenode
```

### `Hive: Unable to instantiate SessionHiveMetaStoreClient`
MetaStore isn't running. Inside the container:
```bash
# Check if it's running
nc -zv localhost 9083

# Start it manually if not
nohup hive --service metastore > /tmp/metastore.log 2>&1 &
sleep 30

# Then re-run only the analysis steps
./run_pipeline.sh --analyze
```

### `MetaStore did not start in time`
```bash
cat /tmp/metastore.log    # inside container — check what went wrong
```

### Pig output check fails
```bash
# Verify Pig data is in HDFS
hdfs dfs -ls /user/root/clickstream/processed/
hdfs dfs -cat /user/root/clickstream/processed/part-*  | head -20
```

---

## 📖 Data Format

### Input — Apache Common Log Format
```
192.168.1.100 - - [06/Apr/2026:10:00:01 +0000] "GET /products/laptop HTTP/1.1" 200 5234
```

### After Pig ETL — CSV Output
```
192.168.1.100,06/Apr/2026:10:00:01 +0000,GET /products/laptop HTTP/1.1
```

### After Hive — Query Results
```
/products/laptop    14823
/cart               11204
/checkout            9876
...
```

---

## 💼 Skills Demonstrated

- **Apache Pig** — MapReduce-based ETL, log parsing with regex, data filtering
- **Apache Hive** — HiveQL, external tables, aggregations, window functions
- **Hadoop HDFS** — Distributed storage, NameNode/DataNode architecture
- **Apache YARN** — Job scheduling and resource management
- **Docker** — Custom image build, volume mounts, port mapping, multi-container setup
- **Bash scripting** — Service orchestration, health checks, automation

---

## 🔮 Potential Enhancements

- [ ] Replace batch Pig with real-time Apache Kafka + Spark Streaming
- [ ] Add Grafana dashboard for visual analytics
- [ ] Partition Hive table by date for faster queries
- [ ] Add Apache Airflow to schedule daily pipeline runs
- [ ] Integrate with real web server (Nginx) for live log tailing
- [ ] Add anomaly detection for bot/DDoS pattern recognition

---

**Last Updated:** June 2026 | **Status:** ✅ Working
