@echo off
@chcp 65001 >nul
setlocal
echo =========================================================
echo [LoongArch SoC] Starting Vivado Simulation for Single-Cycle CPU Core...
echo =========================================================

REM Switch to the sim directory so all temporary logs and xsim.dir stay in sim/
cd /d "%~dp0"

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

echo [1/3] Compiling RTL and Testbench with xvlog...
call "%VIVADO_BIN%\xvlog.bat" ..\rtl\core\regfile.v ..\rtl\core\alu.v ..\rtl\core\pc.v ..\rtl\core\controller.v ..\rtl\core\imm_gen.v ..\rtl\core\core_top.v ..\tb\tb_core_top.v
if errorlevel 1 (
    echo [ERROR] xvlog compilation failed! Please check syntax.
    pause
    exit /b 1
)

echo [2/3] Elaborating top module with xelab...
call "%VIVADO_BIN%\xelab.bat" -debug typical -top tb_core_top -snapshot tb_core_top_snap
if errorlevel 1 (
    echo [ERROR] xelab elaboration failed! Please check module instantiation.
    pause
    exit /b 1
)

echo [3/3] Running simulation with xsim...
call "%VIVADO_BIN%\xsim.bat" tb_core_top_snap -R

echo =========================================================
echo [SUCCESS] Simulation completed!
echo =========================================================
pause
endlocal
