# FamilyAI 量化模型快速部署指南

## 概述

本指南帮助您在 Jetson Thor 服务器上快速部署 INT4 量化模型，将内存占用从 ~272GB 降至 ~65GB（日常服务仅需 ~15GB）。

## 快速开始

### 1. 同步文件到服务器

将以下文件从开发机同步到 Jetson Thor 服务器：

```bash
# 在开发机上执行
rsync -avz --progress \
  .env \
  docker-compose.yml \
  docker-compose.download.yml \
  download-quantized-models.sh \
  test-jetson-fix.sh \
  scripts/batch-download-quantized.sh \
  QUANTIZATION-SUMMARY.md \
  user@jetson-thor:/path/to/FamilyAI/
```

### 2. 下载量化模型

在 Jetson Thor 服务器上执行：

```bash
cd /path/to/FamilyAI

# 批量下载所有 6 个量化模型（推荐）
./download-quantized-models.sh

# 预计时间：30-60 分钟
# 总大小：~33.5GB
```

**可选：单独下载指定模型**

```bash
# 仅下载轻量级模型（用于测试）
./download-quantized-models.sh --model chat-light

# 下载多个模型
./download-quantized-models.sh --model chat-light --model chat-fast
```

### 3. 测试启动服务

```bash
# 停止所有现有容器
docker compose down

# 测试启动最轻量的服务
docker compose up -d chat-light

# 查看启动日志
docker logs familyai-chat-light -f

# 应该看到：
# - quantization: awq
# - Model loading took 2.xxxx GiB
```

### 4. 验证内存占用

```bash
# 检查系统内存
free -h

# 预期结果：
# - chat-light 占用约 5GB 内存
# - 剩余内存充足（>100GB）

# 验证容器实际配置
docker logs familyai-chat-light 2>&1 | grep "gpu_memory_utilization"
# 应该显示: 0.30

docker logs familyai-chat-light 2>&1 | grep "max_model_len"
# 应该显示: 8192
```

### 5. 启动其他服务

**日常模式（推荐，~15GB 内存）：**

```bash
docker compose up -d chat-light chat-fast vision whisper piper gateway web-ui
```

**开发模式（~20GB 内存）：**

```bash
docker compose up -d chat-light code-traditional gateway web-ui
```

**完整模式（~65GB 内存）：**

```bash
docker compose up -d
```

## 服务内存占用参考

| 服务 | 量化方法 | 模型大小 | 内存占用 |
|------|---------|---------|---------|
| chat-light | AWQ INT4 | 2.5GB | ~5GB |
| chat-fast | GPTQ INT4 | 2.5GB | ~6GB |
| chat-advanced | AWQ INT4 | 9GB | ~15.5GB |
| code-traditional | AWQ INT4 | 9GB | ~15.5GB |
| code-agentic | GPTQ INT4 | 8GB | ~16.5GB |
| vision | GPTQ INT4 | 2.5GB | ~6GB |
| whisper + piper | - | <1GB | ~3GB |

## 常见问题

### Q1: 容器启动失败

```bash
# 查看错误日志
docker logs familyai-chat-light --tail 50

# 常见问题检查
docker logs familyai-chat-light 2>&1 | grep "quantization"
# 应该看到: quantization: awq 或 gptq

# 如果看到 quantization: fp8，说明配置未生效
# 需要强制重建容器
docker compose down
docker compose up -d chat-light --force-recreate
```

### Q2: 内存占用过高

```bash
# 检查 .env 配置
grep "VLLM_GPU_MEMORY_UTILIZATION" .env
# 应该显示: 0.3

grep "CHAT_LIGHT_MAX_MODEL_LEN" .env
# 应该显示: 8192

# 如果配置正确但内存仍然过高，检查容器实际使用的值
docker logs familyai-chat-light 2>&1 | grep "gpu_memory_utilization\|max_model_len"
```

### Q3: 模型下载失败

```bash
# 检查代理配置
grep PROXY_URL .env

# 单独重试下载失败的模型
./download-quantized-models.sh --model chat-light

# 查看下载容器日志
docker logs familyai-batch-quantized-downloader
```

### Q4: 内存未释放（需要重启）

如果停止容器后内存未释放：

```bash
# 检查内存状态
free -h

# 如果大量内存被标记为"used"但没有进程占用
# 这是 Jetson Thor UMA 的已知问题
# 解决方法：重启系统
sudo reboot
```

## 验证成功标志

启动成功后，您应该看到：

1. **容器日志显示：**
   ```
   quantization: awq
   gpu_memory_utilization: 0.30
   max_model_len: 8192
   Model loading took 2.xxxx GiB
   Application startup complete
   ```

2. **内存占用正常：**
   ```bash
   free -h
   # chat-light: ~5GB
   # 剩余: >100GB
   ```

3. **服务响应正常：**
   ```bash
   curl http://localhost:8005/health
   # 返回: {"status":"ok"}
   ```

## 下一步

- 查看完整配置说明：`QUANTIZATION-SUMMARY.md`
- 性能测试：`./scripts/06-benchmark.sh`
- Web UI 访问：`http://<jetson-thor-ip>:3000`

## 支持

遇到问题？

1. 检查 `QUANTIZATION-SUMMARY.md` 的"故障排查"章节
2. 运行 `test-jetson-fix.sh` 自动诊断配置问题
3. 查看容器日志：`docker logs familyai-<service-name> --tail 100`

---

**更新日期**: 2025-10-30
**配置版本**: v2.0 - Container-based Quantization
