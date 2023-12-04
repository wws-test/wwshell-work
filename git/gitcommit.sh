#!/bin/bash

repositories=("http://git.git1" "http://git.git2" "http://git.git3")
branch="ailpha/qu/dev"
total_files=0
total_lines_added=0

total_commits=0

for repository_url in "${repositories[@]}"; do
  # 克隆代码仓库到临时目录
  git clone "$repository_url" temp_repository
  cd temp_repository

  # 切换到指定分支
  git checkout "$branch"

  # 获取最近30天的提交记录
  start_date=$(date -d "-30 days" +%Y-%m-%d)
  commits=$(git rev-list --since="$start_date" "$branch")

  # 遍历每个提交，并计算受影响的文件数、新增行数、修改行数和提交数量
  for commit in $commits; do
    files=$(git diff --name-only "$commit" | wc -l)
    lines_added=$(git diff --shortstat $commit | awk '{print $4}')
    total_files=$((total_files + files))
    total_lines_added=$((total_lines_added + lines_added))
    total_commits=$((total_commits + 1))
  done

  # 删除临时克隆的仓库
  cd ..
  rm -rf temp_repository
done

echo "Total files affected in the last 30 days: $total_files"
echo "Total lines added in the last 30 days: $total_lines_added"
echo "Total commits in the last 30 days: $total_commits"