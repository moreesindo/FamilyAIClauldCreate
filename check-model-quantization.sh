#!/bin/bash
# FamilyAI 模型量化检查脚本
# 检查已下载的模型是否为量化版本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================="
echo "FamilyAI 模型量化检查脚本"
echo "==========================================${NC}"
echo ""

# 加载环境变量
if [ -f .env ]; then
    source .env
else
    echo -e "${YELLOW}警告: .env 文件不存在，使用默认路径${NC}"
fi

# 确认 HF_HOME 目录
HF_HOME=${HF_HOME:-"$HOME/.cache/huggingface"}
HF_HUB_CACHE="$HF_HOME/hub"

echo -e "${CYAN}HuggingFace 缓存目录: $HF_HUB_CACHE${NC}"
echo ""

if [ ! -d "$HF_HUB_CACHE" ]; then
    echo -e "${RED}错误: HuggingFace 缓存目录不存在${NC}"
    echo "请先下载模型: ./download-quantized-models.sh"
    exit 1
fi

# 预期的量化模型配置
declare -A EXPECTED_MODELS
EXPECTED_MODELS=(
    ["CHAT_LIGHT_MODEL"]="Eslzzyl/Qwen3-4B-Instruct-2507-AWQ|AWQ INT4|2.5GB|models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ"
    ["CHAT_FAST_MODEL"]="JunHowie/Qwen3-8B-GPTQ-Int4|GPTQ INT4|2.5GB|models--JunHowie--Qwen3-8B-GPTQ-Int4"
    ["CHAT_ADVANCED_MODEL"]="Qwen/Qwen3-32B-AWQ|AWQ INT4|9GB|models--Qwen--Qwen3-32B-AWQ"
    ["CODE_TRADITIONAL_MODEL"]="Qwen/Qwen2.5-Coder-32B-Instruct-AWQ|AWQ INT4|9GB|models--Qwen--Qwen2.5-Coder-32B-Instruct-AWQ"
    ["CODE_AGENTIC_MODEL"]="Qwen/Qwen3-30B-A3B-GPTQ-Int4|GPTQ INT4|8GB|models--Qwen--Qwen3-30B-A3B-GPTQ-Int4"
    ["VISION_MODEL"]="Qwen/Qwen2-VL-7B-Instruct-GPTQ-Int4|GPTQ INT4|2.5GB|models--Qwen--Qwen2-VL-7B-Instruct-GPTQ-Int4"
)

# 检查函数
check_model_quantization() {
    local model_path=$1
    local model_name=$2

    if [ ! -d "$model_path" ]; then
        echo -e "${RED}✗ 未找到${NC}"
        return 1
    fi

    # 查找最新的 snapshot
    local snapshot_dir=$(find "$model_path/snapshots" -maxdepth 1 -type d 2>/dev/null | tail -1)

    if [ -z "$snapshot_dir" ]; then
        echo -e "${RED}✗ 无有效快照${NC}"
        return 1
    fi

    # 检查 config.json 中的量化信息
    local config_file="$snapshot_dir/config.json"
    if [ -f "$config_file" ]; then
        # 检查是否包含量化相关字段
        local quant_method=$(grep -oP '"quantization_config".*?"quant_method":\s*"\K[^"]+' "$config_file" 2>/dev/null || echo "")

        if [ -n "$quant_method" ]; then
            echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}${quant_method}${NC})"

            # 尝试获取 bits 信息
            local bits=$(grep -oP '"bits":\s*\K[0-9]+' "$config_file" 2>/dev/null || echo "")
            if [ -n "$bits" ]; then
                echo -e "  量化位数: ${CYAN}${bits}-bit${NC}"
            fi
            return 0
        fi
    fi

    # 检查文件名是否包含量化标识
    local has_awq=$(find "$snapshot_dir" -name "*awq*" 2>/dev/null | wc -l)
    local has_gptq=$(find "$snapshot_dir" -name "*gptq*" 2>/dev/null | wc -l)

    if [ "$has_awq" -gt 0 ]; then
        echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}AWQ${NC}, 检测依据: 文件名)"
        return 0
    elif [ "$has_gptq" -gt 0 ]; then
        echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}GPTQ${NC}, 检测依据: 文件名)"
        return 0
    fi

    # 检查模型仓库名是否包含量化标识
    if [[ "$model_name" =~ (AWQ|GPTQ|Int4|int4) ]]; then
        echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}INT4${NC}, 检测依据: 仓库名)"
        return 0
    fi

    # 检查模型文件大小（量化模型通常更小）
    local model_size_mb=$(du -sm "$model_path" 2>/dev/null | cut -f1)

    # 如果模型大小异常小，可能是量化的
    if [ -n "$model_size_mb" ]; then
        echo -e "${YELLOW}? 可能是量化模型${NC} (大小: ${model_size_mb}MB)"
        echo -e "  ${YELLOW}警告: 无法从配置确认量化方法${NC}"
        return 2
    fi

    echo -e "${RED}✗ 可能是非量化模型${NC}"
    return 1
}

# 统计变量
TOTAL_COUNT=0
QUANTIZED_COUNT=0
NOT_FOUND_COUNT=0
UNCERTAIN_COUNT=0

echo -e "${YELLOW}检查 .env 配置的模型：${NC}"
echo ""

# 检查每个配置的模型
for env_var in "${!EXPECTED_MODELS[@]}"; do
    IFS='|' read -r expected_name quant_method expected_size model_dir <<< "${EXPECTED_MODELS[$env_var]}"

    # 从 .env 读取实际配置的模型
    actual_model=$(eval echo \$${env_var})

    ((TOTAL_COUNT++))

    echo -e "${BLUE}[$TOTAL_COUNT] 检查 ${env_var}${NC}"
    echo -e "  配置模型: ${CYAN}${actual_model:-未配置}${NC}"
    echo -e "  预期模型: ${expected_name}"
    echo -e "  预期量化: ${quant_method}"

    if [ -z "$actual_model" ]; then
        echo -e "  状态: ${RED}✗ 未配置${NC}"
        ((NOT_FOUND_COUNT++))
        echo ""
        continue
    fi

    # 转换模型名为目录名
    local_model_dir=$(echo "$actual_model" | sed 's|/|--|g' | sed 's/^/models--/')
    model_path="$HF_HUB_CACHE/$local_model_dir"

    echo -e "  本地路径: $model_path"

    # 检查模型是否存在
    if [ ! -d "$model_path" ]; then
        echo -e "  状态: ${RED}✗ 未下载${NC}"
        ((NOT_FOUND_COUNT++))
        echo ""
        continue
    fi

    # 获取模型大小
    model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
    echo -e "  实际大小: ${model_size}"

    # 检查量化状态
    echo -n "  量化状态: "
    check_result=$(check_model_quantization "$model_path" "$actual_model")
    check_status=$?

    if [ $check_status -eq 0 ]; then
        ((QUANTIZED_COUNT++))
    elif [ $check_status -eq 2 ]; then
        ((UNCERTAIN_COUNT++))
    fi

    # 验证是否与预期模型匹配
    if [ "$actual_model" != "$expected_name" ]; then
        echo -e "  ${YELLOW}⚠️  警告: 配置的模型与预期不符${NC}"
    fi

    echo ""
done

# 扫描所有已下载的模型
echo -e "${YELLOW}扫描所有已下载的模型：${NC}"
echo ""

ALL_MODELS=$(ls -d "$HF_HUB_CACHE"/models--* 2>/dev/null || echo "")

if [ -z "$ALL_MODELS" ]; then
    echo -e "${RED}未找到任何已下载的模型${NC}"
else
    SCANNED_COUNT=0
    for model_path in $ALL_MODELS; do
        model_name=$(basename "$model_path" | sed 's/^models--//' | sed 's/--/\//g')
        model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)

        ((SCANNED_COUNT++))

        echo -e "${CYAN}[$SCANNED_COUNT] $model_name${NC}"
        echo -e "  路径: $model_path"
        echo -e "  大小: $model_size"
        echo -n "  量化: "
        check_model_quantization "$model_path" "$model_name" > /dev/null
        echo ""
    done
fi

echo "==========================================="
echo -e "${BLUE}检查结果汇总${NC}"
echo "==========================================="
echo -e "配置的模型总数: ${TOTAL_COUNT}"
echo -e "${GREEN}已量化: ${QUANTIZED_COUNT}${NC}"
echo -e "${RED}未下载/未配置: ${NOT_FOUND_COUNT}${NC}"
echo -e "${YELLOW}不确定: ${UNCERTAIN_COUNT}${NC}"
echo ""

# 给出建议
if [ $NOT_FOUND_COUNT -gt 0 ]; then
    echo -e "${YELLOW}建议操作：${NC}"
    echo "1. 下载缺失的量化模型："
    echo "   ./download-quantized-models.sh"
    echo ""
fi

if [ $UNCERTAIN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}注意：${NC}"
    echo "部分模型无法确认量化方法，请手动验证："
    echo "1. 检查模型配置文件："
    echo "   cat ~/.cache/huggingface/hub/models--<model>/snapshots/*/config.json | grep -A5 quantization"
    echo ""
    echo "2. 启动服务查看日志："
    echo "   docker compose up -d chat-light"
    echo "   docker logs familyai-chat-light 2>&1 | grep quantization"
    echo ""
fi

if [ $QUANTIZED_COUNT -eq $TOTAL_COUNT ] && [ $NOT_FOUND_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ 所有配置的模型均为量化版本！${NC}"
    echo ""
    echo "下一步："
    echo "  1. 启动服务: docker compose up -d"
    echo "  2. 清理非量化模型: ./cleanup-non-quantized-models.sh"
fi

echo "==========================================="
