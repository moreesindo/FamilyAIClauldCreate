# FamilyAI 代理配置指南

本文档说明如何正确配置代理，以便容器能够访问宿主机上的代理服务。

---

## 🔍 问题说明

**重要**: 在 Docker 容器内部，`127.0.0.1` 和 `localhost` 指向容器自己，**不是宿主机**。

如果你的代理服务运行在宿主机上（例如：`192.168.3.84:2526`），容器需要使用宿主机的 IP 地址来访问代理。

---

## 📋 配置方法

### 方法一：使用宿主机 IP（推荐）⭐

**适用场景**: 代理服务运行在宿主机上

**配置步骤**:

1. **确认宿主机 IP**:
```bash
# 在宿主机上执行
ip addr show | grep "inet " | grep -v 127.0.0.1
# 或
hostname -I
```

假设输出是: `192.168.3.84`

2. **确认代理端口**:
```bash
# 检查代理服务是否在监听
netstat -tlnp | grep 2526
# 或
ss -tlnp | grep 2526
```

3. **测试代理连接**:
```bash
# 从宿主机测试
curl -x http://192.168.3.84:2526 https://www.google.com

# 如果成功，说明代理配置正确
```

4. **编辑 `.env` 文件**:
```bash
nano .env
```

修改代理配置:
```bash
# 使用宿主机 IP
PROXY_URL=http://192.168.3.84:2526

# 添加宿主机 IP 到 NO_PROXY
NO_PROXY=localhost,127.0.0.1,172.28.0.0/16,192.168.3.84
```

5. **确保代理监听所有接口**:

如果你的代理只监听 `127.0.0.1`，需要修改为监听 `0.0.0.0` 或特定网卡 IP。

**常见代理软件配置**:

- **Clash**: 修改 `config.yaml`
  ```yaml
  mixed-port: 2526
  bind-address: 0.0.0.0  # 或 192.168.3.84
  ```

- **V2Ray**: 修改 `config.json`
  ```json
  {
    "inbounds": [{
      "listen": "0.0.0.0",  // 监听所有接口
      "port": 2526
    }]
  }
  ```

- **SSH Tunnel**:
  ```bash
  ssh -D 0.0.0.0:2526 user@remote-server
  ```

6. **配置防火墙允许容器访问**:
```bash
# 如果使用 UFW
sudo ufw allow from 172.28.0.0/16 to any port 2526

# 或允许所有 Docker 网络
sudo ufw allow from 172.16.0.0/12 to any port 2526
```

---

### 方法二：使用 Docker 网桥 IP

**适用场景**: 代理运行在宿主机，想要更灵活的配置

Docker 会在宿主机上创建网桥，容器可以通过网桥 IP 访问宿主机。

1. **查找网桥 IP**:
```bash
# 查看 Docker 网络
docker network inspect familyai_familyai | grep Gateway

# 通常是 172.28.0.1（根据你的配置）
```

2. **编辑 `.env`**:
```bash
PROXY_URL=http://172.28.0.1:2526
NO_PROXY=localhost,127.0.0.1,172.28.0.0/16
```

3. **确保代理监听网桥接口**:
```bash
# 代理需要监听 0.0.0.0 或 172.28.0.1
```

---

### 方法三：使用 host.docker.internal（需要额外配置）

**适用场景**: 想要跨平台兼容的配置

在 Linux 上，`host.docker.internal` 默认不可用，需要手动添加。

1. **修改 `docker-compose.yml`**:

为每个服务添加 `extra_hosts`:
```yaml
services:
  code-traditional:
    image: ...
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - HTTP_PROXY=http://host.docker.internal:2526
```

2. **或者编辑 `.env`**:
```bash
PROXY_URL=http://host.docker.internal:2526
```

**注意**: 这需要修改 `docker-compose.yml`，添加 `extra_hosts` 到所有服务。

---

### 方法四：代理服务运行在容器内

**适用场景**: 将代理也容器化

1. **创建代理容器**:

在 `docker-compose.yml` 中添加代理服务:
```yaml
services:
  proxy:
    image: your-proxy-image
    container_name: familyai-proxy
    ports:
      - "2526:2526"
    networks:
      - familyai
    restart: unless-stopped
```

2. **配置其他服务使用该代理**:
```bash
# .env
PROXY_URL=http://proxy:2526
```

---

## 🔧 特殊说明：模型下载容器

### docker-compose.download.yml 配置

模型下载容器使用 `network_mode: host`，这意味着：

- ✅ 容器共享宿主机网络栈
- ✅ 可以直接使用 `127.0.0.1:2526` 访问宿主机代理
- ✅ 不需要修改代理地址

**当前配置**:
```yaml
model-downloader:
  network_mode: host
  environment:
    - HTTP_PROXY=${PROXY_URL:-http://127.0.0.1:2526}
```

**如果使用方法一（宿主机 IP）**:

编辑 `.env`:
```bash
PROXY_URL=http://192.168.3.84:2526
```

下载容器会使用这个配置，但因为 `network_mode: host`，两种地址都能工作：
- `http://127.0.0.1:2526` ✅ (直接访问)
- `http://192.168.3.84:2526` ✅ (通过 IP 访问)

---

## ✅ 验证代理配置

### 1. 测试宿主机代理

```bash
# 在宿主机上测试
curl -x http://192.168.3.84:2526 -I https://huggingface.co
```

### 2. 测试容器内代理

**方法 A: 使用临时容器测试**:
```bash
# 加载环境变量
source .env

# 测试代理连接
docker run --rm \
  --network familyai_familyai \
  -e HTTP_PROXY=$PROXY_URL \
  -e HTTPS_PROXY=$PROXY_URL \
  curlimages/curl:latest \
  -I https://huggingface.co
```

**方法 B: 使用模型下载容器测试**:
```bash
# 尝试下载一个小模型测试
MODEL_NAME=openai/whisper-tiny \
  docker compose -f docker-compose.download.yml run --rm model-downloader
```

如果成功下载，说明代理配置正确。

### 3. 检查代理日志

在代理软件中查看是否有来自 Docker 容器的连接请求。

---

## 🚨 常见问题

### 问题 1: Connection refused

**错误信息**:
```
Failed to connect to 127.0.0.1 port 2526: Connection refused
```

**原因**: 容器无法访问宿主机代理

**解决方案**:
1. 使用宿主机 IP 替换 `127.0.0.1`
2. 确保代理监听 `0.0.0.0` 而不是 `127.0.0.1`
3. 检查防火墙是否阻止了连接

### 问题 2: No route to host

**错误信息**:
```
Failed to connect to 192.168.3.84 port 2526: No route to host
```

**原因**: 防火墙阻止了容器访问宿主机端口

**解决方案**:
```bash
# 允许 Docker 网络访问代理端口
sudo ufw allow from 172.28.0.0/16 to any port 2526

# 或临时关闭防火墙测试
sudo ufw disable
```

### 问题 3: Proxy authentication required

**错误信息**:
```
407 Proxy Authentication Required
```

**原因**: 代理需要认证

**解决方案**:
```bash
# .env
PROXY_URL=http://username:password@192.168.3.84:2526
```

### 问题 4: 只有部分服务能访问代理

**原因**:
- 模型下载容器使用 `host` 网络模式
- 运行服务容器使用 `bridge` 网络模式

**解决方案**:
- 模型下载: 可以使用 `127.0.0.1` 或宿主机 IP
- 运行服务: 必须使用宿主机 IP

---

## 📝 推荐配置（Jetson Thor）

假设:
- 宿主机 IP: `192.168.3.84`
- 代理端口: `2526`
- 代理运行在宿主机上

### 步骤 1: 配置代理监听所有接口

```bash
# 确保代理配置监听 0.0.0.0:2526
```

### 步骤 2: 配置防火墙

```bash
# 允许 Docker 容器访问代理
sudo ufw allow from 172.16.0.0/12 to any port 2526
```

### 步骤 3: 编辑 .env

```bash
# 复制模板
cp .env.example .env

# 编辑配置
nano .env
```

设置:
```bash
# 宿主机配置
JETSON_THOR_IP=192.168.3.84

# 代理配置 - 使用宿主机 IP
PROXY_URL=http://192.168.3.84:2526
NO_PROXY=localhost,127.0.0.1,172.28.0.0/16,192.168.3.84

# 其他配置...
```

### 步骤 4: 测试配置

```bash
# 测试代理
source .env
docker run --rm \
  --network familyai_familyai \
  -e HTTP_PROXY=$PROXY_URL \
  curlimages/curl:latest \
  -I https://huggingface.co

# 应该返回 HTTP 200 OK
```

### 步骤 5: 下载模型

```bash
# 使用配置的代理下载模型
./scripts/02-pull-models.sh --batch
```

---

## 🔍 调试技巧

### 查看容器网络

```bash
# 查看容器的网络配置
docker compose exec code-traditional ip addr
docker compose exec code-traditional cat /etc/resolv.conf

# 测试从容器访问宿主机
docker compose exec code-traditional ping 192.168.3.84

# 测试从容器访问代理端口
docker compose exec code-traditional curl -v telnet://192.168.3.84:2526
```

### 查看代理使用情况

```bash
# 查看环境变量
docker compose exec code-traditional env | grep -i proxy

# 测试代理连接
docker compose exec code-traditional curl -x $PROXY_URL -I https://google.com
```

### 抓包分析

```bash
# 在宿主机上监听代理端口
sudo tcpdump -i any port 2526 -nn

# 然后在另一个终端尝试下载模型
# 观察是否有连接请求
```

---

## 📞 需要帮助？

如果代理配置仍有问题，请提供以下信息：

1. 宿主机 IP: `ip addr show`
2. 代理配置: `netstat -tlnp | grep 2526`
3. Docker 网络: `docker network inspect familyai_familyai`
4. 测试结果: 上述验证命令的输出
5. 错误日志: `docker compose logs`

---

## 📚 参考资料

- [Docker 网络文档](https://docs.docker.com/network/)
- [Docker Compose 网络配置](https://docs.docker.com/compose/networking/)
- [HuggingFace Hub 代理配置](https://huggingface.co/docs/huggingface_hub/guides/manage-cache)

---

**配置正确的代理是成功部署的关键！** 🚀
