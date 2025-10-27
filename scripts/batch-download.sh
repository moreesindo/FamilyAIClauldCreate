#!/bin/bash
# FamilyAI Batch Model Download Script
# This script runs inside the Docker container

set -e

echo "============================================"
echo "FamilyAI Batch Model Downloader"
echo "============================================"
echo "Proxy: ${HTTP_PROXY:-Not configured}"
echo ""

# Install required packages
pip install -q huggingface-hub transformers

# Models to download
MODELS=(
  "$CODE_TRADITIONAL_MODEL"
  "$CODE_AGENTIC_MODEL"
  "$CHAT_ADVANCED_MODEL"
  "$CHAT_FAST_MODEL"
  "$CHAT_LIGHT_MODEL"
  "$VISION_MODEL"
  "$WHISPER_MODEL"
)

START_TIME=$(date +%s)
SUCCESS_COUNT=0
FAIL_COUNT=0

for model in "${MODELS[@]}"; do
  echo ""
  echo "----------------------------------------"
  echo "Downloading: $model"
  echo "----------------------------------------"

  python3 << EOF
import os
import sys
from huggingface_hub import snapshot_download

model_name = "$model"
cache_dir = "/data/huggingface"

try:
    snapshot_download(
        repo_id=model_name,
        cache_dir=cache_dir,
        resume_download=True,
        local_files_only=False
    )
    print(f"✅ Successfully downloaded {model_name}")

except Exception as e:
    print(f"❌ Error downloading {model_name}: {e}", file=sys.stderr)
    sys.exit(1)
EOF

  if [ $? -eq 0 ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
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

if [ $FAIL_COUNT -gt 0 ]; then
  exit 1
fi
