#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Command Monitor - 精准监控构建脚本
Python版本 - 跨平台支持
"""

import os
import sys
import shutil
import subprocess
import argparse
from pathlib import Path

# 配置常量
BINARY_NAME = "cmdmonitor"
MAIN_PATH = "cmd/main.go"
BUILD_DIR = "build"
VERSION = "v1.0.0"

def run_command(cmd, cwd=None, env=None):
    """执行命令并返回结果"""
    try:
        result = subprocess.run(cmd, shell=True, cwd=cwd, env=env,
                              capture_output=True, text=True, check=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

def print_success(msg):
    """打印成功消息"""
    print(f"✅ {msg}")

def print_error(msg):
    """打印错误消息"""
    print(f"❌ {msg}")

def print_info(msg):
    """打印信息消息"""
    print(f"🔧 {msg}")

def clean_build():
    """清理构建文件"""
    print_info("清理构建文件...")
    
    if os.path.exists(BUILD_DIR):
        shutil.rmtree(BUILD_DIR)
    
    # 删除可能的本地二进制文件
    for ext in ['.exe', '']:
        binary_file = f"{BINARY_NAME}{ext}"
        if os.path.exists(binary_file):
            os.remove(binary_file)
    
    print_success("清理完成")

def build_linux():
    """构建Linux版本"""
    print_info(f"构建 {BINARY_NAME} for linux/amd64...")
    
    # 创建构建目录
    os.makedirs(BUILD_DIR, exist_ok=True)
    
    # 设置环境变量
    env = os.environ.copy()
    env.update({
        'GOOS': 'linux',
        'GOARCH': 'amd64',
        'CGO_ENABLED': '0'
    })
    
    # 构建命令
    cmd = f'go build -ldflags "-s -w" -o {BUILD_DIR}/{BINARY_NAME}-linux-amd64 {MAIN_PATH}'

    success, output = run_command(cmd, env=env)
    if success:
        print_success(f"Linux版本构建完成: {BUILD_DIR}/{BINARY_NAME}-linux-amd64")
    else:
        print_error(f"构建失败: {output}")
        return False
    
    return True

def create_package():
    """创建部署包"""
    print_info("创建部署包...")
    
    # 先构建Linux版本
    if not build_linux():
        return False
    
    # 创建部署目录
    deploy_dir = f"{BUILD_DIR}/deploy"
    os.makedirs(deploy_dir, exist_ok=True)
    
    # 复制文件
    files_to_copy = [
        (f"{BUILD_DIR}/{BINARY_NAME}-linux-amd64", f"{deploy_dir}/{BINARY_NAME}"),
        ("configs/config.env", f"{deploy_dir}/config.env"),
        ("configs/cmdmonitor.service", f"{deploy_dir}/cmdmonitor.service"),
        ("scripts/install.sh", f"{deploy_dir}/install.sh"),
        ("DEPLOYMENT.md", f"{deploy_dir}/DEPLOYMENT.md"),
    ]
    
    for src, dst in files_to_copy:
        if os.path.exists(src):
            shutil.copy2(src, dst)
        else:
            print_error(f"文件不存在: {src}")
            return False
    
    # 创建tar.gz包
    os.chdir(BUILD_DIR)
    tar_cmd = f"tar -czf cmdmonitor-{VERSION}-deploy.tar.gz deploy/"
    success, output = run_command(tar_cmd)
    os.chdir("..")
    
    if success:
        print_success(f"部署包已创建: {BUILD_DIR}/cmdmonitor-{VERSION}-deploy.tar.gz")
    else:
        print_error(f"创建部署包失败: {output}")
        return False
    
    return True

def run_tests():
    """运行测试"""
    print_info("运行测试...")
    success, output = run_command("go test -v ./...")
    if success:
        print_success("测试通过")
        print(output)
    else:
        print_error(f"测试失败: {output}")

def format_code():
    """格式化代码"""
    print_info("格式化代码...")
    success, output = run_command("go fmt ./...")
    if success:
        print_success("代码格式化完成")
    else:
        print_error(f"格式化失败: {output}")

def vet_code():
    """代码检查"""
    print_info("代码检查...")
    success, output = run_command("go vet ./...")
    if success:
        print_success("代码检查通过")
    else:
        print_error(f"代码检查失败: {output}")

def run_local():
    """本地运行（仅用于开发调试）"""
    print_info("本地运行...")
    print("注意: 这仅用于开发调试，生产环境请使用Linux版本")
    
    # 直接运行，不捕获输出，让用户看到实时日志
    try:
        subprocess.run(f"go run {MAIN_PATH}", shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print_error(f"运行失败: {e}")
    except KeyboardInterrupt:
        print_info("用户中断运行")

def install_deps():
    """安装依赖"""
    print_info("安装依赖...")
    
    commands = [
        "go mod download",
        "go mod tidy"
    ]
    
    for cmd in commands:
        success, output = run_command(cmd)
        if not success:
            print_error(f"执行失败 '{cmd}': {output}")
            return False
    
    print_success("依赖安装完成")
    return True

def show_help():
    """显示帮助信息"""
    help_text = """
Command Monitor - 精准监控构建工具

可用的命令:
  build-linux  - 构建Linux生产版本
  package      - 创建完整部署包
  test         - 运行测试
  clean        - 清理构建文件
  fmt          - 格式化代码
  vet          - 代码检查
  run          - 本地运行（仅用于开发调试）
  deps         - 安装依赖

示例:
  python build.py build-linux   # 构建Linux版本
  python build.py package       # 创建部署包
  python build.py run           # 本地调试运行
"""
    print(help_text)

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="Command Monitor 构建工具")
    parser.add_argument('command', nargs='?', default='help',
                       choices=['build-linux', 'package', 'test', 'clean', 
                               'fmt', 'vet', 'run', 'deps', 'help'],
                       help='要执行的命令')
    
    args = parser.parse_args()
    
    # 检查是否在正确的目录
    if not os.path.exists(MAIN_PATH):
        print_error(f"找不到 {MAIN_PATH}，请在项目根目录运行此脚本")
        sys.exit(1)
    
    # 执行对应的命令
    commands = {
        'help': show_help,
        'clean': clean_build,
        'build-linux': build_linux,
        'package': create_package,
        'test': run_tests,
        'fmt': format_code,
        'vet': vet_code,
        'run': run_local,
        'deps': install_deps,
    }
    
    command_func = commands.get(args.command)
    if command_func:
        command_func()
    else:
        print_error(f"未知命令: {args.command}")
        show_help()

if __name__ == "__main__":
    main()
