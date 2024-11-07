@echo off
chcp 65001

:: 获取当前工作目录
set currentDir=%cd%

:: 获取脚本所在目录
set scriptDir=%~dp0

:: 切换到脚本目录
cd /d %scriptDir%

:: 检查是否存在 Git 仓库
git rev-parse --is-inside-work-tree >nul 2>&1
if %errorlevel% neq 0 (
    echo 脚本目录没有Git仓库，请确保您在Git仓库目录下运行此脚本。
    exit /b
)

:: hexo工作流
cls
echo 开始清理缓存
call hexo cl

cls
echo 开始生成静态文件
call hexo g

cls
if exist "gulpfile.js" (
    echo 找到 gulpfile.js，开始压缩html，js，css
    call gulp
) else (
    echo 没有找到 gulpfile.js，跳过压缩步骤
    timeout /t 2 /nobreak >nul
)

cls
echo 开始推送静态文件到远程仓库
call hexo d

:: hexo程序备份远程仓库工作流
cls
git fetch -p
:: 获取_config.yml中的branch配置
for /f "delims=" %%i in ('findstr /i "branch" _config.yml') do set branch=%%i
:: 提取"branch"配置中的分支名称（去除多余的空格和冒号）
set branch=%branch:*: =%
echo 开始检查仓库是否超过七个分支（除了%branch%）
set count=0

:: 计算远程分支数量，排除配置的branch
for /f "delims=" %%b in ('git branch -r --sort=committerdate ^| findstr /v "%branch%"') do (
    set /a count+=1
)

:: 获取所有远程分支，排除配置的branch
setlocal enabledelayedexpansion
set count=0
set branches= 
for /f "delims=" %%b in ('git branch -r --sort=committerdate ^| findstr /v "%branch%"') do (
    set /a count+=1
    set branch=%%b
    set branch=!branch:origin/=!
    set branches=!branches!!branch! 
)

:: 如果远程分支超过 7 个，则删除最久远的分支，保留 7 个（除了配置的branch）
if %count% gtr 7 (
    echo 远程分支超过 7 个，删除最久远的分支

    :: 获取所有远程分支（按时间排序），排除配置的branch
    for /f "delims=" %%b in ('git branch -r --sort=committerdate ^| findstr /v "%branch%"') do (
        set branch=%%b
        set branch=!branch:origin/=!
        if /i not "!branch!"=="%branch%" (
            echo 即将删除远程分支: !branch!
            git push origin --delete !branch!
            echo 远程分支 !branch! 已被删除

            :: 删除本地分支
            echo 即将删除本地分支: !branch!
            git branch -d !branch!
            echo 本地分支 !branch! 已被删除
             
            :: 只保留 7 个分支，删除超过的
            set /a count-=1
            if !count! leq 7 (
                goto :doneDeleting
            )
        )
    )
)

:doneDeleting
endlocal

:: 获取当前系统时间
for /f "tokens=2 delims==" %%a in ('wmic path win32_operatingsystem get LocalDateTime /value') do (set t=%%a)
set timestamp=%t:~0,4%%t:~4,2%%t:~6,2%%t:~8,2%%t:~10,2%

:: 创建一个新的分支，用于推送 Hexo 源代码
git checkout -b %timestamp%

:: 提交源代码更改，没有提交信息
git add .
git commit -m "new files"

:: 推送到 GitHub 仓库
git push origin %timestamp%

:: 切换回原本目录
cd /d %currentDir%
echo 已经完成部署和备份