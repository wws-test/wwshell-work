#!/bin/bash

#############################################################################
# 脚本名称: manager.sh
# 功能描述: H3C 工具集管理脚本
#
# 主要功能:
# 1. 提供统一的命令行界面来调用各个工具脚本
# 2. 包含详细的使用说明和帮助信息
# 3. 自动检查依赖和环境配置
#
# 包含工具:
# 1. check_md5.sh      - MD5校验工具
# 2. compass_folder.sh - 文件夹压缩备份工具
# 3. svn_prepare.sh    - SVN提交准备工具
# 4. svn_status_checker.sh - SVN状态检查工具
#
# 作者: sww
# 创建日期: 2025-05-12
#############################################################################

# 定义颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查系统依赖
check_dependencies() {
    local -r required_commands=("svn" "tar" "md5sum" "awk" "grep")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        echo -e "${RED}错误: 以下必需的命令未找到:${NC}"
        printf '%s\n' "${missing_commands[@]}"
        return 1
    fi
    return 0
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}H3C 工具集使用说明${NC}"
    echo "========================================"
    echo -e "${GREEN}可用命令:${NC}"
    echo "1. check    - 运行 MD5 校验工具"
    echo "2. compass  - 运行文件夹压缩备份工具"
    echo "3. prepare  - 运行 SVN 提交准备工具"
    echo "4. status   - 运行 SVN 状态检查工具"
    echo "5. help     - 显示此帮助信息"
    echo
    echo -e "${GREEN}详细说明:${NC}"
    echo -e "${YELLOW}check${NC} - MD5 校验工具"
    echo "  功能: 自动检查指定目录下所有 md5sums.txt 文件的校验结果"
    echo "  用法: ./manager.sh check"
    echo
    echo -e "${YELLOW}compass${NC} - 文件夹压缩备份工具"
    echo "  功能: 自动压缩和备份未被SVN管理的文件夹"
    echo "  - 创建 _bk 备份文件夹"
    echo "  - 压缩源文件夹为 tar.gz"
    echo "  - 生成 MD5 校验文件"
    echo "  用法: ./manager.sh compass"
    echo
    echo -e "${YELLOW}prepare${NC} - SVN 提交准备工具"
    echo "  功能: 检查备份文件并准备 SVN 提交"
    echo "  - 验证备份文件的完整性"
    echo "  - 移除备份文件夹的 _bk 后缀"
    echo "  - 将文件夹添加到 SVN"
    echo "  用法: ./manager.sh prepare"
    echo
    echo -e "${YELLOW}status${NC} - SVN 状态检查工具"
    echo "  功能: 检查指定厂商目录的 SVN 状态"
    echo "  - 显示未提交的文件"
    echo "  - 检查大文件大小"
    echo "  用法: ./manager.sh status"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "1. 压缩并备份文件夹:"
    echo "   ./manager.sh compass"
    echo
    echo "2. 检查备份是否完整:"
    echo "   ./manager.sh check"
    echo
    echo "3. 准备 SVN 提交:"
    echo "   ./manager.sh prepare"
    echo
    echo "4. 检查 SVN 状态:"
    echo "   ./manager.sh status"
}

# 运行指定的脚本
run_script() {
    local script="$1"
    local script_path="${SCRIPT_DIR}/${script}"
    
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}错误: 脚本 $script 不存在${NC}"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        chmod +x "$script_path"
    fi
    
    echo -e "${GREEN}正在运行 $script ...${NC}"
    "$script_path"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}$script 执行完成${NC}"
    else
        echo -e "${RED}$script 执行失败 (退出码: $exit_code)${NC}"
    fi
    
    return $exit_code
}

# 主程序
main() {
    # 检查依赖
    if ! check_dependencies; then
        echo -e "${RED}请安装缺失的依赖后重试${NC}"
        exit 1
    fi
    
    # 处理命令行参数
    case "$1" in
        check)
            nohup bash "${SCRIPT_DIR}/check_md5.sh" &
            echo -e "${GREEN}MD5 校验任务已在后台启动，请稍后通过日志文件查看进度和结果。${NC}"
            ;;
        compass)
            run_script "compass_folder.sh"
            ;;
        prepare)
            run_script "svn_prepare.sh"
            ;;
        status)
            run_script "svn_status_checker.sh"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${YELLOW}未知的命令: $1${NC}"
            echo -e "使用 ${GREEN}./manager.sh help${NC} 查看可用命令"
            exit 1
            ;;
    esac
}

# 如果没有参数，显示帮助信息
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# 执行主程序
main "$@"