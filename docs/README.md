# FamilyAI 文档中心

欢迎来到 FamilyAI 文档中心！这里包含了完整的部署、配置和使用文档。

---

## 📚 文档目录

### 🚀 快速开始

1. **[Jetson Thor 部署指南](jetson-thor-deployment.md)** ⭐ 推荐首次阅读
   - 完整的服务器端部署步骤
   - 从零开始的详细配置
   - 故障排查和性能优化

2. **[快速参考指南](quick-reference.md)**
   - 常用命令速查表
   - Docker 操作备忘录
   - API 测试示例

---

## 📖 按主题浏览

### 部署相关

| 文档 | 描述 | 适用人群 |
|------|------|----------|
| [Jetson Thor 部署](jetson-thor-deployment.md) | 完整部署流程 | 系统管理员 |
| [Docker Compose 部署](../README.md#快速开始) | 开发环境快速部署 | 开发者 |
| K3s 生产部署 | Kubernetes 生产环境 | DevOps 工程师 |

### 配置相关

| 文档 | 描述 |
|------|------|
| [环境变量配置](../.env.example) | 所有配置项说明 |
| [网关路由配置](../gateway/config.yaml) | 智能路由规则 |
| [模型配置](../vllm/) | vLLM 模型参数 |

### 使用相关

| 文档 | 描述 |
|------|------|
| [快速参考](quick-reference.md) | 常用命令 |
| [API 文档](#api-文档) | REST API 使用 |
| [客户端集成](#客户端集成) | IDE 和工具集成 |

### 运维相关

| 文档 | 描述 |
|------|------|
| [监控和告警](#监控系统) | Prometheus + Grafana |
| [备份和恢复](quick-reference.md#备份和恢复) | 数据备份策略 |
| [故障排查](jetson-thor-deployment.md#9-故障排查) | 常见问题解决 |

---

## 🎯 根据角色选择文档

### 👨‍💼 管理员/运维人员

如果你负责部署和维护 FamilyAI 系统：

1. 阅读 [Jetson Thor 部署指南](jetson-thor-deployment.md)
2. 收藏 [快速参考指南](quick-reference.md)
3. 了解 [监控系统配置](#监控系统)
4. 设置 [备份策略](quick-reference.md#备份和恢复)

### 👨‍💻 开发者

如果你要开发或集成 FamilyAI：

1. 快速部署开发环境（[README.md](../README.md)）
2. 查看 [API 文档](#api-文档)
3. 了解 [网关路由逻辑](../CLAUDE.md#intelligent-routing)
4. 参考 [客户端集成示例](#客户端集成)

### 👥 最终用户

如果你是 FamilyAI 的使用者：

1. 了解 [Web UI 使用](../README.md#使用指南)
2. 配置 [VS Code 集成](#vs-code-集成)
3. 查看 [API 使用示例](quick-reference.md#api-测试)

---

## 📝 详细文档

### API 文档

FamilyAI 提供 OpenAI 兼容的 REST API：

**基础地址**: `http://jetson-thor-ip:8080`

**认证方式**:
```bash
Authorization: Bearer YOUR_API_KEY
```

**主要端点**:

#### 1. 列出模型
```bash
GET /v1/models
```

响应示例:
```json
{
  "object": "list",
  "data": [
    {"id": "auto", "object": "model"},
    {"id": "code-traditional", "object": "model"},
    {"id": "chat-advanced", "object": "model"}
  ]
}
```

#### 2. 聊天补全
```bash
POST /v1/chat/completions
```

请求示例:
```json
{
  "model": "auto",
  "messages": [
    {"role": "system", "content": "你是一个有帮助的助手"},
    {"role": "user", "content": "解释什么是 Docker"}
  ],
  "temperature": 0.7,
  "max_tokens": 2000,
  "stream": false
}
```

#### 3. 流式响应
```json
{
  "model": "chat-fast",
  "messages": [...],
  "stream": true
}
```

**模型选择规则**:
- `auto`: 自动选择最优模型
- `code-traditional`: 代码补全和生成
- `code-agentic`: 复杂代码分析
- `chat-advanced`: 复杂对话
- `chat-fast`: 快速响应
- `chat-light`: 轻量交互
- `vision`: 图像理解

### 客户端集成

#### VS Code 集成

1. 安装 [Continue](https://marketplace.visualstudio.com/items?itemName=Continue.continue) 插件

2. 配置 `~/.continue/config.json`:
```json
{
  "models": [
    {
      "title": "FamilyAI Code",
      "provider": "openai",
      "model": "code-traditional",
      "apiBase": "http://jetson-thor-ip:8080/v1",
      "apiKey": "your-api-key"
    }
  ],
  "tabAutocompleteModel": {
    "title": "FamilyAI Autocomplete",
    "provider": "openai",
    "model": "code-traditional",
    "apiBase": "http://jetson-thor-ip:8080/v1",
    "apiKey": "your-api-key"
  }
}
```

#### Cursor 集成

Settings → Models → Add Model:
```
Model: code-traditional
API Base: http://jetson-thor-ip:8080/v1
API Key: your-api-key
```

#### Python SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://jetson-thor-ip:8080/v1",
    api_key="your-api-key"
)

response = client.chat.completions.create(
    model="auto",
    messages=[
        {"role": "user", "content": "你好"}
    ]
)

print(response.choices[0].message.content)
```

#### Node.js SDK

```javascript
import OpenAI from 'openai';

const openai = new OpenAI({
  baseURL: 'http://jetson-thor-ip:8080/v1',
  apiKey: 'your-api-key',
});

const completion = await openai.chat.completions.create({
  model: 'auto',
  messages: [
    { role: 'user', content: '你好' }
  ],
});

console.log(completion.choices[0].message.content);
```

### 监控系统

#### Prometheus

**访问地址**: `http://jetson-thor-ip:9090`

**可用指标**:
- `vllm_request_total`: 请求总数
- `vllm_request_latency_seconds`: 请求延迟
- `vllm_gpu_memory_usage_bytes`: GPU 内存使用
- `vllm_gpu_utilization`: GPU 利用率

**常用查询**:
```promql
# 平均响应时间
rate(vllm_request_latency_seconds_sum[5m]) / rate(vllm_request_latency_seconds_count[5m])

# GPU 内存使用率
vllm_gpu_memory_usage_bytes / vllm_gpu_memory_total_bytes * 100

# 每分钟请求数
rate(vllm_request_total[1m]) * 60
```

#### Grafana

**访问地址**: `http://jetson-thor-ip:3001`

**默认凭据**:
- 用户名: `admin`
- 密码: 见 `.env` 中的 `GRAFANA_ADMIN_PASSWORD`

**预置仪表板**:
1. FamilyAI Overview - 系统总览
2. Model Performance - 模型性能
3. GPU Metrics - GPU 监控
4. Request Analytics - 请求分析

---

## 🔍 搜索文档

使用以下关键词快速查找信息：

- **部署**: deployment, install, setup
- **配置**: config, environment, .env
- **API**: rest, endpoint, request
- **故障**: troubleshoot, error, issue
- **性能**: performance, optimization, tuning
- **监控**: monitoring, metrics, grafana
- **备份**: backup, restore, recovery

---

## 💡 最佳实践

### 部署建议

1. **生产环境**: 使用 K3s + 监控
2. **开发环境**: 使用 Docker Compose
3. **测试环境**: 使用轻量级模型组合

### 安全建议

1. 启用 API 认证
2. 使用防火墙限制访问
3. 定期更新系统和镜像
4. 设置备份策略
5. 监控异常访问

### 性能建议

1. GPU 内存使用率控制在 85-90%
2. 不要同时运行所有模型
3. 根据实际负载选择模型
4. 启用 CUDA Graph
5. 使用适当的量化方式

---

## 📞 获取支持

### 自助资源

1. 查看 [常见问题](../README.md#常见问题)
2. 阅读 [故障排查指南](jetson-thor-deployment.md#9-故障排查)
3. 搜索 [GitHub Issues](https://github.com/yourusername/FamilyAI/issues)

### 社区支持

1. [GitHub Discussions](https://github.com/yourusername/FamilyAI/discussions)
2. [Discord 频道](#)
3. [微信交流群](#)

### 商业支持

如需商业支持和定制开发，请联系: support@familyai.example.com

---

## 📅 文档更新日志

| 日期 | 更新内容 |
|------|---------|
| 2025-10-13 | 初始版本发布 |
| 2025-10-13 | 添加 Jetson Thor 部署指南 |
| 2025-10-13 | 添加快速参考指南 |

---

## 🤝 贡献文档

欢迎贡献和改进文档！

1. Fork 项目
2. 创建文档分支: `git checkout -b docs/your-improvement`
3. 提交更改: `git commit -m 'docs: improve deployment guide'`
4. 推送分支: `git push origin docs/your-improvement`
5. 提交 Pull Request

**文档规范**:
- 使用 Markdown 格式
- 包含代码示例
- 提供清晰的步骤说明
- 添加目录和导航链接

---

**感谢使用 FamilyAI！** 🚀

如有任何文档问题或改进建议，请在 [GitHub Issues](https://github.com/yourusername/FamilyAI/issues) 提出。
