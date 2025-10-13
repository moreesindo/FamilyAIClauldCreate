# FamilyAI 快速参考指南

Jetson Thor 部署和运维的常用命令速查表

---

## 🚀 一键部署流程

```bash
# 1. 克隆项目
git clone https://github.com/yourusername/FamilyAI.git
cd FamilyAI

# 2. 自动配置环境
chmod +x scripts/00-jetson-setup.sh
./scripts/00-jetson-setup.sh

# 3. 重新登录（激活 Docker 组权限）
exit
ssh user@jetson-thor-ip

# 4. 下载模型
cd FamilyAI
./scripts/02-pull-models.sh --batch

# 5. 启动服务
./scripts/03-deploy-docker-compose.sh

# 6. 访问 Web UI
# http://jetson-thor-ip:3000
```

---

## 📦 Docker 操作

### 服务管理

```bash
# 启动所有服务
docker compose up -d

# 启动完整服务（含监控）
docker compose --profile full up -d

# 停止所有服务
docker compose down

# 重启服务
docker compose restart

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f gateway
docker compose logs -f code-traditional

# 重启单个服务
docker compose restart gateway
```

### 资源监控

```bash
# 查看容器资源使用
docker stats

# 实时监控
watch -n 2 'docker stats --no-stream'

# 查看 GPU 使用
watch -n 1 nvidia-smi

# 查看磁盘使用
docker system df
```

### 清理操作

```bash
# 清理未使用的镜像
docker image prune -a

# 清理所有未使用资源
docker system prune -a

# 查看镜像列表
docker images

# 删除特定镜像
docker rmi <image-id>
```

---

## 🤖 模型管理

### 下载模型

```bash
# 批量下载所有模型（推荐）
./scripts/02-pull-models.sh --batch

# 下载特定模型
./scripts/02-pull-models.sh --model code-traditional
./scripts/02-pull-models.sh --model chat-fast

# 直接使用 Docker Compose 下载
MODEL_NAME=Qwen/Qwen3-8B-Instruct \
  docker compose -f docker-compose.download.yml run --rm model-downloader
```

### 查看模型

```bash
# 查看已下载模型
ls ~/.cache/huggingface/hub/models--*

# 查看模型缓存大小
du -sh ~/.cache/huggingface

# 查看特定模型详情
ls -lh ~/.cache/huggingface/hub/models--Qwen--Qwen3-8B-Instruct
```

### 清理模型

```bash
# 删除特定模型
rm -rf ~/.cache/huggingface/hub/models--<model-name>

# 清空所有模型（谨慎！）
rm -rf ~/.cache/huggingface/hub/models--*
```

---

## 🔧 服务配置

### 修改配置

```bash
# 编辑环境变量
nano .env

# 重新加载配置
docker compose down
docker compose up -d
```

### 常用配置项

```bash
# 代理配置
PROXY_URL=http://127.0.0.1:2526

# GPU 内存使用率（0.0-1.0）
VLLM_GPU_MEMORY_UTILIZATION=0.85

# 量化方法
VLLM_QUANTIZATION=awq

# 端口配置
GATEWAY_PORT=8080
WEBUI_PORT=3000
```

### 选择性启动服务

```bash
# 只启动轻量级服务
docker compose up -d chat-light chat-fast gateway web-ui

# 启动代码服务
docker compose up -d code-traditional gateway web-ui

# 启动全部聊天服务
docker compose up -d chat-advanced chat-fast chat-light gateway web-ui
```

---

## 🌐 API 测试

### 健康检查

```bash
# Gateway 健康检查
curl http://localhost:8080/health

# 列出可用模型
curl http://localhost:8080/v1/models | jq
```

### 聊天测试

```bash
# 简单聊天测试
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "chat-light",
    "messages": [{"role": "user", "content": "你好"}]
  }' | jq

# 使用 API Key
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "chat-fast",
    "messages": [{"role": "user", "content": "解释 Docker"}]
  }' | jq
```

### 代码助手测试

```bash
# 代码补全
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "code-traditional",
    "messages": [
      {"role": "user", "content": "写一个 Python 函数计算斐波那契数列"}
    ]
  }' | jq
```

---

## 📊 监控和日志

### 访问监控界面

```bash
# Prometheus
http://jetson-thor-ip:9090

# Grafana
http://jetson-thor-ip:3001
# 用户名: admin
# 密码: 见 .env 中的 GRAFANA_ADMIN_PASSWORD
```

### 日志管理

```bash
# 查看实时日志（所有服务）
docker compose logs -f

# 查看最近 100 行日志
docker compose logs --tail=100

# 查看最近 1 小时日志
docker compose logs --since 1h

# 搜索错误日志
docker compose logs | grep -i error

# 导出日志
docker compose logs > familyai-$(date +%Y%m%d).log
```

### 系统监控

```bash
# CPU 和内存
htop

# GPU 监控
nvidia-smi -l 1

# 磁盘 I/O
iostat -x 1

# 网络连接
netstat -tulpn | grep -E '(3000|8080)'
```

---

## 🔒 安全管理

### 防火墙

```bash
# 查看防火墙状态
sudo ufw status

# 允许端口
sudo ufw allow 3000/tcp
sudo ufw allow 8080/tcp

# 删除规则
sudo ufw delete allow 3000/tcp

# 重新加载
sudo ufw reload
```

### 密钥管理

```bash
# 查看当前 API Key
grep API_KEY .env

# 生成新的 API Key
openssl rand -hex 32

# 更新 API Key（编辑 .env 后重启）
nano .env
docker compose restart gateway
```

---

## 🔄 备份和恢复

### 备份

```bash
# 备份配置
cp .env .env.backup-$(date +%Y%m%d)

# 备份 Web UI 数据
tar -czf webui-backup-$(date +%Y%m%d).tar.gz data/open-webui/

# 备份整个配置目录
tar -czf familyai-config-$(date +%Y%m%d).tar.gz .env docker-compose.yml
```

### 恢复

```bash
# 恢复配置
cp .env.backup-YYYYMMDD .env

# 恢复 Web UI 数据
tar -xzf webui-backup-YYYYMMDD.tar.gz

# 重启服务
docker compose down
docker compose up -d
```

---

## 🛠️ 故障排查

### 常见问题

```bash
# 检查容器状态
docker compose ps

# 检查特定容器日志
docker compose logs <service-name>

# 进入容器调试
docker compose exec <service-name> /bin/bash

# 检查网络连接
docker network ls
docker network inspect familyai_familyai

# 测试服务连通性
curl -v http://localhost:8080/health
```

### 服务重启

```bash
# 完全重启所有服务
docker compose down
docker compose up -d

# 重建并启动（配置更新后）
docker compose down
docker compose up -d --build

# 强制重新创建容器
docker compose up -d --force-recreate
```

### 性能问题

```bash
# 降低 GPU 内存使用
# 编辑 .env: VLLM_GPU_MEMORY_UTILIZATION=0.8

# 减少运行的模型
docker compose stop code-agentic chat-advanced

# 查看资源瓶颈
docker stats
nvidia-smi
```

---

## 🔧 维护任务

### 定期清理

```bash
# 每周清理未使用资源
docker system prune -f

# 每月清理日志
docker compose down
find logs/ -type f -mtime +30 -delete
docker compose up -d
```

### 更新镜像

```bash
# 拉取最新镜像
docker compose pull

# 重启服务
docker compose down
docker compose up -d
```

### 检查更新

```bash
# 检查 Docker 版本
docker --version

# 检查 NVIDIA 驱动
nvidia-smi

# 检查系统更新
sudo apt update
sudo apt list --upgradable
```

---

## 📱 客户端配置

### VS Code (Continue)

配置文件: `~/.continue/config.json`

```json
{
  "models": [
    {
      "title": "FamilyAI Code",
      "provider": "openai",
      "model": "code-traditional",
      "apiBase": "http://jetson-thor-ip:8080/v1",
      "apiKey": "YOUR_API_KEY"
    }
  ]
}
```

### Curl 测试模板

```bash
#!/bin/bash
API_BASE="http://jetson-thor-ip:8080"
API_KEY="your-api-key"

curl -X POST "$API_BASE/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "你的问题"}
    ],
    "temperature": 0.7
  }' | jq
```

---

## 📞 获取帮助

```bash
# 查看脚本帮助
./scripts/02-pull-models.sh --help
./scripts/03-deploy-docker-compose.sh --help

# 查看完整文档
cat docs/jetson-thor-deployment.md

# 查看日志
less logs/familyai.log
```

---

## ⚡ 性能优化提示

1. **GPU 内存优化**: 调整 `VLLM_GPU_MEMORY_UTILIZATION` 在 0.80-0.90 之间
2. **按需启动**: 不要同时运行所有模型，根据实际使用启动
3. **量化选择**: INT4 (awq) 节省内存，FP8 提升精度
4. **并发控制**: 通过 Gateway 的 rate limiting 控制并发
5. **缓存预热**: 系统启动后发送几次测试请求预热模型

---

**快速参考完毕！更多详情请查阅完整文档。** 📚
