# h3c_doc_checker/gui.py
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import json
from pathlib import Path
from typing import List, Dict, Any
import webbrowser
from .batch_processor import BatchProcessor

class DocumentCheckerGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("H3C 文档检查工具")
        self.root.geometry("1000x700")

        # 配置文件路径（将在 scan_config_files 中设置为实际存在的文件）
        self.config_path = None
        # 存储所有可用的配置文件
        self.config_files = self.scan_config_files()

        # 创建主框架
        self.create_widgets()

    def create_widgets(self):
        # 顶部按钮区域
        btn_frame = ttk.Frame(self.root)
        btn_frame.pack(fill=tk.X, padx=5, pady=5)

        # 配置文件下拉框
        config_names = list(self.config_files.keys())
        self.config_combobox = ttk.Combobox(btn_frame, values=config_names, state="readonly")
        # 如果有配置文件，设置第一个为默认选项
        if config_names:
            self.config_combobox.set(config_names[0])
        self.config_combobox.bind("<<ComboboxSelected>>", self.on_config_selected)
        self.config_combobox.pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="选择文档", command=self.select_documents).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="开始检查", command=self.start_check).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="导出报告", command=self.export_report).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="重置", command=self.reset_tool).pack(side=tk.LEFT, padx=5)

        # 主内容区域
        main_frame = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL)
        main_frame.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # 左侧文件列表
        self.file_list = ttk.Treeview(main_frame, columns=("name", "status"), show="headings")
        self.file_list.heading("name", text="文档名")
        self.file_list.heading("status", text="状态")
        self.file_list.column("name", width=100)
        self.file_list.column("status", width=60)
        self.file_list.bind("<<TreeviewSelect>>", self.on_file_select)
        main_frame.add(self.file_list)

        # 右侧结果查看器
        result_frame = ttk.Frame(main_frame)
        main_frame.add(result_frame)

        # 结果查看器
        ttk.Label(result_frame, text="检查结果详情").pack(fill=tk.X, padx=5, pady=5)

        # 创建带滚动条的文本查看器
        result_container = ttk.Frame(result_frame)
        result_container.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # 添加垂直滚动条
        y_scrollbar = ttk.Scrollbar(result_container)
        y_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # 添加水平滚动条
        x_scrollbar = ttk.Scrollbar(result_container, orient=tk.HORIZONTAL)
        x_scrollbar.pack(side=tk.BOTTOM, fill=tk.X)

        # 创建文本查看器并关联滚动条
        self.result_viewer = tk.Text(result_container, wrap=tk.WORD, padx=10, pady=10,
                                    yscrollcommand=y_scrollbar.set,
                                    xscrollcommand=x_scrollbar.set)
        self.result_viewer.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # 配置滚动条
        y_scrollbar.config(command=self.result_viewer.yview)
        x_scrollbar.config(command=self.result_viewer.xview)

        # 设置文本样式
        self.result_viewer.config(font=("Microsoft YaHei", 10))
        self.result_viewer.tag_configure("h1", font=("Microsoft YaHei", 16, "bold"))
        self.result_viewer.tag_configure("h2", font=("Microsoft YaHei", 14, "bold"))
        self.result_viewer.tag_configure("h3", font=("Microsoft YaHei", 12, "bold"))
        self.result_viewer.tag_configure("bold", font=("Microsoft YaHei", 10, "bold"))

        # 存储检查结果
        self.check_results = {}

        # 状态栏
        self.status_var = tk.StringVar()
        self.status_bar = ttk.Label(self.root, textvariable=self.status_var, relief=tk.SUNKEN)
        self.status_bar.pack(fill=tk.X, side=tk.BOTTOM)

    def scan_config_files(self) -> Dict[str, Path]:
        """扫描可用的配置文件"""
        config_files = {}
        base_dir = Path(__file__).parent
        config_dir = base_dir / "config"

        # 扫描config目录下的所有json文件并按字母顺序排序
        json_files = sorted(config_dir.glob("*.json"), key=lambda x: x.name)

        # 添加所有配置文件
        for json_file in json_files:
            # 使用文件名（不含扩展名）作为显示名称
            display_name = json_file.stem
            config_files[display_name] = json_file

        # 如果有配置文件，设置第一个为默认选项
        if json_files:
            self.config_path = str(json_files[0])

        return config_files

    def on_config_selected(self, event):
        """处理配置文件选择事件"""
        selected = self.config_combobox.get()
        if selected in self.config_files:
            self.config_path = str(self.config_files[selected])
            self.status_var.set(f"已选择配置文件: {self.config_files[selected].name}")

    def refresh_config_list(self):
        """刷新配置文件列表"""
        self.config_files = self.scan_config_files()
        self.config_combobox["values"] = list(self.config_files.keys())

    def select_documents(self):
        file_paths = filedialog.askopenfilenames(
            title="选择要检查的文档",
            filetypes=[("Word 文档", "*.docx"), ("所有文件", "*.*")],
            initialdir=str(Path.home() / "Desktop")
        )
        if file_paths:
            for file_path in file_paths:
                file_name = Path(file_path).name
                display_name = file_name[:3] + "..." if len(file_name) > 3 else file_name
                self.file_list.insert("", "end", text=file_path, values=(display_name, "待检查"))

    def start_check(self):
        if not self.file_list.get_children():
            messagebox.showwarning("警告", "请先选择要检查的文档")
            return

        try:
            processor = BatchProcessor(self.config_path)
            doc_paths = [self.file_list.item(item, "text") for item in self.file_list.get_children()]
            results = processor.process_batch(doc_paths)

            # 更新UI并存储结果
            self.check_results = {}
            for i, item in enumerate(self.file_list.get_children()):
                doc_result = results["documents"][i]
                status = "通过" if doc_result.get("passed", False) else "失败"
                # 获取当前显示名称
                display_name = self.file_list.item(item, "values")[0]
                self.file_list.item(item, values=(display_name, status))
                # 存储每个文件的检查结果
                file_path = self.file_list.item(item, "text")
                self.check_results[file_path] = doc_result

            # 显示第一个结果
            if results["documents"] and self.file_list.get_children():
                first_file = self.file_list.item(self.file_list.get_children()[0], "text")
                self.show_result(self.check_results[first_file])

            self.status_var.set(f"检查完成: 共 {results['total']} 个文档, 通过 {results['passed']} 个, 失败 {results['failed']} 个")

        except Exception as e:
            messagebox.showerror("错误", f"检查过程中出错: {str(e)}")

    def on_file_select(self, event):
        """当用户选择文件列表中的文件时触发"""
        selected_items = self.file_list.selection()
        if not selected_items:
            return

        # 获取选中的文件路径
        file_path = self.file_list.item(selected_items[0], "text")

        # 如果有该文件的检查结果，则显示
        if file_path in self.check_results:
            self.show_result(self.check_results[file_path])
        else:
            # 清空结果显示
            self.result_viewer.delete(1.0, tk.END)

    def show_result(self, result):
        """将检查结果转换为Markdown格式并显示"""
        self.result_viewer.delete(1.0, tk.END)
        try:
            # 生成Markdown格式的结果
            md_content = self._format_result_as_markdown(result)

            # 逐行插入并应用样式
            lines = md_content.split('\n')
            for line in lines:
                if line.startswith('# '):
                    self.result_viewer.insert(tk.END, line[2:] + '\n', 'h1')
                elif line.startswith('## '):
                    self.result_viewer.insert(tk.END, line[3:] + '\n', 'h2')
                elif line.startswith('### '):
                    self.result_viewer.insert(tk.END, line[4:] + '\n', 'h3')
                elif line.startswith('#### '):
                    self.result_viewer.insert(tk.END, line[5:] + '\n', 'h3')
                elif '**' in line:
                    # 处理粗体文本
                    parts = line.split('**')
                    for i, part in enumerate(parts):
                        if i % 2 == 0:  # 非粗体部分
                            self.result_viewer.insert(tk.END, part)
                        else:  # 粗体部分
                            self.result_viewer.insert(tk.END, part, 'bold')
                    self.result_viewer.insert(tk.END, '\n')
                else:
                    self.result_viewer.insert(tk.END, line + '\n')
        except Exception as e:
            self.result_viewer.insert(tk.END, f"无法格式化结果: {str(e)}")

    def _format_result_as_markdown(self, result):
        """将JSON结果转换为Markdown格式"""
        md = []

        # 文件标题和状态
        file_name = Path(result.get("file", "未知文件")).name
        status = "✅ 通过" if result.get("passed", False) else "❌ 失败"
        md.append(f"# {file_name} - {status}")

        # 如果有错误信息
        if "error" in result:
            md.append(f"**错误信息:** {result['error']}")
            return "\n".join(md)

        # 详细检查结果
        if "results" in result and result["results"]:
            md.append(f"## 详细检查结果\n")

            for i, check_result in enumerate(result["results"]):
                # 检查类型和状态
                check_type = check_result.get("type", "未知检查")
                check_status = "✅ 通过" if check_result.get("passed", False) else "❌ 失败"
                md.append(f"### {check_type} {check_status}")

                # 检查消息
                if "message" in check_result:
                    md.append(f"{check_result['message']}")

                # 详细信息
                if "details" in check_result and check_result["details"]:
                    details = []
                    for key, value in check_result["details"].items():
                        if isinstance(value, list):
                            details.append(f"- {key}: {', '.join(str(item) for item in value)}")
                        else:
                            details.append(f"- {key}: {value}")
                    if details:
                        md.append("**详细信息:** " + " | ".join(details))
        else:
            md.append("*没有详细的检查结果*\n")

        return "\n".join(md)

    def export_report(self):
        file_types = [
            ("Markdown 文件", "*.md"),
            ("JSON 文件", "*.json"),
            ("所有文件", "*.*")
        ]
        file_path = filedialog.asksaveasfilename(
            title="保存报告",
            defaultextension=".md",
            filetypes=file_types,
            initialfile="document_check_report.md"
        )
        if not file_path:
            return

        try:
            # 根据文件扩展名决定导出格式
            if file_path.lower().endswith(".json"):
                self._export_json_report(file_path)
            else:
                self._export_markdown_report(file_path)

            messagebox.showinfo("成功", f"报告已保存到: {file_path}")
        except Exception as e:
            messagebox.showerror("错误", f"保存报告失败: {str(e)}")

    def _export_json_report(self, file_path):
        """导出JSON格式报告"""
        results = []
        for item in self.file_list.get_children():
            file_path_item = self.file_list.item(item, "text")
            if file_path_item in self.check_results:
                results.append(self.check_results[file_path_item])
            else:
                results.append({
                    "file": file_path_item,
                    "status": self.file_list.item(item, "values")[0]
                })

        with open(file_path, "w", encoding="utf-8") as f:
            json.dump({"documents": results}, f, indent=2, ensure_ascii=False)

    def _export_markdown_report(self, file_path):
        """导出Markdown格式报告"""
        md_lines = ["# H3C文档检查报告", f"生成时间: {Path.ctime(Path())}"]

        # 总体统计
        total = len(self.file_list.get_children())
        passed = sum(1 for item in self.file_list.get_children()
                    if self.file_list.item(item, "values")[0] == "通过")
        failed = total - passed

        md_lines.append(f"## 总体统计: 总计 {total} 个文档 (✅ {passed} 个通过, ❌ {failed} 个失败)")

        # 各文档详细结果
        md_lines.append("## 详细检查结果")

        for item in self.file_list.get_children():
            file_path_item = self.file_list.item(item, "text")
            file_name = Path(file_path_item).name
            status = self.file_list.item(item, "values")[0]
            status_icon = "✅" if status == "通过" else "❌"

            md_lines.append(f"### {file_name} {status_icon}")

            # 如果有详细检查结果
            if file_path_item in self.check_results:
                result = self.check_results[file_path_item]

                # 如果有错误信息
                if "error" in result:
                    md_lines.append(f"**错误信息:** {result['error']}")
                    continue

                # 详细检查结果
                if "results" in result and result["results"]:
                    for check_result in result["results"]:
                        check_type = check_result.get("type", "未知检查")
                        check_icon = "✅" if check_result.get("passed", False) else "❌"

                        md_lines.append(f"#### {check_type} {check_icon}")

                        if "message" in check_result:
                            md_lines.append(check_result['message'])

                        if "details" in check_result and check_result["details"]:
                            details = []
                            for key, value in check_result["details"].items():
                                if isinstance(value, list):
                                    details.append(f"- {key}: {', '.join(str(item) for item in value)}")
                                else:
                                    details.append(f"- {key}: {value}")
                            if details:
                                md_lines.append("**详细信息:** " + " | ".join(details))
                else:
                    md_lines.append("*没有详细的检查结果*")
            else:
                md_lines.append("*没有详细的检查结果*")

        with open(file_path, "w", encoding="utf-8") as f:
            f.write("\n\n".join(md_lines))

    def reset_tool(self):
        """重置工具状态"""
        # 清空文件列表
        for item in self.file_list.get_children():
            self.file_list.delete(item)

        # 清空检查结果
        self.check_results = {}

        # 清空结果显示
        self.result_viewer.delete(1.0, tk.END)

        # 重置状态栏
        self.status_var.set("工具已重置")

def run_gui():
    root = tk.Tk()
    app = DocumentCheckerGUI(root)
    root.mainloop()

if __name__ == "__main__":
    run_gui()