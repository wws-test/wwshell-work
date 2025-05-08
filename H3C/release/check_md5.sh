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
#   - 日志文件位置: /HDD_Raid/log/md5_checks/
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
## 例如每天凌晨2点执行
#  0 2 * * * /HDD_Raid/util_script/check_md5.sh
# 作者: sww
# 创建日期: 2025-05-07
# 版本: 1.0
#############################################################################

# 设置日志文件路径和名称（使用日期作为文件名的一部分）
LOG_DIR="/HDD_Raid/log/md5_checks"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/md5_check_${DATE}.log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 初始化计数器
total_success=0
total_failed=0
total_missing_md5=0

# 写入日志头部
echo "MD5 Checksum Verification Report - ${DATE}" > "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 遍历目录函数
check_directory() {
    local dir="$1"
    local base_dir=$(basename "$dir")
    local missing_md5_dirs=()
    
    echo "Checking directory: $dir" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    # 首先找出所有最深层的目录
    while read -r leaf_dir; do
        # 检查此目录是否包含 md5sums.txt
        if [ ! -f "${leaf_dir}/md5sums.txt" ]; then
            missing_md5_dirs+=("$leaf_dir")
            total_missing_md5=$((total_missing_md5 + 1))
        fi
    done < <(find "$dir" -type d -links 2)
    
    # 记录没有 md5sums.txt 的目录
    if [ ${#missing_md5_dirs[@]} -gt 0 ]; then
        echo "Directories without md5sums.txt:" >> "$LOG_FILE"
        for missing_dir in "${missing_md5_dirs[@]}"; do
            echo "  - $missing_dir" >> "$LOG_FILE"
        done
        echo "" >> "$LOG_FILE"
    fi
    
    # 查找所有 md5sums.txt 文件
    find "$dir" -type f -name "md5sums.txt" | while read -r md5_file; do
        local check_dir=$(dirname "$md5_file")
        echo "Processing: $check_dir" >> "$LOG_FILE"
        
        # 切换到包含 md5sums.txt 的目录
        cd "$check_dir"
        
        # 运行 md5sum 检查并捕获输出
        if md5sum -c md5sums.txt > temp_result 2>&1; then
            # 成功的情况
            local success_count=$(grep -c ': OK' temp_result)
            total_success=$((total_success + success_count))
            echo "✓ All $success_count files verified successfully" >> "$LOG_FILE"
        else
            # 失败的情况
            local failed_files=$(grep -v ': OK' temp_result | grep -v 'WARNING')
            local failed_count=$(echo "$failed_files" | grep -c ': FAILED')
            total_failed=$((total_failed + failed_count))
            
            echo "✗ Found $failed_count failures:" >> "$LOG_FILE"
            echo "$failed_files" >> "$LOG_FILE"
        fi
        
        rm -f temp_result
        echo "" >> "$LOG_FILE"
    done
}

# 主程序开始
echo "Starting MD5 verification process..." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 检查 Model 目录
if [ -d "/HDD_Raid/SVN_MODEL_REPO/Model" ]; then
    echo "Checking Model directory..." >> "$LOG_FILE"
    check_directory "/HDD_Raid/SVN_MODEL_REPO/Model"
fi

# 检查 Vendor 目录
if [ -d "/HDD_Raid/SVN_MODEL_REPO/Vendor" ]; then
    echo "Checking Vendor directory..." >> "$LOG_FILE"
    check_directory "/HDD_Raid/SVN_MODEL_REPO/Vendor"
fi

# 写入总结报告
echo "Summary" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "Total successful verifications: $total_success" >> "$LOG_FILE"
echo "Total failed verifications: $total_failed" >> "$LOG_FILE"
echo "Total directories missing md5sums.txt: $total_missing_md5" >> "$LOG_FILE"
echo "End of report - $(date)" >> "$LOG_FILE"

# 如果有失败的检查，退出码为1
if [ $total_failed -gt 0 ]; then
    exit 1
fi

exit 0 