#!/bin/bash

get_commit_records() {
  local branch=$1
  local start_date=$(date -d "-30 days" +%Y-%m-%d)
  git rev-list --since="$start_date" --count $branch
}

get_affected_files_and_loc() {
  local commit=$1
  git diff --numstat $commit | awk '{ files+=$1; loc+=$1+$2 } END { print files, loc }'
}

read -p "请输入代码仓库的链接（按回车使用默认值）: " repository_url
repository_url=${repository_url:-http://git.git}
read -p "请输入要统计的分支名称: " branch

# 克隆代码仓库到临时目录
git clone $repository_url temp_repository
cd temp_repository

# 切换到指定分支
git checkout $branch

# 获取最近30天的提交记录
commit_records=$(get_commit_records $branch)

total_files=0
total_loc=0
total_commits=0

# 遍历每个提交，并计算受影响的文件数、代码行数和提交数量
for commit in $commit_records; do
  read files loc < <(get_affected_files_and_loc $commit)
  total_files=$((total_files + files))
  total_loc=$((total_loc + loc))
  total_commits=$((total_commits + 1))
done

echo "Total files affected in the last 30 days: $total_files"
echo "Total lines of code affected in the last 30 days: $total_loc"
echo "Total commits in the last 30 days: $total_commits"

# 删除临时克隆的仓库
cd ..
rm -rf temp_repository