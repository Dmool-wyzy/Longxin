`timescale 1ns / 1ps

// =========================================================================
// 模块名称：hazard (工业级五级流水线冒险检测与数据前递单元)
// 功能描述：
//   1. 数据冒险前递 (Forwarding)：解决 RAW 冲突，优先支持 EX/MEM 前递，其次 MEM/WB 前递。
//   2. Load-Use 数据冒险暂停 (Stall)：当 EX 阶段为 Load 指令且目的寄存器与 ID 阶段源操作数冲突时，
//      冻结 PC 和 IF/ID 寄存器，同时冲刷 ID/EX 寄存器插入一个气泡。
//   3. 控制冒险分支冲刷 (Flush)：当 EX 阶段分支判定成立时，冲刷 IF/ID 和 ID/EX 寄存器。
// =========================================================================
module hazard (
    // 源操作数寄存器编号 (来自 ID/EX 段，用于前递判决)
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,

    // 源操作数寄存器编号 (来自 ID 译码段，用于 Load-Use 判决)
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,

    // EX 阶段访存控制与目的寄存器 (检查 Load-Use)
    input  wire       ex_mem_re,
    input  wire [4:0] ex_rd,

    // EX/MEM 级段写回控制与目的寄存器 (前递第一优先级)
    input  wire       mem_reg_we,
    input  wire [4:0] mem_rd,

    // MEM/WB 级段写回控制与目的寄存器 (前递第二优先级)
    input  wire       wb_reg_we,
    input  wire [4:0] wb_rd,

    // EX 阶段分支跳转判断结果
    input  wire       ex_br_taken,

    // 前递控制输出 (00: 寄存器原始值, 10: 来自 EX/MEM 前递, 01: 来自 MEM/WB 前递)
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b,

    // 流水线暂停与冲刷输出
    output reg        pc_stall,
    output reg        if_id_stall,
    output reg        if_id_flush,
    output reg        id_ex_flush
);

    // =========================================================================
    // 1. 数据前递逻辑 (Forwarding Unit) - 组合逻辑
    // =========================================================================
    always @(*) begin
        // 默认选择 ID/EX 寄存器传入的值
        forward_a = 2'b00;
        forward_b = 2'b00;

        // ALU 操作数 A 的前递判决
        if (mem_reg_we && (mem_rd != 5'd0) && (mem_rd == ex_rs1)) begin
            forward_a = 2'b10; // 第一优先级：离当前执行最近的 EX/MEM 前递
        end else if (wb_reg_we && (wb_rd != 5'd0) && (wb_rd == ex_rs1)) begin
            forward_a = 2'b01; // 第二优先级：MEM/WB 前递
        end

        // ALU 操作数 B 的前递判决
        if (mem_reg_we && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) begin
            forward_b = 2'b10;
        end else if (wb_reg_we && (wb_rd != 5'd0) && (wb_rd == ex_rs2)) begin
            forward_b = 2'b01;
        end
    end

    // =========================================================================
    // 2. 暂停与冲刷控制逻辑 (Hazard Detection & Stall/Flush) - 组合逻辑
    // =========================================================================
    always @(*) begin
        pc_stall    = 1'b0;
        if_id_stall = 1'b0;
        if_id_flush = 1'b0;
        id_ex_flush = 1'b0;

        // 优先级最高：控制冒险发生（分支或跳转成功），冲刷错误预取指令
        if (ex_br_taken) begin
            if_id_flush = 1'b1;
            id_ex_flush = 1'b1;
        end
        // Load-Use 数据冒险判断：EX 段为 Load 指令，且要读取的目的寄存器是当前 ID 段需读取的源操作数
        else if (ex_mem_re && (ex_rd != 5'd0) && ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            pc_stall    = 1'b1; // 暂停 PC
            if_id_stall = 1'b1; // 暂停 IF/ID
            id_ex_flush = 1'b1; // 在 EX 段插入 NOP 气泡
        end
    end

endmodule
