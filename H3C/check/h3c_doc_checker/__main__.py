"""
H3C 文档检查工具现代化入口
支持 python -m h3c_doc_checker 直接运行
"""
import sys
import os
import traceback
import logging
import tempfile
from datetime import datetime
from pathlib import Path

def init_basic_logging():
    """初始化基本日志设置"""
    try:
        # 在临时目录下创建日志目录
        log_dir = Path(tempfile.gettempdir()) / "h3c_doc_checker"
        log_dir.mkdir(exist_ok=True)
        
        # 设置日志文件
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = log_dir / f"checker_{timestamp}.log"
        
        # 配置日志
        logging.basicConfig(
            level=logging.DEBUG,
            format='%(asctime)s - %(levelname)s - %(module)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8', mode='w'),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        # 记录基本信息
        logging.info("=== H3C Doc Checker 启动 ===")
        logging.info(f"Python版本: {sys.version}")
        logging.info(f"系统平台: {sys.platform}")
        logging.info(f"工作目录: {os.getcwd()}")
        logging.info(f"日志文件: {log_file}")
        logging.info(f"Python路径: {sys.executable}")
        
        return log_file
    except Exception as e:
        # 如果连日志都无法设置，写入一个简单的错误文件
        error_file = Path(tempfile.gettempdir()) / "h3c_doc_checker_error.txt"
        with open(error_file, "w", encoding='utf-8') as f:
            f.write(f"严重错误: 无法初始化日志\n{str(e)}\n{traceback.format_exc()}")
        return None

def show_error(error_msg, log_file=None):
    """显示错误信息对话框"""
    try:
        import tkinter as tk
        from tkinter import messagebox
        root = tk.Tk()
        root.withdraw()  # 隐藏主窗口
        full_msg = error_msg
        if log_file:
            full_msg += f"\n\n详细日志已保存到：\n{log_file}"
        messagebox.showerror("错误", full_msg)
    except Exception as e:
        # 如果 GUI 显示失败，则打印到控制台
        print("错误：", error_msg, file=sys.stderr)
        if log_file:
            print(f"详细日志已保存到：{log_file}", file=sys.stderr)

def main():
    """主入口函数"""
    # 初始化日志
    log_file = init_basic_logging()
    
    try:
        # 导入主模块
        logging.info("开始导入主模块...")
        from h3c_doc_checker.main import cli_entry
        logging.info("主模块导入成功")
        
        # 执行主程序
        logging.info("开始执行主程序...")
        cli_entry()
        
    except ImportError as e:
        error_msg = f"无法导入必要的模块: {str(e)}"
        logging.error(f"{error_msg}\n{traceback.format_exc()}")
        show_error(error_msg, log_file)
        sys.exit(1)
    except Exception as e:
        error_msg = f"程序运行时出错: {str(e)}"
        logging.error(f"{error_msg}\n{traceback.format_exc()}")
        show_error(error_msg, log_file)
        sys.exit(1)

if __name__ == "__main__":
    main()
