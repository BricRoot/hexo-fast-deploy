#!/bin/bash

# 获取当前工作目录
currentDir=$(pwd)

# 获取脚本所在目录
scriptDir=$(dirname "$0")

# 切换到脚本目录
cd "$scriptDir" || exit

# 检查是否存在 Git 仓库
git rev-parse --is-inside-work-tree > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "脚本目录没有Git仓库，将初始化Git仓库并使用_config.yml中的仓库"
    
    # 获取 _config.yml 中的 repo 配置
    repo=$(grep -i "repo" _config.yml | awk -F ': ' '{print $2}')
    
    if [[ -z "$repo" ]]; then
        echo "无法从_config.yml获取仓库信息，请检查_config.yml中是否包含repo配置"
        exit 1
    fi
    
    echo "使用_config.yml中的仓库地址$repo"
    
    # 初始化 Git 仓库
    git init
    git remote add origin "$repo"
    
    # 获取 _config.yml 中的 branch 配置
    branch=$(grep -i "branch" _config.yml | awk -F ': ' '{print $2}')
    
    # 创建并切换到指定分支
    git checkout -b "$branch"
fi

# hexo工作流
clear
echo "开始清理缓存"
hexo cl

clear
echo "开始生成静态文件"
hexo g

clear
if [[ -f "gulpfile.js" ]]; then
    echo "找到gulpfile.js，开始压缩html，js，css"
    gulp
else
    echo "没有找到gulpfile.js，跳过压缩步骤"
    sleep 2
fi

clear
echo "开始推送静态文件到远程仓库"
hexo d

# hexo程序备份远程仓库工作流
clear
git fetch -p

# 获取 _config.yml中的branch配置
branch=$(grep -i "branch" _config.yml | awk -F ': ' '{print $2}')
echo "开始检查仓库是否超过7个分支（除了$branch）"
count=0

# 计算远程分支数量，排除配置的branch
branches=$(git branch -r --sort=committerdate | grep -v "$branch")
for b in $branches; do
    ((count++))
done

# 如果远程分支超过6个，则删除最久远的分支，保留6个（除了配置的branch）
if [[ $count -gt 6 ]]; then
    echo "远程备份分支超过7个，删除最久远的分支"
    count=0
    for b in $branches; do
        branch=${b#origin/}
        if [[ "$branch" != "$branch" ]]; then
            echo "即将删除远程备份分支: $branch"
            git push origin --delete "$branch"
            echo "远程备份分支$branch已被删除"
            
            # 删除本地分支
            echo "即将删除本地备份分支: $branch"
            git branch -D "$branch"
            echo "本地备份分支$branch已被删除"
        fi
        
        ((count++))
        if [[ $count -ge 6 ]]; then
            break
        fi
    done
fi

# 获取当前系统时间
timestamp=$(date +%Y%m%d%H%M)

# 创建一个新的分支，用于推送 Hexo 源代码
git checkout -b "$timestamp"

# 提交源代码更改，没有提交信息
git add .
git commit -m "new files"

# 推送到 GitHub 仓库
git push origin "$timestamp"

echo "已经完成部署和备份"

# 切换回原本目录
cd "$currentDir" || exit