#!/bin/bash

# ====================================
# sing-box Docker 部署测试脚本
# ====================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}======================================"
echo "sing-box Docker 部署测试"
echo -e "======================================${NC}"
echo ""

# 1. 检查 Docker
echo -e "${YELLOW}[1/8]${NC} 检查 Docker..."
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker 已安装: $(docker --version)"
else
    echo -e "${RED}✗${NC} Docker 未安装"
    exit 1
fi

# 2. 检查 Docker Compose
echo -e "${YELLOW}[2/8]${NC} 检查 Docker Compose..."
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker Compose 已安装"
else
    echo -e "${RED}✗${NC} Docker Compose 未安装"
    exit 1
fi

# 3. 检查配置文件
echo -e "${YELLOW}[3/8]${NC} 检查配置文件..."
if [ -f "config/config.json" ]; then
    echo -e "${GREEN}✓${NC} 配置文件存在"
else
    echo -e "${YELLOW}!${NC} 配置文件不存在,将创建示例配置"
    mkdir -p config
fi

# 4. 检查 Dockerfile
echo -e "${YELLOW}[4/8]${NC} 检查 Dockerfile..."
if [ -f "Dockerfile" ] || [ -f "Dockerfile.production" ]; then
    echo -e "${GREEN}✓${NC} Dockerfile 存在"
else
    echo -e "${RED}✗${NC} Dockerfile 不存在"
    exit 1
fi

# 5. 测试配置文件语法
echo -e "${YELLOW}[5/8]${NC} 测试配置文件语法..."
if [ -f "config/config.json" ]; then
    if python3 -m json.tool config/config.json > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} 配置文件语法正确"
    else
        echo -e "${RED}✗${NC} 配置文件语法错误"
        exit 1
    fi
else
    echo -e "${YELLOW}!${NC} 跳过配置文件检查"
fi

# 6. 检查端口占用
echo -e "${YELLOW}[6/8]${NC} 检查端口占用..."
PORTS=(1080 8388 443 9090)
for port in "${PORTS[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep ":$port " > /dev/null; then
        echo -e "${YELLOW}!${NC} 端口 $port 已被占用"
    else
        echo -e "${GREEN}✓${NC} 端口 $port 可用"
    fi
done

# 7. 检查磁盘空间
echo -e "${YELLOW}[7/8]${NC} 检查磁盘空间..."
AVAILABLE=$(df . | tail -1 | awk '{print $4}')
if [ "$AVAILABLE" -gt 1048576 ]; then  # 1GB
    echo -e "${GREEN}✓${NC} 磁盘空间充足 ($(($AVAILABLE/1024/1024))GB 可用)"
else
    echo -e "${YELLOW}!${NC} 磁盘空间不足 ($(($AVAILABLE/1024))MB 可用)"
fi

# 8. 检查网络
echo -e "${YELLOW}[8/8]${NC} 检查网络连接..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✓${NC} 网络连接正常"
else
    echo -e "${YELLOW}!${NC} 网络连接异常"
fi

echo ""
echo -e "${GREEN}======================================"
echo "测试完成!"
echo -e "======================================${NC}"
echo ""

# 显示部署建议
echo -e "${GREEN}建议的部署步骤:${NC}"
echo "1. 编辑配置文件: vim config/config.json"
echo "2. 初始化部署: ./deploy.sh init"
echo "3. 查看日志: ./deploy.sh logs"
echo "4. 访问 API: http://localhost:9090/ui"
echo ""

# 询问是否继续部署
read -p "是否现在开始部署? (y/N): " choice
case "$choice" in
  y|Y )
    echo "开始部署..."
    ./deploy.sh init
    ;;
  * )
    echo "已取消部署"
    ;;
esac
