#!/bin/bash

# 引入工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# 初始化配置
load_config

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
NC='\033[0m' # 恢复默认颜色
BOLD='\033[1m'
BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_BLUE='\033[44m'
# 定义大字体（使用figlet或toilet需要安装）
LARGE_FONT=false
# 检查是否安装了figlet
if command -v figlet &>/dev/null; then
    LARGE_FONT=true
fi

# 默认显示所有信息
SHOW_ALL=true
SHOW_SYSTEM=false
SHOW_CPU=false
SHOW_MEMORY=false
SHOW_DISK=false
SHOW_GPU=false
SHOW_NETWORK=false
SHOW_BIOS=false
SHOW_USB=false
SHOW_SENSOR=false
SHOW_POWER=false

# 函数：显示帮助信息
show_help() {
    echo -e "${BOLD}硬件信息查看工具${NC}"
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -a, --all      显示所有信息（默认）"
    echo "  -s, --system   仅显示系统信息"
    echo "  -c, --cpu      仅显示CPU信息"
    echo "  -m, --memory   仅显示内存信息"
    echo "  -d, --disk     仅显示磁盘信息"
    echo "  -g, --gpu      仅显示GPU信息"
    echo "  -n, --network  仅显示网络信息"
    echo "  -b, --bios     仅显示BIOS信息"
    echo "  -u, --usb      仅显示USB设备信息"
    echo "  -t, --temp     仅显示温度传感器信息"
    echo "  -p, --power    仅显示电源信息"
    echo "  -l, --large    使用大字体显示标题"
    echo "  -j, --json     以JSON格式输出"
}

# 函数：打印分隔线
print_separator() {
    local width=$(tput cols)
    local line=""
    for ((i=0; i<width; i++)); do
        line="${line}━"
    done
    echo -e "${YELLOW}${line}${NC}"
}

# 函数：创建标题
print_title() {
    local title="$1"
    local color="$2"
    local width=$(tput cols)
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo
    if [ "$LARGE_FONT" = true ] && check_command figlet; then
        figlet -c "$title"
    else
        printf "%${padding}s" ""
        echo -e "${color}${BOLD}${title}${NC}"
    fi
    echo
}

# 函数：检查命令是否存在
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 系统基本信息
print_system_info() {
    print_title "系统信息" "${RED}"

    # 使用表格式式显示系统信息
    local width=$(tput cols)
    local line=""
    for ((i=0; i<width-4; i++)); do
        line="${line}─"
    done

    echo -e "${BOLD}${CYAN}│ 主机名       ${NC}${BOLD}│${NC} $(hostname)"
    echo -e "${CYAN}│${line}│${NC}"

    echo -ne "${BOLD}${CYAN}│ 操作系统     ${NC}${BOLD}│${NC} "
    if [ -f /etc/os-release ]; then
        cat /etc/os-release | grep "PRETTY_NAME" | cut -d= -f2 | tr -d '"'
    else
        uname -o
    fi

    echo -e "${CYAN}│${line}│${NC}"
    echo -e "${BOLD}${CYAN}│ 内核版本     ${NC}${BOLD}│${NC} $(uname -r)"
    echo -e "${CYAN}│${line}│${NC}"
    echo -e "${BOLD}${CYAN}│ 系统架构     ${NC}${BOLD}│${NC} $(uname -m)"
    echo -e "${CYAN}│${line}│${NC}"
    echo -e "${BOLD}${CYAN}│ 系统运行时间 ${NC}${BOLD}│${NC} $(uptime -p)"
    echo -e "${CYAN}│${line}│${NC}"
    echo -e "${BOLD}${CYAN}│ 当前登录用户 ${NC}${BOLD}│${NC} $(who | wc -l) 个用户"
    echo -e "${CYAN}│${line}│${NC}"
}

# CPU信息
print_cpu_info() {
    print_title "CPU 信息" "${BLUE}"
    
    # 使用缓存获取CPU信息
    local cpu_info
    if check_command lscpu; then
        cpu_info=$(cache_command_output "lscpu" "$CACHE_TIMEOUT")
    fi
    
    # 准备数据
    local cpu_data=(
        "型号" "$(echo "$cpu_info" | grep -E "(型号名称|Model name)" | sed 's/^[^:]*://; s/^[ \t]*//' || grep "model name" /proc/cpuinfo | head -n1 | cut -d ":" -f2 | sed 's/^[ \t]*//')"
        "物理核心数" "$(echo "$cpu_info" | grep -E "(CPU\(s\)|Socket\(s\))" | head -n1 | awk '{print $2}')"
        "每核线程数" "$(echo "$cpu_info" | grep -E "(每个核的线程数|Thread\(s\) per core)" | sed 's/^[^:]*://; s/^[ \t]*//')"
        "当前频率" "$(echo "$cpu_info" | grep -E "(CPU MHz|CPU 兆赫)" | sed 's/^[^:]*://; s/^[ \t]*//')"
        "最大频率" "$(echo "$cpu_info" | grep -E "(CPU max MHz|CPU 最大兆赫)" | sed 's/^[^:]*://; s/^[ \t]*//')"
        "负载" "$(uptime | awk -F'load average: ' '{print $2}')"
    )
    
    # 使用JSON格式输出
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        format_json "cpu" "${cpu_data[@]}"
        return
    fi
    
    # 使用表格输出
    draw_table "CPU信息" "${BLUE}" "${cpu_data[@]}"
    
    # 显示CPU缓存信息
    echo -e "\n${BOLD}${BLUE}CPU缓存信息:${NC}"
    if [ -n "$cpu_info" ]; then
        echo "$cpu_info" | grep -i "cache" | sed 's/^[^:]*://; s/^[ \t]*//' | buffer_output
    else
        grep "cache size" /proc/cpuinfo | head -n1 | cut -d ":" -f2 | sed 's/^[ \t]*//' | buffer_output
    fi
    
    # 记录日志
    log_message "INFO" "CPU信息已收集完成"
}

# 内存信息
print_memory_info() {
    print_title "内存信息" "${GREEN}"

    if ! check_command free; then
        log_message "ERROR" "未找到 'free' 命令，无法获取内存信息"
        echo -e "${RED}错误: 未找到 'free' 命令，无法获取内存信息${NC}"
        return 1
    fi

    # 使用缓存获取内存信息
    local mem_info=$(cache_command_output "free -h" "$CACHE_TIMEOUT")
    
    # 准备数据
    local mem_data=(
        "总内存" "$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')"
        "已用内存" "$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')"
        "可用内存" "$(echo "$mem_info" | grep "Mem:" | awk '{print $7}')"
        "共享内存" "$(echo "$mem_info" | grep "Mem:" | awk '{print $5}')"
        "缓存" "$(echo "$mem_info" | grep "Mem:" | awk '{print $6}')"
        "内存使用率" "$(free | grep Mem | awk '{printf("%.2f%%"), $3/$2 * 100}')"
    )
    
    local swap_data=(
        "总交换空间" "$(echo "$mem_info" | grep "Swap:" | awk '{print $2}')"
        "已用交换空间" "$(echo "$mem_info" | grep "Swap:" | awk '{print $3}')"
        "可用交换空间" "$(echo "$mem_info" | grep "Swap:" | awk '{print $4}')"
        "交换空间使用率" "$(free | grep Swap | awk '{if ($2 > 0) printf("%.2f%%"), $3/$2 * 100; else print "0.00%"}')"
    )
    
    # 使用JSON格式输出
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        local all_data=("${mem_data[@]}" "${swap_data[@]}")
        format_json "memory" "${all_data[@]}"
        return
    fi
    
    # 使用表格输出
    draw_table "物理内存" "${GREEN}" "${mem_data[@]}"
    echo
    draw_table "交换空间" "${BLUE}" "${swap_data[@]}"
    
    # 绘制内存使用图表
    echo -e "\n${BOLD}内存使用图表:${NC}"
    
    # 计算内存使用百分比
    local mem_percent=$(free | grep Mem | awk '{printf("%.0f"), $3/$2 * 100}')
    local width=$(tput cols)
    local bar_width=$((width - 10))
    
    show_progress "$mem_percent" "100" "$bar_width"
    echo -e "\n${RED}██${NC} 已用内存  ${GREEN}██${NC} 可用内存"
    
    # 显示内存详细信息
    if [ -f /proc/meminfo ]; then
        echo -e "\n${CYAN}${BOLD}内存详细信息:${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        grep -E "(MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|Cached|Buffers)" /proc/meminfo | \
        while read line; do
            key=$(echo $line | awk '{print $1}')
            value=$(echo $line | awk '{print $2, $3}')
            echo -e "${CYAN}$key${NC} $value"
        done | buffer_output
    fi
    
    # 记录日志
    log_message "INFO" "内存信息已收集完成"
}

# GPU信息
print_gpu_info() {
    print_title "GPU信息" "${PURPLE}"
    
    # 获取所有显卡信息
    if ! check_command lspci; then
        log_message "ERROR" "无法获取GPU信息: lspci 命令不可用"
        echo -e "${RED}无法获取GPU信息: lspci 命令不可用${NC}"
        return 1
    fi
    
    # 使用缓存获取基本GPU信息
    local gpu_info=$(cache_command_output "lspci -v | grep -A 8 -i 'VGA\|3D\|Display'" "$CACHE_TIMEOUT")
    
    # 准备基本GPU数据
    local gpu_basic_data=(
        "检测到的显卡" "$(echo "$gpu_info" | grep -i "VGA\|3D\|Display" | wc -l)"
    )
    
    # 使用JSON格式输出
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        local all_gpu_data=("${gpu_basic_data[@]}")
        
        # 添加NVIDIA GPU信息
        if check_command nvidia-smi; then
            local nvidia_info=$(cache_command_output "nvidia-smi --query-gpu=gpu_name,driver_version,memory.total,memory.used,temperature.gpu,utilization.gpu --format=csv,noheader,nounits" "$CACHE_TIMEOUT")
            if [ -n "$nvidia_info" ]; then
                while IFS="," read -r name driver_ver mem_total mem_used temp util; do
                    name=$(echo "$name" | sed 's/^[ \t]*//;s/[ \t]*$//')
                    all_gpu_data+=(
                        "NVIDIA型号" "$name"
                        "驱动版本" "$driver_ver"
                        "显存总量" "${mem_total}MB"
                        "显存使用" "${mem_used}MB"
                        "温度" "${temp}°C"
                        "使用率" "${util}%"
                    )
                done <<< "$nvidia_info"
            fi
        fi
        
        # 添加AMD GPU信息
        if check_command rocm-smi; then
            local amd_info=$(cache_command_output "rocm-smi --showuse" "$CACHE_TIMEOUT")
            if [ -n "$amd_info" ]; then
                all_gpu_data+=("AMD_INFO" "$amd_info")
            fi
        fi
        
        format_json "gpu" "${all_gpu_data[@]}"
        return
    fi
    
    # 使用表格输出
    draw_table "GPU基本信息" "${PURPLE}" "${gpu_basic_data[@]}"
    
    # 显示所有检测到的显卡信息
    echo -e "\n${PURPLE}${BOLD}● 系统检测到的所有显卡${NC}"
    if [ -n "$gpu_info" ]; then
        echo "$gpu_info" | while IFS= read -r line; do
            [ -z "$line" ] && continue
            [ "$line" = "--" ] && continue
            echo -e "${CYAN}$line${NC}"
        done | buffer_output
    else
        echo -e "${YELLOW}未检测到显卡设备${NC}"
    fi
    
    # 检查NVIDIA显卡
    if check_command nvidia-smi; then
        local nvidia_info=$(cache_command_output "nvidia-smi --query-gpu=gpu_name,driver_version,memory.total,memory.used,temperature.gpu,utilization.gpu --format=csv,noheader,nounits" "$CACHE_TIMEOUT")
        if [ -n "$nvidia_info" ]; then
            echo -e "\n${PURPLE}${BOLD}● NVIDIA GPU 详细信息${NC}"
            while IFS="," read -r name driver_ver mem_total mem_used temp util; do
                # 去除空格
                name=$(echo "$name" | sed 's/^[ \t]*//;s/[ \t]*$//')
                driver_ver=$(echo "$driver_ver" | sed 's/^[ \t]*//;s/[ \t]*$//')
                mem_total=$(echo "$mem_total" | sed 's/^[ \t]*//;s/[ \t]*$//')
                mem_used=$(echo "$mem_used" | sed 's/^[ \t]*//;s/[ \t]*$//')
                temp=$(echo "$temp" | sed 's/^[ \t]*//;s/[ \t]*$//')
                util=$(echo "$util" | sed 's/^[ \t]*//;s/[ \t]*$//')
                
                local nvidia_data=(
                    "型号" "$name"
                    "驱动版本" "$driver_ver"
                    "显存" "${mem_used}MB / ${mem_total}MB"
                    "温度" "${temp}°C"
                    "使用率" "${util}%"
                )
                draw_table "NVIDIA GPU" "${CYAN}" "${nvidia_data[@]}"
            done <<< "$nvidia_info"
        fi
    fi
    
    # 检查AMD显卡
    if check_command rocm-smi; then
        local amd_info=$(cache_command_output "rocm-smi --showuse" "$CACHE_TIMEOUT")
        if [ -n "$amd_info" ]; then
            echo -e "\n${PURPLE}${BOLD}● AMD GPU 详细信息${NC}"
            echo "$amd_info" | head -n 5 | while IFS= read -r line; do
                [ -n "$line" ] && echo -e "${CYAN}$line${NC}"
            done | buffer_output
        fi
    fi
    
    # 记录日志
    log_message "INFO" "GPU信息已收集完成"
}

# 网络信息
print_network_info() {
    print_title "网络信息" "${BLUE}"
    
    # 获取网络接口信息
    local interface_info=""
    if check_command ip; then
        interface_info=$(cache_command_output "ip -br addr" "$CACHE_TIMEOUT")
    elif check_command ifconfig; then
        interface_info=$(cache_command_output "ifconfig" "$CACHE_TIMEOUT")
    else
        log_message "ERROR" "无法获取网络接口信息: ip 和 ifconfig 命令不可用"
        echo -e "${RED}无法获取网络接口信息: ip 和 ifconfig 命令不可用${NC}"
        return 1
    fi
    
    # 获取默认网关信息
    local gateway_info=""
    if check_command ip; then
        gateway_info=$(cache_command_output "ip route" "$CACHE_TIMEOUT")
    elif check_command route; then
        gateway_info=$(cache_command_output "route -n" "$CACHE_TIMEOUT")
    fi
    
    # 获取DNS服务器信息
    local dns_info=""
    if [ -f /etc/resolv.conf ]; then
        dns_info=$(grep nameserver /etc/resolv.conf)
    fi
    
    # 准备数据
    local interface_data=()
    if [ -n "$interface_info" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && interface_data+=("接口" "$line")
        done <<< "$(echo "$interface_info" | head -n 4)"
    fi
    
    local gateway_data=()
    if [ -n "$gateway_info" ]; then
        while IFS= read -r line; do
            [[ "$line" =~ "default" ]] && gateway_data+=("默认网关" "$line")
        done <<< "$(echo "$gateway_info" | head -n 2)"
    fi
    
    local dns_data=()
    if [ -n "$dns_info" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && dns_data+=("DNS服务器" "$line")
        done <<< "$dns_info"
    fi
    
    # 使用JSON格式输出
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        local all_data=("${interface_data[@]}" "${gateway_data[@]}" "${dns_data[@]}")
        format_json "network" "${all_data[@]}"
        return
    fi
    
    # 使用表格输出
    if [ ${#interface_data[@]} -gt 0 ]; then
        echo -e "\n${BOLD}${BLUE}网络接口:${NC}"
        draw_table "网络接口" "${BLUE}" "${interface_data[@]}"
    fi
    
    if [ ${#gateway_data[@]} -gt 0 ]; then
        echo -e "\n${BOLD}${BLUE}默认网关:${NC}"
        draw_table "默认网关" "${BLUE}" "${gateway_data[@]}"
    fi
    
    if [ ${#dns_data[@]} -gt 0 ]; then
        echo -e "\n${BOLD}${BLUE}DNS服务器:${NC}"
        draw_table "DNS服务器" "${BLUE}" "${dns_data[@]}"
    fi
    
    # 记录日志
    log_message "INFO" "网络信息已收集完成"
}

# BIOS/UEFI信息
print_bios_info() {
    print_title "BIOS/UEFI信息" "${BLUE}"

    # 创建美观的BIOS信息表
    local width=$(tput cols)
    local header_line=""
    for ((i=0; i<width-4; i++)); do
        header_line="${header_line}─"
    done

    echo -e "${BLUE}┌${header_line}┐${NC}"
    echo -e "${BLUE}│ ${BOLD}BIOS/UEFI信息${NC}${BLUE}" "$(printf '%*s' $((width - 17)) '')"│${NC}"
    echo -e "${BLUE}├${header_line}┤${NC}"

    if check_command dmidecode; then
        # 尝试获取BIOS信息
        local bios_info=$(sudo dmidecode -t bios 2>/dev/null | grep -E "Vendor|Version|Release Date" | sed 's/^\s*//')
        if [ -n "$bios_info" ]; then
            echo "$bios_info" | while read -r line; do
                echo -e "${BLUE}│${NC} ${CYAN}$line${NC}" "$(printf '%*s' $((width - ${#line} - 5)) '')"${BLUE}│${NC}"
            done
        else
            echo -e "${BLUE}│${NC} ${YELLOW}需要root权限才能查看BIOS信息${NC}" "$(printf '%*s' $((width - 36)) '')"${BLUE}│${NC}"
        fi
    else
        echo -e "${BLUE}│${NC} ${RED}无法获取BIOS信息: dmidecode 命令不可用${NC}" "$(printf '%*s' $((width - 45)) '')"${BLUE}│${NC}"
    fi

    echo -e "${BLUE}└${header_line}┘${NC}"
}

# 系统概览
print_system_overview() {
    print_title "系统概览" "${CYAN}"
    
    # 使用缓存获取系统信息
    local hostname=$(hostname)
    local os_info=""
    if [ -f /etc/os-release ]; then
        os_info=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d= -f2 | tr -d '"')
    else
        os_info=$(uname -o)
    fi
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local uptime=$(uptime -p)
    
    # 获取CPU信息
    local cpu_info=""
    if check_command lscpu; then
        cpu_info=$(cache_command_output "lscpu" "$CACHE_TIMEOUT")
    fi
    local cpu_model=""
    local cpu_cores=""
    if [ -n "$cpu_info" ]; then
        cpu_model=$(echo "$cpu_info" | grep -E "(型号名称|Model name)" | sed 's/^[^:]*://; s/^[ \t]*//' | head -n1)
        cpu_cores=$(echo "$cpu_info" | grep -E "(CPU\(s\)|Socket\(s\))" | head -n1 | awk '{print $2}')
    else
        cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d ":" -f2 | sed 's/^[ \t]*//')
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
    fi
    
    # 获取内存信息
    local mem_info=$(cache_command_output "free -h" "$CACHE_TIMEOUT")
    local mem_total=$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')
    local mem_used=$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')
    local mem_free=$(echo "$mem_info" | grep "Mem:" | awk '{print $7}')
    
    # 获取磁盘信息
    local disk_info=$(cache_command_output "df -h /" "$CACHE_TIMEOUT")
    local disk_total=$(echo "$disk_info" | grep -v "Filesystem" | awk '{print $2}')
    local disk_used=$(echo "$disk_info" | grep -v "Filesystem" | awk '{print $3}')
    local disk_free=$(echo "$disk_info" | grep -v "Filesystem" | awk '{print $4}')
    
    # 获取网络信息
    local ip_addr=""
    local net_interface=""
    local connections=""
    if check_command ip; then
        ip_addr=$(hostname -I | awk '{print $1}')
        net_interface=$(cache_command_output "ip -br link" "$CACHE_TIMEOUT" | grep UP | head -n1 | awk '{print $1}')
    fi
    if check_command netstat; then
        connections=$(cache_command_output "netstat -an" "$CACHE_TIMEOUT" | grep ESTABLISHED | wc -l)
    else
        connections="N/A"
    fi
    
    # 准备数据
    local host_data=(
        "主机名" "$hostname"
        "系统" "${os_info:0:30}"
        "内核" "$kernel"
    )
    
    local cpu_data=(
        "型号" "${cpu_model:0:30}"
        "核心数" "$cpu_cores"
        "负载" "$(uptime | awk -F'load average: ' '{print $2}' | cut -d, -f1)"
    )
    
    local mem_data=(
        "总内存" "$mem_total"
        "已用" "$mem_used"
        "可用" "$mem_free"
    )
    
    local disk_data=(
        "总空间" "$disk_total"
        "已用" "$disk_used"
        "可用" "$disk_free"
    )
    
    local net_data=(
        "IP地址" "$ip_addr"
        "接口" "$net_interface"
        "连接数" "$connections"
    )
    
    local sys_data=(
        "运行时间" "$uptime"
        "当前用户数" "$(who | wc -l)"
        "系统架构" "$arch"
    )
    
    # 使用JSON格式输出
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        local all_data=(
            "${host_data[@]}"
            "${cpu_data[@]}"
            "${mem_data[@]}"
            "${disk_data[@]}"
            "${net_data[@]}"
            "${sys_data[@]}"
        )
        format_json "overview" "${all_data[@]}"
        return
    fi
    
    # 使用表格输出
    echo -e "\n${BOLD}${RED}主机信息:${NC}"
    draw_table "主机信息" "${RED}" "${host_data[@]}"
    
    echo -e "\n${BOLD}${BLUE}CPU信息:${NC}"
    draw_table "CPU信息" "${BLUE}" "${cpu_data[@]}"
    
    echo -e "\n${BOLD}${GREEN}内存信息:${NC}"
    draw_table "内存信息" "${GREEN}" "${mem_data[@]}"
    
    echo -e "\n${BOLD}${PURPLE}磁盘信息:${NC}"
    draw_table "磁盘信息" "${PURPLE}" "${disk_data[@]}"
    
    echo -e "\n${BOLD}${ORANGE}网络信息:${NC}"
    draw_table "网络信息" "${ORANGE}" "${net_data[@]}"
    
    echo -e "\n${BOLD}${CYAN}系统信息:${NC}"
    draw_table "系统信息" "${CYAN}" "${sys_data[@]}"
    
    # 记录日志
    log_message "INFO" "系统概览信息已收集完成"
}

# 解析命令行参数
parse_args() {
    # 验证参数
    if ! validate_args "$@"; then
        show_help
        exit 1
    fi
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                SHOW_ALL=true
                ;;
            -s|--system)
                SHOW_ALL=false
                SHOW_SYSTEM=true
                ;;
            -c|--cpu)
                SHOW_ALL=false
                SHOW_CPU=true
                ;;
            -m|--memory)
                SHOW_ALL=false
                SHOW_MEMORY=true
                ;;
            -d|--disk)
                SHOW_ALL=false
                SHOW_DISK=true
                ;;
            -g|--gpu)
                SHOW_ALL=false
                SHOW_GPU=true
                ;;
            -n|--network)
                SHOW_ALL=false
                SHOW_NETWORK=true
                ;;
            -b|--bios)
                SHOW_ALL=false
                SHOW_BIOS=true
                ;;
            -u|--usb)
                SHOW_ALL=false
                SHOW_USB=true
                ;;
            -t|--temp)
                SHOW_ALL=false
                SHOW_SENSOR=true
                ;;
            -p|--power)
                SHOW_ALL=false
                SHOW_POWER=true
                ;;
            -l|--large)
                # 强制启用大字体模式
                LARGE_FONT=true
                # 检查是否安装了figlet
                if ! check_command figlet; then
                    log_message "WARNING" "figlet命令不可用，大字体模式可能无法正常工作"
                    echo -e "${YELLOW}警告: figlet命令不可用，大字体模式可能无法正常工作${NC}"
                    echo -e "${YELLOW}请安装figlet: sudo apt-get install figlet (或您系统对应的包管理器命令)${NC}"
                    sleep 2
                fi
                ;;
            -j|--json)
                OUTPUT_FORMAT="json"
                ;;
            *)
                log_message "ERROR" "无效的参数: $1"
                echo "错误: 无效的参数 '$1'"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 初始化日志
    log_message "INFO" "开始收集硬件信息"
    
    # 如果是JSON格式输出，创建数组存储所有数据
    local all_json_data=()
    
    # 显示系统信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_SYSTEM" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("system" "$(print_system_info)")
        else
            print_system_info
        fi
    fi
    
    # 显示CPU信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_CPU" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("cpu" "$(print_cpu_info)")
        else
            print_cpu_info
        fi
    fi
    
    # 显示内存信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_MEMORY" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("memory" "$(print_memory_info)")
        else
            print_memory_info
        fi
    fi
    
    # 显示磁盘信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_DISK" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("disk" "$(print_disk_info)")
        else
            print_disk_info
        fi
    fi
    
    # 显示GPU信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_GPU" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("gpu" "$(print_gpu_info)")
        else
            print_gpu_info
        fi
    fi
    
    # 显示网络信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_NETWORK" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("network" "$(print_network_info)")
        else
            print_network_info
        fi
    fi
    
    # 显示BIOS信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_BIOS" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("bios" "$(print_bios_info)")
        else
            print_bios_info
        fi
    fi
    
    # 显示USB设备信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_USB" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("usb" "$(print_usb_info)")
        else
            print_usb_info
        fi
    fi
    
    # 显示温度传感器信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_SENSOR" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("sensor" "$(print_sensor_info)")
        else
            print_sensor_info
        fi
    fi
    
    # 显示电源信息
    if [ "$SHOW_ALL" = true ] || [ "$SHOW_POWER" = true ]; then
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            all_json_data+=("power" "$(print_power_info)")
        else
            print_power_info
        fi
    fi
    
    # 如果是JSON格式输出，打印完整的JSON数据
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{"
        local first=true
        for ((i=0; i<${#all_json_data[@]}; i+=2)); do
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            echo "\"${all_json_data[i]}\": ${all_json_data[i+1]}"
        done
        echo "}"
    fi
    
    # 记录日志
    log_message "INFO" "硬件信息收集完成"
}

# 执行主函数
main "$@"



