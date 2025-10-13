#!/bin/bash
# FamilyAI Model Download Script (Container-based)
# Downloads all required models from HuggingFace using Docker containers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo -e "${GREEN}FamilyAI Model Download Script (Container-based)${NC}"
echo "============================================"
echo "Cache directory: $HF_HOME"
echo "Proxy: ${PROXY_URL:-Not configured}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Check docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed${NC}"
    exit 1
fi

# Function to download a model using container
download_model() {
    local model_name=$1
    local display_name=$2

    echo -e "${YELLOW}Downloading: $display_name${NC}"
    echo "Model: $model_name"
    echo ""

    MODEL_NAME="$model_name" docker-compose -f docker-compose.download.yml run --rm model-downloader

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Downloaded successfully${NC}"
    else
        echo -e "${RED}❌ Error downloading model${NC}"
        return 1
    fi
    echo ""
}

echo -e "${GREEN}Dependencies OK${NC}"
echo ""

# Parse command line arguments
MODELS_TO_DOWNLOAD=()
USE_BATCH_DOWNLOADER=false

if [ "$#" -eq 0 ]; then
    # Use batch downloader for all models
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
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Usage: $0 [--batch] [--model MODEL_NAME]..."
                echo "Available models: code-traditional code-agentic chat-advanced chat-fast chat-light vision whisper"
                echo ""
                echo "Options:"
                echo "  --batch           Download all models using batch downloader (faster)"
                echo "  --model NAME      Download specific model"
                exit 1
                ;;
        esac
    done

    # If no specific models, download all individually
    if [ ${#MODELS_TO_DOWNLOAD[@]} -eq 0 ] && [ "$USE_BATCH_DOWNLOADER" = false ]; then
        MODELS_TO_DOWNLOAD=(code-traditional code-agentic chat-advanced chat-fast chat-light vision whisper)
    fi
fi

# Use batch downloader if requested
if [ "$USE_BATCH_DOWNLOADER" = true ]; then
    echo -e "${YELLOW}Using batch downloader for all models...${NC}"
    echo ""

    docker-compose -f docker-compose.download.yml run --rm batch-downloader

    echo ""
    echo -e "${GREEN}✅ Batch download complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Start services: ./scripts/03-deploy-docker-compose.sh"
    echo "2. Or deploy with K3s: ./scripts/04-deploy-k3s.sh"
    exit 0
fi

# Download models individually
echo "Models to download: ${MODELS_TO_DOWNLOAD[@]}"
echo ""

START_TIME=$(date +%s)

for model in "${MODELS_TO_DOWNLOAD[@]}"; do
    case $model in
        code-traditional)
            download_model "${CODE_TRADITIONAL_MODEL:-Qwen/Qwen2.5-Coder-32B-Instruct}" "Code Traditional (Qwen2.5-Coder-32B)"
            ;;
        code-agentic)
            download_model "${CODE_AGENTIC_MODEL:-Qwen/Qwen3-Coder-30B-A3B-Instruct}" "Code Agentic (Qwen3-Coder-30B-A3B)"
            ;;
        chat-advanced)
            download_model "${CHAT_ADVANCED_MODEL:-Qwen/Qwen3-32B-Instruct}" "Chat Advanced (Qwen3-32B)"
            ;;
        chat-fast)
            download_model "${CHAT_FAST_MODEL:-Qwen/Qwen3-8B-Instruct}" "Chat Fast (Qwen3-8B)"
            ;;
        chat-light)
            download_model "${CHAT_LIGHT_MODEL:-Qwen/Qwen3-4B-Instruct}" "Chat Light (Qwen3-4B)"
            ;;
        vision)
            download_model "${VISION_MODEL:-Qwen/Qwen2-VL-7B-Instruct}" "Vision (Qwen2-VL-7B)"
            ;;
        whisper)
            download_model "${WHISPER_MODEL:-openai/whisper-small}" "Whisper ASR (Small)"
            ;;
        *)
            echo -e "${RED}Unknown model: $model${NC}"
            ;;
    esac
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "============================================"
echo -e "${GREEN}✅ All models downloaded successfully!${NC}"
echo "Total time: $((DURATION / 60)) minutes $((DURATION % 60)) seconds"
echo "Cache location: $HF_HOME"
echo ""
echo "Next steps:"
echo "1. Start services: ./scripts/03-deploy-docker-compose.sh"
echo "2. Or deploy with K3s: ./scripts/04-deploy-k3s.sh"
