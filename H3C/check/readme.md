# H3C Word文档规范自动检查工具

## 项目简介
本项目旨在自动化检查Word文档是否符合预定义的模板规范，支持标题、表格、正文等多维度校验，适用于企业文档标准化场景。提供命令行与现代GUI界面，支持详细报告导出和一键打包为独立可执行文件。

## 主要功能
- ✅ 标题内容与格式自动检查
- ✅ 表格内容、允许值、非空等多规则校验
- ✅ 指定标题下正文内容检查
- ✅ 支持自定义JSON配置模板
- ✅ 检查结果导出为HTML报告
- ✅ 现代美观的图形界面
- ✅ 支持打包为Windows独立EXE

## 检查逻辑与顺序

1. **标题检查**
   - 检查文档中是否包含所有必填标题
   - 验证标题的样式和格式
   - 检查标题的层级结构

2. **表格检查**
   - 验证表格是否存在
   - 检查表格单元格是否为空
   - 验证特定列的值是否符合允许值列表
   - 检查表格行数是否符合要求

3. **正文内容检查**
   - 检查指定标题下的段落内容是否为空
   - 验证段落格式
   - 检查内容是否符合预定义的格式要求

## 快速开始

### 环境要求
- Python 3.8+
- Poetry (推荐) 或 pip

### 安装依赖
```powershell
# 克隆仓库
cd H3C/check

# 使用Poetry安装依赖（推荐）
poetry install

# 或者使用pip
pip install -r requirements.txt
```

### 运行程序

#### 图形界面模式（默认）
```powershell
# 使用Poetry
poetry run python -m h3c_doc_checker

# 或直接运行
python -m h3c_doc_checker
```

#### 命令行模式
```powershell
# 检查单个文件
python -m h3c_doc_checker check -f 文档.docx

# 指定配置文件
python -m h3c_doc_checker check -f 文档.docx -c config/custom_config.json

# 生成报告
python -m h3c_doc_checker check -f 文档.docx -o report.html
```

## 配置说明

配置文件位于 `config/default_config.json`，主要包含以下部分：

- `title_rules`: 标题检查规则
- `table_rules`: 表格检查规则
- `content_under_heading_rules`: 正文内容检查规则

## 打包为独立可执行文件

### 使用 PyInstaller 打包
```powershell
# 安装打包工具
pip install pyinstaller

# 打包为单个可执行文件
pyinstaller --onefile -w -n docx_checker h3c_doc_checker/__main__.py

# 生成的文件位于 dist/ 目录下
```

### 使用 build.py 脚本打包（推荐）
```powershell
# 使用项目自带的构建脚本
python build.py
```

## 调试与开发

### 调试模式
```powershell
# 启用调试日志
set H3C_DEBUG=1
python -m h3c_doc_checker
```

### 运行测试
```powershell
# 运行单元测试
pytest tests/

# 生成测试覆盖率报告
pytest --cov=h3c_doc_checker tests/
```

### 代码风格检查
```powershell
# 使用 flake8 检查代码风格
flake8 h3c_doc_checker

# 自动格式化代码
black h3c_doc_checker
isort h3c_doc_checker
```

## 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 发起 Pull Request

## 许可证

MIT

## 目录结构
- h3c_doc_checker/  主程序包（含核心逻辑、GUI、检查器、配置等）
- config/           默认配置文件
- build/            打包产物
- resources/        图标等资源
- src/              代码副本（如有）

详细结构与说明见 [h3c_doc_checker/README.md](h3c_doc_checker/README.md)

## 配置说明
- 配置文件位于 `h3c_doc_checker/config/default_config.json`
- 支持自定义检查规则，详见[详细配置说明](h3c_doc_checker/README.md)

## 依赖
- Python 3.8+
- python-docx
- 其他依赖见 `pyproject.toml` 或 `requirements.txt`

## 贡献与维护
欢迎提交Issue和PR，详细开发文档与技术方案见 [h3c_doc_checker/README.md](h3c_doc_checker/README.md)

---

> 技术实现与详细方案请参考本目录下原有技术文档。