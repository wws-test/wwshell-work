# Hardware Info Tool

一个用于收集和显示硬件信息的命令行工具。

## 功能特点

- 模块化设计，易于扩展
- 支持多种输出格式（表格、JSON）
- 智能缓存机制
- 完善的错误处理
- 插件系统支持
- 详细的日志记录
- 多环境配置支持

## 项目结构

```
H3C/
├── bin/                    # 可执行文件
├── src/                    # 源代码
│   ├── core/              # 核心功能
│   ├── modules/           # 功能模块
│   ├── plugins/           # 插件
│   └── utils/             # 工具函数
├── config/                # 配置文件
├── tests/                 # 测试文件
└── docs/                  # 文档
```

## 安装

```bash
git clone <repository_url>
cd hardware-info
./install.sh
```

## 使用方法

```bash
hardware-info [选项]

选项:
  -h, --help     显示帮助信息
  -a, --all      显示所有信息
  -s, --system   显示系统信息
  -c, --cpu      显示CPU信息
  -m, --memory   显示内存信息
  -d, --disk     显示磁盘信息
  -g, --gpu      显示GPU信息
  -n, --network  显示网络信息
  -b, --bios     显示BIOS信息
  -j, --json     使用JSON格式输出
```

## 配置

配置文件位于 `~/.config/hardware_info.conf`，支持以下配置项：

- REFRESH_INTERVAL: 刷新间隔（秒）
- CACHE_TIMEOUT: 缓存超时时间（秒）
- COLOR_OUTPUT: 是否启用彩色输出
- DETAILED_INFO: 是否显示详细信息

## 开发

### 添加新模块

1. 在 `src/modules` 目录下创建新模块
2. 实现模块接口
3. 在 `config/modules.conf` 中注册模块

### 创建插件

1. 在 `src/plugins` 目录下创建插件
2. 实现插件接口
3. 在 `config/plugins.conf` 中注册插件

## 测试

```bash
cd tests
./run_tests.sh
```

## 贡献

欢迎提交 Pull Request 或提出 Issue。

## 许可证

MIT License 