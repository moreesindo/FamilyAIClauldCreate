#!/bin/bash
# FamilyAI Benchmark Script
# Tests performance of FamilyAI services

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

GATEWAY_URL=${GATEWAY_URL:-http://localhost:8080}
MODE=${1:-all}

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       FamilyAI Performance Benchmark                 ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq not found, installing...${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y jq
    elif command -v brew &> /dev/null; then
        brew install jq
    else
        echo -e "${RED}Error: Cannot install jq automatically${NC}"
        exit 1
    fi
fi

# Benchmark function
benchmark_model() {
    local model=$1
    local prompt=$2
    local max_tokens=${3:-100}

    echo -e "${YELLOW}Testing $model...${NC}"

    # Make request and measure time
    START=$(date +%s.%N)

    RESPONSE=$(curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"max_tokens\": $max_tokens,
            \"temperature\": 0.7
        }")

    END=$(date +%s.%N)
    DURATION=$(echo "$END - $START" | bc)

    # Parse response
    if echo "$RESPONSE" | jq -e .choices &> /dev/null; then
        TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')
        TOKENS=$(echo "$TEXT" | wc -w)

        TOKENS_PER_SEC=$(echo "scale=2; $TOKENS / $DURATION" | bc)

        echo "  Duration: ${DURATION}s"
        echo "  Tokens: $TOKENS"
        echo "  Speed: ${TOKENS_PER_SEC} tokens/sec"
        echo "  Preview: ${TEXT:0:100}..."
        echo ""

        return 0
    else
        echo -e "${RED}  Error: $(echo $RESPONSE | jq -r '.error.message // "Unknown error"')${NC}"
        echo ""
        return 1
    fi
}

# Code benchmarks
if [ "$MODE" == "all" ] || [ "$MODE" == "code" ]; then
    echo -e "${GREEN}=== Code Assistant Benchmarks ===${NC}"
    echo ""

    benchmark_model "code-traditional" "Write a Python function to calculate fibonacci numbers" 150

    benchmark_model "code-agentic" "Analyze the structure of a large Python project and suggest improvements" 200

    echo ""
fi

# Chat benchmarks
if [ "$MODE" == "all" ] || [ "$MODE" == "chat" ]; then
    echo -e "${GREEN}=== Chat Benchmarks ===${NC}"
    echo ""

    benchmark_model "chat-light" "What is the capital of France?" 50

    benchmark_model "chat-fast" "Explain the theory of relativity in simple terms" 150

    benchmark_model "chat-advanced" "Write a detailed essay on the impact of artificial intelligence on society" 300

    echo ""
fi

# Vision benchmark
if [ "$MODE" == "all" ] || [ "$MODE" == "vision" ]; then
    echo -e "${GREEN}=== Vision Benchmark ===${NC}"
    echo ""
    echo -e "${YELLOW}Note: Vision benchmarks require image input${NC}"
    echo "Use the API directly to test vision capabilities"
    echo ""
fi

# Concurrent request benchmark
if [ "$MODE" == "all" ] || [ "$MODE" == "stress" ]; then
    echo -e "${GREEN}=== Concurrent Request Test ===${NC}"
    echo ""

    CONCURRENT_REQUESTS=5
    echo "Sending $CONCURRENT_REQUESTS concurrent requests to chat-fast..."

    START=$(date +%s.%N)

    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        (curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"chat-fast\",
                \"messages\": [{\"role\": \"user\", \"content\": \"Tell me a short joke\"}],
                \"max_tokens\": 50
            }" > /dev/null) &
    done

    wait

    END=$(date +%s.%N)
    DURATION=$(echo "$END - $START" | bc)

    echo "  Completed $CONCURRENT_REQUESTS requests in ${DURATION}s"
    echo "  Average: $(echo "scale=2; $DURATION / $CONCURRENT_REQUESTS" | bc)s per request"
    echo ""
fi

echo -e "${GREEN}✅ Benchmark complete!${NC}"
echo ""
echo "Usage: $0 [all|code|chat|vision|stress]"
