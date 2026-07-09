@echo off
chcp 65001 > nul
echo ===================================================
echo   [龙芯杯备赛] Phase 3 L1 D-Cache 缓存单元自动化仿真
echo ===================================================

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] 编译 D-Cache RTL 与 Testbench...
call "%VIVADO_BIN%\xvlog.bat" ..\rtl\cache\dcache.v ..\tb\tb_dcache.v
if errorlevel 1 (
    echo [错误] 编译失败！
    exit /b 1
)

echo [2/3] 构建快照...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_dcache -snapshot tb_dcache_snap
if errorlevel 1 (
    echo [错误] 构建失败！
    exit /b 1
)

echo [3/3] 运行 D-Cache 仿真...
call "%VIVADO_BIN%\xsim.bat" tb_dcache_snap -R

echo ===================================================
echo   仿真运行结束
echo ===================================================
