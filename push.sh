#!/bin/bash

# 开启错误检查，确保任何命令失败时脚本都立即退出
set -e

# 获取当前工作目录
currentDir=$(pwd)

# 获取脚本所在目录
scriptDir=$(dirname "$0")

# 提示脚本运行目录
echo "脚本目录位于：$scriptDir"
sleep 2

# 切换到脚本目录
cd "$scriptDir" || { echo -e "无法切换到脚本目录: \n$scriptDir"; exit 1; }

# 获取_config.yml中的repo和branch配置
repo=$(grep -i "repo" _config.yml 2>/dev/null | awk -F ': ' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
branch=$(grep -i "branch" _config.yml 2>/dev/null | awk -F ': ' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')

# 检查repo和branch的有效性
if [[ -z "$repo" && -z "$branch" ]]; then
    echo -e "无法从_config.yml获取仓库链接和分支配置，请检查_config.yml是否存在，是否正确配置_config.yml文件中的'repo'和'branch'字段"
    exit 1
elif [[ -z "$repo" ]]; then
    echo -e "无法从_config.yml获取仓库链接，请检查是否正确配置_config.yml文件中的'repo'字段"
    exit 1
elif [[ -z "$branch" ]]; then
    echo -e "无法从_config.yml获取分支，请检查是否正确配置_config.yml文件中的'branch'字段"
    exit 1
fi

# 检查目录是否存在Git仓库
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || {
    echo -e "脚本目录没有Git仓库，将初始化Git仓库并使用_config.yml中的仓库"
    sleep 2
    
    # 初始化Git仓库
    git init 2>&1 | grep -i "fatal" && { echo -e "Git 初始化失败，具体错误：\n$(git init 2>&1)"; exit 1; }

    # 添加远程仓库
    git remote add origin "$repo" 2>&1 | grep -i "fatal" && { echo -e "添加远程仓库失败，具体错误：\n$(git remote add origin "$repo" 2>&1)"; exit 1; }
}

# hexo工作流
clear
echo "开始清理缓存"
hexo cl 2>&1 | grep -i "error" && { echo -e "清理缓存失败，具体错误：\n$(hexo cl 2>&1)"; exit 1; }

clear
echo "开始生成静态文件"
hexo g 2>&1 | grep -i "error" && { echo -e "生成静态文件失败，具体错误：\n$(hexo g 2>&1)"; exit 1; }

clear
if [[ -f "gulpfile.js" ]]; then
    echo "找到gulpfile.js，开始压缩html，js，css"
    gulp 2>&1 | grep -i "error" && { echo -e "Gulp执行失败，具体错误：\n$(gulp 2>&1)"; exit 1; }
else
    echo "没有找到gulpfile.js，跳过压缩步骤"
    sleep 2
fi

clear
echo "开始部署静态文件"
hexo d 2>&1 | grep -i "error" && { echo -e "部署静态文件失败，具体错误：\n$(hexo d 2>&1)"; exit 1; }

clear
echo "开始备份Hexo源文件到Git标签"

# 检查是否有更改
git status | grep -q "nothing to commit, working tree clean" && {
    echo "没有更改，跳过提交"
    sleep 2
    clear
    echo "已完成Hexo源文件备份和部署"
    exit 0
}

# 排除public文件夹的所有文件
git add --all 2>&1 | grep -i "error" && { echo -e "Git add操作失败，具体错误：\n$(git add --all 2>&1)"; exit 1; }

# 删除public文件夹，不将其推送
git reset public 2>&1 | grep -i "error" && { echo -e "Git reset操作失败，具体错误：\n$(git reset public 2>&1)"; exit 1; }

# 提交Hexo源文件
git commit -m "Backup Hexo Files" 2>&1 | grep -i "error" && { echo -e "Git commit操作失败，具体错误：\n$(git commit -m 'Backup Hexo Files' 2>&1)"; exit 1; }

# 获取当前系统时间，作为标签名称
timestamp=$(date +%Y%m%d%H%M)

# 创建一个新的标签，用于备份Hexo源文件
git tag "$timestamp" 2>&1 | grep -i "fatal" && { echo -e "创建Git标签失败，具体错误：\n$(git tag "$timestamp" 2>&1)"; exit 1; }

# 推送标签到远程仓库
git push origin "$timestamp" 2>&1 | grep -i "fatal" && { echo -e "推送Git标签失败，具体错误：\n$(git push origin "$timestamp" 2>&1)"; exit 1; }

clear
echo "已完成Hexo源文件备份和部署"

# 切换回原本目录
cd "$currentDir" || { echo -e "无法切换回原本目录: $currentDir"; exit 1; }

exit 0