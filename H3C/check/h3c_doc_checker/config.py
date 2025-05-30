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
        try:
            # 加载指定的配置文件
            if not self.config_path.exists():
                raise FileNotFoundError(f"配置文件不存在: {self.config_path}")

            with open(self.config_path, 'r', encoding='utf-8') as f:
                config_data = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"配置文件格式错误: {e}")
        except Exception as e:
            raise ValueError(f"加载配置文件失败: {str(e)}")

        # 兼容旧版配置键名
        if 'content_under_heading_rules' in config_data and 'content_rules' not in config_data:
            config_data['content_rules'] = config_data['content_under_heading_rules']

        return config_data

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
        # 兼容 content_under_heading_rules 键名
        elif "content_under_heading_rules" in self.config_data:
            self._validate_content_rules(self.config_data["content_under_heading_rules"])
        if "font_rules" in self.config_data:
            self._validate_font_rules(self.config_data["font_rules"])

    def _validate_title_rules(self, rules: Dict[str, Any]) -> None:
        """校验标题规则配置"""
        if not isinstance(rules, dict):
            raise ValueError("title_rules 必须是一个对象")

        # 检查expected_titles是否存在且为数组
        if "expected_titles" not in rules:
            raise ValueError("title_rules 必须包含 expected_titles 字段")
        if not isinstance(rules["expected_titles"], list):
            raise ValueError("expected_titles 必须是一个数组")

        # 检查每个标题规则
        for i, title_rule in enumerate(rules["expected_titles"]):
            if not isinstance(title_rule, dict):
                raise ValueError(f"标题规则 #{i+1} 必须是一个对象")
            if "text" not in title_rule:
                raise ValueError(f"标题规则 #{i+1} 必须包含 text 字段")
            # style_name 和 required 是可选的
    def _validate_table_rules(self, rules: List[Dict[str, Any]]) -> None:
        """校验表格规则配置"""
        if not isinstance(rules, list):
            raise ValueError("table_rules 必须是一个数组")

        for rule in rules:
            if not isinstance(rule, dict):
                raise ValueError("每个表格规则必须是一个对象")

            # 检查表格规则必需字段
            required = ["heading_text", "table_index"]
            for field in required:
                if field not in rule:
                    raise ValueError(f"表格规则缺少必需字段: {field}")

            # 检查列值校验配置
            if "column_value_check" in rule:
                column_check = rule["column_value_check"]
                if not isinstance(column_check, dict):
                    raise ValueError("column_value_check 必须是一个对象")

                if "column_header" not in column_check:
                    raise ValueError("column_value_check 必须包含 column_header 字段")

                if "allowed_values" not in column_check:
                    raise ValueError("column_value_check 必须包含 allowed_values 字段")

                if not isinstance(column_check["allowed_values"], list):
                    raise ValueError("allowed_values 必须是一个数组")

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

    def _validate_font_rules(self, rules: Dict[str, Any]) -> None:
        """校验字体规则配置"""
        if not isinstance(rules, dict):
            raise ValueError("font_rules 必须是一个对象")

        # 检查标题字体规则
        if "heading_font_rules" in rules:
            heading_rules = rules["heading_font_rules"]
            if not isinstance(heading_rules, dict):
                raise ValueError("heading_font_rules 必须是一个对象")
            
            for style_name, rule in heading_rules.items():
                if not isinstance(rule, dict):
                    raise ValueError(f"标题样式 '{style_name}' 的字体规则必须是一个对象")
                # font_name 和 font_size 是可选的，但如果存在必须是字符串或数字

        # 检查正文字体规则
        if "content_font_rules" in rules:
            content_rules = rules["content_font_rules"]
            if not isinstance(content_rules, dict):
                raise ValueError("content_font_rules 必须是一个对象")
            # chinese_font 和 english_font 是可选的

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

    @property
    def font_rules(self) -> Optional[Dict[str, Any]]:
        """获取字体规则配置"""
        return self.config_data.get("font_rules")
