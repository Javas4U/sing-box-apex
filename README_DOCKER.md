# 🐳 sing-box Docker 部署快速指南

## 📦 已创建的文件

```
✓ docker-compose.yml          # Docker Compose 配置
✓ Dockerfile.production        # 生产级 Dockerfile
✓ deploy.sh                    # 一键部署脚本(可交互)
✓ test-deployment.sh           # 部署前测试脚本
✓ DOCKER_DEPLOY.md            # 详细部署文档
✓ config/config.json          # 基础配置(VMess+Trojan)
✓ config/config-with-api.json # 带 Web API 的配置
✓ config/logrotate.conf       # 日志轮转配置
```

---

## 🚀 三步快速部署

### 第一步: 测试环境

```bash
./test-deployment.sh
```

这会检查:
- ✓ Docker 是否安装
- ✓ 端口是否可用
- ✓ 配置文件语法
- ✓ 磁盘空间
- ✓ 网络连接

### 第二步: 修改配置

```bash
vim config/config.json
```

**必须修改的部分:**

```json
{
  "inbounds": [
    {
      "type": "vmess",
      "users": [
        {
          "uuid": "替换为你的UUID"  // ← 改这里!
        }
      ]
    },
    {
      "type": "trojan",
      "users": [
        {
          "password": "替换为强密码"  // ← 改这里!
        }
      ],
      "tls": {
        "server_name": "your-domain.com",  // ← 改这里!
        "certificate_path": "/etc/sing-box/cert.pem",
        "key_path": "/etc/sing-box/key.pem"
      }
    }
  ]
}
```

**生成 UUID:**
```bash
# Linux/Mac
uuidgen

# 或者在线生成
# https://www.uuidgenerator.net/
```

### 第三步: 一键部署

```bash
./deploy.sh init
```

完成!服务已启动 🎉

---

## 📊 日志持久化 - 三种方案

### 方案 1: 文件日志(已配置,推荐)

**配置:**
```json
{
  "log": {
    "output": "/var/log/sing-box/sing-box.log"
  }
}
```

**日志位置:**
- 容器内: `/var/log/sing-box/sing-box.log`
- 宿主机: `./logs/sing-box.log`

**查看日志:**
```bash
# 实时查看
tail -f logs/sing-box.log

# 搜索错误
grep -i error logs/sing-box.log

# 最近 100 行
tail -n 100 logs/sing-box.log
```

### 方案 2: Docker 日志(备选)

**配置在 docker-compose.yml:**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"   # 单文件最大 10MB
    max-file: "3"     # 保留 3 个文件
```

**查看日志:**
```bash
docker-compose logs -f          # 实时
docker-compose logs --tail=100  # 最近 100 行
```

### 方案 3: 日志轮转(生产环境)

**安装 logrotate:**
```bash
sudo apt-get install logrotate

# 复制配置
sudo cp config/logrotate.conf /etc/logrotate.d/sing-box

# 编辑路径
sudo vim /etc/logrotate.d/sing-box
# 修改: /path/to/sing-box/logs/*.log
# 改为: /home/user/sing-box/logs/*.log

# 测试
sudo logrotate -f /etc/logrotate.d/sing-box
```

**效果:**
- 每天自动轮转日志
- 保留 30 天历史
- 自动压缩旧日志
- 清理过期文件

---

## 🔧 常用运维命令

### 服务管理

```bash
# 使用交互式菜单
./deploy.sh

# 或直接使用 docker-compose
docker-compose start    # 启动
docker-compose stop     # 停止
docker-compose restart  # 重启
docker-compose ps       # 查看状态
```

### 日志查看

```bash
# 方式1: 查看文件日志
tail -f logs/sing-box.log

# 方式2: 查看 Docker 日志
docker-compose logs -f

# 方式3: 使用脚本
./deploy.sh  # 选择 "5. 查看日志"
```

### 配置重载

```bash
# 编辑配置
vim config/config.json

# 重启服务
docker-compose restart

# 或使用信号(无需断开连接)
docker exec sing-box-server killall -SIGHUP sing-box
```

### 备份还原

```bash
# 备份
./deploy.sh  # 选择 "8. 备份配置"

# 手动备份
tar -czf backup-$(date +%Y%m%d).tar.gz config/ data/

# 还原
tar -xzf backup-20241219.tar.gz
docker-compose restart
```

---

## 🌐 VPS 部署流程

### 1. 连接到 VPS

```bash
ssh root@your-vps-ip
```

### 2. 安装 Docker

```bash
# 一键安装 Docker
curl -fsSL https://get.docker.com | sh

# 启动 Docker
systemctl start docker
systemctl enable docker

# 安装 Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

### 3. 上传项目文件

**方法1: 使用 Git(推荐)**
```bash
# 克隆仓库
git clone https://github.com/sagernet/sing-box.git
cd sing-box

# 复制我创建的配置文件到项目目录
# (docker-compose.yml, deploy.sh, config/* 等)
```

**方法2: 使用 SCP**
```bash
# 在本地执行
cd /Users/hunter/myIterm/sing-box
tar -czf sing-box-deploy.tar.gz \
  docker-compose.yml \
  Dockerfile.production \
  deploy.sh \
  test-deployment.sh \
  config/

# 上传到 VPS
scp sing-box-deploy.tar.gz root@your-vps-ip:/root/

# 在 VPS 上解压
ssh root@your-vps-ip
tar -xzf sing-box-deploy.tar.gz
```

**方法3: 直接复制内容**
```bash
# 在 VPS 上创建文件
mkdir -p sing-box/config
cd sing-box

# 创建 docker-compose.yml
vim docker-compose.yml
# (粘贴内容)

# 创建配置文件
vim config/config.json
# (粘贴内容)
```

### 4. 配置防火墙

```bash
# UFW (Ubuntu/Debian)
ufw allow 1080/tcp    # SOCKS/HTTP
ufw allow 8388/tcp    # VMess
ufw allow 443/tcp     # Trojan
ufw allow 9090/tcp    # API(可选)
ufw enable

# Firewalld (CentOS/RHEL)
firewall-cmd --permanent --add-port=1080/tcp
firewall-cmd --permanent --add-port=8388/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=9090/tcp
firewall-cmd --reload
```

### 5. 启动服务

```bash
# 修改配置
vim config/config.json

# 运行测试
./test-deployment.sh

# 一键部署
chmod +x deploy.sh
./deploy.sh init

# 查看日志
./deploy.sh logs
```

### 6. 验证部署

```bash
# 检查容器状态
docker ps

# 检查端口监听
netstat -tuln | grep -E '1080|8388|443'

# 测试连接(在本地)
curl -x socks5://your-vps-ip:1080 https://www.google.com
```

---

## 🔍 故障排查

### 问题 1: 容器启动失败

```bash
# 查看详细日志
docker-compose logs sing-box

# 检查配置文件
cat config/config.json | python3 -m json.tool

# 手动验证配置
docker run --rm -v $(pwd)/config:/etc/sing-box \
  sing-box:latest check -c /etc/sing-box/config.json
```

### 问题 2: 端口被占用

```bash
# 查看占用端口的进程
lsof -i :1080
netstat -tuln | grep 1080

# 停止占用进程
kill -9 <PID>

# 或修改配置使用其他端口
vim config/config.json
```

### 问题 3: 无法访问日志

```bash
# 检查目录权限
ls -la logs/
chmod 755 logs/

# 检查容器内权限
docker exec sing-box-server ls -la /var/log/sing-box/

# 手动创建日志文件
touch logs/sing-box.log
chmod 644 logs/sing-box.log
```

### 问题 4: 连接失败

```bash
# 测试端口连通性
telnet your-vps-ip 1080
nc -zv your-vps-ip 1080

# 检查防火墙
sudo ufw status
sudo iptables -L -n

# 查看容器网络
docker network ls
docker network inspect bridge
```

---

## 📈 性能优化建议

### 1. 调整日志级别

**开发环境:**
```json
{"log": {"level": "debug"}}
```

**生产环境:**
```json
{"log": {"level": "info"}}  // 或 "warn"
```

### 2. 启用缓存

```json
{
  "experimental": {
    "cache_file": {
      "enabled": true,
      "path": "/var/lib/sing-box/cache.db"
    }
  }
}
```

### 3. 限制资源使用

在 docker-compose.yml 中:
```yaml
services:
  sing-box:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
```

### 4. 使用 host 网络模式

```yaml
network_mode: host  # 已配置,性能最佳
```

---

## 📊 监控面板

### 启用 Clash API

1. 使用带 API 的配置:
```bash
cp config/config-with-api.json config/config.json
vim config/config.json  # 修改 secret
docker-compose restart
```

2. 访问 Web UI:
```
http://your-vps-ip:9090/ui
```

3. 输入密钥:
```
在配置中设置的 secret 值
```

**功能:**
- 📊 实时流量统计
- 🔗 连接列表
- 📈 速度图表
- ⚙️ 规则管理
- 🔄 配置热重载

---

## 🔐 安全建议

1. **修改默认密码**
   - VMess UUID
   - Trojan 密码
   - API Secret

2. **启用 TLS**
   ```bash
   # 申请证书
   certbot certonly --standalone -d your-domain.com
   ```

3. **限制访问 IP**
   ```json
   {
     "inbounds": [{
       "listen": "your-specific-ip"  // 不要用 0.0.0.0
     }]
   }
   ```

4. **定期更新**
   ```bash
   git pull
   docker-compose build
   docker-compose up -d
   ```

---

## 📚 参考资料

- **详细文档**: [DOCKER_DEPLOY.md](DOCKER_DEPLOY.md)
- **官方文档**: https://sing-box.sagernet.org
- **GitHub**: https://github.com/sagernet/sing-box
- **配置示例**: https://sing-box.sagernet.org/configuration/

---

## 💬 获取帮助

如有问题:
1. 查看 [DOCKER_DEPLOY.md](DOCKER_DEPLOY.md) 详细文档
2. 运行 `./deploy.sh` 使用交互式菜单
3. 查看 GitHub Issues
4. 加入 Telegram 群组: @SagerNet

---

## ⚖️ 法律声明

- 本项目遵循 GPLv3 开源协议
- 仅供学习研究和合法用途
- 请遵守当地法律法规

---

**祝部署顺利! 🎉**
