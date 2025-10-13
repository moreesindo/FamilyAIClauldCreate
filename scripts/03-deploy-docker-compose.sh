#!/bin/bash
# FamilyAI Docker Compose Deployment Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}FamilyAI Docker Compose Deployment${NC}"
echo "============================================"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    cp .env.example .env
    echo -e "${YELLOW}Please edit .env file and configure your settings${NC}"
    echo -e "${YELLOW}Then run this script again${NC}"
    exit 0
fi

# Load environment
source .env

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check NVIDIA runtime
if ! docker run --rm --runtime=nvidia nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: NVIDIA Docker runtime is not properly configured${NC}"
    echo "Please install nvidia-container-toolkit"
    exit 1
fi

echo -e "${GREEN}✅ Docker and NVIDIA runtime OK${NC}"

# Deployment mode
MODE=${1:-basic}

case $MODE in
    basic)
        echo "Deploying basic services (no monitoring)..."
        docker compose up -d
        ;;
    full)
        echo "Deploying all services (including monitoring)..."
        docker compose --profile full up -d
        ;;
    monitoring)
        echo "Deploying with monitoring only..."
        docker compose --profile monitoring up -d
        ;;
    *)
        echo -e "${RED}Unknown mode: $MODE${NC}"
        echo "Usage: $0 [basic|full|monitoring]"
        exit 1
        ;;
esac

echo ""
echo "Waiting for services to start..."
sleep 10

# Check service health
echo ""
echo "Checking service health..."
docker-compose ps

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Access points:"
echo "- Web UI: http://localhost:${WEBUI_PORT:-3000}"
echo "- Gateway API: http://localhost:${GATEWAY_PORT:-8080}"
if [ "$MODE" == "full" ] || [ "$MODE" == "monitoring" ]; then
    echo "- Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "- Grafana: http://localhost:${GRAFANA_PORT:-3001}"
fi
echo ""
echo "To view logs: docker-compose logs -f [service-name]"
echo "To stop: docker-compose down"
