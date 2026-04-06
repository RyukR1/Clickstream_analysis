# Automation Guide: Running Pipeline Automatically

## 📜 Shell Scripts Included

This project now includes shell scripts to **automate everything**:

| Script | Purpose | When to Use |
|--------|---------|------------|
| `run_pipeline.sh` | Complete pipeline execution | Main script - does everything |
| `start_docker.sh` | Start Docker container | Before running anything |
| `start_services.sh` | Start Hadoop services | First time setup inside container |

---

## 🚀 Quick Start: Automated Pipeline

### Step 1: Make Scripts Executable

```bash
cd "/home/ryukr2/Projects/ClickSteam analysis"
chmod +x run_pipeline.sh start_docker.sh start_services.sh
```

### Step 2: Start Docker Container

```bash
./start_docker.sh amd  # Use 'arm' for M1/M2 Mac

# This automatically:
# ✓ Creates/starts container
# ✓ Mounts project folder
# ✓ Opens interactive shell inside container
```

### Step 3: Initialize Hadoop Services (First Time Only)

```bash
# Inside container:
./start_services.sh

# This automatically:
# ✓ Formats NameNode
# ✓ Starts NameNode, DataNode
# ✓ Starts ResourceManager, NodeManager
# ✓ Starts Hive MetaStore
# ✓ Shows all running services
```

### Step 4: Create HDFS Directories

```bash
# Inside container, run once:
hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed}
```

### Step 5: Run Complete Pipeline

```bash
# Inside container:
./run_pipeline.sh

# This automatically:
# ✓ Generates 100 sample logs
# ✓ Uploads to HDFS
# ✓ Runs Pig cleaning (removes 11% bad data)
# ✓ Creates Hive table
# ✓ Runs 8 analytics queries
# ✓ Displays results

# Total time: ~2 minutes
```

---

## 🎯 What Each Script Does

### 1. **run_pipeline.sh** - Main Pipeline Script

```bash
./run_pipeline.sh              # Run complete pipeline
./run_pipeline.sh --generate   # Only generate logs
./run_pipeline.sh --upload     # Only upload to HDFS
./run_pipeline.sh --clean      # Only clean data with Pig
./run_pipeline.sh --analyze    # Only run analytics
./run_pipeline.sh --help       # Show all options
```

**Process Flow:**
```
Generate 100 logs
  ↓
Upload to HDFS raw directory
  ↓
Delete old processed data
  ↓
Run Pig ETL (MapReduce job)
  ↓
Create Hive table schema
  ↓
Run 8 analytics queries
  ↓
Display results
```

**Features:**
- ✅ Colored output (helps read progress)
- ✅ Error checking at each step
- ✅ Detailed logging
- ✅ Automatic cleanup
- ✅ Can run individual steps

---

### 2. **start_docker.sh** - Docker Automation

```bash
./start_docker.sh amd   # Start for AMD/Intel Linux
./start_docker.sh arm   # Start for Mac M1/M2
```

**What It Does:**
1. Checks if container exists
2. If not, creates new container with:
   - Port mappings (9870, 8088, 9864, 9083)
   - Volume mount (project folder)
   - keeps running in background
3. Connects you to interactive shell

**Smart Features:**
- Reuses existing container if running
- Auto-restarts stopped container
- Handles both AMD and ARM architectures

---

### 3. **start_services.sh** - Hadoop Services

```bash
./start_services.sh
```

**Steps:**
1. Format NameNode (creates file system)
2. Start NameNode daemon
3. Start DataNode daemon
4. Start ResourceManager (YARN)
5. Start NodeManager
6. Start Hive MetaStore
7. Verify with `jps` command
8. Show web UI URLs

**Output Shows:**
```
NameNode listening on port 9870
ResourceManager listening on port 8088
DataNode listening on port 9864
Hive MetaStore listening on port 9083
```

---

## ⏰ Schedule Pipeline to Run Automatically

### Option 1: Run Daily at Midnight

```bash
# Edit crontab
crontab -e

# Add this line:
0 0 * * * cd /home/ryukr2/Projects/ClickSteam\ analysis && docker exec clickstream /clickstream/run_pipeline.sh >> /tmp/pipeline.log 2>&1
```

**What This Does:**
- Runs pipeline every day at 00:00 (midnight)
- Logs output to `/tmp/pipeline.log`
- Runs inside Docker container automatically

**Log File:**
```bash
# View logs
tail -f /tmp/pipeline.log

# See last 100 lines
tail -100 /tmp/pipeline.log
```

### Option 2: Run Every Hour

```bash
# Every hour at minute 0
0 * * * * cd /home/ryukr2/Projects/ClickSteam\ analysis && docker exec clickstream /clickstream/run_pipeline.sh >> /tmp/pipeline.log 2>&1
```

### Option 3: Run Every 15 Minutes

```bash
# Every 15 minutes
*/15 * * * * cd /home/ryukr2/Projects/ClickSteam\ analysis && docker exec clickstream /clickstream/run_pipeline.sh >> /tmp/pipeline.log 2>&1
```

---

## 📺 Example: Automated Daily Analysis

### Setup (Do Once)

```bash
# 1. Start services
./start_services.sh

# 2. Create directories
hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed}

# 3. Schedule pipeline
crontab -e
# Add: 0 0 * * * cd /path/to/project && docker exec clickstream /clickstream/run_pipeline.sh >> /tmp/pipeline.log 2>&1
```

### What Happens Automatically

```
Every day at 00:00 (midnight):
  1. Generate 100 new log entries
  2. Upload to HDFS
  3. Clean data (remove 11% bad records)
  4. Run 8 analytics queries
  5. Results appear (could save to file)
  
Results available for morning review!
```

---

## 🔧 Advanced: Modify for Your Data

### Scenario: Analyze Real Website Logs

**Step 1: Copy your logs to project**
```bash
cp /var/log/apache2/access.log /home/ryukr2/Projects/ClickSteam\ analysis/logs/
```

**Step 2: Modify `run_pipeline.sh`**
```bash
# Change this line:
# FROM: python3 << 'PYTHON_EOF' (generates fake logs)
# TO: # Skip log generation, use real logs

# Just remove or comment out the generate_logs() call
```

**Step 3: Run pipeline**
```bash
./run_pipeline.sh
```

### Scenario: Send Results to Email

**Create email script:**
```bash
# Create: email_results.sh

RESULTS="/tmp/pipeline_results.txt"

hive -hiveconf hive.metastore.uris=thrift://localhost:9083 \
     -f /clickstream/phase3_analysis/trend_queries.hql > "$RESULTS" 2>&1

# Email results
cat "$RESULTS" | mail -s "Daily Clickstream Analysis" your_email@example.com
```

**Update crontab:**
```bash
0 0 * * * cd /path && ./email_results.sh
```

---

## 🐛 Troubleshooting Scripts

### Script Not Running

```bash
# Make sure it's executable
chmod +x *.sh

# Check syntax errors
bash -n run_pipeline.sh

# Run with debug output
bash -x run_pipeline.sh
```

### Container Issues

```bash
# Check if running
docker ps | grep clickstream

# View container logs
docker logs clickstream

# Stop container
docker stop clickstream

# Start container
docker start clickstream

# Remove container (and start fresh)
docker rm clickstream
./start_docker.sh amd
```

### Hadoop Service Issues

```bash
# Check services
jps

# Check NameNode health
hdfs dfsadmin -report

# View Hive MetaStore log
cat /tmp/metastore.log
```

---

## 📊 Full Automation Workflow

```
┌─ Every Day at Midnight ─┐
│                         │
└─→ run_pipeline.sh       │
    ├─ Generate logs      │
    ├─ Upload to HDFS     │
    ├─ Clean with Pig     │
    ├─ Run Hive queries   │
    └─ Display results    │
                          │
                    Morning:
                 Results ready
                 for review!
```

---

## ✅ Checklist: Full Automation Setup

- [ ] Make scripts executable: `chmod +x *.sh`
- [ ] Test `start_docker.sh`
- [ ] Test `start_services.sh`
- [ ] Test `run_pipeline.sh` manually
- [ ] Create HDFS directories: `hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed}`
- [ ] Test full pipeline once: `./run_pipeline.sh`
- [ ] Schedule with crontab: `crontab -e`
- [ ] Verify cron job: `crontab -l`
- [ ] Check logs: `tail -f /tmp/pipeline.log`

---

## 📝 Script Usage Examples

### Run Pipeline Once
```bash
./run_pipeline.sh
# Output: ~2 minutes, shows all query results
```

### Run Only Data Generation
```bash
./run_pipeline.sh --generate
# Output: 100 logs generated
```

### Run Only Analysis (Skip Generation)
```bash
./run_pipeline.sh --analyze
# Output: 8 queries executed
```

### Start Fresh Docker Container
```bash
docker rm clickstream  # Remove old
./start_docker.sh amd  # Create new
```

### Check Scheduled Jobs
```bash
# View all cron jobs
crontab -l

# View cron log
log show --predicate 'process == "cron"' --last 1h

# View custom pipeline log
tail -f /tmp/pipeline.log
```

---

## 🎯 Why Use Scripts?

| Before Scripts | After Scripts |
|---|---|
| Manual commands <br> Each step typed separately <br> Easy to forget steps <br> Time-consuming | Automated execution <br> One command does all <br> Consistent, repeatable <br> Saves hours per month |
| No scheduling <br> Must run manually | Runs automatically daily <br> Results ready every morning <br> Zero manual effort |
| Hard to debug <br> Errors stop process manually | Error checking at each step <br> Colored output for clarity <br> Logs saved for review |

---

## 🚀 Next Steps

1. **Test Scripts**: Run each script manually first
2. **Verify Output**: Check that pipeline produces expected results
3. **Schedule Job**: Add to crontab for automation
4. **Monitor Logs**: Review `/tmp/pipeline.log` daily
5. **Scale Up**: Gradually increase log size or frequency

---

Your pipeline is now **fully automated** ⚡

