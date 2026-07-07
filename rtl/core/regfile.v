    `timescale 1ns / 1ps

    module regfile (
        input  wire        clk,      // 系统时钟
        input  wire        rst_n,    // 低电平异步复位信号 (0有效)

        // 写端口
        input  wire        we,       // 写使能 signal (1为允许写入)
        input  wire [4:0]  waddr,    // 5位写地址 (对应 $r0 ~ $r31)
        input  wire [31:0] wdata,    // 32位待写入的数据

        // 读端口 1
        input  wire [4:0]  raddr1,   // 5位读端口 1 地址
        output wire [31:0] rdata1,   // 32位读端口 1 输出数据

        // 读端口 2
        input  wire [4:0]  raddr2,   // 5位读端口 2 地址
        output wire [31:0] rdata2    // 32位读端口 2 输出数据
    );

        // 物理存储体声明
        reg [31:0] regs [0:31];      // 在芯片内部摆放32组触发器，每组容纳32比特

	// 异步组合逻辑读
	assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
	assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];

	// 时钟同步时序写与异步复位
	integer i;
	always @(posedge clk or negedge rst_n) begin
	    if (!rst_n) begin
		for (i = 0; i < 32; i = i + 1) begin
		    regs[i] <= 32'd0;
		end
	    end else if (we == 1'b1 && waddr != 5'd0) begin
		regs[waddr] <= wdata;
	    end
	end

    endmodule
