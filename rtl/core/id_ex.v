`timescale 1ns / 1ps

// =========================================================================
// 模块名称：id_ex (ID/EX 译码-执行级段流水线寄存器)
// 功能描述：锁存 ID 阶段解析出的控制信号、寄存器源数据、立即数及源/目的寄存器号，
//          向 EX 阶段传递。当遇到数据冲突或分支冲刷 (flush=1) 时清空控制流。
// =========================================================================
module id_ex (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,      // 暂停控制 (1: 保持寄存器原值不变)
    input  wire        flush,      // 冲刷控制 (1: 插入 NOP 气泡)

    // ID 级输入
    input  wire [31:0] id_pc,
    input  wire        id_reg_we,
    input  wire        id_alu_src,
    input  wire [3:0]  id_alu_op,
    input  wire        id_mem_we,
    input  wire        id_mem_re,
    input  wire [1:0]  id_wb_sel,
    input  wire [2:0]  id_br_type,
    input  wire [31:0] id_rdata1,
    input  wire [31:0] id_rdata2,
    input  wire [31:0] id_imm,
    input  wire [4:0]  id_rs1,
    input  wire [4:0]  id_rs2,
    input  wire [4:0]  id_rd,

    // EX 级输出
    output reg  [31:0] ex_pc,
    output reg         ex_reg_we,
    output reg         ex_alu_src,
    output reg  [3:0]  ex_alu_op,
    output reg         ex_mem_we,
    output reg         ex_mem_re,
    output reg  [1:0]  ex_wb_sel,
    output reg  [2:0]  ex_br_type,
    output reg  [31:0] ex_rdata1,
    output reg  [31:0] ex_rdata2,
    output reg  [31:0] ex_imm,
    output reg  [4:0]  ex_rs1,
    output reg  [4:0]  ex_rs2,
    output reg  [4:0]  ex_rd
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_pc      <= 32'd0;
            ex_reg_we  <= 1'b0;
            ex_alu_src <= 1'b0;
            ex_alu_op  <= 4'd0;
            ex_mem_we  <= 1'b0;
            ex_mem_re  <= 1'b0;
            ex_wb_sel  <= 2'd0;
            ex_br_type <= 3'd0;
            ex_rdata1  <= 32'd0;
            ex_rdata2  <= 32'd0;
            ex_imm     <= 32'd0;
            ex_rs1     <= 5'd0;
            ex_rs2     <= 5'd0;
            ex_rd      <= 5'd0;
        end else if (!stall) begin
            if (flush) begin
                ex_pc      <= 32'd0;
                ex_reg_we  <= 1'b0;
                ex_alu_src <= 1'b0;
                ex_alu_op  <= 4'd0;
                ex_mem_we  <= 1'b0;
                ex_mem_re  <= 1'b0;
                ex_wb_sel  <= 2'd0;
                ex_br_type <= 3'd0;
                ex_rdata1  <= 32'd0;
                ex_rdata2  <= 32'd0;
                ex_imm     <= 32'd0;
                ex_rs1     <= 5'd0;
                ex_rs2     <= 5'd0;
                ex_rd      <= 5'd0;
            end else begin
                ex_pc      <= id_pc;
                ex_reg_we  <= id_reg_we;
                ex_alu_src <= id_alu_src;
                ex_alu_op  <= id_alu_op;
                ex_mem_we  <= id_mem_we;
                ex_mem_re  <= id_mem_re;
                ex_wb_sel  <= id_wb_sel;
                ex_br_type <= id_br_type;
                ex_rdata1  <= id_rdata1;
                ex_rdata2  <= id_rdata2;
                ex_imm     <= id_imm;
                ex_rs1     <= id_rs1;
                ex_rs2     <= id_rs2;
                ex_rd      <= id_rd;
            end
        end
    end

endmodule
