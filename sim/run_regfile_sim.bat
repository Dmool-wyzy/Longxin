@echo off
chcp 65001 >nul
echo =========================================================
echo 🌟 [龙芯杯备赛] 正在一键启动 RegFile 模块 Vivado 命令行仿真...
echo =========================================================

cd /d "%~dp0\.."

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] 正在使用 xvlog 编译 RTL 和 Testbench...
call "%VIVADO_BIN%\xvlog.bat" rtl\core\regfile.v tb\tb_regfile.v
if %errorlevel% neq 0 (
    echo ❌ 编译报错！请检查硬件代码语法。
    pause
    exit /b %errorlevel%
)

echo [2/3] 正在使用 xelab 建立顶层连接与生成仿真快照...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_regfile -snapshot tb_regfile_snap
if %errorlevel% neq 0 (
    echo ❌ Elaborate 连接报错！请检查模块实例化端口。
    pause
    exit /b %errorlevel%
)

echo [3/3] 正在使用 xsim 全速运行仿真测试...
call "%VIVADO_BIN%\xsim.bat" tb_regfile_snap -R

echo =========================================================
echo 🎉 仿真测试全流程结束！
echo =========================================================
pause
