# h3c_doc_checker/main.py
import sys
import argparse
from pathlib import Path
from typing import List
import logging
import tkinter as tk

from h3c_doc_checker.config import Config
from h3c_doc_checker.utils import CheckResult, load_document, format_check_results, ensure_utf8_environment
from h3c_doc_checker.checkers import TitleChecker, TableChecker, ContentChecker

# 确保使用UTF-8编码
ensure_utf8_environment()

def test_gui_environment() -> bool:
    """测试GUI环境是否正常"""
    try:
        logging.info("测试GUI环境...")
        root = tk.Tk()
        root.withdraw()
        # 尝试创建一个测试窗口
        test = tk.Toplevel(root)
        test.title("GUI测试")
        test.geometry("1x1")  # 最小化窗口大小
        test.update()
        test.destroy()
        root.destroy()
        logging.info("GUI环境测试通过")
        return True
    except Exception as e:
        logging.error(f"GUI环境测试失败: {str(e)}")
        return False

def launch_gui():
    """启动GUI界面"""
    logging.info("准备启动GUI...")
    
    try:
        # 测试GUI环境
        if not test_gui_environment():
            raise Exception("GUI环境异常")
            
        # 导入GUI模块
        logging.info("导入GUI模块...")
        from h3c_doc_checker.gui import DocumentCheckerGUI
        
        # 创建主窗口
        logging.info("正在创建主窗口...")
        root = tk.Tk()
        app = DocumentCheckerGUI(root)
        logging.info("GUI启动成功")
        return root.mainloop()
        
    except ImportError as e:
        logging.error(f"无法导入GUI模块: {str(e)}")
        raise
    except Exception as e:
        logging.error(f"GUI启动失败: {str(e)}")
        raise

def check_single_document(doc_path: str, config_path: str = None) -> List[CheckResult]:
    """
    检查单个文档
    
    Args:
        doc_path: 文档路径
        config_path: 配置文件路径
        
    Returns:
        检查结果列表
    """
    try:        # 加载配置
        logging.info("开始加载配置文件")
        if not config_path:
            logging.debug("使用默认配置文件")
            effective_config_path = "default_config.json"
        else:
            effective_config_path = Path(config_path)
            
        logging.info(f"加载配置完成: {effective_config_path}")
        config = Config(effective_config_path)
        config.validate()
        
        # 加载文档
        logging.info(f"加载文档: {doc_path}")
        doc = load_document(doc_path)
        
        # 执行检查
        results = []
        
        # 标题检查
        if config.title_rules:
            logging.info("执行标题检查...")
            title_checker = TitleChecker(doc, config.title_rules)
            title_result = title_checker.check_title()
            results.append(title_result)
            logging.info(f"标题检查结果: {title_result.passed}")
        
        # 表格检查
        if config.table_rules:
            logging.info("执行表格检查...")
            table_checker = TableChecker(doc, config.table_rules)
            table_results = table_checker.check_tables()
            results.extend(table_results)
            logging.info(f"表格检查完成，共 {len(table_results)} 个检查项")
            
        # 内容检查
        if config.content_rules:
            logging.info("执行内容检查...")
            content_checker = ContentChecker(doc, config.content_rules)
            content_results = content_checker.check_contents()
            results.extend(content_results)
            logging.info(f"内容检查完成，共 {len(content_results)} 个检查项")
            
        return results
        
    except Exception as e:
        logging.error(f"文档检查出错: {str(e)}", exc_info=True)
        raise

def print_results(results: List[CheckResult]) -> None:
    """打印检查结果"""
    if not results:
        print("没有检查结果")
        return
        
    print("\n=== 检查结果 ===\n")
    for i, result in enumerate(results, 1):
        status = "✓" if result.passed else "✗"
        print(f"{i}. [{status}] {result.message}")
        if result.details:
            print(f"   详情: {result.details}")
    print("\n=== 检查完成 ===\n")
    
    # 打印摘要
    total = len(results)
    passed = sum(1 for r in results if r.passed)
    failed = total - passed
    print(f"总计: {total} 项, 通过: {passed} 项, 失败: {failed} 项")
    
    if failed > 0:
        sys.exit(1)
    sys.exit(0)

def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description="H3C文档规范检查工具")
    subparsers = parser.add_subparsers(dest="command", help="命令")
    
    # GUI模式
    gui_parser = subparsers.add_parser("gui", help="启动图形界面")
    
    # 检查单个文件
    check_parser = subparsers.add_parser("check", help="检查单个文档")
    check_parser.add_argument(
        "-f", "--file",
        required=True,
        help="要检查的Word文档路径"
    )
    check_parser.add_argument(
        "-c", "--config",
        help="配置文件路径（可选）"
    )
    
    # 批量检查
    batch_parser = subparsers.add_parser("batch", help="批量检查多个文档")
    batch_parser.add_argument(
        "-d", "--directory",
        help="包含要检查文档的目录"
    )
    batch_parser.add_argument(
        "-c", "--config",
        help="配置文件路径（可选）"
    )
    
    return parser.parse_args()

def main():
    """主函数"""
    # 配置日志
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler("h3c_checker.log", encoding="utf-8")
        ]
    )
    
    try:
        args = parse_arguments()
        
        if args.command == "gui":
            launch_gui()
        elif args.command == "check":
            results = check_single_document(args.file, args.config)
            print_results(results)
        elif args.command == "batch":
            from h3c_doc_checker.batch_processor import BatchProcessor
            processor = BatchProcessor(args.config)
            # 这里可以添加批量处理逻辑
            print("批量处理功能正在开发中...")
        else:
            # 如果没有指定命令，默认启动GUI
            launch_gui()
            
    except Exception as e:
        logging.error(f"程序出错: {str(e)}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()