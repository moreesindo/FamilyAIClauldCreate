#!/bin/bash
# FamilyAI GGUF Model Download Script
# Downloads pre-quantized GGUF models for llama.cpp

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

# Configuration
HF_HOME=${HF_HOME:-"/home/sindoyang/.cache/huggingface"}
GGUF_OUTPUT_DIR=${GGUF_OUTPUT_DIR:-"/home/sindoyang/.cache/familyai/gguf"}
PROXY_URL=${PROXY_URL:-""}

# Create output directory
mkdir -p "$GGUF_OUTPUT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FamilyAI GGUF Model Downloader${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "GGUF output directory: $GGUF_OUTPUT_DIR"
echo "Proxy: ${PROXY_URL:-Not configured}"
echo ""

# Check if huggingface-cli is available
if ! command -v huggingface-cli &> /dev/null; then
    echo -e "${YELLOW}Installing huggingface-hub...${NC}"
    pip install -q huggingface-hub[cli]
fi

# Model definitions (pre-quantized GGUF models)
declare -A GGUF_MODELS=(
    ["code-agentic"]="unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF"
    ["vision-llava"]="mys/ggml_llava-v1.5-7b"
)

# GGUF file names (Q4_K_M quantization)
declare -A GGUF_FILES=(
    ["code-agentic"]="Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf"
    ["vision-llava"]="ggml-model-q4_k.gguf mmproj-model-f16.gguf"
)

# Model display names
declare -A MODEL_NAMES=(
    ["code-agentic"]="Code Agentic (Qwen3-30B-A3B MoE Q4_K_M)"
    ["vision-llava"]="Vision (LLaVA-1.5-7B Q4_K_M + mmproj)"
)

# Function to download GGUF model
download_gguf_model() {
    local model_key=$1
    local repo_id=${GGUF_MODELS[$model_key]}
    local files=${GGUF_FILES[$model_key]}
    local display_name=${MODEL_NAMES[$model_key]}

    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Downloading: $display_name${NC}"
    echo -e "${YELLOW}Repository: $repo_id${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # Check if files already exist
    local all_exist=true
    for file in $files; do
        if [ ! -f "$GGUF_OUTPUT_DIR/$file" ]; then
            all_exist=false
            break
        fi
    done

    if [ "$all_exist" = true ]; then
        echo -e "${GREEN}✓ Model already downloaded${NC}"
        return 0
    fi

    # Download each file
    for file in $files; do
        echo -e "${BLUE}Downloading: $file${NC}"

        # Build download command
        local download_cmd="huggingface-cli download"
        download_cmd="$download_cmd $repo_id"
        download_cmd="$download_cmd $file"
        download_cmd="$download_cmd --local-dir $GGUF_OUTPUT_DIR"
        download_cmd="$download_cmd --local-dir-use-symlinks False"

        # Add proxy if configured
        if [ -n "$PROXY_URL" ]; then
            export HTTP_PROXY="$PROXY_URL"
            export HTTPS_PROXY="$PROXY_URL"
        fi

        # Add HF token if configured
        if [ -n "$HF_TOKEN" ]; then
            download_cmd="$download_cmd --token $HF_TOKEN"
        fi

        # Execute download
        if eval "$download_cmd"; then
            echo -e "${GREEN}✓ Downloaded: $file${NC}"
        else
            echo -e "${RED}✗ Failed to download: $file${NC}"
            return 1
        fi
    done

    echo -e "${GREEN}✅ Successfully downloaded: $display_name${NC}"
    return 0
}

# Parse command line arguments
MODELS_TO_DOWNLOAD=()

if [ "$#" -eq 0 ]; then
    # Download all models by default
    MODELS_TO_DOWNLOAD=("code-agentic" "vision-llava")
else
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --model)
                if [ -z "${GGUF_MODELS[$2]}" ]; then
                    echo -e "${RED}Unknown model: $2${NC}"
                    echo "Available models: ${!GGUF_MODELS[@]}"
                    exit 1
                fi
                MODELS_TO_DOWNLOAD+=("$2")
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--model MODEL_NAME]..."
                echo ""
                echo "Available models:"
                for key in "${!GGUF_MODELS[@]}"; do
                    echo "  $key: ${MODEL_NAMES[$key]}"
                done
                echo ""
                echo "Examples:"
                echo "  $0                           # Download all models"
                echo "  $0 --model code-agentic      # Download only code-agentic"
                echo "  $0 --model vision-llava      # Download only vision model"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
fi

# Display download plan
echo "Models to download:"
for model_key in "${MODELS_TO_DOWNLOAD[@]}"; do
    echo "  - ${MODEL_NAMES[$model_key]}"
    echo "    Repository: ${GGUF_MODELS[$model_key]}"
done
echo ""

# Estimate sizes
echo -e "${YELLOW}Estimated download sizes:${NC}"
echo "  - code-agentic: ~18.6 GB (Q4_K_M)"
echo "  - vision-llava: ~4.7 GB (Q4_K_M + mmproj)"
echo ""

read -p "Continue with download? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Download cancelled"
    exit 0
fi

# Start download
START_TIME=$(date +%s)

FAILED_MODELS=()
SUCCEEDED_MODELS=()

for model_key in "${MODELS_TO_DOWNLOAD[@]}"; do
    if download_gguf_model "$model_key"; then
        SUCCEEDED_MODELS+=("$model_key")
    else
        FAILED_MODELS+=("$model_key")
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Download Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Total time: $((DURATION / 60)) minutes $((DURATION % 60)) seconds"
echo "Output directory: $GGUF_OUTPUT_DIR"
echo ""

if [ ${#SUCCEEDED_MODELS[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successfully downloaded (${#SUCCEEDED_MODELS[@]}):${NC}"
    for model_key in "${SUCCEEDED_MODELS[@]}"; do
        echo "   - ${MODEL_NAMES[$model_key]}"
    done
    echo ""
fi

if [ ${#FAILED_MODELS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed to download (${#FAILED_MODELS[@]}):${NC}"
    for model_key in "${FAILED_MODELS[@]}"; do
        echo "   - ${MODEL_NAMES[$model_key]}"
    done
    echo ""
fi

# List downloaded files
echo "Downloaded GGUF files:"
ls -lh "$GGUF_OUTPUT_DIR"/*.gguf 2>/dev/null || echo "No GGUF files found"
echo ""

if [ ${#FAILED_MODELS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All models downloaded successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Update docker-compose.yml to use these GGUF models"
    echo "2. Test model loading:"
    echo "   docker run --rm -v $GGUF_OUTPUT_DIR:/models ghcr.io/ggerganov/llama.cpp:server \\"
    echo "     --model /models/Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf --help"
    exit 0
else
    echo -e "${YELLOW}⚠ Some models failed to download${NC}"
    echo "Please check the error messages above and retry"
    exit 1
fi
