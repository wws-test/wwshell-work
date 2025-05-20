@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul
title Word文档规范检查工具安装程序
color 0A

echo ========================================
echo         Word文档规范检查工具安装程序
echo ========================================
echo.

REM 设置Python Scripts目录到PATH
for /f "tokens=*" %%i in ('python -c "import sys; print(sys.prefix)"') do set PYTHON_HOME=%%i
set PATH=%PATH%;%PYTHON_HOME%\Scripts;%USERPROFILE%\AppData\Roaming\Python\Python311\Scripts

REM 显示安装信息
echo 欢迎使用Word文档规范检查工具安装程序！
echo.
echo 本程序将帮助您完成以下步骤：
echo  1. 检查系统环境
echo  2. 安装必要的依赖
echo  3. 生成可执行程序
echo.
echo 注意：安装过程可能需要几分钟时间，请耐心等待。
echo.
pause

REM 运行清理脚本
echo 清理旧版本...
call clean.bat

REM 设置pip源为国内镜像
echo 配置pip镜像源...
set PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
set PIP_TRUSTED_HOST=mirrors.aliyun.com

REM 确保Python环境正确
echo 检查Python环境...
python --version > nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到Python，请确保已安装Python 3.7或更高版本。
    pause
    exit /b 1
)

REM 检查是否以管理员权限运行
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] 当前不是管理员权限运行
    echo 某些操作可能需要管理员权限，建议右键以管理员身份运行此脚本
    echo.
    choice /C YN /M "是否继续安装？(Y=是, N=否)"
    if errorlevel 2 exit /b 1
)

REM 尝试更新pip（但不强制要求成功）
echo 尝试更新pip...
python -m pip install --upgrade pip --user 2>nul
if %errorlevel% neq 0 (
    echo [提示] pip更新失败，继续使用当前版本
) else (
    echo [成功] pip更新完成
)

REM 安装依赖
echo.
echo 安装依赖包...
python -m pip install -r requirements.txt --user
if %errorlevel% neq 0 (
    echo [错误] 安装依赖包失败
    echo 请尝试以管理员身份运行此脚本
    pause
    exit /b 1
)

REM 执行打包
echo.
echo 开始打包程序...
python build.py
if %errorlevel% neq 0 (
    echo [错误] 打包失败
    pause
    exit /b 1
)

echo.
echo ========================================
echo 安装和打包完成！
echo ========================================
echo.

echo.
echo 安装完成！
echo.
echo 程序已生成在 dist 目录下，双击 docx_checker.exe 即可运行。
echo.
echo 祝您使用愉快！
echo ========================================
echo.

pause
