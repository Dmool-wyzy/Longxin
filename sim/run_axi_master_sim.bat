@echo off
chcp 65001 > nul
echo ===================================================
echo   [龙芯杯备赛] Phase 3 AXI4 Master 协议接口自动化仿真
echo ===================================================

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] 编译 AXI Master RTL 与 Testbench...
call "%VIVADO_BIN%\xvlog.bat" ..\rtl\bus\axi_master_if.v ..\tb\tb_axi_master_if.v
if errorlevel 1 (
    echo [错误] 编译失败！
    exit /b 1
)

echo [2/3] 构建快照...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_axi_master_if -snapshot tb_axi_master_snap
if errorlevel 1 (
    echo [错误] 构建失败！
    exit /b 1
)

echo [3/3] 运行 AXI Master 仿真...
call "%VIVADO_BIN%\xsim.bat" tb_axi_master_snap -R

echo ===================================================
echo   仿真运行结束
echo ===================================================
