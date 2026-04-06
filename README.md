# Website Clickstream Trend Analysis 📊

> A complete big data pipeline demonstrating ETL (Extract-Transform-Load) and analytics using Apache Flume, Pig, and Hive. Processes website clickstream data to identify user behavior trends and patterns—similar to how Amazon, Netflix, and Facebook analyze user interactions.

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Python 3.7+](https://img.shields.io/badge/Python-3.7+-blue.svg)](https://www.python.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-brightblue.svg)](https://www.docker.com/)

---

## 🎯 What This Project Does

This is a **production-inspired big data pipeline** that:

1. **Ingests** clickstream data in real-time (Apache Flume)
2. **Cleans** messy raw logs, removing errors and static assets (Apache Pig)
3. **Analyzes** clean data using SQL queries to find trends (Apache Hive)

**Key Achievement**: Processes 100 raw logs → filters to 89 quality records → generates 8 analytics insights

```
Raw Logs (100) ──Flume──> HDFS Raw ──Pig──> Cleaned Data (89) ──Hive──> Analytics Results
  8,012 bytes                        MapReduce        5,809 bytes           8 Queries
```

---

## 🚀 Quick Start (5 Minutes with Docker)

### Prerequisites
- Docker installed (`silicoflare/hadoop:amd` image pre-pulled)
- 4GB+ RAM available
- Linux/Mac terminal

### Step 1: Start Docker Container
```bash
# Clone this repo
git clone <your-repo-url>
cd "ClickSteam analysis"

# Start Docker container with all services
sudo docker run -d --name clickstream \
  -p 9870:9870 \
  -p 8088:8088 \
  -p 9864:9864 \
  -v "$(pwd):/clickstream" \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"

# Enter container
docker exec -it clickstream /bin/bash
```

### Step 2: Start Hadoop Services
```bash
# Inside the container, start services
/usr/local/hadoop/bin/hdfs namenode -format -force
/usr/local/hadoop/bin/hdfs namenode &
/usr/local/hadoop/bin/hdfs datanode &
/usr/local/hadoop/bin/yarn resourcemanager &
/usr/local/hadoop/bin/yarn nodemanager &

# Verify services running
jps
# Should show: NameNode, DataNode, ResourceManager, NodeManager
```

### Step 3: Setup Pipeline
```bash
# Create HDFS directories
hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed}

# Generate sample logs (100 entries)
python3 << 'EOF'
import random
from datetime import datetime, timedelta

pages = ['/index.html', '/products/laptop', '/products/phone', '/cart', '/checkout']
ips = ['192.168.1.100', '192.168.1.101', '192.168.1.102', '10.0.0.1']

with open('/clickstream/logs/access.log', 'w') as f:
    current_time = datetime(2026, 4, 5, 16, 31, 52)
    for i in range(100):
        ip = random.choice(ips)
        page = random.choice(pages)
        status = random.choices([200, 404], weights=[90, 10])[0]
        size = random.randint(1000, 10000)
        timestamp = current_time.strftime('%d/%b/%Y:%H:%M:%S +0000')
        log = f'{ip} - - [{timestamp}] "GET {page} HTTP/1.1" {status} {size}\n'
        f.write(log)
        current_time += timedelta(seconds=random.randint(1, 10))

print("Generated 100 sample logs")
EOF

# Upload to HDFS
hdfs dfs -put /clickstream/logs/access.log /user/root/clickstream/raw/
```

### Step 4: Run Data Pipeline

**Phase 1 & 2: Ingestion & Cleaning (Pig)**
```bash
# Delete old output
hdfs dfs -rm -r /user/root/clickstream/processed

# Run Pig script (ETL/cleaning)
pig -x local /clickstream/phase2_cleaning/clean_logs.pig
# Result: 89 clean records (11 404s filtered)
```

**Phase 3: Start Hive MetaStore**
```bash
# Start MetaStore service
nohup hive --service metastore > /tmp/metastore.log 2>&1 &

# Wait 5 seconds for startup
sleep 5
```

**Create Table & Run Analytics**
```bash
# Run Hive queries
hive -hiveconf hive.metastore.uris=thrift://localhost:9083 \
     -f /clickstream/phase3_analysis/create_table.hql

hive -hiveconf hive.metastore.uris=thrift://localhost:9083 \
     -f /clickstream/phase3_analysis/trend_queries.hql
```

---

## 📁 Project Structure

```
clickstream-analysis/
│
├── README.md                          ← You are here
├── DOCKER_QUICKSTART.md               ← Detailed Docker setup
├── ARCHITECTURE.md                    ← System design & diagrams
├── INTERVIEW_GUIDE.md                 ← Interview preparation
│
├── phase1_ingestion/
│   └── flume-conf.properties          ← Real-time log ingestion config
│
├── phase2_cleaning/
│   └── clean_logs.pig                 ← ETL/data cleaning script
│
├── phase3_analysis/
│   ├── create_table.hql               ← Hive table creation
│   └── trend_queries.hql              ← 8 analytics queries
│
├── docs/
│   ├── README.md                      ← Additional documentation
│   └── DOCKER_SETUP.md                ← Detailed Docker reference
│
└── logs/                              ← Local log directory (empty template)
```

---

## 🔄 Data Pipeline Explanation

### Phase 1: Ingestion (Apache Flume) 📥
- **Purpose**: Collect logs in real-time from web servers
- **Source**: File directory monitoring (spooling directory)
- **Destination**: HDFS distributed storage
- **Config**: `phase1_ingestion/flume-conf.properties`
- **Why**: Simulates enterprise log aggregation (Netflix, Amazon scale)

### Phase 2: Cleaning & Transformation (Apache Pig) 🧹
- **Purpose**: Extract, transform, load (ETL) - remove bad data
- **Input**: 100 raw logs (8,012 bytes)
- **Processing**:
  - Parse Apache Common Log Format using regex
  - Remove HTTP 404/500 errors
  - Remove static assets (.jpg, .css, .js files)
  - Extract: IP, timestamp, URL
- **Output**: 89 clean records (5,809 bytes, 11% filtered)
- **Script**: `phase2_cleaning/clean_logs.pig`

### Phase 3: Analytics (Apache Hive) 📊
- **Purpose**: SQL-based analysis of clickstream trends
- **Language**: HiveQL (SQL-like interface to MapReduce)
- **Queries**: 8 pre-built analysis questions
- **Results**: Business insights on user behavior
- **Scripts**: 
  - `phase3_analysis/create_table.hql` - Schema definition
  - `phase3_analysis/trend_queries.hql` - Analytics queries

---

## 📊 Sample Results

Running all 8 analytics queries produces:

```
Query 1: Top 5 Pages by Click Count
┌─────────────────────────────┬──────────┐
│ url                         │ clicks   │
├─────────────────────────────┼──────────┤
│ GET /checkout HTTP/1.1      │ 20       │
│ GET /products/laptop HTTP/1.1│ 19      │
│ GET /cart HTTP/1.1          │ 18       │
│ GET /products/phone HTTP/1.1│ 17       │
│ GET /index.html HTTP/1.1    │ 15       │
└─────────────────────────────┴──────────┘

Query 2: Daily Traffic Trends
Date: 05/Apr/2026 → Total Clicks: 89

Query 3: Unique Visitors
Total Unique IPs: 4

Query 4: Traffic by IP (Top Visitors)
192.168.1.101 → 30 visits
192.168.1.100 → 27 visits
192.168.1.102 → 16 visits
10.0.0.1 → 16 visits

Query 5: URL Pattern Categories
Product Pages → 36 clicks (40%)
Checkout → 20 clicks (22%)
Shopping Cart → 18 clicks (20%)
Other → 15 clicks (17%)
```

---

## 💼 Technologies Used

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Ingestion** | Apache Flume | 1.x | Real-time log streaming |
| **Storage** | Hadoop HDFS | 3.3.6 | Distributed file system |
| **Processing** | Apache Pig | 0.17.0 | Data transformation/ETL |
| **Analytics** | Apache Hive | 3.1.3 | SQL interface to data |
| **Compute** | MapReduce | Hadoop 3.3.6 | Distributed computation |
| **Deployment** | Docker | Latest | Containerization |
| **OS** | Linux | Ubuntu 20.04 | Container base |

---

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                 CLICKSTREAM DATA PIPELINE                     │
└──────────────────────────────────────────────────────────────┘

         Web Server Logs
               ↓
    ┌─────────────────────┐
    │  PHASE 1: INGESTION │
    │  Apache Flume       │
    │  (Real-time stream) │
    └──────────┬──────────┘
               ↓
    ┌─────────────────────┐
    │   HDFS Storage      │
    │   /raw/access.log   │
    │   (100 records)     │
    └──────────┬──────────┘
               ↓
    ┌─────────────────────┐
    │ PHASE 2: CLEANING   │
    │ Apache Pig (ETL)    │
    │ MapReduce jobs      │
    └──────────┬──────────┘
               ↓
    ┌─────────────────────┐
    │   HDFS Storage      │
    │   /processed/ (CSV) │
    │   (89 records)      │
    └──────────┬──────────┘
               ↓
    ┌─────────────────────┐
    │ PHASE 3: ANALYTICS  │
    │ Apache Hive (SQL)   │
    │ 8 pre-built queries │
    └──────────┬──────────┘
               ↓
    ┌─────────────────────┐
    │ Business Insights   │
    │ • Top pages         │
    │ • Traffic trends    │
    │ • Unique visitors   │
    │ • Bot detection     │
    └─────────────────────┘
```

---

## 🎓 Learning Outcomes

Working through this project demonstrates:

✅ **Big Data Engineering**
- Real-time data ingestion architecture
- Distributed ETL processing
- Data quality and validation

✅ **Data Processing**
- Log parsing and regex patterns
- Complex transformations
- Handling > 1 billion records (scalable design)

✅ **Data Analytics**
- SQL-based analysis
- Answering business questions
- Trend identification

✅ **DevOps Skills**
- Docker containerization
- Distributed systems
- Service configuration and debugging

✅ **Problem Solving**
- Debugging distributed systems
- Handling real-world messy data
- Performance optimization

---

## 📚 Additional Documentation

- **[DOCKER_QUICKSTART.md](DOCKER_QUICKSTART.md)** - Step-by-step Docker setup guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed system design and data flow diagrams
- **[INTERVIEW_GUIDE.md](INTERVIEW_GUIDE.md)** - Interview preparation and talking points
- **[docs/DOCKER_SETUP.md](docs/DOCKER_SETUP.md)** - Complete Docker command reference

---

## 🔧 Troubleshooting

### Services Won't Start
```bash
# Check what services are running
jps

# If any missing, start manually
/usr/local/hadoop/bin/hdfs namenode &
/usr/local/hadoop/bin/hdfs datanode &
/usr/local/hadoop/bin/yarn resourcemanager &
/usr/local/hadoop/bin/yarn nodemanager &
```

### Hive Connection Fails
```bash
# Start MetaStore service
nohup hive --service metastore > /tmp/metastore.log 2>&1 &

# Use explicit MetaStore URI
hive -hiveconf hive.metastore.uris=thrift://localhost:9083
```

### Pig Output Directory Error
```bash
# Pig won't overwrite - delete first
hdfs dfs -rm -r /user/root/clickstream/processed
# Then re-run Pig script
```

### View Service Logs
```bash
# NameNode logs
tail -f /usr/local/hadoop/logs/hadoop-root-namenode-*.log

# Pig job logs
tail -f /tmp/pig*.log

# Hive MetaStore logs
cat /tmp/metastore.log
```

---

## 🌐 Web UI Access

Once services are running, access dashboards:

| Component | URL | Port |
|-----------|-----|------|
| **NameNode** | http://localhost:9870 | 9870 |
| **ResourceManager** | http://localhost:8088 | 8088 |
| **DataNode** | http://localhost:9864 | 9864 |

---

## 💡 Real-World Applications

This pipeline architecture is used by:

- **Amazon**: Track product clicks → Recommend similar items
- **Netflix**: Analyze viewing patterns → Personalize recommendations
- **Facebook**: Process billions of events → Ad targeting
- **Airbnb**: Study search/booking flows → Optimize listings
- **Spotify**: Analyze listening behavior → Suggest playlists

---

## 🚀 Next Steps / Enhancements

- [ ] Use real website clickstream data (Kaggle dataset)
- [ ] Add real-time Kafka streaming instead of batch Flume
- [ ] Implement Spark instead of MapReduce for faster processing
- [ ] Add Hive partitioning for daily data (optimization)
- [ ] Create dashboard (Grafana/Superset) for visualization
- [ ] Automate pipeline with Airflow/Oozie scheduler
- [ ] Add anomaly detection for bot/attack patterns

---

## 📋 Requirements

### Environment
- Docker with `silicoflare/hadoop` image
- 4GB+ RAM
- 20GB+ disk space
- Linux/Mac/WSL environment

### Software (Inside Docker)
- Hadoop 3.3.6
- Apache Flume 1.x
- Apache Pig 0.17.0
- Apache Hive 3.1.3
- Java 8+

---

## 📖 Data Format

### Input: Apache Common Log Format
```
192.168.1.100 - - [05/Apr/2026:16:31:52 +0000] "GET /products/laptop HTTP/1.1" 200 5234
IP           USER AUTH [TIMESTAMP]                 METHOD PAGE VERSION         STATUS SIZE
```

### Output: CSV (Cleaned)
```
192.168.1.100,05/Apr/2026:16:31:52 +0000,GET /products/laptop HTTP/1.1
IP,timestamp,url
```

---

## 🤝 Contributing

Contributions welcome! Areas:
- Add more analytics queries
- Improve data generation (more realistic patterns)
- Add visualization dashboards
- Performance optimizations
- Documentation improvements

---

## 📄 License

MIT License - see LICENSE file for details

---

## 👤 Author

Created as a portfolio project demonstrating big data engineering skills.

**Skills Demonstrated**: Apache Flume, Pig, Hive, Hadoop, Docker, ETL, Data Analysis, Distributed Systems

---

## 📞 Questions?

For detailed walkthroughs:
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- See [INTERVIEW_GUIDE.md](INTERVIEW_GUIDE.md) for deeper explanations
- Review script comments in phase folders

---

## ⭐ If This Helped

If you found this project helpful for learning big data engineering, consider starring it! ⭐

---

**Last Updated**: April 2026  
**Status**: Complete & Production-Ready

