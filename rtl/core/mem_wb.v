`timescale 1ns / 1ps

// =========================================================================
// 模块名称：mem_wb (MEM/WB 访存-写回级段流水线寄存器)
// 功能描述：锁存访存阶段的数据读出结果、ALU结果及写回控制信号，进入 WB 写回阶段。
// =========================================================================
module mem_wb (
    input  wire        clk,
    input  wire        rst_n,

    // MEM 级输入
    input  wire [31:0] mem_pc,
    input  wire        mem_reg_we,
    input  wire [1:0]  mem_wb_sel,
    input  wire [31:0] mem_alu_res,
    input  wire [31:0] mem_rdata,
    input  wire [4:0]  mem_rd,

    // WB 级输出
    output reg  [31:0] wb_pc,
    output reg         wb_reg_we,
    output reg  [1:0]  wb_wb_sel,
    output reg  [31:0] wb_alu_res,
    output reg  [31:0] wb_mem_rdata,
    output reg  [4:0]  wb_rd
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_pc        <= 32'd0;
            wb_reg_we    <= 1'b0;
            wb_wb_sel    <= 2'd0;
            wb_alu_res   <= 32'd0;
            wb_mem_rdata <= 32'd0;
            wb_rd        <= 5'd0;
        end else begin
            wb_pc        <= mem_pc;
            wb_reg_we    <= mem_reg_we;
            wb_wb_sel    <= mem_wb_sel;
            wb_alu_res   <= mem_alu_res;
            wb_mem_rdata <= mem_rdata;
            wb_rd        <= mem_rd;
        end
    end

endmodule
