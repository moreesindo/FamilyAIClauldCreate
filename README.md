# FamilyAI - 家庭 AI 服务中心

<div align="center">

![NVIDIA Jetson Thor](https://img.shields.io/badge/Platform-NVIDIA%20Jetson%20Thor-76B900?style=for-the-badge&logo=nvidia&logoColor=white)
![vLLM](https://img.shields.io/badge/Inference-vLLM-00ADD8?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![K3s](https://img.shields.io/badge/Orchestration-K3s-FFC61C?style=for-the-badge&logo=kubernetes&logoColor=black)

**部署在 NVIDIA Jetson Thor 上的家庭 AI 服务中心**

提供代码辅助、智能对话、视觉理解和语音处理等多种 AI 服务

[功能特性](#-功能特性) • [快速开始](#-快速开始) • [架构设计](#-架构设计) • [文档](#-文档) • [常见问题](#-常见问题)

</div>

---

## 📋 目录

- [项目简介](#项目简介)
- [功能特性](#-功能特性)
- [系统要求](#-系统要求)
- [快速开始](#-快速开始)
- [架构设计](#-架构设计)
- [模型清单](#-模型清单)
- [使用指南](#-使用指南)
- [部署方式](#-部署方式)
- [监控和运维](#-监控和运维)
- [文档](#-文档)
- [常见问题](#-常见问题)
- [贡献指南](#-贡献指南)
- [许可证](#-许可证)

---

## 项目简介

**FamilyAI** 是一个完全开源的家庭 AI 服务解决方案，运行在 NVIDIA Jetson Thor 边缘计算平台上。项目提供：

- 🤖 **智能代码助手** - GPT-4o 级别的代码生成、补全和调试能力
- 💬 **多层次对话系统** - 根据任务复杂度智能选择最优模型
- 👁️ **视觉理解** - 图像识别、描述和视觉问答
- 🎙️ **语音服务** - 实时语音识别（ASR）和自然语音合成（TTS）
- 🔒 **本地化部署** - 所有数据处理在本地完成，保护隐私
- 🚀 **高性能** - 支持 5-8 个家族成员同时使用

**核心优势**：
- ✅ 100% 开源，无需订阅费用
- ✅ 数据不出本地，完全隐私
- ✅ 统一 API，兼容 OpenAI 格式
- ✅ 容器化部署，易于维护和升级
- ✅ 智能路由，自动选择最优模型

---

## ✨ 功能特性

### 🔧 代码辅助服务

**双模型架构**，根据任务类型智能选择：

- **传统代码任务** (Qwen2.5-Coder-32B)
  - IDE 代码补全
  - 函数生成和重构
  - Bug 修复和代码审查
  - 性能：Aider 73.7（= GPT-4o）

- **Agentic 工作流** (Qwen3-Coder-30B-A3B)
  - 多文件分析和重构
  - 大型代码库理解（256K 上下文）
  - 浏览器自动化
  - AI Agent 式编程辅助

**支持的 IDE**：VS Code (Continue)、Cursor、Neovim

---

### 💬 智能对话服务

**三层模型架构**，按需分配算力：

| 模型 | 用途 | 响应速度 | 性能等效 |
|------|------|---------|---------|
| **Qwen3-4B** | 快速问答 | <1秒 | Qwen2.5-7B |
| **Qwen3-8B** | 日常对话 | 1-2秒 | Qwen2.5-14B |
| **Qwen3-32B** | 复杂推理 | 2-3秒 | Qwen2.5-72B |

**应用场景**：
- 知识问答和信息查询
- 文档总结和创作辅助
- 语言翻译（中英等 119 种语言）
- 数学和逻辑推理

---

### 👁️ 视觉理解

- **模型**: Qwen2-VL-7B
- **能力**:
  - 图像内容描述和理解
  - 视觉问答（VQA）
  - OCR 文字识别
  - 多图对比分析

---

### 🎙️ 语音服务

**语音识别（ASR）**:
- 模型: Whisper-Small
- 支持多语言识别
- 实时因子 < 0.3（10秒音频 < 3秒处理）
- 准确率高，适合家庭对话场景

**语音合成（TTS）**:
- 模型: Piper TTS
- 自然流畅的语音输出
- 多音色支持
- 低延迟实时合成

---

## 🖥️ 系统要求

### 硬件要求

**NVIDIA Jetson Thor** (推荐):
- 内存: 128GB LPDDR5X
- GPU: 2070 TFLOPs (FP4)
- 存储: ≥256GB NVMe SSD（用于模型缓存）

**也兼容**（性能降低）:
- NVIDIA Jetson AGX Orin (64GB)
- 其他支持 CUDA 的 NVIDIA GPU 平台

### 软件要求

- **操作系统**: Ubuntu 20.04/22.04（Jetson 推荐 JetPack 6.0+）
- **Docker**: 20.10 或更高版本
- **NVIDIA Container Toolkit**: 最新版本
- **可选**: K3s（用于生产部署）

---

## 🚀 快速开始

### 1. 环境准备

```bash
# 检查 NVIDIA GPU
nvidia-smi

# 安装 Docker（如果尚未安装）
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装 NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### 2. 克隆项目

```bash
git clone https://github.com/yourusername/FamilyAI.git
cd FamilyAI
```

### 3. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑配置（必须设置代理）
nano .env
```

**重要配置项**：

```bash
# 代理配置（用于模型下载）
PROXY_URL=http://127.0.0.1:2526

# vLLM 镜像（NVIDIA Triton Server）
VLLM_IMAGE=nvcr.io/nvidia/tritonserver:25.08-vllm-python-py3

# HuggingFace 缓存目录
HF_HOME=/home/${USER}/.cache/huggingface

# 其他可选配置（API 密钥、端口等）
```

### 4. 下载模型（容器化方式）

模型通过容器自动使用代理下载：

```bash
# 批量下载所有模型（推荐，约 150GB）
./scripts/02-pull-models.sh

# 使用批量下载器（更快）
./scripts/02-pull-models.sh --batch

# 下载特定模型
./scripts/02-pull-models.sh --model code-traditional

# 下载多个特定模型
./scripts/02-pull-models.sh --model code-traditional --model chat-fast

# 直接使用 Docker Compose 下载自定义模型
MODEL_NAME=Qwen/custom-model docker-compose -f docker-compose.download.yml run --rm model-downloader
```

**注意**：
- 所有模型下载自动通过容器使用配置的代理
- 下载时间取决于网络速度，批量模式更高效
- 模型缓存在 `~/.cache/huggingface`，可被所有服务共享

### 5. 启动服务

**开发模式（Docker Compose）**:
```bash
./scripts/03-deploy-docker-compose.sh
```

**生产模式（K3s）**:
```bash
./scripts/04-deploy-k3s.sh
```

### 6. 访问服务

- **Web 界面**: http://your-jetson-ip:3000
- **API 端点**: http://your-jetson-ip:8080/v1
- **Grafana 监控**: http://your-jetson-ip:3001

---

## 🏗️ 架构设计

### 整体架构

```
┌─────────────────────────────────────────────┐
│         家族成员访问层                       │
│  Web UI │ Mobile │ VS Code │ API Client     │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│         智能路由网关 (Gateway)               │
│    • 任务类型识别                           │
│    • 模型选择和负载均衡                      │
│    • 请求缓存和限流                          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│            vLLM 推理服务集群                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │Code 32B  │ │Code 30B  │ │Chat 32B  │    │
│  └──────────┘ └──────────┘ └──────────┘    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │Chat 8B   │ │Chat 4B   │ │Vision 7B │    │
│  └──────────┘ └──────────┘ └──────────┘    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│          Jetson Thor Hardware                │
│        128GB RAM │ 2070 TFLOPs              │
└─────────────────────────────────────────────┘
```

### 技术栈

- **推理框架**: vLLM（统一）
- **量化**: INT4/AWQ
- **容器**: Docker + NVIDIA Runtime
- **编排**: K3s (Kubernetes)
- **网关**: FastAPI + 智能路由
- **前端**: Open WebUI
- **监控**: Prometheus + Grafana

详见 [架构文档](docs/01-architecture.md)

---

## 📦 模型清单

### 代码助手

| 模型 | 大小 | 显存 | 用途 |
|------|------|------|------|
| Qwen2.5-Coder-32B | 32B | ~18GB | 传统代码任务 |
| Qwen3-Coder-30B-A3B | 30B (3.3B激活) | ~15GB | Agentic 工作流 |

### 对话模型

| 模型 | 大小 | 显存 | 用途 |
|------|------|------|------|
| Qwen3-32B | 32B | ~18GB | 高级推理 |
| Qwen3-8B | 8B | ~4GB | 快速响应 |
| Qwen3-4B | 4B | ~2GB | 轻量交互 |

### 多模态

| 模型 | 大小 | 显存 | 用途 |
|------|------|------|------|
| Qwen2-VL-7B | 7B | ~4GB | 视觉理解 |
| Whisper-Small | 244M | ~2GB | 语音识别 |
| Piper TTS | <100M | ~500MB | 语音合成 |

**总显存占用**: ~48GB（峰值），~40GB（典型）

---

## 📖 使用指南

### Web 界面使用

1. 打开浏览器访问 `http://your-jetson-ip:3000`
2. 首次访问需要创建账户
3. 选择对话模型或上传图片进行视觉问答
4. 支持语音输入和输出（需浏览器麦克风权限）

### VS Code 代码辅助

1. 安装 [Continue 扩展](https://marketplace.visualstudio.com/items?itemName=Continue.continue)
2. 配置 `.continue/config.json`:

```json
{
  "models": [
    {
      "title": "FamilyAI Code (Fast)",
      "provider": "openai",
      "model": "code-agentic",
      "apiBase": "http://your-jetson-ip:8080/v1",
      "apiKey": "your-api-key"
    },
    {
      "title": "FamilyAI Code (Accurate)",
      "provider": "openai",
      "model": "code-traditional",
      "apiBase": "http://your-jetson-ip:8080/v1",
      "apiKey": "your-api-key"
    }
  ]
}
```

3. 在代码中使用 `Ctrl+L` 打开对话，或选中代码后右键选择相关操作

### API 调用

**代码补全示例**:
```python
import openai

openai.api_base = "http://your-jetson-ip:8080/v1"
openai.api_key = "your-api-key"

response = openai.ChatCompletion.create(
    model="auto",  # 自动选择最优模型
    messages=[
        {"role": "user", "content": "写一个快速排序的 Python 实现"}
    ]
)

print(response.choices[0].message.content)
```

**图像理解示例**:
```python
import base64
import requests

with open("image.jpg", "rb") as f:
    image_b64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://your-jetson-ip:8080/v1/chat/completions",
    json={
        "model": "vision",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "这张图片里有什么？"},
                    {"type": "image_url", "image_url": f"data:image/jpeg;base64,{image_b64}"}
                ]
            }
        ]
    }
)

print(response.json()['choices'][0]['message']['content'])
```

更多示例见 [用户指南](docs/04-user-guide.md)

---

## 🔧 部署方式

### Docker Compose（开发/测试）

**优点**: 简单快速，适合单机部署

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### K3s Kubernetes（生产）

**优点**: 高可用、自动恢复、易于扩展

```bash
# 安装 K3s
curl -sfL https://get.k3s.io | sh -

# 部署 FamilyAI
./scripts/04-deploy-k3s.sh

# 查看服务状态
kubectl get pods -n familyai

# 查看日志
kubectl logs -f <pod-name> -n familyai
```

详见 [部署指南](docs/03-deployment-guide.md)

---

## 📊 监控和运维

### Prometheus + Grafana

访问 `http://your-jetson-ip:3001` 查看仪表盘，包括：

- GPU 使用率和温度
- 内存占用（按服务）
- 请求延迟和吞吐量
- 模型切换频率
- 错误率和可用性

### 健康检查

```bash
# 运行健康检查脚本
./scripts/05-health-check.sh

# 输出示例
✅ Code Traditional Service: OK (18.2GB mem, 45 tok/s)
✅ Code Agentic Service: OK (14.8GB mem, 72 tok/s)
✅ Chat Advanced Service: OK (17.5GB mem, 58 tok/s)
✅ Chat Fast Service: OK (3.9GB mem, 187 tok/s)
✅ Gateway Service: OK (342ms avg latency)
✅ Web UI Service: OK
```

### 性能基准测试

```bash
# 运行完整基准测试
./scripts/06-benchmark.sh

# 只测试代码模型
./scripts/06-benchmark.sh --code-benchmark

# 只测试对话模型
./scripts/06-benchmark.sh --chat-benchmark
```

---

## 📚 文档

- [架构设计](docs/01-architecture.md) - 系统架构详解
- [模型选型](docs/02-model-selection.md) - 模型选择依据和对比
- [部署指南](docs/03-deployment-guide.md) - 详细部署步骤
- [用户指南](docs/04-user-guide.md) - 使用手册和 API 文档
- [故障排除](docs/05-troubleshooting.md) - 常见问题解决

---

## ❓ 常见问题

### Q: 需要多少存储空间？

A: 约 200GB（模型 ~150GB + 系统和缓存 ~50GB）。建议使用 NVMe SSD。

### Q: 可以只部署部分服务吗？

A: 可以。编辑 `docker-compose.yml` 或 K3s 配置，注释掉不需要的服务。

### Q: 支持其他语言吗？

A: Qwen 系列模型支持 119 种语言，包括中英日韩法德西等主流语言。

### Q: 如何升级模型？

A: 修改 `vllm/models.yaml` 中的模型版本，重新运行 `./scripts/02-pull-models.sh`。

### Q: 内存不足怎么办？

A: 可以：
1. 使用更小的模型（如只用 Qwen3-8B 做对话）
2. 启用模型热插拔（代码助手按需加载）
3. 增加 INT8 量化（牺牲少量精度）

### Q: 可以在其他 NVIDIA GPU 上运行吗？

A: 可以，但需要至少 48GB 显存。建议使用 A100/H100 或多卡部署。

更多问题见 [FAQ](docs/05-troubleshooting.md#faq)

---

## 🤝 贡献指南

欢迎贡献！以下方式都可以帮助改进项目：

- 🐛 提交 Bug 报告
- 💡 提出新功能建议
- 📝 改进文档
- 🔧 提交代码修复或新功能

请阅读 [贡献指南](CONTRIBUTING.md) 了解详情。

---

## 📄 许可证

本项目采用 [Apache 2.0 许可证](LICENSE)。

### 模型许可

- **Qwen 系列**: Apache 2.0
- **Whisper**: MIT
- **Piper**: MIT

---

## 🙏 致谢

感谢以下开源项目：

- [Qwen Team](https://github.com/QwenLM) - 优秀的开源模型
- [vLLM](https://github.com/vllm-project/vllm) - 高性能推理引擎
- [NVIDIA Jetson AI Lab](https://github.com/dusty-nv/jetson-containers) - Jetson 容器生态
- [Open WebUI](https://github.com/open-webui/open-webui) - 优雅的前端界面

---

## 📞 联系方式

- **Issues**: [GitHub Issues](https://github.com/yourusername/FamilyAI/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/FamilyAI/discussions)

---

<div align="center">

**⭐ 如果觉得项目有帮助，请给个 Star！**

Made with ❤️ for families who value privacy and AI

</div>
