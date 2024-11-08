#!/bin/bash

# 获取当前工作目录
currentDir=$(pwd)

# 获取脚本所在目录
scriptDir=$(dirname "$0")

# 提示脚本运行目录
echo 运行目录位于：$scriptDir
sleep 2

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
    sleep 2
    
    # 初始化Git仓库
    git init
    if [[ $? -ne 0 ]]; then
        echo "Git 初始化失败"
        exit 1
    fi

    # 添加远程仓库
    git remote add origin "$repo"
    if [[ $? -ne 0 ]]; then
        echo "添加远程仓库失败，可能是 URL 无效"
        exit 1
    fi
fi

# hexo工作流
clear
echo "开始清理缓存"
hexo cl
if [[ $? -ne 0 ]]; then
    echo "清理缓存失败"
    exit 1
fi

clear
echo "开始生成静态文件"
hexo g
if [[ $? -ne 0 ]]; then
    echo "生成静态文件失败"
    exit 1
fi

clear
if [[ -f "gulpfile.js" ]]; then
    echo "找到gulpfile.js，开始压缩html，js，css"
    gulp
    if [[ $? -ne 0 ]]; then
        echo "Gulp 执行失败"
        exit 1
    fi
else
    echo "没有找到gulpfile.js，跳过压缩步骤"
    sleep 2
fi

clear
echo "开始部署静态文件"
hexo d
if [[ $? -ne 0 ]]; then
    echo "部署静态文件失败"
    exit 1
fi

clear
echo "开始备份Hexo源文件到Git标签"

# 检查是否有更改
git status | grep -q "nothing to commit, working tree clean"
if [[ $? -eq 0 ]]; then
    echo "没有更改，跳过提交"
    sleep 2
    clear
    echo "已完成Hexo源文件备份和部署"
    exit 0  # 跳出脚本，避免继续执行
else
    # 排除public文件夹的所有文件
    git add --all
    if [[ $? -ne 0 ]]; then
        echo "Git add 操作失败"
        exit 1
    fi

    # 删除public文件夹，不将其推送
    git reset public
    if [[ $? -ne 0 ]]; then
        echo "Git reset 操作失败"
        exit 1
    fi

    # 提交Hexo源文件
    git commit -m "Backup Hexo Files"
    if [[ $? -ne 0 ]]; then
        echo "Git commit 操作失败"
        exit 1
    fi
fi

# 获取当前系统时间，作为标签名称
timestamp=$(date +%Y%m%d%H%M)

# 创建一个新的标签，用于备份Hexo源文件
git tag "$timestamp"
if [[ $? -ne 0 ]]; then
    echo "创建 Git 标签失败"
    exit 1
fi

# 推送标签到远程仓库
git push origin "$timestamp"
if [[ $? -ne 0 ]]; then
    echo "推送 Git 标签失败"
    exit 1
fi

clear
echo "已完成Hexo源文件备份和部署"

# 切换回原本目录
cd "$currentDir" || exit