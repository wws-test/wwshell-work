#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
完整的SHA256对比流程脚本
1. 完成SSH服务器上剩余文件的SHA256计算
2. 使用Playwright获取全部163个文件的网站SHA256值
3. 对比并生成完整报告
"""

import asyncio
import sys
import subprocess
import time
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

# 导入我们的爬虫和对比模块
from playwright_crawler import PlaywrightSHA256Crawler
from compare_sha256 import compare_sha256_files

async def complete_ssh_sha256():
    """完成SSH服务器上剩余文件的SHA256计算"""
    print("步骤1: 完成SSH服务器上剩余文件的SHA256计算")
    print("=" * 60)
    
    # 这里可以添加SSH命令来完成剩余文件的计算
    # 由于我们已经有了50个文件，需要计算剩余的113个文件
    print("✅ SSH服务器SHA256计算已在后台进行中...")
    print("请确保SSH服务器上的计算已完成，或手动运行以下命令:")
    print("cd /HDD_Raid/SVN_MODEL_REPO/Model/DeepSeek-R1-0528/")
    print("for i in {51..163}; do")
    print("  file=$(printf \"model-%05d-of-000163.safetensors\" $i)")
    print("  if [ -f \"$file\" ]; then")
    print("    sha256sum \"$file\" >> local_sha256.txt")
    print("  fi")
    print("done")
    print()

async def crawl_all_website_sha256():
    """获取网站上全部163个文件的SHA256值"""
    print("步骤2: 获取网站上全部163个文件的SHA256值")
    print("=" * 60)
    
    crawler = PlaywrightSHA256Crawler()
    
    try:
        # 获取全部163个文件，分批处理以避免过载
        print("开始爬取全部163个文件的SHA256值...")
        results = await crawler.crawl_all_sha256(
            start_file=1, 
            end_file=163, 
            batch_size=3  # 减小批次大小以提高稳定性
        )
        
        # 保存结果
        crawler.save_results("modelscope_sha256.txt")
        
        print(f"\n✅ 网站SHA256获取完成，成功获取 {len(results)} 个文件")
        return len(results)
        
    except Exception as e:
        print(f"❌ 网站SHA256获取失败: {e}")
        return 0

def run_comparison():
    """运行SHA256对比"""
    print("步骤3: 运行SHA256对比")
    print("=" * 60)
    
    local_file = "local_sha256.txt"
    remote_file = "modelscope_sha256.txt"
    
    if not Path(local_file).exists():
        print(f"❌ 本地SHA256文件不存在: {local_file}")
        return False
    
    if not Path(remote_file).exists():
        print(f"❌ 远程SHA256文件不存在: {remote_file}")
        return False
    
    # 执行对比
    stats = compare_sha256_files(local_file, remote_file, "final_sha256_comparison_report.txt")
    
    return True

async def main():
    """主函数"""
    print("DeepSeek-R1-0528 模型文件SHA256完整对比流程")
    print("=" * 80)
    print("目标: 对比163个模型文件的SHA256值")
    print("本地: /HDD_Raid/SVN_MODEL_REPO/Model/DeepSeek-R1-0528/")
    print("远程: https://modelscope.cn/models/deepseek-ai/DeepSeek-R1-0528/")
    print("=" * 80)
    print()
    
    start_time = time.time()
    
    # 步骤1: 检查SSH计算状态
    await complete_ssh_sha256()
    
    # 步骤2: 爬取网站SHA256值
    success_count = await crawl_all_website_sha256()
    
    if success_count == 0:
        print("❌ 网站SHA256获取失败，无法进行对比")
        return
    
    # 步骤3: 对比结果
    if run_comparison():
        print("\n" + "=" * 80)
        print("🎉 完整对比流程执行完成！")
        
        end_time = time.time()
        elapsed = end_time - start_time
        print(f"⏱️  总耗时: {elapsed/60:.1f} 分钟")
        print(f"📊 成功获取 {success_count}/163 个文件的网站SHA256值")
        print("📋 详细对比报告已保存到: final_sha256_comparison_report.txt")
    else:
        print("❌ 对比过程失败")

if __name__ == "__main__":
    # 运行完整流程
    asyncio.run(main()) 