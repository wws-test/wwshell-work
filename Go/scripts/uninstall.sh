#!/bin/bash

# Command Monitor 卸载脚本
# 用法: sudo ./uninstall.sh

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
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

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

# 确认卸载
confirm_uninstall() {
    echo "=== Command Monitor 卸载程序 ==="
    echo
    log_warning "此操作将完全卸载 Command Monitor 服务"
    log_warning "包括服务、配置文件和数据文件"
    echo
    read -p "确定要继续吗？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        exit 0
    fi
}

# 停止并禁用服务
stop_and_disable_service() {
    log_info "停止并禁用服务..."
    
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        systemctl stop ${SERVICE_NAME}
        log_success "服务已停止"
    fi
    
    if systemctl is-enabled --quiet ${SERVICE_NAME}; then
        systemctl disable ${SERVICE_NAME}
        log_success "服务已禁用"
    fi
}

# 删除服务文件
remove_service_file() {
    log_info "删除服务文件..."
    
    if [[ -f ${SERVICE_FILE} ]]; then
        rm -f ${SERVICE_FILE}
        systemctl daemon-reload
        log_success "服务文件已删除"
    else
        log_info "服务文件不存在，跳过"
    fi
}

# 删除二进制文件
remove_binary() {
    log_info "删除二进制文件..."
    
    if [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
        rm -f "${INSTALL_DIR}/${BINARY_NAME}"
        log_success "二进制文件已删除"
    else
        log_info "二进制文件不存在，跳过"
    fi
}

# 删除配置和数据
remove_config_and_data() {
    log_info "删除配置和数据..."
    
    # 询问是否保留配置和数据
    echo
    read -p "是否保留配置文件和数据？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "保留配置和数据文件"
        log_info "配置目录: ${CONFIG_DIR}"
        log_info "数据目录: ${DATA_DIR}"
    else
        # 删除配置目录
        if [[ -d ${CONFIG_DIR} ]]; then
            rm -rf ${CONFIG_DIR}
            log_success "配置目录已删除: ${CONFIG_DIR}"
        fi
        
        # 删除数据目录
        if [[ -d ${DATA_DIR} ]]; then
            rm -rf ${DATA_DIR}
            log_success "数据目录已删除: ${DATA_DIR}"
        fi
    fi
}

# 删除用户
remove_user() {
    log_info "删除系统用户..."
    
    if id "${SERVICE_NAME}" &>/dev/null; then
        # 询问是否删除用户
        echo
        read -p "是否删除系统用户 ${SERVICE_NAME}？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            userdel ${SERVICE_NAME} 2>/dev/null || true
            log_success "系统用户已删除: ${SERVICE_NAME}"
        else
            log_info "保留系统用户: ${SERVICE_NAME}"
        fi
    else
        log_info "系统用户不存在，跳过"
    fi
}

# 清理日志文件
cleanup_logs() {
    log_info "清理日志文件..."
    
    # 询问是否删除日志
    echo
    read -p "是否删除日志文件？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 删除应用日志
        if [[ -f "/var/log/cmdmonitor.log" ]]; then
            rm -f /var/log/cmdmonitor.log*
            log_success "应用日志已删除"
        fi
        
        # 清理systemd日志
        journalctl --vacuum-time=1s --unit=${SERVICE_NAME} >/dev/null 2>&1 || true
        log_success "systemd日志已清理"
    else
        log_info "保留日志文件"
        log_info "查看历史日志: journalctl -u ${SERVICE_NAME}"
    fi
}

# 显示卸载后信息
show_post_uninstall_info() {
    echo
    log_success "=== Command Monitor 卸载完成 ==="
    echo
    
    # 检查是否还有残留文件
    local remaining_files=()
    
    [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]] && remaining_files+=("${INSTALL_DIR}/${BINARY_NAME}")
    [[ -f ${SERVICE_FILE} ]] && remaining_files+=("${SERVICE_FILE}")
    [[ -d ${CONFIG_DIR} ]] && remaining_files+=("${CONFIG_DIR}")
    [[ -d ${DATA_DIR} ]] && remaining_files+=("${DATA_DIR}")
    
    if [[ ${#remaining_files[@]} -gt 0 ]]; then
        log_info "保留的文件/目录:"
        for file in "${remaining_files[@]}"; do
            echo "  - $file"
        done
        echo
        log_info "如需完全清理，请手动删除这些文件"
    else
        log_success "所有文件已清理完毕"
    fi
    
    # 检查服务状态
    if systemctl list-unit-files | grep -q ${SERVICE_NAME}; then
        log_warning "systemd中仍有服务记录，请运行: sudo systemctl reset-failed"
    fi
}

# 主函数
main() {
    check_root
    confirm_uninstall
    
    echo
    log_info "开始卸载 Command Monitor..."
    
    stop_and_disable_service
    remove_service_file
    remove_binary
    remove_config_and_data
    remove_user
    cleanup_logs
    show_post_uninstall_info
    
    echo
    log_success "卸载完成！"
}

# 运行主函数
main "$@"
