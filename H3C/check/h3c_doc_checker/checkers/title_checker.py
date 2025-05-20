"""标题检查模块"""
from typing import Dict, Any, Optional
from docx.document import Document
from docx.text.paragraph import Paragraph
from h3c_doc_checker.utils import CheckResult, get_paragraph_style_name, count_chinese_chars

class TitleChecker:
    """标题检查器类"""
    
    def __init__(self, doc: Document, rules: Dict[str, Any]):
        """
        初始化标题检查器
        
        Args:
            doc: Word文档对象
            rules: 标题检查规则，包含以下可选字段：
                  - expected_text: 期望的标题文本
                  - style_name: 期望的标题样式名称
        """
        self.doc = doc
        self.rules = rules
        
    def check_title(self) -> CheckResult:
        """
        检查文档标题
        
        Returns:
            CheckResult: 检查结果对象，包含是否通过检查及相关信息
        """
        # 获取文档第一个段落作为标题
        if not self.doc.paragraphs:
            return CheckResult(
                passed=False,
                message="文档为空，未找到标题",
                location="文档开头"
            )
            
        title_para: Paragraph = self.doc.paragraphs[0]
        
        # 检查标题文本
        if "expected_text" in self.rules:
            expected = self.rules["expected_text"]
            actual = title_para.text.strip()
            if expected != actual:
                return CheckResult(
                    passed=False,
                    message=f"标题文本不匹配\n期望: {expected}\n实际: {actual}",
                    location="标题行"
                )
                
        # 检查标题样式
        if "style_name" in self.rules:
            expected = self.rules["style_name"]
            actual = get_paragraph_style_name(title_para)
            if expected != actual:
                return CheckResult(
                    passed=False,
                    message=f"标题样式不匹配\n期望: {expected}\n实际: {actual}",
                    location="标题行"
                )
                
        return CheckResult(
            passed=True,
            message="标题检查通过",
            location="标题行"
        )
