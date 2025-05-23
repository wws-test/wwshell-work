import sys
import argparse
from pathlib import Path
from typing import List
import importlib.resources
import logging
import tkinter as tk

from h3c_doc_checker.config import Config
from h3c_doc_checker.utils import CheckResult, load_document, format_check_results, ensure_utf8_environment
from h3c_doc_checker.checkers import TitleChecker, TableChecker, ContentChecker

# 确保使用UTF-8编码
ensure_utf8_environment()

def test_gui_environment():
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
        from h3c_doc_checker.splash import main as splash_main
        
        # 启动splash screen和主程序
        logging.info("正在启动splash screen...")
        splash_main()
        logging.info("GUI启动成功")
        
    except ImportError as e:
        logging.error(f"无法导入GUI模块: {str(e)}")
        raise
    except Exception as e:
        logging.error(f"GUI启动失败: {str(e)}")
        raise

def main(config_path_str: str = None):
    try:
        # 使用外部 config 目录下的默认配置
        logging.info("开始加载配置文件")
        if not config_path_str:
            logging.debug("使用默认配置文件")
            effective_config_path = Path("config") / "default_config.json"  # 使用相对路径，触发默认配置加载
            logging.info(f"默认配置文件路径: {effective_config_path}")
        else:
            logging.debug(f"使用指定配置文件: {config_path_str}")
            effective_config_path = Path(config_path_str)
        logging.info(f"加载配置完成: {effective_config_path}")
        current_config = Config(effective_config_path)
        current_config.validate()
        logging.info(f"配置校验通过，文档路径: {current_config.document_path}")
        doc = load_document(current_config.document_path)
        logging.info("Word文档加载成功")
        results = []
        if current_config.title_rules:
            logging.info("开始标题检查...")
            checker = TitleChecker(doc, current_config.title_rules)
            res = checker.check_title()
            logging.info(f"标题检查结果: {res.__dict__}")
            results.append(res)
        if current_config.table_rules:
            logging.info("开始表格检查...")
            checker = TableChecker(doc, current_config.table_rules)
            table_results = checker.check_tables()
            for r in table_results:
                logging.info(f"表格检查结果: {r.__dict__}")
            results.extend(table_results)
        if current_config.content_rules:
            logging.info("开始正文检查...")
            checker = ContentChecker(doc, current_config.content_rules)
            content_results = checker.check_contents()
            for r in content_results:
                logging.info(f"正文检查结果: {r.__dict__}")
            results.extend(content_results)
        print_results(results)
        sys.exit(0 if all(r.passed for r in results) else 1)
    except Exception as e:
        print(f"错误: {str(e)}", file=sys.stderr)
        sys.exit(2)

def print_results(results: List[CheckResult]):
    print("\n=== 文档检查报告 ===\n")
    total_checks = len(results)
    passed_checks = sum(1 for r in results if r.passed)
    print(format_check_results(results))
    print(f"\n总结:")
    print(f"- 总检查项: {total_checks}")
    print(f"- 通过项数: {passed_checks}")
    print(f"- 失败项数: {total_checks - passed_checks}")
    print(f"\n整体状态: {'通过' if passed_checks == total_checks else '失败'}")

def run_check(doc_path_str: str, config_path_str: str = None) -> List[CheckResult]:
    if not config_path_str:
        # 使用外部 config 目录下的默认配置
        effective_config_path = Path("config") / "default_config.json"  # 使用相对路径，触发默认配置加载
    else:
        effective_config_path = Path(config_path_str)
    current_config = Config(effective_config_path)
    if hasattr(current_config, 'config_data') and 'document_to_check' in current_config.config_data:
        current_config.config_data['document_to_check'] = doc_path_str
    doc = load_document(doc_path_str)
    results = []
    if current_config.title_rules:
        checker = TitleChecker(doc, current_config.title_rules)
        results.append(checker.check_title())
    if current_config.table_rules:
        checker = TableChecker(doc, current_config.table_rules)
        results.extend(checker.check_tables())
    if current_config.content_rules:
        checker = ContentChecker(doc, current_config.content_rules)
        results.extend(checker.check_contents())
    return results

def cli_entry():
    logging.info("解析命令行参数...")
    parser = argparse.ArgumentParser(description='Word文档模板检查工具')
    parser.add_argument('-c', '--config', help='配置文件路径')
    parser.add_argument('document', help='要检查的Word文档路径', nargs='?')
    parser.add_argument('--gui', action='store_true', help='启动图形界面')
    
    # 捕获任何可能的参数解析错误
    try:
        args = parser.parse_args()
    except Exception as e:
        logging.error(f"参数解析错误: {e}")
        args = parser.parse_args([])  # 使用空参数列表
    
    logging.info(f"参数解析结果: {args}")
    
    # 决定是否启动GUI
    should_launch_gui = args.gui or not args.document
    
    if should_launch_gui:
        logging.info("准备以GUI模式启动...")
        try:
            launch_gui()
        except Exception as e:
            logging.error(f"GUI启动失败: {str(e)}")
            from tkinter import messagebox
            messagebox.showerror("错误", 
                f"程序启动失败: {str(e)}\n\n"
                "请检查日志文件以获取详细信息。")
            sys.exit(1)
    else:
        logging.info("以命令行模式启动...")
        main(args.config)

if __name__ == '__main__':
    cli_entry()
