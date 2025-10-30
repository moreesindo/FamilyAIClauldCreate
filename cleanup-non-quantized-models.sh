#!/bin/bash
# FamilyAI 非量化模型清理脚本
# 安全删除已下载的非量化 vLLM 模型文件，保留量化模型

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================="
echo "FamilyAI 非量化模型清理脚本"
echo "==========================================${NC}"
echo ""

# 加载环境变量
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}错误: .env 文件不存在${NC}"
    exit 1
fi

# 确认 HF_HOME 目录
HF_HOME=${HF_HOME:-"$HOME/.cache/huggingface"}
HF_HUB_CACHE="$HF_HOME/hub"

echo -e "${YELLOW}HuggingFace 缓存目录: $HF_HUB_CACHE${NC}"
echo ""

if [ ! -d "$HF_HUB_CACHE" ]; then
    echo -e "${RED}错误: HuggingFace 缓存目录不存在${NC}"
    exit 1
fi

# 需要删除的非量化模型列表
declare -A OLD_MODELS
OLD_MODELS=(
    ["models--Qwen--Qwen3-4B-Instruct-2507"]="Qwen3-4B (BF16, 7.6GB)"
    ["models--Qwen--Qwen3-8B"]="Qwen3-8B (BF16, 16GB)"
    ["models--Qwen--Qwen3-32B"]="Qwen3-32B (BF16, 64GB)"
    ["models--Qwen--Qwen2.5-Coder-32B-Instruct"]="Qwen2.5-Coder-32B (BF16, 64GB)"
    ["models--Qwen--Qwen3-30B-A3B-Instruct-2507"]="Qwen3-30B-A3B (BF16, 60GB)"
    ["models--Qwen--Qwen3-VL-8B-Instruct"]="Qwen3-VL-8B (BF16, 16GB)"
    ["models--Qwen--Qwen2-VL-7B-Instruct"]="Qwen2-VL-7B (BF16, 14GB)"
)

# 需要保留的量化模型列表（仅供参考）
declare -A KEEP_MODELS
KEEP_MODELS=(
    ["models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ"]="chat-light (AWQ INT4, 2.5GB)"
    ["models--JunHowie--Qwen3-8B-GPTQ-Int4"]="chat-fast (GPTQ INT4, 2.5GB)"
    ["models--Qwen--Qwen3-32B-AWQ"]="chat-advanced (AWQ INT4, 9GB)"
    ["models--Qwen--Qwen2.5-Coder-32B-Instruct-AWQ"]="code-traditional (AWQ INT4, 9GB)"
    ["models--Qwen--Qwen3-30B-A3B-GPTQ-Int4"]="code-agentic (GPTQ INT4, 8GB)"
    ["models--Qwen--Qwen2-VL-7B-Instruct-GPTQ-Int4"]="vision (GPTQ INT4, 2.5GB)"
    ["models--Systran--faster-whisper-small"]="whisper (CTranslate2)"
)

echo -e "${YELLOW}即将删除的非量化模型：${NC}"
echo ""

FOUND_COUNT=0
TOTAL_SIZE=0

# 扫描待删除的模型
for model_dir in "${!OLD_MODELS[@]}"; do
    model_path="$HF_HUB_CACHE/$model_dir"
    model_desc=${OLD_MODELS[$model_dir]}

    if [ -d "$model_path" ]; then
        ((FOUND_COUNT++))
        size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
        size_bytes=$(du -sb "$model_path" 2>/dev/null | cut -f1)
        TOTAL_SIZE=$((TOTAL_SIZE + size_bytes))

        echo -e "${RED}[待删除]${NC} $model_desc"
        echo "  路径: $model_path"
        echo "  大小: $size"
        echo ""
    fi
done

if [ $FOUND_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ 未找到非量化模型，无需清理${NC}"
    echo ""
    echo -e "${BLUE}当前保留的量化模型：${NC}"
    for model_dir in "${!KEEP_MODELS[@]}"; do
        model_path="$HF_HUB_CACHE/$model_dir"
        if [ -d "$model_path" ]; then
            size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
            echo -e "${GREEN}[保留]${NC} ${KEEP_MODELS[$model_dir]} - $size"
        fi
    done
    exit 0
fi

echo "==========================================="
echo -e "${RED}发现 $FOUND_COUNT 个非量化模型${NC}"
echo -e "${RED}预计释放空间: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)${NC}"
echo "==========================================="
echo ""

# 安全确认
echo -e "${YELLOW}⚠️  警告: 此操作不可逆！${NC}"
echo ""
echo "将要删除以上非量化模型文件。"
echo ""
read -p "确认删除？(输入 'yes' 继续): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}操作已取消${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}开始删除非量化模型...${NC}"
echo ""

DELETED_COUNT=0
FAILED_COUNT=0

# 执行删除
for model_dir in "${!OLD_MODELS[@]}"; do
    model_path="$HF_HUB_CACHE/$model_dir"
    model_desc=${OLD_MODELS[$model_dir]}

    if [ -d "$model_path" ]; then
        echo -e "${YELLOW}删除: $model_desc${NC}"

        if rm -rf "$model_path" 2>/dev/null; then
            echo -e "${GREEN}✓ 删除成功${NC}"
            ((DELETED_COUNT++))
        else
            echo -e "${RED}✗ 删除失败 (可能需要 sudo)${NC}"
            ((FAILED_COUNT++))
        fi
        echo ""
    fi
done

echo "==========================================="
echo -e "${GREEN}清理完成！${NC}"
echo "==========================================="
echo "成功删除: $DELETED_COUNT 个模型"
echo "失败: $FAILED_COUNT 个模型"
echo ""

if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "${YELLOW}部分文件删除失败，可能需要 sudo 权限：${NC}"
    echo "  sudo rm -rf $HF_HUB_CACHE/models--Qwen--*"
    echo ""
fi

# 显示剩余的量化模型
echo -e "${BLUE}当前保留的量化模型：${NC}"
echo ""
for model_dir in "${!KEEP_MODELS[@]}"; do
    model_path="$HF_HUB_CACHE/$model_dir"
    if [ -d "$model_path" ]; then
        size=$(du -sh "$model_path" 2>/dev/null | cut -f1)
        echo -e "${GREEN}[保留]${NC} ${KEEP_MODELS[$model_dir]}"
        echo "  路径: $model_path"
        echo "  大小: $size"
        echo ""
    fi
done

# 显示缓存目录总大小
echo "==========================================="
CACHE_SIZE=$(du -sh "$HF_HUB_CACHE" 2>/dev/null | cut -f1)
echo -e "${GREEN}HuggingFace 缓存目录总大小: $CACHE_SIZE${NC}"
echo "==========================================="
echo ""

# 可选：清理 .cache/pip 等其他缓存
echo -e "${YELLOW}提示: 您还可以清理其他缓存来释放更多空间：${NC}"
echo "  pip 缓存: pip cache purge"
echo "  Docker 缓存: docker system prune -a"
echo "  系统临时文件: sudo apt-get clean (Ubuntu/Debian)"
echo ""
