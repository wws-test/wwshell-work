#!/bin/bash
#############################################################################
# 脚本名称: check_md5.sh
# 描述: 自动检查指定目录下所有md5sums.txt文件的校验结果，并验证Vendor目录结构是否符合规范
#
# 功能:
#   - 遍历 /HDD_Raid/SVN_MODEL_REPO 下的 Model 和 Vendor 目录
#   - 查找并验证所有 md5sums.txt 文件
#   - 验证Vendor目录结构是否符合JSON Schema定义的规范
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
#   - tree 命令 (用于生成目录结构JSON)
#   - jq 命令 (用于处理JSON)
#   - python3 (用于目录结构验证)
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

# 初始化计数器和临时文件
TEMP_DIR=$(mktemp -d)

# Model目录统计
MODEL_SUCCESS_COUNT_FILE="${TEMP_DIR}/model_success_count"
MODEL_FAILED_COUNT_FILE="${TEMP_DIR}/model_failed_count"
MODEL_MISSING_COUNT_FILE="${TEMP_DIR}/model_missing_count"
MODEL_MD5_FILES_COUNT_FILE="${TEMP_DIR}/model_md5_files_count"

# Vendor目录统计
VENDOR_SUCCESS_COUNT_FILE="${TEMP_DIR}/vendor_success_count"
VENDOR_FAILED_COUNT_FILE="${TEMP_DIR}/vendor_failed_count"
VENDOR_MISSING_COUNT_FILE="${TEMP_DIR}/vendor_missing_count"
VENDOR_MD5_FILES_COUNT_FILE="${TEMP_DIR}/vendor_md5_files_count"

# 初始化所有计数器文件
for file in "$MODEL_SUCCESS_COUNT_FILE" "$MODEL_FAILED_COUNT_FILE" "$MODEL_MISSING_COUNT_FILE" \
           "$VENDOR_SUCCESS_COUNT_FILE" "$VENDOR_FAILED_COUNT_FILE" "$VENDOR_MISSING_COUNT_FILE" \
           "$MODEL_MD5_FILES_COUNT_FILE" "$VENDOR_MD5_FILES_COUNT_FILE"; do
    echo "0" > "$file"
done

# 设置目录结构验证相关的变量
TREE_JSON="/HDD_Raid/util_script/tmp/vendor_tree.json"
SCHEMA_FILE="/HDD_Raid/util_script/vendor_schema.json"
PYTHON_VALIDATOR="/HDD_Raid/util_script/validate_vendor_structure.py"

# 写入日志头部
echo "MD5 Checksum Verification Report - ${DATE}" > "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 在主程序开始之前添加目录结构验证
echo "正在验证Vendor目录结构..." >> "$LOG_FILE"
if [ -d "/HDD_Raid/SVN_MODEL_REPO/Vendor" ]; then
    # 生成目录结构的JSON
    if ! tree -J /HDD_Raid/SVN_MODEL_REPO/Vendor | jq . > "$TREE_JSON"; then
        echo "错误：无法生成目录结构JSON" >> "$LOG_FILE"
        exit 1
    fi

    # 验证目录结构
    if ! python3 "$PYTHON_VALIDATOR" "$TREE_JSON" "$SCHEMA_FILE"; then
        echo "错误：Vendor目录结构验证失败" >> "$LOG_FILE"
        echo "请检查目录结构是否符合规范" >> "$LOG_FILE"
        exit 1
    fi
    echo "Vendor目录结构验证通过" >> "$LOG_FILE"
fi

# 遍历目录函数
check_directory() {
    local dir="$1"
    local dir_type="$2"  # "Model" 或 "Vendor"
    local base_dir=$(basename "$dir")
    
    echo "Checking directory: $dir" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    # 设置对应的计数器文件
    local SUCCESS_COUNT_FILE
    local FAILED_COUNT_FILE
    local MISSING_COUNT_FILE
    local MD5_FILES_COUNT_FILE
    
    if [ "$dir_type" == "Model" ]; then
        SUCCESS_COUNT_FILE="$MODEL_SUCCESS_COUNT_FILE"
        FAILED_COUNT_FILE="$MODEL_FAILED_COUNT_FILE"
        MISSING_COUNT_FILE="$MODEL_MISSING_COUNT_FILE"
        MD5_FILES_COUNT_FILE="$MODEL_MD5_FILES_COUNT_FILE"
    else
        SUCCESS_COUNT_FILE="$VENDOR_SUCCESS_COUNT_FILE"
        FAILED_COUNT_FILE="$VENDOR_FAILED_COUNT_FILE"
        MISSING_COUNT_FILE="$VENDOR_MISSING_COUNT_FILE"
        MD5_FILES_COUNT_FILE="$VENDOR_MD5_FILES_COUNT_FILE"
    fi
    
    # 首先找出所有最深层的目录
    while read -r leaf_dir; do
        # 检查此目录是否包含 md5sums.txt
        if [ ! -f "${leaf_dir}/md5sums.txt" ]; then
            local current_missing=$(($(cat "$MISSING_COUNT_FILE") + 1))
            echo "$current_missing" > "$MISSING_COUNT_FILE"
        fi
    done < <(find "$dir" -type d -links 2)
    
    # 统计md5sums.txt文件数量
    local md5_files_count=$(find "$dir" -type f -name "md5sums.txt" | wc -l)
    echo "$md5_files_count" > "$MD5_FILES_COUNT_FILE"
    
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
            local current_success=$(($(cat "$SUCCESS_COUNT_FILE") + success_count))
            echo "$current_success" > "$SUCCESS_COUNT_FILE"
            echo "✓ All $success_count files verified successfully" >> "$LOG_FILE"
        else
            # 失败的情况
            local failed_files=$(grep -v ': OK' temp_result | grep -v 'WARNING')
            local failed_count=$(echo "$failed_files" | grep -c ': FAILED')
            local current_failed=$(($(cat "$FAILED_COUNT_FILE") + failed_count))
            echo "$current_failed" > "$FAILED_COUNT_FILE"
            
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
    check_directory "/HDD_Raid/SVN_MODEL_REPO/Model" "Model"
fi

# 检查 Vendor 目录
if [ -d "/HDD_Raid/SVN_MODEL_REPO/Vendor" ]; then
    echo "Checking Vendor directory..." >> "$LOG_FILE"
    check_directory "/HDD_Raid/SVN_MODEL_REPO/Vendor" "Vendor"
fi

# 读取所有统计数据
model_success=$(cat "$MODEL_SUCCESS_COUNT_FILE")
model_failed=$(cat "$MODEL_FAILED_COUNT_FILE")
model_missing_md5=$(cat "$MODEL_MISSING_COUNT_FILE")
model_md5_files=$(cat "$MODEL_MD5_FILES_COUNT_FILE")

vendor_success=$(cat "$VENDOR_SUCCESS_COUNT_FILE")
vendor_failed=$(cat "$VENDOR_FAILED_COUNT_FILE")
vendor_missing_md5=$(cat "$VENDOR_MISSING_COUNT_FILE")
vendor_md5_files=$(cat "$VENDOR_MD5_FILES_COUNT_FILE")

# 计算总数
total_success=$((model_success + vendor_success))
total_failed=$((model_failed + vendor_failed))
total_missing_md5=$((model_missing_md5 + vendor_missing_md5))
total_md5_files=$((model_md5_files + vendor_md5_files))

# 写入详细的统计报告
echo "统计报告" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "Model 目录统计：" >> "$LOG_FILE"
echo "- md5sums.txt 文件总数：$model_md5_files" >> "$LOG_FILE"
echo "- 成功校验文件数：$model_success" >> "$LOG_FILE"
[ $model_failed -gt 0 ] && echo "- 校验失败文件数：$model_failed" >> "$LOG_FILE"
echo "- 缺少md5sums.txt的目录数：$model_missing_md5" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "Vendor 目录统计：" >> "$LOG_FILE"
echo "- md5sums.txt 文件总数：$vendor_md5_files" >> "$LOG_FILE"
echo "- 成功校验文件数：$vendor_success" >> "$LOG_FILE"
[ $vendor_failed -gt 0 ] && echo "- 校验失败文件数：$vendor_failed" >> "$LOG_FILE"
echo "- 缺少md5sums.txt的目录数：$vendor_missing_md5" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "总体统计：" >> "$LOG_FILE"
echo "- md5sums.txt 文件总数：$total_md5_files" >> "$LOG_FILE"
[ $total_success -gt 0 ] && echo "- 总成功校验文件数：$total_success" >> "$LOG_FILE"
[ $total_failed -gt 0 ] && echo "- 总校验失败文件数：$total_failed" >> "$LOG_FILE"
echo "- 总缺少md5sums.txt的目录数：$total_missing_md5" >> "$LOG_FILE"
echo "检查完成时间: $(date)" >> "$LOG_FILE"

# 清理临时文件
rm -rf "$TEMP_DIR"

# 如果有失败的检查，退出码为1
if [ $total_failed -gt 0 ]; then
    exit 1
fi

exit 0