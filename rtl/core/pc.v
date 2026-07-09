`timescale 1ns / 1ps

// =========================================================================
// 模块名称：pc (程序计数器 Program Counter)
// 功能描述：管理 32 位程序计数器 PC，支持异步低电平复位（默认复位到 0x1C000000）、
//          正常累加 (+4)、分支/跳转定向，以及为多级流水线预留的暂停 (Stall) 功能。
// =========================================================================
module pc (
    input  wire        clk,        // 系统时钟
    input  wire        rst_n,      // 低电平异步复位信号 (0 为复位有效)
    input  wire        stall,      // 流水线暂停控制 (1 为暂停，保持 PC 不变)
    input  wire        br_taken,   // 分支/跳转跳转生效标记 (1 为跳转)
    input  wire [31:0] br_target,  // 分支/跳转目标地址
    output reg  [31:0] pc          // 32位 PC 地址输出
);

    // 时钟同步触发器：PC 寄存器状态更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h1C000000;    // LoongArch 典型复位启动地址
        end else if (stall) begin
            pc <= pc;              // 流水线暂停，PC 保持不动
        end else if (br_taken) begin
            pc <= br_target;       // 分支或跳转指令命中，加载目标地址
        end else begin
            pc <= pc + 32'h4;      // 正常取指，PC + 4 (每个字 4 字节)
        end
    end

endmodule
