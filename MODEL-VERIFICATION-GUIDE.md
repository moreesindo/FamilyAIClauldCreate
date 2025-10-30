# 模型验证指南

## 概述

本指南帮助您验证已下载的模型是否为正确的量化版本（INT4 AWQ/GPTQ），避免使用非量化模型导致内存占用过高。

## 快速检查

### 方法 1: 使用自动检查脚本（推荐）

```bash
cd /path/to/FamilyAI
./check-model-quantization.sh
```

**输出示例：**

```
===========================================
FamilyAI 模型量化检查脚本
===========================================

HuggingFace 缓存目录: /home/sindoyang/.cache/huggingface/hub

检查 .env 配置的模型：

[1] 检查 CHAT_LIGHT_MODEL
  配置模型: Eslzzyl/Qwen3-4B-Instruct-2507-AWQ
  预期模型: Eslzzyl/Qwen3-4B-Instruct-2507-AWQ
  预期量化: AWQ INT4
  本地路径: /home/sindoyang/.cache/huggingface/hub/models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ
  实际大小: 2.5G
  量化状态: ✓ 量化模型 (方法: awq)
  量化位数: 4-bit

[2] 检查 CHAT_FAST_MODEL
  配置模型: JunHowie/Qwen3-8B-GPTQ-Int4
  预期模型: JunHowie/Qwen3-8B-GPTQ-Int4
  预期量化: GPTQ INT4
  本地路径: /home/sindoyang/.cache/huggingface/hub/models--JunHowie--Qwen3-8B-GPTQ-Int4
  实际大小: 2.5G
  量化状态: ✓ 量化模型 (方法: gptq)
  量化位数: 4-bit

...

===========================================
检查结果汇总
===========================================
配置的模型总数: 6
已量化: 6
未下载/未配置: 0
不确定: 0

✓✓✓ 所有配置的模型均为量化版本！

下一步：
  1. 启动服务: docker compose up -d
  2. 清理非量化模型: ./cleanup-non-quantized-models.sh
===========================================
```

### 方法 2: 手动检查模型配置

检查模型的 `config.json` 文件：

```bash
# 检查 chat-light 模型配置
cat ~/.cache/huggingface/hub/models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ/snapshots/*/config.json | grep -A10 quantization

# 预期输出：
# "quantization_config": {
#   "quant_method": "awq",
#   "bits": 4,
#   "group_size": 128,
#   ...
# }
```

### 方法 3: 检查模型文件大小

量化模型明显更小：

```bash
# 查看所有已下载模型的大小
du -sh ~/.cache/huggingface/hub/models--*/

# 量化模型大小参考：
# - 4B 量化: ~2-3GB   (非量化: ~8GB)
# - 8B 量化: ~2-3GB   (非量化: ~16GB)
# - 32B 量化: ~8-10GB (非量化: ~64GB)
```

## 详细验证方法

### 1. 检查配置文件中的量化信息

**AWQ 量化特征：**

```bash
cat ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B-AWQ/snapshots/*/config.json

# 应该包含：
{
  "quantization_config": {
    "quant_method": "awq",
    "bits": 4,
    "group_size": 128,
    "zero_point": true,
    "version": "gemm"
  }
}
```

**GPTQ 量化特征：**

```bash
cat ~/.cache/huggingface/hub/models--JunHowie--Qwen3-8B-GPTQ-Int4/snapshots/*/config.json

# 应该包含：
{
  "quantization_config": {
    "quant_method": "gptq",
    "bits": 4,
    "group_size": 128,
    "desc_act": false
  }
}
```

### 2. 检查模型文件名

量化模型的权重文件名通常包含标识：

```bash
# AWQ 模型文件
ls ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B-AWQ/snapshots/*/
# 输出: model.safetensors (或包含 awq 标识)

# GPTQ 模型文件
ls ~/.cache/huggingface/hub/models--JunHowie--Qwen3-8B-GPTQ-Int4/snapshots/*/
# 输出: model.safetensors (或包含 gptq 标识)
```

### 3. 通过容器日志验证

启动服务后检查日志：

```bash
# 启动服务
docker compose up -d chat-light

# 检查量化配置
docker logs familyai-chat-light 2>&1 | grep -E "quantization|quant_method"

# 预期输出：
# quantization: awq
# or
# quantization: gptq
```

**完整日志示例：**

```bash
docker logs familyai-chat-light 2>&1 | grep -A5 -B5 "quantization"

# 量化模型输出：
# model: Eslzzyl/Qwen3-4B-Instruct-2507-AWQ
# quantization: awq
# dtype: torch.float16
# gpu_memory_utilization: 0.3
# max_model_len: 8192
# Model loading took 2.5312 GiB

# 非量化模型输出（错误）：
# model: Qwen/Qwen3-4B-Instruct-2507
# quantization: None
# dtype: torch.bfloat16
# Model loading took 7.6543 GiB
```

### 4. 检查内存占用

量化模型内存占用显著降低：

```bash
# 启动服务后检查内存
free -h

# 量化模型（正确）：
# - chat-light (4B AWQ): ~5GB
# - chat-fast (8B GPTQ): ~6GB
# - chat-advanced (32B AWQ): ~15.5GB

# 非量化模型（错误）：
# - chat-light (4B BF16): ~31GB
# - chat-fast (8B BF16): ~35GB
# - chat-advanced (32B BF16): ~95GB
```

## 常见问题排查

### 问题 1: 检查脚本显示"未下载"

**原因：** 模型未下载或 `.env` 配置错误

**解决：**

```bash
# 检查 .env 配置
grep -E "CHAT_LIGHT_MODEL|CHAT_FAST_MODEL" .env

# 下载缺失的模型
./download-quantized-models.sh

# 或单独下载
./download-quantized-models.sh --model chat-light
```

### 问题 2: 配置文件中无 quantization_config 字段

**原因：** 可能下载了非量化版本

**验证：**

```bash
# 检查模型仓库名
ls -d ~/.cache/huggingface/hub/models--*/

# 量化模型应包含以下标识之一：
# - AWQ
# - GPTQ
# - Int4
# - int4
```

**解决：**

```bash
# 删除非量化版本
rm -rf ~/.cache/huggingface/hub/models--Qwen--Qwen3-4B-Instruct-2507

# 重新下载量化版本
./download-quantized-models.sh --model chat-light
```

### 问题 3: 容器日志显示 "quantization: None"

**原因：** docker-compose.yml 配置错误或使用了非量化模型

**检查：**

```bash
# 查看 docker-compose 实际配置
docker compose config | grep -A20 "chat-light:"

# 应该显示：
# --quantization awq  # 或 gptq
# model: Eslzzyl/Qwen3-4B-Instruct-2507-AWQ
```

**解决：**

```bash
# 停止容器
docker compose down

# 强制重建
docker compose up -d chat-light --force-recreate

# 验证日志
docker logs familyai-chat-light 2>&1 | grep quantization
```

### 问题 4: 模型大小与预期不符

**情况 1：模型比预期大**

可能下载了非量化版本：

```bash
# 检查模型大小
du -sh ~/.cache/huggingface/hub/models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ

# 如果显示 >5GB（预期 2.5GB），可能是错误的模型
# 删除并重新下载
rm -rf ~/.cache/huggingface/hub/models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ
./download-quantized-models.sh --model chat-light
```

**情况 2：模型比预期小**

可能是部分下载或损坏：

```bash
# 重新下载（支持断点续传）
./download-quantized-models.sh --model chat-light
```

## 完整验证流程

### 步骤 1: 运行自动检查

```bash
./check-model-quantization.sh
```

### 步骤 2: 验证单个服务

```bash
# 启动最小服务
docker compose up -d chat-light

# 等待 30 秒启动
sleep 30

# 检查日志
docker logs familyai-chat-light --tail 50

# 验证关键信息：
# ✓ quantization: awq
# ✓ Model loading took 2.x GiB
# ✓ Application startup complete
```

### 步骤 3: 验证内存占用

```bash
# 检查系统内存
free -h

# 预期结果：
# - 启动前可用: ~115GB
# - 启动后可用: ~110GB
# - chat-light 占用: ~5GB
```

### 步骤 4: API 测试

```bash
# 测试服务响应
curl http://localhost:8005/v1/models

# 预期输出：
# {
#   "object": "list",
#   "data": [
#     {
#       "id": "Eslzzyl/Qwen3-4B-Instruct-2507-AWQ",
#       ...
#     }
#   ]
# }
```

## 量化模型清单

### 必须包含的量化标识

| 服务 | 模型仓库名 | 量化方法 | 目录名关键字 |
|------|-----------|---------|-------------|
| chat-light | Eslzzyl/Qwen3-4B-Instruct-2507-**AWQ** | AWQ INT4 | `AWQ` |
| chat-fast | JunHowie/Qwen3-8B-**GPTQ-Int4** | GPTQ INT4 | `GPTQ-Int4` |
| chat-advanced | Qwen/Qwen3-32B-**AWQ** | AWQ INT4 | `AWQ` |
| code-traditional | Qwen/Qwen2.5-Coder-32B-Instruct-**AWQ** | AWQ INT4 | `AWQ` |
| code-agentic | Qwen/Qwen3-30B-A3B-**GPTQ-Int4** | GPTQ INT4 | `GPTQ-Int4` |
| vision | Qwen/Qwen2-VL-7B-Instruct-**GPTQ-Int4** | GPTQ INT4 | `GPTQ-Int4` |

### 模型大小参考

| 参数量 | 非量化 (BF16) | 量化 (INT4) | 压缩比 |
|-------|--------------|------------|--------|
| 4B | 7.6GB | 2.5GB | 67% |
| 8B | 16GB | 2.5GB | 84% |
| 32B | 64GB | 9GB | 86% |
| 30B MoE | 60GB | 8GB | 87% |

## 错误模型识别

### 非量化模型特征（需删除）

```bash
# 目录名不包含 AWQ/GPTQ/Int4
models--Qwen--Qwen3-4B-Instruct-2507  # ✗ 非量化
models--Qwen--Qwen3-8B                # ✗ 非量化
models--Qwen--Qwen3-32B               # ✗ 非量化（如无 -AWQ 后缀）

# 模型大小异常大
Qwen3-4B: 7.6GB   # ✗ 应该是 2.5GB
Qwen3-8B: 16GB    # ✗ 应该是 2.5GB
Qwen3-32B: 64GB   # ✗ 应该是 9GB

# 配置文件无量化字段
cat config.json | grep quantization
# 无输出或 "quantization_config": null  # ✗ 非量化
```

### 量化模型特征（保留）

```bash
# 目录名包含量化标识
models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ      # ✓ AWQ 量化
models--JunHowie--Qwen3-8B-GPTQ-Int4             # ✓ GPTQ 量化
models--Qwen--Qwen3-32B-AWQ                       # ✓ AWQ 量化

# 模型大小正常
Qwen3-4B-AWQ: 2.5GB    # ✓ 正确
Qwen3-8B-GPTQ: 2.5GB   # ✓ 正确
Qwen3-32B-AWQ: 9GB     # ✓ 正确

# 配置文件包含量化信息
"quantization_config": {
  "quant_method": "awq",  # ✓ 量化模型
  "bits": 4               # ✓ INT4
}
```

## 脚本输出说明

### 状态标识

- **✓ 量化模型** - 确认为量化版本，可以使用
- **✗ 未下载** - 模型未下载，需要运行下载脚本
- **✗ 未配置** - .env 文件中未配置此模型
- **✗ 可能是非量化模型** - 无法确认量化，建议重新下载
- **? 可能是量化模型** - 无明确证据，但文件大小符合预期

### 建议操作

根据检查结果采取相应操作：

1. **所有模型已量化** → 可以启动服务
2. **部分未下载** → 运行 `./download-quantized-models.sh`
3. **部分非量化** → 删除并重新下载
4. **不确定** → 查看详细日志或重新下载

---

**更新日期**: 2025-10-30
**脚本版本**: v1.0
