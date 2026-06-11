#!/bin/bash

# Multi-Node Hadoop Cluster Startup Script
# Starts: 1 NameNode + 3 DataNodes via docker-compose
# Usage: ./start_multinode.sh [up|down|status|logs|pipeline]

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ARCHITECTURE="${ARCH:-amd}"
BASE_IMAGE="silicoflare/hadoop:${ARCHITECTURE}"
IMAGE="clickstream-pipeline:latest"
PROJECT_DIR="$(pwd)"

banner() {
    echo -e "${BLUE}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║     Clickstream Multi-Node Hadoop Cluster        ║"
    echo "  ║     1 NameNode + 3 DataNodes (HDFS + YARN)       ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

build_image() {
    echo -e "${YELLOW}Building Docker image (base: $BASE_IMAGE)...${NC}"
    docker build --build-arg BASE_IMAGE="$BASE_IMAGE" -t "$IMAGE" .
    echo -e "${GREEN}✓ Image built: $IMAGE${NC}"
}

start_cluster() {
    banner

    # Build image if it doesn't exist
    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        build_image
    else
        echo -e "${GREEN}✓ Image '$IMAGE' already exists (skipping build)${NC}"
        echo -e "${YELLOW}  Tip: run with 'rebuild' to force a fresh build${NC}"
    fi

    echo -e "${YELLOW}Starting cluster (namenode + 3 datanodes)...${NC}"
    docker compose up -d

    echo ""
    echo -e "${YELLOW}Waiting for NameNode to leave safe mode (~40-60s)...${NC}"
    echo -e "${YELLOW}(DataNodes start automatically once NameNode is healthy)${NC}"

    # Poll until namenode exits safe mode
    TIMEOUT=120
    ELAPSED=0
    while [ $ELAPSED -lt $TIMEOUT ]; do
        STATUS=$(docker exec hadoop-namenode hdfs dfsadmin -safemode get 2>/dev/null || echo "not ready")
        if echo "$STATUS" | grep -q "Safe mode is OFF"; then
            break
        fi
        printf "."
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
    echo ""

    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -e "${RED}✗ Timed out waiting for NameNode. Check logs: docker compose logs namenode${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ NameNode is out of safe mode!${NC}"

    # Create HDFS directories for the pipeline
    echo -e "${YELLOW}Creating HDFS directories...${NC}"
    docker exec hadoop-namenode hdfs dfs -mkdir -p /user/root/clickstream/raw     2>/dev/null || true
    docker exec hadoop-namenode hdfs dfs -mkdir -p /user/root/clickstream/processed 2>/dev/null || true
    echo -e "${GREEN}✓ HDFS directories ready${NC}"

    # Show cluster status
    echo ""
    echo -e "${BLUE}Cluster Status:${NC}"
    docker exec hadoop-namenode hdfs dfsadmin -report 2>/dev/null | grep -E "Live|Dead|Name|Hostname" || true

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Cluster is UP! 🚀${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Web UIs:"
    echo -e "  • NameNode UI:       ${BLUE}http://localhost:9870${NC}"
    echo -e "  • ResourceManager:   ${BLUE}http://localhost:8088${NC}"
    echo -e "  • DataNode 1 UI:     ${BLUE}http://localhost:9864${NC}"
    echo -e "  • DataNode 2 UI:     ${BLUE}http://localhost:9865${NC}"
    echo -e "  • DataNode 3 UI:     ${BLUE}http://localhost:9866${NC}"
    echo ""
    echo "  Run the pipeline:"
    echo -e "  ${YELLOW}docker exec -it hadoop-namenode bash -c 'cd /clickstream && ./run_pipeline.sh'${NC}"
    echo ""
}

stop_cluster() {
    echo -e "${YELLOW}Stopping cluster...${NC}"
    docker compose down
    echo -e "${GREEN}✓ Cluster stopped${NC}"
}

show_status() {
    echo -e "${BLUE}Container Status:${NC}"
    docker compose ps
    echo ""
    echo -e "${BLUE}HDFS Cluster Report:${NC}"
    docker exec hadoop-namenode hdfs dfsadmin -report 2>/dev/null || echo "NameNode not running"
}

show_logs() {
    SERVICE="${2:-namenode}"
    echo -e "${YELLOW}Logs for: $SERVICE${NC}"
    docker compose logs -f "$SERVICE"
}

run_pipeline() {
    echo -e "${YELLOW}Running Clickstream pipeline on NameNode...${NC}"
    docker exec -it hadoop-namenode bash -c "cd /clickstream && ./run_pipeline.sh"
}

# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────
case "${1:-up}" in
    up|start)
        start_cluster
        ;;
    down|stop)
        stop_cluster
        ;;
    rebuild)
        build_image
        start_cluster
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$@"
        ;;
    pipeline)
        run_pipeline
        ;;
    *)
        echo "Usage: $0 [up|down|rebuild|status|logs [service]|pipeline]"
        echo ""
        echo "  up       — Build image (if needed) and start 1 NameNode + 3 DataNodes"
        echo "  down     — Stop and remove all containers"
        echo "  rebuild  — Force rebuild image then start cluster"
        echo "  status   — Show container + HDFS cluster status"
        echo "  logs     — Follow logs (default: namenode)"
        echo "  pipeline — Run the full ETL pipeline inside the namenode container"
        ;;
esac
