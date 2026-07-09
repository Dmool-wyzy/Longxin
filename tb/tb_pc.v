`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_pc (程序计数器 PC 自测实验室)
// =========================================================================
module tb_pc();

    reg         clk;
    reg         rst_n;
    reg         stall;
    reg         br_taken;
    reg  [31:0] br_target;
    wire [31:0] pc;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // 实例化被测模块 DUT
    pc u_pc (
        .clk       (clk),
        .rst_n     (rst_n),
        .stall     (stall),
        .br_taken  (br_taken),
        .br_target (br_target),
        .pc        (pc)
    );

    // 时钟生成：周期 10ns (主频 100MHz)
    always #5 clk = ~clk;

    task check_pc;
        input [255:0] test_name;
        input [31:0]  expected_pc;
        begin
            #1; // 时序打拍后小幅延时检查数据正确性
            if (pc === expected_pc) begin
                $display("✅ [通过] %s | 预期PC=0x%h, 实际PC=0x%h", test_name, expected_pc, pc);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("❌ [失败] %s | 预期PC=0x%h, 实际PC=0x%h", test_name, expected_pc, pc);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        $display("=================================================");
        $display("🌟 [龙芯杯备赛] 程序计数器 PC 仿真测试启动！");
        $display("=================================================");

        // --- [第 0 幕：初始化与异步复位] ---
        clk       = 0;
        rst_n     = 0;
        stall     = 0;
        br_taken  = 0;
        br_target = 32'd0;

        #12; // 保持低电平复位
        check_pc("异步复位阶段 ($rst_n=0)", 32'h1C000000);

        // --- [第 1 幕：释放复位并测试连续递增 (+4)] ---
        rst_n = 1;
        @(posedge clk);
        check_pc("第1个时钟周期递增 (PC+4)", 32'h1C000004);

        @(posedge clk);
        check_pc("第2个时钟周期递增 (PC+4)", 32'h1C000008);

        @(posedge clk);
        check_pc("第3个时钟周期递增 (PC+4)", 32'h1C00000C);

        // --- [第 2 幕：测试分支跳转 (Branch / Jump)] ---
        br_taken  = 1;
        br_target = 32'h1C000100;
        @(posedge clk);
        check_pc("跳转命中目标地址 (br_target=0x1C000100)", 32'h1C000100);

        // 跳转信号取消，恢复递增
        br_taken  = 0;
        @(posedge clk);
        check_pc("跳转结束后正常递增 (PC+4)", 32'h1C000104);

        // --- [第 3 幕：测试流水线暂停 (Stall)] ---
        stall = 1;
        @(posedge clk);
        check_pc("Stall 生效第1拍 (保持 0x1C000104)", 32'h1C000104);

        @(posedge clk);
        check_pc("Stall 生效第2拍 (保持 0x1C000104)", 32'h1C000104);

        // --- [第 4 幕：测试 Stall 优先级高于跳转] ---
        br_taken  = 1;
        br_target = 32'h20000000;
        @(posedge clk);
        check_pc("Stall 优先于跳转指令 (仍保持 0x1C000104)", 32'h1C000104);

        // 释放 Stall，应当跳转
        stall = 0;
        @(posedge clk);
        check_pc("释放 Stall 后执行有效跳转", 32'h20000000);

        $display("=================================================");
        if (fail_cnt == 0) begin
            $display("🎉 [测试总结] 完美通过！全部 %0d 项验证成功 (0 失败)！", pass_cnt);
        end else begin
            $display("❌ [测试总结] 有 %0d 项未通过，共 %0d 项通过。", fail_cnt, pass_cnt);
        end
        $display("=================================================");

        #10;
        $finish;
    end

endmodule
