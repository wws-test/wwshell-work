# 部署指南

本文档详细说明如何在Windows上编译Linux版本并部署到Linux服务器。

## 🚀 快速部署

### 方法1: 自动部署脚本（推荐）

```powershell
# 在Windows上运行
.\deploy.ps1 -Server "user@your-server" -EmailUser "your@qq.com" -EmailPass "your_auth_code"
```

### 方法2: 手动部署

```powershell
# 1. 编译Linux版本
.\build-linux.ps1

# 2. 上传到服务器
scp build/cmdmonitor-linux-amd64 user@your-server:/tmp/

# 3. 在服务器上安装
ssh user@your-server
sudo mv /tmp/cmdmonitor-linux-amd64 /usr/local/bin/cmdmonitor
sudo chmod +x /usr/local/bin/cmdmonitor
```

## 📋 详细步骤

### 1. 准备工作

**Windows端要求**:
- Go 1.21+ 已安装
- Git 已安装
- 可以SSH连接到Linux服务器

**Linux服务器要求**:
- Ubuntu 20.04+ 或 CentOS 7+ 或其他主流Linux发行版
- systemd 支持
- sudo 权限

### 2. 编译Linux版本

#### 选项A: 使用PowerShell脚本
```powershell
cd GO
.\build-linux.ps1
```

#### 选项B: 使用Makefile
```powershell
cd GO
make build-linux
```

#### 选项C: 手动编译
```powershell
cd GO
$env:GOOS="linux"
$env:GOARCH="amd64" 
$env:CGO_ENABLED="1"
go build -o build/cmdmonitor-linux-amd64 cmd/main.go
```

### 3. 配置邮箱

在部署前，您需要准备邮箱配置信息：

**QQ邮箱示例**:
- SMTP服务器: smtp.qq.com:587
- 用户名: your_qq_number@qq.com
- 密码: QQ邮箱授权码（不是QQ密码）

**获取QQ邮箱授权码**:
1. 登录QQ邮箱网页版
2. 设置 → 账户 → POP3/IMAP/SMTP服务
3. 开启IMAP/SMTP服务
4. 发送短信获取授权码

### 4. 部署到服务器

#### 自动部署
```powershell
.\deploy.ps1 -Server "root@192.168.1.100" -EmailUser "1092587222@qq.com" -EmailPass "abcdefghijklmnop"
```

参数说明:
- `-Server`: SSH连接字符串，格式为 `user@host` 或 `user@host:port`
- `-EmailUser`: 邮箱用户名
- `-EmailPass`: 邮箱密码/授权码
- `-EmailHost`: SMTP服务器（可选，默认smtp.qq.com）
- `-EmailPort`: SMTP端口（可选，默认587）
- `-EmailTo`: 收件人（可选，默认1092587222@qq.com）

#### 手动部署

**步骤1: 上传文件**
```bash
# 上传二进制文件
scp build/cmdmonitor-linux-amd64 user@server:/tmp/

# 上传配置文件
scp configs/cmdmonitor.service user@server:/tmp/
scp scripts/install.sh user@server:/tmp/
```

**步骤2: 服务器端安装**
```bash
# 连接到服务器
ssh user@server

# 安装二进制文件
sudo mv /tmp/cmdmonitor-linux-amd64 /usr/local/bin/cmdmonitor
sudo chmod +x /usr/local/bin/cmdmonitor

# 创建目录
sudo mkdir -p /etc/cmdmonitor
sudo mkdir -p /var/lib/cmdmonitor

# 创建配置文件
sudo tee /etc/cmdmonitor/config.env << EOF
EMAIL_SMTP_HOST=smtp.qq.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=your@qq.com
EMAIL_PASSWORD=your_auth_code
EMAIL_FROM_ADDRESS=your@qq.com
EMAIL_DEFAULT_TO=1092587222@qq.com
MONITOR_THRESHOLD_MINUTES=5
SCAN_INTERVAL_SECONDS=30
STORAGE_PATH=/var/lib/cmdmonitor/data.db
LOG_LEVEL=info
LOG_PATH=/var/log/cmdmonitor.log
EOF

# 设置配置文件权限
sudo chmod 600 /etc/cmdmonitor/config.env

# 安装systemd服务
sudo mv /tmp/cmdmonitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cmdmonitor
sudo systemctl start cmdmonitor
```

### 5. 验证部署

```bash
# 检查服务状态
sudo systemctl status cmdmonitor

# 查看日志
sudo journalctl -u cmdmonitor -f

# 测试邮件通知（服务启动时会自动发送测试邮件）
```

## 🔧 故障排除

### 编译问题

**问题1: CGO编译失败**
```
# 解决方案1: 安装交叉编译工具链
go install github.com/mattn/go-sqlite3

# 解决方案2: 禁用CGO（会失去SQLite支持）
$env:CGO_ENABLED="0"
go build -o build/cmdmonitor-linux-amd64 cmd/main.go
```

**问题2: 依赖问题**
```bash
# 清理并重新下载依赖
go clean -modcache
go mod tidy
```

### 部署问题

**问题1: SSH连接失败**
```bash
# 检查SSH连接
ssh -v user@server

# 检查SSH密钥
ssh-add -l
```

**问题2: 权限问题**
```bash
# 确保有sudo权限
sudo -l

# 检查文件权限
ls -la /usr/local/bin/cmdmonitor
```

**问题3: 服务启动失败**
```bash
# 查看详细错误
sudo journalctl -u cmdmonitor --no-pager -l

# 检查配置文件
sudo cat /etc/cmdmonitor/config.env

# 手动测试
sudo /usr/local/bin/cmdmonitor
```

### 邮件问题

**问题1: SMTP认证失败**
- 检查用户名和密码
- 确认使用授权码而不是登录密码
- 验证SMTP服务器和端口

**问题2: 邮件发送失败**
```bash
# 测试SMTP连接
telnet smtp.qq.com 587

# 检查防火墙
sudo ufw status
```

## 📝 配置文件示例

完整的配置文件示例：
```bash
# /etc/cmdmonitor/config.env

# 邮箱通知配置
EMAIL_SMTP_HOST=smtp.qq.com
EMAIL_SMTP_PORT=587
EMAIL_USERNAME=1092587222@qq.com
EMAIL_PASSWORD=abcdefghijklmnop
EMAIL_FROM_ADDRESS=1092587222@qq.com
EMAIL_DEFAULT_TO=1092587222@qq.com

# 监控配置
MONITOR_THRESHOLD_MINUTES=5
SCAN_INTERVAL_SECONDS=30
MAX_MONITORED_PROCESSES=50

# 存储配置
STORAGE_PATH=/var/lib/cmdmonitor/data.db

# 日志配置
LOG_LEVEL=info
LOG_PATH=/var/log/cmdmonitor.log

# 进程过滤
IGNORE_PROCESSES=systemd,kthreadd,ksoftirqd,migration,rcu_,watchdog
MONITOR_SYSTEM_PROCESSES=false

# Docker配置（暂时禁用）
MONITOR_DOCKER_ENABLED=false
```

## 🎯 常用命令

```bash
# 服务管理
sudo systemctl start cmdmonitor      # 启动
sudo systemctl stop cmdmonitor       # 停止
sudo systemctl restart cmdmonitor    # 重启
sudo systemctl status cmdmonitor     # 状态
sudo systemctl enable cmdmonitor     # 开机自启
sudo systemctl disable cmdmonitor    # 禁用自启

# 日志查看
sudo journalctl -u cmdmonitor -f     # 实时日志
sudo journalctl -u cmdmonitor -n 50  # 最近50行
sudo tail -f /var/log/cmdmonitor.log # 应用日志

# 配置管理
sudo nano /etc/cmdmonitor/config.env # 编辑配置
sudo systemctl restart cmdmonitor    # 重启生效

# 卸载
sudo systemctl stop cmdmonitor
sudo systemctl disable cmdmonitor
sudo rm /usr/local/bin/cmdmonitor
sudo rm /etc/systemd/system/cmdmonitor.service
sudo rm -rf /etc/cmdmonitor
sudo systemctl daemon-reload
```

---

**默认收件邮箱**: 1092587222@qq.com  
**推荐配置**: QQ邮箱 + 授权码
