# NVIDIA Jetson Thor 服务器端部署指南

完整的 FamilyAI 在 Jetson Thor 上的部署实施文档

---

## 📋 目录

1. [部署前准备](#1-部署前准备)
2. [系统环境配置](#2-系统环境配置)
3. [Docker 和 NVIDIA 运行时安装](#3-docker-和-nvidia-运行时安装)
4. [项目部署](#4-项目部署)
5. [模型下载](#5-模型下载)
6. [服务启动](#6-服务启动)
7. [验证和测试](#7-验证和测试)
8. [生产环境优化](#8-生产环境优化)
9. [故障排查](#9-故障排查)

---

## 1. 部署前准备

### 1.1 硬件检查清单

确认你的 Jetson Thor 满足以下要求：

```bash
# 登录到 Jetson Thor 服务器
ssh your-user@jetson-thor-ip

# 检查系统信息
cat /etc/nv_tegra_release
uname -a

# 检查内存
free -h
# 应显示接近 128GB

# 检查存储空间
df -h
# 至少需要 300GB 可用空间（150GB 模型 + 100GB 运行空间 + 50GB 系统）

# 检查 GPU
sudo nvidia-smi
# 应显示 Jetson Thor GPU 信息
```

**预期输出示例**：
```
Total Memory: 128GB
Available Storage: 300GB+
GPU: NVIDIA Jetson Thor (Blackwell Architecture)
```

### 1.2 网络配置

```bash
# 检查网络连接
ping -c 4 google.com

# 检查 DNS
cat /etc/resolv.conf

# 配置静态 IP（可选，推荐）
sudo nano /etc/netplan/01-network-manager-all.yaml
```

**静态 IP 配置示例**：
```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

应用配置：
```bash
sudo netplan apply
```

### 1.3 代理配置（如果需要）

**⚠️ 重要**: 如果代理运行在宿主机上，容器必须使用宿主机 IP，不能使用 `127.0.0.1`！

假设宿主机 IP 是 `192.168.3.84`，代理端口是 `2526`：

```bash
# 1. 确认代理服务运行并监听正确的接口
# 代理必须监听 0.0.0.0 或宿主机 IP，不能只监听 127.0.0.1
netstat -tlnp | grep 2526
# 应显示: 0.0.0.0:2526 或 192.168.3.84:2526

# 2. 从宿主机测试代理（使用宿主机 IP）
curl -x http://192.168.3.84:2526 https://www.google.com

# 3. 如果代理只监听 127.0.0.1，需要修改代理配置
# 例如 Clash: 编辑 config.yaml，设置 bind-address: 0.0.0.0
# 例如 V2Ray: 编辑 config.json，设置 "listen": "0.0.0.0"

# 4. 配置防火墙允许 Docker 容器访问代理
sudo ufw allow from 172.16.0.0/12 to any port 2526
```

**代理配置检查清单**:
- [ ] 代理监听 `0.0.0.0` 或宿主机 IP（不是 `127.0.0.1`）
- [ ] 防火墙允许 Docker 网络访问代理端口
- [ ] 能够通过宿主机 IP 访问代理（`curl -x http://192.168.3.84:2526 https://google.com`）

详细代理配置说明请参考: [docs/proxy-configuration.md](proxy-configuration.md)

---

## 2. 系统环境配置

### 2.1 更新系统

```bash
# 更新软件包列表
sudo apt update

# 升级已安装的包
sudo apt upgrade -y

# 安装基础工具
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
    lsb-release
```

### 2.2 配置 Swap（可选，推荐）

虽然有 128GB 内存，但配置 swap 可以作为保险：

```bash
# 检查当前 swap
sudo swapon --show

# 创建 32GB swap 文件
sudo fallocate -l 32G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 永久化配置
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 验证
free -h
```

### 2.3 配置系统限制

```bash
# 编辑系统限制
sudo nano /etc/security/limits.conf
```

添加以下内容：
```
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
```

```bash
# 编辑 sysctl 配置
sudo nano /etc/sysctl.conf
```

添加：
```
# 网络优化
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.ip_local_port_range = 1024 65535

# 文件句柄
fs.file-max = 2097152
```

应用配置：
```bash
sudo sysctl -p
```

---

## 3. Docker 和 NVIDIA 运行时安装

### 3.1 安装 Docker

```bash
# 卸载旧版本（如果存在）
sudo apt remove docker docker-engine docker.io containerd runc

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

# 验证安装
sudo docker --version
sudo docker compose version
```

**预期输出**：
```
Docker version 24.0.x
Docker Compose version v2.x.x
```

### 3.2 配置 Docker 权限

```bash
# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新登录使权限生效（或使用以下命令）
newgrp docker

# 测试无 sudo 运行
docker ps
```

### 3.3 安装 NVIDIA Container Toolkit

```bash
# 配置软件源
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 安装
sudo apt update
sudo apt install -y nvidia-container-toolkit

# 配置 Docker 使用 NVIDIA 运行时
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# 验证
docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

**预期输出**：应显示 Jetson Thor GPU 信息

### 3.4 配置 Docker 代理（如果需要）

如果 Docker 需要通过代理拉取镜像：

```bash
# 创建 Docker 服务配置目录
sudo mkdir -p /etc/systemd/system/docker.service.d

# 创建代理配置文件
sudo nano /etc/systemd/system/docker.service.d/http-proxy.conf
```

添加内容：
```ini
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:2526"
Environment="HTTPS_PROXY=http://127.0.0.1:2526"
Environment="NO_PROXY=localhost,127.0.0.1,172.17.0.0/16"
```

重启 Docker：
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## 4. 项目部署

### 4.1 克隆项目

```bash
# 创建工作目录
mkdir -p ~/projects
cd ~/projects

# 克隆项目（替换为你的仓库地址）
git clone https://github.com/yourusername/FamilyAI.git
cd FamilyAI

# 检查项目结构
ls -la
```

### 4.2 配置环境变量

```bash
# 复制环境配置模板
cp .env.example .env

# 编辑配置
nano .env
```

**关键配置项**（根据实际情况修改）：

```bash
# ============================================
# Jetson Thor 配置
# ============================================
JETSON_THOR_IP=192.168.1.100
JETSON_THOR_HOSTNAME=familyai-thor

# ============================================
# 代理配置
# ============================================
PROXY_URL=http://127.0.0.1:2526
NO_PROXY=localhost,127.0.0.1,172.28.0.0/16

# ============================================
# vLLM 镜像
# ============================================
VLLM_IMAGE=nvcr.io/nvidia/tritonserver:25.08-vllm-python-py3

# ============================================
# HuggingFace 配置
# ============================================
HF_HOME=/home/$USER/.cache/huggingface
# HF_TOKEN=your_token_here  # 如果需要访问 gated models

# ============================================
# vLLM 配置
# ============================================
VLLM_GPU_MEMORY_UTILIZATION=0.85  # Jetson Thor 可以用 0.85-0.9
VLLM_QUANTIZATION=awq
VLLM_TENSOR_PARALLEL_SIZE=1

# ============================================
# 端口配置（确保不冲突）
# ============================================
CODE_TRADITIONAL_PORT=8001
CODE_AGENTIC_PORT=8002
CHAT_ADVANCED_PORT=8003
CHAT_FAST_PORT=8004
CHAT_LIGHT_PORT=8005
VISION_PORT=8006
WHISPER_PORT=8007
PIPER_PORT=8008
GATEWAY_PORT=8080
WEBUI_PORT=3000

# ============================================
# 安全配置
# ============================================
API_AUTH_ENABLED=true
API_KEY=$(openssl rand -hex 32)  # 生成随机密钥
WEBUI_SECRET_KEY=$(openssl rand -hex 32)

# ============================================
# 监控配置
# ============================================
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001
GRAFANA_ADMIN_PASSWORD=change_this_password
```

保存后验证配置：
```bash
# 检查配置文件
cat .env | grep -v '^#' | grep -v '^$'
```

### 4.3 创建必要的目录

```bash
# 创建数据目录
mkdir -p ~/projects/FamilyAI/data/{open-webui,prometheus,grafana}

# 创建日志目录
mkdir -p ~/projects/FamilyAI/logs

# 设置权限
chmod -R 755 ~/projects/FamilyAI/data
chmod -R 755 ~/projects/FamilyAI/logs
```

---

## 5. 模型下载

### 5.1 预先拉取 Docker 镜像

为了加快后续部署，先拉取必要的镜像：

```bash
# 加载环境变量
source .env

# 拉取 vLLM 镜像（大约 8-10GB）
docker pull $VLLM_IMAGE

# 拉取其他镜像
docker pull ghcr.io/open-webui/open-webui:main
docker pull prom/prometheus:latest
docker pull grafana/grafana:latest

# 验证镜像
docker images
```

### 5.2 下载 AI 模型

**方式一：批量下载所有模型（推荐）**

```bash
# 赋予脚本执行权限
chmod +x scripts/*.sh

# 开始批量下载（约 150GB，需要 2-6 小时取决于网速）
./scripts/02-pull-models.sh --batch
```

**方式二：逐个下载（更可控）**

```bash
# 下载代码模型
./scripts/02-pull-models.sh --model code-traditional  # ~18GB
./scripts/02-pull-models.sh --model code-agentic      # ~15GB

# 下载对话模型
./scripts/02-pull-models.sh --model chat-advanced     # ~18GB
./scripts/02-pull-models.sh --model chat-fast         # ~8GB
./scripts/02-pull-models.sh --model chat-light        # ~4GB

# 下载视觉模型
./scripts/02-pull-models.sh --model vision            # ~7GB

# 下载语音模型
./scripts/02-pull-models.sh --model whisper           # ~1GB
```

**方式三：手动下载单个模型**

```bash
# 示例：下载特定模型
MODEL_NAME=Qwen/Qwen3-8B-Instruct docker-compose -f docker-compose.download.yml run --rm model-downloader
```

### 5.3 验证模型下载

```bash
# 检查模型缓存大小
du -sh ~/.cache/huggingface/hub

# 列出已下载的模型
ls -lh ~/.cache/huggingface/hub/models--*

# 预期输出：应该看到 7 个模型目录
```

---

## 6. 服务启动

### 6.1 测试配置

在启动所有服务前，先测试配置：

```bash
# 验证 Docker Compose 配置
docker compose config

# 检查语法错误
docker compose -f docker-compose.yml config --quiet && echo "配置正确" || echo "配置有误"
```

### 6.2 启动基础服务（不含监控）

```bash
# 启动基础服务
./scripts/03-deploy-docker-compose.sh basic

# 或手动启动
docker compose up -d
```

**启动顺序**：
1. 首先启动 LLM 服务（code-traditional, chat-advanced, chat-fast, chat-light, vision）
2. 然后启动 Gateway
3. 最后启动 Web UI

### 6.3 监控启动过程

```bash
# 实时查看所有容器日志
docker compose logs -f

# 或查看特定服务
docker compose logs -f gateway
docker compose logs -f code-traditional

# 在另一个终端监控资源使用
watch -n 2 'docker stats --no-stream'
```

**预期启动时间**：
- 代码模型（32B）: 3-5 分钟
- 对话模型（4B/8B/32B）: 2-5 分钟
- 视觉模型（7B）: 2-3 分钟
- Gateway: 30 秒
- Web UI: 30 秒

### 6.4 启动完整服务（含监控）

```bash
# 停止基础服务
docker compose down

# 启动完整服务（包括 Prometheus 和 Grafana）
./scripts/03-deploy-docker-compose.sh full

# 或手动
docker compose --profile full up -d
```

### 6.5 检查服务状态

```bash
# 查看所有容器状态
docker compose ps

# 预期输出：所有服务应为 "running" 或 "healthy"
```

**健康检查**：
```bash
# 运行健康检查脚本（如果存在）
./scripts/05-health-check.sh

# 或手动检查
curl http://localhost:8080/health  # Gateway
curl http://localhost:8001/health  # Code Traditional
curl http://localhost:8003/health  # Chat Advanced
curl http://localhost:3000         # Web UI
```

---

## 7. 验证和测试

### 7.1 API 测试

**测试 Gateway API**：

```bash
# 测试健康检查
curl http://localhost:8080/health

# 列出可用模型
curl http://localhost:8080/v1/models

# 测试聊天接口（无认证）
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "chat-light",
    "messages": [{"role": "user", "content": "你好"}],
    "temperature": 0.7
  }'
```

**如果启用了 API 认证**：

```bash
# 从 .env 获取 API 密钥
API_KEY=$(grep API_KEY .env | cut -d '=' -f2)

# 带认证的请求
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "chat-fast",
    "messages": [{"role": "user", "content": "解释什么是 Docker"}],
    "temperature": 0.7
  }'
```

### 7.2 Web UI 访问

```bash
# 在服务器上测试
curl http://localhost:3000

# 从其他设备访问
# 浏览器打开：http://192.168.1.100:3000
```

**首次访问**：
1. 创建管理员账户
2. 配置 API 连接（已自动配置为 Gateway）
3. 测试对话

### 7.3 性能基准测试

```bash
# 测试推理速度
./scripts/06-benchmark.sh --quick

# 完整基准测试
./scripts/06-benchmark.sh --full
```

### 7.4 监控检查

访问监控界面：
- **Prometheus**: http://192.168.1.100:9090
- **Grafana**: http://192.168.1.100:3001
  - 默认用户名: admin
  - 密码: 见 .env 中的 GRAFANA_ADMIN_PASSWORD

---

## 8. 生产环境优化

### 8.1 配置开机自启动

```bash
# 创建 systemd 服务
sudo nano /etc/systemd/system/familyai.service
```

添加内容：
```ini
[Unit]
Description=FamilyAI Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/youruser/projects/FamilyAI
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=youruser

[Install]
WantedBy=multi-user.target
```

启用服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable familyai.service
sudo systemctl start familyai.service

# 测试重启
sudo reboot
```

### 8.2 配置日志轮转

```bash
# 编辑 Docker daemon 配置
sudo nano /etc/docker/daemon.json
```

添加：
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
```

重启 Docker：
```bash
sudo systemctl restart docker
```

### 8.3 设置备份策略

```bash
# 创建备份脚本
nano ~/backup-familyai.sh
```

内容：
```bash
#!/bin/bash
BACKUP_DIR="/backup/familyai"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR

# 备份配置
cp ~/projects/FamilyAI/.env $BACKUP_DIR/.env-$DATE

# 备份 Web UI 数据
tar -czf $BACKUP_DIR/webui-data-$DATE.tar.gz ~/projects/FamilyAI/data/open-webui

# 保留最近 7 天的备份
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "备份完成: $DATE"
```

设置定时任务：
```bash
chmod +x ~/backup-familyai.sh
crontab -e

# 添加：每天凌晨 3 点备份
0 3 * * * /home/youruser/backup-familyai.sh >> /var/log/familyai-backup.log 2>&1
```

### 8.4 防火墙配置

```bash
# 安装 UFW
sudo apt install -y ufw

# 允许 SSH
sudo ufw allow 22/tcp

# 允许 FamilyAI 端口
sudo ufw allow 3000/tcp  # Web UI
sudo ufw allow 8080/tcp  # Gateway API

# 如果需要外网访问监控
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 3001/tcp  # Grafana

# 启用防火墙
sudo ufw enable

# 检查状态
sudo ufw status
```

---

## 9. 故障排查

### 9.1 常见问题

**问题 1: 容器启动失败**

```bash
# 查看详细日志
docker compose logs <service-name>

# 检查资源使用
docker stats

# 检查 GPU 使用
nvidia-smi

# 常见原因：
# - 内存不足：降低 VLLM_GPU_MEMORY_UTILIZATION
# - 模型未下载：检查 ~/.cache/huggingface
# - 端口冲突：修改 .env 中的端口
```

**问题 2: 模型加载慢或失败**

```bash
# 检查模型文件完整性
ls -lh ~/.cache/huggingface/hub/models--*/snapshots/*/

# 重新下载损坏的模型
rm -rf ~/.cache/huggingface/hub/models--<model-name>
./scripts/02-pull-models.sh --model <model-name>

# 检查磁盘空间
df -h
```

**问题 3: 代理连接失败**

```bash
# 测试代理
curl -x $PROXY_URL https://huggingface.co

# 检查容器内代理
docker compose run --rm model-downloader env | grep -i proxy

# 临时禁用代理测试
unset HTTP_PROXY HTTPS_PROXY
```

**问题 4: GPU 不可用**

```bash
# 检查 NVIDIA 驱动
nvidia-smi

# 检查 Docker 运行时
docker run --rm --gpus all ubuntu nvidia-smi

# 重新配置
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

**问题 5: 服务响应慢**

```bash
# 检查 GPU 利用率
nvidia-smi -l 1

# 检查内存使用
free -h

# 检查磁盘 I/O
iostat -x 1

# 调整配置
# 降低 GPU_MEMORY_UTILIZATION
# 减少同时运行的模型数量
# 考虑使用更小的量化（FP8 instead of INT4）
```

### 9.2 性能调优

**调优建议**：

```bash
# 1. 优化 GPU 内存使用
# 编辑 .env
VLLM_GPU_MEMORY_UTILIZATION=0.85  # 从 0.9 降低

# 2. 启用 CUDA Graph（如果未启用）
VLLM_ENABLE_CUDA_GRAPH=true

# 3. 调整批处理大小
VLLM_MAX_BATCH_SIZE=32  # 根据实际负载调整

# 4. 使用模型热交换
# 不要同时运行所有模型，按需启动
docker compose up -d code-traditional chat-fast chat-light gateway web-ui

# 5. 监控和分析
# 使用 Grafana 仪表板分析瓶颈
```

### 9.3 日志分析

```bash
# 查看实时日志
docker compose logs -f --tail=100

# 查看特定时间段日志
docker compose logs --since 1h gateway

# 搜索错误
docker compose logs | grep -i error

# 导出日志用于分析
docker compose logs > familyai-logs-$(date +%Y%m%d).log
```

### 9.4 重置和清理

```bash
# 停止所有服务
docker compose down

# 清理未使用的资源
docker system prune -a --volumes

# 完全重置（谨慎！）
docker compose down -v
rm -rf data/*
# 重新开始部署流程
```

---

## 📞 获取帮助

如果遇到问题：

1. 检查日志: `docker compose logs`
2. 查阅文档: `/docs` 目录
3. 提交 Issue: [GitHub Issues](https://github.com/yourusername/FamilyAI/issues)
4. 社区支持: [讨论区](https://github.com/yourusername/FamilyAI/discussions)

---

## ✅ 部署检查清单

完成部署后，确认以下项目：

- [ ] 系统信息正确（128GB RAM, GPU 可用）
- [ ] Docker 和 NVIDIA 运行时正常工作
- [ ] 所有模型已下载（~150GB）
- [ ] 所有容器运行正常（docker compose ps）
- [ ] Gateway API 响应正常（curl test）
- [ ] Web UI 可访问
- [ ] 监控系统运行（Prometheus + Grafana）
- [ ] 开机自启动已配置
- [ ] 备份策略已设置
- [ ] 防火墙规则已配置

---

**部署完成后，FamilyAI 即可为你的家族成员提供 AI 服务！** 🎉
