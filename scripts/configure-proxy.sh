#!/bin/bash
# FamilyAI 代理配置辅助脚本
# 帮助用户正确配置代理以访问宿主机上的代理服务

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 横幅
print_banner() {
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║          FamilyAI 代理配置向导                       ║
║          Proxy Configuration Wizard                   ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检测宿主机 IP
detect_host_ip() {
    log_info "检测宿主机 IP 地址..."

    # 获取主要网络接口的 IP
    HOST_IP=$(hostname -I | awk '{print $1}')

    if [ -z "$HOST_IP" ]; then
        log_error "无法自动检测 IP 地址"
        exit 1
    fi

    log_success "检测到宿主机 IP: $HOST_IP"
    echo ""
}

# 检测代理服务
detect_proxy_service() {
    log_info "扫描常见代理端口..."
    echo ""

    COMMON_PORTS=(1080 2526 7890 8080 8118 10809)
    FOUND_PROXIES=()

    for port in "${COMMON_PORTS[@]}"; do
        if netstat -tln 2>/dev/null | grep -q ":$port " || ss -tln 2>/dev/null | grep -q ":$port "; then
            echo -e "  ✓ 发现服务监听端口: ${GREEN}$port${NC}"

            # 检查监听地址
            LISTEN_ADDR=$(netstat -tln 2>/dev/null | grep ":$port " | awk '{print $4}' | head -1)
            if [ -z "$LISTEN_ADDR" ]; then
                LISTEN_ADDR=$(ss -tln 2>/dev/null | grep ":$port " | awk '{print $4}' | head -1)
            fi

            echo "    监听地址: $LISTEN_ADDR"

            # 判断是否可从容器访问
            if [[ $LISTEN_ADDR == 0.0.0.0:* ]] || [[ $LISTEN_ADDR == *:* && ! $LISTEN_ADDR == 127.0.0.1:* ]]; then
                echo -e "    状态: ${GREEN}✓ 可从容器访问${NC}"
                FOUND_PROXIES+=("$port")
            else
                echo -e "    状态: ${YELLOW}⚠ 仅监听 127.0.0.1，容器无法访问${NC}"
            fi
            echo ""
        fi
    done

    if [ ${#FOUND_PROXIES[@]} -eq 0 ]; then
        log_warning "未发现可用的代理服务"
        return 1
    fi

    return 0
}

# 测试代理连接
test_proxy() {
    local proxy_url=$1

    log_info "测试代理连接: $proxy_url"

    # 测试 Google
    if curl -x "$proxy_url" -s -I https://www.google.com -m 5 >/dev/null 2>&1; then
        log_success "✓ Google 连接成功"
    else
        log_warning "✗ Google 连接失败"
    fi

    # 测试 HuggingFace
    if curl -x "$proxy_url" -s -I https://huggingface.co -m 5 >/dev/null 2>&1; then
        log_success "✓ HuggingFace 连接成功"
    else
        log_warning "✗ HuggingFace 连接失败"
    fi

    echo ""
}

# 配置 .env 文件
configure_env_file() {
    local proxy_url=$1

    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            log_info "创建 .env 文件..."
            cp .env.example .env
        else
            log_error ".env.example 文件不存在"
            exit 1
        fi
    fi

    log_info "更新 .env 文件..."

    # 更新 PROXY_URL
    if grep -q "^PROXY_URL=" .env; then
        sed -i.bak "s|^PROXY_URL=.*|PROXY_URL=$proxy_url|g" .env
    else
        echo "PROXY_URL=$proxy_url" >> .env
    fi

    # 更新 NO_PROXY
    if grep -q "^NO_PROXY=" .env; then
        sed -i.bak "s|^NO_PROXY=.*|NO_PROXY=localhost,127.0.0.1,172.28.0.0/16,$HOST_IP|g" .env
    else
        echo "NO_PROXY=localhost,127.0.0.1,172.28.0.0/16,$HOST_IP" >> .env
    fi

    log_success ".env 文件已更新"
    echo ""
}

# 测试 Docker 容器代理
test_docker_proxy() {
    local proxy_url=$1

    log_info "测试 Docker 容器代理访问..."

    if ! command -v docker &> /dev/null; then
        log_warning "Docker 未安装，跳过容器测试"
        return 0
    fi

    # 测试容器能否访问代理
    if docker run --rm \
        --network host \
        -e HTTP_PROXY="$proxy_url" \
        -e HTTPS_PROXY="$proxy_url" \
        curlimages/curl:latest \
        -x "$proxy_url" -s -I https://www.google.com -m 5 >/dev/null 2>&1; then
        log_success "✓ 容器可以通过代理访问外网"
    else
        log_error "✗ 容器无法通过代理访问外网"
        echo ""
        log_info "可能的原因:"
        echo "  1. 代理未监听 0.0.0.0 或宿主机 IP"
        echo "  2. 防火墙阻止了容器访问"
        echo "  3. 代理服务未正常运行"
    fi

    echo ""
}

# 显示代理配置建议
show_proxy_recommendations() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}代理软件配置建议${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "确保你的代理软件监听 0.0.0.0 而不是 127.0.0.1："
    echo ""
    echo "Clash:"
    echo "  编辑 config.yaml:"
    echo "    mixed-port: 2526"
    echo "    bind-address: 0.0.0.0"
    echo ""
    echo "V2Ray:"
    echo "  编辑 config.json:"
    echo "    \"inbounds\": [{"
    echo "      \"listen\": \"0.0.0.0\","
    echo "      \"port\": 2526"
    echo "    }]"
    echo ""
    echo "SSH Tunnel:"
    echo "  ssh -D 0.0.0.0:2526 user@remote-server"
    echo ""
    echo "配置后重启代理服务！"
    echo ""
}

# 显示防火墙配置
show_firewall_config() {
    local proxy_port=$1

    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}防火墙配置${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "如果使用 UFW 防火墙，运行以下命令："
    echo ""
    echo "  sudo ufw allow from 172.16.0.0/12 to any port $proxy_port"
    echo ""
    echo "这将允许所有 Docker 容器访问代理端口。"
    echo ""
}

# 主函数
main() {
    print_banner

    log_info "开始代理配置向导"
    echo ""

    # 检测宿主机 IP
    detect_host_ip

    # 扫描代理服务
    if detect_proxy_service; then
        echo -e "${GREEN}发现 ${#FOUND_PROXIES[@]} 个可用代理端口${NC}"
        echo ""
    else
        log_warning "未发现可用代理，请手动配置"
        show_proxy_recommendations
        echo ""
    fi

    # 询问代理地址
    echo -e "${BLUE}请选择配置方式:${NC}"
    echo "1. 自动配置（使用检测到的代理）"
    echo "2. 手动输入代理地址"
    echo "3. 查看配置建议并退出"
    echo ""
    read -p "请选择 [1-3]: " -n 1 -r
    echo ""
    echo ""

    case $REPLY in
        1)
            if [ ${#FOUND_PROXIES[@]} -eq 0 ]; then
                log_error "未检测到可用代理"
                exit 1
            fi

            # 使用第一个找到的端口
            PROXY_PORT=${FOUND_PROXIES[0]}
            PROXY_URL="http://$HOST_IP:$PROXY_PORT"

            log_info "使用代理: $PROXY_URL"
            echo ""
            ;;
        2)
            read -p "请输入代理地址 (例如: http://$HOST_IP:2526): " PROXY_URL

            if [ -z "$PROXY_URL" ]; then
                log_error "代理地址不能为空"
                exit 1
            fi

            # 检查是否误用了 127.0.0.1
            if [[ $PROXY_URL == *"127.0.0.1"* ]]; then
                log_error "错误: 不能使用 127.0.0.1"
                log_info "容器内的 127.0.0.1 指向容器自己，无法访问宿主机"
                log_info "请使用宿主机 IP: $HOST_IP"
                exit 1
            fi

            # 提取端口
            PROXY_PORT=$(echo $PROXY_URL | grep -oP ':\K[0-9]+')
            ;;
        3)
            show_proxy_recommendations
            show_firewall_config "2526"
            exit 0
            ;;
        *)
            log_error "无效选择"
            exit 1
            ;;
    esac

    # 测试代理
    test_proxy "$PROXY_URL"

    # 配置 .env 文件
    read -p "是否更新 .env 文件？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        configure_env_file "$PROXY_URL"
    fi

    # 测试 Docker 容器代理
    read -p "是否测试 Docker 容器代理访问？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_docker_proxy "$PROXY_URL"
    fi

    # 显示防火墙配置
    if [ ! -z "$PROXY_PORT" ]; then
        echo ""
        show_firewall_config "$PROXY_PORT"
    fi

    # 完成
    echo ""
    log_success "代理配置完成！"
    echo ""
    echo -e "${GREEN}配置摘要:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "宿主机 IP: $HOST_IP"
    echo "代理地址: $PROXY_URL"
    if [ -f .env ]; then
        echo ".env 文件: 已更新"
    fi
    echo ""
    echo -e "${BLUE}下一步:${NC}"
    echo "1. 确保代理监听 0.0.0.0 而不是 127.0.0.1"
    echo "2. 配置防火墙允许 Docker 容器访问"
    echo "3. 运行模型下载: ./scripts/02-pull-models.sh --batch"
    echo ""
    echo "详细文档: docs/proxy-configuration.md"
    echo ""
}

# 运行主函数
main "$@"
