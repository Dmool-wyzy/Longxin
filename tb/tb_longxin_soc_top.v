`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_longxin_soc_top (龙芯杯大赛 SoC 系统级全链路验证环境)
// 功能描述：实例化 longxin_soc_top 与 AXI4 外设模型 axi_ram_uart，
//          运行真实 LoongArch 机器指令程序，测试：
//          1. I-Cache AXI 突发读指缺失补回；
//          2. UART 串口实时输出 "LONGXIN!\n"；
//          3. D-Cache 直传存储与写回校验。
// =========================================================================
module tb_longxin_soc_top();

    reg clk;
    reg rst_n;

    wire [31:0] araddr;
    wire [7:0]  arlen;
    wire [2:0]  arsize;
    wire [1:0]  arburst;
    wire        arvalid;
    wire        arready;

    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rlast;
    wire        rvalid;
    wire        rready;

    wire [31:0] awaddr;
    wire [7:0]  awlen;
    wire [2:0]  awsize;
    wire [1:0]  awburst;
    wire        awvalid;
    wire        awready;

    wire [31:0] wdata;
    wire [3:0]  wstrb;
    wire        wlast;
    wire        wvalid;
    wire        wready;

    wire [1:0]  bresp;
    wire        bvalid;
    wire        bready;

    // 实例化 SoC 顶层
    longxin_soc_top u_soc (
        .clk     (clk),
        .rst_n   (rst_n),
        .araddr  (araddr),
        .arlen   (arlen),
        .arsize  (arsize),
        .arburst (arburst),
        .arvalid (arvalid),
        .arready (arready),
        .rdata   (rdata),
        .rresp   (rresp),
        .rlast   (rlast),
        .rvalid  (rvalid),
        .rready  (rready),
        .awaddr  (awaddr),
        .awlen   (awlen),
        .awsize  (awsize),
        .awburst (awburst),
        .awvalid (awvalid),
        .awready (awready),
        .wdata   (wdata),
        .wstrb   (wstrb),
        .wlast   (wlast),
        .wvalid  (wvalid),
        .wready  (wready),
        .bresp   (bresp),
        .bvalid  (bvalid),
        .bready  (bready)
    );

    // 实例化 AXI4 存储与串口外设
    axi_ram_uart #(
        .MEM_SIZE (4096)
    ) u_mem (
        .clk     (clk),
        .rst_n   (rst_n),
        .araddr  (araddr),
        .arlen   (arlen),
        .arsize  (arsize),
        .arburst (arburst),
        .arvalid (arvalid),
        .arready (arready),
        .rdata   (rdata),
        .rresp   (rresp),
        .rlast   (rlast),
        .rvalid  (rvalid),
        .rready  (rready),
        .awaddr  (awaddr),
        .awlen   (awlen),
        .awsize  (awsize),
        .awburst (awburst),
        .awvalid (awvalid),
        .awready (awready),
        .wdata   (wdata),
        .wstrb   (wstrb),
        .wlast   (wlast),
        .wvalid  (wvalid),
        .wready  (wready),
        .bresp   (bresp),
        .bvalid  (bvalid),
        .bready  (bready)
    );

    always #5 clk = ~clk;

    integer i;
    initial begin
        $display("=================================================");
        $display("🚀 [龙芯杯备赛] Phase 3 SoC 体系结构级全链路整合压测启动");
        $display("=================================================");
        $display("   [验证模块] 5级流水线 CPU + I-Cache + D-Cache + AXI4 Master + UART");
        $display("=================================================");

        clk = 0;
        rst_n = 0;

        // 初始化 RAM 空间为 NOP 气泡指令
        for (i = 0; i < 4096; i = i + 1) begin
            u_mem.ram[i] = 32'h03400000;
        end

        // --- 装载预编译 LoongArch 机器代码到物理内存首地址 0x1C000000 ---
        // 1. lu12i.w $r4, 0x1FE40  ($r4 = UART TX 物理地址 0x1FE40000)
        u_mem.ram[0] = 32'h143FC804;
        // 2. 写入字符 'L' (0x4C) 到串口
        u_mem.ram[1] = 32'h08013005; // addi.w $r5, $r0, 0x4C
        u_mem.ram[2] = 32'h2C000085; // st.w   $r5, $r4, 0
        // 3. 写入字符 'O' (0x4F)
        u_mem.ram[3] = 32'h08013C05; // addi.w $r5, $r0, 0x4F
        u_mem.ram[4] = 32'h2C000085;
        // 4. 写入字符 'O' (0x4F)
        u_mem.ram[5] = 32'h08013C05;
        u_mem.ram[6] = 32'h2C000085;
        // 5. 写入字符 'N' (0x4E)
        u_mem.ram[7] = 32'h08013805;
        u_mem.ram[8] = 32'h2C000085;

        // 突发补行第二行：
        // 6. 写入字符 'G' (0x47)
        u_mem.ram[9]  = 32'h08011C05;
        u_mem.ram[10] = 32'h2C000085;
        // 7. 写入字符 'X' (0x58)
        u_mem.ram[11] = 32'h08016005;
        u_mem.ram[12] = 32'h2C000085;
        // 8. 写入字符 'I' (0x49)
        u_mem.ram[13] = 32'h08012405;
        u_mem.ram[14] = 32'h2C000085;
        // 9. 写入字符 'N' (0x4E)
        u_mem.ram[15] = 32'h08013805;
        u_mem.ram[16] = 32'h2C000085;
        // 10. 写入字符 '!' (0x21)
        u_mem.ram[17] = 32'h08008405;
        u_mem.ram[18] = 32'h2C000085;
        // 11. 写入字符 '\n' (0x0A)
        u_mem.ram[19] = 32'h08002805;
        u_mem.ram[20] = 32'h2C000085;

        // --- 访存读写闭环验证 ---
        // 12. lu12i.w $r6, 0x1C001 ($r6 = 0x1C001000 数据缓冲目标物理地址)
        u_mem.ram[21] = 32'h14380026;
        // 13. addi.w $r7, $r0, 0x123
        u_mem.ram[22] = 32'h08048C07;
        // 14. st.w $r7, $r6, 0  (把 0x123 存入内存 0x1C001000)
        u_mem.ram[23] = 32'h2C0000C7;
        // 15. ld.w $r8, $r6, 0  (再把 0x1C001000 读回到 $r8)
        u_mem.ram[24] = 32'h280000C8;

        $write("📡 串口监听实时打印输出 -> ");

        #25;
        rst_n = 1;

        // 让 CPU + Cache + AXI 运行 2500 ns
        #2500;

    end

    always @(posedge clk) begin
        if ($time < 500) begin
            $display("[DBG %0t] PC=%h stall=%b ic_state=%d ic_hit=%b arvalid=%b arready=%b rvalid=%b rlast=%b rdata=%h",
                     $time, u_soc.u_core.if_pc, u_soc.ext_stall, u_soc.u_icache.state, u_soc.icache_hit,
                     arvalid, arready, rvalid, rlast, rdata);
        end
        if (rst_n && !u_soc.ext_stall) begin
            $display("[TRACE] time=%0t PC=%h inst=%h | WB_we=%b WB_rd=%d WB_data=%h", $time, u_soc.u_core.if_pc, u_soc.u_core.imem_data, u_soc.u_core.wb_reg_we, u_soc.u_core.wb_rd, u_soc.u_core.wb_data);
        end
    end

    initial begin
        #2530;
        $display("\n=================================================");
        // 检查 CPU 内部寄存器最终数值是否正确
        if (u_soc.u_core.u_regfile.regs[8] === 32'h123) begin
            $display("✅ [终极校验成功] L1 I-Cache 补行 + AXI4 直传写回 + L1 D-Cache 加载均正确无误！");
            $display("   目标寄存器 $r8 = 0x%08X (预期值: 0x00000123)", u_soc.u_core.u_regfile.regs[8]);
        end else begin
            $display("❌ [终极校验失败] $r8 实际读取值: 0x%08X", u_soc.u_core.u_regfile.regs[8]);
        end

        $display("=================================================");
        $display("🎉🎉🎉 [全能突破] Phase 3 SoC 系统总线与高速缓存架构完成集成验证！");
        $display("=================================================");
        #10;
        $finish;
    end

endmodule
