#!/bin/bash

#############################################################################
# 脚本名称: check_md5.sh
# 描述: 自动检查指定目录下所有md5sums.txt文件的校验结果
#
# 功能:
#   - 遍历 /HDD_Raid/SVN_MODEL_REPO 下的 Model 和 Vendor 目录
#   - 查找并验证所有 md5sums.txt 文件
#   - 生成详细的检查报告
#   - 记录所有检查结果到日志文件
#
# 用法: ./check_md5.sh
#
# 输出:
#   - 日志文件位置: /var/log/md5_checks/
#   - 日志命名格式: md5_check_YYYY-MM-DD_HH-MM-SS.log
#
# 返回值:
#   - 0: 所有检查都成功
#   - 1: 存在检查失败的文件
#
# 依赖:
#   - md5sum 命令
#   - find 命令
#   - 需要对日志目录的写入权限
#
# 作者: Claude
# 创建日期: 2024-03-19
# 版本: 1.0
#############################################################################

# 定义颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 输出函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "$1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "$1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$1" >> "$LOG_FILE"
}

# 设置日志文件路径和名称（使用日期作为文件名的一部分）
LOG_DIR="/var/log/md5_checks"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/md5_check_${DATE}.log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"
log_info "日志文件创建在: $LOG_FILE"

# 初始化计数器
total_success=0
total_failed=0
total_md5sums_files=0
total_md5_checks=0

# 写入日志头部
log_info "MD5 Checksum Verification Report - ${DATE}"
echo "=========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 遍历目录函数
check_directory() {
    local dir="$1"
    local base_dir=$(basename "$dir")
    
    log_info "正在检查目录: $dir"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    # 查找所有 md5sums.txt 文件
    local md5_files_count=$(find "$dir" -type f -name "md5sums.txt" | wc -l)
    total_md5sums_files=$((total_md5sums_files + md5_files_count))
    log_info "找到 $md5_files_count 个 md5sums.txt 文件待检查"
    
    find "$dir" -type f -name "md5sums.txt" | while read -r md5_file; do
        local check_dir=$(dirname "$md5_file")
        log_info "处理: $check_dir"
        
        # 切换到包含 md5sums.txt 的目录
        cd "$check_dir"
        
        # 获取当前md5sums.txt中的MD5值数量
        local current_md5_count=$(wc -l < md5sums.txt)
        total_md5_checks=$((total_md5_checks + current_md5_count))
        
        # 运行 md5sum 检查并捕获输出
        if md5sum -c md5sums.txt > temp_result 2>&1; then
            # 成功的情况
            local success_count=$(grep -c ': OK' temp_result)
            total_success=$((total_success + success_count))
            log_info "✓ 成功验证 $success_count 个文件"
        else
            # 失败的情况
            local failed_files=$(grep -v ': OK' temp_result | grep -v 'WARNING')
            local failed_count=$(echo "$failed_files" | grep -c ': FAILED')
            total_failed=$((total_failed + failed_count))
            
            log_error "✗ 发现 $failed_count 个失败:"
            echo "$failed_files" | while read -r line; do
                log_error "  - $line"
            done
        fi
        
        rm -f temp_result
        echo "" >> "$LOG_FILE"
    done
}

# 主程序开始
log_info "开始 MD5 验证进程..."
echo "" >> "$LOG_FILE"

# 检查 Model 目录
if [ -d "/HDD_Raid/SVN_MODEL_REPO/Model" ]; then
    log_info "检查 Model 目录..."
    check_directory "/HDD_Raid/SVN_MODEL_REPO/Model"
else
    log_warning "Model 目录不存在: /HDD_Raid/SVN_MODEL_REPO/Model"
fi

# 检查 Vendor 目录
if [ -d "/HDD_Raid/SVN_MODEL_REPO/Vendor" ]; then
    log_info "检查 Vendor 目录..."
    check_directory "/HDD_Raid/SVN_MODEL_REPO/Vendor"
else
    log_warning "Vendor 目录不存在: /HDD_Raid/SVN_MODEL_REPO/Vendor"
fi

# 写入总结报告
log_info "检查完成！生成总结报告..."
echo "Summary" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# 详细的总结信息
log_info "巡检总结:"
log_info "----------------------------------------"
log_info "总共找到 $total_md5sums_files 个 md5sums.txt 文件"
log_info "总计需要验证 $total_md5_checks 个 MD5 值"
if [ $total_failed -eq 0 ]; then
    log_info "本次巡检未发现任何 MD5 值不匹配"
    log_info "所有 $total_success 个文件验证通过"
else
    log_info "本次巡检发现 $total_failed 个 MD5 值不匹配"
    log_info "成功验证: $total_success 个文件"
    log_error "失败验证: $total_failed 个文件"
fi
log_info "----------------------------------------"

echo "End of report - $(date)" >> "$LOG_FILE"

# 如果有失败的检查，退出码为1
if [ $total_failed -gt 0 ]; then
    log_error "检查完成，但存在失败项，请查看日志文件了解详情"
    exit 1
fi

log_info "所有检查均已成功完成！"
exit 0 