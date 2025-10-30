#!/bin/bash
# FamilyAI .env 文件量化模型更新脚本
# 将 .env 中的非量化模型路径更新为量化版本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================="
echo "FamilyAI .env 量化模型更新脚本"
echo "==========================================${NC}"
echo ""

# 检查 .env 文件
if [ ! -f .env ]; then
    echo -e "${RED}错误: .env 文件不存在${NC}"
    echo ""
    echo "请先创建 .env 文件："
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# 备份原始 .env 文件
BACKUP_FILE=".env.backup.$(date +%Y%m%d_%H%M%S)"
cp .env "$BACKUP_FILE"
echo -e "${GREEN}✓ 已备份 .env 到 $BACKUP_FILE${NC}"
echo ""

# 读取当前配置
echo -e "${YELLOW}当前 .env 配置：${NC}"
echo ""

CHAT_LIGHT_MODEL=$(grep "^CHAT_LIGHT_MODEL=" .env | cut -d'=' -f2 || echo "")
CHAT_FAST_MODEL=$(grep "^CHAT_FAST_MODEL=" .env | cut -d'=' -f2 || echo "")
CHAT_ADVANCED_MODEL=$(grep "^CHAT_ADVANCED_MODEL=" .env | cut -d'=' -f2 || echo "")
CODE_TRADITIONAL_MODEL=$(grep "^CODE_TRADITIONAL_MODEL=" .env | cut -d'=' -f2 || echo "")
CODE_AGENTIC_MODEL=$(grep "^CODE_AGENTIC_MODEL=" .env | cut -d'=' -f2 || echo "")
VISION_MODEL=$(grep "^VISION_MODEL=" .env | cut -d'=' -f2 || echo "")

echo "CHAT_LIGHT_MODEL=$CHAT_LIGHT_MODEL"
echo "CHAT_FAST_MODEL=$CHAT_FAST_MODEL"
echo "CHAT_ADVANCED_MODEL=$CHAT_ADVANCED_MODEL"
echo "CODE_TRADITIONAL_MODEL=$CODE_TRADITIONAL_MODEL"
echo "CODE_AGENTIC_MODEL=$CODE_AGENTIC_MODEL"
echo "VISION_MODEL=$VISION_MODEL"
echo ""

# 定义模型映射（非量化 -> 量化）
declare -A MODEL_MAPPING
MODEL_MAPPING=(
    ["Qwen/Qwen3-4B-Instruct-2507"]="Eslzzyl/Qwen3-4B-Instruct-2507-AWQ"
    ["Qwen/Qwen3-8B"]="JunHowie/Qwen3-8B-GPTQ-Int4"
    ["Qwen/Qwen3-32B"]="Qwen/Qwen3-32B-AWQ"
    ["Qwen/Qwen2.5-Coder-32B-Instruct"]="Qwen/Qwen2.5-Coder-32B-Instruct-AWQ"
    ["Qwen/Qwen3-30B-A3B-Instruct-2507"]="Qwen/Qwen3-30B-A3B-GPTQ-Int4"
    ["Qwen/Qwen3-VL-8B-Instruct"]="Qwen/Qwen2-VL-7B-Instruct-GPTQ-Int4"
    ["Qwen/Qwen2-VL-7B-Instruct"]="Qwen/Qwen2-VL-7B-Instruct-GPTQ-Int4"
)

# 检查是否需要更新
NEEDS_UPDATE=0

check_and_update() {
    local var_name=$1
    local current_value=$2

    for old_model in "${!MODEL_MAPPING[@]}"; do
        if [ "$current_value" = "$old_model" ]; then
            new_model=${MODEL_MAPPING[$old_model]}
            echo -e "${YELLOW}需要更新:${NC}"
            echo "  变量: $var_name"
            echo "  当前: $current_value (非量化)"
            echo "  更新: $new_model (INT4 量化)"
            echo ""
            NEEDS_UPDATE=1

            # 执行替换
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s|^${var_name}=.*|${var_name}=${new_model}|" .env
            else
                # Linux
                sed -i "s|^${var_name}=.*|${var_name}=${new_model}|" .env
            fi
            return 0
        fi
    done

    # 检查是否已经是量化模型
    if echo "$current_value" | grep -qE "(AWQ|GPTQ|Int4|int4)"; then
        echo -e "${GREEN}✓ $var_name 已经是量化模型${NC}"
        return 0
    fi

    return 1
}

echo -e "${YELLOW}检查并更新模型配置...${NC}"
echo ""

# 检查每个模型
check_and_update "CHAT_LIGHT_MODEL" "$CHAT_LIGHT_MODEL"
check_and_update "CHAT_FAST_MODEL" "$CHAT_FAST_MODEL"
check_and_update "CHAT_ADVANCED_MODEL" "$CHAT_ADVANCED_MODEL"
check_and_update "CODE_TRADITIONAL_MODEL" "$CODE_TRADITIONAL_MODEL"
check_and_update "CODE_AGENTIC_MODEL" "$CODE_AGENTIC_MODEL"
check_and_update "VISION_MODEL" "$VISION_MODEL"

echo "==========================================="

if [ $NEEDS_UPDATE -eq 1 ]; then
    echo -e "${GREEN}✓ .env 文件已更新为量化模型配置${NC}"
    echo ""
    echo -e "${YELLOW}更新后的配置：${NC}"
    echo ""
    grep -E "^(CHAT_LIGHT_MODEL|CHAT_FAST_MODEL|CHAT_ADVANCED_MODEL|CODE_TRADITIONAL_MODEL|CODE_AGENTIC_MODEL|VISION_MODEL)=" .env
    echo ""
    echo -e "${BLUE}下一步操作：${NC}"
    echo "1. 验证配置："
    echo "   ./check-model-quantization.sh"
    echo ""
    echo "2. 下载量化模型："
    echo "   ./download-quantized-models.sh"
    echo ""
    echo "3. 启动服务："
    echo "   docker compose up -d chat-light"
    echo ""
    echo -e "${YELLOW}注意：${NC}"
    echo "- 原始配置已备份到: $BACKUP_FILE"
    echo "- 如需回滚: cp $BACKUP_FILE .env"
else
    echo -e "${GREEN}✓ .env 配置已经是量化模型，无需更新${NC}"
    echo ""
    echo "当前配置："
    grep -E "^(CHAT_LIGHT_MODEL|CHAT_FAST_MODEL|CHAT_ADVANCED_MODEL|CODE_TRADITIONAL_MODEL|CODE_AGENTIC_MODEL|VISION_MODEL)=" .env
fi

echo "==========================================="
