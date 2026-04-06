# Docker Setup Guide: Clickstream Analysis Project

## ✅ Advantage: Using Docker

Since you've already pulled the `silicoflare/hadoop` Docker image, setup is **dramatically simplified**:

- ✓ No manual tool installation needed
- ✓ Everything pre-configured
- ✓ Same environment every time  
- ✓ Isolated from system dependencies
- ✓ Easy to start/stop

**Tools already installed in the image:**
- HDFS (Hadoop Distributed File System)
- Pig (ETL tool)
- Hive (SQL interface)
- Flume (Real-time ingestion)
- Spark, Kafka, and more

---

## 🚀 Quick Start with Docker

### Step 1: Start the Docker Container

**For AMD/Intel (x86_64) based systems:**
```bash
sudo docker run -d --name hadoop-clickstream \
  -p 9870:9870 \
  -p 8088:8088 \
  -p 9864:9864 \
  -p 9083:9083 \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"
```

**For Mac M1/M2 (ARM-based) systems:**
```bash
sudo docker run -d --name hadoop-clickstream \
  -p 9870:9870 \
  -p 8088:8088 \
  -p 9864:9864 \
  -p 9083:9083 \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:arm \
  -c "sleep infinity"
```

**What these ports are:**
- `9870` - NameNode UI (Hadoop 3.x)
- `8088` - ResourceManager UI
- `9864` - DataNode UI
- `9083` - Hive MetaStore

### Step 2: Enter the Container

```bash
sudo docker exec -it hadoop-clickstream /bin/bash
```

You're now inside the container! Check if tools are installed:

```bash
# Verify tools
which hdfs
which pig
which hive
which flume-ng

# Check versions
pig -version
hive --version
```

### Step 3: Create Project Directories

```bash
# Create project structure inside container
mkdir -p /root/clickstream/{raw,processed,logs}

# Create HDFS directories
hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed}
```

### Step 4: Copy Your Config Files

**In a NEW terminal (outside container):**

```bash
# Copy the project files into container
docker cp /home/ryukr2/Projects/ClickSteam\ analysis/phase1_ingestion/flume-conf.properties \
  hadoop-clickstream:/root/flume-conf.properties

docker cp /home/ryukr2/Projects/ClickSteam\ analysis/phase2_cleaning/clean_logs.pig \
  hadoop-clickstream:/root/clean_logs.pig

docker cp /home/ryukr2/Projects/ClickSteam\ analysis/phase3_analysis/ \
  hadoop-clickstream:/root/
```

---

## 🔄 Running the Pipeline in Docker

### Inside the Container

#### Step 1: Generate Sample Logs

```bash
# Create logs directory
mkdir -p /root/logs

# Generate logs (copy the script content and run inside container)
for i in {1..100}; do
  IPS=("192.168.1.100" "192.168.1.101" "192.168.1.102" "10.0.0.1" "10.0.0.2" "172.16.0.5")
  URLS=('GET /index.html HTTP/1.1' 'GET /products/laptop HTTP/1.1' 'GET /products/phone HTTP/1.1' 'GET /cart HTTP/1.1' 'GET /checkout HTTP/1.1' 'GET /login HTTP/1.1')
  IP=${IPS[$((RANDOM % ${#IPS[@]}))]}
  URL=${URLS[$((RANDOM % ${#URLS[@]}))]}
  STATUS=200
  
  TIMESTAMP=$(date '+%d/%b/%Y:%H:%M:%S +0000')
  echo "$IP - [$TIMESTAMP] \"$URL\" $STATUS 2048" >> /root/logs/access.log
done

echo "✓ Generated 100 sample log entries"
ls -lah /root/logs/
```

#### Step 2: Start HDFS

```bash
# Format namenode (first time only)
/usr/local/hadoop/bin/hdfs namenode -format -force

# Start Hadoop services directly
/usr/local/hadoop/bin/hdfs namenode &
/usr/local/hadoop/bin/hdfs datanode &
/usr/local/hadoop/bin/yarn resourcemanager &
/usr/local/hadoop/bin/yarn nodemanager &

# Verify (should see NameNode, DataNode, ResourceManager, NodeManager)
sleep 3
jps
```

#### Step 3: Start Flume (Optional - for real-time ingestion)

```bash
# Copy logs to HDFS using Flume
cd /root

# For simple file copy to HDFS (no Flume needed for test)
hdfs dfs -put /root/logs/access.log /user/root/clickstream/raw/
```

#### Step 4: Run Pig (Data Cleaning)

```bash
cd /root

# Run Pig script
pig -f clean_logs.pig -x mapreduce
# or for quick testing:
pig -f clean_logs.pig -x local
```

**Verify Pig output:**
```bash
hdfs dfs -ls /user/root/clickstream/processed/
hdfs dfs -cat /user/root/clickstream/processed/* | head -5
```

#### Step 5: Run Hive (Analytics)

**Option A: Run Hive queries from file**
```bash
cd /root/phase3_analysis

# Create table
hive -f create_table.hql

# Run queries
hive -f trend_queries.hql | tee /root/results.txt
```

**Option B: Interactive Hive Shell**
```bash
hive

# Inside Hive shell
SHOW TABLES;
SELECT COUNT(*) FROM clickstream;
SELECT url, COUNT(*) as clicks FROM clickstream GROUP BY url ORDER BY clicks DESC LIMIT 5;
exit;
```

---

## 📊 Complete Docker Workflow

### Terminal 1: Start Container & Run Pipeline

```bash
# Start container
sudo docker run -it --name hadoop-clickstream \
  -p 9870:9870 \
  -p 8088:8088 \
  -p 9864:9864 \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  silicoflare/hadoop:amd /bin/bash

# Inside container:
/usr/local/hadoop/bin/hdfs namenode -format -force
/usr/local/hadoop/bin/hdfs namenode &
/usr/local/hadoop/bin/hdfs datanode &
/usr/local/hadoop/bin/yarn resourcemanager &
/usr/local/hadoop/bin/yarn nodemanager &
sleep 3
jps  # Verify services

# Generate logs
mkdir -p /root/logs
for i in {1..100}; do
  echo "192.168.1.100 - [$(date '+%d/%b/%Y:%H:%M:%S +0000')] \"GET /page$i HTTP/1.1\" 200 2048" >> /root/logs/access.log
done

# Copy to HDFS
hdfs dfs -mkdir -p /user/root/clickstream/{raw,processed}
hdfs dfs -put /root/logs/access.log /user/root/clickstream/raw/

# Run Pig
pig -x local -f /clickstream/phase2_cleaning/clean_logs.pig

# Run Hive
hive -f /clickstream/phase3_analysis/create_table.hql
hive -f /clickstream/phase3_analysis/trend_queries.hql
```

### Terminal 2: Container Management (Optional)

```bash
# From outside container - execute commands
docker exec hadoop-clickstream hdfs dfs -ls /user/root/clickstream/

# View logs
docker logs hadoop-clickstream

# Stop container
docker stop hadoop-clickstream

# Resume container
docker start hadoop-clickstream

# Remove container
docker rm hadoop-clickstream
```

---

## 🔗 Container Port Access

Once running, access cluster UIs locally:

| Service | URL | Notes |
|---------|-----|-------|
| NameNode | http://localhost:9870 | HDFS monitoring (Hadoop 3.x) |
| ResourceManager | http://localhost:8088 | YARN job tracking |
| Hive Metastore | localhost:9083 | Hive metadata |

---

## 🔄 Docker Compose (Optional - For Easier Management)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  hadoop:
    image: silicoflare/hadoop:amd
    container_name: hadoop-clickstream
    ports:
      - "9870:9870"  # NameNode UI
      - "8088:8088"    # ResourceManager UI
      - "9864:9864"    # DataNode UI
      - "9083:9083"    # Hive MetaStore
    volumes:
      - /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream
      - hadoop_data:/var/hadoop
    environment:
      - HADOOP_NAME_NODE=hadoop
      - CLUSTER_NAME=hadoop-cluster
    command: /bin/bash

volumes:
  hadoop_data:
```

**Run with Docker Compose:**
```bash
docker-compose up -d
docker-compose exec hadoop /bin/bash
docker-compose logs -f
docker-compose down
```

---

## 💾 Managing Data Persistence

### Option 1: Named Volume (Recommended)
```bash
sudo docker run -d \
  -v clickstream_data:/var/hadoop \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"
```

### Option 2: Host Directory Mount
```bash
sudo docker run -d \
  -v /home/ryukr2/hadoop_data:/var/hadoop \
  -v /home/ryukr2/Projects/ClickSteam\ analysis:/clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"
```

### Option 3: Copy Out Results
```bash
# Copy HDFS data to host
docker cp hadoop-clickstream:/user/root/clickstream /home/ryukr2/Projects/ClickSteam\ analysis/docker_results
```

---

## 🐛 Troubleshooting Docker

### Issue: "Cannot connect to HDFS"
```bash
# Verify HDFS is running inside container
docker exec hadoop-clickstream jps
# Should show: NameNode, DataNode, ResourceManager, NodeManager

# If not running, start again with direct daemon commands
docker exec hadoop-clickstream /usr/local/hadoop/bin/hdfs namenode &
docker exec hadoop-clickstream /usr/local/hadoop/bin/hdfs datanode &
docker exec hadoop-clickstream /usr/local/hadoop/bin/yarn resourcemanager &
docker exec hadoop-clickstream /usr/local/hadoop/bin/yarn nodemanager &
```

### Issue: "Container exits immediately"
```bash
# For background containers, use entrypoint with sleep:
sudo docker run -d --name hadoop-clickstream \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"

# For interactive sessions, use -it:
sudo docker run -it silicoflare/hadoop:amd /bin/bash
```

### Issue: "Permission denied errors"
```bash
# Inside container, use appropriate user
# Default might be root - check with: whoami

# Or run as root
sudo docker run -it --user root silicoflare/hadoop:amd /bin/bash
```

### Issue: "Port already in use"
```bash
# Use different ports
sudo docker run -d \
  -p 9871:9870 \
  -p 8089:8088 \
  -p 9865:9864 \
  --entrypoint /bin/bash \
  silicoflare/hadoop:amd \
  -c "sleep infinity"
```

### View container logs
```bash
docker logs hadoop-clickstream
docker logs -f hadoop-clickstream  # Follow in real-time
```

---

## 🎯 Quick Commands Reference

### Container Management
```bash
# List all containers
docker ps -a

# Start container
docker start hadoop-clickstream

# Stop container
docker stop hadoop-clickstream

# Remove container
docker rm hadoop-clickstream

# View container stats
docker stats hadoop-clickstream
```

### File Transfer
```bash
# Copy FROM host TO container
docker cp /local/path hadoop-clickstream:/container/path

# Copy FROM container TO host
docker cp hadoop-clickstream:/container/path /local/path

# List container file system
docker exec hadoop-clickstream ls -la /root/
```

### Execute Commands
```bash
# Run single command
docker exec hadoop-clickstream hdfs dfs -ls /

# Run interactive bash
docker exec -it hadoop-clickstream /bin/bash

# Check Java version
docker exec hadoop-clickstream java -version

# Check Pig version
docker exec hadoop-clickstream pig -version
```

---

## ✅ Docker vs Manual Setup Comparison

| Aspect | Docker | Manual |
|--------|--------|--------|
| Setup Time | 5 min (pull + run) | 1-2 hours |
| Dependencies | Only Docker needed | Java, Hadoop, Pig, Hive, Flume |
| Configuration | Pre-configured | Many config files |
| Reproducibility | Identical every time | Varies by system |
| Learning | Great for practice | Better for understanding |
| Production | Not recommended | Common approach |

---

## 🚀 Recommended Docker Workflow

1. **Development & Testing** (You are here!)
   - Use Docker for quick iterations
   - Modify scripts independently
   - Test pipeline repeatedly

2. **Learning**
   - Explore tools inside container
   - Understand data flow
   - Experiment with queries

3. **Demonstration**
   - Easy to show working system
   - No system dependencies
   - Reproducible runs

4. **Production** (Future)
   - Consider Kubernetes orchestration
   - Multi-node cluster setup
   - High availability configuration

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [silicoflare/hadoop Image](https://hub.docker.com/r/silicoflare/hadoop)
- [Hadoop in Docker](https://hadoop.apache.org/documentation.html)
- [Docker Compose Guide](https://docs.docker.com/compose/)

---

**Ready to run in Docker? Follow the Quick Start section above!** 🐳
