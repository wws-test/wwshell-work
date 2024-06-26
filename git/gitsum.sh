#!/bin/bash

read -p "请输入代码仓库的链接（按回车使用默认值）: " repository_url
repository_url=${repository_url:-http://vdgitlab.das-security.cn/ailpha_jgtsgz/bigdata-web-backend.git}
read -p "请输入要统计的分支名称（按回车使用默认值 ailpha/qu/dev）: " branch
branch=${branch:-ailpha/qu/dev}
read -p "请输入要统计的天数（按回车使用默认值 30）: " days
days=${days:-30}

total_files=0
total_loc=0
total_commits=0
total_modifications=0

# 克隆代码仓库到临时目录
git clone $repository_url temp_repository
cd temp_repository

# 切换到指定分支
git checkout $branch

# 获取指定天数的提交记录
start_date=$(date -d "-$days days" +%Y-%m-%d)
commits=$(git rev-list --since="$start_date" $branch | tail -1)

# 遍历每个提交，并计算受影响的文件数、受影响的代码行数和提交数量
for commit in $commits; do
  files=$(git diff --name-only $commit | wc -l)
  add_loc=$(git diff --shortstat $commit | awk -F ',' '{print $2}')
  del_loc=$(git diff --shortstat $commit | awk -F ',' '{print $3}')
  total_files=$((total_files + files))
  total_commits=$(git rev-list --since="$start_date" $branch | wc -l)
done

echo "Total files affected in the last $days days: $total_files"
echo "Total ADD lines of code affected in the last $days days: $add_loc"
echo "Total DEL lines of code affected in the last $days days: $del_loc"
echo "Total commits in the last $days days: $total_commits"

# 删除临时克隆的仓库
cd ..
rm -rf temp_repository
