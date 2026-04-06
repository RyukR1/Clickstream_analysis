# Website Clickstream Trend Analysis - Project Documentation

## 🐳 Docker Setup Required

**Start here:** [DOCKER_QUICKSTART.md](../DOCKER_QUICKSTART.md) - Run in 5 minutes!

For detailed Docker reference, see [DOCKER_SETUP.md](DOCKER_SETUP.md).

---

## Overview
This project demonstrates a complete end-to-end big data pipeline for analyzing website clickstream data, similar to how companies like Amazon and Netflix track user behavior. It integrates Apache Flume, Hadoop/HDFS, Apache Pig, and Apache Hive to build a scalable system for trend analysis.

## Project Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLICKSTREAM PIPELINE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: INGESTION           Phase 2: CLEANING               │
│  (Apache Flume)               (Apache Pig)                     │
│       │                            │                          │
│   Spool Dir ────────────> HDFS ────────────> Cleaned Data     │
│   /home/.../logs  (raw)            (processed)                │
│                                                                 │
│                       Phase 3: ANALYSIS                         │
│                       (Apache Hive/SQL)                         │
│                            │                                   │
│                      ┌──────┴──────┐                           │
│                      │ Trend Query │                           │
│                      │ Insights    │                           │
│                      └─────────────┘                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Phase 1: Data Ingestion (Apache Flume)

### Purpose
Flume monitors a local directory for new log files and automatically streams them to HDFS in real-time, eliminating manual data transfer.

### Configuration File
- Location: `phase1_ingestion/flume-conf.properties`
- Source: Spooling Directory (`/home/ryukr2/project/logs`)
- Sink: HDFS (`hdfs://localhost:9000/user/ryukr2/clickstream/raw/`)

### How It Works
1. **Source Component**: Monitors `/home/ryukr2/project/logs` for new files
2. **Buffering**: Events are buffered in memory before being flushed to HDFS
3. **Sink Component**: Writes events to HDFS every 300 seconds or when internal buffer fills

### Running Phase 1

See [DOCKER_QUICKSTART.md](../DOCKER_QUICKSTART.md) for Docker-based execution instructions.

### Log Format
Logs follow Apache Common Log Format (CLF):
```
IP User [Timestamp] "HTTP_METHOD /URL HTTP_VERSION" STATUS_CODE SIZE
```

Example:
```
192.168.1.100 - [01/Feb/2024:10:30:45 +0000] "GET /products/laptop HTTP/1.1" 200 2048
```

---

## Phase 2: Data Cleaning (Apache Pig)

### Purpose
Raw logs contain noise:
- Failed requests (404, 500 errors)
- Static assets (.jpg, .gif, .css, .js, .png)
- Metadata that's not relevant for trend analysis

Pig filters this data and extracts only relevant information for analysis.

### Processing Steps
1. **Load**: Read raw logs from HDFS
2. **Filter**: Remove status codes != 200 and static asset requests
3. **Transform**: Extract IP, date, and URL fields
4. **Store**: Save cleaned data as CSV to HDFS

### Script
- Location: `phase2_cleaning/clean_logs.pig`
- Filters applied:
  - `status == 200` (only successful requests)
  - Excludes: `.jpg`, `.gif`, `.css`, `.js`, `.png`, `.ico`, `favicon`

### Input
- Location: `/user/ryukr2/clickstream/raw/`
- Format: Space-separated values (Apache CLF)

### Output
- Location: `/user/ryukr2/clickstream/processed/`
- Format: Comma-separated values (CSV)
- Columns: `ip, visit_date, url`

### Running Phase 2

See [DOCKER_QUICKSTART.md](../DOCKER_QUICKSTART.md) for Docker-based execution instructions.

### Pig Syntax Notes
- `LOAD`: Read data from HDFS
- `FILTER`: Filter records based on conditions
- `FOREACH GENERATE`: Transform/extract specific columns
- `STORE`: Write output to HDFS

---

## Phase 3: Trend Analysis (Apache Hive)

### Purpose
Hive provides a SQL interface to query cleaned data in HDFS, enabling trend analysis without writing MapReduce code.

### Table Definition
- Location: `phase3_analysis/create_table.hql`
- Table Type: External (points to HDFS data)
- Data Format: CSV with comma delimiters

### Available Queries
- Location: `phase3_analysis/trend_queries.hql`
- Includes 8 pre-built queries:

| Query | Purpose |
|-------|---------|
| Query 1-2 | Top 5-10 most visited pages |
| Query 3 | Daily traffic trends |
| Query 4 | Top pages by date (time-series) |
| Query 5 | Unique visitor count |
| Query 6 | Pages by unique visitors |
| Query 7 | Top visitor IPs (traffic generators) |
| Query 8 | Traffic by page category |

### Running Phase 3

See [DOCKER_QUICKSTART.md](../DOCKER_QUICKSTART.md) for Docker-based execution instructions.

### Query Examples

**Find top 5 pages:**
```sql
SELECT url, COUNT(*) as click_count
FROM clickstream
GROUP BY url
ORDER BY click_count DESC
LIMIT 5;
```

**Daily traffic analysis:**
```sql
SELECT visit_date, COUNT(*) as daily_clicks
FROM clickstream
GROUP BY visit_date
ORDER BY visit_date DESC;
```

---

## Project Structure

```
ClickSteam\ analysis/
├── phase1_ingestion/
│   └── flume-conf.properties       # Flume configuration
├── phase2_cleaning/
│   └── clean_logs.pig               # Pig script for data cleaning
├── phase3_analysis/
│   ├── create_table.hql             # Create Hive table
│   └── trend_queries.hql            # Analysis queries
├── logs/                            # Local log directory
├── scripts/
│   ├── generate_sample_logs.sh      # Generate test data
│   ├── start_flume.sh               # Start Flume agent
│   ├── run_pig_job.sh               # Run Pig job
│   └── run_hive_queries.sh          # Run Hive queries
├── docs/
│   ├── README.md                    # This file
│   ├── SETUP_GUIDE.md               # Installation & setup
│   └── TROUBLESHOOTING.md           # Common issues
└── results/                         # Query results (auto-created)
```

---

## Prerequisites

See [DOCKER_SETUP.md](DOCKER_SETUP.md) for Docker environment setup.

---

## Complete Pipeline Execution

See [DOCKER_QUICKSTART.md](../DOCKER_QUICKSTART.md) for step-by-step Docker instructions to run the complete pipeline.

---

## Portfolio Highlights

### 1. **End-to-End Pipeline**
- Demonstrates complete data flow: Ingestion → Storage → Processing → Analysis
- Not just running queries; building production-like infrastructure

### 2. **Scalability**
- Can handle millions of logs by adding more DataNodes to HDFS
- MapReduce handles distributed processing automatically
- Flume can ingest from multiple sources simultaneously

### 3. **Enterprise Technologies**
- Real tools used by companies like Netflix, Amazon, LinkedIn
- Combines multiple components in a cohesive architecture
- Shows understanding of distributed systems

### 4. **Extension Potential**
- Export results via PyHive to Python for predictive analytics
- Time-series forecasting on traffic patterns
- Learn about data warehousing (Hive) vs NoSQL (HBase)

---

## Common Commands

### HDFS Commands
```bash
# List contents of HDFS directories
hdfs dfs -ls /user/ryukr2/clickstream/raw/
hdfs dfs -ls /user/ryukr2/clickstream/processed/

# View HDFS file contents
hdfs dfs -cat /user/ryukr2/clickstream/raw/file_name

# Check HDFS storage usage
hdfs dfs -du -h /user/ryukr2/clickstream/
```

### Hive Commands
```bash
# Connect to Hive shell
hive

# List all tables
SHOW TABLES;

# Describe table structure
DESCRIBE clickstream;

# Show table statistics
SHOW TBLPROPERTIES clickstream;

# Run a query
SELECT * FROM clickstream LIMIT 10;
```

### Pig Commands
```bash
# Run Pig script
pig -f script.pig

# Run in local mode (for testing)
pig -x local -f script.pig

# Run in verbose mode
pig -v -f script.pig
```

### Flume Commands
```bash
# Start Flume agent
flume-ng agent --conf ./conf --conf-file config.properties --name agent1

# View Flume logs
tail -f flume.log
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

---

## Next Steps & Enhancements

1. **Real-Time Dashboards**: Connect to tools like Grafana/Kibana for live visualization
2. **ML Integration**: Use Spark MLlib for anomaly detection in traffic patterns
3. **A/B Testing**: Analyze how different page layouts affect click patterns
4. **User Segmentation**: Identify user groups based on browsing behavior
5. **Predictive Analytics**: Forecast traffic spikes using time-series models

---

## References

- [Apache Flume Documentation](https://flume.apache.org/)
- [Apache Pig Documentation](https://pig.apache.org/)
- [Apache Hive Documentation](https://hive.apache.org/)
- [Hadoop Official Guide](https://hadoop.apache.org/docs/)

---

**Created for Data Science Portfolio | Masters in Data Science, IIIT Lucknow**
