#!/bin/bash

#############################################################################
# 脚本名称: check_doc_files.sh
# 描述: 自动检查指定Vendor目录下模型文件夹的doc文件完整性和命名规范
#
# 功能:
#   - 遍历 /HDD_Raid/SVN_MODEL_REPO/Vendor 下指定的厂商目录
#   - 检查每个模型的doc文件夹是否存在
#   - 验证doc文件夹中是否包含word和pdf文件（缺一不可）
#   - 检查文件名是否与上级文件夹名称匹配（推理/训练等字样）
#   - 生成详细的检查报告
#
# 检查的厂商目录:
#   - Cambricon, Enflame, Iluvatar, Kunlunxin, MetaX, Moffett
#
# 用法: ./check_doc_files.sh
#
# 输出:
#   - 日志文件位置: /var/log/doc_checks/
#   - 日志命名格式: doc_check_YYYY-MM-DD_HH-MM-SS.log
#
# 返回值:
#   - 0: 所有检查都成功
#   - 1: 存在检查失败的项目
#
# 依赖:
#   - find 命令
#   - file 命令（用于文件类型检测）
#   - 需要对日志目录的写入权限
#
# 作者: Claude
# 创建日期: 2024-12-19
# 版本: 1.0
#############################################################################

# 定义颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[WARN] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
    echo "[DEBUG] $1" >> "$LOG_FILE"
}

# 设置日志文件路径和名称
LOG_DIR="/var/log/doc_checks"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/doc_check_${DATE}.log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"
log_info "日志文件创建在: $LOG_FILE"

# 声明全局计数器变量
declare -g total_models_checked=0
declare -g total_doc_folders_found=0
declare -g total_doc_folders_missing=0
declare -g total_word_files_found=0
declare -g total_pdf_files_found=0
declare -g total_word_files_missing=0
declare -g total_pdf_files_missing=0
declare -g total_naming_matches=0
declare -g total_naming_mismatches=0

# 定义要检查的厂商目录
VENDORS=("Cambricon" "Enflame" "Iluvatar" "Kunlunxin" "MetaX" "Moffett")

# 基础路径
BASE_PATH="/HDD_Raid/SVN_MODEL_REPO/Vendor"

# 写入日志头部
log_info "Doc Files Verification Report - ${DATE}"
echo "=========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"    # 检查文件名是否包含推理或训练关键词
check_filename_keywords() {
    local filename="$1"
    local version_dir="$2"
    local file_type="$3"

    # 获取推理/训练目录（从版本目录往上找到第二级目录，即inference目录）
    local inference_dir=$(dirname "$(dirname "$version_dir")")
    local inference_name=$(basename "$inference_dir")
    
    # 转换为小写进行比较
    local filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    local inference_name_lower=$(echo "$inference_name" | tr '[:upper:]' '[:lower:]')

    # 定义关键词映射
    local inference_keywords=("inference" "推理" "infer")
    local training_keywords=("training" "训练" "train")

    local found_match=false
    local keyword_type=""
    local parent_dir=$(dirname "$folder_name")
    local parent_name=$(basename "$parent_dir")
    local folder_name_lower=$(echo "$folder_name" | tr '[:upper:]' '[:lower:]')
    local parent_name_lower=$(echo "$parent_name" | tr '[:upper:]' '[:lower:]')

    # 检查推理关键词
    for keyword in "${inference_keywords[@]}"; do
        if [[ "$filename_lower" == *"$keyword"* ]]; then
            keyword_type="推理"
            if [[ "$folder_name_lower" == *"$keyword"* ]] || [[ "$parent_name_lower" == *"$keyword"* ]]; then
                found_match=true
            fi
            break
        fi
    done

    # 检查训练关键词
    if [ "$found_match" = false ]; then
        for keyword in "${training_keywords[@]}"; do
            if [[ "$filename_lower" == *"$keyword"* ]]; then
                keyword_type="训练"
                if [[ "$folder_name_lower" == *"$keyword"* ]] || [[ "$parent_name_lower" == *"$keyword"* ]]; then
                    found_match=true
                fi
                break
            fi
        done
    fi

    if [ "$keyword_type" != "" ]; then
        if [ "$found_match" = true ]; then
            log_info "    ✓ ${file_type}文件名匹配: $filename (包含${keyword_type}关键词，与文件夹 $folder_name 匹配)"
            total_naming_matches=$((total_naming_matches + 1))
        else
            log_warning "    ⚠ ${file_type}文件名不匹配: $filename (包含${keyword_type}关键词，但与文件夹 $folder_name 不匹配)"
            total_naming_mismatches=$((total_naming_mismatches + 1))
        fi
    else
        log_debug "    - ${file_type}文件: $filename (未包含推理/训练关键词)"
    fi
}

# 检查单个模型目录的doc文件夹
check_model_doc() {
    local model_path="$1"
    local model_name=$(basename "$model_path")
    local vendor_name=$(basename "$(dirname "$model_path")")

    log_info "检查模型: $vendor_name/$model_name"
    total_models_checked=$((total_models_checked + 1))

    # 遍历查找完整路径（六级目录：厂商/模型/子模型/推理类型/版本/doc）
    local version_dirs=""
    while IFS= read -r -d '' dir; do
        # 跳过 .svn 目录
        if [[ "$dir" == *"/.svn"* ]]; then
            continue
        fi
        
        if [[ -d "$dir" ]]; then
            # 检查目录名是否匹配版本格式（v1.0、V2.0、v3.2.1等）
            local dirname=$(basename "$dir")
            if [[ "$dirname" =~ ^[vV][0-9]+(\.[0-9]+)*$ ]]; then
                # 检查上层目录是否为Inference或Training
                local parent_dir=$(dirname "$dir")
                local parent_name=$(basename "$parent_dir")
                if [[ "${parent_name,,}" =~ ^(inference|training|推理|训练)$ ]]; then
                    # 检查版本目录下是否存在doc文件夹
                    if [[ -d "$dir/doc" ]]; then
                        version_dirs="${version_dirs}${dir}"$'\n'
                    fi
                fi
            fi
        fi
    done < <(find "$model_path" -type d -print0 2>/dev/null)

    if [ -z "$version_dirs" ]; then
        log_warning "  未找到版本目录在: $model_path"
        return
    fi

    # 使用全局变量来存储统计信息
    while IFS= read -r version_dir; do
        [ -z "$version_dir" ] && continue
        local version_name=$(basename "$version_dir")
        log_debug "  检查版本目录: $version_name"

        # 检查doc文件夹是否存在
        local doc_dir="$version_dir/doc"
        if [ ! -d "$doc_dir" ]; then
            log_error "  ✗ doc文件夹不存在: $doc_dir"
            total_doc_folders_missing=$((total_doc_folders_missing + 1))
            continue
        fi

        log_info "  ✓ doc文件夹存在: $doc_dir"
        total_doc_folders_found=$((total_doc_folders_found + 1))

        # 检查Word文件（排除.svn目录）
        local word_files=$(find "$doc_dir" -maxdepth 1 -type f \( -iname "*.doc" -o -iname "*.docx" \) -not -path "*.svn*" 2>/dev/null)
        local word_count=0
        if [ -n "$word_files" ]; then
            word_count=$(echo "$word_files" | wc -l)
        fi

        if [ "$word_count" -eq 0 ]; then
            log_error "  ✗ 缺少Word文档文件 (.doc/.docx)"
            total_word_files_missing=$((total_word_files_missing + 1))
        else
            log_info "  ✓ 找到 $word_count 个Word文档文件"
            total_word_files_found=$((total_word_files_found + word_count))

            # 检查Word文件名
            echo "$word_files" | while read -r word_file; do
                if [ -n "$word_file" ]; then
                    local word_filename=$(basename "$word_file")
                    check_filename_keywords "$word_filename" "$version_name" "Word"
                fi
            done
        fi

        # 检查PDF文件（排除.svn目录）
        local pdf_files=$(find "$doc_dir" -maxdepth 1 -type f -iname "*.pdf" -not -path "*.svn*" 2>/dev/null)
        local pdf_count=0
        if [ -n "$pdf_files" ]; then
            pdf_count=$(echo "$pdf_files" | wc -l)
        fi

        if [ "$pdf_count" -eq 0 ]; then
            log_error "  ✗ 缺少PDF文档文件 (.pdf)"
            total_pdf_files_missing=$((total_pdf_files_missing + 1))
        else
            log_info "  ✓ 找到 $pdf_count 个PDF文档文件"
            total_pdf_files_found=$((total_pdf_files_found + pdf_count))

            # 检查PDF文件名
            echo "$pdf_files" | while read -r pdf_file; do
                if [ -n "$pdf_file" ]; then
                    local pdf_filename=$(basename "$pdf_file")
                    check_filename_keywords "$pdf_filename" "$version_name" "PDF"
                fi
            done
        fi

        echo "" >> "$LOG_FILE"
    done <<< "$version_dirs"
}

# 检查厂商目录
check_vendor_directory() {
    local vendor_path="$1"
    local vendor_name=$(basename "$vendor_path")

    log_info "开始检查厂商目录: $vendor_name"
    echo "----------------------------------------" >> "$LOG_FILE"

    if [ ! -d "$vendor_path" ]; then
        log_warning "厂商目录不存在: $vendor_path"
        return
    fi

    # 查找所有模型目录（五级目录结构：厂商/模型/子模型/推理类型/版本）
    local model_dirs=$(find "$vendor_path" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    if [ -z "$model_dirs" ]; then
        log_warning "在 $vendor_name 中未找到模型目录"
        return
    fi

    # 直接使用找到的一级目录（如S60）
    local unique_models=$(echo "$model_dirs" | sort -u)

    echo "$unique_models" | while read -r model_path; do
        if [ -n "$model_path" ] && [ -d "$model_path" ]; then
            check_model_doc "$model_path"
        fi
    done
}

# 主程序开始
log_info "开始 Doc Files 验证进程..."
echo "" >> "$LOG_FILE"

# 声明全局计数器变量
declare -g total_models_checked=0
declare -g total_doc_folders_found=0
declare -g total_doc_folders_missing=0
declare -g total_word_files_found=0
declare -g total_pdf_files_found=0
declare -g total_word_files_missing=0
declare -g total_pdf_files_missing=0
declare -g total_naming_matches=0
declare -g total_naming_mismatches=0

# 检查基础路径是否存在
if [ ! -d "$BASE_PATH" ]; then
    log_error "基础路径不存在: $BASE_PATH"
    exit 1
fi

# 遍历所有指定的厂商目录
for vendor in "${VENDORS[@]}"; do
    vendor_path="$BASE_PATH/$vendor"
    check_vendor_directory "$vendor_path"
    echo "" >> "$LOG_FILE"
done

# 写入总结报告
log_info "检查完成！生成总结报告..."
echo "Summary" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# 计算统计数据
# 清理可能的重复计数
declare -g final_models_checked=0
declare -g final_doc_folders_found=0
declare -g final_doc_folders_missing=0
declare -g final_word_files_found=0
declare -g final_pdf_files_found=0
declare -g final_word_files_missing=0
declare -g final_pdf_files_missing=0
declare -g final_naming_matches=0
declare -g final_naming_mismatches=0

# 定义一个函数来处理每个目录
process_directory() {
    local dir="$1"
    
    if [[ "$dir" == *"/.svn"* ]]; then
        return
    fi
    
    if [[ -d "$dir" && $(basename "$dir") =~ ^[vV][0-9]+(\.[0-9]+)*$ ]]; then
        local parent_dir=$(dirname "$dir")
        local parent_name=$(basename "$parent_dir")
        if [[ "${parent_name,,}" =~ ^(inference|training|推理|训练)$ ]]; then
            ((final_models_checked++))
            if [[ -d "$dir/doc" ]]; then
                ((final_doc_folders_found++))
                
                # 检查Word文件
                local word_files=$(find "$dir/doc" -maxdepth 1 -type f \( -iname "*.doc" -o -iname "*.docx" \) -not -path "*.svn*" 2>/dev/null)
                if [[ -n "$word_files" ]]; then
                    ((final_word_files_found++))
                    # 检查Word文件名匹配
                    while IFS= read -r word_file; do
                        if [ -n "$word_file" ]; then
                            local word_filename=$(basename "$word_file")
                            local word_filename_lower=$(echo "$word_filename" | tr '[:upper:]' '[:lower:]')
                            
                            # 获取上上级目录（如Inference/Training目录）
                            local upper_dir=$(dirname "$(dirname "$dir")")
                            local upper_dir_name=$(basename "$upper_dir")
                            local upper_dir_name_lower=$(echo "$upper_dir_name" | tr '[:upper:]' '[:lower:]')
                            
                            if [[ "$word_filename_lower" =~ (inference|training|推理|训练) ]] && [[ "$upper_dir_name_lower" =~ (inference|training|推理|训练) ]]; then
                                ((final_naming_matches++))
                            else
                                ((final_naming_mismatches++))
                            fi
                        fi
                    done <<< "$word_files"
                else
                    # 版本文件夹存在但没有Word文件，计为缺失
                    ((final_word_files_missing++))
                fi
                
                # 检查PDF文件
                local pdf_files=$(find "$dir/doc" -maxdepth 1 -type f -iname "*.pdf" -not -path "*.svn*" 2>/dev/null)
                if [[ -n "$pdf_files" ]]; then
                    ((final_pdf_files_found++))
                    # 检查PDF文件名匹配
                    while IFS= read -r pdf_file; do
                        if [ -n "$pdf_file" ]; then
                            local pdf_filename=$(basename "$pdf_file")
                            local pdf_filename_lower=$(echo "$pdf_filename" | tr '[:upper:]' '[:lower:]')
                            
                            # 获取上上级目录（如Inference/Training目录）
                            local upper_dir=$(dirname "$(dirname "$dir")")
                            local upper_dir_name=$(basename "$upper_dir")
                            local upper_dir_name_lower=$(echo "$upper_dir_name" | tr '[:upper:]' '[:lower:]')
                            
                            if [[ "$pdf_filename_lower" =~ (inference|training|推理|训练) ]] && [[ "$upper_dir_name_lower" =~ (inference|training|推理|训练) ]]; then
                                ((final_naming_matches++))
                            else
                                ((final_naming_mismatches++))
                            fi
                        fi
                    done <<< "$pdf_files"
                else
                    # 版本文件夹存在但没有PDF文件，计为缺失
                    ((final_pdf_files_missing++))
                fi
            else
                ((final_doc_folders_missing++))
            fi
        fi
    fi
}

# 统计每个文件夹的实际情况
while IFS= read -r -d '' dir; do
    process_directory "$dir"
done < <(find "$BASE_PATH" -type d -print0 2>/dev/null)

# 详细的总结信息
log_info "巡检总结:"
log_info "----------------------------------------"
log_info "检查的厂商数量: ${#VENDORS[@]} (${VENDORS[*]})"
log_info "总计检查模型数量: $final_models_checked"
log_info "找到doc文件夹数量: $final_doc_folders_found"
log_info "缺少doc文件夹数量: $final_doc_folders_missing"
log_info "----------------------------------------"
log_info "文档文件统计:"
log_info "  Word文件找到: $final_word_files_found"
log_info "  Word文件缺失: $final_word_files_missing"
log_info "  PDF文件找到: $final_pdf_files_found"
log_info "  PDF文件缺失: $final_pdf_files_missing"
log_info "----------------------------------------"
log_info "文件名匹配统计:"
log_info "  命名匹配: $final_naming_matches"
log_info "  命名不匹配: $final_naming_mismatches"
log_info "----------------------------------------"

# 重新计算Word和PDF文件缺失数量，基于版本文件夹的数量
final_word_files_missing=$((final_models_checked - final_word_files_found))
final_pdf_files_missing=$((final_models_checked - final_pdf_files_found))

# 计算总体状态
total_issues=$((final_doc_folders_missing + final_word_files_missing + final_pdf_files_missing + final_naming_mismatches))

if [ $total_issues -eq 0 ]; then
    log_info "✅ 本次巡检未发现任何问题"
    log_info "所有模型的doc文件夹都存在，且包含完整的Word和PDF文档"
    if [ $final_naming_matches -gt 0 ]; then
        log_info "所有包含关键词的文件名都与上上级文件夹名称匹配"
    fi
else
    log_error "❌ 本次巡检发现 $total_issues 个问题"
    if [ $final_doc_folders_missing -gt 0 ]; then
        log_error "  - $final_doc_folders_missing 个模型缺少doc文件夹"
    fi
    if [ $final_word_files_missing -gt 0 ]; then
        log_error "  - $final_word_files_missing 个版本文件夹缺少Word文档"
    fi
    if [ $final_pdf_files_missing -gt 0 ]; then
        log_error "  - $final_pdf_files_missing 个版本文件夹缺少PDF文档"
    fi
    if [ $final_naming_mismatches -gt 0 ]; then
        log_error "  - $final_naming_mismatches 个文件名与上上级文件夹名称不匹配"
    fi
fi

log_info "----------------------------------------"
echo "End of report - $(date)" >> "$LOG_FILE"

# 如果有问题，退出码为1
if [ $total_issues -gt 0 ]; then
    log_error "检查完成，但存在问题，请查看日志文件了解详情"
    exit 1
fi

log_info "所有检查均已成功完成！"
exit 0
