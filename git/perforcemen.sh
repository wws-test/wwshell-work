#!/bin/bash

# 清除屏幕
clear

# 检查CPU使用情况
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
echo "CPU Usage: $cpu_usage%"
echo

# 检查内存使用情况
mem_usage=$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2}')
echo "Memory Usage: $mem_usage"
echo

# 检查磁盘I/O
disk_io=$(iostat -dxk 1 2 | awk 'NR==4{print $4}')
echo "Disk I/O (KB/s): $disk_io"
echo