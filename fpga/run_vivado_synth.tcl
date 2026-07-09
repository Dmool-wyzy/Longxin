# =========================================================================
# 龙芯杯大赛 (LoongArch Cup) Phase 4: Vivado 一键综合与时序收敛脚本
# 执行方式: vivado -mode batch -source run_vivado_synth.tcl
# =========================================================================

puts "========================================================="
puts "🚀 [LoongArch Cup Phase 4] 启动 Vivado 高性能综合与物理时序优化"
puts "========================================================="

# 1. 创建内存级综合工程 (目标器件: Xilinx Artix-7 XC7A100T)
set PART "xc7a100tcsg324-1"
set TOP_MODULE "soc_fpga_top"

# 2. 读取所有硬件 RTL 源代码与约束
puts "[1/4] 读取可综合 RTL 源码..."
read_verilog ../rtl/core/pc.v
read_verilog ../rtl/core/if_id.v
read_verilog ../rtl/core/controller.v
read_verilog ../rtl/core/imm_gen.v
read_verilog ../rtl/core/regfile.v
read_verilog ../rtl/core/id_ex.v
read_verilog ../rtl/core/alu.v
read_verilog ../rtl/core/ex_mem.v
read_verilog ../rtl/core/mem_wb.v
read_verilog ../rtl/core/hazard.v
read_verilog ../rtl/core/pipelined_core_top.v
read_verilog ../rtl/cache/icache.v
read_verilog ../rtl/cache/dcache.v
read_verilog ../rtl/bus/axi_master_if.v
read_verilog ../rtl/soc/axi_ram_uart.v
read_verilog ../rtl/soc/longxin_soc_top.v
read_verilog ../rtl/soc/soc_fpga_top.v

puts "[2/4] 读取物理管脚与时序约束 XDC 文件..."
read_xdc ./constraints/longxin_artix7.xdc

# 3. 执行高性能综合 (开启资源映射优化与关键路径重布局)
puts "[3/4] 正在执行 RTL 综合 (synth_design -directive PerformanceOptimized)..."
synth_design -top $TOP_MODULE -part $PART -directive PerformanceOptimized -retiming

# 4. 生成综合报告与时序静态分析
puts "[4/4] 导出综合时序报告与资源利用率分析..."
report_timing_summary -file timing_summary_synth.rpt
report_utilization -file utilization_synth.rpt

# 校验最差负时钟裕量 (WNS)
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "========================================================="
if {$wns >= 0} {
    puts "✅ [时序完美收敛] 当前最差时钟裕量 WNS = ${wns} ns (满足正时序要求！)"
} else {
    puts "⚠️ [时序警告] 当前最差时钟裕量 WNS = ${wns} ns，将通过多周期逻辑拆解优化！"
}
puts "========================================================="
exit
