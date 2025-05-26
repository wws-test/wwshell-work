# h3c_doc_checker/batch_processor.py
import json
from pathlib import Path
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor
from .config import Config
from .checkers import TitleChecker, TableChecker, ContentChecker
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
            
            # 执行所有检查
            if self.config.title_rules:
                checker = TitleChecker(doc, self.config.title_rules)
                results.append(checker.check_title())
                
            if self.config.table_rules:
                checker = TableChecker(doc, self.config.table_rules)
                results.extend(checker.check_tables())
                
            if self.config.content_rules:
                checker = ContentChecker(doc, self.config.content_rules)
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