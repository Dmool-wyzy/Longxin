`timescale 1ns / 1ps

module alu (
    input  wire [3:0]  alu_op,    // 4位操作码
    input  wire [31:0] src1,      // 32位源操作数1
    input  wire [31:0] src2,      // 32位源操作数2
    output reg  [31:0] alu_res    // 32位计算输出结果
);

    //组合电路逻辑计算
    always @(*) begin
        alu_res = 32'd0;
        case (alu_op)
            //1.基础算术运算
            4'd0: alu_res = src1 + src2;                     //ADD：加法
            4'd1: alu_res = src1 - src2;                     //SUB：减法
            
            //2.逻辑大小比较
            4'd2: alu_res = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; //SLT ：有符号比较
            4'd3: alu_res = (src1 < src2) ? 32'd1 : 32'd0;                   //SLTU：无符号比较

            //3.逻辑按位运算
            4'd4: alu_res = src1 & src2;                     //AND：按位与
            4'd5: alu_res = src1 | src2;                     //OR ：按位或
            4'd6: alu_res = src1 ^ src2;                     //XOR：按位异或
            4'd7: alu_res = ~(src1 | src2);                  //NOR：按位或非

            //4.移位运算
            4'd8:  alu_res = src1 << src2[4:0];              //SLL：逻辑左移
            4'd9:  alu_res = src1 >> src2[4:0];              //SRL：逻辑右移
            4'd10: alu_res = $signed(src1) >>> src2[4:0];    //SRA：算术右移

            //5.直接传递源操作数2 (对应 lu12i.w 等立即数指令)
            4'd11: alu_res = src2;                           //LUI / PASS_SRC2

            default: alu_res = 32'd0;                        //防止锁存器 (Latch)
        endcase
    end

endmodule
