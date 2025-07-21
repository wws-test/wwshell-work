# 命令行注释标记功能修复

## 问题描述

用户希望能够直接在命令行后面添加注释标记，而不需要修改脚本文件。例如：

```bash
./long_script.sh # CMDMONITOR:experiment
```

## 修复内容

### 1. 增强的命令行获取方法

修改了 `getProcessCmdline` 方法，使用两种方式获取更完整的命令行信息：

1. **直接读取 `/proc/PID/cmdline`** - 处理null字符分隔的参数
2. **使用 `ps -o args` 命令** - 获取可能包含注释的完整命令行

```go
// 方法1: 尝试从 /proc/PID/cmdline 读取完整命令行
cmd := fmt.Sprintf("docker exec %s cat /proc/%d/cmdline", containerID, pid)
// ...处理null字符...

// 方法2: 使用ps命令获取更完整的命令行信息
psCmd := fmt.Sprintf("docker exec %s ps -p %d -o args --no-headers", containerID, pid)
```

### 2. 增强的注释标记检测

修改了 `hasCommentTagInContainer` 方法，增加了多层检测：

1. **当前进程命令检测**
2. **增强的完整命令行检测**
3. **父进程命令行检测**
4. **递归父进程检测**
5. **脚本文件内容检测**

### 3. 新增父进程PID获取方法

实现了 `getContainerParentPID` 方法来获取容器内进程的父进程PID。

## 部署步骤

### 1. 构建新版本

```bash
cd Go
python build.py build-linux
```

### 2. 部署到服务器

```bash
# 停止服务
systemctl stop cmdmonitor

# 备份当前版本
cp /usr/local/bin/cmdmonitor /usr/local/bin/cmdmonitor-backup-$(date +%Y%m%d-%H%M%S)

# 部署新版本
cp build/cmdmonitor-linux-amd64 /usr/local/bin/cmdmonitor
chmod +x /usr/local/bin/cmdmonitor

# 启动服务
systemctl start cmdmonitor
```

### 3. 测试功能

#### 测试1: 直接命令行注释

```bash
# 在容器中执行带注释的命令
docker exec -d 17f437d0877e bash -c 'sleep 600 # CMDMONITOR:test1'

# 检查进程
docker exec 17f437d0877e ps aux | grep sleep
```

#### 测试2: 脚本执行带注释

```bash
# 创建测试脚本
docker exec 17f437d0877e bash -c 'echo "#!/bin/bash" > /tmp/test.sh'
docker exec 17f437d0877e bash -c 'echo "sleep 600 # CMDMONITOR:test2" >> /tmp/test.sh'
docker exec 17f437d0877e chmod +x /tmp/test.sh

# 执行脚本
docker exec -d 17f437d0877e /tmp/test.sh
```

#### 测试3: 查看检测日志

```bash
# 实时查看日志
tail -f /var/log/cmdmonitor.log | grep -E "(CMDMONITOR|注释|test1|test2)"

# 如果需要更详细的调试信息
sed -i 's/LOG_LEVEL=info/LOG_LEVEL=debug/' /etc/cmdmonitor/config.env
systemctl restart cmdmonitor
```

## 预期结果

修复后，系统应该能够检测到以下类型的注释标记：

1. **直接命令行注释**: `sleep 600 # CMDMONITOR:test`
2. **bash -c 执行的注释**: `bash -c 'sleep 600 # CMDMONITOR:test'`
3. **脚本文件内的注释**: 脚本文件中包含 `# CMDMONITOR:test`
4. **父进程中的注释**: 父进程命令行包含注释标记

## 日志示例

成功检测到注释标记时，应该看到类似的日志：

```
time="2025-07-21 XX:XX:XX" level=debug msg="在完整命令行中发现注释标记: sleep 600 # CMDMONITOR:test1 (PID=12345)"
time="2025-07-21 XX:XX:XX" level=info msg="开始监控进程: sleep (PID=12345, 运行时间=1分钟)"
time="2025-07-21 XX:XX:XX" level=info msg="容器 17f437d0877e 扫描完成，发现 1 个符合条件的进程"
```

## 故障排除

### 1. 如果仍然检测不到注释标记

- 检查进程的实际命令行：`docker exec container ps -p PID -o args --no-headers`
- 检查父进程命令行：`docker exec container ps -p PPID -o args --no-headers`
- 启用debug日志查看详细检测过程

### 2. 如果服务启动失败

- 检查二进制文件权限：`ls -la /usr/local/bin/cmdmonitor`
- 查看服务日志：`journalctl -u cmdmonitor -f`
- 恢复备份版本：`cp /usr/local/bin/cmdmonitor-backup-* /usr/local/bin/cmdmonitor`

## 技术说明

### 为什么需要多种检测方法

1. **shell注释处理**: 当用户执行 `./script.sh # CMDMONITOR:test` 时，shell会将注释部分处理掉
2. **进程继承**: 子进程的 `/proc/PID/cmdline` 可能不包含完整的原始命令
3. **ps命令优势**: `ps -o args` 有时能显示比 `/proc/PID/cmdline` 更完整的信息
4. **父进程信息**: 父进程（如bash）可能保留了完整的命令行信息

### 检测优先级

1. 当前进程命令 → 2. 完整命令行 → 3. 父进程命令 → 4. 递归父进程 → 5. 脚本文件内容

这样确保了最大的兼容性和检测成功率。
