#!/bin/bash

# 检查当前系统是否为CentOS或RHEL
if grep -q "CentOS" /etc/os-release || grep -q "Red Hat Enterprise Linux" /etc/os-release; then
    # 检查是否已安装kernel-tools
    if! rpm -q kernel-tools &>/dev/null; then
        echo "在CentOS/RHEL系统上，kernel-tools未安装，正在安装..."
        sudo yum install -y kernel-tools
        if [ $? -ne 0 ]; then
            echo "安装kernel-tools失败，请检查网络连接或手动安装。"
            exit 1
        fi
    fi
    # 设置CPU调节器模式为performance
    sudo cpupower frequency-set -g performance
    if [ $? -ne 0 ]; then
        echo "设置CPU调节器模式为performance失败，请检查权限或联系系统管理员。"
        exit 1
    fi
# 检查当前系统是否为Ubuntu
elif grep -q "Ubuntu" /etc/os-release; then
    # 检查是否已安装cpufrequtils
    if! dpkg -s cpufrequtils &>/dev/null; then
        echo "在Ubuntu系统上，cpufrequtils未安装，正在安装..."
        sudo apt-get update
        sudo apt-get install -y cpufrequtils
        if [ $? -ne 0 ]; then
            echo "安装cpufrequtils失败，请检查网络连接或手动安装。"
            exit 1
        fi
    fi
    # 设置CPU调节器模式为performance
    sudo cpufrequtils -c all -u performance
    if [ $? -ne 0 ]; then
        echo "设置CPU调节器模式为performance失败，请检查权限或联系系统管理员。"
        exit 1
    fi
else
    echo "不支持的操作系统，脚本仅支持CentOS/RHEL和Ubuntu。"
    exit 1
fi

# 查看CPU调节器模式并输出结果
current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
if [ -n "$current_governor" ]; then
    echo "当前CPU调节器模式为: $current_governor"
else
    echo "无法获取当前CPU调节器模式，请检查路径是否正确或权限是否足够。"
fi