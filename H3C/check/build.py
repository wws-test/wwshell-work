import os
import sys
import subprocess
from pathlib import Path

# 项目根目录
BASE_PATH = Path(__file__).resolve().parent
PKG_NAME = "h3c_doc_checker"
ENTRY = f"{PKG_NAME}/__main__.py"
DIST_NAME = "docx_checker.exe"

# 检查依赖
try:
    import PyInstaller
except ImportError:
    print("未检测到 PyInstaller，正在尝试自动安装...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])

# 检查 poetry
def has_poetry():
    try:
        subprocess.check_call(["poetry", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False

# 确保资源目录和文件存在
PKG_RESOURCES = BASE_PATH / PKG_NAME / "resources"
PKG_CONFIG = BASE_PATH / PKG_NAME / "config"
if not PKG_RESOURCES.exists():
    PKG_RESOURCES.mkdir(parents=True)
if not PKG_CONFIG.exists():
    PKG_CONFIG.mkdir(parents=True)

# 如果icon.ico不存在，生成它
icon_path = PKG_RESOURCES / "icon.ico"
if not icon_path.exists():
    print("正在生成图标...")
    sys.path.append(str(BASE_PATH / "src"))
    from create_icon import create_default_icon
    create_default_icon()

# 复制default_config.json到打包目录
DEFAULT_CONFIG = BASE_PATH / PKG_NAME / "default_config.json"
PKG_DEFAULT_CONFIG = PKG_CONFIG / "default_config.json"
if DEFAULT_CONFIG.exists():
    print("复制默认配置文件...")
    import shutil
    if not PKG_CONFIG.exists():
        PKG_CONFIG.mkdir(parents=True)
    shutil.copy2(DEFAULT_CONFIG, PKG_DEFAULT_CONFIG)

# Windows下需要使用分号，其他平台使用冒号
PATH_SEP = ";" if sys.platform.startswith('win') else ":"

# 打包命令
pyi_cmd = [
    sys.executable, "-m", "PyInstaller",
    "--onefile", "-w",
    "--name", "docx_checker",
    "--add-data", f"{PKG_RESOURCES}{PATH_SEP}{PKG_NAME}/resources",
    "--add-data", f"{PKG_CONFIG}{PATH_SEP}{PKG_NAME}/config",
    "--icon", str(PKG_RESOURCES / "icon.ico"),
    "--clean",  # 清理临时文件
    "--noconfirm",  # 不询问确认
    ENTRY
]

if __name__ == "__main__":
    print("\n==== H3C Word文档规范检查工具 打包脚本 ====")
    # 优先用 poetry 安装依赖
    if has_poetry():
        print("检测到 poetry，自动安装依赖...")
        subprocess.check_call(["poetry", "install"])
    else:
        print("未检测到 poetry，请确保依赖已手动安装！")
    # 执行打包
    print(f"\n正在打包 {ENTRY} ...")
    subprocess.check_call(pyi_cmd, cwd=BASE_PATH)
    print(f"\n打包完成！可执行文件在 dist/{DIST_NAME}")
