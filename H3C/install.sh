#!/bin/bash

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 设置变量
INSTALL_DIR="/usr/local/share/hardware_info"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/hardware_info"
LOG_DIR="/var/log/hardware_info"

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 需要root权限来安装${NC}"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    local deps=("bash" "grep" "sed" "awk" "date")
    local missing=()
    
    echo -e "${YELLOW}检查依赖...${NC}"
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少以下依赖:${NC}"
        printf '%s\n' "${missing[@]}"
        exit 1
    fi
    
    echo -e "${GREEN}所有依赖已满足${NC}"
}

# 创建目录
create_directories() {
    echo -e "${YELLOW}创建目录...${NC}"
    
    mkdir -p "$INSTALL_DIR"/{src/{core,modules,plugins,utils},config,docs}
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    
    echo -e "${GREEN}目录创建完成${NC}"
}

# 复制文件
copy_files() {
    echo -e "${YELLOW}复制文件...${NC}"
    
    # 复制源代码
    cp -r src/* "$INSTALL_DIR/src/"
    
    # 复制配置文件
    cp -r config/* "$CONFIG_DIR/"
    
    # 复制文档
    cp -r docs/* "$INSTALL_DIR/docs/"
    
    # 复制并设置可执行权限
    cp bin/hardware_info "$BIN_DIR/"
    chmod +x "$BIN_DIR/hardware_info"
    
    echo -e "${GREEN}文件复制完成${NC}"
}

# 设置权限
set_permissions() {
    echo -e "${YELLOW}设置权限...${NC}"
    
    # 设置目录权限
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
    
    # 设置文件权限
    chmod 644 "$CONFIG_DIR"/*
    chmod 644 "$INSTALL_DIR/docs"/*
    chmod 755 "$INSTALL_DIR/src"/**/*.sh
    
    # 设置所有者
    chown -R root:root "$INSTALL_DIR"
    chown -R root:root "$CONFIG_DIR"
    chown -R root:adm "$LOG_DIR"
    
    echo -e "${GREEN}权限设置完成${NC}"
}

# 创建配置文件
create_config() {
    echo -e "${YELLOW}创建配置文件...${NC}"
    
    if [ ! -f "$CONFIG_DIR/hardware_info.conf" ]; then
        cp config/default.conf "$CONFIG_DIR/hardware_info.conf"
    else
        echo -e "${YELLOW}配置文件已存在，跳过创建${NC}"
    fi
    
    echo -e "${GREEN}配置文件创建完成${NC}"
}

# 创建日志文件
create_log() {
    echo -e "${YELLOW}创建日志文件...${NC}"
    
    touch "$LOG_DIR/hardware_info.log"
    chmod 640 "$LOG_DIR/hardware_info.log"
    chown root:adm "$LOG_DIR/hardware_info.log"
    
    echo -e "${GREEN}日志文件创建完成${NC}"
}

# 安装完成消息
show_completion() {
    echo -e "\n${GREEN}安装完成!${NC}"
    echo -e "安装目录: ${YELLOW}$INSTALL_DIR${NC}"
    echo -e "配置文件: ${YELLOW}$CONFIG_DIR/hardware_info.conf${NC}"
    echo -e "日志文件: ${YELLOW}$LOG_DIR/hardware_info.log${NC}"
    echo -e "\n使用方法: ${YELLOW}hardware_info [选项]${NC}"
    echo -e "查看帮助: ${YELLOW}hardware_info --help${NC}"
}

# 主函数
main() {
    echo -e "${YELLOW}开始安装 Hardware Info...${NC}\n"
    
    check_root
    check_dependencies
    create_directories
    copy_files
    set_permissions
    create_config
    create_log
    show_completion
}

# 执行主函数
main 