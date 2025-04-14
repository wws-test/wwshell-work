#!/bin/bash

# 检查 /etc/docker/daemon.json 文件是否存在
if [ -f "/etc/docker/daemon.json" ]; then
    echo "文件已存在，将进行覆盖"
else
    echo "文件不存在，将创建新文件"
    sudo mkdir -p /etc/docker
fi

# 写入配置内容
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://weamrb4h.mirror.aliyuncs.com"]
}
EOF

# 重新加载 Docker 守护进程
sudo systemctl daemon-reload
sudo systemctl restart docker