# h3c_doc_checker/batch_processor.py
import json
from pathlib import Path
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor
from .config import Config
from .checkers import TitleChecker, TableChecker, ContentChecker, FontChecker
from .utils import CheckResult, load_document

class BatchProcessor:
    def __init__(self, config_path: str):
        self.config = Config(config_path)
        self.config.validate()
        
    def process_document(self, doc_path: str) -> Dict[str, Any]:
        """处理单个文档并返回结果"""
        try:
            doc = load_document(doc_path)
            results = []
            
            # 初始化检查器
            checkers = []
            if self.config.title_rules:
                checkers.append(TitleChecker(doc, self.config.title_rules))
            if hasattr(self.config, 'font_rules') and self.config.font_rules:
                checkers.append(FontChecker(doc, self.config.font_rules))
            if self.config.table_rules:
                checkers.append(TableChecker(doc, self.config.table_rules))
            if self.config.content_rules:
                checkers.append(ContentChecker(doc, self.config.content_rules))
            
            # 执行检查
            for checker in checkers:
                if isinstance(checker, TitleChecker):
                    results.append(checker.check_title())
                elif isinstance(checker, FontChecker):
                    results.extend(checker.check_fonts())
                elif isinstance(checker, TableChecker):
                    results.extend(checker.check_tables())
                elif isinstance(checker, ContentChecker):
                    results.extend(checker.check_contents())
            
            return {
                "file": str(doc_path),
                "passed": all(r.passed for r in results),
                "results": [r.to_dict() for r in results]
            }
            
        except Exception as e:
            return {
                "file": str(doc_path),
                "error": str(e),
                "passed": False
            }
    
    def process_batch(self, doc_paths: List[str], max_workers: int = 4) -> Dict[str, Any]:
        """批量处理多个文档"""
        results = {
            "total": len(doc_paths),
            "passed": 0,
            "failed": 0,
            "documents": []
        }
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            for result in executor.map(self.process_document, doc_paths):
                if result.get("passed", False):
                    results["passed"] += 1
                else:
                    results["failed"] += 1
                results["documents"].append(result)
                
        return results