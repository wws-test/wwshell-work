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
    """启动主应用程序"""
    import tkinter as tk
    from h3c_doc_checker.gui import DocumentCheckerGUI

    root = tk.Tk()
    app = DocumentCheckerGUI(root)
    root.mainloop()

def main():
    """主启动函数，显示启动画面并启动应用"""
    ensure_utf8_environment()
    splash = SplashScreen()

    steps = [
        (15, "正在初始化环境..."),
        (30, "扫描配置文件..."),
        (50, "加载检查模块..."),
        (70, "准备界面组件..."),
        (90, "初始化完成..."),
        (100, "启动应用")
    ]

    for progress, text in steps:
        splash.update_progress(progress, text)
        time.sleep(0.3)  # 稍微快一点的加载速度

    splash.finish()
    start_main_app()

if __name__ == "__main__":
    main()
