#!/bin/bash

#############################################################################
# 脚本名称: directory_structure_monitor.sh
# 描述: 监控SVN模型仓库目录结构变化，生成JSON格式的目录树并进行对比
#
# 功能:
#   - 使用tree命令生成Model和Vendor目录的JSON格式结构
#   - 按月份保存JSON文件到指定目录
#   - 与上次的结构进行对比，生成差异报告
#   - 支持定时任务执行（每月10号）
#
# 用法: ./directory_structure_monitor.sh [--force] [--compare-only]
#
# 参数:
#   --force: 强制重新生成，即使当月文件已存在
#   --compare-only: 仅进行对比，不生成新的JSON文件
#
# 定时任务设置:
#   0 2 10 * * /HDD_Raid/util_script/directory_structure_monitor.sh
#
# 输出:
#   - JSON文件: /HDD_Raid/log/directory_structure/Vendor_YYYY-MM.json
#   - 对比报告: /HDD_Raid/log/directory_structure/comparison_YYYY-MM.txt
#
# 作者: Claude
# 创建日期: 2024-12-19
# 版本: 1.0
#############################################################################

# 设置颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 基础配置
BASE_MODEL_PATH="/HDD_Raid/SVN_MODEL_REPO/Model"
BASE_VENDOR_PATH="/HDD_Raid/SVN_MODEL_REPO/Vendor"
LOG_BASE_DIR="/HDD_Raid/log/directory_structure"
DATE=$(date +"%Y-%m")
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

# 文件路径
JSON_FILE="${LOG_BASE_DIR}/Vendor_${DATE}.json"
COMPARISON_FILE="${LOG_BASE_DIR}/comparison_${DATE}.txt"
TEMP_DIR="/tmp/dir_monitor_$$"

# 解析命令行参数
FORCE_GENERATE=false
COMPARE_ONLY=false

for arg in "$@"; do
    case $arg in
        --force)
            FORCE_GENERATE=true
            shift
            ;;
        --compare-only)
            COMPARE_ONLY=true
            shift
            ;;
        *)
            echo "未知参数: $arg"
            echo "用法: $0 [--force] [--compare-only]"
            exit 1
            ;;
    esac
done

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建必要的目录
create_directories() {
    if [ ! -d "$LOG_BASE_DIR" ]; then
        mkdir -p "$LOG_BASE_DIR"
        log_info "创建日志目录: $LOG_BASE_DIR"
    fi

    if [ ! -d "$TEMP_DIR" ]; then
        mkdir -p "$TEMP_DIR"
    fi
}

# 检查依赖命令
check_dependencies() {
    local missing_deps=()

    if ! command -v tree >/dev/null 2>&1; then
        missing_deps+=("tree")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少必要的依赖命令: ${missing_deps[*]}"
        log_info "请安装缺少的命令:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# 生成目录结构JSON
generate_directory_json() {
    local target_file="$1"

    log_info "开始生成目录结构JSON文件..."

    # 检查源目录是否存在
    if [ ! -d "$BASE_MODEL_PATH" ]; then
        log_error "Model目录不存在: $BASE_MODEL_PATH"
        return 1
    fi

    if [ ! -d "$BASE_VENDOR_PATH" ]; then
        log_error "Vendor目录不存在: $BASE_VENDOR_PATH"
        return 1
    fi

    # 生成临时JSON文件
    local temp_json="${TEMP_DIR}/structure.json"

    # 创建包含两个目录的JSON结构
    cat > "$temp_json" << EOF
{
  "generated_at": "$CURRENT_DATE",
  "directories": {
    "Model": null,
    "Vendor": null
  }
}
EOF

    # 生成Model目录的JSON
    log_info "扫描Model目录结构..."
    local model_json="${TEMP_DIR}/model.json"
    if tree -J "$BASE_MODEL_PATH" > "$model_json" 2>/dev/null; then
        # 使用jq合并JSON
        jq --argjson model "$(cat "$model_json")" '.directories.Model = $model[0]' "$temp_json" > "${temp_json}.tmp"
        mv "${temp_json}.tmp" "$temp_json"
        log_success "Model目录结构生成完成"
    else
        log_warning "Model目录结构生成失败"
    fi

    # 生成Vendor目录的JSON
    log_info "扫描Vendor目录结构..."
    local vendor_json="${TEMP_DIR}/vendor.json"
    if tree -J "$BASE_VENDOR_PATH" > "$vendor_json" 2>/dev/null; then
        # 使用jq合并JSON
        jq --argjson vendor "$(cat "$vendor_json")" '.directories.Vendor = $vendor[0]' "$temp_json" > "${temp_json}.tmp"
        mv "${temp_json}.tmp" "$temp_json"
        log_success "Vendor目录结构生成完成"
    else
        log_warning "Vendor目录结构生成失败"
    fi

    # 美化JSON并保存到目标文件
    if jq '.' "$temp_json" > "$target_file" 2>/dev/null; then
        log_success "JSON文件已保存: $target_file"

        # 显示文件大小
        local file_size=$(du -h "$target_file" | cut -f1)
        log_info "文件大小: $file_size"

        return 0
    else
        log_error "JSON文件保存失败"
        return 1
    fi
}

# 查找上一个月的JSON文件
find_previous_json() {
    local current_year_month=$(date +"%Y-%m")
    local previous_month

    # 计算上一个月
    if [ "$(date +%m)" = "01" ]; then
        # 如果是1月，上一个月是去年12月
        previous_month="$(date -d "last year" +%Y)-12"
    else
        # 其他月份，减1
        previous_month=$(date -d "$(date +%Y-%m-01) -1 month" +%Y-%m)
    fi

    local previous_file="${LOG_BASE_DIR}/Vendor_${previous_month}.json"

    if [ -f "$previous_file" ]; then
        echo "$previous_file"
        return 0
    else
        # 查找最近的JSON文件
        local latest_file=$(find "$LOG_BASE_DIR" -name "Vendor_*.json" -type f | sort -r | head -1)
        if [ -n "$latest_file" ] && [ -f "$latest_file" ]; then
            echo "$latest_file"
            return 0
        fi
    fi

    return 1
}

# 比较两个JSON文件
compare_json_files() {
    local current_file="$1"
    local previous_file="$2"
    local output_file="$3"

    log_info "开始比较JSON文件..."
    log_info "当前文件: $(basename "$current_file")"
    log_info "对比文件: $(basename "$previous_file")"

    # 创建对比报告
    cat > "$output_file" << EOF
目录结构变化对比报告
====================
生成时间: $CURRENT_DATE
当前文件: $(basename "$current_file")
对比文件: $(basename "$previous_file")

EOF

    # 使用jq进行深度比较
    local temp_diff="${TEMP_DIR}/diff_analysis.txt"

    # 比较Model目录
    echo "=== Model目录变化 ===" >> "$output_file"
    if jq -e '.directories.Model' "$current_file" >/dev/null 2>&1 && \
       jq -e '.directories.Model' "$previous_file" >/dev/null 2>&1; then

        # 提取并比较Model目录的文件列表
        jq -r '.directories.Model | .. | select(type == "object" and has("name") and has("type")) | "\(.type):\(.name)"' "$current_file" | sort > "${TEMP_DIR}/current_model.txt"
        jq -r '.directories.Model | .. | select(type == "object" and has("name") and has("type")) | "\(.type):\(.name)"' "$previous_file" | sort > "${TEMP_DIR}/previous_model.txt"

        # 找出新增的项目
        local added_model=$(comm -23 "${TEMP_DIR}/current_model.txt" "${TEMP_DIR}/previous_model.txt")
        if [ -n "$added_model" ]; then
            echo "新增项目:" >> "$output_file"
            echo "$added_model" | sed 's/^/  + /' >> "$output_file"
        fi

        # 找出删除的项目
        local removed_model=$(comm -13 "${TEMP_DIR}/current_model.txt" "${TEMP_DIR}/previous_model.txt")
        if [ -n "$removed_model" ]; then
            echo "删除项目:" >> "$output_file"
            echo "$removed_model" | sed 's/^/  - /' >> "$output_file"
        fi

        if [ -z "$added_model" ] && [ -z "$removed_model" ]; then
            echo "无变化" >> "$output_file"
        fi
    else
        echo "无法比较Model目录（数据不完整）" >> "$output_file"
    fi

    echo "" >> "$output_file"

    # 比较Vendor目录
    echo "=== Vendor目录变化 ===" >> "$output_file"
    if jq -e '.directories.Vendor' "$current_file" >/dev/null 2>&1 && \
       jq -e '.directories.Vendor' "$previous_file" >/dev/null 2>&1; then

        # 提取并比较Vendor目录的文件列表
        jq -r '.directories.Vendor | .. | select(type == "object" and has("name") and has("type")) | "\(.type):\(.name)"' "$current_file" | sort > "${TEMP_DIR}/current_vendor.txt"
        jq -r '.directories.Vendor | .. | select(type == "object" and has("name") and has("type")) | "\(.type):\(.name)"' "$previous_file" | sort > "${TEMP_DIR}/previous_vendor.txt"

        # 找出新增的项目
        local added_vendor=$(comm -23 "${TEMP_DIR}/current_vendor.txt" "${TEMP_DIR}/previous_vendor.txt")
        if [ -n "$added_vendor" ]; then
            echo "新增项目:" >> "$output_file"
            echo "$added_vendor" | sed 's/^/  + /' >> "$output_file"
        fi

        # 找出删除的项目
        local removed_vendor=$(comm -13 "${TEMP_DIR}/current_vendor.txt" "${TEMP_DIR}/previous_vendor.txt")
        if [ -n "$removed_vendor" ]; then
            echo "删除项目:" >> "$output_file"
            echo "$removed_vendor" | sed 's/^/  - /' >> "$output_file"
        fi

        if [ -z "$added_vendor" ] && [ -z "$removed_vendor" ]; then
            echo "无变化" >> "$output_file"
        fi
    else
        echo "无法比较Vendor目录（数据不完整）" >> "$output_file"
    fi

    echo "" >> "$output_file"

    # 统计信息
    echo "=== 统计信息 ===" >> "$output_file"
    local current_model_count=$(jq -r '.directories.Model | .. | select(type == "object" and has("name") and .type == "file") | .name' "$current_file" 2>/dev/null | wc -l)
    local current_vendor_count=$(jq -r '.directories.Vendor | .. | select(type == "object" and has("name") and .type == "file") | .name' "$current_file" 2>/dev/null | wc -l)
    local previous_model_count=$(jq -r '.directories.Model | .. | select(type == "object" and has("name") and .type == "file") | .name' "$previous_file" 2>/dev/null | wc -l)
    local previous_vendor_count=$(jq -r '.directories.Vendor | .. | select(type == "object" and has("name") and .type == "file") | .name' "$previous_file" 2>/dev/null | wc -l)

    echo "当前文件数量:" >> "$output_file"
    echo "  Model目录: $current_model_count 个文件" >> "$output_file"
    echo "  Vendor目录: $current_vendor_count 个文件" >> "$output_file"
    echo "  总计: $((current_model_count + current_vendor_count)) 个文件" >> "$output_file"
    echo "" >> "$output_file"
    echo "对比文件数量:" >> "$output_file"
    echo "  Model目录: $previous_model_count 个文件" >> "$output_file"
    echo "  Vendor目录: $previous_vendor_count 个文件" >> "$output_file"
    echo "  总计: $((previous_model_count + previous_vendor_count)) 个文件" >> "$output_file"
    echo "" >> "$output_file"
    echo "变化量:" >> "$output_file"
    echo "  Model目录: $((current_model_count - previous_model_count)) 个文件" >> "$output_file"
    echo "  Vendor目录: $((current_vendor_count - previous_vendor_count)) 个文件" >> "$output_file"
    echo "  总计: $(((current_model_count + current_vendor_count) - (previous_model_count + previous_vendor_count))) 个文件" >> "$output_file"

    log_success "对比报告已生成: $output_file"
}

# 清理临时文件
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 设置退出时清理
trap cleanup EXIT

# 主程序
main() {
    echo -e "${CYAN}=== 目录结构监控工具 ===${NC}"
    echo "执行时间: $CURRENT_DATE"
    echo "目标目录: Model, Vendor"
    echo "输出目录: $LOG_BASE_DIR"
    echo ""

    # 检查依赖
    check_dependencies

    # 创建目录
    create_directories

    # 如果只是对比模式
    if [ "$COMPARE_ONLY" = true ]; then
        log_info "仅对比模式，跳过JSON生成"

        if [ ! -f "$JSON_FILE" ]; then
            log_error "当前月份的JSON文件不存在: $JSON_FILE"
            exit 1
        fi

        # 查找上一个文件进行对比
        local previous_file
        if previous_file=$(find_previous_json); then
            compare_json_files "$JSON_FILE" "$previous_file" "$COMPARISON_FILE"
        else
            log_warning "未找到可对比的历史文件"
        fi

        return 0
    fi

    # 检查是否需要生成新的JSON文件
    if [ -f "$JSON_FILE" ] && [ "$FORCE_GENERATE" = false ]; then
        log_warning "当月JSON文件已存在: $JSON_FILE"
        log_info "使用 --force 参数强制重新生成"

        # 仍然尝试进行对比
        local previous_file
        if previous_file=$(find_previous_json); then
            if [ "$previous_file" != "$JSON_FILE" ]; then
                log_info "执行对比分析..."
                compare_json_files "$JSON_FILE" "$previous_file" "$COMPARISON_FILE"
            else
                log_info "没有找到不同的历史文件进行对比"
            fi
        else
            log_info "这是第一次运行，没有历史文件可对比"
        fi

        return 0
    fi

    # 生成新的JSON文件
    if generate_directory_json "$JSON_FILE"; then
        log_success "JSON文件生成成功"

        # 查找上一个文件进行对比
        local previous_file
        if previous_file=$(find_previous_json); then
            if [ "$previous_file" != "$JSON_FILE" ]; then
                log_info "执行对比分析..."
                compare_json_files "$JSON_FILE" "$previous_file" "$COMPARISON_FILE"
            else
                log_info "没有找到不同的历史文件进行对比"
            fi
        else
            log_info "这是第一次运行，没有历史文件可对比"
        fi
    else
        log_error "JSON文件生成失败"
        exit 1
    fi

    # 显示结果摘要
    echo ""
    echo -e "${CYAN}=== 执行结果摘要 ===${NC}"
    echo "JSON文件: $JSON_FILE"
    if [ -f "$COMPARISON_FILE" ]; then
        echo "对比报告: $COMPARISON_FILE"
    fi

    # 显示历史文件列表
    local history_files=$(find "$LOG_BASE_DIR" -name "Vendor_*.json" -type f | sort)
    local file_count=$(echo "$history_files" | wc -l)
    echo "历史文件数量: $file_count"

    if [ $file_count -gt 5 ]; then
        echo "最近5个文件:"
        echo "$history_files" | tail -5 | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            echo "  $(basename "$file") ($size)"
        done
    else
        echo "所有历史文件:"
        echo "$history_files" | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            echo "  $(basename "$file") ($size)"
        done
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
目录结构监控工具

用法: $0 [选项]

选项:
  --force         强制重新生成，即使当月文件已存在
  --compare-only  仅进行对比，不生成新的JSON文件
  -h, --help      显示此帮助信息

功能:
  - 生成Model和Vendor目录的JSON格式结构树
  - 与历史文件进行对比分析
  - 生成详细的变化报告

定时任务设置:
  # 每月10号凌晨2点执行
  0 2 10 * * /HDD_Raid/util_script/directory_structure_monitor.sh

输出文件:
  JSON文件: /HDD_Raid/log/directory_structure/Vendor_YYYY-MM.json
  对比报告: /HDD_Raid/log/directory_structure/comparison_YYYY-MM.txt

示例:
  $0                    # 正常执行
  $0 --force            # 强制重新生成
  $0 --compare-only     # 仅对比分析

EOF
}

# 检查帮助参数
for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            exit 0
            ;;
    esac
done

# 执行主程序
main

log_success "脚本执行完成"
