# sing-box Docker 部署完整指南

## 📋 目录结构

```
sing-box/
├── Dockerfile                    # 官方 Dockerfile
├── Dockerfile.production         # 生产级 Dockerfile
├── docker-compose.yml           # Docker Compose 配置
├── deploy.sh                    # 一键部署脚本
├── config/
│   ├── config.json             # 基础配置
│   ├── config-with-api.json    # 带 API 的配置
│   └── logrotate.conf          # 日志轮转配置
├── logs/                        # 日志目录(挂载)
│   └── sing-box.log
├── data/                        # 数据目录(挂载)
│   └── cache.db
└── backups/                     # 备份目录
```

---

## 🚀 快速开始

### 方法1: 使用一键部署脚本(推荐)

```bash
# 1. 赋予执行权限
chmod +x deploy.sh

# 2. 初始化部署
./deploy.sh init

# 3. 查看日志
./deploy.sh logs
```

### 方法2: 使用 Docker Compose

```bash
# 1. 创建目录
mkdir -p config logs data

# 2. 编辑配置文件
vim config/config.json

# 3. 构建并启动
docker-compose up -d

# 4. 查看日志
docker-compose logs -f
```

### 方法3: 手动 Docker 命令

```bash
# 1. 构建镜像
docker build -f Dockerfile.production -t sing-box:latest .

# 2. 运行容器
docker run -d \
  --name sing-box-server \
  --restart unless-stopped \
  --network host \
  --cap-add NET_ADMIN \
  -v $(pwd)/config:/etc/sing-box:ro \
  -v $(pwd)/logs:/var/log/sing-box \
  -v $(pwd)/data:/var/lib/sing-box \
  -e TZ=Asia/Shanghai \
  sing-box:latest \
  run -c /etc/sing-box/config.json

# 3. 查看日志
docker logs -f sing-box-server
```

---

## 📝 配置文件详解

### 日志配置关键参数

```json
{
  "log": {
    "disabled": false,              // 是否禁用日志
    "level": "info",                // 日志级别: trace, debug, info, warn, error, fatal, panic
    "output": "/var/log/sing-box/sing-box.log",  // 日志输出路径
    "timestamp": true               // 是否显示时间戳
  }
}
```

### 日志级别说明

| 级别 | 说明 | 适用场景 |
|------|------|---------|
| `trace` | 最详细 | 调试协议细节 |
| `debug` | 调试信息 | 开发调试 |
| `info` | 常规信息 | **生产环境推荐** |
| `warn` | 警告信息 | 生产环境 |
| `error` | 错误信息 | 最小日志 |
| `fatal` | 致命错误 | 仅记录崩溃 |
| `panic` | 严重错误 | 仅记录严重问题 |

---

## 🗂️ 日志持久化方案

### 方案1: Docker Volume 挂载(推荐)

**在 docker-compose.yml 中:**
```yaml
volumes:
  - ./logs:/var/log/sing-box  # 挂载到宿主机
```

**日志文件位置:**
```bash
# 宿主机
./logs/sing-box.log

# 容器内
/var/log/sing-box/sing-box.log
```

### 方案2: 使用 Docker 日志驱动

**在 docker-compose.yml 中:**
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"      # 单个日志文件最大 10MB
    max-file: "3"        # 保留 3 个日志文件
```

**查看日志:**
```bash
# 查看最新 100 行
docker-compose logs --tail=100

# 实时查看
docker-compose logs -f

# 导出日志
docker-compose logs > sing-box-$(date +%Y%m%d).log
```

### 方案3: 日志轮转(Logrotate)

**1. 在宿主机安装 logrotate:**
```bash
# Ubuntu/Debian
sudo apt-get install logrotate

# CentOS/RHEL
sudo yum install logrotate
```

**2. 配置 logrotate:**
```bash
sudo cp config/logrotate.conf /etc/logrotate.d/sing-box
sudo chmod 644 /etc/logrotate.d/sing-box

# 编辑配置,修改路径
sudo vim /etc/logrotate.d/sing-box
```

**3. 手动测试:**
```bash
sudo logrotate -f /etc/logrotate.d/sing-box
```

### 方案4: 集中式日志(高级)

**使用 ELK Stack / Grafana Loki:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  sing-box:
    # ... 省略其他配置
    logging:
      driver: "loki"
      options:
        loki-url: "http://localhost:3100/loki/api/v1/push"
        loki-retries: 5
        loki-batch-size: 400

  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
```

---

## 📊 日志监控与分析

### 1. 实时监控日志

```bash
# 查看最新日志
tail -f logs/sing-box.log

# 搜索错误
grep -i "error" logs/sing-box.log

# 统计连接数
grep "connection established" logs/sing-box.log | wc -l

# 按时间查看
grep "2024-12-19 10:" logs/sing-box.log
```

### 2. 使用 Clash API 监控

**启用 Clash API:**
使用 `config-with-api.json` 配置文件

**访问 Web UI:**
```bash
# 浏览器打开
http://your-vps-ip:9090/ui

# 使用 API
curl -H "Authorization: Bearer your-secret-key-here" \
  http://localhost:9090/traffic
```

### 3. 监控脚本

**创建监控脚本 `monitor.sh`:**
```bash
#!/bin/bash

while true; do
    clear
    echo "===== sing-box 实时监控 ====="
    echo ""

    # 容器状态
    echo "📦 容器状态:"
    docker ps --filter name=sing-box-server --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""

    # 资源使用
    echo "💻 资源使用:"
    docker stats --no-stream sing-box-server --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    echo ""

    # 最新日志
    echo "📄 最新日志:"
    tail -n 10 logs/sing-box.log
    echo ""

    # 连接统计
    echo "🔗 今日连接数:"
    grep "$(date +%Y-%m-%d)" logs/sing-box.log | grep -c "connection"

    sleep 5
done
```

---

## 🔧 常用运维操作

### 启动/停止/重启

```bash
# 使用 deploy.sh
./deploy.sh              # 交互式菜单

# 使用 docker-compose
docker-compose start     # 启动
docker-compose stop      # 停止
docker-compose restart   # 重启
docker-compose down      # 停止并删除容器

# 使用 docker 命令
docker start sing-box-server
docker stop sing-box-server
docker restart sing-box-server
```

### 配置热重载

```bash
# 方法1: 发送信号
docker exec sing-box-server killall -SIGHUP sing-box

# 方法2: 使用 Clash API
curl -X PUT \
  -H "Authorization: Bearer your-secret-key-here" \
  http://localhost:9090/configs \
  -d @config/config.json

# 方法3: 重启容器
docker-compose restart
```

### 备份与恢复

```bash
# 备份
./deploy.sh  # 选择 "8. 备份配置"

# 手动备份
tar -czf sing-box-backup-$(date +%Y%m%d).tar.gz config/ data/

# 恢复
tar -xzf sing-box-backup-20241219.tar.gz
docker-compose restart
```

### 清理日志

```bash
# 使用脚本
./deploy.sh  # 选择 "9. 清理日志"

# 手动清理
find logs -name "*.log" -mtime +7 -delete  # 删除7天前的日志
truncate -s 0 logs/sing-box.log            # 清空当前日志
```

### 查看连接信息

```bash
# 查看所有连接
curl -H "Authorization: Bearer your-secret-key-here" \
  http://localhost:9090/connections

# 查看流量统计
curl -H "Authorization: Bearer your-secret-key-here" \
  http://localhost:9090/traffic
```

---

## 🐛 故障排查

### 1. 容器无法启动

```bash
# 查看错误日志
docker-compose logs sing-box

# 检查配置文件
docker run --rm -v $(pwd)/config:/etc/sing-box \
  sing-box:latest check -c /etc/sing-box/config.json

# 检查端口占用
netstat -tuln | grep -E '1080|8388|443'
```

### 2. 日志不输出

**检查配置:**
```json
{
  "log": {
    "disabled": false,  // 确保未禁用
    "output": "/var/log/sing-box/sing-box.log"  // 路径正确
  }
}
```

**检查权限:**
```bash
# 容器内
docker exec sing-box-server ls -la /var/log/sing-box/

# 宿主机
ls -la logs/
chmod 755 logs/
```

### 3. 连接失败

```bash
# 测试端口
telnet your-vps-ip 1080

# 查看防火墙
sudo ufw status
sudo firewall-cmd --list-all

# 查看容器网络
docker network inspect bridge
```

### 4. 性能问题

```bash
# 查看资源使用
docker stats sing-box-server

# 调整日志级别为 warn 或 error
# 减少日志输出量
```

---

## 🔒 安全加固

### 1. 使用非 root 用户

在 `Dockerfile.production` 中取消注释:
```dockerfile
RUN addgroup -g 1000 sing-box && \
    adduser -D -u 1000 -G sing-box sing-box
USER sing-box
```

### 2. 限制资源使用

```yaml
# docker-compose.yml
services:
  sing-box:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### 3. 启用 TLS 证书

```bash
# 使用 Let's Encrypt
docker run -it --rm \
  -v $(pwd)/config:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d your-domain.com \
  --email your-email@example.com \
  --agree-tos
```

### 4. 配置防火墙

```bash
# UFW
sudo ufw allow 443/tcp
sudo ufw allow 8388/tcp
sudo ufw enable

# Firewalld
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8388/tcp
sudo firewall-cmd --reload
```

---

## 📈 生产环境最佳实践

### 1. 监控告警

**使用 Prometheus + Alertmanager:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'sing-box'
    static_configs:
      - targets: ['sing-box-server:9090']
```

### 2. 自动重启

```yaml
# docker-compose.yml
services:
  sing-box:
    restart: unless-stopped  # 或 always
```

### 3. 健康检查

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:9090/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 5s
```

### 4. 定期备份

**创建 cron 任务:**
```bash
# 编辑 crontab
crontab -e

# 每天凌晨 2 点备份
0 2 * * * cd /path/to/sing-box && ./deploy.sh backup
```

---

## 🌐 VPS 部署完整流程

### 1. 准备 VPS

```bash
# 更新系统
sudo apt-get update && sudo apt-get upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 2. 上传代码

```bash
# 方法1: Git
git clone https://github.com/sagernet/sing-box.git
cd sing-box

# 方法2: SCP
scp -r sing-box/ user@vps-ip:/home/user/

# 方法3: 使用我创建的文件
# 确保已有 docker-compose.yml, deploy.sh 等文件
```

### 3. 配置并启动

```bash
# 修改配置
vim config/config.json

# 一键部署
chmod +x deploy.sh
./deploy.sh init
```

### 4. 验证部署

```bash
# 检查状态
docker ps
curl http://localhost:9090/health

# 测试连接
curl -x socks5://localhost:1080 https://www.google.com
```

---

## 📞 技术支持

- **官方文档**: https://sing-box.sagernet.org
- **GitHub**: https://github.com/sagernet/sing-box
- **Telegram**: @SagerNet

---

## ⚖️ 法律声明

本指南仅供技术学习和合法用途。请遵守当地法律法规,不得用于非法用途。

**GPLv3 许可协议**: 如需商业化使用,请遵守 GPLv3 开源协议。
