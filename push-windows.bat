@echo off
setlocal enabledelayedexpansion

:: 设置字符编码为UTF-8，避免中文乱码
chcp 65001

:: 获取当前工作目录
set currentDir=%cd%

:: 获取脚本所在目录
set scriptDir=%~dp0

:: 切换到脚本目录
cd /d %scriptDir%

:: 获取_config.yml中的repo和branch配置
for /f "delims=" %%i in ('findstr /i "repo" _config.yml') do set repo=%%i
set repo=%repo:*: =%
for /f "delims=" %%i in ('findstr /i "branch" _config.yml') do set branch=%%i
set branch=%branch:*: =%

:: 检查repo和branch是否有效
if "%repo%"=="" (
    echo 无法从_config.yml获取repo配置，请检查配置
    exit /b 1
)

if "%branch%"=="" (
    echo 无法从_config.yml获取branch配置，请检查配置
    exit /b 1
)

:: 检查是否存在 Git 仓库
git rev-parse --is-inside-work-tree >nul 2>&1
if %errorlevel% neq 0 (
    echo 脚本目录没有Git仓库，将初始化Git仓库并使用_config.yml中的仓库
    
    :: 获取_config.yml中的repo配置
    for /f "delims=" %%i in ('findstr /i "repo" _config.yml') do set repo=%%i
    
    if not defined repo (
        echo 无法从_config.yml获取仓库信息，请检查_config.yml中是否包含repo配置
        exit /b
    )

    echo 使用_config.yml中的仓库地址%repo%
    
    :: 初始化Git仓库
    git init
    git remote add origin %repo%
    
    :: 创建并切换到指定分支
    git checkout -b %branch%
)

:: hexo工作流
cls
echo 开始清理缓存
call hexo cl

cls
echo 开始生成静态文件
call hexo g

cls
if exist gulpfile.js (
    echo 找到gulpfile.js，开始压缩html，js，css
    call gulp
) else (
    echo 没有找到gulpfile.js，跳过压缩步骤
    timeout /t 2 /nobreak >nul
)

cls
echo 开始部署静态文件到远程仓库
call hexo d

cls
echo 开始备份Hexo源文件到Git标签

:: 排除public文件夹的所有文件
git add --all

:: 删除public文件夹，不将其推送
git reset public

:: 提交Hexo源文件
git commit -m "Backup Hexo Files"

:: 获取当前系统时间，作为标签名称
for /f "tokens=2 delims==" %%a in ('wmic path win32_operatingsystem get LocalDateTime /value') do (set t=%%a)
set timestamp=%t:~0,4%%t:~4,2%%t:~6,2%%t:~8,2%%t:~10,2%

:: 创建一个新的标签，用于备份Hexo源文件
git tag %timestamp%

:: 推送标签到远程仓库
git push origin %timestamp%

echo 已完成Hexo源文件备份和部署

:: 切换回原本目录
cd /d %currentDir%
