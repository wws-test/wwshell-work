#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ModelScope SHA256 爬虫
用于获取 DeepSeek-R1-0528 模型的所有文件SHA256值
"""

import requests
import time
import re
from bs4 import BeautifulSoup
import json
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

class ModelScopeSHA256Crawler:
    def __init__(self):
        self.base_url = "https://modelscope.cn/models/deepseek-ai/DeepSeek-R1-0528/file/view/master"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })
        self.lock = threading.Lock()
        self.results = {}
        
    def get_file_sha256(self, file_number):
        """获取单个文件的SHA256值"""
        filename = f"model-{file_number:05d}-of-000163.safetensors"
        url = f"{self.base_url}/{filename}"
        
        try:
            print(f"正在获取文件 {filename} 的SHA256...")
            
            # 添加重试机制
            for attempt in range(3):
                try:
                    response = self.session.get(url, timeout=30)
                    if response.status_code == 200:
                        break
                    else:
                        print(f"文件 {filename} 获取失败，状态码: {response.status_code}")
                        if attempt < 2:
                            time.sleep(2)
                            continue
                        return None
                except requests.exceptions.RequestException as e:
                    print(f"文件 {filename} 请求异常: {e}")
                    if attempt < 2:
                        time.sleep(2)
                        continue
                    return None
            
            # 解析页面查找SHA256值
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # 查找SHA256值的多种方式
            sha256_value = None
            
            # 方式1: 查找文本中包含SHA256的部分
            sha256_pattern = r'SHA256[:\s]*([a-f0-9]{64})'
            matches = re.findall(sha256_pattern, response.text, re.IGNORECASE)
            if matches:
                sha256_value = matches[0]
            
            # 方式2: 查找特定的HTML元素
            if not sha256_value:
                # 查找可能包含SHA256的div或span
                for element in soup.find_all(['div', 'span', 'td', 'code']):
                    text = element.get_text(strip=True)
                    if re.match(r'^[a-f0-9]{64}$', text):
                        sha256_value = text
                        break
            
            # 方式3: 查找特定的数据属性或JSON
            if not sha256_value:
                scripts = soup.find_all('script')
                for script in scripts:
                    if script.string:
                        json_matches = re.findall(r'"sha256"[:\s]*"([a-f0-9]{64})"', script.string)
                        if json_matches:
                            sha256_value = json_matches[0]
                            break
            
            if sha256_value:
                with self.lock:
                    self.results[filename] = sha256_value
                print(f"✅ {filename}: {sha256_value}")
                return sha256_value
            else:
                print(f"❌ 未找到文件 {filename} 的SHA256值")
                return None
                
        except Exception as e:
            print(f"❌ 处理文件 {filename} 时出错: {e}")
            return None
        
        # 添加延时避免请求过快
        time.sleep(0.5)
    
    def crawl_all_sha256(self, max_workers=5):
        """并发获取所有文件的SHA256值"""
        print("开始爬取ModelScope上的SHA256值...")
        print(f"目标文件数量: 163")
        print(f"并发线程数: {max_workers}")
        print("-" * 50)
        
        # 使用线程池并发处理
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # 提交所有任务
            future_to_number = {
                executor.submit(self.get_file_sha256, i): i 
                for i in range(1, 164)
            }
            
            # 收集结果
            completed = 0
            for future in as_completed(future_to_number):
                completed += 1
                print(f"进度: {completed}/163 ({completed/163*100:.1f}%)")
        
        return self.results
    
    def save_results(self, filename="modelscope_sha256.txt"):
        """保存结果到文件"""
        if not self.results:
            print("没有结果可保存")
            return
        
        with open(filename, 'w', encoding='utf-8') as f:
            # 按文件名排序
            sorted_files = sorted(self.results.keys())
            for filename in sorted_files:
                sha256 = self.results[filename]
                f.write(f"{sha256}  {filename}\n")
        
        print(f"结果已保存到: {filename}")
        print(f"成功获取 {len(self.results)} 个文件的SHA256值")

def main():
    crawler = ModelScopeSHA256Crawler()
    
    print("ModelScope SHA256 爬虫启动")
    print("=" * 50)
    
    # 开始爬取
    results = crawler.crawl_all_sha256()
    
    # 保存结果
    crawler.save_results()
    
    # 统计信息
    print("\n" + "=" * 50)
    print("爬取完成统计:")
    print(f"成功: {len(results)} 个文件")
    print(f"失败: {163 - len(results)} 个文件")
    
    if len(results) < 163:
        print("\n失败的文件:")
        all_files = set(f"model-{i:05d}-of-000163.safetensors" for i in range(1, 164))
        success_files = set(results.keys())
        failed_files = all_files - success_files
        for failed_file in sorted(failed_files):
            print(f"  - {failed_file}")

if __name__ == "__main__":
    main() 