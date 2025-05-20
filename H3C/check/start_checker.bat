@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul

REM 设置标题
title Word文档检查工具

REM 设置颜色
color 0A

:menu
cls
echo =============================================
echo            Word文档检查工具
echo =============================================
echo.
echo  1. 使用默认配置检查文档
echo  2. 使用自定义配置检查文档
echo  3. 查看帮助
echo  4. 退出
echo.
echo =============================================
echo.

set /p choice=请输入选项 (1-4): 

if "%choice%"=="1" goto default_check
if "%choice%"=="2" goto custom_check
if "%choice%"=="3" goto help
if "%choice%"=="4" goto end

echo 无效的选项，请重试！
timeout /t 2 >nul
goto menu

:default_check
cls
start "" "docx_checker.exe" --gui
goto menu

:custom_check
cls
echo 请将配置文件拖拽到此窗口中（或输入完整路径）:
set /p config_path=
if "%config_path%"=="" goto menu
echo.
echo 请将要检查的Word文档拖拽到此窗口中（或输入完整路径）:
set /p doc_path=
if "%doc_path%"=="" goto menu
echo.
echo 正在使用自定义配置检查文档...
docx_checker.exe -c "%config_path%" "%doc_path%"
pause
goto menu

:help
cls
echo =============================================
echo                  使用帮助
echo =============================================
echo.
echo 1. 默认配置检查：
echo    - 使用工具自带的默认配置检查文档
echo    - 适用于标准模板文档的检查
echo.
echo 2. 自定义配置检查：
echo    - 使用自定义的配置文件检查文档
echo    - 配置文件格式请参考 config/default_config.json
echo.
echo 3. 配置文件说明：
echo    - 可以自定义检查的标题、表格和内容规则
echo    - 支持多种检查规则组合
echo    - 详细说明请查看 readme.md
echo.
pause
goto menu

:end
exit
