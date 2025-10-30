#!/bin/bash
# FamilyAI 快速量化检查脚本
# 简化版本，快速检查 .env 配置和已下载模型

echo "=========================================="
echo "FamilyAI 快速量化检查"
echo "=========================================="
echo ""

# 加载环境变量
if [ -f .env ]; then
    source .env 2>/dev/null || true
else
    echo "警告: .env 文件不存在"
    exit 1
fi

HF_HOME=${HF_HOME:-"$HOME/.cache/huggingface"}
HF_HUB_CACHE="$HF_HOME/hub"

echo "缓存目录: $HF_HUB_CACHE"
echo ""

# 检查 .env 配置
echo "=========================================="
echo "检查 .env 配置的模型："
echo "=========================================="
echo ""

check_model_name() {
    local name=$1
    local value=$2

    echo -n "[$name] "

    if [ -z "$value" ]; then
        echo "未配置"
        return
    fi

    echo "$value"

    # 检查是否包含量化标识
    if echo "$value" | grep -qiE "(AWQ|GPTQ|Int4|int4)"; then
        echo "  ✓ 模型名包含量化标识"
    else
        echo "  ✗ 警告: 模型名不包含量化标识"
    fi

    # 检查是否已下载
    local model_dir=$(echo "$value" | sed 's|/|--|g' | sed 's/^/models--/')
    local model_path="$HF_HUB_CACHE/$model_dir"

    if [ -d "$model_path" ]; then
        local size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
        echo "  ✓ 已下载 (大小: $size)"
    else
        echo "  ✗ 未下载"
    fi

    echo ""
}

check_model_name "CHAT_LIGHT_MODEL" "$CHAT_LIGHT_MODEL"
check_model_name "CHAT_FAST_MODEL" "$CHAT_FAST_MODEL"
check_model_name "CHAT_ADVANCED_MODEL" "$CHAT_ADVANCED_MODEL"
check_model_name "CODE_TRADITIONAL_MODEL" "$CODE_TRADITIONAL_MODEL"
check_model_name "CODE_AGENTIC_MODEL" "$CODE_AGENTIC_MODEL"
check_model_name "VISION_MODEL" "$VISION_MODEL"

# 扫描已下载的模型
echo "=========================================="
echo "已下载的所有模型："
echo "=========================================="
echo ""

if [ ! -d "$HF_HUB_CACHE" ]; then
    echo "缓存目录不存在"
else
    COUNT=0
    for model_path in "$HF_HUB_CACHE"/models--*; do
        if [ -d "$model_path" ]; then
            ((COUNT++))
            model_name=$(basename "$model_path" | sed 's/^models--//' | sed 's/--/\//g')
            size=$(du -sh "$model_path" 2>/dev/null | cut -f1)

            echo "[$COUNT] $model_name"
            echo "    大小: $size"

            # 检查量化标识
            if echo "$model_name" | grep -qiE "(AWQ|GPTQ|Int4|int4)"; then
                echo "    ✓ 量化模型"
            else
                echo "    ? 可能是非量化模型"
            fi
            echo ""
        fi
    done

    if [ $COUNT -eq 0 ]; then
        echo "未找到任何已下载的模型"
    else
        echo "总计: $COUNT 个模型"
    fi
fi

echo "=========================================="
echo ""

# 给出建议
echo "下一步操作："
echo ""
echo "1. 如果模型未下载："
echo "   ./download-quantized-models.sh"
echo ""
echo "2. 如果需要详细检查："
echo "   ./check-model-quantization.sh"
echo ""
echo "3. 启动服务测试："
echo "   docker compose up -d chat-light"
echo "   docker logs familyai-chat-light 2>&1 | grep quantization"
echo ""
