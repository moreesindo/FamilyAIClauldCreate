#!/bin/bash
# FamilyAI Quantized Model Download Script (Container-based)
# Downloads all INT4 AWQ/GPTQ quantized models from HuggingFace using Docker containers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${YELLOW}Warning: .env file not found, using defaults${NC}"
fi

# Set default cache directory
HF_HOME=${HF_HOME:-"$HOME/.cache/huggingface"}
export HF_HOME

echo -e "${BLUE}============================================"
echo "FamilyAI Quantized Model Download Script"
echo "============================================${NC}"
echo "Cache directory: $HF_HOME"
echo "Proxy: ${PROXY_URL:-Not configured}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check docker-compose
if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed${NC}"
    exit 1
fi

# Determine docker compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

echo -e "${GREEN}Dependencies OK${NC}"
echo ""

# Parse command line arguments
MODELS_TO_DOWNLOAD=()
USE_BATCH_DOWNLOADER=false

if [ "$#" -eq 0 ]; then
    # Use batch downloader for all models by default
    USE_BATCH_DOWNLOADER=true
else
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --batch)
                USE_BATCH_DOWNLOADER=true
                shift
                ;;
            --model)
                MODELS_TO_DOWNLOAD+=("$2")
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--batch] [--model MODEL_NAME]..."
                echo ""
                echo "Options:"
                echo "  --batch           Download all quantized models using batch downloader (default)"
                echo "  --model NAME      Download specific quantized model"
                echo ""
                echo "Available quantized models:"
                echo "  chat-light        Eslzzyl/Qwen3-4B-Instruct-2507-AWQ (2.5GB)"
                echo "  chat-fast         JunHowie/Qwen3-8B-GPTQ-Int4 (2.5GB)"
                echo "  chat-advanced     Qwen/Qwen3-32B-AWQ (9GB)"
                echo "  code-traditional  Qwen/Qwen2.5-Coder-32B-Instruct-AWQ (9GB)"
                echo "  code-agentic      Qwen/Qwen3-30B-A3B-GPTQ-Int4 (8GB)"
                echo "  vision            Qwen/Qwen2-VL-7B-Instruct-GPTQ-Int4 (2.5GB)"
                echo ""
                echo "Examples:"
                echo "  $0                              # Download all quantized models (batch mode)"
                echo "  $0 --batch                      # Download all quantized models (explicit)"
                echo "  $0 --model chat-light           # Download only chat-light model"
                echo "  $0 --model chat-light --model chat-fast  # Download multiple models"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # If no specific models, download all individually
    if [ ${#MODELS_TO_DOWNLOAD[@]} -eq 0 ] && [ "$USE_BATCH_DOWNLOADER" = false ]; then
        MODELS_TO_DOWNLOAD=(chat-light chat-fast chat-advanced code-traditional code-agentic vision)
    fi
fi

# Function to download a model using container
download_model() {
    local model_name=$1
    local display_name=$2

    echo -e "${YELLOW}Downloading: $display_name${NC}"
    echo "Model: $model_name"
    echo ""

    MODEL_NAME="$model_name" $DOCKER_COMPOSE -f docker-compose.download.yml run --rm model-downloader

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Downloaded successfully${NC}"
    else
        echo -e "${RED}❌ Error downloading model${NC}"
        return 1
    fi
    echo ""
}

# Use batch downloader if requested
if [ "$USE_BATCH_DOWNLOADER" = true ]; then
    echo -e "${YELLOW}Using batch downloader for all quantized models...${NC}"
    echo "Total models: 6"
    echo "Total size: ~33.5GB"
    echo ""

    $DOCKER_COMPOSE -f docker-compose.download.yml run --rm batch-quantized-downloader

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Batch download complete!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Verify models: ls -lh $HF_HOME/hub/"
        echo "2. Start services: docker compose up -d"
        echo "3. Check logs: docker logs familyai-chat-light -f"
        exit 0
    else
        echo ""
        echo -e "${RED}❌ Batch download failed${NC}"
        exit 1
    fi
fi

# Download models individually
echo "Models to download: ${MODELS_TO_DOWNLOAD[@]}"
echo ""

START_TIME=$(date +%s)
SUCCESS_COUNT=0
FAIL_COUNT=0

for model in "${MODELS_TO_DOWNLOAD[@]}"; do
    case $model in
        code-traditional)
            download_model "${CODE_TRADITIONAL_MODEL:-Qwen/Qwen2.5-Coder-32B-Instruct-AWQ}" "Code Traditional (Qwen2.5-Coder-32B-AWQ)"
            ;;
        code-agentic)
            download_model "${CODE_AGENTIC_MODEL:-Qwen/Qwen3-30B-A3B-GPTQ-Int4}" "Code Agentic (Qwen3-30B-A3B-GPTQ-Int4)"
            ;;
        chat-advanced)
            download_model "${CHAT_ADVANCED_MODEL:-Qwen/Qwen3-32B-AWQ}" "Chat Advanced (Qwen3-32B-AWQ)"
            ;;
        chat-fast)
            download_model "${CHAT_FAST_MODEL:-JunHowie/Qwen3-8B-GPTQ-Int4}" "Chat Fast (Qwen3-8B-GPTQ-Int4)"
            ;;
        chat-light)
            download_model "${CHAT_LIGHT_MODEL:-Eslzzyl/Qwen3-4B-Instruct-2507-AWQ}" "Chat Light (Qwen3-4B-AWQ)"
            ;;
        vision)
            download_model "${VISION_MODEL:-Qwen/Qwen2-VL-7B-Instruct-GPTQ-Int4}" "Vision (Qwen2-VL-7B-GPTQ-Int4)"
            ;;
        *)
            echo -e "${RED}Unknown model: $model${NC}"
            ;;
    esac

    if [ $? -eq 0 ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "============================================"
echo -e "${GREEN}✅ Download summary${NC}"
echo "============================================"
echo "Success: $SUCCESS_COUNT"
echo "Failed: $FAIL_COUNT"
echo "Total time: $((DURATION / 60)) minutes $((DURATION % 60)) seconds"
echo "Cache location: $HF_HOME"
echo ""
echo "Next steps:"
echo "1. Verify models: ls -lh $HF_HOME/hub/"
echo "2. Start services: docker compose up -d"
echo "3. Check logs: docker logs familyai-chat-light -f"
