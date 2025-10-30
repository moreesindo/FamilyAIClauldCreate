#!/bin/bash
# FamilyAI Batch Quantized Model Download Script (INT4 AWQ/GPTQ)
# This script runs inside the Docker container

set -e

echo "============================================"
echo "FamilyAI Quantized Model Batch Downloader"
echo "============================================"
echo "Proxy: ${HTTP_PROXY:-Not configured}"
echo ""

# Install required packages
pip install -q huggingface-hub transformers

# Quantized models to download with display names
declare -A MODELS
MODELS=(
  ["$CHAT_LIGHT_MODEL"]="chat-light (2.5GB)"
  ["$CHAT_FAST_MODEL"]="chat-fast (2.5GB)"
  ["$CHAT_ADVANCED_MODEL"]="chat-advanced (9GB)"
  ["$CODE_TRADITIONAL_MODEL"]="code-traditional (9GB)"
  ["$CODE_AGENTIC_MODEL"]="code-agentic (8GB)"
  ["$VISION_MODEL"]="vision (2.5GB)"
)

START_TIME=$(date +%s)
SUCCESS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=${#MODELS[@]}
CURRENT=0

echo "Total models to download: $TOTAL_COUNT"
echo "Total estimated size: ~33.5GB"
echo ""

for model in "${!MODELS[@]}"; do
  ((CURRENT++))
  service_name=${MODELS[$model]}

  echo ""
  echo "=========================================="
  echo "[$CURRENT/$TOTAL_COUNT] Downloading: $model"
  echo "Service: $service_name"
  echo "=========================================="

  python3 << EOF
import os
import sys
from huggingface_hub import snapshot_download

model_name = "$model"
cache_dir = "/data/huggingface"

try:
    print(f"Starting download...")
    print(f"Cache directory: {cache_dir}")
    print("")

    snapshot_download(
        repo_id=model_name,
        cache_dir=cache_dir,
        resume_download=True,
        local_files_only=False
    )
    print("")
    print(f"✅ Successfully downloaded {model_name}")

except Exception as e:
    print(f"❌ Error downloading {model_name}: {e}", file=sys.stderr)
    sys.exit(1)
EOF

  if [ $? -eq 0 ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "⚠️  Failed to download $model, but continuing..."
  fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "============================================"
echo "Batch download complete!"
echo "============================================"
echo "Success: $SUCCESS_COUNT"
echo "Failed: $FAIL_COUNT"
echo "Total time: $((DURATION / 60)) minutes $((DURATION % 60)) seconds"
echo ""
echo "Models stored in: /data/huggingface"
echo ""
echo "Next steps:"
echo "  1. Verify models: ls -lh ${HF_HOME}/hub/"
echo "  2. Start services: docker compose up -d"
echo "  3. Check logs: docker logs familyai-chat-light -f"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
  echo "⚠️  Warning: $FAIL_COUNT model(s) failed to download"
  exit 1
fi
