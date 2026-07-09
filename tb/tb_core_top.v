`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_core_top (单周期 CPU 系统集成闭环验证实验室)
// 功能描述：集成 core_top，并配备指令存储器 (I-Mem) 与数据存储器 (D-Mem)，
//          运行一套包含加法、访存读写、条件跳转的分支程序，全程自检验证 CPU 正确性。
// =========================================================================
module tb_core_top();

    reg         clk;
    reg         rst_n;

    // CPU 接口连线
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire        dmem_we;
    wire        dmem_re;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;

    // 简易指令 ROM (1024 字节 / 256 字)
    reg [31:0] imem_rom [0:255];

    // 简易数据 RAM (1024 字节 / 256 字)
    reg [31:0] dmem_ram [0:255];

    // ROM 读取指令 (基于 0x1C000000 基址偏移)
    wire [29:0] imem_index = (imem_addr - 32'h1C000000) >> 2;
    assign imem_data = (imem_index < 256) ? imem_rom[imem_index] : 32'h00000000;

    // RAM 读取与同步写入 (按字寻址)
    wire [7:0] dmem_index = dmem_addr[9:2];
    assign dmem_rdata = dmem_ram[dmem_index];

    always @(posedge clk) begin
        if (dmem_we) begin
            dmem_ram[dmem_index] <= dmem_wdata;
        end
    end

    // 实例化被测单周期 CPU 核心
    core_top u_core_top (
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

    // 时钟生成：10ns 周期 (100MHz)
    always #5 clk = ~clk;

    integer i;
    initial begin
        $display("=================================================");
        $display("🌟 [龙芯杯备赛] 单周期完整 CPU 系统集成闭环测试启动！");
        $display("=================================================");

        // 初始化存储器
        for (i = 0; i < 256; i = i + 1) begin
            imem_rom[i] = 32'h00000000;
            dmem_ram[i] = 32'h00000000;
        end

        // 装载内嵌测试汇编程序（32位严格指令编码）：
        // [0] 0x1C000000: addi.w $r1, $r0, 10    (# r1 = 10) -> 6+4+12+5+5=32b
        imem_rom[0] = 32'b000010_0000_000000001010_00000_00001;
        // [1] 0x1C000004: addi.w $r2, $r0, 20    (# r2 = 20)
        imem_rom[1] = 32'b000010_0000_000000010100_00000_00010;
        // [2] 0x1C000008: add.w  $r3, $r1, $r2   (# r3 = r1 + r2 = 30) -> 6+4+7+5+5+5=32b
        imem_rom[2] = 32'b000000_0000_0000000_00010_00001_00011;
        // [3] 0x1C00000C: st.w   $r3, $r0, 4     (# 将 r3(30) 写入 dmem 地址 4) -> 6+4+12+5+5=32b
        imem_rom[3] = 32'b001011_0000_000000000100_00000_00011;
        // [4] 0x1C000010: ld.w   $r4, $r0, 4     (# 从 dmem 地址 4 读取到 r4 = 30)
        imem_rom[4] = 32'b001010_0000_000000000100_00000_00100;
        // [5] 0x1C000014: beq    $r3, $r4, 2     (# 如果 r3==r4，跳转偏移 +2字 = 跳过指令[6]) -> 6+16+5+5=32b
        imem_rom[5] = 32'b011000_0000000000000010_00011_00100;
        // [6] 0x1C000018: addi.w $r5, $r0, 99    (# 被跳过，不执行，r5 保持为 0)
        imem_rom[6] = 32'b000010_0000_000001100011_00000_00101;
        // [7] 0x1C00001C: addi.w $r6, $r0, 88    (# 跳转命中目标，执行 r6 = 88)
        imem_rom[7] = 32'b000010_0000_000001011000_00000_00110;

        clk   = 0;
        rst_n = 0;
        #15;
        rst_n = 1;

        // 让 CPU 自主执行 12 个时钟周期
        repeat (12) @(posedge clk);

        $display("=================================================");
        $display("📊 CPU 运行完成！检查核心寄存器最终值：");
        $display("  $r1 = %0d (预期: 10)", u_core_top.u_regfile.regs[1]);
        $display("  $r2 = %0d (预期: 20)", u_core_top.u_regfile.regs[2]);
        $display("  $r3 = %0d (预期: 30)", u_core_top.u_regfile.regs[3]);
        $display("  $r4 = %0d (预期: 30)", u_core_top.u_regfile.regs[4]);
        $display("  $r5 = %0d (预期: 0, 被 BEQ 正确跳过)", u_core_top.u_regfile.regs[5]);
        $display("  $r6 = %0d (预期: 88, 跳转目标执行成功)", u_core_top.u_regfile.regs[6]);
        $display("  MEM[4] = %0d (预期: 30)", dmem_ram[1]);
        $display("=================================================");

        if (u_core_top.u_regfile.regs[1] === 32'd10 &&
            u_core_top.u_regfile.regs[2] === 32'd20 &&
            u_core_top.u_regfile.regs[3] === 32'd30 &&
            u_core_top.u_regfile.regs[4] === 32'd30 &&
            u_core_top.u_regfile.regs[5] === 32'd0  &&
            u_core_top.u_regfile.regs[6] === 32'd88 &&
            dmem_ram[1] === 32'd30) begin
            $display("🎉🎉🎉 [大获全胜] 单周期 CPU 顶层闭环验证 100% 完美通过！执行、访存、跳转全线正常！");
        end else begin
            $display("❌ [测试失败] 数据通路或控制译码结果不符！");
        end
        $display("=================================================");

        #10;
        $finish;
    end

endmodule
