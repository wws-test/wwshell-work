#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 命令结果缓存
declare -A cmd_cache

# 执行带超时的命令
execute_with_timeout() {
    local cmd="$1"
    local timeout="$2"
    local output
    
    output=$( (timeout "$timeout" $cmd) 2>&1 )
    local ret=$?
    
    if [ $ret -eq 124 ]; then
        log_message "ERROR" "Command timed out after ${timeout} seconds: $cmd"
        return 124
    elif [ $ret -ne 0 ]; then
        log_message "ERROR" "Command failed with exit code $ret: $cmd"
        return $ret
    fi
    
    echo "$output"
    return 0
}

# 缓存命令输出
cache_command_output() {
    local cmd="$1"
    local cache_time="$2"  # 缓存时间（秒）
    local current_time=$(date +%s)
    
    # 检查缓存是否存在且未过期
    if [ -n "${cmd_cache[$cmd]}" ]; then
        local cache_data=(${cmd_cache[$cmd]})
        local cache_timestamp=${cache_data[0]}
        if [ $((current_time - cache_timestamp)) -lt $cache_time ]; then
            echo "${cache_data[1]}"
            return 0
        fi
    fi
    
    # 执行命令并缓存结果
    local output=$(execute_with_timeout "$cmd" 5)
    cmd_cache[$cmd]="$current_time $output"
    echo "$output"
}

# 统一的表格绘制函数
draw_table() {
    local title="$1"
    local color="$2"
    shift 2
    local width=$(tput cols)
    local line=""
    
    for ((i=0; i<width-4; i++)); do
        line="${line}─"
    done
    
    echo -e "${color}┌${line}┐${NC}"
    echo -e "${color}│ ${BOLD}${title}${NC}${color}" "$(printf '%*s' $((width - ${#title} - 3)) '')"│${NC}"
    echo -e "${color}├${line}┤${NC}"
    
    while [ "$1" ]; do
        local key="$1"
        local value="$2"
        echo -e "${color}│ ${key}: ${value}${NC}" "$(printf '%*s' $((width - ${#key} - ${#value} - 4)) '')"${color}│${NC}"
        shift 2
    done
    
    echo -e "${color}└${line}┘${NC}"
}

# 进度显示函数
show_progress() {
    local current="$1"
    local total="$2"
    local width="$3"
    local percent=$((current * 100 / total))
    local progress=$((width * current / total))
    
    printf "\r["
    for ((i=0; i<progress; i++)); do printf "="; done
    for ((i=progress; i<width; i++)); do printf " "; done
    printf "] %3d%%" "$percent"
}

# 日志记录函数
log_message() {
    local level="$1"
    local message="$2"
    local log_file="$HOME/.hardware_info.log"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$log_file"
}

# 参数验证函数
validate_args() {
    local args=("$@")
    local valid_args=(-h --help -a --all -s --system -c --cpu -m --memory -d --disk -g --gpu -n --network -b --bios -u --usb -t --temp -p --power -l --large -j --json)
    
    for arg in "${args[@]}"; do
        if [[ ! " ${valid_args[@]} " =~ " ${arg} " ]]; then
            echo "错误: 无效的参数 '$arg'"
            return 1
        fi
    done
    return 0
}

# 配置文件处理
load_config() {
    local config_file="$HOME/.config/hardware_info.conf"
    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        # 创建默认配置
        mkdir -p "$(dirname "$config_file")"
        cat > "$config_file" << EOF
# Hardware Info 配置文件
REFRESH_INTERVAL=5  # 刷新间隔（秒）
CACHE_TIMEOUT=60   # 缓存超时时间（秒）
COLOR_OUTPUT=true  # 是否启用彩色输出
DETAILED_INFO=false # 是否显示详细信息
EOF
    fi
}

# JSON输出格式化函数
format_json() {
    local type="$1"
    shift
    local data=("$@")
    local json="{"
    
    case "$type" in
        "cpu")
            json+="\"type\":\"cpu\","
            json+="\"data\":{"
            for ((i=0; i<${#data[@]}; i+=2)); do
                json+="\"${data[i]}\":\"${data[i+1]}\","
            done
            json="${json%,}"  # 移除最后一个逗号
            json+="}}"
            ;;
        "memory")
            json+="\"type\":\"memory\","
            json+="\"data\":{"
            for ((i=0; i<${#data[@]}; i+=2)); do
                json+="\"${data[i]}\":\"${data[i+1]}\","
            done
            json="${json%,}"
            json+="}}"
            ;;
        "gpu")
            json+="\"type\":\"gpu\","
            json+="\"data\":{"
            for ((i=0; i<${#data[@]}; i+=2)); do
                json+="\"${data[i]}\":\"${data[i+1]}\","
            done
            json="${json%,}"
            json+="}}"
            ;;
        *)
            json+="\"error\":\"Unknown type: $type\"}"
            ;;
    esac
    
    echo "$json"
}

# 检查命令是否可用
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# 输出缓冲
buffer_output() {
    local output=""
    while IFS= read -r line; do
        output+="$line\n"
    done
    printf "$output"
} 