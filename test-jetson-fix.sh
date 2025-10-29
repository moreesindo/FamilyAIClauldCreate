#!/bin/bash
# FamilyAI Jetson Thor 修复后的测试脚本
# 此脚本用于在 Jetson Thor 服务器上测试修复后的配置

set -e

echo "=========================================="
echo "FamilyAI Jetson Thor 配置修复测试脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 验证 .env 配置文件
echo -e "${YELLOW}步骤 1: 验证 .env 配置文件...${NC}"
if [ ! -f .env ]; then
    echo -e "${RED}✗ .env 文件不存在${NC}"
    exit 1
fi

# 检查关键配置项
GPU_MEM_UTIL=$(grep "^VLLM_GPU_MEMORY_UTILIZATION=" .env | cut -d'=' -f2)
CHAT_LIGHT_LEN=$(grep "^CHAT_LIGHT_MAX_MODEL_LEN=" .env | cut -d'=' -f2)
HF_HOME=$(grep "^HF_HOME=" .env | cut -d'=' -f2)

echo "  VLLM_GPU_MEMORY_UTILIZATION = ${GPU_MEM_UTIL}"
echo "  CHAT_LIGHT_MAX_MODEL_LEN = ${CHAT_LIGHT_LEN}"
echo "  HF_HOME = ${HF_HOME}"

# 验证配置值是否合理
if (( $(echo "$GPU_MEM_UTIL > 0.7" | bc -l) )); then
    echo -e "${RED}✗ GPU 内存利用率 ${GPU_MEM_UTIL} 过高（建议 ≤ 0.5）${NC}"
    exit 1
fi

if [ "$CHAT_LIGHT_LEN" -gt 32768 ]; then
    echo -e "${RED}✗ chat-light 上下文长度 ${CHAT_LIGHT_LEN} 过大（建议 ≤ 16384）${NC}"
    exit 1
fi

echo -e "${GREEN}✓ .env 配置值合理${NC}"
echo ""

# 2. 验证 docker-compose.yml 语法和实际配置
echo -e "${YELLOW}步骤 2: 验证 docker-compose.yml 配置...${NC}"
if ! docker compose config > /dev/null 2>&1; then
    echo -e "${RED}✗ docker-compose.yml 语法错误${NC}"
    docker compose config
    exit 1
fi

# 检查 docker-compose 实际会使用的值
COMPOSED_CONFIG=$(docker compose config 2>/dev/null)

# 使用兼容的正则表达式提取值 (避免使用 -oP)
ACTUAL_GPU_MEM=$(echo "$COMPOSED_CONFIG" | grep -A 100 "chat-light:" | grep "gpu-memory-utilization" | head -1 | sed -n 's/.*gpu-memory-utilization \([0-9.]*\).*/\1/p')
ACTUAL_MAX_LEN=$(echo "$COMPOSED_CONFIG" | grep -A 100 "chat-light:" | grep "max-model-len" | head -1 | sed -n 's/.*max-model-len \([0-9]*\).*/\1/p')

echo "  实际 GPU 内存利用率: ${ACTUAL_GPU_MEM}"
echo "  实际最大上下文长度: ${ACTUAL_MAX_LEN}"

# 只有在成功提取到值时才进行验证
if [ ! -z "$ACTUAL_GPU_MEM" ]; then
    # 将小数转换为整数比较 (0.5 -> 50, 0.7 -> 70)
    GPU_MEM_INT=$(echo "$ACTUAL_GPU_MEM * 100" | bc | cut -d'.' -f1)
    if [ "$GPU_MEM_INT" -gt 70 ]; then
        echo -e "${RED}✗ Docker Compose 实际会使用 ${ACTUAL_GPU_MEM} GPU 利用率，过高！${NC}"
        echo -e "${YELLOW}提示: 检查 docker-compose.yml 中是否有硬编码的默认值${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ 无法从 docker-compose config 提取 GPU 内存利用率，跳过验证${NC}"
fi

if [ ! -z "$ACTUAL_MAX_LEN" ] && [ "$ACTUAL_MAX_LEN" -gt 32768 ]; then
    echo -e "${RED}✗ Docker Compose 实际会使用 ${ACTUAL_MAX_LEN} 上下文长度，过大！${NC}"
    exit 1
elif [ -z "$ACTUAL_MAX_LEN" ]; then
    echo -e "${YELLOW}⚠ 无法从 docker-compose config 提取上下文长度，跳过验证${NC}"
fi

echo -e "${GREEN}✓ docker-compose.yml 配置检查完成${NC}"
echo ""

# 3. 停止所有现有容器
echo -e "${YELLOW}步骤 3: 停止所有现有容器...${NC}"
docker compose down
echo -e "${GREEN}✓ 所有容器已停止${NC}"
echo ""

# 4. 检查 GPU 状态
echo -e "${YELLOW}步骤 4: 检查 GPU 状态...${NC}"
nvidia-smi --query-gpu=index,name,memory.total,memory.free,memory.used --format=csv 2>/dev/null || echo "  nvidia-smi 无法查询 GPU（Jetson Thor 正常现象）"
echo ""

# 5. 检查系统内存
echo -e "${YELLOW}步骤 5: 检查系统内存状态...${NC}"
free -h
MEM_AVAILABLE=$(free -g | awk '/^Mem:/ {print $7}')
echo ""

if [ "$MEM_AVAILABLE" -lt 60 ]; then
    echo -e "${RED}✗ 可用内存仅 ${MEM_AVAILABLE}GB，建议至少 60GB${NC}"
    echo -e "${YELLOW}警告: 内存不足可能导致容器启动失败或系统崩溃${NC}"
    echo -e "${YELLOW}建议: 执行 'sudo reboot' 释放被锁定的内存${NC}"
    read -p "是否继续启动容器？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# 6. 测试启动 chat-light (最轻量的服务)
echo -e "${YELLOW}步骤 6: 测试启动 chat-light 服务...${NC}"
echo "启动容器..."
docker compose up -d chat-light

echo "等待 30 秒让服务初始化..."
sleep 30

# 检查容器状态
if docker ps | grep -q familyai-chat-light; then
    echo -e "${GREEN}✓ chat-light 容器正在运行${NC}"
    echo ""

    # 7. 验证容器实际使用的配置参数
    echo -e "${YELLOW}步骤 7: 验证容器实际使用的配置...${NC}"

    # 使用兼容的 sed 替代 grep -oP
    ACTUAL_USED_GPU_MEM=$(docker logs familyai-chat-light 2>&1 | grep "gpu_memory_utilization" | tail -1 | sed -n 's/.*gpu_memory_utilization (\([0-9.]*\)).*/\1/p' | head -1)
    ACTUAL_USED_MAX_LEN=$(docker logs familyai-chat-light 2>&1 | grep "max_model_len" | tail -1 | sed -n 's/.*max_model_len \([0-9]*\).*/\1/p')

    echo "  容器实际使用的 GPU 内存利用率: ${ACTUAL_USED_GPU_MEM}"
    echo "  容器实际使用的上下文长度: ${ACTUAL_USED_MAX_LEN}"

    # 验证实际使用的值
    VALIDATION_FAILED=0
    if [ ! -z "$ACTUAL_USED_GPU_MEM" ]; then
        GPU_MEM_INT=$(echo "$ACTUAL_USED_GPU_MEM * 100" | bc 2>/dev/null | cut -d'.' -f1)
        if [ ! -z "$GPU_MEM_INT" ] && [ "$GPU_MEM_INT" -gt 70 ]; then
            echo -e "${RED}✗ 容器实际使用了 ${ACTUAL_USED_GPU_MEM} GPU 利用率（预期 ≤ 0.5）${NC}"
            VALIDATION_FAILED=1
        fi
    fi

    if [ ! -z "$ACTUAL_USED_MAX_LEN" ] && [ "$ACTUAL_USED_MAX_LEN" -gt 32768 ]; then
        echo -e "${RED}✗ 容器实际使用了 ${ACTUAL_USED_MAX_LEN} 上下文长度（预期 ≤ 16384）${NC}"
        VALIDATION_FAILED=1
    fi

    if [ $VALIDATION_FAILED -eq 1 ]; then
        echo -e "${RED}配置验证失败！容器使用了错误的参数${NC}"
        echo -e "${YELLOW}可能原因：${NC}"
        echo "  1. .env 文件未正确同步到服务器"
        echo "  2. docker-compose.yml 中有硬编码的默认值"
        echo "  3. 容器缓存导致使用了旧配置"
        echo ""
        echo -e "${YELLOW}建议操作：${NC}"
        echo "  1. 停止容器: docker compose down"
        echo "  2. 验证 .env 和 docker-compose.yml 文件"
        echo "  3. 强制重建: docker compose up -d chat-light --force-recreate"
        exit 1
    fi

    echo -e "${GREEN}✓ 容器配置参数正确${NC}"
    echo ""

    # 8. 检查内存实际占用
    echo -e "${YELLOW}步骤 8: 检查内存实际占用...${NC}"
    sleep 5  # 等待内存稳定
    free -h
    MEM_AVAILABLE_AFTER=$(free -g | awk '/^Mem:/ {print $7}')
    MEM_USED=$((MEM_AVAILABLE - MEM_AVAILABLE_AFTER))

    echo "  启动前可用内存: ${MEM_AVAILABLE}GB"
    echo "  启动后可用内存: ${MEM_AVAILABLE_AFTER}GB"
    echo "  容器占用内存: ~${MEM_USED}GB"

    if [ "$MEM_USED" -gt 50 ]; then
        echo -e "${RED}✗ 容器占用内存过高 (${MEM_USED}GB)，预期应小于 35GB${NC}"
        echo -e "${YELLOW}这通常表示配置参数未生效，容器使用了过大的上下文长度${NC}"
    else
        echo -e "${GREEN}✓ 内存占用正常${NC}"
    fi
    echo ""

    # 查看日志中是否有错误
    echo "最近的日志输出："
    docker logs familyai-chat-light --tail 30

    # 检查是否有启动成功的标志
    if docker logs familyai-chat-light 2>&1 | grep -q "Application startup complete\|Uvicorn running"; then
        echo ""
        echo -e "${GREEN}✓✓✓ chat-light 启动成功！${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠ chat-light 容器在运行，但可能还在初始化中${NC}"
        echo "请手动检查日志: docker logs familyai-chat-light -f"
    fi
else
    echo -e "${RED}✗ chat-light 容器未运行${NC}"
    echo "查看错误日志:"
    docker logs familyai-chat-light
    exit 1
fi
echo ""

# 9. 提示下一步操作
echo -e "${YELLOW}=========================================="
echo "测试完成！"
echo "==========================================${NC}"
echo ""
echo "如果 chat-light 启动成功，您可以继续启动其他服务："
echo ""
echo "  # 启动 chat-fast (8B 模型)"
echo "  docker compose up -d chat-fast"
echo ""
echo "  # 查看日志"
echo "  docker logs familyai-chat-fast -f"
echo ""
echo "  # 启动 speech 服务（内存占用小）"
echo "  docker compose up -d whisper piper"
echo ""
echo "  # 启动 gateway 和 web-ui"
echo "  docker compose up -d gateway web-ui"
echo ""
echo "  # 查看所有运行中的服务"
echo "  docker compose ps"
echo ""
echo -e "${YELLOW}注意事项：${NC}"
echo "1. chat-advanced (32B) 和 code-traditional (32B) 可能因内存不足无法启动"
echo "2. 建议一次只运行 1-2 个 LLM 服务"
echo "3. 实时监控 GPU 内存: watch -n 1 nvidia-smi"
echo ""
