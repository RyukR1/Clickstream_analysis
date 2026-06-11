#!/bin/bash

# Hadoop Services Startup Script
# Starts all required Hadoop services inside the Docker container
# Usage: ./start_services.sh
# Note: Run this INSIDE the Docker container (root@namenode)

set -e

# Ensure required environment variables and paths are set
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}
export HADOOP_HOME=${HADOOP_HOME:-/usr/local/hadoop}
export HIVE_HOME=${HIVE_HOME:-/usr/local/hive}
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HIVE_HOME/bin

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Starting Hadoop + Hive Services      ${NC}"
echo -e "${BLUE}=======================================${NC}\n"

# ─────────────────────────────────────────────────────────────────────
# Step 1: Format NameNode — ONLY if this is a fresh filesystem
# Formatting every run wipes all HDFS data! We check first.
# ─────────────────────────────────────────────────────────────────────
NAMENODE_DIR="/home/hadoop/hdfs/namenode"
if [ ! -d "$NAMENODE_DIR/current" ]; then
    echo -e "${YELLOW}Step 1: Formatting NameNode (first-time setup)...${NC}"
    /usr/local/hadoop/bin/hdfs namenode -format -force 2>&1 | tail -5
    echo -e "${GREEN}✓ NameNode formatted${NC}\n"
else
    echo -e "${GREEN}✓ NameNode already formatted — skipping (data preserved)${NC}\n"
fi

# ─────────────────────────────────────────────────────────────────────
# Step 2: Start NameNode
# ─────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Step 2: Starting NameNode...${NC}"
/usr/local/hadoop/bin/hdfs namenode &
sleep 5
echo -e "${GREEN}✓ NameNode started${NC}\n"

# ─────────────────────────────────────────────────────────────────────
# Step 3: Start DataNode
# ─────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Step 3: Starting DataNode...${NC}"
/usr/local/hadoop/bin/hdfs datanode &
sleep 5
echo -e "${GREEN}✓ DataNode started${NC}\n"

# ─────────────────────────────────────────────────────────────────────
# Step 4: Start ResourceManager (YARN)
# ─────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Step 4: Starting ResourceManager (YARN)...${NC}"
/usr/local/hadoop/bin/yarn resourcemanager &
sleep 5
echo -e "${GREEN}✓ ResourceManager started${NC}\n"

# ─────────────────────────────────────────────────────────────────────
# Step 5: Start NodeManager
# ─────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Step 5: Starting NodeManager...${NC}"
/usr/local/hadoop/bin/yarn nodemanager &
sleep 5
echo -e "${GREEN}✓ NodeManager started${NC}\n"

# ─────────────────────────────────────────────────────────────────────
# Step 6: Start Hive MetaStore
# ─────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Step 6: Starting Hive MetaStore...${NC}"

# 6a: Create required HDFS directories for Hive
echo -e "${YELLOW}  Creating Hive HDFS directories...${NC}"
hdfs dfs -mkdir -p /tmp/hive                 2>/dev/null || true
hdfs dfs -mkdir -p /user/hive/warehouse      2>/dev/null || true
hdfs dfs -chmod -R 777 /tmp/hive             2>/dev/null || true
hdfs dfs -chmod -R 777 /user/hive/warehouse  2>/dev/null || true
echo -e "${GREEN}  ✓ Hive HDFS dirs ready${NC}"

# 6b: Clear stale Derby lock files (left over from previous container run)
echo -e "${YELLOW}  Clearing any stale Derby lock files...${NC}"
find /clickstream/metastore_db -name "*.lck" -delete 2>/dev/null || true
find /tmp -name "derby*.lck" -delete 2>/dev/null || true
echo -e "${GREEN}  ✓ Derby locks cleared${NC}"

# 6c: Initialise Hive schema — check if valid, wipe and reinit if corrupt
echo -e "${YELLOW}  Checking Hive Derby schema...${NC}"
cd /clickstream
DERBY_DB="/clickstream/metastore_db"

if [ -d "$DERBY_DB" ] && schematool -dbType derby -info >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Derby schema already valid${NC}"
else
    if [ -d "$DERBY_DB" ]; then
        echo -e "${YELLOW}  ⚠ Derby DB found but schema missing/corrupt — reinitializing...${NC}"
        rm -rf "$DERBY_DB"
    else
        echo -e "${YELLOW}  Derby DB not found — initializing fresh...${NC}"
    fi
    schematool -dbType derby -initSchema
    echo -e "${GREEN}  ✓ Derby schema initialized${NC}"
fi

# 6d: Start the MetaStore service (run from /clickstream so Derby path resolves)
echo -e "${YELLOW}  Starting MetaStore service...${NC}"
cd /clickstream
nohup hive --service metastore \
    --hiveconf javax.jdo.option.ConnectionURL="jdbc:derby:;databaseName=/clickstream/metastore_db;create=true" \
    > /tmp/metastore.log 2>&1 &
METASTORE_PID=$!

echo -e "${YELLOW}  Waiting for MetaStore on port 9083 (up to 90s)...${NC}"
TIMEOUT=90
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/9083' 2>/dev/null; then
        echo -e "${GREEN}✓ Hive MetaStore is ready (PID $METASTORE_PID)${NC}\n"
        break
    fi
    printf "."
    sleep 3
    ELAPSED=$((ELAPSED + 3))
done
echo ""

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${RED}✗ MetaStore did not start in ${TIMEOUT}s.${NC}"
    echo -e "${RED}  Check: cat /tmp/metastore.log${NC}"
fi

# ─────────────────────────────────────────────────────────────────────
# Step 7: Create HDFS directories (safe to re-run — uses -p flag)
# ─────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Step 7: Creating HDFS directories...${NC}"
hdfs dfs -mkdir -p /user/root/clickstream/raw     2>/dev/null || true
hdfs dfs -mkdir -p /user/root/clickstream/processed 2>/dev/null || true
echo -e "${GREEN}✓ HDFS directories ready${NC}\n"

# ─────────────────────────────────────────────────────────────────────
# Step 8: Verify all services
# ─────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Step 8: Verifying running Java processes (jps)...${NC}"
jps

echo ""
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  ✓ All services started!              ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "${BLUE}Web UIs (open in your browser):${NC}"
echo -e "  NameNode UI      → http://localhost:9870"
echo -e "  ResourceManager  → http://localhost:8088"
echo -e "  DataNode UI      → http://localhost:9864"
echo ""
echo -e "${YELLOW}Next step — run the pipeline:${NC}"
echo -e "  ./run_pipeline.sh"
echo ""
