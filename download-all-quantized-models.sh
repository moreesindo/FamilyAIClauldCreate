#!/bin/bash
# FamilyAI 量化模型批量下载脚本
# 下载所有 INT4 量化模型到 HuggingFace 缓存目录

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "FamilyAI 量化模型批量下载"
echo "==========================================${NC}"
echo ""

# 检查环境变量
if [ -z "$HF_HOME" ]; then
    export HF_HOME=/home/sindoyang/.cache/huggingface
    echo -e "${YELLOW}使用默认 HF_HOME: $HF_HOME${NC}"
fi

# 设置代理
export HTTP_PROXY=http://192.168.3.84:2526
export HTTPS_PROXY=http://192.168.3.84:2526

echo -e "${GREEN}环境配置:${NC}"
echo "  HF_HOME=$HF_HOME"
echo "  HTTP_PROXY=$HTTP_PROXY"
echo ""

# 需要下载的模型列表
declare -A MODELS
MODELS=(
    ["Eslzzyl/Qwen3-4B-Instruct-2507-AWQ"]="chat-light (2.5GB)"
    ["JunHowie/Qwen3-8B-GPTQ-Int4"]="chat-fast (2.5GB)"
    ["Qwen/Qwen3-32B-AWQ"]="chat-advanced (9GB)"
    ["Qwen/Qwen2.5-Coder-32B-Instruct-AWQ"]="code-traditional (9GB)"
    ["Qwen/Qwen3-30B-A3B-GPTQ-Int4"]="code-agentic (8GB)"
    ["Qwen/Qwen2-VL-7B-Instruct-GPTQ-Int4"]="vision (2.5GB)"
)

TOTAL=${#MODELS[@]}
CURRENT=0

echo -e "${YELLOW}即将下载 $TOTAL 个量化模型，总大小约 33.5GB${NC}"
echo ""

# 安装 huggingface-cli（如果未安装）
if ! command -v huggingface-cli &> /dev/null; then
    echo -e "${YELLOW}安装 huggingface-hub...${NC}"
    pip install -U huggingface-hub
fi

# 下载每个模型
for MODEL in "${!MODELS[@]}"; do
    ((CURRENT++))
    SERVICE=${MODELS[$MODEL]}

    echo -e "${BLUE}=========================================="
    echo "[$CURRENT/$TOTAL] 下载: $MODEL"
    echo "用途: $SERVICE"
    echo "==========================================${NC}"

    # 使用 huggingface-cli 下载
    if huggingface-cli download "$MODEL" --cache-dir "$HF_HOME"; then
        echo -e "${GREEN}✓ $MODEL 下载成功${NC}"
    else
        echo -e "${RED}✗ $MODEL 下载失败${NC}"
        echo -e "${YELLOW}提示: 可以稍后手动重试或跳过${NC}"
    fi
    echo ""
done

echo -e "${GREEN}=========================================="
echo "所有模型下载完成！"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}模型存储位置: $HF_HOME${NC}"
echo ""
echo "下一步:"
echo "  1. 验证模型: ls -lh $HF_HOME/hub/"
echo "  2. 启动服务: docker compose up -d"
echo "  3. 检查日志: docker logs familyai-chat-light -f"
echo ""
