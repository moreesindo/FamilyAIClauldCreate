#!/bin/bash
# FamilyAI Model Conversion Script
# Converts HuggingFace models to GGUF format (Q4_K_M quantization) for llama.cpp

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
HF_HOME=${HF_HOME:-"$HOME/.cache/huggingface"}
GGUF_OUTPUT_DIR=${GGUF_OUTPUT_DIR:-"$HOME/.cache/familyai/gguf"}
PROXY_URL=${PROXY_URL:-""}

# Create output directory
mkdir -p "$GGUF_OUTPUT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FamilyAI Model Conversion to GGUF${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "HuggingFace cache: $HF_HOME"
echo "GGUF output directory: $GGUF_OUTPUT_DIR"
echo "Proxy: ${PROXY_URL:-Not configured}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker available${NC}"
echo ""

# Model definitions (unquantized base models from HuggingFace)
declare -A MODELS=(
    ["code-traditional"]="Qwen/Qwen2.5-Coder-32B-Instruct"
    ["code-agentic"]="Qwen/Qwen3-30B-A3B-Instruct-2507"
    ["chat-advanced"]="Qwen/Qwen3-32B-Instruct"
    ["chat-fast"]="Qwen/Qwen3-8B-Instruct"
    ["chat-light"]="Qwen/Qwen3-4B-Instruct"
    ["vision"]="Qwen/Qwen2-VL-7B-Instruct"
)

# Model display names
declare -A MODEL_NAMES=(
    ["code-traditional"]="Code Traditional (Qwen2.5-Coder-32B)"
    ["code-agentic"]="Code Agentic (Qwen3-30B-A3B MoE)"
    ["chat-advanced"]="Chat Advanced (Qwen3-32B)"
    ["chat-fast"]="Chat Fast (Qwen3-8B)"
    ["chat-light"]="Chat Light (Qwen3-4B)"
    ["vision"]="Vision (Qwen2-VL-7B for llava)"
)

# Function to download HuggingFace model if not cached
download_hf_model() {
    local model_id=$1
    local display_name=$2

    echo -e "${BLUE}[1/3] Checking cache for: $display_name${NC}"
    echo "Model ID: $model_id"

    # Check if model exists in cache
    local model_cache_path="$HF_HOME/hub/models--${model_id//\/\/--}"

    if [ -d "$model_cache_path" ]; then
        echo -e "${GREEN}✓ Model found in cache${NC}"
        return 0
    fi

    echo -e "${YELLOW}Model not in cache, downloading...${NC}"

    # Build docker run command with proxy if configured
    local docker_cmd="docker run --rm"
    docker_cmd="$docker_cmd -v \"$HF_HOME:/root/.cache/huggingface\""

    if [ -n "$PROXY_URL" ]; then
        docker_cmd="$docker_cmd -e HTTP_PROXY=$PROXY_URL"
        docker_cmd="$docker_cmd -e HTTPS_PROXY=$PROXY_URL"
        docker_cmd="$docker_cmd -e NO_PROXY=$NO_PROXY"
    fi

    if [ -n "$HF_TOKEN" ]; then
        docker_cmd="$docker_cmd -e HUGGING_FACE_HUB_TOKEN=$HF_TOKEN"
    fi

    docker_cmd="$docker_cmd huggingface/transformers-pytorch-gpu:latest"
    docker_cmd="$docker_cmd python -c \"from huggingface_hub import snapshot_download; snapshot_download('$model_id')\""

    eval "$docker_cmd"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Model downloaded successfully${NC}"
    else
        echo -e "${RED}✗ Failed to download model${NC}"
        return 1
    fi
}

# Function to convert HF model to GGUF F16
convert_to_gguf() {
    local model_id=$1
    local display_name=$2
    local output_name=$3

    echo -e "${BLUE}[2/3] Converting to GGUF (F16): $display_name${NC}"

    # Build docker command for conversion
    local docker_cmd="docker run --rm"
    docker_cmd="$docker_cmd -v \"$HF_HOME:/models\""
    docker_cmd="$docker_cmd -v \"$GGUF_OUTPUT_DIR:/output\""
    docker_cmd="$docker_cmd ghcr.io/ggerganov/llama.cpp:full"

    # Model path in container
    local model_path="/models/hub/models--${model_id//\/\/--}/snapshots"

    # Find latest snapshot directory
    local snapshot_cmd="ls -t \"$HF_HOME/hub/models--${model_id//\/\/--}/snapshots\" | head -1"
    local snapshot_dir=$(eval "$snapshot_cmd")

    if [ -z "$snapshot_dir" ]; then
        echo -e "${RED}✗ Could not find model snapshot${NC}"
        return 1
    fi

    local full_model_path="$model_path/$snapshot_dir"

    docker_cmd="$docker_cmd python3 /app/convert_hf_to_gguf.py"
    docker_cmd="$docker_cmd \"$full_model_path\""
    docker_cmd="$docker_cmd --outfile \"/output/${output_name}-f16.gguf\""
    docker_cmd="$docker_cmd --outtype f16"

    eval "$docker_cmd"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Converted to GGUF F16${NC}"
    else
        echo -e "${RED}✗ Failed to convert to GGUF${NC}"
        return 1
    fi
}

# Function to quantize GGUF to Q4_K_M
quantize_gguf() {
    local output_name=$1
    local display_name=$2

    echo -e "${BLUE}[3/3] Quantizing to Q4_K_M: $display_name${NC}"

    # Build docker command for quantization
    local docker_cmd="docker run --rm"
    docker_cmd="$docker_cmd -v \"$GGUF_OUTPUT_DIR:/models\""
    docker_cmd="$docker_cmd ghcr.io/ggerganov/llama.cpp:full"
    docker_cmd="$docker_cmd /app/llama-quantize"
    docker_cmd="$docker_cmd \"/models/${output_name}-f16.gguf\""
    docker_cmd="$docker_cmd \"/models/${output_name}-q4-k-m.gguf\""
    docker_cmd="$docker_cmd Q4_K_M"

    eval "$docker_cmd"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Quantized to Q4_K_M${NC}"

        # Remove intermediate F16 file to save space
        rm -f "$GGUF_OUTPUT_DIR/${output_name}-f16.gguf"
        echo -e "${GREEN}✓ Cleaned up intermediate F16 file${NC}"
    else
        echo -e "${RED}✗ Failed to quantize${NC}"
        return 1
    fi
}

# Function to process a single model
process_model() {
    local model_key=$1
    local model_id=${MODELS[$model_key]}
    local display_name=${MODEL_NAMES[$model_key]}
    local output_name="${model_key}"

    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Processing: $display_name${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # Check if already converted
    if [ -f "$GGUF_OUTPUT_DIR/${output_name}-q4-k-m.gguf" ]; then
        echo -e "${GREEN}✓ Model already converted: ${output_name}-q4-k-m.gguf${NC}"
        return 0
    fi

    # Step 1: Download if needed
    if ! download_hf_model "$model_id" "$display_name"; then
        echo -e "${RED}Failed to download model${NC}"
        return 1
    fi

    echo ""

    # Step 2: Convert to GGUF F16
    if ! convert_to_gguf "$model_id" "$display_name" "$output_name"; then
        echo -e "${RED}Failed to convert model${NC}"
        return 1
    fi

    echo ""

    # Step 3: Quantize to Q4_K_M
    if ! quantize_gguf "$output_name" "$display_name"; then
        echo -e "${RED}Failed to quantize model${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}✅ Successfully processed: $display_name${NC}"
    echo -e "${GREEN}   Output: ${output_name}-q4-k-m.gguf${NC}"
}

# Parse command line arguments
MODELS_TO_CONVERT=()

if [ "$#" -eq 0 ]; then
    # Convert all models by default
    MODELS_TO_CONVERT=("code-traditional" "code-agentic" "chat-advanced" "chat-fast" "chat-light" "vision")
else
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --model)
                if [ -z "${MODELS[$2]}" ]; then
                    echo -e "${RED}Unknown model: $2${NC}"
                    echo "Available models: ${!MODELS[@]}"
                    exit 1
                fi
                MODELS_TO_CONVERT+=("$2")
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--model MODEL_NAME]..."
                echo ""
                echo "Available models:"
                for key in "${!MODELS[@]}"; do
                    echo "  $key: ${MODEL_NAMES[$key]}"
                done
                echo ""
                echo "Examples:"
                echo "  $0                              # Convert all models"
                echo "  $0 --model code-traditional     # Convert only code-traditional"
                echo "  $0 --model chat-fast --model chat-light  # Convert multiple models"
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

# Display conversion plan
echo "Models to convert:"
for model_key in "${MODELS_TO_CONVERT[@]}"; do
    echo "  - ${MODEL_NAMES[$model_key]}"
done
echo ""

# Estimate total time
TOTAL_MODELS=${#MODELS_TO_CONVERT[@]}
echo -e "${YELLOW}Estimated time: $(($TOTAL_MODELS * 30)) - $(($TOTAL_MODELS * 60)) minutes${NC}"
echo -e "${YELLOW}(~30-60 minutes per model depending on size and hardware)${NC}"
echo ""

read -p "Continue with conversion? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Conversion cancelled"
    exit 0
fi

# Start conversion
START_TIME=$(date +%s)

FAILED_MODELS=()
SUCCEEDED_MODELS=()

for model_key in "${MODELS_TO_CONVERT[@]}"; do
    if process_model "$model_key"; then
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
echo -e "${GREEN}Conversion Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Total time: $((DURATION / 60)) minutes $((DURATION % 60)) seconds"
echo "Output directory: $GGUF_OUTPUT_DIR"
echo ""

if [ ${#SUCCEEDED_MODELS[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successfully converted (${#SUCCEEDED_MODELS[@]}):${NC}"
    for model_key in "${SUCCEEDED_MODELS[@]}"; do
        echo "   - ${MODEL_NAMES[$model_key]}"
    done
    echo ""
fi

if [ ${#FAILED_MODELS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed to convert (${#FAILED_MODELS[@]}):${NC}"
    for model_key in "${FAILED_MODELS[@]}"; do
        echo "   - ${MODEL_NAMES[$model_key]}"
    done
    echo ""
fi

# List generated files
echo "Generated GGUF files:"
ls -lh "$GGUF_OUTPUT_DIR"/*.gguf 2>/dev/null || echo "No GGUF files found"
echo ""

if [ ${#FAILED_MODELS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All models converted successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Update docker-compose.yml to use llama.cpp with GGUF models"
    echo "2. Test model loading: docker run --rm -v $GGUF_OUTPUT_DIR:/models ghcr.io/ggerganov/llama.cpp:server --model /models/chat-light-q4-k-m.gguf --help"
    exit 0
else
    echo -e "${YELLOW}⚠ Some models failed to convert${NC}"
    echo "Please check the error messages above and retry"
    exit 1
fi
