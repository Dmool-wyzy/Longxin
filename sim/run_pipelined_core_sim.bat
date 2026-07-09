@echo off
chcp 65001 > nul
echo ===================================================
echo   [龙芯杯备赛] Phase 2 五级流水线完整 CPU 自动化仿真
echo ===================================================

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] 正在使用 xvlog 编译各个流水段及核心...
call "%VIVADO_BIN%\xvlog.bat" ..\rtl\core\regfile.v ..\rtl\core\alu.v ..\rtl\core\pc.v ..\rtl\core\controller.v ..\rtl\core\imm_gen.v ..\rtl\core\if_id.v ..\rtl\core\id_ex.v ..\rtl\core\ex_mem.v ..\rtl\core\mem_wb.v ..\rtl\core\hazard.v ..\rtl\core\pipelined_core_top.v ..\tb\tb_pipelined_core_top.v
if errorlevel 1 (
    echo [错误] 编译失败！
    exit /b 1
)

echo [2/3] 正在构建仿真快照...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_pipelined_core_top -snapshot tb_pipelined_core_snap
if errorlevel 1 (
    echo [错误] 仿真构建失败！
    exit /b 1
)

echo [3/3] 运行五级流水线架构测试...
call "%VIVADO_BIN%\xsim.bat" tb_pipelined_core_snap -R

echo ===================================================
echo   仿真运行结束
echo ===================================================
