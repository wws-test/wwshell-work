#!/bin/bash

#############################################################################
# 脚本名称: svn_structure_compare.sh
# 描述: 从远程SVN服务器获取目录结构并与本地Vendor目录进行对比
#
# 功能:
#   - 从远程SVN服务器获取目录结构
#   - 转换为JSON格式
#   - 与本地Vendor目录结构进行对比
#   - 生成详细的对比报告
#
# 用法: ./svn_structure_compare.sh [--save-json] [--verbose]
#
# 参数:
#   --save-json: 保存SVN结构为JSON文件
#   --verbose: 显示详细输出
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
NC='\033[0m'

# 配置信息
SVN_URL="http://10.63.30.93/GPU_MODEL_REPO/01.DEV/"
SVN_PASSWORD="Aa123,.,."
LOCAL_VENDOR_PATH="/HDD_Raid/SVN_MODEL_REPO/Vendor"
LOG_DIR="/HDD_Raid/log/svn_compare"
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_DIR="/tmp/svn_compare_$$"

# 输出文件
SVN_LIST_FILE="${TEMP_DIR}/svn_list.txt"
SVN_JSON_FILE="${LOG_DIR}/svn_structure_${DATE}.json"
LOCAL_JSON_FILE="${TEMP_DIR}/local_structure.json"
COMPARISON_REPORT="${LOG_DIR}/svn_comparison_${DATE}.txt"

# 解析命令行参数
SAVE_JSON=false
VERBOSE=false

for arg in "$@"; do
    case $arg in
        --save-json)
            SAVE_JSON=true
            ;;
        --verbose)
            VERBOSE=true
            ;;
        -h|--help)
            echo "SVN目录结构对比工具"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --save-json    保存SVN结构为JSON文件"
            echo "  --verbose      显示详细输出"
            echo "  -h, --help     显示此帮助信息"
            echo ""
            echo "功能:"
            echo "  - 从远程SVN服务器获取目录结构"
            echo "  - 与本地Vendor目录进行对比"
            echo "  - 生成详细的对比报告"
            echo ""
            echo "配置:"
            echo "  SVN URL: $SVN_URL"
            echo "  本地路径: $LOCAL_VENDOR_PATH"
            echo "  输出目录: $LOG_DIR"
            exit 0
            ;;
        *)
            echo "未知参数: $arg"
            echo "用法: $0 [--save-json] [--verbose] [-h|--help]"
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

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# 创建必要的目录
create_directories() {
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        log_info "创建日志目录: $LOG_DIR"
    fi

    if [ ! -d "$TEMP_DIR" ]; then
        mkdir -p "$TEMP_DIR"
    fi
}

# 检查依赖
check_dependencies() {
    local missing_deps=()

    if ! command -v svn >/dev/null 2>&1; then
        missing_deps+=("subversion")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi

    if ! command -v tree >/dev/null 2>&1; then
        missing_deps+=("tree")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少必要的依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# 从SVN获取目录结构
get_svn_structure() {
    log_info "从SVN服务器获取目录结构..."
    log_verbose "SVN URL: $SVN_URL"

    # 使用svn list获取递归目录结构
    if svn list --recursive --username="" --password="$SVN_PASSWORD" --non-interactive --trust-server-cert "$SVN_URL" > "$SVN_LIST_FILE" 2>/dev/null; then
        local file_count=$(wc -l < "$SVN_LIST_FILE")
        log_success "SVN目录结构获取成功，共 $file_count 个条目"
        log_verbose "SVN列表保存到: $SVN_LIST_FILE"
        return 0
    else
        log_error "SVN目录结构获取失败"
        log_error "请检查SVN URL、网络连接和认证信息"
        return 1
    fi
}

# 将SVN列表转换为JSON格式
convert_svn_to_json() {
    local output_file="$1"

    log_info "将SVN列表转换为JSON格式..."

    # 创建JSON结构
    cat > "$output_file" << EOF
{
  "generated_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "source": "SVN",
  "svn_url": "$SVN_URL",
  "structure": {
    "type": "directory",
    "name": "01.DEV",
    "contents": []
  }
}
EOF

    # 处理SVN列表，构建目录树
    local temp_structure="${TEMP_DIR}/structure_build.json"
    echo '{"contents": []}' > "$temp_structure"

    # 读取SVN列表并构建结构
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # 移除末尾的斜杠（如果是目录）
            local clean_path="${line%/}"

            # 判断是文件还是目录
            local item_type="file"
            if [[ "$line" == */ ]]; then
                item_type="directory"
            fi

            # 获取文件/目录名
            local item_name=$(basename "$clean_path")

            # 获取路径深度
            local depth=$(echo "$clean_path" | tr -cd '/' | wc -c)

            log_verbose "处理: $item_type - $clean_path (深度: $depth)"
        fi
    done < "$SVN_LIST_FILE"

    # 简化版本：直接创建扁平化的JSON结构
    log_info "创建简化的JSON结构..."

    cat > "$output_file" << EOF
{
  "generated_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "source": "SVN",
  "svn_url": "$SVN_URL",
  "total_items": $(wc -l < "$SVN_LIST_FILE"),
  "items": [
EOF

    # 添加每个条目
    local first_item=true
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local clean_path="${line%/}"
            local item_type="file"
            if [[ "$line" == */ ]]; then
                item_type="directory"
            fi

            local item_name=$(basename "$clean_path")
            local parent_path=$(dirname "$clean_path")

            if [ "$first_item" = true ]; then
                first_item=false
            else
                echo "," >> "$output_file"
            fi

            cat >> "$output_file" << EOF
    {
      "type": "$item_type",
      "name": "$item_name",
      "path": "$clean_path",
      "parent": "$parent_path"
    }
EOF
        fi
    done < "$SVN_LIST_FILE"

    echo "" >> "$output_file"
    echo "  ]" >> "$output_file"
    echo "}" >> "$output_file"

    # 验证JSON格式
    if jq '.' "$output_file" >/dev/null 2>&1; then
        log_success "SVN结构JSON文件创建成功: $output_file"
        local file_size=$(du -h "$output_file" | cut -f1)
        log_info "JSON文件大小: $file_size"
        return 0
    else
        log_error "JSON文件格式验证失败"
        return 1
    fi
}

# 获取本地Vendor目录结构
get_local_structure() {
    log_info "获取本地Vendor目录结构..."

    if [ ! -d "$LOCAL_VENDOR_PATH" ]; then
        log_error "本地Vendor目录不存在: $LOCAL_VENDOR_PATH"
        return 1
    fi

    # 使用tree命令生成JSON
    if tree -J "$LOCAL_VENDOR_PATH" > "$LOCAL_JSON_FILE" 2>/dev/null; then
        # 包装为标准格式
        local temp_file="${TEMP_DIR}/local_wrapped.json"
        cat > "$temp_file" << EOF
{
  "generated_at": "$(date +"%Y-%m-%d %H:%M:%S")",
  "source": "Local",
  "local_path": "$LOCAL_VENDOR_PATH",
  "structure": $(cat "$LOCAL_JSON_FILE" | jq '.[0]')
}
EOF
        mv "$temp_file" "$LOCAL_JSON_FILE"

        log_success "本地目录结构获取成功"
        local file_size=$(du -h "$LOCAL_JSON_FILE" | cut -f1)
        log_info "本地JSON文件大小: $file_size"
        return 0
    else
        log_error "本地目录结构获取失败"
        return 1
    fi
}

# 比较SVN和本地结构
compare_structures() {
    local svn_json="$1"
    local local_json="$2"
    local report_file="$3"

    log_info "开始比较SVN和本地目录结构..."

    # 创建对比报告
    cat > "$report_file" << EOF
SVN与本地目录结构对比报告
========================
生成时间: $(date +"%Y-%m-%d %H:%M:%S")
SVN URL: $SVN_URL
本地路径: $LOCAL_VENDOR_PATH

EOF

    # 提取SVN中的文件列表
    log_verbose "提取SVN文件列表..."
    jq -r '.items[] | select(.type == "file") | .path' "$svn_json" | sort > "${TEMP_DIR}/svn_files.txt"
    jq -r '.items[] | select(.type == "directory") | .path' "$svn_json" | sort > "${TEMP_DIR}/svn_dirs.txt"

    # 提取本地文件列表
    log_verbose "提取本地文件列表..."
    jq -r '.structure | .. | select(type == "object" and has("name") and has("type") and .type == "file") | .name' "$local_json" | sort > "${TEMP_DIR}/local_files.txt"
    jq -r '.structure | .. | select(type == "object" and has("name") and has("type") and .type == "directory") | .name' "$local_json" | sort > "${TEMP_DIR}/local_dirs.txt"

    # 统计信息
    local svn_file_count=$(wc -l < "${TEMP_DIR}/svn_files.txt")
    local svn_dir_count=$(wc -l < "${TEMP_DIR}/svn_dirs.txt")
    local local_file_count=$(wc -l < "${TEMP_DIR}/local_files.txt")
    local local_dir_count=$(wc -l < "${TEMP_DIR}/local_dirs.txt")

    echo "=== 统计信息 ===" >> "$report_file"
    echo "SVN服务器:" >> "$report_file"
    echo "  文件数量: $svn_file_count" >> "$report_file"
    echo "  目录数量: $svn_dir_count" >> "$report_file"
    echo "  总计: $((svn_file_count + svn_dir_count))" >> "$report_file"
    echo "" >> "$report_file"
    echo "本地Vendor:" >> "$report_file"
    echo "  文件数量: $local_file_count" >> "$report_file"
    echo "  目录数量: $local_dir_count" >> "$report_file"
    echo "  总计: $((local_file_count + local_dir_count))" >> "$report_file"
    echo "" >> "$report_file"

    # 文件对比
    echo "=== 文件对比 ===" >> "$report_file"
    local files_only_in_svn=$(comm -23 "${TEMP_DIR}/svn_files.txt" "${TEMP_DIR}/local_files.txt")
    local files_only_in_local=$(comm -13 "${TEMP_DIR}/svn_files.txt" "${TEMP_DIR}/local_files.txt")
    local common_files=$(comm -12 "${TEMP_DIR}/svn_files.txt" "${TEMP_DIR}/local_files.txt")

    if [ -n "$files_only_in_svn" ]; then
        echo "仅在SVN中存在的文件:" >> "$report_file"
        echo "$files_only_in_svn" | head -20 | sed 's/^/  + /' >> "$report_file"
        local svn_only_count=$(echo "$files_only_in_svn" | wc -l)
        if [ $svn_only_count -gt 20 ]; then
            echo "  ... 还有 $((svn_only_count - 20)) 个文件" >> "$report_file"
        fi
        echo "" >> "$report_file"
    fi

    if [ -n "$files_only_in_local" ]; then
        echo "仅在本地存在的文件:" >> "$report_file"
        echo "$files_only_in_local" | head -20 | sed 's/^/  - /' >> "$report_file"
        local local_only_count=$(echo "$files_only_in_local" | wc -l)
        if [ $local_only_count -gt 20 ]; then
            echo "  ... 还有 $((local_only_count - 20)) 个文件" >> "$report_file"
        fi
        echo "" >> "$report_file"
    fi

    local common_count=$(echo "$common_files" | wc -l)
    echo "共同文件数量: $common_count" >> "$report_file"
    echo "" >> "$report_file"

    # 目录对比
    echo "=== 目录对比 ===" >> "$report_file"
    local dirs_only_in_svn=$(comm -23 "${TEMP_DIR}/svn_dirs.txt" "${TEMP_DIR}/local_dirs.txt")
    local dirs_only_in_local=$(comm -13 "${TEMP_DIR}/svn_dirs.txt" "${TEMP_DIR}/local_dirs.txt")
    local common_dirs=$(comm -12 "${TEMP_DIR}/svn_dirs.txt" "${TEMP_DIR}/local_dirs.txt")

    if [ -n "$dirs_only_in_svn" ]; then
        echo "仅在SVN中存在的目录:" >> "$report_file"
        echo "$dirs_only_in_svn" | head -20 | sed 's/^/  + /' >> "$report_file"
        local svn_dir_only_count=$(echo "$dirs_only_in_svn" | wc -l)
        if [ $svn_dir_only_count -gt 20 ]; then
            echo "  ... 还有 $((svn_dir_only_count - 20)) 个目录" >> "$report_file"
        fi
        echo "" >> "$report_file"
    fi

    if [ -n "$dirs_only_in_local" ]; then
        echo "仅在本地存在的目录:" >> "$report_file"
        echo "$dirs_only_in_local" | head -20 | sed 's/^/  - /' >> "$report_file"
        local local_dir_only_count=$(echo "$dirs_only_in_local" | wc -l)
        if [ $local_dir_only_count -gt 20 ]; then
            echo "  ... 还有 $((local_dir_only_count - 20)) 个目录" >> "$report_file"
        fi
        echo "" >> "$report_file"
    fi

    local common_dir_count=$(echo "$common_dirs" | wc -l)
    echo "共同目录数量: $common_dir_count" >> "$report_file"
    echo "" >> "$report_file"

    # 总结
    echo "=== 对比总结 ===" >> "$report_file"
    local total_differences=$(($(echo "$files_only_in_svn" | wc -l) + $(echo "$files_only_in_local" | wc -l) + $(echo "$dirs_only_in_svn" | wc -l) + $(echo "$dirs_only_in_local" | wc -l)))

    if [ $total_differences -eq 0 ]; then
        echo "✅ SVN和本地目录结构完全一致" >> "$report_file"
    else
        echo "❌ 发现 $total_differences 处差异" >> "$report_file"
        echo "建议检查差异项目并进行同步" >> "$report_file"
    fi

    log_success "对比报告生成完成: $report_file"
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
    echo -e "${CYAN}=== SVN目录结构对比工具 ===${NC}"
    echo "执行时间: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "SVN URL: $SVN_URL"
    echo "本地路径: $LOCAL_VENDOR_PATH"
    echo "输出目录: $LOG_DIR"
    echo ""

    # 检查依赖
    check_dependencies

    # 创建目录
    create_directories

    # 步骤1: 获取SVN目录结构
    if ! get_svn_structure; then
        log_error "无法获取SVN目录结构，退出"
        exit 1
    fi

    # 步骤2: 转换SVN列表为JSON
    local svn_json_target="$SVN_JSON_FILE"
    if [ "$SAVE_JSON" = false ]; then
        svn_json_target="${TEMP_DIR}/svn_structure.json"
    fi

    if ! convert_svn_to_json "$svn_json_target"; then
        log_error "SVN结构JSON转换失败，退出"
        exit 1
    fi

    # 步骤3: 获取本地目录结构
    if ! get_local_structure; then
        log_error "无法获取本地目录结构，退出"
        exit 1
    fi

    # 步骤4: 进行对比
    if ! compare_structures "$svn_json_target" "$LOCAL_JSON_FILE" "$COMPARISON_REPORT"; then
        log_error "目录结构对比失败，退出"
        exit 1
    fi

    # 显示结果摘要
    echo ""
    echo -e "${CYAN}=== 执行结果摘要 ===${NC}"

    if [ "$SAVE_JSON" = true ]; then
        echo "SVN结构JSON: $SVN_JSON_FILE"
        local svn_size=$(du -h "$SVN_JSON_FILE" | cut -f1)
        echo "SVN JSON大小: $svn_size"
    fi

    echo "对比报告: $COMPARISON_REPORT"
    local report_size=$(du -h "$COMPARISON_REPORT" | cut -f1)
    echo "报告大小: $report_size"

    # 显示对比结果预览
    echo ""
    echo -e "${CYAN}=== 对比结果预览 ===${NC}"

    # 显示统计信息
    if grep -q "统计信息" "$COMPARISON_REPORT"; then
        echo "统计信息:"
        sed -n '/=== 统计信息 ===/,/=== 文件对比 ===/p' "$COMPARISON_REPORT" | head -15
    fi

    # 显示总结
    if grep -q "对比总结" "$COMPARISON_REPORT"; then
        echo "对比总结:"
        sed -n '/=== 对比总结 ===/,$p' "$COMPARISON_REPORT"
    fi

    echo ""
    echo "完整报告请查看: $COMPARISON_REPORT"
}

# 显示使用示例
show_examples() {
    cat << EOF
使用示例:

1. 基本对比（不保存SVN JSON）:
   $0

2. 对比并保存SVN结构为JSON:
   $0 --save-json

3. 详细输出模式:
   $0 --verbose --save-json

4. 查看帮助:
   $0 --help

输出文件说明:
- 对比报告: /HDD_Raid/log/svn_compare/svn_comparison_YYYY-MM-DD_HH-MM-SS.txt
- SVN JSON: /HDD_Raid/log/svn_compare/svn_structure_YYYY-MM-DD_HH-MM-SS.json (使用--save-json时)

EOF
}

# 检查是否需要显示示例
if [ $# -eq 0 ]; then
    echo "提示: 使用 $0 --help 查看详细帮助信息"
    echo ""
fi

# 执行主程序
main

log_success "SVN目录结构对比完成"
