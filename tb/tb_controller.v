`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_controller (主译码控制器 Control Unit 仿真测试实验室)
// =========================================================================
module tb_controller();

    reg  [31:0] inst;
    wire        reg_we;
    wire        alu_src;
    wire [3:0]  alu_op;
    wire        mem_we;
    wire        mem_re;
    wire [1:0]  wb_sel;
    wire [2:0]  br_type;
    wire [2:0]  imm_type;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    controller u_controller (
        .inst     (inst),
        .reg_we   (reg_we),
        .alu_src  (alu_src),
        .alu_op   (alu_op),
        .mem_we   (mem_we),
        .mem_re   (mem_re),
        .wb_sel   (wb_sel),
        .br_type  (br_type),
        .imm_type (imm_type)
    );

    task check_ctrl;
        input [255:0] test_name;
        input         exp_reg_we;
        input         exp_alu_src;
        input [3:0]   exp_alu_op;
        input         exp_mem_we;
        input         exp_mem_re;
        input [1:0]   exp_wb_sel;
        input [2:0]   exp_br_type;
        input [2:0]   exp_imm_type;
        begin
            #1;
            if (reg_we   === exp_reg_we  && alu_src === exp_alu_src &&
                alu_op   === exp_alu_op  && mem_we  === exp_mem_we  &&
                mem_re   === exp_mem_re  && wb_sel  === exp_wb_sel  &&
                br_type  === exp_br_type && imm_type === exp_imm_type) begin
                $display("✅ [通过] %s 译码成功", test_name);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("❌ [失败] %s | 实际结果: reg_we=%b, alu_src=%b, alu_op=%d, mem_we=%b, mem_re=%b, wb_sel=%d, br_type=%d, imm_type=%d", 
                         test_name, reg_we, alu_src, alu_op, mem_we, mem_re, wb_sel, br_type, imm_type);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        $display("=================================================");
        $display("🌟 [龙芯杯备赛] 主译码控制器 Controller 仿真测试启动！");
        $display("=================================================");

        // 1. add.w: 31:26=000000, 25:22=0000, 21:15=0000000 (32 bits total)
        inst = 32'b000000_0000_0000000_00000_00000_00000;
        check_ctrl("add.w", 1, 0, 4'd0, 0, 0, 2'd0, 3'd0, 3'd0);

        // 2. sub.w: 25:22=0010
        inst = 32'b000000_0010_0000000_00000_00000_00000;
        check_ctrl("sub.w", 1, 0, 4'd1, 0, 0, 2'd0, 3'd0, 3'd0);

        // 3. slt: 25:22=0100
        inst = 32'b000000_0100_0000000_00000_00000_00000;
        check_ctrl("slt", 1, 0, 4'd2, 0, 0, 2'd0, 3'd0, 3'd0);

        // 4. sltu: 25:22=0101
        inst = 32'b000000_0101_0000000_00000_00000_00000;
        check_ctrl("sltu", 1, 0, 4'd3, 0, 0, 2'd0, 3'd0, 3'd0);

        // 5. and: 25:22=1001
        inst = 32'b000000_1001_0000000_00000_00000_00000;
        check_ctrl("and", 1, 0, 4'd4, 0, 0, 2'd0, 3'd0, 3'd0);

        // 6. or: 25:22=1010
        inst = 32'b000000_1010_0000000_00000_00000_00000;
        check_ctrl("or", 1, 0, 4'd5, 0, 0, 2'd0, 3'd0, 3'd0);

        // 7. xor: 25:22=1011
        inst = 32'b000000_1011_0000000_00000_00000_00000;
        check_ctrl("xor", 1, 0, 4'd6, 0, 0, 2'd0, 3'd0, 3'd0);

        // 8. addi.w: 31:26=000010 (6 + 16 + 5 + 5 = 32 bits)
        inst = 32'b000010_0000000000000000_00000_00000;
        check_ctrl("addi.w", 1, 1, 4'd0, 0, 0, 2'd0, 3'd0, 3'd0);

        // 9. lu12i.w: 31:25=0001010 (7 + 20 + 5 = 32 bits)
        inst = 32'b0001010_00000000000000000000_00000;
        check_ctrl("lu12i.w", 1, 1, 4'd11, 0, 0, 2'd0, 3'd0, 3'd1);

        // 10. ld.w: 31:26=001010 (6 + 16 + 5 + 5 = 32 bits)
        inst = 32'b001010_0000000000000000_00000_00000;
        check_ctrl("ld.w", 1, 1, 4'd0, 0, 1, 2'd1, 3'd0, 3'd0);

        // 11. st.w: 31:26=001011 (6 + 16 + 5 + 5 = 32 bits)
        inst = 32'b001011_0000000000000000_00000_00000;
        check_ctrl("st.w", 0, 1, 4'd0, 1, 0, 2'd0, 3'd0, 3'd0);

        // 12. beq: 31:26=011000 (6 + 16 + 5 + 5 = 32 bits)
        inst = 32'b011000_0000000000000000_00000_00000;
        check_ctrl("beq", 0, 0, 4'd0, 0, 0, 2'd0, 3'd1, 3'd2);

        // 13. bne: 31:26=011001 (6 + 16 + 5 + 5 = 32 bits)
        inst = 32'b011001_0000000000000000_00000_00000;
        check_ctrl("bne", 0, 0, 4'd0, 0, 0, 2'd0, 3'd2, 3'd2);

        // 14. b: 31:26=010100 (6 + 26 = 32 bits)
        inst = 32'b010100_00000000000000000000000000;
        check_ctrl("b", 0, 0, 4'd0, 0, 0, 2'd0, 3'd3, 3'd3);

        // 15. jirl: 31:26=010011 (6 + 16 + 5 + 5 = 32 bits)
        inst = 32'b010011_0000000000000000_00000_00000;
        check_ctrl("jirl", 1, 0, 4'd0, 0, 0, 2'd2, 3'd4, 3'd2);

        $display("=================================================");
        if (fail_cnt == 0) begin
            $display("🎉 [测试总结] 完美通过！全部 %0d 条核心指令译码验证成功 (0 失败)！", pass_cnt);
        end else begin
            $display("❌ [测试总结] 有 %0d 项未通过，共 %0d 项通过。", fail_cnt, pass_cnt);
        end
        $display("=================================================");

        #10;
        $finish;
    end

endmodule
