#!/bin/bash

# ====================================
# sing-box Docker 部署脚本
# ====================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装,请先安装 Docker"
        exit 1
    fi
    log_info "Docker 已安装: $(docker --version)"
}

# 检查 Docker Compose 是否安装
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装,请先安装"
        exit 1
    fi
    log_info "Docker Compose 已安装"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    mkdir -p config logs data
    chmod 755 config logs data
    log_info "目录创建完成"
}

# 生成配置文件
generate_config() {
    if [ ! -f "config/config.json" ]; then
        log_warn "配置文件不存在,将创建示例配置"
        # 配置文件已经通过 Write 工具创建
        if [ ! -f "config/config.json" ]; then
            log_error "请手动创建 config/config.json 配置文件"
            exit 1
        fi
    else
        log_info "配置文件已存在: config/config.json"
    fi
}

# 构建镜像
build_image() {
    log_info "开始构建 Docker 镜像..."
    docker build -f Dockerfile.production -t sing-box:latest .
    log_info "镜像构建完成"
}

# 启动服务
start_service() {
    log_info "启动 sing-box 服务..."
    docker-compose up -d
    log_info "服务启动完成"
}

# 查看日志
view_logs() {
    log_info "查看实时日志 (Ctrl+C 退出)..."
    docker-compose logs -f --tail=100
}

# 停止服务
stop_service() {
    log_info "停止 sing-box 服务..."
    docker-compose down
    log_info "服务已停止"
}

# 重启服务
restart_service() {
    log_info "重启 sing-box 服务..."
    docker-compose restart
    log_info "服务已重启"
}

# 查看服务状态
check_status() {
    log_info "服务状态:"
    docker-compose ps
    echo ""
    log_info "容器资源使用情况:"
    docker stats --no-stream $(docker-compose ps -q)
}

# 备份配置
backup_config() {
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    log_info "备份配置到 ${BACKUP_DIR}..."
    mkdir -p "${BACKUP_DIR}"
    cp -r config "${BACKUP_DIR}/"
    cp -r data "${BACKUP_DIR}/"
    log_info "备份完成"
}

# 清理日志
clean_logs() {
    log_warn "清理旧日志文件..."
    find logs -name "*.log" -mtime +7 -delete
    log_info "日志清理完成"
}

# 主菜单
show_menu() {
    echo ""
    echo "======================================"
    echo "   sing-box Docker 管理脚本"
    echo "======================================"
    echo "1. 初始化部署 (首次使用)"
    echo "2. 启动服务"
    echo "3. 停止服务"
    echo "4. 重启服务"
    echo "5. 查看日志"
    echo "6. 查看状态"
    echo "7. 重新构建镜像"
    echo "8. 备份配置"
    echo "9. 清理日志"
    echo "0. 退出"
    echo "======================================"
}

# 初始化部署
init_deploy() {
    log_info "开始初始化部署..."
    check_docker
    check_docker_compose
    create_directories
    generate_config
    build_image
    start_service
    log_info "初始化部署完成!"
    echo ""
    log_info "服务访问地址:"
    echo "  - SOCKS5/HTTP: 0.0.0.0:1080"
    echo "  - VMess: 0.0.0.0:8388"
    echo "  - Trojan: 0.0.0.0:443"
    echo ""
    log_info "日志文件位置: ./logs/sing-box.log"
    log_info "配置文件位置: ./config/config.json"
}

# 主程序
main() {
    if [ "$1" == "init" ]; then
        init_deploy
        exit 0
    fi

    if [ "$1" == "logs" ]; then
        view_logs
        exit 0
    fi

    while true; do
        show_menu
        read -p "请选择操作 [0-9]: " choice

        case $choice in
            1)
                init_deploy
                ;;
            2)
                start_service
                ;;
            3)
                stop_service
                ;;
            4)
                restart_service
                ;;
            5)
                view_logs
                ;;
            6)
                check_status
                ;;
            7)
                build_image
                ;;
            8)
                backup_config
                ;;
            9)
                clean_logs
                ;;
            0)
                log_info "退出脚本"
                exit 0
                ;;
            *)
                log_error "无效的选择,请重新输入"
                ;;
        esac

        echo ""
        read -p "按回车键继续..."
    done
}

# 执行主程序
main "$@"
