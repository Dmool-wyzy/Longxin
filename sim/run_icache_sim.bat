@echo off
chcp 65001 > nul
echo ===================================================
echo   [龙芯杯备赛] Phase 3 L1 I-Cache 缓存单元自动化仿真
echo ===================================================

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] 编译 I-Cache RTL 与 Testbench...
call "%VIVADO_BIN%\xvlog.bat" ..\rtl\cache\icache.v ..\tb\tb_icache.v
if errorlevel 1 (
    echo [错误] 编译失败！
    exit /b 1
)

echo [2/3] 构建快照...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_icache -snapshot tb_icache_snap
if errorlevel 1 (
    echo [错误] 构建失败！
    exit /b 1
)

echo [3/3] 运行 I-Cache 仿真...
call "%VIVADO_BIN%\xsim.bat" tb_icache_snap -R

echo ===================================================
echo   仿真运行结束
echo ===================================================
