`timescale 1ns / 1ps

// =========================================================================
// 模块名称：ex_mem (EX/MEM 执行-访存级段流水线寄存器)
// 功能描述：锁存 EX 执行完毕后的 ALU 结果、访存控制与源数据，传递至 MEM 段。
// =========================================================================
module ex_mem (
    input  wire        clk,
    input  wire        rst_n,

    // EX 级输入
    input  wire [31:0] ex_pc,
    input  wire        ex_reg_we,
    input  wire        ex_mem_we,
    input  wire        ex_mem_re,
    input  wire [1:0]  ex_wb_sel,
    input  wire [31:0] ex_alu_res,
    input  wire [31:0] ex_mem_wdata,
    input  wire [4:0]  ex_rd,

    // MEM 级输出
    output reg  [31:0] mem_pc,
    output reg         mem_reg_we,
    output reg         mem_mem_we,
    output reg         mem_mem_re,
    output reg  [1:0]  mem_wb_sel,
    output reg  [31:0] mem_alu_res,
    output reg  [31:0] mem_wdata,
    output reg  [4:0]  mem_rd
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_pc      <= 32'd0;
            mem_reg_we  <= 1'b0;
            mem_mem_we  <= 1'b0;
            mem_mem_re  <= 1'b0;
            mem_wb_sel  <= 2'd0;
            mem_alu_res <= 32'd0;
            mem_wdata   <= 32'd0;
            mem_rd      <= 5'd0;
        end else begin
            mem_pc      <= ex_pc;
            mem_reg_we  <= ex_reg_we;
            mem_mem_we  <= ex_mem_we;
            mem_mem_re  <= ex_mem_re;
            mem_wb_sel  <= ex_wb_sel;
            mem_alu_res <= ex_alu_res;
            mem_wdata   <= ex_mem_wdata;
            mem_rd      <= ex_rd;
        end
    end

endmodule
