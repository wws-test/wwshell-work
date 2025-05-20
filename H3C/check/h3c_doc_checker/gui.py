import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from ttkthemes import ThemedTk
import json
import webbrowser
import time
import logging
import importlib.resources
from pathlib import Path
from h3c_doc_checker.utils import ensure_utf8_environment, format_check_results, CheckResult
from h3c_doc_checker.config import Config
from h3c_doc_checker.checkers import title_checker, table_checker, content_checker

class CheckerGUI:
    def __init__(self):
        self.root = ThemedTk(theme="arc")
        self.root.title("Word文档规范检查工具")
        self.root.geometry("800x600")
        # 设置图标（打包后也能找到）
        try:
            with importlib.resources.path("h3c_doc_checker.resources", "icon.ico") as icon_path:
                self.root.iconbitmap(str(icon_path))
        except Exception:
            logging.warning("无法加载图标文件", exc_info=True)
            pass
            
        # 初始化变量
        self.doc_path = tk.StringVar()
        self.config_path = tk.StringVar()
        self.result_text = None
        
        self.create_widgets()
        
    def create_widgets(self):
        """创建GUI界面元素"""
        # 主框架
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        
        # 文件选择区域
        file_frame = ttk.LabelFrame(main_frame, text="文件选择", padding="5")
        file_frame.grid(row=0, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=5)
        
        # Word文档选择
        ttk.Label(file_frame, text="Word文档:").grid(row=0, column=0, sticky=tk.W, padx=5)
        ttk.Entry(file_frame, textvariable=self.doc_path, width=50).grid(row=0, column=1, sticky=(tk.W, tk.E), padx=5)
        ttk.Button(file_frame, text="浏览...", command=self.select_doc).grid(row=0, column=2, sticky=tk.W, padx=5)
        
        # 配置文件选择
        ttk.Label(file_frame, text="配置文件:").grid(row=1, column=0, sticky=tk.W, padx=5)
        ttk.Entry(file_frame, textvariable=self.config_path, width=50).grid(row=1, column=1, sticky=(tk.W, tk.E), padx=5)
        ttk.Button(file_frame, text="浏览...", command=self.select_config).grid(row=1, column=2, sticky=tk.W, padx=5)
        
        # 控制按钮区域
        button_frame = ttk.Frame(main_frame)
        button_frame.grid(row=1, column=0, columnspan=3, pady=10)
        
        ttk.Button(button_frame, text="开始检查", command=self.start_check).grid(row=0, column=0, padx=5)
        ttk.Button(button_frame, text="导出报告", command=self.export_report).grid(row=0, column=1, padx=5)
        ttk.Button(button_frame, text="帮助", command=self.show_help).grid(row=0, column=2, padx=5)
        
        # 结果显示区域
        result_frame = ttk.LabelFrame(main_frame, text="检查结果", padding="5")
        result_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=5)
        main_frame.rowconfigure(2, weight=1)
        
        self.result_text = tk.Text(result_frame, wrap=tk.WORD, width=80, height=20)
        self.result_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        scrollbar = ttk.Scrollbar(result_frame, orient=tk.VERTICAL, command=self.result_text.yview)
        scrollbar.grid(row=0, column=1, sticky=(tk.N, tk.S))
        self.result_text.configure(yscrollcommand=scrollbar.set)
        
        result_frame.columnconfigure(0, weight=1)
        result_frame.rowconfigure(0, weight=1)
        
        # 状态栏
        status_frame = ttk.Frame(main_frame)
        status_frame.grid(row=3, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=5)
        self.status_label = ttk.Label(status_frame, text="就绪")
        self.status_label.grid(row=0, column=0, sticky=tk.W)
        
    def select_doc(self):
        """选择Word文档"""
        filename = filedialog.askopenfilename(
            title="选择Word文档",
            filetypes=[("Word文档", "*.docx"), ("所有文件", "*.*")]
        )
        if filename:
            self.doc_path.set(filename)
            
    def select_config(self):
        """选择配置文件"""
        filename = filedialog.askopenfilename(
            title="选择配置文件",
            filetypes=[("JSON文件", "*.json"), ("所有文件", "*.*")]
        )
        if filename:
            self.config_path.set(filename)
            
    def start_check(self):
        """开始检查文档"""
        # 检查文档路径
        doc_path = self.doc_path.get().strip()
        if not doc_path:
            messagebox.showerror("错误", "请选择要检查的Word文档")
            return
            
        # 获取配置路径
        config_path = self.config_path.get().strip()
        if not config_path:
            # 使用默认配置
            with importlib.resources.path("h3c_doc_checker.config", "default_config.json") as p:
                config_path = str(p)
                
        try:
            # 更新状态
            self.status_label.config(text="正在检查...")
            self.root.update()
            
            # 运行检查
            from h3c_doc_checker.main import run_check
            results = run_check(doc_path, config_path)
            
            # 显示结果
            self.display_results(results)
            
        except Exception as e:
            messagebox.showerror("错误", f"检查过程中出错:\n{str(e)}")
            logging.error("检查失败", exc_info=True)
        finally:
            self.status_label.config(text="就绪")
            
    def display_results(self, results):
        """显示检查结果"""
        self.result_text.delete(1.0, tk.END)
        
        # 统计结果
        total_checks = len(results)
        passed_checks = sum(1 for r in results if r.passed)
        
        # 显示结果摘要
        summary = f"=== 文档检查报告 ===\n\n"
        summary += format_check_results(results)
        summary += f"\n总结:\n"
        summary += f"- 总检查项: {total_checks}\n"
        summary += f"- 通过项数: {passed_checks}\n"
        summary += f"- 失败项数: {total_checks - passed_checks}\n"
        summary += f"\n整体状态: {'通过' if passed_checks == total_checks else '失败'}\n"
        
        self.result_text.insert(tk.END, summary)
        
    def export_report(self):
        """导出检查报告"""
        if not self.result_text.get(1.0, tk.END).strip():
            messagebox.showinfo("提示", "没有可以导出的检查结果")
            return
            
        filename = filedialog.asksaveasfilename(
            title="导出报告",
            defaultextension=".txt",
            filetypes=[("文本文件", "*.txt"), ("所有文件", "*.*")]
        )
        
        if filename:
            try:
                with open(filename, 'w', encoding='utf-8') as f:
                    f.write(self.result_text.get(1.0, tk.END))
                messagebox.showinfo("成功", "报告已导出")
            except Exception as e:
                messagebox.showerror("错误", f"导出报告失败:\n{str(e)}")
                
    def show_help(self):
        """显示帮助信息"""
        help_text = """
使用说明：

1. 选择要检查的Word文档
2. 选择配置文件（可选，默认使用内置配置）
3. 点击"开始检查"按钮
4. 查看检查结果
5. 可以使用"导出报告"保存结果

如需更多帮助，请参考文档。
        """
        messagebox.showinfo("帮助", help_text)
        
    def run(self):
        """运行GUI程序"""
        self.root.mainloop()
