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

# 1. 验证配置文件语法
echo -e "${YELLOW}步骤 1: 验证 docker-compose.yml 语法...${NC}"
if docker compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ docker-compose.yml 语法正确${NC}"
else
    echo -e "${RED}✗ docker-compose.yml 语法错误，请检查${NC}"
    docker compose config
    exit 1
fi
echo ""

# 2. 停止所有现有容器
echo -e "${YELLOW}步骤 2: 停止所有现有容器...${NC}"
docker compose down
echo -e "${GREEN}✓ 所有容器已停止${NC}"
echo ""

# 3. 检查 GPU 状态
echo -e "${YELLOW}步骤 3: 检查 GPU 状态...${NC}"
nvidia-smi --query-gpu=index,name,memory.total,memory.free,memory.used --format=csv
echo ""

# 4. 检查系统内存
echo -e "${YELLOW}步骤 4: 检查系统内存...${NC}"
free -h
echo ""

# 5. 测试启动 chat-light (最轻量的服务)
echo -e "${YELLOW}步骤 5: 测试启动 chat-light 服务...${NC}"
echo "启动容器..."
docker compose up -d chat-light

echo "等待 30 秒让服务初始化..."
sleep 30

# 检查容器状态
if docker ps | grep -q familyai-chat-light; then
    echo -e "${GREEN}✓ chat-light 容器正在运行${NC}"

    # 查看日志中是否有错误
    echo ""
    echo "最近的日志输出："
    docker logs familyai-chat-light --tail 50

    # 检查是否有启动成功的标志
    if docker logs familyai-chat-light 2>&1 | grep -q "Application startup complete\|Uvicorn running"; then
        echo -e "${GREEN}✓✓✓ chat-light 启动成功！${NC}"
    else
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

# 6. 提示下一步操作
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
