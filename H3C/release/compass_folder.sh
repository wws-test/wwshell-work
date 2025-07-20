#!/bin/bash

#############################################################################
# 脚本名称: compass_folder.sh
# 功能描述: 自动压缩和备份未被SVN管理的文件夹，准备SVN提交
#
# 主要功能:
# 1. 自动识别当前目录下未被SVN管理的文件夹
# 2. 为每个文件夹创建对应的 _bk 备份文件夹
# 3. 对源文件夹进行压缩（tar.gz格式）
# 4. 移动压缩文件到备份文件夹
# 5. 生成文件的 MD5 校验值（md5sums.txt）
# 6. 大于300GB的文件夹特殊处理
# 7. 自动清理不完整的备份
#
# 使用方法:
#   bash compass_folder.sh
#
# 文件处理流程:
# 1. 检查文件夹大小和有效性
# 2. 创建备份文件夹（xxx_bk）
# 3. 压缩源文件夹
# 4. 生成MD5校验文件
# 5. 验证备份完整性
#
#
# 注意事项:
# 1. 需要有 svn, tar, awk, grep 等基本命令
# 2. 会跳过以下内容:
#    - 空文件夹
#    - 大于300GB的文件夹
#    - 已存在的 tar.gz 文件
#    - 已存在的 _bk，_300bk 文件夹
# 3. 自动清理不完整或失败的备份
#
# 作者: sww
# 创建日期: 2025-05-07
# 最后修改: 2025-05-08
#############################################################################

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 声明变量
declare -a unmanaged_folders  # 存储未被SVN管理的文件夹列表
declare backup_folder_path    # 备份文件夹的完整路径
declare -r TIMESTAMP_FORMAT='+%Y-%m-%d %H:%M:%S'  # 时间戳格式

# 日志级别
declare -r LOG_INFO="INFO"
declare -r LOG_WARNING="WARNING"
declare -r LOG_ERROR="ERROR"

# 日志输出函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "${TIMESTAMP_FORMAT}")
    
    case "$level" in
        "$LOG_INFO")
            echo -e "[${timestamp}] ${GREEN}[${level}]${NC} ${message}"
            ;;
        "$LOG_WARNING")
            echo -e "[${timestamp}] ${YELLOW}[${level}]${NC} ${message}" >&2
            ;;
        "$LOG_ERROR")
            echo -e "[${timestamp}] ${RED}[${level}]${NC} ${message}" >&2
            ;;
    esac
}

# 检查系统依赖
check_dependencies() {
    local -r required_commands=("svn" "tar" "awk" "grep")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_message "$LOG_ERROR" "必需的命令 '$cmd' 未找到，请先安装"
            return 1
        fi
    done
    return 0
}

# 清理临时文件
cleanup_temp_files() {
    local folder="$1"
    # 如果压缩文件存在但移动失败，则删除它
    if [ -f "${folder}.tar.gz" ]; then
        rm -f "${folder}.tar.gz"
        log_message "$LOG_INFO" "清理临时文件 ${folder}.tar.gz"
    fi
}

get_folder_size() {
    local folder="$1"
    local size_in_bytes
    size_in_bytes=$(du -sb "$folder" 2>/dev/null | awk '{print $1}')
    echo $((size_in_bytes / 1024 / 1024 / 1024)) # 转换为GB
}

# 处理大文件夹，将其分片打包
process_large_folder() {
    local folder="$1"
    local success=true
    local -r MAX_SIZE=280 # 每个tar包最大尺寸(GB)
    local backup_folder="${folder}_bk"
    
    log_message "$LOG_INFO" "处理大文件夹: $folder (分片打包模式)"
    
    # 创建备份文件夹
    mkdir -p "$backup_folder" || {
        log_message "$LOG_ERROR" "创建备份文件夹失败: $backup_folder"
        return 1
    }
    
    # 进入源文件夹
    cd "$folder" || return 1
    
    # 计算总大小(GB)和预估分片数
    local total_size=$(get_folder_size ".")
    local estimated_parts=$(( (total_size + MAX_SIZE - 1) / MAX_SIZE ))
    
    log_message "$LOG_INFO" "文件夹大小: ${total_size}GB, 预计分: $estimated_parts 片"
    
    # 创建临时文件列表
    local file_list="/tmp/tar_files_$$.txt"
    find . -type f -print0 | xargs -0 ls -l | sort -k5 -nr | awk '{print $NF}' > "$file_list"
    
    # 初始化变量
    local current_size=0
    local current_files=()
    local part=1
    
    # 读取文件列表并分组
    while IFS= read -r file; do
        # 获取单个文件大小(bytes转GB)
        local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
        file_size=$(( file_size / 1024 / 1024 / 1024 ))
        
        # 如果当前文件过大，单独打包
        if [ "$file_size" -gt "$MAX_SIZE" ]; then
            log_message "$LOG_WARNING" "文件过大，单独打包: $file ($file_size GB)"
            tar -czf "../${backup_folder}/$(basename "$folder")_single_${part}.tar.gz" "$file" || {
                log_message "$LOG_ERROR" "打包失败: $file"
                continue
            }
            ((part++))
            continue
        fi
        
        # 累计大小超过限制时，打包当前组
        if [ "$((current_size + file_size))" -gt "$MAX_SIZE" ] && [ "${#current_files[@]}" -gt 0 ]; then
            log_message "$LOG_INFO" "打包分片 $part (${current_size}GB)"
            tar -czf "../${backup_folder}/$(basename "$folder")_part${part}.tar.gz" "${current_files[@]}" || {
                log_message "$LOG_ERROR" "打包分片 $part 失败"
                success=false
                break
            }
            ((part++))
            current_size=0
            current_files=()
        fi
        
        # 添加文件到当前组
        current_files+=("$file")
        current_size=$((current_size + file_size))
    done < "$file_list"
    
    # 处理最后一组文件
    if [ "${#current_files[@]}" -gt 0 ]; then
        log_message "$LOG_INFO" "打包最后一个分片 $part (${current_size}GB)"
        tar -czf "../${backup_folder}/$(basename "$folder")_part${part}.tar.gz" "${current_files[@]}" || {
            log_message "$LOG_ERROR" "打包最后一个分片失败"
            success=false
        }
    fi
    
    # 清理临时文件
    rm -f "$file_list"
    
    # 生成完整的md5sums文件
    cd "../$backup_folder" || return 1
    log_message "$LOG_INFO" "生成MD5校验文件..."
    find . -type f ! -name "md5sums.txt" -exec md5sum {} \; > md5sums.txt
    
    # 生成分片信息文件
    {
        echo "分片信息:"
        echo "总大小: ${total_size}GB"
        echo "分片数量: $part"
        echo "分片列表:"
        ls -lh *.tar.gz
    } > split_info.txt
    
    if $success; then
        log_message "$LOG_INFO" "成功完成分片打包: $folder (共 $part 个分片)"
        return 0
    else
        log_message "$LOG_ERROR" "分片打包过程中出现错误"
        return 1
    fi
}

# 主处理函数
process_folder() {
    local folder="$1"
    local success=true
    
    # 检查文件夹是否为空
    if [ -z "$(ls -A "$folder" 2>/dev/null)" ]; then
        log_message "$LOG_WARNING" "文件夹 $folder 为空，跳过处理"
        return 0
    fi
    
    # 检查文件夹大小
    local folder_size
    folder_size=$(get_folder_size "$folder")
    
    # 如果大于300GB，使用特殊处理
    if [ "$folder_size" -gt 300 ]; then
        process_large_folder "$folder"
        return $?
    fi
    
    # 创建备份文件夹
    backup_folder_path="${folder}_bk"
    mkdir -p "$backup_folder_path" || {
        log_message "$LOG_ERROR" "创建备份文件夹 $backup_folder_path 失败"
        return 1
    }
    
    # 压缩文件夹
    log_message "$LOG_INFO" "开始压缩文件夹: $folder"
    tar -czf "${folder}.tar.gz" "$folder" 2>/dev/null || {
        log_message "$LOG_ERROR" "压缩 $folder 失败"
        cleanup_temp_files "$folder"
        return 1
    }
    
    # 移动文件到备份文件夹
    mv "${folder}.tar.gz" "$backup_folder_path/" || {
        log_message "$LOG_ERROR" "移动 ${folder}.tar.gz 到 $backup_folder_path 失败"
        cleanup_temp_files "$folder"
        return 1
    }
    
    log_message "$LOG_INFO" "成功处理文件夹 $folder"
    # 进入备份文件夹并生成md5sums.txt
    (cd "$backup_folder_path" && find . -type f ! -name "md5sums.txt" -exec md5sum {} \; > md5sums.txt) || {
        log_message "$LOG_WARNING" "生成 md5sums.txt 失败"
    }
    
    return 0
}

# 主程序开始
log_message "$LOG_INFO" "开始执行文件夹压缩备份任务"

# 检查系统依赖
check_dependencies || exit 1

# 获取未被SVN管理的文件夹列表，跳过 .tar.gz 文件、_bk 和 _300bk 备份文件夹
mapfile -t unmanaged_folders < <(svn status | grep '^?' | awk '{print $2}' | grep -vE '\.tar(\.gz)?$|_bk$|_300bk$')

# 检查是否找到未管理的文件夹
if [ ${#unmanaged_folders[@]} -eq 0 ]; then
    log_message "$LOG_WARNING" "未找到未被SVN管理的文件夹"
    exit 0
fi

# 显示可选择的文件夹列表
echo -e "\n${YELLOW}=== 未被SVN管理的文件夹列表 ===${NC}"
echo -e "序号  大小(GB)  文件夹路径"
echo -e "--------------------------------"
for i in "${!unmanaged_folders[@]}"; do
    folder="${unmanaged_folders[$i]}"
    size=$(get_folder_size "$folder")
    printf "${GREEN}%3d   %6d    %s${NC}\n" "$((i+1))" "$size" "$folder"
done

# 用户选择提示
echo -e "\n${YELLOW}请选择要处理的文件夹:${NC}"
echo "选项:"
echo "  - 输入序号(如: 1 3 5)选择多个文件夹"
echo "  - 输入 'all' 处理所有文件夹"
echo "  - 输入 'q' 退出程序"
echo -n "> "
read -r selection

# 处理用户输入
if [[ "$selection" == "q" ]]; then
    log_message "$LOG_INFO" "用户取消操作"
    exit 0
fi

declare -a selected_folders

if [[ "$selection" == "all" ]]; then
    selected_folders=("${unmanaged_folders[@]}")
    log_message "$LOG_INFO" "已选择全部文件夹"
else
    # 解析用户选择的序号
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && ((num > 0)) && ((num <= ${#unmanaged_folders[@]})); then
            selected_folders+=("${unmanaged_folders[$((num-1))]}")
        else
            log_message "$LOG_WARNING" "无效的选择: $num, 已跳过"
        fi
    done
fi

# 如果没有选择任何文件夹，退出
if [ ${#selected_folders[@]} -eq 0 ]; then
    log_message "$LOG_ERROR" "未选择任何有效的文件夹"
    exit 1
fi

# 确认用户选择
echo -e "\n${YELLOW}已选择以下文件夹:${NC}"
for folder in "${selected_folders[@]}"; do
    size=$(get_folder_size "$folder")
    echo -e "${GREEN}- $folder (${size}GB)${NC}"
done

echo -ne "\n${YELLOW}确认处理这些文件夹? (y/n):${NC} "
read -r confirm

if [[ "$confirm" != "y" ]]; then
    log_message "$LOG_INFO" "用户取消操作"
    exit 0
fi

# 统计信息
declare -i total_folders=${#unmanaged_folders[@]}
declare -i processed=0
declare -i success=0
declare -i failed=0
# 检查备份是否已完成
check_backup_completed() {
    local folder="$1"
    local backup_folder_bk="${folder}_bk"
    local backup_folder_300bk="${folder}_300bk"
    
    # 检查普通备份文件夹
    if [ -d "$backup_folder_bk" ] && [ -f "${backup_folder_bk}/md5sums.txt" ]; then
        # 检查压缩文件是否存在
        if [ -f "${backup_folder_bk}/${folder}.tar.gz" ]; then
            # 验证md5文件不为空
            if [ -s "${backup_folder_bk}/md5sums.txt" ]; then
                return 0  # 备份完成
            fi
        fi
    fi
    
    # 检查大文件备份文件夹
    if [ -d "$backup_folder_300bk" ] && [ -f "${backup_folder_300bk}/md5sums.txt" ]; then
        # 验证md5文件不为空
        if [ -s "${backup_folder_300bk}/md5sums.txt" ]; then
            return 0  # 备份完成
        fi
    fi
    
    return 1  # 备份未完成
}

# 清理不完整的备份
cleanup_incomplete_backup() {
    local folder="$1"
    local backup_folder_bk="${folder}_bk"
    local backup_folder_300bk="${folder}_300bk"
    
    # 如果普通备份文件夹存在，删除它
    if [ -d "$backup_folder_bk" ]; then
        log_message "$LOG_INFO" "清理不完整的备份文件夹: $backup_folder_bk"
        rm -rf "$backup_folder_bk"
    fi
    
    # 如果大文件备份文件夹存在，删除它
    if [ -d "$backup_folder_300bk" ]; then
        log_message "$LOG_INFO" "清理不完整的备份文件夹: $backup_folder_300bk"
        rm -rf "$backup_folder_300bk"
    fi
    
    # 如果压缩文件存在，删除它
    if [ -f "${folder}.tar.gz" ]; then
        log_message "$LOG_INFO" "清理残留的压缩文件: ${folder}.tar.gz"
        rm -f "${folder}.tar.gz"
    fi
}
# 处理选中的文件夹
for folder in "${selected_folders[@]}"; do
    ((processed++))
    
    # 显示处理进度
    log_message "$LOG_INFO" "处理进度: $processed/$total_folders - 当前处理: $folder"
    
    # 检查是否为有效文件夹
    if [ ! -d "$folder" ]; then
        log_message "$LOG_WARNING" "$folder 不是有效的文件夹，跳过处理"
        ((failed++))
        continue
    fi
    
    # 检查备份是否已完成
    if check_backup_completed "$folder"; then
        log_message "$LOG_INFO" "文件夹 $folder 已完成备份，跳过处理"
        ((success++))
        continue
    else
        # 如果存在不完整的备份，清理它
        cleanup_incomplete_backup "$folder"
    fi
    
    # 处理文件夹
    if process_folder "$folder"; then
        ((success++))
    else
        ((failed++))
        # 清理失败的备份
        cleanup_incomplete_backup "$folder"
    fi
done 

# 输出处理结果统计
log_message "$LOG_INFO" "处理完成，总结："
log_message "$LOG_INFO" "- 总文件夹数: $total_folders"
log_message "$LOG_INFO" "- 成功处理: $success"
log_message "$LOG_INFO" "- 处理失败: $failed"

exit 0
