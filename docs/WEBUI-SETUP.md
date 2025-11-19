# Open WebUI 管理员设置指南

## 📋 首次部署 - 创建管理员账户

FamilyAI 默认**关闭公开注册**以确保安全。以下是设置管理员账户的步骤：

---

## 方法 1: 通过 Web 界面创建（推荐）

### 步骤 1: 临时开启注册

编辑 `.env` 文件：

```bash
# 临时开启注册（仅用于创建管理员）
WEBUI_ENABLE_SIGNUP=true
```

### 步骤 2: 启动 Web UI

```bash
docker-compose --profile full up -d web-ui
```

### 步骤 3: 访问并注册管理员

1. 打开浏览器访问: `http://<jetson-thor-ip>:3000`
2. 您会看到注册页面
3. 填写信息:
   - **邮箱**: 任意格式（如 `admin@familyai.local`）
   - **用户名**: 您的管理员用户名
   - **密码**: 设置强密码
4. 点击 "Sign Up"

**重要**: **第一个注册的用户自动成为管理员！**

### 步骤 4: 关闭公开注册

创建管理员账户后，立即关闭注册：

```bash
# 编辑 .env 文件
WEBUI_ENABLE_SIGNUP=false

# 重启 Web UI
docker-compose restart web-ui
```

---

## 方法 2: 使用自动化脚本

我们提供了一个脚本来简化流程：

### 步骤 1: 临时开启注册

```bash
# 编辑 .env 文件
WEBUI_ENABLE_SIGNUP=true

# 启动 Web UI
docker-compose --profile full up -d web-ui
```

### 步骤 2: 运行创建脚本

```bash
chmod +x scripts/create-admin.sh
./scripts/create-admin.sh
```

脚本会提示您输入:
- 管理员邮箱
- 管理员用户名
- 管理员密码

### 步骤 3: 关闭注册

脚本执行后会提示您关闭注册功能。

---

## 🔐 管理员账户信息

创建账户后，请妥善保管：

- **邮箱**: `_____________`
- **用户名**: `_____________`
- **密码**: `_____________`

---

## 👥 添加家庭成员

管理员登录后，可以通过以下方式添加家庭成员：

### 方法 A: 邀请链接（推荐）

1. 登录管理员账户
2. 进入 **Settings** → **Admin Panel**
3. 点击 **Users** → **Invite User**
4. 生成邀请链接并分享给家庭成员

### 方法 B: 临时开启注册

1. 临时设置 `WEBUI_ENABLE_SIGNUP=true`
2. 重启服务: `docker-compose restart web-ui`
3. 让家庭成员注册
4. 完成后立即关闭: `WEBUI_ENABLE_SIGNUP=false`

---

## 🛡️ 安全建议

### 基本安全

1. **强密码**: 使用至少 12 位包含大小写字母、数字和符号的密码
2. **关闭注册**: 始终保持 `WEBUI_ENABLE_SIGNUP=false`
3. **定期更新**: 定期更新 `WEBUI_SECRET_KEY`

### 高级安全（外网访问）

如果需要外网访问，建议：

1. **使用反向代理 (Nginx/Traefik)**
2. **启用 HTTPS**
3. **添加防火墙规则**
4. **启用 API 认证**:
   ```bash
   API_AUTH_ENABLED=true
   API_KEY=your-secure-random-key
   ```

---

## 🔄 重置管理员密码

如果忘记密码，有两种方法：

### 方法 1: 删除数据库重新开始

```bash
# 停止服务
docker-compose down

# 删除 Web UI 数据（会删除所有用户和聊天记录）
rm -rf ./data/open-webui

# 重新启动并创建管理员
docker-compose --profile full up -d
```

### 方法 2: 通过数据库修改

```bash
# 进入 Web UI 容器
docker exec -it familyai-webui bash

# 使用 Open WebUI 的密码重置工具（如果有）
# 或手动修改数据库
```

---

## 📝 配置参数说明

`.env` 文件中的 Web UI 相关配置：

```bash
# Web UI 端口
WEBUI_PORT=3000

# 加密密钥（请修改为随机字符串）
WEBUI_SECRET_KEY=change_this_to_a_random_secret_key

# 数据存储目录
WEBUI_DATA_DIR=./data/open-webui

# 是否允许注册（首次设为 true，创建管理员后改为 false）
WEBUI_ENABLE_SIGNUP=false

# 新用户默认角色
WEBUI_DEFAULT_USER_ROLE=user

# 连接到网关
WEBUI_OLLAMA_BASE_URL=http://gateway:8080/v1
```

---

## ❓ 常见问题

### Q: 为什么不能直接预设管理员账户？

A: Open WebUI 的设计要求首次访问时通过 Web 界面创建账户，这是为了确保密码安全（不以明文存储在配置文件中）。

### Q: 可以有多个管理员吗？

A: 可以。在管理员面板中可以将普通用户提升为管理员。

### Q: 如何备份用户数据？

A: 备份 `./data/open-webui` 目录即可。该目录包含所有用户数据和聊天记录。

```bash
# 备份
tar -czf webui-backup-$(date +%Y%m%d).tar.gz ./data/open-webui

# 恢复
tar -xzf webui-backup-YYYYMMDD.tar.gz
```

### Q: 忘记管理员邮箱怎么办？

A: 查看数据库文件：

```bash
docker exec -it familyai-webui cat /app/backend/data/webui.db | grep -a email
```

或者直接删除数据库重新创建。

---

## 📞 需要帮助？

如果遇到问题：

1. 检查 Web UI 日志: `docker-compose logs web-ui`
2. 确认服务运行: `docker-compose ps`
3. 验证端口开放: `curl http://localhost:3000`

---

**安全提示**: 创建管理员账户后，务必将 `WEBUI_ENABLE_SIGNUP` 设置为 `false`！
