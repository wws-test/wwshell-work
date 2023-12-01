#!/bin/bash

read -p "请输入代码仓库的链接（按回车使用默认值）: " repository_url
repository_url=${repository_url:-http://git.git}
read -p "请输入要统计的tag名称: " tag
total_files=0
total_loc=0

# 克隆代码仓库到临时目录
git clone $repository_url temp_repository
cd temp_repository

# 获取某个tag之后的所有提交记录
commits=$(git log $tag.. --format="%H")

# 遍历每个提交，并计算受影响的文件数和代码行数
for commit in $commits; do
  files=$(git diff --name-only $commit | wc -l)
  loc=$(git diff --shortstat $commit | awk '{print $1}')
  total_files=$((total_files + files))
  total_loc=$((total_loc + loc))
done

echo "Total files affected: $total_files"
echo "Total lines of code affected: $total_loc"

# 删除临时克隆的仓库
cd ..
rm -rf temp_repository