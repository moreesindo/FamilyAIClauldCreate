#!/bin/bash
# FamilyAI 模型量化检查脚本
# 检查已下载的模型是否为量化版本

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

# 加载环境变量（使用 set +e 避免 .env 中的错误导致脚本退出）
if [ -f .env ]; then
    set +e
    source .env 2>/dev/null || {
        echo -e "${YELLOW}警告: .env 文件加载失败，使用默认配置${NC}"
    }
    set -e
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

    if [ -z "$snapshot_dir" ] || [ "$snapshot_dir" = "$model_path/snapshots" ]; then
        echo -e "${RED}✗ 无有效快照${NC}"
        return 1
    fi

    # 检查 config.json 中的量化信息
    local config_file="$snapshot_dir/config.json"
    if [ -f "$config_file" ]; then
        # 使用兼容的方式检查量化信息（不使用 -P）
        local quant_method=$(grep -o '"quant_method"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/')

        if [ -n "$quant_method" ]; then
            echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}${quant_method}${NC})"

            # 尝试获取 bits 信息
            local bits=$(grep -o '"bits"[[:space:]]*:[[:space:]]*[0-9]*' "$config_file" 2>/dev/null | sed 's/[^0-9]//g')
            if [ -n "$bits" ]; then
                echo -e "  量化位数: ${CYAN}${bits}-bit${NC}"
            fi
            return 0
        fi
    fi

    # 检查文件名是否包含量化标识
    local has_awq=$(find "$snapshot_dir" -iname "*awq*" 2>/dev/null | wc -l)
    local has_gptq=$(find "$snapshot_dir" -iname "*gptq*" 2>/dev/null | wc -l)

    if [ "$has_awq" -gt 0 ]; then
        echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}AWQ${NC}, 检测依据: 文件名)"
        return 0
    elif [ "$has_gptq" -gt 0 ]; then
        echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}GPTQ${NC}, 检测依据: 文件名)"
        return 0
    fi

    # 检查模型仓库名是否包含量化标识
    if echo "$model_name" | grep -qiE "(AWQ|GPTQ|Int4|int4)"; then
        echo -e "${GREEN}✓ 量化模型${NC} (方法: ${CYAN}INT4${NC}, 检测依据: 仓库名)"
        return 0
    fi

    # 检查模型文件大小
    local model_size_mb=$(du -sm "$model_path" 2>/dev/null | cut -f1)

    if [ -n "$model_size_mb" ]; then
        echo -e "${YELLOW}? 不确定${NC} (大小: ${model_size_mb}MB)"
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

# 定义要检查的模型列表
check_models() {
    # chat-light
    if [ -n "$CHAT_LIGHT_MODEL" ]; then
        ((TOTAL_COUNT++))
        echo -e "${BLUE}[$TOTAL_COUNT] 检查 CHAT_LIGHT_MODEL${NC}"
        echo -e "  配置模型: ${CYAN}${CHAT_LIGHT_MODEL}${NC}"
        echo -e "  预期模型: Eslzzyl/Qwen3-4B-Instruct-2507-AWQ"
        echo -e "  预期量化: AWQ INT4"

        local_model_dir=$(echo "$CHAT_LIGHT_MODEL" | sed 's|/|--|g' | sed 's/^/models--/')
        model_path="$HF_HUB_CACHE/$local_model_dir"
        echo -e "  本地路径: $model_path"

        if [ -d "$model_path" ]; then
            model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
            echo -e "  实际大小: ${model_size}"
            echo -n "  量化状态: "
            check_model_quantization "$model_path" "$CHAT_LIGHT_MODEL"
            check_status=$?
            if [ $check_status -eq 0 ]; then
                ((QUANTIZED_COUNT++))
            elif [ $check_status -eq 2 ]; then
                ((UNCERTAIN_COUNT++))
            else
                ((NOT_FOUND_COUNT++))
            fi
        else
            echo -e "  状态: ${RED}✗ 未下载${NC}"
            ((NOT_FOUND_COUNT++))
        fi
        echo ""
    fi

    # chat-fast
    if [ -n "$CHAT_FAST_MODEL" ]; then
        ((TOTAL_COUNT++))
        echo -e "${BLUE}[$TOTAL_COUNT] 检查 CHAT_FAST_MODEL${NC}"
        echo -e "  配置模型: ${CYAN}${CHAT_FAST_MODEL}${NC}"
        echo -e "  预期模型: JunHowie/Qwen3-8B-GPTQ-Int4"
        echo -e "  预期量化: GPTQ INT4"

        local_model_dir=$(echo "$CHAT_FAST_MODEL" | sed 's|/|--|g' | sed 's/^/models--/')
        model_path="$HF_HUB_CACHE/$local_model_dir"
        echo -e "  本地路径: $model_path"

        if [ -d "$model_path" ]; then
            model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
            echo -e "  实际大小: ${model_size}"
            echo -n "  量化状态: "
            check_model_quantization "$model_path" "$CHAT_FAST_MODEL"
            check_status=$?
            if [ $check_status -eq 0 ]; then
                ((QUANTIZED_COUNT++))
            elif [ $check_status -eq 2 ]; then
                ((UNCERTAIN_COUNT++))
            else
                ((NOT_FOUND_COUNT++))
            fi
        else
            echo -e "  状态: ${RED}✗ 未下载${NC}"
            ((NOT_FOUND_COUNT++))
        fi
        echo ""
    fi

    # chat-advanced
    if [ -n "$CHAT_ADVANCED_MODEL" ]; then
        ((TOTAL_COUNT++))
        echo -e "${BLUE}[$TOTAL_COUNT] 检查 CHAT_ADVANCED_MODEL${NC}"
        echo -e "  配置模型: ${CYAN}${CHAT_ADVANCED_MODEL}${NC}"
        echo -e "  预期模型: Qwen/Qwen3-32B-AWQ"
        echo -e "  预期量化: AWQ INT4"

        local_model_dir=$(echo "$CHAT_ADVANCED_MODEL" | sed 's|/|--|g' | sed 's/^/models--/')
        model_path="$HF_HUB_CACHE/$local_model_dir"
        echo -e "  本地路径: $model_path"

        if [ -d "$model_path" ]; then
            model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
            echo -e "  实际大小: ${model_size}"
            echo -n "  量化状态: "
            check_model_quantization "$model_path" "$CHAT_ADVANCED_MODEL"
            check_status=$?
            if [ $check_status -eq 0 ]; then
                ((QUANTIZED_COUNT++))
            elif [ $check_status -eq 2 ]; then
                ((UNCERTAIN_COUNT++))
            else
                ((NOT_FOUND_COUNT++))
            fi
        else
            echo -e "  状态: ${RED}✗ 未下载${NC}"
            ((NOT_FOUND_COUNT++))
        fi
        echo ""
    fi

    # code-traditional
    if [ -n "$CODE_TRADITIONAL_MODEL" ]; then
        ((TOTAL_COUNT++))
        echo -e "${BLUE}[$TOTAL_COUNT] 检查 CODE_TRADITIONAL_MODEL${NC}"
        echo -e "  配置模型: ${CYAN}${CODE_TRADITIONAL_MODEL}${NC}"
        echo -e "  预期模型: Qwen/Qwen2.5-Coder-32B-Instruct-AWQ"
        echo -e "  预期量化: AWQ INT4"

        local_model_dir=$(echo "$CODE_TRADITIONAL_MODEL" | sed 's|/|--|g' | sed 's/^/models--/')
        model_path="$HF_HUB_CACHE/$local_model_dir"
        echo -e "  本地路径: $model_path"

        if [ -d "$model_path" ]; then
            model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
            echo -e "  实际大小: ${model_size}"
            echo -n "  量化状态: "
            check_model_quantization "$model_path" "$CODE_TRADITIONAL_MODEL"
            check_status=$?
            if [ $check_status -eq 0 ]; then
                ((QUANTIZED_COUNT++))
            elif [ $check_status -eq 2 ]; then
                ((UNCERTAIN_COUNT++))
            else
                ((NOT_FOUND_COUNT++))
            fi
        else
            echo -e "  状态: ${RED}✗ 未下载${NC}"
            ((NOT_FOUND_COUNT++))
        fi
        echo ""
    fi

    # code-agentic
    if [ -n "$CODE_AGENTIC_MODEL" ]; then
        ((TOTAL_COUNT++))
        echo -e "${BLUE}[$TOTAL_COUNT] 检查 CODE_AGENTIC_MODEL${NC}"
        echo -e "  配置模型: ${CYAN}${CODE_AGENTIC_MODEL}${NC}"
        echo -e "  预期模型: Qwen/Qwen3-30B-A3B-GPTQ-Int4"
        echo -e "  预期量化: GPTQ INT4"

        local_model_dir=$(echo "$CODE_AGENTIC_MODEL" | sed 's|/|--|g' | sed 's/^/models--/')
        model_path="$HF_HUB_CACHE/$local_model_dir"
        echo -e "  本地路径: $model_path"

        if [ -d "$model_path" ]; then
            model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
            echo -e "  实际大小: ${model_size}"
            echo -n "  量化状态: "
            check_model_quantization "$model_path" "$CODE_AGENTIC_MODEL"
            check_status=$?
            if [ $check_status -eq 0 ]; then
                ((QUANTIZED_COUNT++))
            elif [ $check_status -eq 2 ]; then
                ((UNCERTAIN_COUNT++))
            else
                ((NOT_FOUND_COUNT++))
            fi
        else
            echo -e "  状态: ${RED}✗ 未下载${NC}"
            ((NOT_FOUND_COUNT++))
        fi
        echo ""
    fi

    # vision
    if [ -n "$VISION_MODEL" ]; then
        ((TOTAL_COUNT++))
        echo -e "${BLUE}[$TOTAL_COUNT] 检查 VISION_MODEL${NC}"
        echo -e "  配置模型: ${CYAN}${VISION_MODEL}${NC}"
        echo -e "  预期模型: Qwen/Qwen2-VL-7B-Instruct-GPTQ-Int4"
        echo -e "  预期量化: GPTQ INT4"

        local_model_dir=$(echo "$VISION_MODEL" | sed 's|/|--|g' | sed 's/^/models--/')
        model_path="$HF_HUB_CACHE/$local_model_dir"
        echo -e "  本地路径: $model_path"

        if [ -d "$model_path" ]; then
            model_size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
            echo -e "  实际大小: ${model_size}"
            echo -n "  量化状态: "
            check_model_quantization "$model_path" "$VISION_MODEL"
            check_status=$?
            if [ $check_status -eq 0 ]; then
                ((QUANTIZED_COUNT++))
            elif [ $check_status -eq 2 ]; then
                ((UNCERTAIN_COUNT++))
            else
                ((NOT_FOUND_COUNT++))
            fi
        else
            echo -e "  状态: ${RED}✗ 未下载${NC}"
            ((NOT_FOUND_COUNT++))
        fi
        echo ""
    fi
}

# 执行检查
check_models

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
        check_model_quantization "$model_path" "$model_name"
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

if [ $QUANTIZED_COUNT -eq $TOTAL_COUNT ] && [ $NOT_FOUND_COUNT -eq 0 ] && [ $TOTAL_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓✓✓ 所有配置的模型均为量化版本！${NC}"
    echo ""
    echo "下一步："
    echo "  1. 启动服务: docker compose up -d"
    echo "  2. 清理非量化模型: ./cleanup-non-quantized-models.sh"
fi

echo "==========================================="
