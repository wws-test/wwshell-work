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
            rules: 内容检查规则列表，每个规则是一个包含以下可选字段的字典：
                  - pattern: 要匹配的文本模式（字符串或正则表达式）
                  - style_name: 期望的段落样式名称
                  - forbidden_words: 禁止使用的词语列表
                  - required_words: 必须包含的词语列表
                  - min_length: 段落最小长度
                  - max_length: 段落最大长度
        """
        self.doc = doc
        self.rules = rules
        
    def check_contents(self) -> List[CheckResult]:
        """
        检查文档中的内容
        
        Returns:
            List[CheckResult]: 检查结果列表
        """
        if not self.doc.paragraphs:
            return [CheckResult(
                passed=False,
                message="文档中未找到任何内容",
                location="整个文档"
            )]
            
        results = []
        for i, rule in enumerate(self.rules):
            # 跳过第一个段落（标题）
            for j, para in enumerate(self.doc.paragraphs[1:], 1):
                text = para.text.strip()
                location = f"第{j}段"
                
                # 检查段落样式
                if "style_name" in rule:
                    expected = rule["style_name"]
                    actual = get_paragraph_style_name(para)
                    if expected != actual:
                        results.append(CheckResult(
                            passed=False,
                            message=f"段落样式不匹配\n期望: {expected}\n实际: {actual}",
                            location=location
                        ))
                        continue
                
                # 检查文本模式
                if "pattern" in rule:
                    import re
                    pattern = rule["pattern"]
                    if not re.search(pattern, text):
                        results.append(CheckResult(
                            passed=False,
                            message=f"段落文本不符合指定模式: {pattern}",
                            location=location
                        ))
                        continue
                
                # 检查禁用词
                if "forbidden_words" in rule:
                    forbidden = rule["forbidden_words"]
                    found = [word for word in forbidden if word in text]
                    if found:
                        results.append(CheckResult(
                            passed=False,
                            message=f"段落包含禁用词: {', '.join(found)}",
                            location=location
                        ))
                        continue
                
                # 检查必需词
                if "required_words" in rule:
                    required = rule["required_words"]
                    missing = [word for word in required if word not in text]
                    if missing:
                        results.append(CheckResult(
                            passed=False,
                            message=f"段落缺少必需词: {', '.join(missing)}",
                            location=location
                        ))
                        continue
                
                # 检查长度限制
                if "min_length" in rule and len(text) < rule["min_length"]:
                    results.append(CheckResult(
                        passed=False,
                        message=f"段落长度过短\n期望最小长度: {rule['min_length']}\n实际长度: {len(text)}",
                        location=location
                    ))
                    continue
                    
                if "max_length" in rule and len(text) > rule["max_length"]:
                    results.append(CheckResult(
                        passed=False,
                        message=f"段落长度过长\n期望最大长度: {rule['max_length']}\n实际长度: {len(text)}",
                        location=location
                    ))
                    continue
                
                # 如果通过了所有检查
                results.append(CheckResult(
                    passed=True,
                    message=f"内容检查通过",
                    location=location
                ))
                
        return results
