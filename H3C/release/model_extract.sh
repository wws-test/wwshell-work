 #!/bin/bash

#############################################################################
# 脚本名称: model_extract.sh
# 功能描述: 解压模型分片文件，还原原始目录结构
#
# 使用方法:
#   ./model_extract.sh [tar包所在目录] [解压目标目录]
#   例如: ./model_extract.sh . ./DeepSeek-R1-0528
#############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# 检查参数
if [ $# -lt 2 ]; then
    echo "用法: $0 [tar包所在目录] [解压目标目录]"
    echo "例如: $0 . ./DeepSeek-R1-0528"
    exit 1
fi

SRC_DIR="$1"
TARGET_DIR="$2"

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 获取所有tar包列表
log "INFO" "查找所有tar包..."
configs=($(find "$SRC_DIR" -name "*_config_part*.tar.gz" | sort))
models=($(find "$SRC_DIR" -name "*_model_part*.tar.gz" | sort))
others=($(find "$SRC_DIR" -name "*_other_part*.tar.gz" | sort))

# 显示找到的文件
log "INFO" "找到以下文件："
echo "配置文件包: ${#configs[@]} 个"
echo "模型文件包: ${#models[@]} 个"
echo "其他文件包: ${#others[@]} 个"

# 解压函数
extract_files() {
    local files=("$@")
    
    for file in "${files[@]}"; do
        log "INFO" "正在解压: $(basename "$file")"
        if ! tar -xzf "$file" -C "$TARGET_DIR"; then
            log "ERROR" "解压失败: $file"
            return 1
        fi
    done
    return 0
}

# 按顺序解压
echo -e "\n${YELLOW}开始解压文件...${NC}"

# 1. 先解压配置文件
log "INFO" "解压配置文件..."
extract_files "${configs[@]}" || exit 1

# 2. 解压模型文件
log "INFO" "解压模型文件..."
extract_files "${models[@]}" || exit 1

# 3. 最后解压其他文件
log "INFO" "解压其他文件..."
extract_files "${others[@]}" || exit 1

# 验证结果
if [ -f "$TARGET_DIR/md5sums.txt" ]; then
    log "INFO" "开始验证文件完整性..."
    cd "$TARGET_DIR" || exit 1
    if md5sum -c md5sums.txt; then
        log "INFO" "✅ 所有文件验证成功！"
    else
        log "ERROR" "❌ 部分文件验证失败，请检查日志"
        exit 1
    fi
else
    log "WARN" "未找到md5sums.txt，跳过文件验证"
fi

log "INFO" "解压完成，文件已还原到: $TARGET_DIR"
echo -e "\n目录结构预览:"
if command -v tree >/dev/null 2>&1; then
    tree -L 2 "$TARGET_DIR"
else
    ls -la "$TARGET_DIR"
fi
