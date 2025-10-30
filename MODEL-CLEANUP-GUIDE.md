# 模型清理指南

## 概述

当您从非量化模型迁移到 INT4 量化模型后，旧的非量化模型文件仍会占用大量磁盘空间（~272GB）。本指南帮助您安全地删除这些文件。

## HuggingFace 缓存目录结构

```
~/.cache/huggingface/
└── hub/
    ├── models--Qwen--Qwen3-4B-Instruct-2507/          # 非量化 (7.6GB)
    ├── models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ/  # 量化 (2.5GB) ✓ 保留
    ├── models--Qwen--Qwen3-8B/                        # 非量化 (16GB)
    ├── models--JunHowie--Qwen3-8B-GPTQ-Int4/         # 量化 (2.5GB) ✓ 保留
    └── ...
```

## 方法 1: 使用自动清理脚本（推荐）

### 步骤 1: 运行清理脚本

在 Jetson Thor 服务器上执行：

```bash
cd /path/to/FamilyAI

# 运行清理脚本
./cleanup-non-quantized-models.sh
```

### 步骤 2: 确认删除

脚本会显示待删除的模型列表：

```
即将删除的非量化模型：

[待删除] Qwen3-4B (BF16, 7.6GB)
  路径: /home/sindoyang/.cache/huggingface/hub/models--Qwen--Qwen3-4B-Instruct-2507
  大小: 7.6G

[待删除] Qwen3-32B (BF16, 64GB)
  路径: /home/sindoyang/.cache/huggingface/hub/models--Qwen--Qwen3-32B
  大小: 64G

...

发现 7 个非量化模型
预计释放空间: 272GB

⚠️  警告: 此操作不可逆！

确认删除？(输入 'yes' 继续):
```

输入 `yes` 确认删除。

### 步骤 3: 验证结果

脚本会显示保留的量化模型：

```
当前保留的量化模型：

[保留] chat-light (AWQ INT4, 2.5GB) - 2.5G
[保留] chat-fast (GPTQ INT4, 2.5GB) - 2.5G
...

HuggingFace 缓存目录总大小: 34G
```

## 方法 2: 手动删除

如果您希望手动删除特定模型：

### 查看所有已下载的模型

```bash
ls -lh ~/.cache/huggingface/hub/
```

### 删除单个非量化模型

```bash
# 示例：删除非量化的 Qwen3-4B
rm -rf ~/.cache/huggingface/hub/models--Qwen--Qwen3-4B-Instruct-2507

# 示例：删除非量化的 Qwen3-32B
rm -rf ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B
```

### 批量删除所有非量化 Qwen 模型

```bash
# ⚠️ 危险操作：会删除所有 Qwen 官方仓库的模型（包括量化的）
# 请谨慎使用，确保已下载量化版本

# 仅删除非量化模型（不包含 AWQ/GPTQ）
cd ~/.cache/huggingface/hub/
rm -rf models--Qwen--Qwen3-4B-Instruct-2507
rm -rf models--Qwen--Qwen3-8B
rm -rf models--Qwen--Qwen3-32B  # 注意：会删除非量化版本
rm -rf models--Qwen--Qwen2.5-Coder-32B-Instruct
rm -rf models--Qwen--Qwen3-30B-A3B-Instruct-2507
rm -rf models--Qwen--Qwen3-VL-8B-Instruct
rm -rf models--Qwen--Qwen2-VL-7B-Instruct
```

## 需要删除的非量化模型列表

| 模型目录 | 描述 | 大小 | 是否删除 |
|---------|------|------|---------|
| `models--Qwen--Qwen3-4B-Instruct-2507` | Qwen3-4B (BF16) | ~7.6GB | ✓ 删除 |
| `models--Qwen--Qwen3-8B` | Qwen3-8B (BF16) | ~16GB | ✓ 删除 |
| `models--Qwen--Qwen3-32B` | Qwen3-32B (BF16) | ~64GB | ⚠️ 与量化版本同名 |
| `models--Qwen--Qwen2.5-Coder-32B-Instruct` | Qwen2.5-Coder-32B (BF16) | ~64GB | ✓ 删除 |
| `models--Qwen--Qwen3-30B-A3B-Instruct-2507` | Qwen3-30B-A3B (BF16) | ~60GB | ✓ 删除 |
| `models--Qwen--Qwen3-VL-8B-Instruct` | Qwen3-VL-8B (BF16) | ~16GB | ✓ 删除 |
| `models--Qwen--Qwen2-VL-7B-Instruct` | Qwen2-VL-7B (BF16) | ~14GB | ✓ 删除 |

**总计可释放空间：~272GB**

## 需要保留的量化模型列表

| 模型目录 | 描述 | 大小 | 用途 |
|---------|------|------|------|
| `models--Eslzzyl--Qwen3-4B-Instruct-2507-AWQ` | Qwen3-4B (AWQ INT4) | ~2.5GB | chat-light |
| `models--JunHowie--Qwen3-8B-GPTQ-Int4` | Qwen3-8B (GPTQ INT4) | ~2.5GB | chat-fast |
| `models--Qwen--Qwen3-32B-AWQ` | Qwen3-32B (AWQ INT4) | ~9GB | chat-advanced |
| `models--Qwen--Qwen2.5-Coder-32B-Instruct-AWQ` | Qwen2.5-Coder-32B (AWQ INT4) | ~9GB | code-traditional |
| `models--Qwen--Qwen3-30B-A3B-GPTQ-Int4` | Qwen3-30B-A3B (GPTQ INT4) | ~8GB | code-agentic |
| `models--Qwen--Qwen2-VL-7B-Instruct-GPTQ-Int4` | Qwen2-VL-7B (GPTQ INT4) | ~2.5GB | vision |
| `models--Systran--faster-whisper-small` | Whisper Small (CTranslate2) | <1GB | whisper |

**总计保留空间：~34GB**

## 特殊情况处理

### 问题 1: Qwen3-32B 同名冲突

某些官方量化模型与非量化版本可能使用相同的仓库名（例如 `Qwen/Qwen3-32B-AWQ` 和 `Qwen/Qwen3-32B`）。

**解决方法：**

1. 先检查模型目录内是否包含量化文件：
   ```bash
   ls ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B/snapshots/*/
   # 查找是否有 .safetensors 文件带有 "awq" 或 "gptq" 标记
   ```

2. 如果不确定，可以先备份：
   ```bash
   mv ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B \
      ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B.backup
   ```

3. 重新下载量化版本：
   ```bash
   ./download-quantized-models.sh --model chat-advanced
   ```

4. 验证新模型正常后删除备份：
   ```bash
   rm -rf ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B.backup
   ```

### 问题 2: 权限不足

如果删除时提示权限不足：

```bash
# 使用 sudo
sudo rm -rf ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B

# 或修改权限后删除
sudo chown -R $USER:$USER ~/.cache/huggingface
rm -rf ~/.cache/huggingface/hub/models--Qwen--Qwen3-32B
```

### 问题 3: 误删量化模型

如果不慎删除了量化模型，可以重新下载：

```bash
# 重新下载所有量化模型
./download-quantized-models.sh

# 或单独下载特定模型
./download-quantized-models.sh --model chat-light
```

## 验证清理结果

### 检查磁盘空间

```bash
# 查看缓存目录大小
du -sh ~/.cache/huggingface/hub/

# 查看系统可用空间
df -h
```

### 验证量化模型完整性

```bash
# 列出所有保留的模型
ls -lh ~/.cache/huggingface/hub/ | grep -E "AWQ|GPTQ|faster-whisper"

# 验证服务启动
docker compose up -d chat-light
docker logs familyai-chat-light 2>&1 | grep "Model loading took"
# 应该显示: Model loading took 2.xxxx GiB
```

## 其他缓存清理

完成模型清理后，您还可以清理其他缓存：

```bash
# 清理 pip 缓存
pip cache purge

# 清理 Docker 缓存（谨慎使用）
docker system prune -a

# 清理 APT 缓存（Ubuntu/Debian）
sudo apt-get clean
sudo apt-get autoclean

# 清理日志文件
sudo journalctl --vacuum-time=7d

# 清理临时文件
sudo rm -rf /tmp/*
```

## 安全建议

1. **删除前验证量化模型可用**
   - 先下载所有量化模型
   - 测试至少一个服务启动成功
   - 确认内存占用正常（~5GB）

2. **分阶段删除**
   - 先删除最大的模型（32B）
   - 验证服务正常
   - 再删除其他模型

3. **保留备份时间窗口**
   - 建议保留 1-2 周观察期
   - 确认量化模型完全满足需求
   - 再执行最终清理

4. **记录删除日志**
   ```bash
   ./cleanup-non-quantized-models.sh 2>&1 | tee cleanup-$(date +%Y%m%d).log
   ```

## 预期结果

清理完成后，您的系统应该：

- **HuggingFace 缓存**: ~34GB（从 ~306GB）
- **可用磁盘空间**: +272GB
- **服务内存占用**: ~5GB/服务（从 ~31GB）
- **所有量化模型**: 正常工作

---

**更新日期**: 2025-10-30
**脚本版本**: v1.0
