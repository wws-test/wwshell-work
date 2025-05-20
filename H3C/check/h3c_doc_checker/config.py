"""
配置管理模块
"""
import json
from pathlib import Path
from typing import Dict, Any, Optional, List

class Config:
    """文档检查配置类"""
    def __init__(self, config_path: str | Path):
        self.config_path = Path(config_path)
        self.config_data = self._load_config()
        
    def _load_config(self) -> Dict[str, Any]:
        """加载配置文件"""
        if not self.config_path.exists():
            raise FileNotFoundError(f"配置文件不存在: {self.config_path}")
        
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"配置文件格式错误: {e}")
            
    def validate(self) -> None:
        """校验配置有效性"""
        if not isinstance(self.config_data, dict):
            raise ValueError("配置必须是一个JSON对象")
            
        # 检查必需字段
        required = ["document_to_check"]
        for field in required:
            if field not in self.config_data:
                raise ValueError(f"缺少必需的配置项: {field}")
                
        # 校验具体规则配置
        if "title_rules" in self.config_data:
            self._validate_title_rules(self.config_data["title_rules"])
        if "table_rules" in self.config_data:
            self._validate_table_rules(self.config_data["table_rules"])
        if "content_rules" in self.config_data:
            self._validate_content_rules(self.config_data["content_rules"])
    
    def _validate_title_rules(self, rules: Dict[str, Any]) -> None:
        """校验标题规则配置"""
        if not isinstance(rules, dict):
            raise ValueError("title_rules 必须是一个对象")
            
        # 检查标题规则必需字段
        if not any(key in rules for key in ["expected_text", "style_name"]):
            raise ValueError("title_rules 必须至少包含 expected_text 或 style_name 之一")
            
    def _validate_table_rules(self, rules: List[Dict[str, Any]]) -> None:
        """校验表格规则配置"""
        if not isinstance(rules, list):
            raise ValueError("table_rules 必须是一个数组")
            
        for rule in rules:
            if not isinstance(rule, dict):
                raise ValueError("每个表格规则必须是一个对象")
                
            # 检查表格规则必需字段
            required = ["table_index"]
            for field in required:
                if field not in rule:
                    raise ValueError(f"表格规则缺少必需字段: {field}")
                    
    def _validate_content_rules(self, rules: List[Dict[str, Any]]) -> None:
        """校验正文规则配置"""
        if not isinstance(rules, list):
            raise ValueError("content_rules 必须是一个数组")
            
        for rule in rules:
            if not isinstance(rule, dict):
                raise ValueError("每个正文规则必须是一个对象")
                
            # 检查标题定位方式
            if not any(key in rule for key in ["heading_text_contains", "heading_text_exact"]):
                raise ValueError("正文规则必须指定 heading_text_contains 或 heading_text_exact")
    
    @property
    def document_path(self) -> str:
        """获取要检查的文档路径"""
        return self.config_data.get("document_to_check", "")
        
    @property
    def title_rules(self) -> Optional[Dict[str, Any]]:
        """获取标题规则配置"""
        return self.config_data.get("title_rules")
        
    @property
    def table_rules(self) -> List[Dict[str, Any]]:
        """获取表格规则配置"""
        return self.config_data.get("table_rules", [])
        
    @property
    def content_rules(self) -> List[Dict[str, Any]]:
        """获取正文规则配置"""
        return self.config_data.get("content_rules", [])
