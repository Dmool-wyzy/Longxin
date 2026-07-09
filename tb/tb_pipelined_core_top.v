`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_pipelined_core_top (五级流水线 CPU 系统闭环自检实验室)
// 功能描述：全面测试五级流水线架构：
//   1. 算术连续相关前递 (EX/MEM Forwarding)
//   2. 访存读取与后继计算冲突停顿 (Load-Use Stall + Bubble)
//   3. 分支跳转流水线冲刷 (Branch Flush)
// =========================================================================
module tb_pipelined_core_top();

    reg         clk;
    reg         rst_n;

    // 接口连线
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire        dmem_we;
    wire        dmem_re;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;

    reg [31:0] imem_rom [0:255];
    reg [31:0] dmem_ram [0:255];

    wire [29:0] imem_index = (imem_addr - 32'h1C000000) >> 2;
    assign imem_data = (imem_index < 256) ? imem_rom[imem_index] : 32'h03400000;

    wire [7:0] dmem_index = dmem_addr[9:2];
    assign dmem_rdata = dmem_ram[dmem_index];

    always @(posedge clk) begin
        if (dmem_we) begin
            dmem_ram[dmem_index] <= dmem_wdata;
        end
    end

    // 实例化被测五级流水线 CPU 核心
    pipelined_core_top u_pipe_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_data  (imem_data),
        .dmem_we    (dmem_we),
        .dmem_re    (dmem_re),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata)
    );

    always #5 clk = ~clk;

    integer i;
    initial begin
        $display("=================================================");
        $display("🚀 [龙芯杯备赛] Phase 2 五级流水线 CPU 系统集成闭环测试启动！");
        $display("=================================================");

        for (i = 0; i < 256; i = i + 1) begin
            imem_rom[i] = 32'h03400000; // 默认塞满 NOP
            dmem_ram[i] = 32'h00000000;
        end

        // 预设数据存储器地址 4 的初值为 50
        dmem_ram[1] = 32'd50;

        // 装载流水线严格压力测试程序：
        // [0] 0x1C000000: addi.w $r1, $r0, 10    (# r1 = 10)
        imem_rom[0] = 32'b000010_0000_000000001010_00000_00001;
        // [1] 0x1C000004: addi.w $r2, $r1, 5     (# RAW冒险：紧密使用上一条刚算出的 r1 -> 期望前递得出 r2 = 15)
        imem_rom[1] = 32'b000010_0000_000000000101_00001_00010;
        // [2] 0x1C000008: st.w   $r2, $r0, 8     (# 将刚算出的 r2=15 写入内存地址 8)
        imem_rom[2] = 32'b001011_0000_000000001000_00000_00010;
        // [3] 0x1C00000C: ld.w   $r3, $r0, 4     (# Load：读取内存地址 4 获得 50 存入 r3)
        imem_rom[3] = 32'b001010_0000_000000000100_00000_00011;
        // [4] 0x1C000010: add.w  $r4, $r3, $r1   (# Load-Use冒险：立马使用r3！自动暂停1周期气泡后前递得出 r4=50+10=60)
        imem_rom[4] = 32'b000000_0000_0000000_00001_00011_00100;
        // [5] 0x1C000014: beq    $r1, $r1, 2     (# 成立的分支跳转：跳过指令[6]，执行指令[7])
        imem_rom[5] = 32'b011000_0000000000000010_00001_00001;
        // [6] 0x1C000018: addi.w $r5, $r0, 99    (# 被冲刷气泡代替，不执行，r5 应为 0)
        imem_rom[6] = 32'b000010_0000_000001100011_00000_00101;
        // [7] 0x1C00001C: addi.w $r6, $r0, 88    (# 跳转命中目的地址，正常执行 r6 = 88)
        imem_rom[7] = 32'b000010_0000_000001011000_00000_00110;

        clk   = 0;
        rst_n = 0;
        #15;
        rst_n = 1;

        // 流水线深度为 5，加上冲突停顿和冲刷，执行 18 个时钟周期充足保证写回完毕
        repeat (18) @(posedge clk);

        $display("=================================================");
        $display("📊 五级流水线运行完成！检查最终核心寄存器与访存状态：");
        $display("  $r1 = %0d (预期: 10, 基础立即数加载)", u_pipe_core.u_regfile.regs[1]);
        $display("  $r2 = %0d (预期: 15, EX/MEM RAW 连续前递准确无误)", u_pipe_core.u_regfile.regs[2]);
        $display("  $r3 = %0d (预期: 50, ld.w 正常载入)", u_pipe_core.u_regfile.regs[3]);
        $display("  $r4 = %0d (预期: 60, Load-Use 暂停与前递配合完美)", u_pipe_core.u_regfile.regs[4]);
        $display("  $r5 = %0d (预期: 0,  分支跳转有效冲刷错取气泡)", u_pipe_core.u_regfile.regs[5]);
        $display("  $r6 = %0d (预期: 88, 跳转目标指令顺利落盘写回)", u_pipe_core.u_regfile.regs[6]);
        $display("  MEM[8] = %0d (预期: 15, st.w 前递写入数据内存无差错)", dmem_ram[2]);
        $display("=================================================");

        if (u_pipe_core.u_regfile.regs[1] === 32'd10 &&
            u_pipe_core.u_regfile.regs[2] === 32'd15 &&
            u_pipe_core.u_regfile.regs[3] === 32'd50 &&
            u_pipe_core.u_regfile.regs[4] === 32'd60 &&
            u_pipe_core.u_regfile.regs[5] === 32'd0  &&
            u_pipe_core.u_regfile.regs[6] === 32'd88 &&
            dmem_ram[2] === 32'd15) begin
            $display("🎉🎉🎉 [大获全胜] 工业级五级流水线 CPU 系统集成及冒险处理 100% 完美通过！");
        end else begin
            $display("❌ [测试失败] 流水线相关数据或控制逻辑异常！");
        end
        $display("=================================================");

        #10;
        $finish;
    end

endmodule
