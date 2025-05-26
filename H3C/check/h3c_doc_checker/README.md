# H3C Word文档规范检查工具（现代包结构）

## 项目简介
本工具用于自动检查 Word 文档是否符合预设模板规范，支持批量校验、详细报告导出、GUI 操作和一键打包为独立可执行文件。

## 目录结构
```
h3c_doc_checker/
├── __init__.py
├── __main__.py           # 入口，可用 python -m h3c_doc_checker 启动
├── main.py               # CLI/核心逻辑
├── gui.py                # 图形界面
├── splash.py             # 启动界面
├── utils.py              # 工具函数
├── config.py             # 配置加载与校验
├── check_env.py          # 环境检测
├── checkers/             # 检查器子模块
│   ├── __init__.py
│   ├── title_checker.py
│   ├── table_checker.py
│   └── content_checker.py
├── config/
│   └── *.json  # 配置文件
├── resources/
│   └── icon.ico
└── README.md
```

## 快速开始
### 1. 安装依赖（推荐 Poetry）
```bash
cd H3C/check
poetry install
```

### 2. 运行（开发环境）
```bash
poetry run python -m h3c_doc_checker
```
或
```bash
python -m h3c_doc_checker
```

### 3. 打包为独立 EXE（推荐 PyInstaller）
```bash
pyinstaller --onefile -w -n docx_checker h3c_doc_checker/__main__.py
```
打包后在 dist/ 目录下生成 docx_checker.exe。

## 主要功能
- 支持 Word 文档标题、表格、内容多维度规范检查
- 支持自定义 JSON 配置模板
- 支持详细报告导出（HTML）
- 支持现代美观的 GUI 操作，带启动画面
- 支持一键打包为 Windows 独立可执行文件

## 配置说明
详见 `config/` 目录下的配置文件，或在 GUI 内点击“查看配置说明”。

## 资源文件访问
所有资源（如 icon、配置）均通过 `importlib.resources` 访问，打包后无需担心路径丢失。

## 依赖
- python-docx
- ttkthemes
- poetry（推荐）
- pyinstaller（可选，打包用）

## 贡献与维护
如需二次开发，建议所有新模块均放入 `h3c_doc_checker/` 包内，导入统一用 `from h3c_doc_checker.xxx import ...`。

---
如有问题请联系维护者。
