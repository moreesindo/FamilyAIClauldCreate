#!/bin/bash
# FamilyAI Health Check Script
# Checks the health of all FamilyAI services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
if [ -f .env ]; then
    source .env
fi

# Default ports
CODE_TRADITIONAL_PORT=${CODE_TRADITIONAL_PORT:-8001}
CODE_AGENTIC_PORT=${CODE_AGENTIC_PORT:-8002}
CHAT_ADVANCED_PORT=${CHAT_ADVANCED_PORT:-8003}
CHAT_FAST_PORT=${CHAT_FAST_PORT:-8004}
CHAT_LIGHT_PORT=${CHAT_LIGHT_PORT:-8005}
VISION_PORT=${VISION_PORT:-8006}
WHISPER_PORT=${WHISPER_PORT:-8007}
PIPER_PORT=${PIPER_PORT:-8008}
GATEWAY_PORT=${GATEWAY_PORT:-8080}
WEBUI_PORT=${WEBUI_PORT:-3000}

HOST=${1:-localhost}

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       FamilyAI System Health Check                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

check_service() {
    local name=$1
    local port=$2
    local endpoint=${3:-/health}

    echo -n "Checking $name... "

    response=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST:$port$endpoint 2>/dev/null || echo "000")

    if [ "$response" == "200" ]; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED (HTTP $response)${NC}"
        return 1
    fi
}

check_service_with_metrics() {
    local name=$1
    local port=$2

    echo -n "Checking $name... "

    # Check health endpoint
    health_response=$(curl -s http://$HOST:$port/health 2>/dev/null || echo "{}")

    if echo "$health_response" | grep -q "healthy\|ok"; then
        echo -e "${GREEN}✓ OK${NC}"

        # Try to get metrics if available
        metrics=$(curl -s http://$HOST:$port/metrics 2>/dev/null | grep -E "memory|gpu|requests" | head -3)
        if [ ! -z "$metrics" ]; then
            echo "$metrics" | sed 's/^/    /'
        fi

        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

TOTAL=0
PASSED=0

# Check vLLM services
echo -e "${YELLOW}vLLM Services:${NC}"
check_service_with_metrics "Code Traditional" $CODE_TRADITIONAL_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

check_service_with_metrics "Code Agentic" $CODE_AGENTIC_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

check_service_with_metrics "Chat Advanced" $CHAT_ADVANCED_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

check_service_with_metrics "Chat Fast" $CHAT_FAST_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

check_service_with_metrics "Chat Light" $CHAT_LIGHT_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

check_service_with_metrics "Vision" $VISION_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

echo ""
echo -e "${YELLOW}Speech Services:${NC}"
check_service "Whisper ASR" $WHISPER_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

check_service "Piper TTS" $PIPER_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

echo ""
echo -e "${YELLOW}Core Services:${NC}"
check_service "Gateway" $GATEWAY_PORT && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

check_service "Web UI" $WEBUI_PORT /health && PASSED=$((PASSED+1))
TOTAL=$((TOTAL+1))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $PASSED -eq $TOTAL ]; then
    echo -e "${GREEN}✅ All services healthy! ($PASSED/$TOTAL)${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some services are down ($PASSED/$TOTAL healthy)${NC}"
    exit 1
fi
