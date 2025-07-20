#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
对比本地SHA256和网站SHA256值
"""

import sys
import re
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

def parse_sha256_file(filepath):
    """解析SHA256文件，返回字典 {filename: sha256}"""
    results = {}
    
    if not Path(filepath).exists():
        print(f"文件不存在: {filepath}")
        return results
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                # 支持多种格式:
                # 1. sha256  filename
                # 2. filename: sha256
                # 3. filename,sha256
                
                if '  ' in line:  # 标准格式
                    parts = line.split('  ', 1)
                    if len(parts) == 2:
                        sha256, filename = parts
                        results[filename.strip()] = sha256.strip().lower()
                elif ':' in line:  # filename: sha256 格式
                    parts = line.split(':', 1)
                    if len(parts) == 2:
                        filename, sha256 = parts
                        results[filename.strip()] = sha256.strip().lower()
                elif ',' in line:  # filename,sha256 格式
                    parts = line.split(',', 1)
                    if len(parts) == 2:
                        filename, sha256 = parts
                        results[filename.strip()] = sha256.strip().lower()
                else:
                    print(f"第{line_num}行格式无法识别: {line}")
                    continue
    
    except Exception as e:
        print(f"读取文件 {filepath} 时出错: {e}")
    
    return results

def compare_sha256_files(local_file, remote_file, output_file="sha256_comparison_report.txt"):
    """对比两个SHA256文件"""
    print("开始对比SHA256值...")
    print("=" * 60)
    
    # 解析文件
    local_sha256 = parse_sha256_file(local_file)
    remote_sha256 = parse_sha256_file(remote_file)
    
    print(f"本地文件 ({local_file}): {len(local_sha256)} 个文件")
    print(f"远程文件 ({remote_file}): {len(remote_sha256)} 个文件")
    print("-" * 60)
    
    # 找到所有文件名
    all_files = set(local_sha256.keys()) | set(remote_sha256.keys())
    local_only = set(local_sha256.keys()) - set(remote_sha256.keys())
    remote_only = set(remote_sha256.keys()) - set(local_sha256.keys())
    common_files = set(local_sha256.keys()) & set(remote_sha256.keys())
    
    # 对比结果
    matches = []
    mismatches = []
    
    for filename in sorted(common_files):
        local_hash = local_sha256[filename]
        remote_hash = remote_sha256[filename]
        
        if local_hash == remote_hash:
            matches.append(filename)
        else:
            mismatches.append((filename, local_hash, remote_hash))
    
    # 生成报告
    report_lines = []
    report_lines.append("SHA256 对比报告")
    report_lines.append("=" * 60)
    report_lines.append(f"生成时间: {sys.modules['time'].strftime('%Y-%m-%d %H:%M:%S')}")
    report_lines.append("")
    
    report_lines.append("📊 统计信息:")
    report_lines.append(f"  - 本地文件数量: {len(local_sha256)}")
    report_lines.append(f"  - 远程文件数量: {len(remote_sha256)}")
    report_lines.append(f"  - 共同文件数量: {len(common_files)}")
    report_lines.append(f"  - 仅本地存在: {len(local_only)}")
    report_lines.append(f"  - 仅远程存在: {len(remote_only)}")
    report_lines.append(f"  - SHA256匹配: {len(matches)}")
    report_lines.append(f"  - SHA256不匹配: {len(mismatches)}")
    report_lines.append("")
    
    # 详细结果
    if matches:
        report_lines.append("✅ SHA256匹配的文件:")
        for filename in sorted(matches):
            report_lines.append(f"  ✓ {filename}")
        report_lines.append("")
    
    if mismatches:
        report_lines.append("❌ SHA256不匹配的文件:")
        for filename, local_hash, remote_hash in sorted(mismatches):
            report_lines.append(f"  ✗ {filename}")
            report_lines.append(f"    本地:  {local_hash}")
            report_lines.append(f"    远程:  {remote_hash}")
        report_lines.append("")
    
    if local_only:
        report_lines.append("📁 仅本地存在的文件:")
        for filename in sorted(local_only):
            report_lines.append(f"  📄 {filename} (SHA256: {local_sha256[filename]})")
        report_lines.append("")
    
    if remote_only:
        report_lines.append("🌐 仅远程存在的文件:")
        for filename in sorted(remote_only):
            report_lines.append(f"  📄 {filename} (SHA256: {remote_sha256[filename]})")
        report_lines.append("")
    
    # 输出到控制台
    for line in report_lines:
        print(line)
    
    # 保存到文件
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report_lines))
        print(f"\n📋 详细报告已保存到: {output_file}")
    except Exception as e:
        print(f"保存报告时出错: {e}")
    
    # 返回统计信息
    return {
        'total_local': len(local_sha256),
        'total_remote': len(remote_sha256),
        'common': len(common_files),
        'matches': len(matches),
        'mismatches': len(mismatches),
        'local_only': len(local_only),
        'remote_only': len(remote_only)
    }

def main():
    """主函数"""
    print("SHA256 对比工具")
    print("=" * 60)
    
    # 检查文件是否存在
    local_file = "local_sha256.txt"  # SSH服务器上计算的SHA256
    remote_file = "modelscope_sha256.txt"  # 从网站爬取的SHA256
    
    # 如果有测试文件，也可以使用
    if Path("test_sha256.txt").exists() and not Path(remote_file).exists():
        remote_file = "test_sha256.txt"
        print(f"使用测试文件: {remote_file}")
    
    if not Path(local_file).exists():
        print(f"❌ 本地SHA256文件不存在: {local_file}")
        print("请先运行SSH命令计算本地文件的SHA256值")
        return
    
    if not Path(remote_file).exists():
        print(f"❌ 远程SHA256文件不存在: {remote_file}")
        print("请先运行playwright_crawler.py获取网站的SHA256值")
        return
    
    # 执行对比
    stats = compare_sha256_files(local_file, remote_file)
    
    # 总结
    print("\n" + "=" * 60)
    print("🎯 对比总结:")
    if stats['matches'] == stats['common'] and stats['common'] > 0:
        print("✅ 所有共同文件的SHA256值完全匹配！")
    elif stats['mismatches'] > 0:
        print(f"⚠️  发现 {stats['mismatches']} 个文件的SHA256值不匹配")
    
    if stats['local_only'] > 0:
        print(f"📁 本地有 {stats['local_only']} 个文件在远程不存在")
    
    if stats['remote_only'] > 0:
        print(f"🌐 远程有 {stats['remote_only']} 个文件在本地不存在")

if __name__ == "__main__":
    import time
    main() 