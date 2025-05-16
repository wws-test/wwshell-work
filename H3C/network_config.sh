#!/bin/bash

# Rocky Linux 9.3 网络配置脚本
# 支持静态IP和DHCP模式配置

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行。请使用sudo执行此脚本。"
        exit 1
    fi
}

# 检查网络配置文件是否存在
check_network_file() {
    local iface=$1
    local config_file="/etc/sysconfig/network-scripts/ifcfg-$iface"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "网络接口 '$iface' 的配置文件不存在: $config_file"
        return 1
    fi
    
    return 0
}

# 获取可用的网络接口
get_available_interfaces() {
    local interfaces=()
    for iface in $(ls /sys/class/net/); do
        # 排除回环接口
        if [[ "$iface" != "lo" ]]; then
            interfaces+=("$iface")
        fi
    done
    
    echo "${interfaces[@]}"
}

# 配置为DHCP模式
configure_dhcp() {
    local iface=$1
    local config_file="/etc/sysconfig/network-scripts/ifcfg-$iface"
    
    log_info "配置接口 '$iface' 为DHCP模式..."
    
    # 备份原配置文件
    cp "$config_file" "${config_file}.bak"
    
    # 创建新配置
    cat > "$config_file" <<EOF
TYPE=Ethernet
BOOTPROTO=dhcp
DEFROUTE=yes
NAME=$iface
DEVICE=$iface
ONBOOT=yes
EOF
    
    log_info "DHCP配置已写入 $config_file"
    
    # 重启网络服务
    restart_network_service
}

# 配置为静态IP模式
configure_static_ip() {
    local iface=$1
    
    log_info "配置接口 '$iface' 为静态IP模式..."
    
    # 获取用户输入
    read -p "请输入IP地址: " ip_address
    read -p "请输入子网掩码: " netmask
    read -p "请输入网关: " gateway
    read -p "请输入DNS服务器(多个DNS用空格分隔): " dns_servers
    
    local config_file="/etc/sysconfig/network-scripts/ifcfg-$iface"
    
    # 备份原配置文件
    cp "$config_file" "${config_file}.bak"
    
    # 创建新配置
    cat > "$config_file" <<EOF
TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
NAME=$iface
UUID=2b2c0153-94c2-4c11-9559-6c9d74d0b994
DEVICE=$iface
ONBOOT=yes
IPADDR=$ip_address
NETMASK=$netmask

EOF
    
    # 添加额外的DNS服务器
    if [[ ! -z "$(echo $dns_servers | awk '{print $2}')" ]]; then
        echo "DNS2=$(echo $dns_servers | awk '{print $2}')" >> "$config_file"
    fi
    
    if [[ ! -z "$(echo $dns_servers | awk '{print $3}')" ]]; then
        echo "DNS3=$(echo $dns_servers | awk '{print $3}')" >> "$config_file"
    fi
    
    log_info "静态IP配置已写入 $config_file"
    
    # 重启网络服务
    restart_network_service
}

# 重启网络服务
restart_network_service() {
    log_info "正在重启网络服务..."
    
    # 尝试使用nmcli
    if command -v nmcli &> /dev/null; then
        nmcli networking off
        sleep 2
        nmcli networking on
        log_info "已使用NetworkManager重启网络"
        return
    fi
    
    # 尝试使用systemctl
    if command -v systemctl &> /dev/null; then
        systemctl restart NetworkManager
        log_info "已使用systemctl重启NetworkManager服务"
        return
    fi
    
    log_warn "无法重启网络服务。请手动重启网络服务。"
}

# 主函数
main() {
    check_root
    
    log_info "Rocky Linux 9.3 网络配置脚本"
    log_info "----------------------------"
    
    # 获取可用接口
    interfaces=($(get_available_interfaces))
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        log_error "未找到可用的网络接口。"
        exit 1
    fi
    
    # 显示可用接口
    log_info "可用的网络接口:"
    for ((i=0; i<${#interfaces[@]}; i++)); do
        echo "[$i] ${interfaces[$i]}"
    done
    
    # 选择接口
    read -p "请选择要配置的网络接口编号 [0]: " iface_index
    
    if [[ -z "$iface_index" ]]; then
        iface_index=0
    fi
    
    # 验证选择
    if [[ ! "$iface_index" =~ ^[0-9]+$ ]] || [[ "$iface_index" -ge ${#interfaces[@]} ]]; then
        log_error "无效的接口选择。"
        exit 1
    fi
    
    selected_iface=${interfaces[$iface_index]}
    
    # 检查网络配置文件
    if ! check_network_file "$selected_iface"; then
        log_error "无法继续配置。"
        exit 1
    fi
    
    # 选择配置类型
    echo
    echo "请选择配置类型:"
    echo "[1] DHCP (动态获取IP)"
    echo "[2] 静态IP"
    read -p "请选择 [1]: " config_type
    
    if [[ -z "$config_type" ]]; then
        config_type=1
    fi
    
    # 验证选择
    if [[ "$config_type" != "1" && "$config_type" != "2" ]]; then
        log_error "无效的配置类型选择。"
        exit 1
    fi
    
    # 执行配置
    if [[ "$config_type" == "1" ]]; then
        configure_dhcp "$selected_iface"
    else
        configure_static_ip "$selected_iface"
    fi
    
    log_info "网络配置完成！"
    log_info "当前网络接口配置信息:"
    ip addr show "$selected_iface"
}

# 执行主函数
main    