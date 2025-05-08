#!/bin/bash

# 引入基础类
source "${SCRIPT_DIR}/src/core/base.sh"

# 系统信息模块类
class_system_info() {
    # 继承基础类
    class_base
    
    # 私有变量
    local _cache_manager
    local _config_manager
    local _error_handler
    
    # 构造函数
    constructor() {
        # 调用父类构造函数
        class_base::constructor "system_info" "1.0.0" "系统信息收集模块"
        
        # 初始化组件
        _cache_manager=$(class_cache_manager)
        _config_manager=$(class_config_manager "$HOME/.config/hardware_info.conf")
        _error_handler=$(class_error_handler)
        
        # 加载配置
        $_config_manager.load_config
    }
    
    # 初始化
    initialize() {
        # 检查必要的命令
        local required_commands=("uname" "hostname" "uptime" "who")
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" &>/dev/null; then
                $_error_handler.handle_error "$ERROR_LEVEL_ERROR" "命令 '$cmd' 不可用" 1
                return 1
            fi
        done
        
        return 0
    }
    
    # 获取系统信息
    get_system_info() {
        local cache_key="system_info"
        local cache_ttl=300  # 5分钟缓存
        
        # 尝试从缓存获取
        local cached_data=$($_cache_manager.get_cache "$cache_key")
        if [ $? -eq 0 ]; then
            echo "$cached_data"
            return 0
        fi
        
        # 收集系统信息
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
        local users=$(who | wc -l)
        
        # 格式化数据
        local data=(
            "主机名" "$hostname"
            "操作系统" "$os_info"
            "内核版本" "$kernel"
            "系统架构" "$arch"
            "运行时间" "$uptime"
            "当前用户数" "$users"
        )
        
        # 缓存数据
        local json_data=$(format_json "system" "${data[@]}")
        $_cache_manager.set_cache "$cache_key" "$json_data" "$cache_ttl"
        
        echo "$json_data"
        return 0
    }
    
    # 格式化JSON输出
    format_json() {
        local type="$1"
        shift
        local data=("$@")
        local json="{"
        
        json+="\"type\":\"$type\","
        json+="\"data\":{"
        
        local first=true
        for ((i=0; i<${#data[@]}; i+=2)); do
            if [ "$first" = true ]; then
                first=false
            else
                json+=","
            fi
            json+="\"${data[i]}\":\"${data[i+1]}\""
        done
        
        json+="}}"
        
        echo "$json"
    }
    
    # 执行模块
    execute() {
        # 检查模块是否启用
        if ! $(is_enabled); then
            $_error_handler.handle_error "$ERROR_LEVEL_WARNING" "系统信息模块已禁用" 0
            return 0
        fi
        
        # 初始化模块
        if ! $(initialize); then
            return 1
        fi
        
        # 获取系统信息
        local result=$(get_system_info)
        if [ $? -ne 0 ]; then
            $_error_handler.handle_error "$ERROR_LEVEL_ERROR" "获取系统信息失败" 2
            return 2
        fi
        
        echo "$result"
        return 0
    }
    
    # 清理
    cleanup() {
        $_cache_manager.clear_cache
    }
}

# 导出模块
export -f class_system_info 