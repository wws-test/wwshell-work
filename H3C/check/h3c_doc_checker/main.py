# h3c_doc_checker/main.py
import sys
import argparse
from pathlib import Path
from typing import List
import logging
import tkinter as tk

from h3c_doc_checker.config import Config
from h3c_doc_checker.utils import CheckResult, load_document, format_check_results, ensure_utf8_environment
from h3c_doc_checker.checkers import TitleChecker, TableChecker, ContentChecker, FontChecker
from h3c_doc_checker.batch_processor import BatchProcessor

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

        # 使用启动画面启动GUI
        logging.info("启动带启动画面的GUI...")
        from h3c_doc_checker.splash import main as splash_main
        splash_main()
        logging.info("GUI启动成功")

    except ImportError as e:
        logging.error(f"无法导入GUI模块: {str(e)}")
        # 如果启动画面失败，回退到直接启动GUI
        logging.info("回退到直接启动GUI...")
        from h3c_doc_checker.gui import DocumentCheckerGUI
        root = tk.Tk()
        app = DocumentCheckerGUI(root)
        return root.mainloop()
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
    try:
        # 加载配置
        if not config_path:
            # 使用实际存在的配置文件
            default_config_dir = Path(__file__).parent / "config"
            config_files = list(default_config_dir.glob("*.json"))
            if config_files:
                effective_config_path = config_files[0]  # 使用第一个找到的配置文件
            else:
                raise FileNotFoundError("未找到任何配置文件")
        else:
            effective_config_path = Path(config_path)

        config = Config(effective_config_path)
        config.validate()

        # 创建批处理器
        processor = BatchProcessor(config_path=config_path)
        
        # 执行检查
        doc_result = processor.process_document(doc_path)
        
        # 将字典格式的结果转换为CheckResult列表
        results = []
        for result_dict in doc_result.get("results", []):
            result = CheckResult(
                type=result_dict.get("type"),
                passed=result_dict.get("passed"),
                message=result_dict.get("message"),
                details=result_dict.get("details")
            )
            results.append(result)

        return results

    except Exception as e:
        logging.error(f"文档检查出错: {str(e)}", exc_info=True)
        raise

def output_check_results(results: List[CheckResult], total: int, passed: int, failed: int) -> int:
    """输出检查结果
    
    Args:
        results: 检查结果列表
        total: 总检查项数
        passed: 通过项数
        failed: 失败项数
        
    Returns:
        int: 退出码，0表示全部通过，1表示有失败项
    """
    # 使用集合存储唯一的检查结果
    unique_results = set()
    for result in results:
        unique_results.add((result.type, result.message, str(result.details), result.passed))
    
    # 重新计算统计数据
    total = len(unique_results)
    passed = sum(1 for r in unique_results if r[3])
    failed = total - passed
    
    if failed > 0:
        print("\n=== 检查结果 ===\n")
        for i, (type_, message, details, _) in enumerate(sorted(r for r in unique_results if not r[3]), 1):
            status = "✗"
            print(f"{i}. [{status}] {message}")
            print(f"   详情: {details}")
    
    print("\n=== 检查完成 ===\n")
    print(f"总计: {total} 项, 通过: {passed} 项, 失败: {failed} 项")
    
    return 1 if failed > 0 else 0

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
    try:
        args = parse_arguments()

        if args.command == "gui":
            return launch_gui()
        elif args.command == "check":
            results = check_single_document(args.file, args.config)
            total = len(results)
            passed = sum(1 for r in results if r.passed)
            failed = total - passed
            
            return output_check_results(results, total, passed, failed)
        elif args.command == "batch":
            from h3c_doc_checker.batch_processor import BatchProcessor
            processor = BatchProcessor(args.config)
            # 这里可以添加批量处理逻辑
            print("批量处理功能正在开发中...")
            return 0
        else:
            # 如果没有指定命令，默认启动GUI
            return launch_gui()

    except Exception as e:
        logging.error(f"程序出错: {str(e)}", exc_info=True)
        return 1

if __name__ == "__main__":
    sys.exit(main())