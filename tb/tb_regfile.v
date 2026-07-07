    `timescale 1ns / 1ps

    // =========================================================================
    // 模块名称：tb_regfile (通用寄存器堆虚拟测试实验室)
    // 注意：测试台没有输入输出端口，它是一个封闭的测试环境！
    // =========================================================================
    module tb_regfile();

        // 1. 实验室内部信号声明
        // 要给芯片灌入信号，用到时序生成，必须用 reg 类型；接收芯片输出，用 wire 类型
        reg         clk;
        reg         rst_n;
        reg         we;
        reg  [4:0]  waddr;
        reg  [31:0] wdata;
        reg  [4:0]  raddr1;
        wire [31:0] rdata1;
        reg  [4:0]  raddr2;
        wire [31:0] rdata2;

        // 2. 将待测芯片 (DUT: Device Under Test) 插入测试台
        // 就好像在 PCB 板上把 regfile 芯片焊接起来，将引脚与实验室导线对联
        regfile u_regfile (
            .clk    (clk),
            .rst_n  (rst_n),
            .we     (we),
            .waddr  (waddr),
            .wdata  (wdata),
            .raddr1 (raddr1),
            .rdata1 (rdata1),
            .raddr2 (raddr2),
            .rdata2 (rdata2)
        );

        // 3. 指挥家节拍器：产生系统时钟 (100MHz，周期 10ns)
        // 语法：每隔 5 个时间单位(5ns)，时钟翻转一次电平 -> 0变1，1变0
        always #5 clk = ~clk;

        // 4. 核心测试剧本 (Initial Block: 仅在仿真启动时从上到下执行一次)
        initial begin
            // --- [第 0 幕：初始化与通电复位] ---
            clk   = 0;
            rst_n = 0;   // 按下复位按键 (低电平有效)
            we    = 0;
            waddr = 0;
            wdata = 0;
            raddr1 = 0;
            raddr2 = 0;

            #20;         // 等待 20ns (让时钟跳动两拍，系统稳定)
            rst_n = 1;   // 释放复位按键，开机正常工作！

            $display("=================================================");
            $display("🌟 [龙芯杯备赛] 通用寄存器堆 RegFile 仿真测试启动！");
            $display("=================================================");

            // --- [第 1 幕：测试对 $r0 恒零特性的挑战] ---
            // 尝试向 $r0 (0号地址) 写入十六进制数字 32'h88888888
            @(posedge clk); // 等待时钟上升沿到来
            we    = 1;
            waddr = 5'd0;
            wdata = 32'h88888888;

            @(posedge clk);
            we    = 0;      // 关闭写使能
            raddr1 = 5'd0;  // 去读 $r0
            #1;             // 等待 1ns 组合逻辑导线传播

            if (rdata1 == 32'h00000000)
                $display("✅ [测试通过] $r0 恒定为零！尝试写入 88888888 被成功硬件屏蔽，读出仍为: %h", rdata1);
            else
                $display("❌ [测试失败] $r0 被篡改了！当前读出值为: %h", rdata1);

            // --- [第 2 幕：测试向 $r1 和 $r2 的正常双端写入与同时读取] ---
            // 1. 向 $r1 写入 12345678
            @(posedge clk);
            we    = 1;
            waddr = 5'd1;
            wdata = 32'h12345678;

            // 2. 向 $r2 写入 DEADBEEF
            @(posedge clk);
            waddr = 5'd2;
            wdata = 32'hDEADBEEF;

            // 3. 关闭写使能，开启双端口同时读取
            @(posedge clk);
            we     = 0;
            raddr1 = 5'd1;  // 端口 1 读 $r1
            raddr2 = 5'd2;  // 端口 2 读 $r2
            #1;

            if (rdata1 == 32'h12345678 && rdata2 == 32'hDEADBEEF)
                $display("✅ [测试通过] 双读端口并发测试完美！端口1读出: %h, 端口2读出: %h", rdata1, rdata2);
            else
                $display("❌ [测试失败] 读出数据不匹配！");

            $display("=================================================");
            $display("🎉 全部功能回归验证完毕！龙芯 SoC 第一块砖石砌成！");
            $display("=================================================");

            #50;
            $finish; // 结束仿真
        end

    endmodule
