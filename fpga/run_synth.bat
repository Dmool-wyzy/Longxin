@echo off
echo =========================================================
echo   [LoongArch Cup] Phase 4: FPGA Hardware Synthesis Flow
echo =========================================================

set VIVADO_BIN=D:\Xilinx\Vivado\2022.2\bin

if not exist "%VIVADO_BIN%\vivado.bat" (
    echo [ERROR] Vivado binary not found at %VIVADO_BIN%
    echo Please modify run_synth.bat with your Vivado installation path.
    exit /b 1
)

call "%VIVADO_BIN%\vivado.bat" -mode batch -source run_vivado_synth.tcl

echo.
echo =========================================================
echo   Synthesis Flow Completed. Check timing_summary_synth.rpt
echo =========================================================
