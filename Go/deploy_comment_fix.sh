#!/bin/bash

# 部署命令行注释标记功能修复的脚本

echo "=== 部署命令行注释标记功能修复 ==="

# 检查是否有新的二进制文件
if [ ! -f "build/cmdmonitor-linux-amd64" ]; then
    echo "错误: 找不到构建的二进制文件 build/cmdmonitor-linux-amd64"
    echo "请先运行: python build.py build-linux"
    exit 1
fi

echo "1. 停止当前服务..."
systemctl stop cmdmonitor

echo "2. 备份当前二进制文件..."
cp /usr/local/bin/cmdmonitor /usr/local/bin/cmdmonitor-backup-$(date +%Y%m%d-%H%M%S)

echo "3. 部署新的二进制文件..."
cp build/cmdmonitor-linux-amd64 /usr/local/bin/cmdmonitor
chmod +x /usr/local/bin/cmdmonitor

echo "4. 启动服务..."
systemctl start cmdmonitor

echo "5. 检查服务状态..."
systemctl status cmdmonitor --no-pager

echo ""
echo "=== 测试命令行注释标记功能 ==="

# 创建测试脚本
cat > /tmp/test_cmdline_comment.sh << 'EOF'
#!/bin/bash
echo "测试命令行注释标记功能..."

# 测试1: 直接在容器中执行带注释的命令
echo "在容器中执行: sleep 600 # CMDMONITOR:cmdline_test"
docker exec -d 17f437d0877e bash -c 'sleep 600 # CMDMONITOR:cmdline_test'

# 等待几秒让进程启动
sleep 3

# 检查容器中的进程
echo "容器中的sleep进程:"
docker exec 17f437d0877e ps aux | grep sleep

echo ""
echo "等待系统检测进程（约30-60秒）..."
echo "请查看日志: tail -f /var/log/cmdmonitor.log | grep -E '(CMDMONITOR|注释|cmdline_test)'"
EOF

chmod +x /tmp/test_cmdline_comment.sh

echo "6. 运行测试..."
/tmp/test_cmdline_comment.sh

echo ""
echo "=== 部署完成 ==="
echo "新功能已部署，请查看日志验证功能："
echo "  tail -f /var/log/cmdmonitor.log | grep -E '(CMDMONITOR|注释|cmdline_test)'"
echo ""
echo "如果需要调试，可以临时启用debug日志："
echo "  sed -i 's/LOG_LEVEL=info/LOG_LEVEL=debug/' /etc/cmdmonitor/config.env"
echo "  systemctl restart cmdmonitor"
