import tkinter as tk
from tkinter import ttk
from ttkthemes import ThemedTk
import time
import importlib.resources
from h3c_doc_checker.utils import ensure_utf8_environment

class SplashScreen:
    def __init__(self):
        self.root = tk.Tk()
        self.root.overrideredirect(True)
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        width = 400
        height = 200
        x = (screen_width - width) // 2
        y = (screen_height - height) // 2
        self.root.geometry(f'{width}x{height}+{x}+{y}')
        self.root.configure(bg='#2c3e50')
        title = tk.Label(
            self.root,
            text="Word文档规范检查工具",
            font=("微软雅黑", 16, "bold"),
            bg='#2c3e50',
            fg='white'
        )
        title.pack(pady=20)
        self.progress = ttk.Progressbar(
            self.root,
            length=300,
            mode='determinate'
        )
        self.progress.pack(pady=20)
        self.loading_text = tk.Label(
            self.root,
            text="正在加载...",
            font=("微软雅黑", 10),
            bg='#2c3e50',
            fg='white'
        )
        self.loading_text.pack(pady=10)
        version = tk.Label(
            self.root,
            text="v1.0.0",
            font=("微软雅黑", 8),
            bg='#2c3e50',
            fg='#95a5a6'
        )
        version.pack(side=tk.BOTTOM, pady=10)
    def update_progress(self, value, text=""):
        self.progress['value'] = value
        if text:
            self.loading_text['text'] = text
        self.root.update()
    def finish(self):
        self.root.destroy()

def start_main_app():
    from h3c_doc_checker.gui import CheckerGUI
    app = CheckerGUI()
    app.run()

def main():
    ensure_utf8_environment()
    splash = SplashScreen()
    steps = [
        (20, "正在初始化..."),
        (40, "加载配置文件..."),
        (60, "准备界面组件..."),
        (80, "初始化检查模块..."),
        (100, "启动完成")
    ]
    for progress, text in steps:
        splash.update_progress(progress, text)
        time.sleep(0.5)
    splash.finish()
    start_main_app()

if __name__ == "__main__":
    main()
