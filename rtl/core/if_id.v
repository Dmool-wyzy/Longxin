`timescale 1ns / 1ps

// =========================================================================
// 模块名称：if_id (IF/ID 取指-译码级段流水线寄存器)
// 功能描述：在时钟上升沿锁存 IF 阶段取到的指令及 PC，向下传递至 ID 译码阶段。
//          支持流水线暂停 (Stall) 和分支冲刷气泡 (Flush，填入 NOP 0x03400000)。
// =========================================================================
module if_id (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,      // 暂停控制 (1: 锁死当前状态不动)
    input  wire        flush,      // 冲刷控制 (1: 插入 NOP 气泡)
    
    // IF 级输入
    input  wire [31:0] if_pc,
    input  wire [31:0] if_inst,
    
    // ID 级输出
    output reg  [31:0] id_pc,
    output reg  [31:0] id_inst
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_pc   <= 32'd0;
            id_inst <= 32'h03400000; // LoongArch NOP 指令: addi.w $r0, $r0, 0
        end else if (flush) begin
            id_pc   <= 32'd0;
            id_inst <= 32'h03400000; // 冲刷流水线，填入 NOP 气泡
        end else if (!stall) begin
            id_pc   <= if_pc;
            id_inst <= if_inst;      // 正常传递
        end
        // 当 stall == 1 且 flush == 0 时，保持寄存器原值不变
    end

endmodule
