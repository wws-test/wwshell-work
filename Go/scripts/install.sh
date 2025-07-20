#!/bin/bash

# Command Monitor 安装脚本
# 用法: sudo ./install.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SERVICE_NAME="cmdmonitor"
BINARY_NAME="cmdmonitor"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/${SERVICE_NAME}"
DATA_DIR="/var/lib/${SERVICE_NAME}"
LOG_DIR="/var/log"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
WATCHER_SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}-watcher.service"
WATCHER_SCRIPT="config-watcher.sh"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查systemd
    if ! command -v systemctl &> /dev/null; then
        log_error "系统不支持systemd"
        exit 1
    fi
    
    # 检查二进制文件是否存在
    if [[ ! -f "build/${BINARY_NAME}-linux-amd64" ]]; then
        log_error "找不到编译后的二进制文件: build/${BINARY_NAME}-linux-amd64"
        log_info "请先运行: make build-linux"
        exit 1
    fi
    
    log_success "系统要求检查通过"
}

# 停止现有服务
stop_existing_service() {
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log_info "停止现有服务..."
        systemctl stop ${SERVICE_NAME}
        log_success "服务已停止"
    fi
}

# 创建用户和目录
create_user_and_dirs() {
    log_info "创建用户和目录..."
    
    # 创建系统用户（如果不存在）
    if ! id "${SERVICE_NAME}" &>/dev/null; then
        useradd -r -s /bin/false -d ${DATA_DIR} ${SERVICE_NAME}
        log_success "创建系统用户: ${SERVICE_NAME}"
    else
        log_info "用户 ${SERVICE_NAME} 已存在"
    fi
    
    # 创建目录
    mkdir -p ${CONFIG_DIR}
    mkdir -p ${DATA_DIR}
    mkdir -p ${LOG_DIR}
    
    # 设置目录权限
    chown -R ${SERVICE_NAME}:${SERVICE_NAME} ${DATA_DIR}
    chown -R ${SERVICE_NAME}:${SERVICE_NAME} ${CONFIG_DIR}
    chmod 755 ${CONFIG_DIR}
    chmod 755 ${DATA_DIR}
    
    log_success "目录创建完成"
}

# 安装二进制文件
install_binary() {
    log_info "安装二进制文件..."
    
    # 复制二进制文件
    cp "build/${BINARY_NAME}-linux-amd64" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
    chown root:root "${INSTALL_DIR}/${BINARY_NAME}"
    
    log_success "二进制文件安装完成: ${INSTALL_DIR}/${BINARY_NAME}"
}

# 安装配置文件
install_config() {
    log_info "安装配置文件..."
    
    # 复制配置文件（如果不存在）
    if [[ ! -f "${CONFIG_DIR}/config.env" ]]; then
        cp "configs/config.env.example" "${CONFIG_DIR}/config.env"
        chown ${SERVICE_NAME}:${SERVICE_NAME} "${CONFIG_DIR}/config.env"
        chmod 600 "${CONFIG_DIR}/config.env"
        log_success "配置文件已创建: ${CONFIG_DIR}/config.env"
        log_warning "请编辑配置文件并设置WECHAT_WEBHOOK_URL"
    else
        log_info "配置文件已存在，跳过创建"
    fi
}

# 安装systemd服务
install_service() {
    log_info "安装systemd服务..."
    
    # 复制服务文件
    cp "configs/${SERVICE_NAME}.service" "${SERVICE_FILE}"
    
    # 重新加载systemd
    systemctl daemon-reload
    
    log_success "systemd服务安装完成"
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    # 启用服务
    systemctl enable ${SERVICE_NAME}
    
    # 启动服务
    systemctl start ${SERVICE_NAME}
    
    # 检查服务状态
    sleep 2
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        log_info "查看日志: journalctl -u ${SERVICE_NAME} -f"
        exit 1
    fi
}

# 安装配置监控功能
install_config_watcher() {
    log_info "安装配置监控功能..."

    # 检查是否安装了 inotify-tools
    if ! command -v inotifywait &> /dev/null; then
        log_info "安装 inotify-tools..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y inotify-tools
        elif command -v yum &> /dev/null; then
            yum install -y inotify-tools
        elif command -v dnf &> /dev/null; then
            dnf install -y inotify-tools
        else
            log_warning "无法自动安装 inotify-tools，请手动安装"
            return
        fi
    fi

    # 复制配置监控脚本
    if [[ -f "scripts/${WATCHER_SCRIPT}" ]]; then
        cp "scripts/${WATCHER_SCRIPT}" "${INSTALL_DIR}/${WATCHER_SCRIPT}"
        chmod +x "${INSTALL_DIR}/${WATCHER_SCRIPT}"
        log_success "配置监控脚本已安装"
    else
        log_warning "配置监控脚本不存在，跳过安装"
        return
    fi

    # 安装配置监控服务
    if [[ -f "configs/${SERVICE_NAME}-watcher.service" ]]; then
        cp "configs/${SERVICE_NAME}-watcher.service" "${WATCHER_SERVICE_FILE}"
        log_success "配置监控服务文件已安装"
    else
        log_warning "配置监控服务文件不存在，跳过安装"
        return
    fi

    # 启用配置监控服务
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME}-watcher
    systemctl start ${SERVICE_NAME}-watcher

    if systemctl is-active --quiet ${SERVICE_NAME}-watcher; then
        log_success "配置监控服务启动成功"
    else
        log_warning "配置监控服务启动失败"
    fi
}

# 显示安装后信息
show_post_install_info() {
    echo
    log_success "=== Command Monitor 安装完成 ==="
    echo
    echo "服务状态:"
    systemctl status ${SERVICE_NAME} --no-pager -l
    echo
    echo "常用命令:"
    echo "  启动服务: sudo systemctl start ${SERVICE_NAME}"
    echo "  停止服务: sudo systemctl stop ${SERVICE_NAME}"
    echo "  重启服务: sudo systemctl restart ${SERVICE_NAME}"
    echo "  查看状态: sudo systemctl status ${SERVICE_NAME}"
    echo "  查看日志: sudo journalctl -u ${SERVICE_NAME} -f"
    echo
    echo "配置文件: ${CONFIG_DIR}/config.env"
    echo "数据目录: ${DATA_DIR}"
    echo "日志文件: ${LOG_DIR}/cmdmonitor.log"
    echo
    log_warning "重要: 请编辑 ${CONFIG_DIR}/config.env 并设置正确的微信Webhook URL"
    log_info "编辑完成后重启服务: sudo systemctl restart ${SERVICE_NAME}"
}

# 主函数
main() {
    echo "=== Command Monitor 安装程序 ==="
    echo

    check_root
    check_requirements
    stop_existing_service
    create_user_and_dirs
    install_binary
    install_config
    install_service
    start_service
    install_config_watcher
    show_post_install_info

    echo
    log_success "安装完成！"
}

# 运行主函数
main "$@"
