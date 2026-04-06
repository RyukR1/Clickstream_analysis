# 🐳 Docker Quick Start (Fastest!)

## ⚡ Fastest Way to Get Running: 5 Minutes!

Since you have the Docker image already pulled, this is the **fastest** path!

---

## 🚀 Step-by-Step (5 minutes total)

### Step 1: Start Docker Container (2 minutes)

**For AMD/Intel (most systems):**
```bash
sudo docker run -d --name clickstream \
  -p 9870:9870 \
  -p 8088:8088 \
  -p 9864:9864 \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"
```

**For Mac M1/M2:**
```bash
sudo docker run -d --name clickstream \
  -p 9870:9870 \
  -p 8088:8088 \
  -p 9864:9864 \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:arm \
  -c "sleep infinity"
```

Enter the container:
```bash
docker exec -it clickstream /bin/bash
```

### Step 2: Start Hadoop Services (30 seconds)

Inside the container:
```bash
# If start-dfs.sh doesn't work, use direct daemon startup:
/usr/local/hadoop/bin/hdfs namenode -format -force  # Format once
/usr/local/hadoop/bin/hdfs namenode &               # Start NameNode
/usr/local/hadoop/bin/hdfs datanode &               # Start DataNode  
/usr/local/hadoop/bin/yarn resourcemanager &        # Start ResourceManager
/usr/local/hadoop/bin/yarn nodemanager &            # Start NodeManager

# Verify
jps  # Should show NameNode, DataNode, ResourceManager, NodeManager
```

### Step 3: Setup HDFS (30 seconds)

```bash
# Create directories
hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed}

# Verify
hdfs dfs -ls /user/root/clickstream/
```

### Step 4: Generate Logs (1 minute)

```bash
# Create logs directory
mkdir -p /root/logs

# Generate 100 sample clickstream logs
python3 << 'EOF'
import random
from datetime import datetime
import os

ips = ["192.168.1.100", "192.168.1.101", "192.168.1.102", "10.0.0.1"]
urls = ["/index.html", "/products/laptop", "/products/phone", "/cart", "/checkout"]

with open("/root/logs/access.log", "w") as f:
    for i in range(100):
        ip = random.choice(ips)
        url = random.choice(urls)
        timestamp = datetime.now().strftime("%d/%b/%Y:%H:%M:%S +0000")
        status = 200 if random.random() > 0.1 else 404
        size = random.randint(512, 5000)
        
        line = f'{ip} - [{timestamp}] "GET {url} HTTP/1.1" {status} {size}\n'
        f.write(line)

print("✓ Created /root/logs/access.log with 100 entries")
EOF
```

### Step 5: Copy Logs to HDFS (30 seconds)

```bash
# Put logs in HDFS raw directory
hdfs dfs -put /root/logs/access.log /user/root/clickstream/raw/

# Verify
hdfs dfs -ls /user/root/clickstream/raw/
hdfs dfs -cat /user/root/clickstream/raw/access.log | head -5
```

### Step 6: Run Pig Job (1 minute)

```bash
# Navigate to project
cd /clickstream

# Run Pig (local mode is faster for testing)
pig -x local -f phase2_cleaning/clean_logs.pig

# Verify output
hdfs dfs -ls /user/root/clickstream/processed/
```

### Step 7: Run Hive Analysis (1 minute)

```bash
# Create table
hive -f /clickstream/phase3_analysis/create_table.hql

# Run queries
hive -f /clickstream/phase3_analysis/trend_queries.hql

# Or interactive:
hive
# Inside Hive shell:
# SELECT url, COUNT(*) as clicks FROM clickstream GROUP BY url ORDER BY clicks DESC LIMIT 5;
# exit;
```

---

## ✅ Success!

You should see:
- ✓ Logs generated
- ✓ Logs in HDFS raw directory
- ✓ Pig cleaned the data
- ✓ Hive queries ran successfully
- ✓ Results showing top pages, daily trends, etc.

---

## 📊 View Results

**Option 1: Save to file and view outside container**
```bash
# Inside container
hive -f /clickstream/phase3_analysis/trend_queries.hql > /clickstream/results.txt 2>&1

# Exit container (Ctrl+D or type 'exit')
exit

# View results on host
cat /home/ryukr2/Projects/ClickSteam\ analysis/results.txt
```

**Option 2: Interactive exploration in Hive**
```bash
# Inside container
hive

# Try these queries:
SELECT COUNT(*) FROM clickstream;
SELECT DISTINCT url FROM clickstream;
SELECT url, COUNT(*) as clicks FROM clickstream GROUP BY url ORDER BY clicks DESC;
exit;
```

---

## 🔄 Complete One-Shot Command

Want to run everything in one go? Use this script inside the container:

```bash
#!/bin/bash
set -e

echo "🚀 Starting Clickstream Pipeline in Docker..."

# Start services
echo "1️⃣ Starting HDFS..."
/usr/local/hadoop/bin/hdfs namenode -format -force > /dev/null 2>&1
/usr/local/hadoop/bin/hdfs namenode > /dev/null 2>&1 &
/usr/local/hadoop/bin/hdfs datanode > /dev/null 2>&1 &
sleep 5

echo "1️⃣ Starting YARN..."
/usr/local/hadoop/bin/yarn resourcemanager > /dev/null 2>&1 &
/usr/local/hadoop/bin/yarn nodemanager > /dev/null 2>&1 &
sleep 3

# Setup
echo "2️⃣ Setting up HDFS directories..."
hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed} 2>/dev/null || true

# Generate logs
echo "3️⃣ Generating sample logs..."
mkdir -p /root/logs
for i in {1..100}; do
  echo "192.168.1.$((RANDOM % 254 + 1)) - [$(date '+%d/%b/%Y:%H:%M:%S +0000')] \"GET /page$i HTTP/1.1\" 200 2048" >> /root/logs/access.log
done

# Ingest
echo "4️⃣ Ingesting to HDFS..."
hdfs dfs -put /root/logs/access.log /user/root/clickstream/raw/ 2>/dev/null || true

# Clean
echo "5️⃣ Cleaning data with Pig..."
cd /clickstream
pig -x local -f phase2_cleaning/clean_logs.pig

# Analyze
echo "6️⃣ Analyzing with Hive..."
hive -f phase3_analysis/create_table.hql > /dev/null 2>&1
hive -f phase3_analysis/trend_queries.hql

echo "✅ COMPLETE!"
```

Save as `/root/run_pipeline.sh`, then:
```bash
chmod +x /root/run_pipeline.sh
./run_pipeline.sh
```

---

## 🛑 Cleanup

When done:

```bash
# Exit container
exit

# Stop container (from host)
docker stop clickstream

# Remove container
docker rm clickstream

# Optional: Remove image
docker rmi silicoflare/hadoop:amd
```

---

## 🔗 Access Web UIs

While container is running:

- **NameNode**: http://localhost:9870
- **DataNode**: http://localhost:9864
- **ResourceManager**: http://localhost:8088

---

## 💡 Tips & Tricks

### Modify Scripts Without Reinstalling
The `/clickstream` directory is mounted from your host, so changes are reflected instantly:
```bash
# On host
edit /home/ryukr2/Projects/ClickSteam\ analysis/phase3_analysis/trend_queries.hql

# Inside container
hive -f /clickstream/phase3_analysis/trend_queries.hql  # Sees your changes immediately
```

### Run Multiple Containers
```bash
sudo docker run -d --name clickstream2 \
  -p 9871:9870 \
  -p 8089:8088 \
  -p 9865:9864 \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"
```

### Persist Data Between Runs
```bash
# Use named volume
sudo docker run -d --name clickstream \
  -v clickstream_data:/var/hadoop \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"
```

### Debug Mode
```bash
# See detailed output
docker exec clickstream hdfs dfs -ls /user/root/clickstream/

# Check Hadoop logs
docker exec clickstream tail -f /opt/hadoop/logs/hadoop-root-namenode-*.log
```

---

## ⚡ Performance

- **On local machine:** ~5-10 seconds per job
- **Docker overhead:** Minimal (< 1 second)
- **Total pipeline:** ~2-3 minutes for complete run

---

## 🎯 Next Level

- Modify `clean_logs.pig` to add custom filters
- Create new Hive queries in `trend_queries.hql`
- Generate 1000s more logs for realistic testing
- Explore Spark inside the container

---

**Done! You have a working clickstream analysis pipeline in Docker!** 🎉

Go back to: [Main Documentation](../INDEX.md)
