`timescale 1ns / 1ps

// =========================================================================
// 模块名称：core_top (单周期 CPU 核心架构顶层)
// 功能描述：组合 PC、Controller、Immediate Generator、RegFile、ALU 模块，
//          构成支持 15 条首批 LoongArch32 基准指令的完备可综合单周期处理核心。
// =========================================================================
module core_top (
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

    // 内部互联导线声明
    wire [31:0] pc_addr;
    wire [31:0] inst;

    // 控制器输出信号
    wire        reg_we;
    wire        alu_src;
    wire [3:0]  alu_op;
    wire [1:0]  wb_sel;
    wire [2:0]  br_type;
    wire [2:0]  imm_type;

    // 立即数及寄存器操作数
    wire [31:0] imm;
    wire [31:0] rdata1;
    wire [31:0] rdata2;
    wire [31:0] alu_res;

    // 分支判定与跳转目标
    reg         br_taken;
    wire [31:0] br_target;

    // 写回数据选择
    reg  [31:0] wb_data;

    // 1. 指令存储器寻址绑定
    assign imem_addr = pc_addr;
    assign inst      = imem_data;

    // 2. 寄存器堆读端口 2 路由判定：
    //    st.w, beq, bne 需比较/保存寄存器 rd (inst[4:0])，其它的使用 rk (inst[14:10])
    wire use_rd_as_r2 = dmem_we | (br_type == 3'd1) | (br_type == 3'd2);
    wire [4:0] raddr2 = use_rd_as_r2 ? inst[4:0] : inst[14:10];

    // 3. 分支条件判断与跳转逻辑
    always @(*) begin
        case (br_type)
            3'd0: br_taken = 1'b0;                         // 非分支跳转指令
            3'd1: br_taken = (rdata1 == rdata2);           // BEQ: 相等则跳转
            3'd2: br_taken = (rdata1 != rdata2);           // BNE: 不等则跳转
            3'd3: br_taken = 1'b1;                         // B: 无条件直接跳转
            3'd4: br_taken = 1'b1;                         // JIRL: 变址跳转
            default: br_taken = 1'b0;
        endcase
    end

    // JIRL 指令跳转目标为 (rdata1 + imm)，常规分支/直接跳转目标为 (pc_addr + imm)
    assign br_target = (br_type == 3'd4) ? (rdata1 + imm) : (pc_addr + imm);

    // 4. 写回数据多路选择
    always @(*) begin
        case (wb_sel)
            2'd0: wb_data = alu_res;                       // ALU 计算输出
            2'd1: wb_data = dmem_rdata;                    // 数据存储器读出数据
            2'd2: wb_data = pc_addr + 32'd4;               // JIRL 写入返回地址 PC+4
            default: wb_data = alu_res;
        endcase
    end

    // 5. 数据存储器输出绑定
    assign dmem_addr  = alu_res;
    assign dmem_wdata = rdata2;

    // =========================================================================
    // 子模块实例化
    // =========================================================================

    // 程序计数器模块
    pc u_pc (
        .clk       (clk),
        .rst_n     (rst_n),
        .stall     (1'b0),          // 单周期 CPU 暂不启用流水线暂停
        .br_taken  (br_taken),
        .br_target (br_target),
        .pc        (pc_addr)
    );

    // 主译码控制器
    controller u_controller (
        .inst     (inst),
        .reg_we   (reg_we),
        .alu_src  (alu_src),
        .alu_op   (alu_op),
        .mem_we   (dmem_we),
        .mem_re   (dmem_re),
        .wb_sel   (wb_sel),
        .br_type  (br_type),
        .imm_type (imm_type)
    );

    // 立即数生成单元
    imm_gen u_imm_gen (
        .inst     (inst),
        .imm_type (imm_type),
        .imm      (imm)
    );

    // 32x32 通用寄存器堆
    regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (reg_we),
        .waddr  (inst[4:0]),        // rd
        .wdata  (wb_data),
        .raddr1 (inst[9:5]),        // rj
        .rdata1 (rdata1),
        .raddr2 (raddr2),           // rk / rd
        .rdata2 (rdata2)
    );

    // 算术逻辑运算单元
    alu u_alu (
        .alu_op  (alu_op),
        .src1    (rdata1),
        .src2    (alu_src ? imm : rdata2),
        .alu_res (alu_res)
    );

endmodule
