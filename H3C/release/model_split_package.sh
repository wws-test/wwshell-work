#!/bin/bash

#############################################################################
# 脚本名称: model_split_package.sh
# 功能描述: 智能分片打包大型模型文件夹
#          - 支持按文件类型分组（配置文件、模型文件、其他文件）
#          - 自动分片，确保每个tar包不超过指定大小（默认280GB）
#          - 保持原始目录结构
#          - 生成MD5校验文件
#
# 使用方法:
#   ./model_split_package.sh -t <目标目录> [-s <最大分片大小GB>] [-o <输出目录>]
#   例如: ./model_split_package.sh -t ./DeepSeek-Models -s 280 -o ./output
#############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 设置默认值
MAX_SIZE=280 # 单位：GB
TARGET_DIR=""
OUTPUT_DIR=""

# 日志函数
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        "INFO")  echo -e "${GREEN}[${timestamp}] [INFO] ${msg}${NC}" ;;
        "WARN")  echo -e "${YELLOW}[${timestamp}] [WARN] ${msg}${NC}" ;;
        "ERROR") echo -e "${RED}[${timestamp}] [ERROR] ${msg}${NC}" ;;
    esac
}

# 显示使用说明
show_usage() {
    echo "使用方法: $0 [-s size] [-t target_dir] [-o output_dir]"
    echo "选项:"
    echo "  -s: 指定单个tar包的最大大小（GB），默认为280GB"
    echo "  -t: 指定要打包的目标目录"
    echo "  -o: 指定输出目录（可选，默认在当前目录创建output文件夹）"
    exit 1
}

# 解析命令行参数
while getopts "s:t:o:h" opt; do
    case $opt in
        s) MAX_SIZE=$OPTARG ;;
        t) TARGET_DIR=$OPTARG ;;
        o) OUTPUT_DIR=$OPTARG ;;
        h|?) show_usage ;;
    esac
done

# 验证必要参数
if [ -z "$TARGET_DIR" ]; then
    log "ERROR" "必须指定目标目录 (-t)"
    show_usage
fi

# 设置默认输出目录
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="./output_$(date +%Y%m%d_%H%M%S)"
fi

# 验证目标目录存在
if [ ! -d "$TARGET_DIR" ]; then
    log "ERROR" "目标目录不存在: $TARGET_DIR"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 定义文件类型分组
declare -A FILE_PATTERNS=(
    ["config"]="\.conf$|\.config$|\.json$|\.ya?ml$|\.xml$|\.properties$|\.ini$|\.toml$|\.env$|\.cfg$"
    ["model"]="\.bin$|\.onnx$|\.tflite$|\.pt$|\.pth$|\.h5$|\.pb$|\.caffemodel$|\.keras$|\.joblib$|\.pickle$|\.pkl$|\.model$|\.savedmodel$"
    ["other"]=""  # 其他所有文件
)

# 创建工作目录
WORK_DIR="$OUTPUT_DIR/.work"
mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

# 计算分片大小（字节）
MAX_BYTES=$((MAX_SIZE * 1024 * 1024 * 1024))

# 分类文件
classify_files() {
    local file=$1
    local type="other"
    
    for t in "config" "model"; do
        if [[ $file =~ ${FILE_PATTERNS[$t]} ]]; then
            type=$t
            break
        fi
    done
    
    echo "$type"
}

# 创建分片打包函数
create_split_package() {
    local type=$1
    shift
    local files=("$@")
    local current_size=0
    local file_count=0
    local package_count=1
    local package_files=()
    
    log "INFO" "处理 $type 类型文件 (${#files[@]} 个文件)"
    
    for file in "${files[@]}"; do
        # 跨平台获取文件大小
        local file_size
        if [[ "$OSTYPE" == "darwin"* ]]; then
            file_size=$(stat -f%z "$file" 2>/dev/null)
        else
            file_size=$(stat -c%s "$file" 2>/dev/null)
        fi
        
        if [ $? -ne 0 ] || [ -z "$file_size" ]; then
            log "ERROR" "无法获取文件大小: $file"
            continue
        fi
        
        current_size=$((current_size + file_size))
        file_count=$((file_count + 1))
        package_files+=("$file")
        
        # 如果当前包大小接近限制或文件数量过多，创建新包
        if [ $current_size -ge $MAX_BYTES ] || [ $file_count -ge 1000 ]; then
            create_package "$type" "$package_count" "${package_files[@]}"
            package_count=$((package_count + 1))
            current_size=0
            file_count=0
            package_files=()
        fi
    done
    
    # 处理剩余文件
    if [ ${#package_files[@]} -gt 0 ]; then
        create_package "$type" "$package_count" "${package_files[@]}"
    fi
}

# 创建单个tar包
create_package() {
    local type=$1
    local count=$2
    shift 2
    local files=("$@")
    # 修改文件名格式，添加前缀以匹配extract脚本的查找模式
    local output_file="$OUTPUT_DIR/model_${type}_part${count}.tar.gz"
    
    # 写入文件列表
    local list_file="$WORK_DIR/${type}_part${count}.txt"
    printf "%s\n" "${files[@]}" > "$list_file"
    
    log "INFO" "创建包：$(basename "$output_file") (${#files[@]} 个文件)"
    
    # 创建相对路径文件列表
    local rel_files=()
    for file in "${files[@]}"; do
        # 移除TARGET_DIR前缀，保留相对路径
        rel_files+=("${file#$TARGET_DIR/}")
    done
    
    # 创建tar包，保持相对路径
    tar -czf "$output_file" -C "$TARGET_DIR" "${rel_files[@]}"
    
    # 生成MD5 - 使用相对路径
    for rel_file in "${rel_files[@]}"; do
        (cd "$TARGET_DIR" && md5sum "$rel_file") >> "$OUTPUT_DIR/md5sums.txt"
    done
}

# 主程序
main() {
    log "INFO" "开始分析目录: $TARGET_DIR"
    
    # 创建临时文件来存储分类后的文件列表
    local config_files="$WORK_DIR/config_files.txt"
    local model_files="$WORK_DIR/model_files.txt"
    local other_files="$WORK_DIR/other_files.txt"
    
    # 清空临时文件
    > "$config_files"
    > "$model_files"
    > "$other_files"
    
    # 分类文件并写入对应的临时文件
    while IFS= read -r -d '' file; do
        type=$(classify_files "$file")
        case "$type" in
            "config") echo "$file" >> "$config_files" ;;
            "model")  echo "$file" >> "$model_files" ;;
            "other")  echo "$file" >> "$other_files" ;;
        esac
    done < <(find "$TARGET_DIR" -type f -print0)
    
    # 创建空的MD5文件
    > "$OUTPUT_DIR/md5sums.txt"
    
    # 统计文件数量
    local config_count=$(wc -l < "$config_files" 2>/dev/null || echo 0)
    local model_count=$(wc -l < "$model_files" 2>/dev/null || echo 0)
    local other_count=$(wc -l < "$other_files" 2>/dev/null || echo 0)
    local total_files=$((config_count + model_count + other_count))
    
    log "INFO" "共发现 $total_files 个文件，开始分组打包..."
    
    # 处理每种类型的文件
    for type in "config" "model" "other"; do
        local file_list=""
        local count=0
        
        case "$type" in
            "config") file_list="$config_files"; count=$config_count ;;
            "model")  file_list="$model_files"; count=$model_count ;;
            "other")  file_list="$other_files"; count=$other_count ;;
        esac
        
        if [ $count -gt 0 ]; then
            log "INFO" "处理 $type 类型文件 ($count 个)..."
            # 读取文件列表并转换为数组
            local files=()
            while IFS= read -r file; do
                files+=("$file")
            done < "$file_list"
            create_split_package "$type" "${files[@]}"
        else
            log "WARN" "没有发现 $type 类型的文件"
        fi
    done
    
    log "INFO" "打包完成！"
    log "INFO" "输出目录：$OUTPUT_DIR"
    log "INFO" "MD5校验文件：$OUTPUT_DIR/md5sums.txt"
    
    # 清理工作目录
    rm -rf "$WORK_DIR"
}

# 执行主程序
main
