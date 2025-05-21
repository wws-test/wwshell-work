# H3C Word文档规范自动检查工具

## 项目简介
本项目旨在自动化检查Word文档是否符合预定义的模板规范，支持标题、表格、正文等多维度校验，适用于企业文档标准化场景。提供命令行与现代GUI界面，支持详细报告导出和一键打包为独立可执行文件。

## 主要功能
- 标题内容与格式自动检查
- 表格内容、允许值、非空等多规则校验
- 指定标题下正文内容检查
- 支持自定义JSON配置模板
- 检查结果导出为HTML报告
- 现代美观的图形界面
- 支持打包为Windows独立EXE

## 快速开始
1. 安装依赖（推荐Poetry）
   ```powershell
   cd H3C/check
   poetry install
   ```
2. 运行（开发环境）
   ```powershell
   poetry run python -m h3c_doc_checker
   # 或
   python -m h3c_doc_checker
   ```
3. 打包为独立EXE（可选）
   ```powershell
   pyinstaller --onefile -w -n docx_checker h3c_doc_checker/__main__.py
   # 生成的可执行文件在dist/目录下
   ```

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