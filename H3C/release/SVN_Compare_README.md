# SVN目录结构对比工具使用说明

## 📋 功能概述

SVN目录结构对比工具 (`svn_structure_compare.sh`) 是一个用于比较远程SVN服务器和本地Vendor目录结构差异的自动化脚本。

### 🎯 主要功能

- 🌐 从远程SVN服务器获取完整目录结构
- 📄 将SVN目录结构转换为JSON格式
- 🔍 与本地Vendor目录进行详细对比
- 📊 生成详细的差异分析报告
- 💾 可选择保存SVN结构为JSON文件

## 🚀 快速开始

### 基本使用

```bash
# 显示帮助信息
/HDD_Raid/util_script/svn_structure_compare.sh --help

# 基本对比（不保存JSON）
/HDD_Raid/util_script/svn_structure_compare.sh

# 对比并保存SVN结构为JSON
/HDD_Raid/util_script/svn_structure_compare.sh --save-json

# 详细输出模式
/HDD_Raid/util_script/svn_structure_compare.sh --save-json --verbose
```

## ⚙️ 配置信息

### 默认配置

- **SVN URL**: `http://10.63.30.93/GPU_MODEL_REPO/01.DEV/`
- **SVN用户**: `sys49169`
- **SVN密码**: `Aa123,.,.*`
- **本地路径**: `/HDD_Raid/SVN_MODEL_REPO/Vendor`
- **输出目录**: `/HDD_Raid/log/svn_compare`

### 命令行参数

| 参数 | 说明 |
|------|------|
| `--save-json` | 保存SVN结构为JSON文件 |
| `--verbose` | 显示详细输出信息 |
| `-h, --help` | 显示帮助信息 |

## 📁 输出文件

### 文件命名规则

```
/HDD_Raid/log/svn_compare/
├── svn_structure_YYYY-MM-DD_HH-MM-SS.json    # SVN结构JSON文件
└── svn_comparison_YYYY-MM-DD_HH-MM-SS.txt    # 对比报告
```

### JSON文件格式

```json
{
  "generated_at": "2025-05-30 03:41:09",
  "source": "SVN",
  "svn_url": "http://10.63.30.93/GPU_MODEL_REPO/01.DEV/",
  "svn_username": "sys49169",
  "total_items": 2461,
  "items": [
    {
      "type": "directory",
      "name": "DataSet",
      "path": "DataSet",
      "parent": "."
    },
    {
      "type": "file",
      "name": "model.tar.gz",
      "path": "Vendor/Cambricon/model.tar.gz",
      "parent": "Vendor/Cambricon"
    }
  ]
}
```

## 📊 对比报告示例

```
SVN与本地目录结构对比报告
========================
生成时间: 2025-05-30 03:42:16
SVN URL: http://10.63.30.93/GPU_MODEL_REPO/01.DEV/
SVN用户: sys49169
本地路径: /HDD_Raid/SVN_MODEL_REPO/Vendor

=== 统计信息 ===
SVN Vendor目录:
  文件数量: 712
  目录数量: 447
  总计: 1159

本地Vendor目录:
  文件数量: 1547
  目录数量: 1097
  总计: 2644

=== 文件对比 ===
仅在SVN中存在的文件:
  + MetaX/MXC550/Bert-Large/Pre-training/v1.0/md5sums.txt
  + MetaX/MXC550/Bert-Large/Pre-training/v1.0/modelzoo_cnn_training_maca2_29_0_6.tar

仅在本地存在的文件:
  - AMD/GPU-AMD MI308X 8GPU/DeepSeek-R1-671B/inference/0325/rocm6.3.0_ubuntu22.04_py3.12_sglang_v0.4.4_0325.tar
  - Cambricon/MLU370-X8/Llama2-13B/Inference/v1.0/bangtransformer-0.4.0-ubuntu18.04-py3.tar.gz

共同文件数量: 708

=== 对比总结 ===
❌ 发现 843 处文件差异
  - 仅在SVN中: 4 个文件
  - 仅在本地: 839 个文件

建议操作:
  - 从SVN更新缺失的文件到本地
  - 检查本地多余文件是否需要提交到SVN
```

## 🔧 实际测试结果

### 最新测试数据

- **SVN服务器总条目**: 2,461 个
- **SVN Vendor目录**: 1,159 个（712文件 + 447目录）
- **本地Vendor目录**: 2,644 个（1,547文件 + 1,097目录）
- **文件差异**: 843 处
  - 仅在SVN中: 4 个文件
  - 仅在本地中: 839 个文件
  - 共同文件: 708 个

### 性能表现

- **SVN数据获取**: ~30秒（2,461个条目）
- **JSON转换**: ~5秒（600KB文件）
- **本地扫描**: ~10秒（2,644个条目）
- **对比分析**: ~5秒
- **总执行时间**: ~50秒

## 🛠️ 故障排除

### 常见问题

1. **SVN连接失败**
   ```bash
   [ERROR] SVN目录结构获取失败
   ```
   **解决方案**：
   - 检查网络连接：`ping 10.63.30.93`
   - 验证SVN服务：`curl -I http://10.63.30.93/GPU_MODEL_REPO/01.DEV/`
   - 确认认证信息正确

2. **依赖缺失**
   ```bash
   [ERROR] 缺少必要的依赖: subversion jq
   ```
   **解决方案**：
   ```bash
   # CentOS/RHEL
   yum install subversion jq
   
   # Ubuntu/Debian
   apt-get install subversion jq
   ```

3. **权限问题**
   ```bash
   [ERROR] 无法创建日志目录
   ```
   **解决方案**：
   ```bash
   mkdir -p /HDD_Raid/log/svn_compare
   chmod 755 /HDD_Raid/log/svn_compare
   ```

### 调试方法

```bash
# 测试SVN连接
svn list --username="sys49169" --password="Aa123,.,." --non-interactive --trust-server-cert "http://10.63.30.93/GPU_MODEL_REPO/01.DEV/"

# 检查本地目录
ls -la /HDD_Raid/SVN_MODEL_REPO/Vendor

# 验证JSON格式
jq '.' /HDD_Raid/log/svn_compare/svn_structure_*.json

# 查看详细日志
/HDD_Raid/util_script/svn_structure_compare.sh --verbose
```

## 📈 使用建议

### 定期对比

1. **每周对比**：了解SVN和本地的同步状态
2. **发布前对比**：确保所有必要文件已同步
3. **问题排查**：当发现文件缺失时进行对比

### 数据分析

1. **关注差异文件**：重点检查仅在一侧存在的文件
2. **版本管理**：利用JSON文件追踪历史变化
3. **同步策略**：根据对比结果制定同步计划

### 自动化集成

```bash
# 添加到定时任务
crontab -e

# 每天凌晨3点执行对比
0 3 * * * /HDD_Raid/util_script/svn_structure_compare.sh --save-json >> /HDD_Raid/log/svn_compare/cron.log 2>&1
```

## 🔗 相关工具

- **目录结构监控**: `/HDD_Raid/util_script/directory_structure_monitor.sh`
- **模型文档检查**: `/HDD_Raid/util_script/model_report.sh`
- **MD5校验工具**: `/HDD_Raid/util_script/check_md5.sh`

## 📞 技术支持

如果在使用过程中遇到问题，请：

1. 查看帮助信息：`--help`
2. 使用详细模式：`--verbose`
3. 检查日志文件：`/HDD_Raid/log/svn_compare/`
4. 验证网络连接和认证信息
5. 确认依赖软件已正确安装

---

**注意**: 此工具会连接到远程SVN服务器，请确保网络连接稳定且认证信息正确。
