#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用Playwright自动化浏览器获取ModelScope上的SHA256值
"""

import asyncio
import re
import json
import time
from playwright.async_api import async_playwright
import sys

sys.stdout.reconfigure(encoding='utf-8')

class PlaywrightSHA256Crawler:
    def __init__(self):
        self.base_url = "https://modelscope.cn/models/deepseek-ai/DeepSeek-R1-0528/file/view/master"
        self.results = {}
        self.browser = None
        self.context = None
        
    async def init_browser(self):
        """初始化浏览器"""
        self.playwright = await async_playwright().start()
        # 使用Chromium浏览器
        self.browser = await self.playwright.chromium.launch(
            headless=True,  # 无头模式，如果需要看到浏览器窗口，设置为False
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
        
        # 创建浏览器上下文
        self.context = await self.browser.new_context(
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            viewport={'width': 1920, 'height': 1080}
        )
        
    async def close_browser(self):
        """关闭浏览器"""
        if self.context:
            await self.context.close()
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
    
    async def get_file_sha256(self, file_number):
        """获取单个文件的SHA256值"""
        filename = f"model-{file_number:05d}-of-000163.safetensors"
        url = f"{self.base_url}/{filename}"
        
        try:
            print(f"正在获取文件 {filename} 的SHA256...")
            
            # 创建新页面
            page = await self.context.new_page()
            
            # 设置较长的超时时间
            page.set_default_timeout(60000)  # 60秒
            
            # 访问页面
            response = await page.goto(url, wait_until='networkidle')
            
            if response.status != 200:
                print(f"文件 {filename} 访问失败，状态码: {response.status}")
                await page.close()
                return None
            
            # 等待页面加载完成
            await page.wait_for_load_state('networkidle')
            await asyncio.sleep(2)  # 额外等待2秒确保内容加载
            
            # 获取页面内容
            content = await page.content()
            
            # 方式1: 在页面内容中搜索SHA256值
            sha256_pattern = r'\b[a-f0-9]{64}\b'
            matches = re.findall(sha256_pattern, content.lower())
            
            sha256_value = None
            if matches:
                # 取第一个匹配的值
                sha256_value = matches[0]
                print(f"✅ 在页面内容中找到 {filename}: {sha256_value}")
            
            # 方式2: 尝试在JavaScript执行的数据中查找
            if not sha256_value:
                try:
                    # 等待可能的动态内容加载
                    await page.wait_for_function(
                        "document.readyState === 'complete'", 
                        timeout=10000
                    )
                    
                    # 检查页面中的文本内容
                    text_content = await page.inner_text('body')
                    
                    # 在文本内容中搜索SHA256
                    matches = re.findall(sha256_pattern, text_content.lower())
                    if matches:
                        sha256_value = matches[0]
                        print(f"✅ 在页面文本中找到 {filename}: {sha256_value}")
                
                except Exception as e:
                    print(f"在JavaScript内容中搜索时出错: {e}")
            
            # 方式3: 检查页面中的特定元素
            if not sha256_value:
                try:
                    # 查找可能包含SHA256的元素
                    elements = await page.query_selector_all('div, span, code, pre, td')
                    
                    for element in elements:
                        text = await element.inner_text()
                        if text and re.match(r'^[a-f0-9]{64}$', text.strip().lower()):
                            sha256_value = text.strip().lower()
                            print(f"✅ 在HTML元素中找到 {filename}: {sha256_value}")
                            break
                            
                except Exception as e:
                    print(f"在HTML元素中搜索时出错: {e}")
            
            # 方式4: 尝试从网络请求中获取信息
            if not sha256_value:
                try:
                    # 监听网络请求
                    responses = []
                    
                    def handle_response(response):
                        if response.url.endswith('.json') or 'api' in response.url:
                            responses.append(response)
                    
                    page.on('response', handle_response)
                    
                    # 刷新页面以捕获网络请求
                    await page.reload(wait_until='networkidle')
                    await asyncio.sleep(3)
                    
                    # 检查捕获的响应
                    for response in responses:
                        try:
                            if response.status == 200:
                                json_data = await response.json()
                                json_str = json.dumps(json_data, ensure_ascii=False)
                                
                                matches = re.findall(sha256_pattern, json_str.lower())
                                if matches:
                                    sha256_value = matches[0]
                                    print(f"✅ 在API响应中找到 {filename}: {sha256_value}")
                                    break
                        except:
                            continue
                            
                except Exception as e:
                    print(f"监听网络请求时出错: {e}")
            
            # 保存结果
            if sha256_value:
                self.results[filename] = sha256_value
                
                # 同时保存到文件以防程序中断
                with open('temp_results.txt', 'a', encoding='utf-8') as f:
                    f.write(f"{sha256_value}  {filename}\n")
                    
                await page.close()
                return sha256_value
            else:
                print(f"❌ 未找到文件 {filename} 的SHA256值")
                
                # 保存页面内容用于调试
                await page.screenshot(path=f'debug_{filename.replace(".", "_")}.png')
                with open(f'debug_{filename.replace(".", "_")}.html', 'w', encoding='utf-8') as f:
                    f.write(await page.content())
                
                await page.close()
                return None
                
        except Exception as e:
            print(f"❌ 处理文件 {filename} 时出错: {e}")
            if 'page' in locals():
                await page.close()
            return None
    
    async def crawl_all_sha256(self, start_file=1, end_file=163, batch_size=5):
        """分批并发获取所有文件的SHA256值"""
        print("开始使用Playwright爬取ModelScope上的SHA256值...")
        print(f"目标文件数量: {end_file - start_file + 1}")
        print(f"批次大小: {batch_size}")
        print("-" * 50)
        
        await self.init_browser()
        
        try:
            # 分批处理以避免过多并发
            for batch_start in range(start_file, end_file + 1, batch_size):
                batch_end = min(batch_start + batch_size - 1, end_file)
                print(f"\n处理批次: {batch_start} - {batch_end}")
                
                # 创建批次任务
                tasks = []
                for i in range(batch_start, batch_end + 1):
                    task = self.get_file_sha256(i)
                    tasks.append(task)
                
                # 并发执行批次任务
                batch_results = await asyncio.gather(*tasks, return_exceptions=True)
                
                # 统计批次结果
                success_count = sum(1 for result in batch_results if result is not None and not isinstance(result, Exception))
                print(f"批次 {batch_start}-{batch_end} 完成，成功: {success_count}/{len(tasks)}")
                
                # 批次间休息
                if batch_end < end_file:
                    print("批次间休息5秒...")
                    await asyncio.sleep(5)
                    
        finally:
            await self.close_browser()
        
        return self.results
    
    def save_results(self, filename="modelscope_sha256.txt"):
        """保存结果到文件"""
        if not self.results:
            print("没有结果可保存")
            return
        
        with open(filename, 'w', encoding='utf-8') as f:
            # 按文件名排序
            sorted_files = sorted(self.results.keys())
            for filename_key in sorted_files:
                sha256 = self.results[filename_key]
                f.write(f"{sha256}  {filename_key}\n")
        
        print(f"结果已保存到: {filename}")
        print(f"成功获取 {len(self.results)} 个文件的SHA256值")

async def main():
    crawler = PlaywrightSHA256Crawler()
    
    print("Playwright SHA256 爬虫启动")
    print("=" * 50)
    
    # 获取全部163个文件
    print("开始获取全部163个文件...")
    results = await crawler.crawl_all_sha256(start_file=1, end_file=163, batch_size=3)
    
    # 保存结果
    crawler.save_results("modelscope_sha256.txt")
    
    # 统计信息
    print("\n" + "=" * 50)
    print("爬取完成统计:")
    print(f"成功: {len(results)} 个文件")
    print(f"失败: {163 - len(results)} 个文件")
    
    if len(results) >= 160:
        print("✅ 获取成功率超过98%，质量很好！")
    elif len(results) >= 150:
        print("⚠️ 获取成功率超过92%，还不错")
    else:
        print("❌ 获取成功率较低，可能需要重试")

if __name__ == "__main__":
    # 运行爬虫
    asyncio.run(main()) 