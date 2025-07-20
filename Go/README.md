# Command Monitor - 精准监控

🎯 **精准监控长命令执行，智能邮件通知** - 一个专为长时间运行任务设计的监控工具

## ✨ 核心特性

- 🎯 **精准监控** - 只监控明确标记的进程，避免无用提醒
- 📧 **智能通知** - 任务完成时发送详细邮件通知
- 🐳 **容器支持** - 完美支持Docker容器内进程监控
- ⚡ **轻量高效** - 低资源占用，适合长期运行
- 🔧 **简单易用** - 两种标记方式，灵活便捷

## 🎯 精准监控模式

### 方式1：注释标记
```bash
# 在命令后添加监控标记
python train_model.py --epochs 100 # MONITOR:training
./long_script.sh # CMDMONITOR:experiment
nohup data_process.py & # TRACK:processing
```

### 方式2：动态标记
```bash
# 为已运行的进程添加监控
echo "PID:12345:training_task" >> /etc/cmdmonitor/dynamic_tags.txt

# 查看当前标记
cat /etc/cmdmonitor/dynamic_tags.txt

# 删除标记
sed -i '/PID:12345:/d' /etc/cmdmonitor/dynamic_tags.txt
```

## 🚀 快速部署

### 一键安装脚本
```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/your-org/cmdmonitor/main/scripts/install.sh | sudo bash
```

### 手动安装
```bash
# 1. 下载部署包
wget https://github.com/your-org/cmdmonitor/releases/latest/download/cmdmonitor-deploy.tar.gz
tar -xzf cmdmonitor-deploy.tar.gz
cd deploy/

# 2. 运行安装脚本
sudo ./install.sh

# 3. 配置邮箱（编辑配置文件）
sudo nano /etc/cmdmonitor/config.env

# 4. 启动服务
sudo systemctl start cmdmonitor
sudo systemctl enable cmdmonitor
```

## ⚙️ 配置说明

### 邮箱配置（必需）
```bash
# QQ邮箱示例
EMAIL_SMTP_HOST=smtp.qq.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your@qq.com
EMAIL_PASSWORD=your_auth_code  # QQ邮箱授权码
EMAIL_FROM_ADDRESS=your@qq.com
EMAIL_DEFAULT_TO=your@qq.com
```

### 监控配置
```bash
SCAN_INTERVAL_SECONDS=30        # 扫描间隔
MONITOR_THRESHOLD_MINUTES=5     # 最小监控时间
MONITOR_DOCKER_ENABLED=true     # 启用Docker监控
MAX_MONITORED_PROCESSES=20      # 最大监控进程数
```

## 📧 邮件通知示例

```
🔔 长命令执行完成通知
===============================

✅ 执行状态: 成功
📋 命令名称: bash run_1k_4K.sh

详细信息:
---------------------
⏱️  执行时长: 1天16小时
📊 退出码: 0
🔢 进程ID: 62969
📍 运行环境: Docker容器 (17f437d0877e)
👤 执行用户: root
🕐 开始时间: 2025-07-18 10:30:00
🕑 完成时间: 2025-07-20 02:45:00

==================================================
此邮件由 Command Monitor 自动发送
```

## 🔧 使用示例

### 机器学习训练
```bash
# 训练模型时添加监控标记
python train.py --model bert --epochs 50 # MONITOR:bert_training

# 或在脚本开头添加标记
#!/bin/bash
# MONITOR:model_training
python train.py --config config.yaml
```

### 数据处理任务
```bash
# 大数据处理
./process_data.sh # CMDMONITOR:data_processing

# 已运行的任务动态添加监控
ps aux | grep process_data  # 找到PID
echo "PID:12345:data_processing" >> /etc/cmdmonitor/dynamic_tags.txt
```

### Docker容器任务
```bash
# 容器内任务自动监控
docker exec -it mycontainer bash -c "python long_task.py # MONITOR:container_task"

# 为容器内已运行进程添加监控
echo "PID:62969:benchmark_task" >> /etc/cmdmonitor/dynamic_tags.txt
```

## 📊 监控状态查看

```bash
# 查看服务状态
sudo systemctl status cmdmonitor

# 查看实时日志
sudo journalctl -u cmdmonitor -f

# 查看当前监控的进程
sudo tail -20 /var/log/cmdmonitor.log | grep "监控中"

# 查看动态标记
cat /etc/cmdmonitor/dynamic_tags.txt
```

## 🛠️ 开发构建

### 构建命令

**Linux/macOS (Makefile)**：
```bash
make                # 构建Linux版本（默认）
make package        # 创建部署包
make test           # 运行测试
make help           # 查看帮助
```

**跨平台 (Python)**：
```bash
python build.py build-linux   # 构建Linux版本
python build.py package       # 创建部署包
python build.py test          # 运行测试
python build.py help          # 查看帮助
```

### 项目结构
```
cmdmonitor/
├── cmd/main.go              # 主程序入口
├── internal/
│   ├── monitor/             # 进程监控核心
│   ├── notification/        # 邮件通知
│   ├── storage/            # 数据存储
│   └── config/             # 配置管理
├── configs/
│   ├── config.env          # 配置文件
│   └── cmdmonitor.service  # 系统服务
├── scripts/install.sh      # 安装脚本
├── DEPLOYMENT.md           # 部署文档
├── Makefile               # Linux构建脚本
└── build.py               # 跨平台构建脚本
```

## 🐛 故障排除

### 邮件发送问题
```bash
# 检查邮箱配置
sudo cat /etc/cmdmonitor/config.env

# 查看邮件发送日志
sudo journalctl -u cmdmonitor | grep "邮件"
```

### 进程监控问题
```bash
# 检查是否有标记
cat /etc/cmdmonitor/dynamic_tags.txt

# 查看监控日志
sudo tail -50 /var/log/cmdmonitor.log
```

### 权限问题
```bash
# 修复配置文件权限
sudo chmod 600 /etc/cmdmonitor/config.env
sudo chown root:root /etc/cmdmonitor/config.env
```

## 📄 许可证

MIT License - 查看 [LICENSE](LICENSE) 文件了解详情

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**精准监控，智能通知 - 让长任务执行更安心** 🚀
