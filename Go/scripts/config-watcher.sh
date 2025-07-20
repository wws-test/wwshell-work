#!/bin/bash

# 配置文件监控脚本
# 当配置文件修改时自动重启 cmdmonitor 服务

CONFIG_FILE="/etc/cmdmonitor/config.env"
SERVICE_NAME="cmdmonitor"
LOG_FILE="/var/log/cmdmonitor-watcher.log"

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    log "错误: 配置文件 $CONFIG_FILE 不存在"
    exit 1
fi

# 检查 inotify-tools 是否安装
if ! command -v inotifywait &> /dev/null; then
    log "错误: inotify-tools 未安装，请运行: sudo apt-get install inotify-tools"
    exit 1
fi

log "开始监控配置文件: $CONFIG_FILE"

# 监控配置文件变化
inotifywait -m -e modify,move,create,delete "$CONFIG_FILE" --format '%w%f %e' |
while read file event; do
    log "检测到配置文件变化: $file ($event)"
    
    # 等待一秒，确保文件写入完成
    sleep 1
    
    # 验证配置文件语法
    if ! bash -n "$CONFIG_FILE" 2>/dev/null; then
        log "警告: 配置文件语法错误，跳过重启"
        continue
    fi
    
    log "重启 $SERVICE_NAME 服务..."
    
    # 重启服务
    if systemctl restart "$SERVICE_NAME"; then
        log "服务重启成功"
        
        # 等待服务启动
        sleep 2
        
        # 检查服务状态
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log "服务运行正常"
        else
            log "警告: 服务重启后状态异常"
            systemctl status "$SERVICE_NAME" >> "$LOG_FILE" 2>&1
        fi
    else
        log "错误: 服务重启失败"
        systemctl status "$SERVICE_NAME" >> "$LOG_FILE" 2>&1
    fi
done
