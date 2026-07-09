`timescale 1ns / 1ps

// =========================================================================
// 模块名称：controller (主译码控制器 Control Unit)
// 功能描述：解析 LoongArch32 (LA32R) 基础指令集指令格式，为 Phase 1 首批 15 条
//          基准指令生成精确无锁存器 (No Latch) 的控制信号流。
// =========================================================================
module controller (
    input  wire [31:0] inst,       // 32位机器指令

    // 寄存器堆控制
    output reg         reg_we,     // 寄存器堆写使能 (1: 允许写入)
    
    // ALU 运算通路控制
    output reg         alu_src,    // ALU操作数2选择 (0: rdata2, 1: 立即数 imm)
    output reg  [3:0]  alu_op,     // ALU 运算类型控制 (见 alu.v 操作码表)

    // 访存与写回控制
    output reg         mem_we,     // 数据存储器写使能
    output reg         mem_re,     // 数据存储器读使能
    output reg  [1:0]  wb_sel,     // 写回数据选择 (0: ALU输出, 1: 访存输出, 2: PC+4)

    // 分支与跳转控制
    output reg  [2:0]  br_type,    // 跳转类型 (0: 无, 1: BEQ, 2: BNE, 3: B, 4: JIRL)
    output reg  [2:0]  imm_type    // 立即数类型 (0: si12, 1: si20, 2: offs16, 3: offs26)
);

    // LoongArch32 操作码切片
    wire [5:0] op_31_26 = inst[31:26];
    wire [3:0] op_25_22 = inst[25:22];
    wire [6:0] op_31_25 = inst[31:25];

    // 组合逻辑译码：始终给每个输出赋默认值以杜绝隐形锁存器 (Latch)
    always @(*) begin
        // 默认控制状态（安全初始态）
        reg_we   = 1'b0;
        alu_src  = 1'b0;
        alu_op   = 4'd0;       // 默认 ADD
        mem_we   = 1'b0;
        mem_re   = 1'b0;
        wb_sel   = 2'd0;       // 默认写回 ALU 结果
        br_type  = 3'd0;       // 默认无跳转
        imm_type = 3'd0;       // 默认 12 位符号扩展立即数

        if (op_31_26 == 6'b000000) begin
            // 3R 格式运算指令 (add.w, sub.w, slt, sltu, and, or, xor 等)
            case (op_25_22)
                4'b0000: begin // add.w
                    reg_we  = 1'b1;
                    alu_src = 1'b0;
                    alu_op  = 4'd0; // ADD
                end
                4'b0010: begin // sub.w
                    reg_we  = 1'b1;
                    alu_src = 1'b0;
                    alu_op  = 4'd1; // SUB
                end
                4'b0100: begin // slt
                    reg_we  = 1'b1;
                    alu_src = 1'b0;
                    alu_op  = 4'd2; // SLT (有符号比较)
                end
                4'b0101: begin // sltu
                    reg_we  = 1'b1;
                    alu_src = 1'b0;
                    alu_op  = 4'd3; // SLTU (无符号比较)
                end
                4'b1001: begin // and
                    reg_we  = 1'b1;
                    alu_src = 1'b0;
                    alu_op  = 4'd4; // AND
                end
                4'b1010: begin // or
                    reg_we  = 1'b1;
                    alu_src = 1'b0;
                    alu_op  = 4'd5; // OR
                end
                4'b1011: begin // xor
                    reg_we  = 1'b1;
                    alu_src = 1'b0;
                    alu_op  = 4'd6; // XOR
                end
                default: ;
            endcase
        end
        else if (op_31_26 == 6'b000010) begin
            // addi.w (立即数加法)
            reg_we   = 1'b1;
            alu_src  = 1'b1;        // 选立即数
            alu_op   = 4'd0;        // ADD
            imm_type = 3'd0;        // 12 位符号扩展
        end
        else if (op_31_25 == 7'b0001010) begin
            // lu12i.w (装载高 20 位立即数)
            reg_we   = 1'b1;
            alu_src  = 1'b1;
            alu_op   = 4'd11;       // LUI / PASS_SRC2
            imm_type = 3'd1;        // 20 位高位移位立即数
        end
        else if (op_31_26 == 6'b001010) begin
            // ld.w (从存储器加载字)
            reg_we   = 1'b1;
            alu_src  = 1'b1;        // 地址计算 rs1 + imm12
            alu_op   = 4'd0;        // ADD
            mem_re   = 1'b1;
            wb_sel   = 2'd1;        // 存储器读数据写回
            imm_type = 3'd0;
        end
        else if (op_31_26 == 6'b001011) begin
            // st.w (存储字到存储器)
            reg_we   = 1'b0;
            alu_src  = 1'b1;        // 地址计算 rs1 + imm12
            alu_op   = 4'd0;        // ADD
            mem_we   = 1'b1;
            imm_type = 3'd0;
        end
        else if (op_31_26 == 6'b011000) begin
            // beq (相等则跳转)
            reg_we   = 1'b0;
            br_type  = 3'd1;        // BEQ 分支
            imm_type = 3'd2;        // 16 位偏移立即数 offs16
        end
        else if (op_31_26 == 6'b011001) begin
            // bne (不等则跳转)
            reg_we   = 1'b0;
            br_type  = 3'd2;        // BNE 分支
            imm_type = 3'd2;        // 16 位偏移立即数 offs16
        end
        else if (op_31_26 == 6'b010100) begin
            // b (无条件直接跳转)
            reg_we   = 1'b0;
            br_type  = 3'd3;        // B 无条件直接跳转
            imm_type = 3'd3;        // 26 位偏移立即数 offs26
        end
        else if (op_31_26 == 6'b010011) begin
            // jirl (跳转并连接寄存器)
            reg_we   = 1'b1;        // 写入返回地址 PC+4 到 rd
            wb_sel   = 2'd2;        // 写回 PC+4
            br_type  = 3'd4;        // JIRL 跳转
            imm_type = 3'd2;        // 16 位偏移立即数 offs16
        end
    end

endmodule
