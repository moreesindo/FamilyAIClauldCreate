#!/bin/bash
# FamilyAI Jetson Thor 自动部署脚本
# 此脚本自动化完成系统准备、Docker 安装和项目配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          FamilyAI Jetson Thor 部署脚本                   ║
║          NVIDIA Jetson Thor Deployment Setup             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查是否为 root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "请不要使用 root 用户运行此脚本"
        log_info "使用普通用户运行，需要 sudo 权限时会自动提示"
        exit 1
    fi
}

# 检查 sudo 权限
check_sudo() {
    log_info "检查 sudo 权限..."
    if sudo -n true 2>/dev/null; then
        log_success "已有 sudo 权限"
    else
        log_info "需要 sudo 权限，请输入密码："
        sudo -v
    fi
}

# 系统检查
system_check() {
    log_info "执行系统检查..."

    # 检查 Jetson 平台
    if [ ! -f /etc/nv_tegra_release ]; then
        log_warning "未检测到 Jetson 平台标识，继续执行可能遇到问题"
        read -p "是否继续？(y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "检测到 NVIDIA Jetson 平台"
        cat /etc/nv_tegra_release
    fi

    # 检查内存
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 100 ]; then
        log_warning "系统内存不足 100GB (当前: ${TOTAL_MEM}GB)，建议至少 128GB"
    else
        log_success "内存充足: ${TOTAL_MEM}GB"
    fi

    # 检查磁盘空间
    AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 300 ]; then
        log_warning "可用磁盘空间不足 300GB (当前: ${AVAILABLE_SPACE}GB)"
        log_warning "建议至少 300GB 用于模型存储和运行"
    else
        log_success "磁盘空间充足: ${AVAILABLE_SPACE}GB"
    fi

    echo ""
}

# 更新系统
update_system() {
    log_info "更新系统软件包..."

    sudo apt update
    sudo apt upgrade -y

    log_info "安装必要工具..."
    sudo apt install -y \
        build-essential \
        git \
        curl \
        wget \
        vim \
        htop \
        net-tools \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common

    log_success "系统更新完成"
    echo ""
}

# 配置系统限制
configure_system_limits() {
    log_info "配置系统限制..."

    # 配置文件描述符限制
    if ! grep -q "# FamilyAI limits" /etc/security/limits.conf; then
        sudo tee -a /etc/security/limits.conf > /dev/null << EOF

# FamilyAI limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF
        log_success "已配置文件描述符限制"
    else
        log_info "系统限制已配置，跳过"
    fi

    # 配置 sysctl
    if ! grep -q "# FamilyAI sysctl" /etc/sysctl.conf; then
        sudo tee -a /etc/sysctl.conf > /dev/null << EOF

# FamilyAI sysctl
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.ip_local_port_range = 1024 65535
fs.file-max = 2097152
EOF
        sudo sysctl -p
        log_success "已配置 sysctl 参数"
    else
        log_info "sysctl 已配置，跳过"
    fi

    echo ""
}

# 安装 Docker
install_docker() {
    log_info "检查 Docker 安装状态..."

    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        log_success "Docker 已安装: $DOCKER_VERSION"
        return 0
    fi

    log_info "开始安装 Docker..."

    # 卸载旧版本
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # 添加 Docker GPG 密钥
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # 添加 Docker 仓库
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 配置用户权限
    sudo usermod -aG docker $USER

    log_success "Docker 安装完成: $(docker --version)"
    log_warning "需要重新登录以使 Docker 组权限生效"

    echo ""
}

# 安装 NVIDIA Container Toolkit
install_nvidia_toolkit() {
    log_info "检查 NVIDIA Container Toolkit..."

    if command -v nvidia-ctk &> /dev/null; then
        log_success "NVIDIA Container Toolkit 已安装"
        return 0
    fi

    log_info "安装 NVIDIA Container Toolkit..."

    # 配置软件源
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    # 安装
    sudo apt update
    sudo apt install -y nvidia-container-toolkit

    # 配置 Docker
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker

    log_success "NVIDIA Container Toolkit 安装完成"
    echo ""
}

# 验证 NVIDIA 运行时
verify_nvidia_runtime() {
    log_info "验证 NVIDIA 运行时..."

    # 等待 Docker 重启
    sleep 3

    # 测试 NVIDIA 运行时
    if docker run --rm --runtime=nvidia --gpus all ubuntu:22.04 nvidia-smi &>/dev/null; then
        log_success "NVIDIA 运行时验证成功"
    else
        log_error "NVIDIA 运行时验证失败"
        log_info "尝试运行: docker run --rm --runtime=nvidia --gpus all ubuntu:22.04 nvidia-smi"
        return 1
    fi

    echo ""
}

# 配置 Docker 代理（可选）
configure_docker_proxy() {
    log_info "是否需要配置 Docker 代理？(y/n)"
    read -p "> " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "跳过代理配置"
        return 0
    fi

    read -p "请输入代理地址 (例如: http://127.0.0.1:2526): " PROXY_URL

    sudo mkdir -p /etc/systemd/system/docker.service.d

    sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null << EOF
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
Environment="NO_PROXY=localhost,127.0.0.1,172.17.0.0/16"
EOF

    sudo systemctl daemon-reload
    sudo systemctl restart docker

    log_success "Docker 代理配置完成"
    echo ""
}

# 配置 Swap
configure_swap() {
    log_info "检查 Swap 配置..."

    if swapon --show | grep -q '/swapfile'; then
        log_info "Swap 已配置，跳过"
        return 0
    fi

    log_info "是否创建 32GB Swap？(推荐) (y/n)"
    read -p "> " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "跳过 Swap 配置"
        return 0
    fi

    log_info "创建 Swap 文件 (需要几分钟)..."

    sudo fallocate -l 32G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    # 永久化
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi

    log_success "Swap 配置完成: $(swapon --show)"
    echo ""
}

# 拉取 Docker 镜像
pull_docker_images() {
    log_info "是否预先拉取 Docker 镜像？(y/n)"
    read -p "> " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "跳过镜像拉取"
        return 0
    fi

    log_info "拉取 NVIDIA Triton vLLM 镜像 (约 8-10GB)..."
    docker pull nvcr.io/nvidia/tritonserver:25.08-vllm-python-py3 || true

    log_info "拉取其他必要镜像..."
    docker pull ghcr.io/open-webui/open-webui:main || true
    docker pull prom/prometheus:latest || true
    docker pull grafana/grafana:latest || true

    log_success "镜像拉取完成"
    echo ""
}

# 创建项目目录结构
setup_project_dirs() {
    log_info "创建项目目录结构..."

    # 数据目录
    mkdir -p data/{open-webui,prometheus,grafana}

    # 日志目录
    mkdir -p logs

    # 配置目录
    mkdir -p config

    # 设置权限
    chmod -R 755 data logs config

    log_success "目录结构创建完成"
    echo ""
}

# 配置环境文件
configure_env() {
    log_info "配置环境变量..."

    if [ -f .env ]; then
        log_warning ".env 文件已存在"
        read -p "是否覆盖？(y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "保持现有 .env 文件"
            return 0
        fi
    fi

    cp .env.example .env

    # 获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    # 生成随机密钥
    API_KEY=$(openssl rand -hex 32)
    WEBUI_SECRET=$(openssl rand -hex 32)

    # 更新配置
    sed -i "s|JETSON_THOR_IP=.*|JETSON_THOR_IP=$SERVER_IP|g" .env
    sed -i "s|API_KEY=.*|API_KEY=$API_KEY|g" .env
    sed -i "s|WEBUI_SECRET_KEY=.*|WEBUI_SECRET_KEY=$WEBUI_SECRET|g" .env

    # 询问代理配置
    echo ""
    log_info "代理配置（用于下载模型）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "重要提示："
    echo "- 如果代理运行在本机，使用本机 IP: http://$SERVER_IP:端口"
    echo "- 不要使用 127.0.0.1（容器内无法访问）"
    echo "- 确保代理监听 0.0.0.0 而不是 127.0.0.1"
    echo ""
    read -p "是否配置代理？(y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入代理地址 (例如: http://$SERVER_IP:2526): " PROXY_INPUT

        if [ ! -z "$PROXY_INPUT" ]; then
            # 检查是否误用了 127.0.0.1
            if [[ $PROXY_INPUT == *"127.0.0.1"* ]]; then
                log_warning "检测到使用 127.0.0.1！"
                log_warning "容器内无法访问 127.0.0.1，建议使用: http://$SERVER_IP:端口"
                read -p "是否使用 http://$SERVER_IP:2526 替代？(y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    PROXY_INPUT="http://$SERVER_IP:2526"
                fi
            fi

            sed -i "s|PROXY_URL=.*|PROXY_URL=$PROXY_INPUT|g" .env

            # 添加服务器 IP 到 NO_PROXY
            sed -i "s|NO_PROXY=.*|NO_PROXY=localhost,127.0.0.1,172.28.0.0/16,$SERVER_IP|g" .env

            log_success "代理配置: $PROXY_INPUT"

            # 测试代理
            log_info "测试代理连接..."
            if curl -x "$PROXY_INPUT" -s -I https://www.google.com -m 5 >/dev/null 2>&1; then
                log_success "代理连接测试成功 ✓"
            else
                log_warning "代理连接测试失败，请检查:"
                echo "  1. 代理服务是否运行"
                echo "  2. 代理是否监听正确的接口 (0.0.0.0)"
                echo "  3. 防火墙是否允许连接"
            fi
        fi
    else
        log_info "跳过代理配置"
        log_warning "注意: 下载模型可能需要代理才能访问 HuggingFace"
    fi

    log_success ".env 配置完成"
    echo ""
    log_info "配置摘要:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "服务器 IP: $SERVER_IP"
    echo "API Key: $API_KEY"
    echo "WebUI Secret: $WEBUI_SECRET"
    if [ ! -z "$PROXY_INPUT" ]; then
        echo "代理地址: $PROXY_INPUT"
    fi
    echo ""
}

# 配置防火墙
configure_firewall() {
    log_info "是否配置防火墙规则？(y/n)"
    read -p "> " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "跳过防火墙配置"
        return 0
    fi

    log_info "配置 UFW 防火墙..."

    # 安装 UFW
    sudo apt install -y ufw

    # 配置规则
    sudo ufw --force enable
    sudo ufw allow 22/tcp comment 'SSH'
    sudo ufw allow 3000/tcp comment 'FamilyAI WebUI'
    sudo ufw allow 8080/tcp comment 'FamilyAI Gateway'

    read -p "是否允许外网访问监控端口？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ufw allow 9090/tcp comment 'Prometheus'
        sudo ufw allow 3001/tcp comment 'Grafana'
    fi

    sudo ufw reload

    log_success "防火墙配置完成"
    sudo ufw status
    echo ""
}

# 配置开机自启动
configure_autostart() {
    log_info "是否配置开机自启动？(y/n)"
    read -p "> " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "跳过自启动配置"
        return 0
    fi

    CURRENT_DIR=$(pwd)
    CURRENT_USER=$(whoami)

    sudo tee /etc/systemd/system/familyai.service > /dev/null << EOF
[Unit]
Description=FamilyAI Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$CURRENT_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=$CURRENT_USER

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable familyai.service

    log_success "开机自启动配置完成"
    echo ""
}

# 最终检查
final_check() {
    log_info "执行最终检查..."
    echo ""

    echo "系统信息:"
    echo "--------------------------------"
    echo "Docker: $(docker --version)"
    echo "Docker Compose: $(docker compose version)"
    echo "NVIDIA Toolkit: $(nvidia-ctk --version 2>/dev/null || echo 'N/A')"
    echo "系统内存: $(free -h | awk '/^Mem:/{print $2}')"
    echo "可用磁盘: $(df -h / | awk 'NR==2{print $4}')"
    echo "服务器 IP: $(hostname -I | awk '{print $1}')"
    echo ""
}

# 显示下一步
show_next_steps() {
    log_success "Jetson Thor 环境配置完成！"
    echo ""
    echo -e "${YELLOW}下一步操作:${NC}"
    echo "--------------------------------"
    echo "1. 重新登录以使 Docker 组权限生效:"
    echo "   exit"
    echo "   ssh $USER@$(hostname -I | awk '{print $1}')"
    echo ""
    echo "2. 下载 AI 模型 (约 150GB, 需要 2-6 小时):"
    echo "   cd $(pwd)"
    echo "   ./scripts/02-pull-models.sh --batch"
    echo ""
    echo "3. 启动服务:"
    echo "   ./scripts/03-deploy-docker-compose.sh"
    echo ""
    echo "4. 访问 Web UI:"
    echo "   http://$(hostname -I | awk '{print $1}'):3000"
    echo ""
    echo "5. API 访问地址:"
    echo "   http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo -e "${GREEN}详细部署文档: docs/jetson-thor-deployment.md${NC}"
    echo ""
}

# 主函数
main() {
    print_banner

    log_info "开始 FamilyAI Jetson Thor 环境配置"
    echo ""

    check_root
    check_sudo

    system_check

    log_info "即将执行以下操作:"
    echo "  1. 更新系统软件包"
    echo "  2. 配置系统限制"
    echo "  3. 安装 Docker"
    echo "  4. 安装 NVIDIA Container Toolkit"
    echo "  5. 配置代理（可选）"
    echo "  6. 配置 Swap（可选）"
    echo "  7. 拉取 Docker 镜像（可选）"
    echo "  8. 创建项目目录"
    echo "  9. 配置环境变量"
    echo "  10. 配置防火墙（可选）"
    echo "  11. 配置开机自启动（可选）"
    echo ""

    read -p "按 Enter 继续，或 Ctrl+C 取消..."
    echo ""

    update_system
    configure_system_limits
    install_docker
    install_nvidia_toolkit
    verify_nvidia_runtime
    configure_docker_proxy
    configure_swap
    pull_docker_images
    setup_project_dirs
    configure_env
    configure_firewall
    configure_autostart

    final_check
    show_next_steps

    log_success "脚本执行完成！"
}

# 运行主函数
main "$@"
