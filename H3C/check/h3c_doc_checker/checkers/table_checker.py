from typing import Dict, List, Optional, Tuple, Any
from docx.document import Document
from docx.table import Table, _Cell
from h3c_doc_checker.utils import CheckResult

class TableChecker:
    """表格检查器类"""
    
    def __init__(self, doc: Document, rules: List[Dict[str, Any]]):
        """
        初始化表格检查器
        
        Args:
            doc: Word文档对象
            rules: 表格检查规则列表，每个规则是一个包含以下可选字段的字典：
                  - expected_columns: 期望的列数
                  - expected_header: 期望的表头文本列表
                  - style_name: 期望的表格样式名称
        """
        self.doc = doc
        self.rules = rules
        
    def check_tables(self) -> List[CheckResult]:
        """
        检查文档中的所有表格
        
        Returns:
            List[CheckResult]: 检查结果列表
        """
        if not self.doc.tables:
            return [CheckResult(
                passed=False,
                message="文档中未找到任何表格",
                location="整个文档"
            )]
            
        results = []
        for i, table in enumerate(self.doc.tables):
            # 获取适用的规则
            rule = self.rules[i] if i < len(self.rules) else None
            if not rule:
                continue
                
            # 检查列数
            if "expected_columns" in rule:
                expected = rule["expected_columns"]
                actual = len(table.columns)
                if expected != actual:
                    results.append(CheckResult(
                        passed=False,
                        message=f"表格列数不匹配\n期望: {expected}\n实际: {actual}",
                        location=f"第{i+1}个表格"
                    ))
                    continue
                    
            # 检查表头
            if "expected_header" in rule:
                expected = rule["expected_header"]
                actual = [cell.text.strip() for cell in table.rows[0].cells]
                if expected != actual:
                    results.append(CheckResult(
                        passed=False,
                        message=f"表头不匹配\n期望: {expected}\n实际: {actual}",
                        location=f"第{i+1}个表格的表头"
                    ))
                    continue
                    
            # 检查样式
            if "style_name" in rule:
                expected = rule["style_name"]
                actual = table.style.name if table.style else "默认样式"
                if expected != actual:
                    results.append(CheckResult(
                        passed=False,
                        message=f"表格样式不匹配\n期望: {expected}\n实际: {actual}",
                        location=f"第{i+1}个表格"
                    ))
                    continue
            
            # 如果通过了所有检查
            results.append(CheckResult(
                passed=True,
                message=f"表格检查通过",
                location=f"第{i+1}个表格"
            ))
            
        return results
