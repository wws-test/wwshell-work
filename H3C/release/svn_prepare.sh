#!/bin/bash

#############################################################################
# 脚本名称: svn_prepare.sh
# 功能描述: 检查备份文件并准备SVN提交
#
# 主要功能:
# 1. 查找所有以 _bk 或 _300bk 结尾的备份文件夹，确认文件数量名称交给用户确认
# 2. 检查每个备份文件夹中的 MD5 校验和
# 3. 验证备份文件的完整性
# 4. 删除已成功备份的源文件
# 5. 移除备份文件夹的后缀 (_bk 或 _300bk)
# 6. 将重命名后的文件夹添加到 SVN
# 7. 记录所有操作到日志文件
#
# 使用方法:
#   bash svn_prepare.sh
#
# 日志说明:
# - 所有操作都记录在 logs/svn_operations.log 文件中
# - 包含每次操作的时间戳和详细状态
# - 记录所有新添加到SVN的文件（状态为A的文件）
#
# 输出说明:
# - 绿色: 正常信息
# - 黄色: 警告信息
# - 红色: 错误信息
#
# 注意事项:
# 1. 需要有 svn, md5sum 等基本命令
# 2. 只处理 _bk 和 _300bk 结尾的文件夹
# 3. 会检查 md5sums.txt 文件的存在和正确性
# 4. 所有操作都会保持单一日志文件，便于追踪
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

# 日志级别
declare -r LOG_INFO="INFO"
declare -r LOG_WARNING="WARNING"
declare -r LOG_ERROR="ERROR"

# 日志文件路径
declare -r LOG_DIR="/HDD_Raid/util_script/logs"
declare -r LOG_FILE="${LOG_DIR}/svn_operations.log"

# 创建日志目录
create_log_dir() {
    if [ ! -d "$LOG_DIR" ];then
        mkdir -p "$LOG_DIR" || {
            echo "无法创建日志目录: $LOG_DIR"
            return 1
        }
    fi
    
    # 如果日志文件不存在，创建它并添加文件头
    if [ ! -f "$LOG_FILE" ];then
        echo "=== SVN操作日志 ===" > "$LOG_FILE"
        echo "首次创建时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
        echo "----------------------------------------" >> "$LOG_FILE"
    fi
}

# 记录SVN文件状态到日志
log_svn_status() {
    local status_output
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "----------------------------------------" >> "$LOG_FILE"
    echo "[${timestamp}] SVN操作记录" >> "$LOG_FILE"
    echo "新添加的文件:" >> "$LOG_FILE"
    
    # 获取SVN状态并过滤出已添加的文件（状态为A的文件）
    status_output=$(svn status | grep '^A')
    if [ -n "$status_output" ];then
        echo "$status_output" >> "$LOG_FILE"
        echo "成功添加以上文件到SVN" >> "$LOG_FILE"
    else
        echo "没有新添加的文件" >> "$LOG_FILE"
    fi
    echo "----------------------------------------" >> "$LOG_FILE"
}

# 日志函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 控制台输出
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
    
    # 追加到日志文件
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# 检查系统依赖
check_dependencies() {
    local -r required_commands=("svn" "md5sum" "find")
    
    for cmd in "${required_commands[@]}";do
        if ! command -v "$cmd" &> /dev/null;then
            log_message "$LOG_ERROR" "必需的命令 '$cmd' 未找到，请先安装"
            return 1
        fi
    done
    return 0
}

# 显示所有要处理的文件夹并等待用户确认
show_and_confirm() {
    local -a backup_folders=("$@")
    local total=${#backup_folders[@]}
    
    echo -e "\n${YELLOW}找到以下备份文件夹及其对应的源文件：${NC}"
    echo -e "${YELLOW}----------------------------------------${NC}"
    
    for backup_folder in "${backup_folders[@]}"; do
        local source_folder
        if [[ "$backup_folder" == *"_300bk" ]]; then
            source_folder="${backup_folder%_300bk}"
        else
            source_folder="${backup_folder%_bk}"
        fi
        
        if [ -d "$source_folder" ]; then
            echo -e "${GREEN}备份文件夹:${NC} $backup_folder"
            echo -e "${GREEN}源文件夹:  ${NC} $source_folder"
            echo -e "${YELLOW}----------------------------------------${NC}"
        else
            echo -e "${GREEN}备份文件夹:${NC} $backup_folder"
            echo -e "${RED}源文件夹:  ${NC} $source_folder ${RED}(不存在)${NC}"
            echo -e "${YELLOW}----------------------------------------${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}总共发现 ${total} 个备份文件夹${NC}"
    echo -e "${YELLOW}请确认是否继续处理这些文件？[y/N]${NC}"
    
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_message "$LOG_INFO" "用户取消操作"
        return 1
    fi
    return 0
}

# 检查MD5并处理备份文件夹
process_backup_folder() {
    local backup_folder="$1"
    local source_folder
    if [[ "$backup_folder" == *"_300bk" ]]; then
        source_folder="${backup_folder%_300bk}"
    else
        source_folder="${backup_folder%_bk}"
    fi
    
    # 检查md5sums.txt是否存在
    if [ ! -f "${backup_folder}/md5sums.txt" ];then
        log_message "$LOG_ERROR" "文件夹 ${backup_folder} 中没有找到 md5sums.txt"
        return 1
    fi
    
    # 验证MD5校验和
    log_message "$LOG_INFO" "正在验证 ${backup_folder} 的MD5校验和..."
    if ! (cd "$backup_folder" && md5sum -c md5sums.txt &>/dev/null);then
        log_message "$LOG_ERROR" "MD5校验失败: ${backup_folder}"
        return 1
    fi
    
    # MD5校验成功，删除源文件夹
    if [ -d "$source_folder" ];then
        log_message "$LOG_INFO" "正在删除源文件夹: ${source_folder}"
        rm -rf "$source_folder" || {
            log_message "$LOG_ERROR" "删除源文件夹失败: ${source_folder}"
            return 1
        }
        
        # 删除成功后，将备份文件夹重命名（移除后缀）
        log_message "$LOG_INFO" "正在重命名备份文件夹..."
        mv "$backup_folder" "$source_folder" || {
            log_message "$LOG_ERROR" "重命名备份文件夹失败: ${backup_folder} -> ${source_folder}"
            return 1
        }
        log_message "$LOG_INFO" "成功重命名备份文件夹为: ${source_folder}"
    fi
    
    # 添加重命名后的文件夹到SVN
    log_message "$LOG_INFO" "正在将 ${source_folder} 添加到SVN..."
    svn add "$source_folder" --force &>/dev/null || {
        log_message "$LOG_ERROR" "添加到SVN失败: ${source_folder}"
        return 1
    }
    
    return 0
}

main() {
    # 创建日志目录
    create_log_dir || exit 1
    
    log_message "$LOG_INFO" "开始准备SVN提交..."
    
    # 检查依赖
    check_dependencies || exit 1
    
    # 查找所有备份文件夹（包括 _bk 和 _300bk）
    mapfile -t backup_folders < <(find . -type d \( -name "*_bk" -o -name "*_300bk" \))
    
    if [ ${#backup_folders[@]} -eq 0 ]; then
        log_message "$LOG_WARNING" "未找到任何备份文件夹"
        exit 0
    fi
    
    # 显示文件夹列表并等待用户确认
    if ! show_and_confirm "${backup_folders[@]}"; then
        exit 0
    fi
    
    log_message "$LOG_INFO" "用户确认继续处理..."
    
    # 统计信息
    local total_folders=${#backup_folders[@]}
    local success=0
    local failed=0
    
    # 处理每个备份文件夹
    for folder in "${backup_folders[@]}"; do
        if process_backup_folder "$folder"; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
    # 记录SVN状态到日志文件
    log_message "$LOG_INFO" "正在检查并记录SVN状态..."
    log_svn_status
    
    # 显示SVN状态
    svn status
    
    # 输出最终统计
    log_message "$LOG_INFO" "处理完成，总结："
    log_message "$LOG_INFO" "- 总文件夹数: $total_folders"
    log_message "$LOG_INFO" "- 成功处理: $success"
    log_message "$LOG_INFO" "- 处理失败: $failed"
    log_message "$LOG_INFO" "详细日志已保存到: $LOG_FILE"
}

# 执行主程序
main