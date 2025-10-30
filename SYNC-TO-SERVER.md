# 同步文件到 Jetson Thor 服务器

## 方法 1: 使用 Git（推荐）

在服务器上直接从 GitHub 拉取最新代码：

```bash
# 在 Jetson Thor 服务器上执行
cd /path/to/FamilyAI
git pull origin master
```

**优势：**
- 自动同步所有修改
- 保留 Git 历史记录
- 简单快速

## 方法 2: 使用 rsync

从开发机同步特定文件到服务器：

```bash
# 在开发机上执行
rsync -avz --progress \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='*.pyc' \
  --exclude='__pycache__' \
  .env.example \
  docker-compose.yml \
  docker-compose.download.yml \
  download-quantized-models.sh \
  test-jetson-fix.sh \
  scripts/batch-download-quantized.sh \
  QUANTIZATION-SUMMARY.md \
  QUANTIZATION-QUICKSTART.md \
  user@jetson-thor-ip:/path/to/FamilyAI/
```

**注意：**
- `.env` 文件被排除（需要手动配置）
- 保留服务器上的本地配置

## 方法 3: 手动复制单个文件

如果只需要更新特定文件：

```bash
scp download-quantized-models.sh user@jetson-thor-ip:/path/to/FamilyAI/
scp scripts/batch-download-quantized.sh user@jetson-thor-ip:/path/to/FamilyAI/scripts/
```

## 同步后的步骤

### 1. 配置 .env 文件

如果是首次部署或 `.env` 文件不存在：

```bash
# 在 Jetson Thor 服务器上执行
cd /path/to/FamilyAI
cp .env.example .env
nano .env  # 或使用 vim

# 必须修改的配置：
# - HF_HOME: 改为服务器实际路径（例如 /home/YOUR_USERNAME/.cache/huggingface）
# - PROXY_URL: 确认代理地址正确
# - JETSON_THOR_IP: 改为实际服务器 IP
```

### 2. 添加执行权限

```bash
chmod +x download-quantized-models.sh
chmod +x test-jetson-fix.sh
chmod +x scripts/batch-download-quantized.sh
```

### 3. 验证配置

```bash
# 检查 .env 配置
grep -E "HF_HOME|PROXY_URL|VLLM_GPU_MEMORY_UTILIZATION|CHAT_LIGHT_MODEL" .env

# 检查 Docker Compose 配置
docker compose config | grep -E "quantization|gpu-memory-utilization|max-model-len" | head -20
```

### 4. 下载量化模型

```bash
# 批量下载所有量化模型
./download-quantized-models.sh

# 预计时间：30-60 分钟
# 总大小：~33.5GB
```

### 5. 测试启动服务

```bash
# 使用测试脚本（推荐）
./test-jetson-fix.sh

# 或手动启动
docker compose down
docker compose up -d chat-light
docker logs familyai-chat-light -f
```

## 常见问题

### Q: Git pull 失败，提示 "would be overwritten"

```bash
# 查看冲突文件
git status

# 如果是配置文件冲突，备份后重置
cp .env .env.backup
git reset --hard origin/master
cp .env.backup .env
```

### Q: rsync 权限被拒绝

```bash
# 确保目标目录有写权限
ssh user@jetson-thor-ip "chmod 755 /path/to/FamilyAI"

# 或使用 sudo
ssh user@jetson-thor-ip "sudo chown -R $USER:$USER /path/to/FamilyAI"
```

### Q: .env 文件被覆盖

`.env` 文件在 `.gitignore` 中，不会被 Git 同步。如果使用 rsync：

1. 添加 `--exclude='.env'` 参数
2. 或在同步后手动恢复：`cp .env.backup .env`

## 验证同步成功

```bash
# 检查文件是否存在
ls -lh download-quantized-models.sh
ls -lh scripts/batch-download-quantized.sh
ls -lh QUANTIZATION-QUICKSTART.md

# 检查 Git 状态（如果使用 Git）
git log --oneline -1

# 检查文件权限
ls -l download-quantized-models.sh test-jetson-fix.sh
# 应该显示 -rwxr-xr-x（可执行权限）
```

---

**提示：** 推荐使用 Git 方式同步，保持开发机和服务器代码一致。
