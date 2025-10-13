# 代理配置快速指南

**⚠️ 重要提示**: 如果你的代理服务运行在宿主机（Jetson Thor）上，请务必正确配置！

---

## 🎯 核心问题

你的宿主机 IP 是 `192.168.3.84`，代理端口是 `2526`。

**错误配置** ❌:
```bash
PROXY_URL=http://127.0.0.1:2526
```

**正确配置** ✅:
```bash
PROXY_URL=http://192.168.3.84:2526
```

**为什么？**
- 在 Docker 容器内，`127.0.0.1` 指向容器自己，不是宿主机
- 容器需要使用宿主机的实际 IP 地址来访问宿主机上的服务

---

## ⚡ 快速配置（3 步）

### 第 1 步：运行配置向导

```bash
cd FamilyAI
./scripts/configure-proxy.sh
```

这个脚本会：
- ✅ 自动检测宿主机 IP
- ✅ 扫描代理服务端口
- ✅ 测试代理连接
- ✅ 更新 .env 配置
- ✅ 验证容器能否访问代理

### 第 2 步：确保代理监听正确接口

检查代理是否监听 `0.0.0.0`:

```bash
netstat -tlnp | grep 2526
```

**期望输出**:
```
tcp  0.0.0.0:2526  0.0.0.0:*  LISTEN
```

**错误输出** (需要修改):
```
tcp  127.0.0.1:2526  0.0.0.0:*  LISTEN
```

### 第 3 步：配置防火墙

允许 Docker 容器访问代理：

```bash
sudo ufw allow from 172.16.0.0/12 to any port 2526
```

---

## 📝 手动配置

如果不想使用配置向导：

### 1. 编辑 .env 文件

```bash
nano .env
```

修改以下内容：

```bash
# 代理配置 - 使用宿主机 IP
PROXY_URL=http://192.168.3.84:2526

# No Proxy 例外 - 添加宿主机 IP
NO_PROXY=localhost,127.0.0.1,172.28.0.0/16,192.168.3.84
```

### 2. 测试代理

```bash
# 从宿主机测试
curl -x http://192.168.3.84:2526 https://www.google.com

# 测试容器访问（如果 Docker 已安装）
docker run --rm \
  -e HTTP_PROXY=http://192.168.3.84:2526 \
  curlimages/curl:latest \
  -x http://192.168.3.84:2526 -I https://www.google.com
```

---

## 🔧 代理软件配置

### Clash

编辑 `~/.config/clash/config.yaml`:

```yaml
mixed-port: 2526
bind-address: 0.0.0.0  # 改为 0.0.0.0，不要用 127.0.0.1
```

重启 Clash:
```bash
systemctl --user restart clash
```

### V2Ray

编辑 `/etc/v2ray/config.json`:

```json
{
  "inbounds": [{
    "port": 2526,
    "listen": "0.0.0.0",  // 改为 0.0.0.0
    "protocol": "socks"
  }]
}
```

重启 V2Ray:
```bash
sudo systemctl restart v2ray
```

### Qv2ray / Clash for Windows / 其他图形化工具

在设置中找到"允许来自局域网的连接"或类似选项并启用。

---

## ✅ 验证配置

运行以下命令验证配置是否正确：

```bash
# 1. 检查 .env 配置
grep PROXY_URL .env
# 应显示: PROXY_URL=http://192.168.3.84:2526

# 2. 检查代理监听
netstat -tlnp | grep 2526
# 应显示: 0.0.0.0:2526

# 3. 测试代理连接
curl -x http://192.168.3.84:2526 -I https://huggingface.co
# 应返回 HTTP 200 OK

# 4. 测试容器访问（完整测试）
docker run --rm \
  --network bridge \
  -e HTTP_PROXY=http://192.168.3.84:2526 \
  curlimages/curl:latest \
  -x http://192.168.3.84:2526 -I https://google.com
# 应返回 HTTP 200 OK
```

---

## 🚀 开始下载模型

配置完成后，开始下载模型：

```bash
# 批量下载所有模型（推荐）
./scripts/02-pull-models.sh --batch

# 或下载单个模型测试
./scripts/02-pull-models.sh --model chat-light
```

**预期行为**:
- 容器启动，显示代理配置
- 通过代理连接 HuggingFace
- 开始下载模型文件

---

## 🆘 常见问题

### Q: 为什么不能用 127.0.0.1？

**A**: 在 Docker 容器内：
- `127.0.0.1` = 容器自己
- `192.168.3.84` = 宿主机（Jetson Thor）

容器需要访问宿主机的代理，所以必须使用宿主机 IP。

### Q: docker-compose.download.yml 为什么用 127.0.0.1 可以？

**A**: 因为模型下载容器使用了 `network_mode: host`，共享宿主机网络栈：
- 容器和宿主机使用相同的网络接口
- `127.0.0.1` 在容器内指向宿主机
- 但为了一致性，建议统一使用宿主机 IP

### Q: 代理配置正确但还是连不上？

**A**: 检查以下几点：
1. 代理是否在运行: `netstat -tlnp | grep 2526`
2. 代理监听接口: 应该是 `0.0.0.0` 不是 `127.0.0.1`
3. 防火墙: `sudo ufw allow from 172.16.0.0/12 to any port 2526`
4. 代理本身能否访问外网: `curl -x http://192.168.3.84:2526 https://google.com`

### Q: 可以把代理也放在 Docker 里吗？

**A**: 可以！如果代理运行在 Docker 容器内：
```bash
PROXY_URL=http://proxy-container-name:2526
```

但需要确保代理容器和其他容器在同一个 Docker 网络中。

---

## 📚 详细文档

- [完整代理配置指南](docs/proxy-configuration.md) - 所有配置方法详解
- [Jetson Thor 部署指南](docs/jetson-thor-deployment.md) - 完整部署流程
- [快速参考](docs/quick-reference.md) - 常用命令

---

## 🔗 相关文件

```
FamilyAI/
├── .env                              # 主配置文件（修改这里）
├── docker-compose.yml                # 服务配置（代理通过环境变量传递）
├── docker-compose.download.yml       # 模型下载配置
├── scripts/
│   ├── configure-proxy.sh           # 代理配置向导 ⭐
│   ├── 00-jetson-setup.sh           # 自动环境配置
│   └── 02-pull-models.sh            # 模型下载
└── docs/
    └── proxy-configuration.md        # 详细代理文档
```

---

**配置好代理，下载模型更流畅！** 🚀

有问题？运行 `./scripts/configure-proxy.sh` 或查看 [docs/proxy-configuration.md](docs/proxy-configuration.md)
