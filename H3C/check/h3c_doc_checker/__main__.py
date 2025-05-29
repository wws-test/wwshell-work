# h3c_doc_checker/__main__.py
import sys
import logging
from pathlib import Path

def setup_logging():
    """配置日志记录"""
    log_file = Path("h3c_checker.log")
    # 移除所有现有的处理器
    logger = logging.getLogger()
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # 只添加文件处理器
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s"))
    logger.addHandler(file_handler)
    logger.setLevel(logging.INFO)
    
    return log_file

def main():
    """主入口函数"""
    # 设置日志记录
    log_file = setup_logging()
    
    try:
        # 记录启动信息
        logging.info("=" * 50)
        logging.info("H3C Doc Checker 启动")
        logging.info(f"Python版本: {sys.version}")
        logging.info(f"工作目录: {Path.cwd()}")
        logging.info(f"日志文件: {log_file.absolute()}")
        
        # 导入主模块
        from h3c_doc_checker.main import main as main_module
        return main_module()
        
    except ImportError as e:
        logging.error(f"无法导入必要的模块: {str(e)}", exc_info=True)
        return 1
    except Exception as e:
        logging.error(f"程序出错: {str(e)}", exc_info=True)
        return 1

if __name__ == "__main__":
    sys.exit(main())