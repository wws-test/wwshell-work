#!/bin/bash

#############################################################################
# 脚本名称: check_doc_files.sh
# 描述: 自动检查模型文档完整性检查工具
#
# 功能描述:
#   1. 文档完整性检查:
#      - 验证每个模型版本目录下的doc文件夹存在性
#      - 检查doc文件夹中是否同时包含Word和PDF格式文档
#      - 支持多种训练类型目录: inference/training/fine-tuning等
#   
#   2. 版本目录规范检查:
#      - 识别标准版本目录格式(v1.0, V2.1等)
#      - 自动识别训练类型目录(推理/训练/微调/预训练等)
#   
#   3. 统计功能:
#      - 按厂商分类统计版本目录数量
#      - 统计Word文档和PDF文档数量
#      - 生成详细的检查报告和日志
#
# 支持的厂商:
#   - Cambricon (寒武纪)
#   - Enflame (燧原科技)
#   - Iluvatar (天数智芯)
#   - Kunlunxin (昆仑芯)
#   - MetaX (九天)
#   - Moffett (莫斐)
#
# 使用方法:
#   常规模式: ./check_doc_files.sh
#   详细模式: ./check_doc_files.sh -v
#            ./check_doc_files.sh --verbose
#
# 输出说明:
#   1. 终端输出:
#      - 实时显示检查进度
#      - 使用彩色输出区分不同级别信息
#      - 支持详细模式显示调试信息
#
#   2. 日志文件:
#      - 位置: /HDD_Raid/log/
#      - 命名: doc_check_YYYY-MM-DD_HH-MM-SS.log
#      - 包含完整的检查记录和统计信息
#
# 返回值:
#   0: 检查通过 - 所有厂商的文档完整性检查均通过
#   1: 检查失败 - 存在一个或多个厂商未通过检查
#
# 作者: Claude
# 创建日期: 2024-12-19
# 当前版本: 1.4
# 更新说明: 
#   - 优化了MetaX厂商的统计逻辑
#   - 增加了更多训练类型目录的支持
#   - 改进了文件计数统计方式
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
LOG_DIR="/HDD_Raid/log"
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

echo -e "${CYAN}=== Doc Files 检查工具 (按厂商统计) ===${NC}"
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

# 定义要检查的厂商目录
VENDORS=("Cambricon" "Enflame" "Iluvatar" "Kunlunxin" "MetaX" "Moffett")

# 基础路径
BASE_PATH="/HDD_Raid/SVN_MODEL_REPO/Vendor"

# 按厂商统计的数组
declare -A vendor_version_dirs
declare -A vendor_word_files
declare -A vendor_pdf_files
declare -A vendor_passed

# 初始化厂商统计数组
for vendor in "${VENDORS[@]}"; do
    vendor_version_dirs[$vendor]=0
    vendor_word_files[$vendor]=0
    vendor_pdf_files[$vendor]=0
    vendor_passed[$vendor]=false
done

# 写入日志头部
echo "=========================================" >> "$LOG_FILE"
echo "Doc Files Verification Report - ${DATE}" >> "$LOG_FILE"
echo "Verbose Mode: $VERBOSE" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

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
                # 扩展匹配条件，包含更多类型的目录
                if [[ "${parent_name,,}" =~ ^(inference|inferece|training|推理|训练|pre-training|pre_training|lora_fine-tuning|lora_fine-tuing|fine-tuning|sft_fine-tuning|微调|预训练)$ ]]; then
                    if [[ -d "$dir/doc" ]]; then
                        version_dirs="${version_dirs}${dir}"$'\n'
                        # 增加厂商的版本目录计数
                        vendor_version_dirs[$vendor_name]=$((vendor_version_dirs[$vendor_name] + 1))
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
            # 增加厂商的Word文件计数 - 只在文件存在时计数一次
            vendor_word_files[$vendor_name]=$((vendor_word_files[$vendor_name] + 1))
        fi

        if [ "$word_count" -eq 0 ]; then
            log_fail "缺少Word文档: $inference_type/$version_name"
            total_word_files_missing=$((total_word_files_missing + 1))
            ((model_issues++))
        else
            log_success "Word文档 ($word_count个): $inference_type/$version_name"
            total_word_files_found=$((total_word_files_found + word_count))
        fi

        # 检查PDF文件
        local pdf_files=$(find "$doc_dir" -maxdepth 1 -type f -iname "*.pdf" -not -path "*.svn*" 2>/dev/null)
        local pdf_count=0
        if [ -n "$pdf_files" ]; then
            pdf_count=$(echo "$pdf_files" | wc -l)
            # 增加厂商的PDF文件计数 - 只在文件存在时计数一次
            vendor_pdf_files[$vendor_name]=$((vendor_pdf_files[$vendor_name] + 1))
        fi

        if [ "$pdf_count" -eq 0 ]; then
            log_fail "缺少PDF文档: $inference_type/$version_name"
            total_pdf_files_missing=$((total_pdf_files_missing + 1))
            ((model_issues++))
        else
            log_success "PDF文档 ($pdf_count个): $inference_type/$version_name"
            total_pdf_files_found=$((total_pdf_files_found + pdf_count))
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

    local model_dirs=$(find "$vendor_path" -mindepth 1 -maxdepth 1 -type d -not -name ".svn" 2>/dev/null)

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

# 检查厂商是否通过
check_vendor_status() {
    local vendor="$1"
    local version_dirs=${vendor_version_dirs[$vendor]}
    local word_files=${vendor_word_files[$vendor]}
    local pdf_files=${vendor_pdf_files[$vendor]}
    
    if [ $version_dirs -eq $word_files ] && [ $version_dirs -eq $pdf_files ] && [ $version_dirs -gt 0 ]; then
        vendor_passed[$vendor]=true
        return 0
    else
        vendor_passed[$vendor]=false
        return 1
    fi
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

# 检查每个厂商是否通过
total_vendors_passed=0
total_vendors_failed=0

# 生成按厂商的统计报告
echo -e "${CYAN}📊 厂商检查结果统计${NC}"
echo "========================================="
for vendor in "${VENDORS[@]}"; do
    check_vendor_status "$vendor"
    version_dirs=${vendor_version_dirs[$vendor]}
    word_files=${vendor_word_files[$vendor]}
    pdf_files=${vendor_pdf_files[$vendor]}
    
    echo -n "📁 $vendor: "
    if ${vendor_passed[$vendor]}; then
        echo -e "${GREEN}通过✓${NC}"
        ((total_vendors_passed++))
    else
        echo -e "${RED}未通过✗${NC}"
        ((total_vendors_failed++))
    fi
    echo "  版本目录数量: $version_dirs"
    echo "  Word文件数量: $word_files"
    echo "  PDF文件数量: $pdf_files"
    
    if [ $version_dirs -ne $word_files ]; then
        echo -e "  ${RED}Word文件数量与版本目录数量不匹配${NC}"
    fi
    
    if [ $version_dirs -ne $pdf_files ]; then
        echo -e "  ${RED}PDF文件数量与版本目录数量不匹配${NC}"
    fi
    
    echo ""
done

# 生成整体总结报告
echo -e "${CYAN}📊 总体检查结果${NC}"
echo "========================================="
echo "厂商总数: ${#VENDORS[@]}"
echo "通过的厂商: $total_vendors_passed"
echo "未通过的厂商: $total_vendors_failed"
echo ""
echo "总计版本目录数: $(( $(for v in "${VENDORS[@]}"; do echo ${vendor_version_dirs[$v]}; done | paste -sd+ -) ))"
echo "总计Word文件数: $(( $(for v in "${VENDORS[@]}"; do echo ${vendor_word_files[$v]}; done | paste -sd+ -) ))"
echo "总计PDF文件数: $(( $(for v in "${VENDORS[@]}"; do echo ${vendor_pdf_files[$v]}; done | paste -sd+ -) ))"
echo "========================================="

# 计算总体状态
if [ $total_vendors_failed -eq 0 ]; then
    echo -e "${GREEN}✅ 检查完成，所有厂商均通过检查！${NC}"
    echo "所有厂商的版本目录、Word文件和PDF文件数量均匹配。"
else
    echo -e "${RED}❌ 检查完成，有 $total_vendors_failed 个厂商未通过检查${NC}"
    echo "未通过的厂商:"
    for vendor in "${VENDORS[@]}"; do
        if ! ${vendor_passed[$vendor]}; then
            echo -e "${RED}  - $vendor${NC}"
        fi
    done
    echo "详细信息请查看上方厂商统计或日志文件。"
fi

echo ""
echo "日志文件: $LOG_FILE"

# 写入日志总结
echo "" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
echo "VENDOR SUMMARY - $(date)" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"
for vendor in "${VENDORS[@]}"; do
    echo "$vendor:" >> "$LOG_FILE"
    echo "  Version Dirs: ${vendor_version_dirs[$vendor]}" >> "$LOG_FILE"
    echo "  Word Files: ${vendor_word_files[$vendor]}" >> "$LOG_FILE"
    echo "  PDF Files: ${vendor_pdf_files[$vendor]}" >> "$LOG_FILE"
    if ${vendor_passed[$vendor]}; then
        echo "  Status: PASSED" >> "$LOG_FILE"
    else
        echo "  Status: FAILED" >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
done
echo "Total Vendors Passed: $total_vendors_passed" >> "$LOG_FILE"
echo "Total Vendors Failed: $total_vendors_failed" >> "$LOG_FILE"
echo "=========================================" >> "$LOG_FILE"

# 退出状态
if [ $total_vendors_failed -gt 0 ]; then
    exit 1
fi

exit 0
