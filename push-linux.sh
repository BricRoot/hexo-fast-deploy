#!/bin/bash

# 获取当前工作目录
currentDir=$(pwd)

# 获取脚本所在目录
scriptDir=$(dirname "$0")

# 切换到脚本目录
cd "$scriptDir" || exit

# 获取_config.yml中的repo和branch配置
repo=$(grep -i "repo" _config.yml | awk -F ': ' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
branch=$(grep -i "branch" _config.yml | awk -F ': ' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')

# 检查repo和branch是否有效
if [[ -z "$repo" || -z "$branch" ]]; then
    echo "无法从_config.yml获取repo或branch配置，请检查配置"
    exit 1
fi

# 检查目录是否存在Git仓库
git rev-parse --is-inside-work-tree > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "脚本目录没有Git仓库，将初始化Git仓库并使用_config.yml中的仓库"
    
    # 初始化Git仓库
    git init
    git remote add origin "$repo"
    
    # 强制提交一个空提交
    git commit --allow-empty -m "Initial empty commit"
    
    # 推送初始提交到远程仓库的指定分支
    git push -u origin "$branch"
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
echo "开始备份Hexo源文件到Git标签"

# 排除public文件夹的所有文件
git add --all

# 删除public文件夹，不将其推送
git reset public

# 提交Hexo源文件
git commit -m "Backup Hexo Flies"

# 获取当前系统时间，作为标签名称
timestamp=$(date +%Y%m%d%H%M)

# 创建一个新的标签，用于备份Hexo源文件
git tag "$timestamp"

# 推送标签到远程仓库
git push origin "$timestamp"

clear
echo "已完成Hexo源文件备份和部署"

# 切换回原本目录
cd "$currentDir" || exit