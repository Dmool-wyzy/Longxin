@echo off
echo ===================================================
echo   [LoongArch Cup] Phase 4 FPGA Top Simulation
echo ===================================================

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] Compiling FPGA Top and Submodules...
call "%VIVADO_BIN%\xvlog.bat" ..\rtl\core\pc.v ..\rtl\core\if_id.v ..\rtl\core\controller.v ..\rtl\core\imm_gen.v ..\rtl\core\regfile.v ..\rtl\core\id_ex.v ..\rtl\core\alu.v ..\rtl\core\ex_mem.v ..\rtl\core\mem_wb.v ..\rtl\core\hazard.v ..\rtl\core\pipelined_core_top.v ..\rtl\cache\icache.v ..\rtl\cache\dcache.v ..\rtl\bus\axi_master_if.v ..\rtl\soc\axi_ram_uart.v ..\rtl\soc\longxin_soc_top.v ..\rtl\soc\soc_fpga_top.v ..\tb\tb_soc_fpga_top.v
if errorlevel 1 (
    echo [ERROR] Compilation failed!
    exit /b 1
)

echo [2/3] Elaborating snapshot...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_soc_fpga_top -snapshot tb_soc_fpga_snap
if errorlevel 1 (
    echo [ERROR] Elaboration failed!
    exit /b 1
)

echo [3/3] Running FPGA Top Simulation...
call "%VIVADO_BIN%\xsim.bat" tb_soc_fpga_snap -R

echo ===================================================
echo   FPGA Top Simulation Completed
echo ===================================================
