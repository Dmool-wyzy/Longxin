`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_alu (核心算术逻辑运算单元自测实验室)
// =========================================================================
module tb_alu();

    // 1. 激励信号与监测信号声明
    reg  [3:0]  alu_op;
    reg  [31:0] src1;
    reg  [31:0] src2;
    wire [31:0] alu_res;

    // 统计用变量
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // 2. 实例化 ALU 待测模块 (DUT)
    alu u_alu (
        .alu_op  (alu_op),
        .src1    (src1),
        .src2    (src2),
        .alu_res (alu_res)
    );

    // 3. 辅助验证 Task：自动核查预期结果
    task check_result;
        input [255:0] test_name;
        input [31:0]  expected_res;
        begin
            #1; // 等待 1ns 组合逻辑传播
            if (alu_res === expected_res) begin
                $display("✅ [通过] %s | op=%d, src1=0x%h, src2=0x%h => res=0x%h", 
                         test_name, alu_op, src1, src2, alu_res);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("❌ [失败] %s | op=%d, src1=0x%h, src2=0x%h => 期望=0x%h, 实际=0x%h", 
                         test_name, alu_op, src1, src2, expected_res, alu_res);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    // 4. 核心测试剧本
    initial begin
        $display("=================================================");
        $display("🌟 [龙芯杯备赛] ALU 核心算术逻辑单元仿真测试启动！");
        $display("=================================================");

        alu_op = 4'd0;
        src1   = 32'd0;
        src2   = 32'd0;
        #10;

        // --- [第 1 幕：算术加减测试] ---
        // ADD (4'd0): 1234 + 5678 = 6912 (0x1B00)
        alu_op = 4'd0; src1 = 32'd1234; src2 = 32'd5678;
        check_result("ADD 正数加法", 32'd6912);

        // SUB (4'd1): 100 - 30 = 70
        alu_op = 4'd1; src1 = 32'd100; src2 = 32'd30;
        check_result("SUB 正数减法", 32'd70);

        // SUB 负数测试: 10 - 20 = -10 (0xFFFFFFF6)
        alu_op = 4'd1; src1 = 32'd10; src2 = 32'd20;
        check_result("SUB 产生负数结果", 32'hFFFFFFF6);

        // --- [第 2 幕：比较大小测试] ---
        // SLT (4'd2 有符号比较): -1 < 1 => 1
        alu_op = 4'd2; src1 = 32'hFFFFFFFF; src2 = 32'd1;
        check_result("SLT 有符号比较 (-1 < 1)", 32'd1);

        // SLT (4'd2 有符号比较): 1 < -1 => 0
        alu_op = 4'd2; src1 = 32'd1; src2 = 32'hFFFFFFFF;
        check_result("SLT 有符号比较 (1 < -1)", 32'd0);

        // SLTU (4'd3 无符号比较): 0xFFFFFFFF < 1 => 0 (4294967295 > 1)
        alu_op = 4'd3; src1 = 32'hFFFFFFFF; src2 = 32'd1;
        check_result("SLTU 无符号比较 (0xFFFFFFFF < 1)", 32'd0);

        // --- [第 3 幕：逻辑位运算测试] ---
        // AND (4'd4): 0xF0F0F0F0 & 0x0F0F0F0F = 0x00000000
        alu_op = 4'd4; src1 = 32'hF0F0F0F0; src2 = 32'h0F0F0F0F;
        check_result("AND 按位与", 32'h00000000);

        // OR (4'd5): 0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF
        alu_op = 4'd5; src1 = 32'hF0F0F0F0; src2 = 32'h0F0F0F0F;
        check_result("OR 按位或", 32'hFFFFFFFF);

        // XOR (4'd6): 0xAAAAAAAA ^ 0xAAAAAAAA = 0x00000000
        alu_op = 4'd6; src1 = 32'hAAAAAAAA; src2 = 32'hAAAAAAAA;
        check_result("XOR 按位异或", 32'h00000000);

        // NOR (4'd7): ~(0x0000FFFF | 0xFFFF0000) = 0x00000000
        alu_op = 4'd7; src1 = 32'h0000FFFF; src2 = 32'hFFFF0000;
        check_result("NOR 按位或非", 32'h00000000);

        // --- [第 4 幕：移位操作测试] ---
        // SLL (4'd8): 0x00000001 << 4 = 0x00000010
        alu_op = 4'd8; src1 = 32'h00000001; src2 = 32'd4;
        check_result("SLL 逻辑左移", 32'h00000010);

        // SRL (4'd9): 0x80000000 >> 4 = 0x08000000 (最高位补0)
        alu_op = 4'd9; src1 = 32'h80000000; src2 = 32'd4;
        check_result("SRL 逻辑右移", 32'h08000000);

        // SRA (4'd10): 0x80000000 >>> 4 = 0xF8000000 (最高位符号扩展)
        alu_op = 4'd10; src1 = 32'h80000000; src2 = 32'd4;
        check_result("SRA 算术右移 (符号扩展)", 32'hF8000000);

        // --- [第 5 幕：LUI 传递测试] ---
        // LUI (4'd11): 传递 src2 (0x12345000)
        alu_op = 4'd11; src1 = 32'hDEADBEEF; src2 = 32'h12345000;
        check_result("LUI 直接传递 src2", 32'h12345000);

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
