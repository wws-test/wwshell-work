import sys
import docx
from typing import Dict, List, Any, Iterator, Union
from docx.document import Document
from docx.table import Table, _Cell
from docx.text.paragraph import Paragraph
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from h3c_doc_checker.utils import CheckResult

def iter_block_items(parent):
    """
    生成一个文档的块级项目序列（段落和表格）
    """
    if parent.element.body is None:
        return

    for child in parent.element.body:
        if isinstance(child, CT_P):
            yield Paragraph(child, parent)
        elif isinstance(child, CT_Tbl):
            yield Table(child, parent)

class TableChecker:
    """表格检查器类"""
    def __init__(self, doc: Document, rules: List[Dict[str, Any]]):
        """
        初始化表格检查器
        
        Args:
            doc: Word文档对象
            rules: 表格检查规则列表，每个规则是一个包含以下字段的字典：
                  - heading_text: 表格所在标题的文本
                  - table_index: 该标题下第几个表格(从0开始)
                  - all_cells_not_empty: 是否检查所有单元格非空
        """
        self.doc = doc
        self.rules = rules    
    def find_tables_under_heading(self, heading_text: str) -> List[Table]:
        """
        查找指定标题下的所有表格
        """
        tables = []
        heading_found = False
        
        # 使用全局的 iter_block_items 函数
        for block in iter_block_items(self.doc):
            if isinstance(block, Paragraph):
                # 如果还没找到标题，检查当前段落
                if not heading_found:
                    if block.text.strip() == heading_text:
                        heading_found = True
                        continue
                # 如果已经找到标题，检查是否到达下一个标题
                elif block.style and block.style.name.startswith(("Heading", "标题")):
                    break
            # 如果是表格并且已经找到标题，则添加到结果中
            elif heading_found and isinstance(block, Table):
                tables.append(block)
        
        return tables
        
    def check_tables(self) -> List[CheckResult]:
        """检查文档中的表格"""
        if not self.rules:
            return [CheckResult(
                type="表格检查",
                passed=True,
                message="没有表格检查规则",
                details={"location": "配置文件"}
            )]
            
        results = []
        for rule in self.rules:
            heading_text = rule.get("heading_text", "").strip()

            # 确保规则中指定了 heading_text
            if not heading_text:
                results.append(CheckResult(
                    type="表格检查",
                    passed=False,
                    message="规则中 'heading_text' 未指定或为空。",
                    details={"rule_details": rule} # 提供规则详情以便调试
                ))
                continue

            table_index = rule.get("table_index", 0)
            
            # 查找标题下的表格
            tables = self.find_tables_under_heading(heading_text)
            
            # 检查是否找到表格
            if not tables:
                results.append(CheckResult(
                    type="表格检查",
                    passed=False,
                    message=f"在标题 '{heading_text}' 下未找到任何表格",
                    details={"location": heading_text}
                ))
                continue # 处理下一条规则
                
            # 检查表格索引是否越界
            if table_index >= len(tables):
                results.append(CheckResult(
                    type="表格检查",
                    passed=False,
                    message=f"标题 '{heading_text}' 下只有 {len(tables)} 个表格，无法检查第 {table_index + 1} 个表格",
                    details={"location": f"{heading_text}#表格{table_index + 1}"}
                ))
                continue # 处理下一条规则
                
            table = tables[table_index]
            current_location_detail = f"{heading_text}#表格{table_index + 1}"
            
            # 标志，用于跟踪此特定表格规则的所有检查是否都通过
            all_checks_for_this_table_passed = True            # 检查单元格是否为空
            if rule.get("all_cells_not_empty", False):
                empty_cells = []
                # 获取允许为空的列
                allow_empty_columns = rule.get("column_value_check", {}).get("allow_empty_columns", [])
                # 获取表头行，用于查找允许为空的列的索引
                header_row = table.rows[0]
                allow_empty_indices = []
                for i, cell in enumerate(header_row.cells):
                    if cell.text.strip() in allow_empty_columns:
                        allow_empty_indices.append(i)
                
                # 检查非空
                for r_idx, row in enumerate(table.rows):
                    for c_idx, cell in enumerate(row.cells):
                        # 如果当前列允许为空，则跳过检查
                        if c_idx in allow_empty_indices:
                            continue
                        if not cell.text.strip():
                            empty_cells.append((r_idx + 1, c_idx + 1)) # 行号和列号从1开始
                if empty_cells:
                    all_checks_for_this_table_passed = False # 标记此检查失败
                    results.append(CheckResult(
                        type="表格检查",
                        passed=False,
                        message=f"标题 '{heading_text}' 下表格 (第 {table_index + 1} 个) 包含空单元格:\n" + 
                                "\n".join(f"- 第{row}行第{col}列" for row, col in empty_cells),
                        details={
                            "location": current_location_detail,
                            "empty_cells": empty_cells
                        }
                    ))

            # 检查列值是否在允许的范围内
            if "column_value_check" in rule:
                column_check = rule["column_value_check"]
                header = column_check["column_header"]
                allowed_values = column_check["allowed_values"]
                
                # 找到指定列的索引
                header_row = table.rows[0]
                column_index = None
                for i, cell in enumerate(header_row.cells):
                    if cell.text.strip() == header:
                        column_index = i
                        break
                
                if column_index is None:
                    all_checks_for_this_table_passed = False
                    results.append(CheckResult(
                        type="表格检查",
                        passed=False,
                        message=f"标题 '{heading_text}' 下表格未找到列 '{header}'",
                        details={"location": current_location_detail}
                    ))
                    continue
                
                # 检查该列中的所有值
                invalid_values = []
                for row_idx, row in enumerate(table.rows[1:], 1):  # 跳过表头行
                    value = row.cells[column_index].text.strip()
                    if value and value not in allowed_values:
                        invalid_values.append((row_idx + 1, value))  # +1 因为跳过了表头行
                        if invalid_values:
                            all_checks_for_this_table_passed = False
                            results.append(CheckResult(
                        type="表格检查",
                        passed=False,
                        message=f"标题 '{heading_text}' 下表格中'{header}'列包含非法值:\n" + 
                                "\n".join(f"- 第{row}行: {value}" for row, value in invalid_values),
                        details={
                            "location": current_location_detail,
                            "invalid_values": invalid_values
                        }
                    ))
            
            # 未来可以在此添加针对同一表格和规则的其他检查
            # 例如: if rule.get("check_column_count"): ... ; if failed, set all_checks_for_this_table_passed = False

            # 如果此规则的所有检查都通过了
            if all_checks_for_this_table_passed:
                results.append(CheckResult(
                    type="表格检查",
                    passed=True,
                    message=f"标题 '{heading_text}' 下的表格 (第 {table_index + 1} 个) 检查通过",
                    details={"location": current_location_detail}
                ))
            
        return results