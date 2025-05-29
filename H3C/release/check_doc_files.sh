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
# 用法: ./check_doc_files.sh [-v|--verbose]
#
# 参数:
#   -v, --verbose: 启用详细输出模式
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
# 版本: 1.2 (优化日志输出)
#############################################################################

# 定义颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查命令行参数
VERBOSE=false
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE=true
fi

# 设置日志文件路径和名称
LOG_DIR="/var/log/doc_checks"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/doc_check_${DATE}.log"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 优化的输出函数
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
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
    echo "[DEBUG] $1" >> "$LOG_FILE"
}

log_progress() {
    echo -e "${CYAN}[PROGRESS]${NC} $1"
    echo "[PROGRESS] $1" >> "$LOG_FILE"
}

# 简化的成功/失败输出
log_success() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}  ✓${NC} $1"
    fi
    echo "  ✓ $1" >> "$LOG_FILE"
}

log_fail() {
    echo -e "${RED}  ✗${NC} $1"
    echo "  ✗ $1" >> "$LOG_FILE"
}

echo -e "${CYAN}=== Doc Files 检查工具 ===${NC}"
echo "日志文件: $LOG_FILE"
if [ "$VERBOSE" = true ]; then
    echo "详细模式: 已启用"
else
    echo "详细模式: 已禁用 (使用 -v 启用详细输出)"
fi
echo ""

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
echo "=========================================" >> "$LOG_FILE"
echo "Doc Files Verification Report - ${DATE}" >> "$LOG_FILE"
echo "Verbose Mode: $VERBOSE" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# 简化的文件名检查函数
check_filename_keywords() {
    local filename="$1"
    local version_dir="$2"
    local file_type="$3"

    # 获取推理/训练目录
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

    # 检查推理关键词
    for keyword in "${inference_keywords[@]}"; do
        if [[ "$filename_lower" == *"$keyword"* ]]; then
            keyword_type="推理"
            if [[ "$inference_name_lower" == *"$keyword"* ]]; then
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
                if [[ "$inference_name_lower" == *"$keyword"* ]]; then
                    found_match=true
                fi
                break
            fi
        done
    fi

    if [ "$keyword_type" != "" ]; then
        if [ "$found_match" = true ]; then
            log_success "${file_type}文件名匹配: $filename"
            total_naming_matches=$((total_naming_matches + 1))
        else
            log_fail "${file_type}文件名不匹配: $filename (${keyword_type}关键词与文件夹 $inference_name 不匹配)"
            total_naming_mismatches=$((total_naming_mismatches + 1))
        fi
    else
        log_debug "${file_type}文件: $filename (无关键词)"
    fi
}

# 简化的模型检查函数
check_model_doc() {
    local model_path="$1"
    local model_name=$(basename "$model_path")
    local vendor_name=$(basename "$(dirname "$model_path")")

    log_progress "检查 $vendor_name/$model_name"
    total_models_checked=$((total_models_checked + 1))

    # 查找版本目录
    local version_dirs=""
    while IFS= read -r -d '' dir; do
        if [[ "$dir" == *"/.svn"* ]]; then
            continue
        fi
        
        if [[ -d "$dir" ]]; then
            local dirname=$(basename "$dir")
            if [[ "$dirname" =~ ^[vV][0-9]+(\.[0-9]+)*$ ]]; then
                local parent_dir=$(dirname "$dir")
                local parent_name=$(basename "$parent_dir")
                if [[ "${parent_name,,}" =~ ^(inference|training|推理|训练)$ ]]; then
                    if [[ -d "$dir/doc" ]]; then
                        version_dirs="${version_dirs}${dir}"$'\n'
                    fi
                fi
            fi
        fi
    done < <(find "$model_path" -type d -print0 2>/dev/null)

    if [ -z "$version_dirs" ]; then
        log_fail "未找到有效的版本目录"
        return
    fi

    local model_issues=0
    
    # 检查每个版本目录
    while IFS= read -r version_dir; do
        [ -z "$version_dir" ] && continue
        local version_name=$(basename "$version_dir")
        local inference_type=$(basename "$(dirname "$version_dir")")
        
        log_debug "检查版本: $inference_type/$version_name"

        local doc_dir="$version_dir/doc"
        if [ ! -d "$doc_dir" ]; then
            log_fail "doc文件夹不存在: $inference_type/$version_name"
            total_doc_folders_missing=$((total_doc_folders_missing + 1))
            ((model_issues++))
            continue
        fi

        log_success "doc文件夹存在: $inference_type/$version_name"
        total_doc_folders_found=$((total_doc_folders_found + 1))

        # 检查Word文件
        local word_files=$(find "$doc_dir" -maxdepth 1 -type f \( -iname "*.doc" -o -iname "*.docx" \) -not -path "*.svn*" 2>/dev/null)
        local word_count=0
        if [ -n "$word_files" ]; then
            word_count=$(echo "$word_files" | wc -l)
        fi

        if [ "$word_count" -eq 0 ]; then
            log_fail "缺少Word文档: $inference_type/$version_name"
            total_word_files_missing=$((total_word_files_missing + 1))
            ((model_issues++))
        else
            log_success "Word文档 ($word_count个): $inference_type/$version_name"
            total_word_files_found=$((total_word_files_found + word_count))

            # 只在详细模式下检查文件名
            if [ "$VERBOSE" = true ]; then
                echo "$word_files" | while read -r word_file; do
                    if [ -n "$word_file" ]; then
                        local word_filename=$(basename "$word_file")
                        check_filename_keywords "$word_filename" "$version_dir" "Word"
                    fi
                done
            fi
        fi

        # 检查PDF文件
        local pdf_files=$(find "$doc_dir" -maxdepth 1 -type f -iname "*.pdf" -not -path "*.svn*" 2>/dev/null)
        local pdf_count=0
        if [ -n "$pdf_files" ]; then
            pdf_count=$(echo "$pdf_files" | wc -l)
        fi

        if [ "$pdf_count" -eq 0 ]; then
            log_fail "缺少PDF文档: $inference_type/$version_name"
            total_pdf_files_missing=$((total_pdf_files_missing + 1))
            ((model_issues++))
        else
            log_success "PDF文档 ($pdf_count个): $inference_type/$version_name"
            total_pdf_files_found=$((total_pdf_files_found + pdf_count))

            # 只在详细模式下检查文件名
            if [ "$VERBOSE" = true ]; then
                echo "$pdf_files" | while read -r pdf_file; do
                    if [ -n "$pdf_file" ]; then
                        local pdf_filename=$(basename "$pdf_file")
                        check_filename_keywords "$pdf_filename" "$version_dir" "PDF"
                    fi
                done
            fi
        fi
    done <<< "$version_dirs"

    # 模型检查结果摘要
    if [ $model_issues -eq 0 ]; then
        echo -e "${GREEN}  ✓ $vendor_name/$model_name 检查通过${NC}"
    else
        echo -e "${RED}  ✗ $vendor_name/$model_name 发现 $model_issues 个问题${NC}"
    fi
    echo ""
}

# 简化的厂商目录检查
check_vendor_directory() {
    local vendor_path="$1"
    local vendor_name=$(basename "$vendor_path")

    echo -e "${CYAN}📁 检查厂商: $vendor_name${NC}"

    if [ ! -d "$vendor_path" ]; then
        log_warning "厂商目录不存在: $vendor_path"
        return
    fi

    local model_dirs=$(find "$vendor_path" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    if [ -z "$model_dirs" ]; then
        log_warning "在 $vendor_name 中未找到模型目录"
        return
    fi

    # 使用数组避免子进程问题
    local model_array=()
    while IFS= read -r model_path; do
        if [ -n "$model_path" ] && [ -d "$model_path" ]; then
            model_array+=("$model_path")
        fi
    done <<< "$(echo "$model_dirs" | sort -u)"

    # 遍历模型数组
    for model_path in "${model_array[@]}"; do
        check_model_doc "$model_path"
    done
}

# 主程序开始
echo -e "${CYAN}🚀 开始 Doc Files 验证...${NC}"
echo ""

# 检查基础路径
if [ ! -d "$BASE_PATH" ]; then
    log_error "基础路径不存在: $BASE_PATH"
    exit 1
fi

# 遍历厂商目录
for vendor in "${VENDORS[@]}"; do
    vendor_path="$BASE_PATH/$vendor"
    check_vendor_directory "$vendor_path"
done

# 生成简洁的总结报告
echo -e "${CYAN}📊 检查结果总结${NC}"
echo "========================================="
echo "厂商数量: ${#VENDORS[@]} (${VENDORS[*]})"
echo "模型总数: $total_models_checked"
echo ""
echo "📁 Doc文件夹:"
echo "  ✓ 存在: $total_doc_folders_found"
echo "  ✗ 缺失: $total_doc_folders_missing"
echo ""
echo "📄 文档文件:"
echo "  ✓ Word: $total_word_files_found"
echo "  ✗ Word缺失: $total_word_files_missing"
echo "  ✓ PDF: $total_pdf_files_found"
echo "  ✗ PDF缺失: $total_pdf_files_missing"

if [ "$VERBOSE" = true ]; then
    echo ""
    echo "🏷️ 文件名匹配:"
    echo "  ✓ 匹配: $total_naming_matches"
    echo "  ✗ 不匹配: $total_naming_mismatches"
fi

echo "========================================="

# 计算总体状态
total_issues=$((total_doc_folders_missing + total_word_files_missing + total_pdf_files_missing + total_naming_mismatches))

if [ $total_issues -eq 0 ]; then
    echo -e "${GREEN}✅ 检查完成，未发现问题！${NC}"
    echo "所有模型的文档都完整且规范。"
else
    echo -e "${RED}❌ 检查完成，发现 $total_issues 个问题${NC}"
    echo "详细信息请查看日志文件: $LOG_FILE"
fi

echo ""
echo "日志文件: $LOG_FILE"

# 写入日志总结
echo "" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "SUMMARY - $(date)" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "Total Issues: $total_issues" >> "$LOG_FILE"
echo "Models Checked: $total_models_checked" >> "$LOG_FILE"
echo "Doc Folders Missing: $total_doc_folders_missing" >> "$LOG_FILE"
echo "Word Files Missing: $total_word_files_missing" >> "$LOG_FILE"
echo "PDF Files Missing: $total_pdf_files_missing" >> "$LOG_FILE"
echo "Naming Mismatches: $total_naming_mismatches" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# 退出状态
if [ $total_issues -gt 0 ]; then
    exit 1
fi

exit 0
