# 目录结构监控工具使用说明

## 📋 功能概述

目录结构监控工具 (`directory_structure_monitor.sh`) 是一个用于监控SVN模型仓库目录结构变化的自动化脚本。它能够：

- 🌳 使用 `tree` 命令生成 Model 和 Vendor 目录的 JSON 格式结构树
- 📅 按月份自动保存 JSON 文件
- 🔍 与历史文件进行智能对比分析
- 📊 生成详细的变化报告
- ⏰ 支持定时任务自动执行

## 🚀 快速开始

### 安装依赖

确保系统已安装必要的依赖：

```bash
# 检查依赖
which tree jq

# 如果缺少，请安装
# CentOS/RHEL: yum install tree jq
# Ubuntu/Debian: apt-get install tree jq
```

### 基本使用

```bash
# 显示帮助信息
/HDD_Raid/util_script/directory_structure_monitor.sh --help

# 首次运行（生成当月JSON文件）
/HDD_Raid/util_script/directory_structure_monitor.sh --force

# 正常运行（如果当月文件已存在，会进行对比）
/HDD_Raid/util_script/directory_structure_monitor.sh

# 仅进行对比分析（不生成新文件）
/HDD_Raid/util_script/directory_structure_monitor.sh --compare-only
```

## 📁 文件结构

### 输出目录
```
/HDD_Raid/log/directory_structure/
├── Vendor_2024-12.json          # 2024年12月的目录结构
├── Vendor_2025-01.json          # 2025年1月的目录结构
├── Vendor_2025-05.json          # 2025年5月的目录结构
├── comparison_2025-01.txt       # 2025年1月的对比报告
├── comparison_2025-05.txt       # 2025年5月的对比报告
└── cron.log                     # 定时任务执行日志
```

### JSON文件格式
```json
{
  "generated_at": "2025-05-29 12:23:55",
  "directories": {
    "Model": {
      "type": "directory",
      "name": "/HDD_Raid/SVN_MODEL_REPO/Model",
      "contents": [
        {
          "type": "directory",
          "name": "Baichuan2-13B",
          "contents": [
            {
              "type": "file",
              "name": "Baichuan2-13B-Chat.tar.gz"
            }
          ]
        }
      ]
    },
    "Vendor": {
      "type": "directory",
      "name": "/HDD_Raid/SVN_MODEL_REPO/Vendor",
      "contents": [...]
    }
  }
}
```

## ⏰ 定时任务设置

### 自动设置定时任务

```bash
# 运行定时任务设置脚本
/HDD_Raid/util_script/setup_directory_monitor_cron.sh
```

### 手动设置定时任务

```bash
# 编辑crontab
crontab -e

# 添加以下行（每月10号凌晨2点执行）
0 2 10 * * /HDD_Raid/util_script/directory_structure_monitor.sh >> /HDD_Raid/log/directory_structure/cron.log 2>&1
```

### 验证定时任务

```bash
# 查看当前定时任务
crontab -l | grep directory_structure_monitor

# 查看执行日志
tail -f /HDD_Raid/log/directory_structure/cron.log
```

## 📊 对比报告示例

```
目录结构变化对比报告
====================
生成时间: 2025-05-29 12:24:32
当前文件: Vendor_2025-05.json
对比文件: Vendor_2025-04.json

=== Model目录变化 ===
新增项目:
  + file:new_model_v2.tar.gz
  + directory:ChatGLM3-6B
删除项目:
  - file:old_model_v1.tar.gz

=== Vendor目录变化 ===
新增项目:
  + directory:NewVendor
  + file:updated_driver.so
删除项目:
  - file:deprecated_lib.so

=== 统计信息 ===
当前文件数量:
  Model目录: 585 个文件
  Vendor目录: 742 个文件
  总计: 1327 个文件

对比文件数量:
  Model目录: 582 个文件
  Vendor目录: 739 个文件
  总计: 1321 个文件

变化量:
  Model目录: +3 个文件
  Vendor目录: +3 个文件
  总计: +6 个文件
```

## 🔧 高级用法

### 命令行参数

| 参数 | 说明 |
|------|------|
| `--force` | 强制重新生成，即使当月文件已存在 |
| `--compare-only` | 仅进行对比，不生成新的JSON文件 |
| `-h, --help` | 显示帮助信息 |

### 使用场景

1. **月度例行检查**：每月10号自动执行，生成当月目录结构并与上月对比
2. **手动检查**：在重要变更后手动运行，及时发现目录结构变化
3. **历史追溯**：通过历史JSON文件，可以追溯任意时间点的目录结构
4. **变更审计**：通过对比报告，可以清楚了解每月的文件变化情况

### 性能优化

- JSON文件大小通常在几百KB到几MB之间
- 扫描时间取决于目录中的文件数量，通常在1-5分钟内完成
- 对比分析通常在几秒内完成

## 🛠️ 故障排除

### 常见问题

1. **依赖缺失**
   ```bash
   [ERROR] 缺少必要的依赖命令: tree jq
   ```
   **解决方案**：安装缺失的命令

2. **权限问题**
   ```bash
   [ERROR] JSON文件保存失败
   ```
   **解决方案**：检查 `/HDD_Raid/log/directory_structure/` 目录权限

3. **磁盘空间不足**
   ```bash
   [ERROR] Model目录不存在
   ```
   **解决方案**：检查源目录是否存在和可访问

### 日志查看

```bash
# 查看最新的执行日志
tail -20 /HDD_Raid/log/directory_structure/cron.log

# 查看所有历史文件
ls -la /HDD_Raid/log/directory_structure/

# 检查JSON文件完整性
jq '.' /HDD_Raid/log/directory_structure/Vendor_2025-05.json > /dev/null && echo "JSON格式正确"
```

## 📈 监控建议

1. **定期检查**：建议每月查看对比报告，了解目录结构变化
2. **空间管理**：定期清理过旧的JSON文件（建议保留12个月）
3. **备份重要**：重要的JSON文件可以备份到其他位置
4. **异常告警**：可以结合其他监控工具，在发现异常变化时发送告警

## 🔗 相关文件

- 主脚本：`/HDD_Raid/util_script/directory_structure_monitor.sh`
- 定时任务设置：`/HDD_Raid/util_script/setup_directory_monitor_cron.sh`
- 输出目录：`/HDD_Raid/log/directory_structure/`
- 源目录：`/HDD_Raid/SVN_MODEL_REPO/Model` 和 `/HDD_Raid/SVN_MODEL_REPO/Vendor`

## 📞 技术支持

如果在使用过程中遇到问题，请：

1. 查看帮助信息：`--help`
2. 检查日志文件：`/HDD_Raid/log/directory_structure/cron.log`
3. 验证依赖安装：`which tree jq`
4. 检查目录权限：`ls -la /HDD_Raid/log/directory_structure/`
