# Project Architecture & Data Flow

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SYSTEM ARCHITECTURE OVERVIEW                     │
└─────────────────────────────────────────────────────────────────────┘

                        Real-World Website
                               ↓
                        HTTP Requests/Clicks
                               ↓
                    ┌──────────────────────┐
                    │  Web Server Logs     │
                    │  (Apache/Nginx)      │
                    │  /home/.../logs/     │
                    └──────────────────────┘
                               ↓
                    ┌──────────────────────┐
        ╔═══════════│ PHASE 1: INGESTION    │═══════════╗
        ║           │ (Apache Flume)       │           ║
        ║           │ Real-time Streaming  │           ║
        ║           └──────────────────────┘           ║
        ║                      ↓                        ║
        ║           ┌──────────────────────┐           ║
        ║           │    HDFS/Hadoop       │           ║
        ║           │  Raw Data Storage    │           ║
        ║           │ /clickstream/raw/    │           ║
        ║           └──────────────────────┘           ║
        ║                      ↓                        ║
        ║           ┌──────────────────────┐           ║
        ║════════╪══│ PHASE 2: CLEANING    │═══════════╣
                ║   │ (Apache Pig)         │           ║
                ║   │ ETL/Filtering        │           ║
                ║   └──────────────────────┘           ║
                ║              ↓                        ║
                ║   ┌──────────────────────┐           ║
                ║   │  HDFS Storage        │           ║
                ║   │ Cleaned Data         │           ║
                ║   │ /clickstream/proc/   │           ║
                ║   └──────────────────────┘           ║
                ║              ↓                        ║
                ║   ┌──────────────────────┐           ║
                ╚═══│ PHASE 3: ANALYSIS    │═══════════╝
                    │ (Apache Hive)        │
                    │ SQL-based Queries    │
                    └──────────────────────┘
                              ↓
                   ┌──────────────────────┐
                   │   INSIGHTS           │
                   │ ┌─────────────────┐  │
                   │ │ Top Pages       │  │
                   │ │ Trends          │  │
                   │ │ User Patterns   │  │
                   │ │ Traffic Spikes  │  │
                   │ └─────────────────┘  │
                   └──────────────────────┘
                              ↓
                   ┌──────────────────────┐
                   │  Future Work         │
                   │ - Python Analytics   │
                   │ - ML/Forecasting     │
                   │ - Dashboards         │
                   └──────────────────────┘
```

---

## Data Flow Diagram

### Phase 1: Data Ingestion
```
┌─────────────────────────────────────────────────────────────┐
│ INPUT: Web Server Logs (Apache Common Log Format)           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  192.168.1.100 - [01/Feb/2024:10:30:45 +0000]            │
│  "GET /products/laptop HTTP/1.1" 200 2048               │
│                                                             │
│  192.168.1.101 - [01/Feb/2024:10:30:46 +0000]            │
│  "GET /cart HTTP/1.1" 200 1024                           │
│                                                             │
│  192.168.1.100 - [01/Feb/2024:10:30:47 +0000]            │
│  "GET /products/phone.jpg HTTP/1.1" 200 5120  ← NOISE    │
│                                                             │
│  192.168.1.102 - [01/Feb/2024:10:30:48 +0000]            │
│  "GET /notfound HTTP/1.1" 404 0  ← ERROR                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
        ┌───────────────────────────────────────┐
        │   Phase 1: Apache Flume              │
        ├───────────────────────────────────────┤
        │ • Monitors: /home/.../logs/          │
        │ • Source: Spooling Directory         │
        │ • Transport: Real-time streaming     │
        │ • Channel: In-memory buffer          │
        │ • Sink: HDFS write                   │
        └───────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ OUTPUT: Raw Data Stored in HDFS                             │
│ Location: /user/ryukr2/clickstream/raw/                     │
│ Format: Space-separated (unchanged)                         │
│ Size: Grows with incoming logs                              │
├─────────────────────────────────────────────────────────────┤
│ Note: Includes ALL logs - raw, unfiltered, messy            │
└─────────────────────────────────────────────────────────────┘
```

### Phase 2: Data Cleaning & Transformation
```
┌─────────────────────────────────────────────────────────────┐
│ INPUT: Raw HDFS Data (from Flume)                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  192.168.1.100 - [01/Feb/2024:10:30:45 +0000]            │
│  "GET /products/laptop HTTP/1.1" 200 2048               │
│                                                             │
│  192.168.1.101 - [01/Feb/2024:10:30:46 +0000]            │
│  "GET /cart HTTP/1.1" 200 1024                           │
│                                                             │
│  192.168.1.100 - [01/Feb/2024:10:30:47 +0000]            │
│  "GET /products/phone.jpg HTTP/1.1" 200 5120             │
│                                                             │
│  192.168.1.102 - [01/Feb/2024:10:30:48 +0000]            │
│  "GET /notfound HTTP/1.1" 404 0                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
        ┌───────────────────────────────────────┐
        │   Phase 2: Apache Pig Script          │
        ├───────────────────────────────────────┤
        │ FILTER RULES:                         │
        │ ✓ Keep: status == 200                │
        │ ✗ Remove: .jpg, .gif, .css, .js     │
        │ ✗ Remove: .png, .ico, favicon        │
        │                                       │
        │ EXTRACT: IP, Date, URL only          │
        │ CONVERT: Space-delimited → CSV       │
        └───────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ OUTPUT: Cleaned Data (CSV format)                           │
│ Location: /user/ryukr2/clickstream/processed/               │
│ Format: Comma-separated values                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  192.168.1.100,01/Feb/2024,GET /products/laptop HTTP/1.1 │
│                                                             │
│  192.168.1.101,01/Feb/2024,GET /cart HTTP/1.1             │
│                                                             │
│  (removed: phone.jpg, notfound, favicon, etc)             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Phase 3: Analysis & Insights
```
┌─────────────────────────────────────────────────────────────┐
│ INPUT: Cleaned CSV Data from HDFS                           │
│ Location: /user/ryukr2/clickstream/processed/               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Pig Output (cleaned):                                    │
│  ip,visit_date,url                                        │
│  192.168.1.100,01/Feb/2024,GET /products/laptop ...     │
│  192.168.1.101,01/Feb/2024,GET /cart HTTP/1.1            │
│  ... (100s or 1000s of records)                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
        ┌───────────────────────────────────────┐
        │  Phase 3: Apache Hive                 │
        ├───────────────────────────────────────┤
        │ • Creates SQL table from HDFS data    │
        │ • Enables SQL-style queries           │
        │ • Uses MapReduce for distributed      │
        │   processing (built-in)               │
        └───────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ QUERY 1: Top 5 Most Visited Pages                           │
├─────────────────────────────────────────────────────────────┤
│ SELECT url, COUNT(*) as click_count                        │
│ FROM clickstream                                            │
│ GROUP BY url                                                │
│ ORDER BY click_count DESC LIMIT 5                          │
│                                                             │
│ OUTPUT:                                                     │
│ url                              click_count              │
│ GET /products/laptop HTTP/1.1    45                       │
│ GET /cart HTTP/1.1               32                       │
│ GET /checkout HTTP/1.1           28                       │
│ GET /search?q=... HTTP/1.1       15                       │
│ GET /products/phone HTTP/1.1     12                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ QUERY 2-8: Additional Analytics                             │
├─────────────────────────────────────────────────────────────┤
│ • Daily traffic trends                                      │
│ • Time-series analysis                                      │
│ • Unique visitor counts                                     │
│ • Top visitor IPs                                           │
│ • Page categories (products, cart, checkout, etc)           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
        ┌───────────────────────────────────────┐
        │  BUSINESS INSIGHTS                    │
        ├───────────────────────────────────────┤
        │ • What pages attract most traffic     │
        │ • Which time periods are busiest      │
        │ • How users navigate the site         │
        │ • Patterns for optimization           │
        │ • Bottlenecks in user journey         │
        └───────────────────────────────────────┘
```

---

## Component Responsibilities

### Apache Flume (Phase 1) - Real-time Ingestion
**Role**: Stream log data from source to HDFS

| Aspect | Details |
|--------|---------|
| **Source Component** | Spooling Directory source (`spooldir`) |
| **Monitoring Path** | `/home/ryukr2/project/logs/` |
| **Detection** | Automatically finds new files in directory |
| **Processing** | Reads files line-by-line as events |
| **Channel (Buffer)** | In-memory channel (capacity: 1000 events) |
| **Sink (Output)** | HDFS sink to `/user/ryukr2/clickstream/raw/` |
| **Guarantee** | At-least-once delivery (may duplicate) |
| **Format** | DataStream (text format) |
| **Rollover** | Every 300 seconds or when buffer full |

**Advantages:**
- Decouples data collection from processing
- Handles backpressure from HDFS
- Can scale to multiple sources
- No code changes needed - configuration-only

---

### Apache Pig (Phase 2) - ETL & Cleaning
**Role**: Transform and filter raw data

| Aspect | Details |
|--------|---------|
| **Language** | Pig Latin (high-level, SQL-like) |
| **Execution** | MapReduce jobs (distributed processing) |
| **Compiler** | Translates Pig Latin to MapReduce jobs |
| **Input** | Reads space-delimited logs from HDFS |
| **Processing Steps** | 1. Load → 2. Filter → 3. Transform → 4. Store |
| **Parallelism** | Automatic across HDFS data blocks |
| **Output** | CSV format to `/user/ryukr2/clickstream/processed/` |

**Filters Applied:**
- Status code must be 200 (successful requests)
- Exclude: `.jpg`, `.gif`, `.css`, `.js`, `.png`, `.ico`, `favicon`

**Transformation:**
- Extract 3 columns: `ip`, `visit_date`, `url`
- Convert timestamp format if needed
- Flatten data structure

---

### Apache Hive (Phase 3) - SQL Analytics
**Role**: SQL interface for data analysis

| Aspect | Details |
|--------|---------|
| **Language** | HiveQL (SQL-like syntax) |
| **Table Type** | External (points to HDFS data) |
| **Execution** | MapReduce jobs (optimization automatic) |
| **Serialization** | CSV format with comma delimiter |
| **Location** | `/user/ryukr2/clickstream/processed/` |
| **Metastore** | Derby database (embedded) |
| **Query Types** | Aggregation, grouping, filtering, sorting |

**Table Schema:**
```
+----------+------ -------+-----------+
| Column   | Type | Notes |
+----------+----------+-----------+
| ip       | STRING | Visitor IP address |
| visit_date | STRING | DD/Mon/YYYY format |
| url      | STRING | HTTP request/URL |
+----------+----------+-----------+
```

---

## Data Transformation Pipeline

### Step-by-Step Data Changes

**Stage 1 - Raw Web Server Log**
```
192.168.1.100 - [01/Feb/2024:10:30:45 +0000] "GET /products/laptop HTTP/1.1" 200 2048
└─ Unstructured, mixed data types, includes status codes
```

**Stage 2 - Flume Transport**
```
192.168.1.100 - [01/Feb/2024:10:30:45 +0000] "GET /products/laptop HTTP/1.1" 200 2048
└─ Stored in HDFS as-is, in space-separated format
```

**Stage 3 - Pig Transformation**
```
192.168.1.100,01/Feb/2024,GET /products/laptop HTTP/1.1
└─ Filtered (200 only), extracted (IP, date, URL), CSV format
```

**Stage 4 - Hive Table**
```
Columns: ip | visit_date | url
Values:  192.168.1.100 | 01/Feb/2024 | GET /products/laptop HTTP/1.1
└─ Queryable via SQL, aggregatable, filterable
```

**Stage 5 - Analysis Result**
```
url                              click_count
GET /products/laptop HTTP/1.1    45
GET /cart HTTP/1.1               32
...
└─ Business insights ready for decision-making
```

---

## Distributed Processing at Scale

### How the Pipeline Scales

```
Small Dataset (100 MB)              Large Dataset (100 GB)
│                                   │
├─ Flume: 1 agent → processes and   ├─ Flume: Multiple agents on
│  sends to HDFS in real-time       │  different servers, all feeding
│                                   │  to same HDFS cluster
├─ Pig: Runs 1-2 MapReduce jobs    ├─ Pig: Parallel processing:
│  sequ sequentially on data blocks   │  • Job 1: Load on 100 blocks
│                                   │  • Job 2: Filter on 100 blocks
│                                   │  • Combined: 4x faster
├─ Hive: Single machine handles     ├─ Hive: Distributed query execution
│  query                             │  • Group By across 100 mappers
│                                   │  • Aggregation in reducers
│                                   │  • Automatic parallelism
│                                   │
└─ Total Time: ~2 minutes           └─ Total Time: ~3 minutes
                                       (only 1.5x longer, not 1000x!)
```

### Hadoop MapReduce Distribution

```
HDFS Files (stored on 3 DataNodes):
├─ Block 1 (DataNode 1): 128 MB
├─ Block 2 (DataNode 2): 128 MB
├─ Block 3 (DataNode 3): 128 MB
└─ Block 4 (DataNode 1): 50 MB

Pig Job:
├─ Map Phase (parallel, co-located with data):
│  ├─ Mapper 1 → processes Block 1
│  ├─ Mapper 2 → processes Block 2
│  ├─ Mapper 3 → processes Block 3
│  └─ Mapper 4 → processes Block 4
│
├─ Shuffle & Sort (group by key):
│  └─ Combines all outputs
│
└─ Reduce Phase (parallel):
   ├─ Reducer 1 → aggregates group 1
   ├─ Reducer 2 → aggregates group 2
   └─ Reducer 3 → aggregates group 3

Output: Merged and sorted results
```

---

## System Requirements & Constraints

### Memory & Disk Usage

```
Service               Memory      Disk        Purpose
─────────────────────────────────────────────────────────
Hadoop NameNode       1-2 GB      50 GB       Metadata storage
Hadoop DataNode       512 MB      1-10 TB     Actual data
Flume Agent           256-512 MB  5-10 GB     Buffering
Pig (MapReduce)       2-4 GB      varies      Processing
Hive MetaStore (Derby) 256 MB     1 GB        Table metadata
─────────────────────────────────────────────────────────
Total Minimum         ~4-5 GB     ~20 GB      Test environment
Recommended (Prod)    8+ GB       100+ GB     Real workloads
```

### Performance Considerations

| Factor | Optimization |
|--------|-------------|
| **Data Volume** | HDFS automatically partitions across blocks |
| **Data Velocity** | Flume's buffering handles traffic spikes |
| **Query Speed** | Hive caches metadata, parallel execution |
| **Latency** | Trade-off: Batch process every 5 min vs real-time |
| **Reliability** | HDFS replication (default 3x), MapReduce retry |

---

## Extension Opportunities

```
Current Pipeline:
Logs → Flume → HDFS → Pig → HDFS → Hive → SQL Analysis

Future Enhancements:
                                        ↓
                                    Results
                                        ↓
                    ┌───────────────────┼───────────────────┐
                    ↓                   ↓                   ↓
                ╔═════════╗         ╔═════════╗         ╔═════════╗
                ║ Grafana ║         ║  Spark  ║         ║ Python  ║
                ║DashBoard║         ║   ML    ║         ║ Jupyter ║
                ╚═════════╝         ╚═════════╝         ╚═════════╝
                    ↓                   ↓                   ↓
                Live UI            Anomaly             Time-Series
                                  Detection           Forecasting
```

### Potential Additions

1. **Real-time Dashboards**: Grafana + Elasticsearch
2. **Machine Learning**: Spark MLlib for recommendations
3. **Predictive Analytics**: Python + statsmodels for forecasting
4. **A/B Testing**: Custom analytics on variants
5. **User Segmentation**: Clustering algorithms

---

## Conclusion

This architecture demonstrates a complete data pipeline using enterprise-grade technologies. It shows understanding of:

- ✅ **Real-time data ingestion** (Flume)
- ✅ **ETL & data cleaning** (Pig)
- ✅ **Distributed SQL analytics** (Hive)
- ✅ **HDFS for scalable storage**
- ✅ **MapReduce for parallel processing**
- ✅ **Data architecture design**

Perfect for a Data Science portfolio! 🚀
