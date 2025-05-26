"""
工具函数模块
"""
import os
import sys
import locale
from typing import Dict, Optional, Any, Any
from docx import Document
from docx.text.paragraph import Paragraph

class CheckResult:
    """检查结果类"""
    def __init__(self, type: str = "未知检查", passed: bool = False, message: str = "", details: Dict = None):
        self.type = type
        self.passed = passed
        self.message = message
        self.details = details or {}
    
    def to_dict(self) -> Dict[str, Any]:
        """将检查结果转换为字典格式"""
        return {
            "type": self.type,
            "passed": self.passed,
            "message": self.message,
            "details": self.details
        }

def ensure_utf8_environment() -> None:
    """确保系统环境使用UTF-8编码"""
    if sys.platform.startswith('win'):
        # 在Windows上设置UTF-8编码
        if locale.getpreferredencoding().upper() != 'UTF-8':
            # 设置控制台代码页为UTF-8
            import subprocess
            subprocess.run(['chcp', '65001'], shell=True)
            # 设置环境变量
            os.environ['PYTHONIOENCODING'] = 'utf-8'

def get_paragraph_style_name(paragraph: Paragraph) -> str:
    """获取段落的样式名称"""
    return paragraph.style.name if paragraph.style else ""

def count_chinese_chars(text: str) -> int:
    """统计中文字符数"""
    return sum(1 for char in text if '\u4e00' <= char <= '\u9fff')

def load_document(doc_path: str) -> Document:
    """加载Word文档"""
    try:
        if not os.path.exists(doc_path):
            raise FileNotFoundError(f"文档不存在: {doc_path}")
        return Document(doc_path)
    except Exception as e:
        raise Exception(f"无法加载文档 {doc_path}: {str(e)}")

def format_check_results(results: list[CheckResult], indent: int = 0) -> str:
    """格式化检查结果为易读的字符串"""
    output = []
    indent_str = " " * indent
    for result in results:
        status = "✓" if result.passed else "✗"
        output.append(f"{indent_str}{status} {result.message}")
        if result.details:
            for key, value in result.details.items():
                output.append(f"{indent_str}  - {key}: {value}")
    return "\n".join(output)
