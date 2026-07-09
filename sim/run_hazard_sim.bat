@echo off
chcp 65001 > nul
echo ===================================================
echo   [龙芯杯备赛] Phase 2 冒险与前递单元自动化仿真流程
echo ===================================================

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] 正在使用 xvlog 编译 RTL 及测试文件...
call "%VIVADO_BIN%\xvlog.bat" ..\rtl\core\hazard.v ..\tb\tb_hazard.v
if errorlevel 1 (
    echo [错误] RTL 编译失败！
    exit /b 1
)

echo [2/3] 正在使用 xelab 构建仿真快照...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_hazard -snapshot tb_hazard_snap
if errorlevel 1 (
    echo [错误] 仿真快照构建失败！
    exit /b 1
)

echo [3/3] 正在使用 xsim 运行仿真...
call "%VIVADO_BIN%\xsim.bat" tb_hazard_snap -R

echo ===================================================
echo   仿真流程结束
echo ===================================================
