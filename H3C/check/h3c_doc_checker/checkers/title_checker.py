"""标题检查模块"""
from typing import Dict, Any, List, Optional
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
            rules: 标题检查规则，格式如下：
                  {
                      "expected_titles": [
                          {
                              "text": "标题文本",
                              "style_name": "标题样式",
                              "required": true/false
                          },
                          ...
                      ]
                  }
        """
        self.doc = doc
        self.rules = rules
        
    def check_title(self) -> CheckResult:
        """
        检查文档标题
        
        Returns:
            CheckResult: 检查结果对象，包含是否通过检查及相关信息
        """
        # 获取所有段落及其文本
        if not self.doc.paragraphs:
            return CheckResult(
                type="标题检查",
                passed=False,
                message="文档为空，未找到任何标题",
                details={"location": "整个文档"}
            )
            
        # 获取期望的标题列表
        expected_titles = self.rules.get("expected_titles", [])
        if not expected_titles:
            return CheckResult(
                type="标题检查",
                passed=False,
                message="配置文件中未定义标题规则",
                details={"location": "配置文件"}
            )
            
        # 遍历所有段落查找标题
        found_titles = {}  # 记录找到的标题
        for para in self.doc.paragraphs:
            text = para.text.strip()
            style = get_paragraph_style_name(para)
            
            # 检查这个段落是否匹配任何期望的标题
            for title_rule in expected_titles:
                expected_text = title_rule.get("text", "").strip()
                expected_style = title_rule.get("style_name")
                
                # 如果文本和样式都匹配，记录这个标题已找到
                if text == expected_text and (not expected_style or style == expected_style):
                    found_titles[expected_text] = True
                    break
        
        # 检查所有必需的标题是否都找到了
        missing_titles = []
        for title_rule in expected_titles:
            if title_rule.get("required", False):
                expected_text = title_rule.get("text", "").strip()
                if expected_text not in found_titles:
                    missing_titles.append(expected_text)
        
        # 返回检查结果
        if missing_titles:
            return CheckResult(
                type="标题检查",
                passed=False,
                message=f"缺少必需的标题:\n{chr(10).join(f'- {title}' for title in missing_titles)}",
                details={
                    "location": "整个文档",
                    "missing_titles": missing_titles
                }
            )
        
        return CheckResult(
            type="标题检查",
            passed=True,
            message="所有必需的标题检查通过",
            details={"location": "整个文档"}
        )
