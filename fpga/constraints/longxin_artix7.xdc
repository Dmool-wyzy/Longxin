# =========================================================================
# 龙芯杯大赛 (LoongArch Cup) Phase 4: FPGA 物理约束与时序时钟约束定义
# 目标芯片平台：Xilinx Artix-7 (XC7A100T-CSG324-1 / XC7A35T)
# =========================================================================

# 1. 物理主频时钟时序约束 (50MHz 系统主频，目标周期 20.000ns)
create_clock -period 20.000 -name sys_clk_pin -waveform {0.000 10.000} [get_ports clk_50m]

# 管脚绑定：板载时钟晶振输入
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports clk_50m]

# 2. 异步低电平物理按键复位 (btn_reset_n)
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports btn_reset_n]
# 异步复位输入设为 false_path (因为片内有异步复位、同步释放两级同步电路)
set_false_path -from [get_ports btn_reset_n]

# 3. RS232 / USB-UART TX 物理串口输出端口
set_property -dict { PACKAGE_PIN D4  IOSTANDARD LVCMOS33 } [get_ports uart_tx]

# 4. 板载 8 位状态指示灯与跑分监控 LED
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]

# 5. 组合逻辑与时序收敛策略配置 (优化 WNS)
# 对跨层互联信号与高速缓存数据总线开启组合重优化
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
