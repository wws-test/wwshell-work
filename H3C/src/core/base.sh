#!/bin/bash

# 基础模块类
class_base() {
    # 私有变量
    local _name=""
    local _version=""
    local _description=""
    local _enabled=true
    
    # 构造函数
    constructor() {
        _name="$1"
        _version="$2"
        _description="$3"
    }
    
    # 获取名称
    get_name() {
        echo "$_name"
    }
    
    # 获取版本
    get_version() {
        echo "$_version"
    }
    
    # 获取描述
    get_description() {
        echo "$_description"
    }
    
    # 检查是否启用
    is_enabled() {
        echo "$_enabled"
    }
    
    # 启用模块
    enable() {
        _enabled=true
    }
    
    # 禁用模块
    disable() {
        _enabled=false
    }
    
    # 初始化函数（由子类实现）
    initialize() {
        :
    }
    
    # 执行函数（由子类实现）
    execute() {
        :
    }
    
    # 清理函数（由子类实现）
    cleanup() {
        :
    }
}

# 错误处理类
class_error_handler() {
    # 错误级别
    local ERROR_LEVEL_INFO=0
    local ERROR_LEVEL_WARNING=1
    local ERROR_LEVEL_ERROR=2
    local ERROR_LEVEL_FATAL=3
    
    # 错误处理函数
    handle_error() {
        local level="$1"
        local message="$2"
        local code="$3"
        
        case "$level" in
            $ERROR_LEVEL_INFO)
                log_info "$message"
                ;;
            $ERROR_LEVEL_WARNING)
                log_warning "$message"
                ;;
            $ERROR_LEVEL_ERROR)
                log_error "$message"
                return "$code"
                ;;
            $ERROR_LEVEL_FATAL)
                log_fatal "$message"
                exit "$code"
                ;;
        esac
    }
    
    # 日志函数
    log_info() {
        echo "[INFO] $1"
    }
    
    log_warning() {
        echo "[WARNING] $1" >&2
    }
    
    log_error() {
        echo "[ERROR] $1" >&2
    }
    
    log_fatal() {
        echo "[FATAL] $1" >&2
    }
}

# 配置管理类
class_config_manager() {
    # 私有变量
    local _config_file=""
    local -A _config_values
    
    # 构造函数
    constructor() {
        _config_file="$1"
    }
    
    # 加载配置
    load_config() {
        if [ ! -f "$_config_file" ]; then
            return 1
        fi
        
        while IFS='=' read -r key value; do
            # 忽略注释和空行
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            
            # 去除空格
            key=$(echo "$key" | sed 's/^[ \t]*//;s/[ \t]*$//')
            value=$(echo "$value" | sed 's/^[ \t]*//;s/[ \t]*$//')
            
            _config_values["$key"]="$value"
        done < "$_config_file"
    }
    
    # 获取配置值
    get_config() {
        local key="$1"
        local default="$2"
        
        if [ -n "${_config_values[$key]}" ]; then
            echo "${_config_values[$key]}"
        else
            echo "$default"
        fi
    }
    
    # 设置配置值
    set_config() {
        local key="$1"
        local value="$2"
        
        _config_values["$key"]="$value"
    }
    
    # 保存配置
    save_config() {
        # 创建临时文件
        local temp_file=$(mktemp)
        
        # 写入配置
        for key in "${!_config_values[@]}"; do
            echo "$key=${_config_values[$key]}" >> "$temp_file"
        done
        
        # 替换原文件
        mv "$temp_file" "$_config_file"
    }
}

# 缓存管理类
class_cache_manager() {
    # 私有变量
    local -A _cache
    local _max_size=1000
    local _cleanup_threshold=800
    
    # 构造函数
    constructor() {
        if [ -n "$1" ]; then
            _max_size="$1"
        fi
        if [ -n "$2" ]; then
            _cleanup_threshold="$2"
        fi
    }
    
    # 获取缓存
    get_cache() {
        local key="$1"
        local default="$2"
        
        if [ -n "${_cache[$key]}" ]; then
            local cache_data=(${_cache[$key]})
            local timestamp=${cache_data[0]}
            local ttl=${cache_data[1]}
            local value=${cache_data[2]}
            
            # 检查是否过期
            local current_time=$(date +%s)
            if [ $((current_time - timestamp)) -lt "$ttl" ]; then
                echo "$value"
                return 0
            fi
        fi
        
        echo "$default"
        return 1
    }
    
    # 设置缓存
    set_cache() {
        local key="$1"
        local value="$2"
        local ttl="$3"
        
        # 检查缓存大小
        if [ ${#_cache[@]} -ge $_max_size ]; then
            cleanup_cache
        fi
        
        local timestamp=$(date +%s)
        _cache["$key"]="$timestamp $ttl $value"
    }
    
    # 清理过期缓存
    cleanup_cache() {
        local current_time=$(date +%s)
        local temp_cache=()
        
        # 遍历缓存
        for key in "${!_cache[@]}"; do
            local cache_data=(${_cache[$key]})
            local timestamp=${cache_data[0]}
            local ttl=${cache_data[1]}
            
            # 检查是否过期
            if [ $((current_time - timestamp)) -lt "$ttl" ]; then
                temp_cache["$key"]="${_cache[$key]}"
            fi
        done
        
        # 更新缓存
        _cache=()
        for key in "${!temp_cache[@]}"; do
            _cache["$key"]="${temp_cache[$key]}"
        done
    }
    
    # 清除所有缓存
    clear_cache() {
        _cache=()
    }
}

# 插件管理类
class_plugin_manager() {
    # 私有变量
    local _plugin_dir=""
    local -A _plugins
    
    # 构造函数
    constructor() {
        _plugin_dir="$1"
    }
    
    # 加载插件
    load_plugins() {
        if [ ! -d "$_plugin_dir" ]; then
            return 1
        fi
        
        # 遍历插件目录
        for plugin_file in "$_plugin_dir"/*.sh; do
            [ -f "$plugin_file" ] || continue
            
            # 获取插件名
            local plugin_name=$(basename "$plugin_file" .sh)
            
            # 加载插件
            source "$plugin_file"
            
            # 检查插件接口
            if type "plugin_${plugin_name}_init" &>/dev/null; then
                _plugins["$plugin_name"]="$plugin_file"
                "plugin_${plugin_name}_init"
            fi
        done
    }
    
    # 执行插件
    execute_plugin() {
        local plugin_name="$1"
        shift
        
        if [ -n "${_plugins[$plugin_name]}" ]; then
            if type "plugin_${plugin_name}_execute" &>/dev/null; then
                "plugin_${plugin_name}_execute" "$@"
                return $?
            fi
        fi
        
        return 1
    }
    
    # 获取已加载的插件列表
    get_loaded_plugins() {
        echo "${!_plugins[@]}"
    }
}

# 导出类
export -f class_base
export -f class_error_handler
export -f class_config_manager
export -f class_cache_manager
export -f class_plugin_manager 