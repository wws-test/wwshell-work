"""正文内容检查模块"""
from typing import Dict, List, Optional, Tuple, Any
from docx.document import Document
from docx.text.paragraph import Paragraph
from h3c_doc_checker.utils import CheckResult, get_paragraph_style_name

class ContentChecker:
    """内容检查器类"""
    
    def __init__(self, doc: Document, rules: List[Dict[str, Any]]):
        """
        初始化内容检查器
        
        Args:
            doc: Word文档对象
            rules: 内容检查规则列表
        """
        self.doc = doc
        self.rules = rules
        
    def get_paragraphs_after_heading(self, heading_text: str, exact_match: bool = True, count: int = 1) -> List[Paragraph]:
        """获取标题后的指定数量段落"""
        paragraphs = []
        heading_found = False
        collected = 0
        
        for para in self.doc.paragraphs:
            text = para.text.strip()
            
            if not heading_found:
                # 查找标题
                if (exact_match and text == heading_text) or (not exact_match and heading_text in text):
                    heading_found = True
                    # 找到标题后立即检查下一段落
                    continue
                continue
            
            # 跳过空行
            if not text and not para.runs:
                continue
                
            # 如果遇到同级别或更高级别的标题，停止收集
            if para.style and para.style.name and para.style.name.startswith(("Heading", "标题")):
                # 获取当前标题级别
                current_heading_level = 0
                if para.style.name.startswith("Heading ") and len(para.style.name) > 8:
                    try:
                        current_heading_level = int(para.style.name[8:])
                    except (ValueError, IndexError):
                        pass
                
                # 如果找到同级别或更高级别的标题，停止收集
                if current_heading_level > 0 and current_heading_level <= 4:  # 假设4是当前标题的级别
                    break
            
            # 收集段落
            if collected < count:
                paragraphs.append(para)
                collected += 1
            else:
                break
                
        return paragraphs
        
    def check_contents(self) -> List[CheckResult]:
        """检查文档内容"""
        if not self.rules:
            return [CheckResult(
                type="内容检查",
                passed=True,
                message="没有正文检查规则",
                details={"location": "配置文件"}
            )]
            
        results = []
        for rule in self.rules:
            heading_text = rule.get("heading_text_exact", "").strip()
            check_count = rule.get("check_next_paragraphs", 1)
            
            # 获取并检查段落
            paragraphs = self.get_paragraphs_after_heading(heading_text, True, check_count)
            
            if not paragraphs:
                results.append(CheckResult(
                    type="内容检查",
                    passed=False,
                    message=f"标题 '{heading_text}' 后未找到任何段落",
                    details={"location": heading_text}
                ))
                continue
                
            # 检查是否为空
            empty_paragraphs = []
            for i, para in enumerate(paragraphs, 1):
                if rule.get("not_empty", True) and not para.text.strip():
                    empty_paragraphs.append(i)
            
            if empty_paragraphs:
                results.append(CheckResult(
                    type="内容检查",
                    passed=False,
                    message=f"标题 '{heading_text}' 后的第 {', '.join(map(str, empty_paragraphs))} 个段落为空",
                    details={
                        "location": heading_text,
                        "empty_paragraphs": empty_paragraphs
                    }
                ))
            else:
                results.append(CheckResult(
                    type="内容检查",
                    passed=True,
                    message=f"标题 '{heading_text}' 下的正文检查通过",
                    details={"location": heading_text}
                ))
                
        return results
