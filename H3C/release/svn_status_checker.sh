#!/bin/bash

#############################################################################
# 脚本名称: svn_status_checker.sh
# 功能描述: SVN状态检查工具 - 重构版
#
# 主要功能:
# 1. 检查指定厂商目录的SVN状态
# 2. 智能判断SVN工作区位置
# 3. 显示未提交的文件和目录结构
# 4. 支持大文件大小显示
#
# 作者: sww
# 创建日期: 2025-05-08
#############################################################################

# 样式定义
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'

# 表格样式
TABLE_HEADER="------------------------------------------------------------------------------------------------"
FORMAT_STRING="%-70s %-10s %s\n"
SUB_FORMAT_STRING="  ├─ %-66s %-10s %s\n"
LAST_SUB_FORMAT_STRING="  └─ %-66s %-10s %s\n"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 获取文件夹大小（GB）
get_folder_size() {
    local dir="$1"
    local size
    size=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    if [ $? -eq 0 ]; then
        echo $((size/1024/1024/1024))
    else
        echo 0
    fi
}

# 检查空文件夹
is_empty_dir() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir")" ]]
}

# 检查目录的SVN状态
check_svn_status() {
    local dir="$1"
    local status_output
    
    # 备份当前目录
    local current_dir=$(pwd)
    
    # 查找最近的SVN工作目录
    local check_dir="$dir"
    while [ "$check_dir" != "/" ] && [ -n "$check_dir" ]; do
        if [ -d "$check_dir/.svn" ]; then
            break
        fi
        check_dir=$(dirname "$check_dir")
    done
    
    # 如果找不到.svn目录，返回错误
    if [ "$check_dir" = "/" ] || [ -z "$check_dir" ]; then
        log_error "无法找到SVN工作目录: $dir"
        return 1
    fi
    
    # 切换到SVN工作目录
    cd "$check_dir" || return 1
    
    # 获取相对于SVN工作目录的路径
    local rel_path="${dir#$check_dir/}"
    [ "$rel_path" = "$dir" ] && rel_path=""
    
    # 先检查是否有未版本控制的文件
    local has_content=false
    local unversioned_files=$(svn status | grep ? | sort)
    
    if [ -n "$unversioned_files" ]; then
        # 如果指定了特定目录，检查是否有相关的未版本控制文件
        if [ -n "$rel_path" ]; then
            while IFS= read -r line; do
                local path="${line:8}"
                if [[ "$path" == "$rel_path"* ]]; then
                    has_content=true
                    break
                fi
            done <<< "$unversioned_files"
        else
            has_content=true
        fi
    fi
    
    # 只有在有未版本控制文件时才显示表格
    if $has_content; then
        echo -e "\n${BLUE}检查目录: $dir${NC} ${BLUE}SVN工作目录: $check_dir${NC}"
        echo "$TABLE_HEADER"
        printf "$FORMAT_STRING" "路径" "类型" "状态"
        echo "$TABLE_HEADER"
        
        # 处理每个未版本控制的文件
        while IFS= read -r line; do
            local status_char="${line:0:1}"
            local path="${line:8}"
            
            # 如果指定了特定目录，只处理该目录下的条目
            if [ -n "$rel_path" ] && [[ "$path" != "$rel_path"* ]]; then
                continue
            fi
            
            local full_path="$check_dir/$path"
            
            # 设置类型和状态
            local type_desc
            local status_desc
            
            if [ -d "$full_path" ]; then
                type_desc="目录"
                if ! is_empty_dir "$full_path"; then
                    local size=$(get_folder_size "$full_path")
                    if [ "$size" -gt 300 ]; then
                        status_desc="未版本控制 (${size}GB)"
                    else
                        status_desc="未版本控制"
                    fi
                else
                    status_desc="空目录"
                fi
            else
                type_desc="文件"
                status_desc="未版本控制"
            fi
            
            [ "$status_char" = "!" ] && status_desc="缺失"
            
            # 显示相对于检查目录的路径
            local display_path="$path"
            [ -n "$rel_path" ] && display_path="${path#$rel_path/}"
            
            printf "$FORMAT_STRING" "$display_path" "$type_desc" "$status_desc"
            
            # 如果是目录，显示其内容
            if [ -d "$full_path" ] && ! is_empty_dir "$full_path" ]; then
                (cd "$full_path" && find . -maxdepth 1 -mindepth 1 -type d | sort | while read -r subdir; do
                    local sub_path="${subdir#./}"
                    if [ -d "$full_path/$sub_path" ]; then
                        local sub_size=$(get_folder_size "$full_path/$sub_path")
                        local sub_status="未版本控制"
                        [ "$sub_size" -gt 300 ] && sub_status="未版本控制 (${sub_size}GB)"
                        printf "$SUB_FORMAT_STRING" "$sub_path" "子目录" "$sub_status"
                    fi
                done)
            fi
        done <<< "$unversioned_files"
        
        echo "$TABLE_HEADER"
    else
        log_info "目录 ${dir} 中没有发现未版本控制的文件"
    fi
    
    # 恢复原目录
    cd "$current_dir"
    return 0
}

# 主函数
main() {
    echo "SVN 状态检查结果"
    echo "================"
    
    # 检查命令
    if ! command -v svn &> /dev/null; then
        log_error "未找到svn命令，请确保已安装SVN客户端"
        exit 1
    fi
    
    # 获取当前目录
    local base_dir="/HDD_Raid/SVN_MODEL_REPO/Vendor"
    
    # 检查特定厂商目录
    local vendors=("Iluvatar" "Kunlunxin" "MetaX" "Cambricon" "Enflame" "Moffett")
    
    local found_unversioned=false
    for vendor in "${vendors[@]}"; do
        local check_path="$base_dir/$vendor"
        
        # 对于Kunlunxin，检查二级目录
        if [ "$vendor" = "Kunlunxin" ] && [ -d "$check_path/Kunlunxin" ]; then
            check_path="$check_path/Kunlunxin"
        fi
        
        if check_svn_status "$check_path"; then
            found_unversioned=true
        fi
    done
    
    if $found_unversioned; then
        echo -e "\n${GREEN}检查完成${NC}"
    else
        echo -e "\n${GREEN}检查完成，所有文件都在版本控制之下${NC}"
    fi
}

# 执行主程序
main