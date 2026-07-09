`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_hazard (工业级流水线冒险与前递控制自检实验室)
// 功能描述：全面测试 hazard 模块的 5 大核心功能：
//   1. EX/MEM 优先前递验证
//   2. MEM/WB 次优前递验证
//   3. EX/MEM 覆盖 MEM/WB 优先级测试
//   4. Load-Use 数据冒险暂停 (Stall + Bubble) 测试
//   5. 分支跳转成功冲刷 (Flush) 测试
// =========================================================================
module tb_hazard();

    reg  [4:0] ex_rs1;
    reg  [4:0] ex_rs2;
    reg  [4:0] id_rs1;
    reg  [4:0] id_rs2;
    reg        ex_mem_re;
    reg  [4:0] ex_rd;
    reg        mem_reg_we;
    reg  [4:0] mem_rd;
    reg        wb_reg_we;
    reg  [4:0] wb_rd;
    reg        ex_br_taken;

    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire       pc_stall;
    wire       if_id_stall;
    wire       if_id_flush;
    wire       id_ex_flush;

    hazard u_hazard (
        .ex_rs1      (ex_rs1),
        .ex_rs2      (ex_rs2),
        .id_rs1      (id_rs1),
        .id_rs2      (id_rs2),
        .ex_mem_re   (ex_mem_re),
        .ex_rd       (ex_rd),
        .mem_reg_we  (mem_reg_we),
        .mem_rd      (mem_rd),
        .wb_reg_we   (wb_reg_we),
        .wb_rd       (wb_rd),
        .ex_br_taken (ex_br_taken),
        .forward_a   (forward_a),
        .forward_b   (forward_b),
        .pc_stall    (pc_stall),
        .if_id_stall (if_id_stall),
        .if_id_flush (if_id_flush),
        .id_ex_flush (id_ex_flush)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    initial begin
        $display("=================================================");
        $display("⚡ [龙芯杯备赛] 五级流水线冒险与前递单元深度验证启动！");
        $display("=================================================");

        // 初始化默认状态
        ex_rs1 = 0; ex_rs2 = 0; id_rs1 = 0; id_rs2 = 0;
        ex_mem_re = 0; ex_rd = 0;
        mem_reg_we = 0; mem_rd = 0;
        wb_reg_we = 0; wb_rd = 0;
        ex_br_taken = 0;
        #10;

        // 测试项 1: EX/MEM 前递 (离当前指令最近的数据前递)
        ex_rs1 = 5'd3;
        mem_reg_we = 1'b1;
        mem_rd = 5'd3;
        #10;
        if (forward_a === 2'b10 && forward_b === 2'b00) begin
            $display("✅ [测试项1通过] EX/MEM 成功向 A 通道前递 (forward_a=10)");
            pass_count = pass_count + 1;
        end else begin
            $display("❌ [测试项1失败] 期望 forward_a=10, 实际得到 %b", forward_a);
            fail_count = fail_count + 1;
        end

        // 测试项 2: MEM/WB 前递 (较远距离的数据前递)
        ex_rs1 = 5'd1;
        ex_rs2 = 5'd4;
        mem_reg_we = 1'b0;
        mem_rd = 5'd0;
        wb_reg_we = 1'b1;
        wb_rd = 5'd4;
        #10;
        if (forward_a === 2'b00 && forward_b === 2'b01) begin
            $display("✅ [测试项2通过] MEM/WB 成功向 B 通道前递 (forward_b=01)");
            pass_count = pass_count + 1;
        end else begin
            $display("❌ [测试项2失败] 期望 forward_b=01, 实际得到 %b", forward_b);
            fail_count = fail_count + 1;
        end

        // 测试项 3: EX/MEM 覆盖 MEM/WB 优先级测试 (当两级都尝试写同寄存器时)
        ex_rs1 = 5'd5;
        mem_reg_we = 1'b1;
        mem_rd = 5'd5;
        wb_reg_we = 1'b1;
        wb_rd = 5'd5;
        #10;
        if (forward_a === 2'b10) begin
            $display("✅ [测试项3通过] EX/MEM 优先级正确覆盖 MEM/WB (forward_a=10)");
            pass_count = pass_count + 1;
        end else begin
            $display("❌ [测试项3失败] 期望 forward_a=10, 实际得到 %b", forward_a);
            fail_count = fail_count + 1;
        end

        // 复位所有前递输入
        mem_reg_we = 0; wb_reg_we = 0; ex_rs1 = 0; ex_rs2 = 0;
        #10;

        // 测试项 4: Load-Use 数据冒险 (EX段为ld.w，ID段要读取其写回的目标寄存器)
        ex_mem_re = 1'b1;
        ex_rd = 5'd8;
        id_rs1 = 5'd8;
        #10;
        if (pc_stall === 1'b1 && if_id_stall === 1'b1 && id_ex_flush === 1'b1) begin
            $display("✅ [测试项4通过] Load-Use 冲突正确产生暂停与气泡 (pc_stall=1, if_id_stall=1, id_ex_flush=1)");
            pass_count = pass_count + 1;
        end else begin
            $display("❌ [测试项4失败] Load-Use 控制输出不符！");
            fail_count = fail_count + 1;
        end

        // 清楚 Load-Use
        ex_mem_re = 0; ex_rd = 0; id_rs1 = 0;
        #10;

        // 测试项 5: 控制冒险分支成功冲刷
        ex_br_taken = 1'b1;
        #10;
        if (if_id_flush === 1'b1 && id_ex_flush === 1'b1) begin
            $display("✅ [测试项5通过] 分支跳转发生正确触发冲刷 (if_id_flush=1, id_ex_flush=1)");
            pass_count = pass_count + 1;
        end else begin
            $display("❌ [测试项5失败] 分支跳转冲刷信号输出错误！");
            fail_count = fail_count + 1;
        end

        $display("=================================================");
        $display("统计报告：通过 %0d 项 / 共 5 项", pass_count);
        if (fail_count == 0 && pass_count == 5) begin
            $display("🎉🎉🎉 [大获全胜] 冒险检测与数据前递模块 100% 验证通过！");
        end else begin
            $display("❌ 验证未完全通过，请检查逻辑！");
        end
        $display("=================================================");
        $finish;
    end

endmodule
