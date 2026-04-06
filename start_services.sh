#!/bin/bash

# Hadoop Services Startup Script
# Starts all required Hadoop services
# Usage: ./start_services.sh
# Note: Run this INSIDE the Docker container

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting Hadoop Services${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Step 1: Format NameNode (first time only)
echo -e "${YELLOW}Step 1: Formatting NameNode...${NC}"
/usr/local/hadoop/bin/hdfs namenode -format -force 2>&1 | tail -5
echo -e "${GREEN}✓ NameNode formatted${NC}\n"

# Step 2: Start NameNode
echo -e "${YELLOW}Step 2: Starting NameNode...${NC}"
/usr/local/hadoop/bin/hdfs namenode &
sleep 3
echo -e "${GREEN}✓ NameNode started${NC}\n"

# Step 3: Start DataNode
echo -e "${YELLOW}Step 3: Starting DataNode...${NC}"
/usr/local/hadoop/bin/hdfs datanode &
sleep 3
echo -e "${GREEN}✓ DataNode started${NC}\n"

# Step 4: Start ResourceManager (YARN)
echo -e "${YELLOW}Step 4: Starting ResourceManager...${NC}"
/usr/local/hadoop/bin/yarn resourcemanager &
sleep 3
echo -e "${GREEN}✓ ResourceManager started${NC}\n"

# Step 5: Start NodeManager
echo -e "${YELLOW}Step 5: Starting NodeManager...${NC}"
/usr/local/hadoop/bin/yarn nodemanager &
sleep 3
echo -e "${GREEN}✓ NodeManager started${NC}\n"

# Step 6: Start Hive MetaStore
echo -e "${YELLOW}Step 6: Starting Hive MetaStore...${NC}"
nohup hive --service metastore > /tmp/metastore.log 2>&1 &
sleep 3
echo -e "${GREEN}✓ Hive MetaStore started${NC}\n"

# Step 7: Verify all services running
echo -e "${YELLOW}Step 7: Verifying services...${NC}"
echo -e "${BLUE}Active Java processes (jps):${NC}"
jps

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ All services started successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Web UIs available:${NC}"
echo -e "  NameNode:       http://localhost:9870"
echo -e "  ResourceManager: http://localhost:8088"
echo -e "  DataNode:       http://localhost:9864"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Create HDFS directories: hdfs dfs -mkdir -p /user/root/clickstream/raw"
echo -e "  2. Run pipeline: ./run_pipeline.sh"
echo ""
