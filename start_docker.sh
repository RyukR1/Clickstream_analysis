#!/bin/bash

# Docker Startup Script for Clickstream Pipeline
# This starts the Docker container and initializes all services
# Usage: ./start_docker.sh [amd|arm]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONTAINER_NAME="clickstream"
PROJECT_DIR="$(pwd)"
ARCHITECTURE="${1:-amd}"  # Default to amd, can be arm for M1/M2 Mac

# Docker Hub image (pre-built and published)
DOCKERHUB_IMAGE="ryukr1/clickstream-pipeline:latest"
LOCAL_IMAGE="clickstream-pipeline:latest"

# Check which architecture base image to use (only needed for local build)
if [ "$ARCHITECTURE" = "arm" ]; then
    BASE_IMAGE="silicoflare/hadoop:arm"
else
    BASE_IMAGE="silicoflare/hadoop:amd"
fi
IMAGE="$LOCAL_IMAGE"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting Clickstream Docker Container${NC}"
echo -e "${BLUE}Architecture: $ARCHITECTURE${NC}"
echo -e "${BLUE}Base Image: $BASE_IMAGE${NC}"
echo -e "${BLUE}Target Image: $IMAGE${NC}"
echo -e "${BLUE}========================================${NC}\n"

# ── Get the Docker image ───────────────────────────────────────────
# Try pulling from Docker Hub first (fast).
# Falls back to building locally if pull fails.
if docker image inspect "$LOCAL_IMAGE" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Image '$LOCAL_IMAGE' already exists locally — skipping pull${NC}\n"
else
    echo -e "${YELLOW}Pulling pre-built image from Docker Hub: $DOCKERHUB_IMAGE${NC}"
    if docker pull "$DOCKERHUB_IMAGE" 2>/dev/null; then
        docker tag "$DOCKERHUB_IMAGE" "$LOCAL_IMAGE"
        echo -e "${GREEN}✓ Pulled and tagged as '$LOCAL_IMAGE'${NC}\n"
    else
        echo -e "${YELLOW}Docker Hub pull failed — building locally (this takes ~5 min)...${NC}"
        docker build --build-arg BASE_IMAGE="$BASE_IMAGE" -t "$LOCAL_IMAGE" .
        echo -e "${GREEN}✓ Local build complete${NC}\n"
    fi
fi

# Check if container already running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Container '$CONTAINER_NAME' already running${NC}"
    echo -e "${YELLOW}Connecting to existing container...${NC}"
    docker exec -it "$CONTAINER_NAME" /bin/bash
    exit 0
fi

# Check if container exists but not running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Starting existing container...${NC}"
    docker start "$CONTAINER_NAME"
    docker exec -it "$CONTAINER_NAME" /bin/bash
    exit 0
fi

# Create new container
echo -e "${YELLOW}Creating new Docker container...${NC}"

sudo docker run -d --name "$CONTAINER_NAME" \
  --hostname namenode \
  -p 9870:9870 \
  -p 8088:8088 \
  -p 9864:9864 \
  -p 9083:9083 \
  -v "$PROJECT_DIR:/clickstream" \
  --entrypoint /bin/bash \
  "$IMAGE" \
  -c "sleep infinity"

# Wait for container to start
echo -e "${YELLOW}Waiting for container to start...${NC}"
sleep 3

# Enter container
echo -e "${GREEN}✓ Container started successfully${NC}"
echo -e "${GREEN}✓ Port mappings:${NC}"
echo -e "   - 9870: NameNode UI (http://localhost:9870)"
echo -e "   - 8088: ResourceManager UI (http://localhost:8088)"
echo -e "   - 9864: DataNode UI (http://localhost:9864)"
echo -e "   - 9083: Hive MetaStore"
echo ""
echo -e "${YELLOW}Connecting to container...${NC}\n"

docker exec -it "$CONTAINER_NAME" /bin/bash
