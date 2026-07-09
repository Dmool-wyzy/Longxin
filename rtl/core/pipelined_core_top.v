`timescale 1ns / 1ps

// =========================================================================
// 模块名称：pipelined_core_top (工业级五级流水线 CPU 核心顶层)
// 功能描述：将 IF、ID、EX、MEM、WB 五段流水线寄存器与控制器、运算器、寄存器堆、
//          冒险前递单元打通，形成支持前递与气泡暂停的高频五级流水线 CPU 核心。
// =========================================================================
module pipelined_core_top (
    input  wire        clk,
    input  wire        rst_n,

    // 指令存储器接口 (I-Mem)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_data,

    // 数据存储器接口 (D-Mem)
    output wire        dmem_we,
    output wire        dmem_re,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata
);

    // =========================================================================
    // 信号声明区
    // =========================================================================

    // 冒险与前递单元控制信号
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire       pc_stall;
    wire       if_id_stall;
    wire       if_id_flush;
    wire       id_ex_flush;

    // --- 1. IF 取指阶段信号 ---
    wire [31:0] if_pc;

    // --- 2. ID 译码阶段信号 ---
    wire [31:0] id_pc;
    wire [31:0] id_inst;
    wire        id_reg_we;
    wire        id_alu_src;
    wire [3:0]  id_alu_op;
    wire        id_mem_we;
    wire        id_mem_re;
    wire [1:0]  id_wb_sel;
    wire [2:0]  id_br_type;
    wire [2:0]  id_imm_type;
    wire [31:0] id_imm;
    wire [31:0] id_rdata1;
    wire [31:0] id_rdata2;

    wire [4:0]  id_rs1 = id_inst[9:5];
    wire        use_rd_as_r2 = id_mem_we | (id_br_type == 3'd1) | (id_br_type == 3'd2);
    wire [4:0]  id_rs2 = use_rd_as_r2 ? id_inst[4:0] : id_inst[14:10];
    wire [4:0]  id_rd  = id_inst[4:0];

    // --- 3. EX 执行阶段信号 ---
    wire [31:0] ex_pc;
    wire        ex_reg_we;
    wire        ex_alu_src;
    wire [3:0]  ex_alu_op;
    wire        ex_mem_we;
    wire        ex_mem_re;
    wire [1:0]  ex_wb_sel;
    wire [2:0]  ex_br_type;
    wire [31:0] ex_rdata1;
    wire [31:0] ex_rdata2;
    wire [31:0] ex_imm;
    wire [4:0]  ex_rs1;
    wire [4:0]  ex_rs2;
    wire [4:0]  ex_rd;

    reg  [31:0] ex_fwd_data1;
    reg  [31:0] ex_fwd_data2;
    wire [31:0] alu_in2 = ex_alu_src ? ex_imm : ex_fwd_data2;
    wire [31:0] ex_alu_res;

    reg         ex_br_taken;
    wire [31:0] ex_br_target;

    // --- 4. MEM 访存阶段信号 ---
    wire [31:0] mem_pc;
    wire        mem_reg_we;
    wire        mem_mem_we;
    wire        mem_mem_re;
    wire [1:0]  mem_wb_sel;
    wire [31:0] mem_alu_res;
    wire [31:0] mem_wdata;
    wire [4:0]  mem_rd;

    // --- 5. WB 写回阶段信号 ---
    wire [31:0] wb_pc;
    wire        wb_reg_we;
    wire [1:0]  wb_wb_sel;
    wire [31:0] wb_alu_res;
    wire [31:0] wb_mem_rdata;
    wire [4:0]  wb_rd;
    reg  [31:0] wb_data;

    // =========================================================================
    // 逻辑实现区
    // =========================================================================

    // --- 1. IF 阶段：程序计数器 ---
    pc u_pc (
        .clk       (clk),
        .rst_n     (rst_n),
        .stall     (pc_stall),
        .br_taken  (ex_br_taken),
        .br_target (ex_br_target),
        .pc        (if_pc)
    );

    assign imem_addr = if_pc;

    // --- IF/ID 流水线寄存器 ---
    if_id u_if_id (
        .clk     (clk),
        .rst_n   (rst_n),
        .stall   (if_id_stall),
        .flush   (if_id_flush),
        .if_pc   (if_pc),
        .if_inst (imem_data),
        .id_pc   (id_pc),
        .id_inst (id_inst)
    );

    // --- 2. ID 阶段：译码与寄存器堆读取 ---
    controller u_controller (
        .inst     (id_inst),
        .reg_we   (id_reg_we),
        .alu_src  (id_alu_src),
        .alu_op   (id_alu_op),
        .mem_we   (id_mem_we),
        .mem_re   (id_mem_re),
        .wb_sel   (id_wb_sel),
        .br_type  (id_br_type),
        .imm_type (id_imm_type)
    );

    imm_gen u_imm_gen (
        .inst     (id_inst),
        .imm_type (id_imm_type),
        .imm      (id_imm)
    );

    regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (wb_reg_we),
        .waddr  (wb_rd),
        .wdata  (wb_data),
        .raddr1 (id_rs1),
        .rdata1 (id_rdata1),
        .raddr2 (id_rs2),
        .rdata2 (id_rdata2)
    );

    // --- ID/EX 流水线寄存器 ---
    id_ex u_id_ex (
        .clk        (clk),
        .rst_n      (rst_n),
        .flush      (id_ex_flush),
        .id_pc      (id_pc),
        .id_reg_we  (id_reg_we),
        .id_alu_src (id_alu_src),
        .id_alu_op  (id_alu_op),
        .id_mem_we  (id_mem_we),
        .id_mem_re  (id_mem_re),
        .id_wb_sel  (id_wb_sel),
        .id_br_type (id_br_type),
        .id_rdata1  (id_rdata1),
        .id_rdata2  (id_rdata2),
        .id_imm     (id_imm),
        .id_rs1     (id_rs1),
        .id_rs2     (id_rs2),
        .id_rd      (id_rd),
        .ex_pc      (ex_pc),
        .ex_reg_we  (ex_reg_we),
        .ex_alu_src (ex_alu_src),
        .ex_alu_op  (ex_alu_op),
        .ex_mem_we  (ex_mem_we),
        .ex_mem_re  (ex_mem_re),
        .ex_wb_sel  (ex_wb_sel),
        .ex_br_type (ex_br_type),
        .ex_rdata1  (ex_rdata1),
        .ex_rdata2  (ex_rdata2),
        .ex_imm     (ex_imm),
        .ex_rs1     (ex_rs1),
        .ex_rs2     (ex_rs2),
        .ex_rd      (ex_rd)
    );

    // --- 3. EX 阶段：前递选择与 ALU / 分支跳转运算 ---
    always @(*) begin
        case (forward_a)
            2'b10: ex_fwd_data1 = mem_alu_res;
            2'b01: ex_fwd_data1 = wb_data;
            default: ex_fwd_data1 = ex_rdata1;
        endcase

        case (forward_b)
            2'b10: ex_fwd_data2 = mem_alu_res;
            2'b01: ex_fwd_data2 = wb_data;
            default: ex_fwd_data2 = ex_rdata2;
        endcase
    end

    // 分支条件决断
    always @(*) begin
        case (ex_br_type)
            3'd0: ex_br_taken = 1'b0;
            3'd1: ex_br_taken = (ex_fwd_data1 == ex_fwd_data2);
            3'd2: ex_br_taken = (ex_fwd_data1 != ex_fwd_data2);
            3'd3: ex_br_taken = 1'b1;
            3'd4: ex_br_taken = 1'b1;
            default: ex_br_taken = 1'b0;
        endcase
    end

    assign ex_br_target = (ex_br_type == 3'd4) ? (ex_fwd_data1 + ex_imm) : (ex_pc + ex_imm);

    alu u_alu (
        .src1    (ex_fwd_data1),
        .src2    (alu_in2),
        .alu_op  (ex_alu_op),
        .alu_res (ex_alu_res)
    );

    // --- EX/MEM 流水线寄存器 ---
    ex_mem u_ex_mem (
        .clk          (clk),
        .rst_n        (rst_n),
        .ex_pc        (ex_pc),
        .ex_reg_we    (ex_reg_we),
        .ex_mem_we    (ex_mem_we),
        .ex_mem_re    (ex_mem_re),
        .ex_wb_sel    (ex_wb_sel),
        .ex_alu_res   (ex_alu_res),
        .ex_mem_wdata (ex_fwd_data2), // 经前递后的写入数据
        .ex_rd        (ex_rd),
        .mem_pc       (mem_pc),
        .mem_reg_we   (mem_reg_we),
        .mem_mem_we   (mem_mem_we),
        .mem_mem_re   (mem_mem_re),
        .mem_wb_sel   (mem_wb_sel),
        .mem_alu_res  (mem_alu_res),
        .mem_wdata    (mem_wdata),
        .mem_rd       (mem_rd)
    );

    // --- 4. MEM 阶段：访问数据存储器 ---
    assign dmem_we    = mem_mem_we;
    assign dmem_re    = mem_mem_re;
    assign dmem_addr  = mem_alu_res;
    assign dmem_wdata = mem_wdata;

    // --- MEM/WB 流水线寄存器 ---
    mem_wb u_mem_wb (
        .clk         (clk),
        .rst_n       (rst_n),
        .mem_pc      (mem_pc),
        .mem_reg_we  (mem_reg_we),
        .mem_wb_sel  (mem_wb_sel),
        .mem_alu_res (mem_alu_res),
        .mem_rdata   (dmem_rdata),
        .mem_rd      (mem_rd),
        .wb_pc       (wb_pc),
        .wb_reg_we   (wb_reg_we),
        .wb_wb_sel   (wb_wb_sel),
        .wb_alu_res  (wb_alu_res),
        .wb_mem_rdata(wb_mem_rdata),
        .wb_rd       (wb_rd)
    );

    // --- 5. WB 阶段：写回选择多路开关 ---
    always @(*) begin
        case (wb_wb_sel)
            2'd0: wb_data = wb_alu_res;
            2'd1: wb_data = wb_mem_rdata;
            2'd2: wb_data = wb_pc + 32'd4;
            default: wb_data = wb_alu_res;
        endcase
    end

    // --- 6. 冒险与前递单元 ---
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

endmodule
