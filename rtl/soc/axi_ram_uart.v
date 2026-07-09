`timescale 1ns / 1ps

// =========================================================================
// 模块名称：axi_ram_uart (SoC 外部 AXI4 从设备存储器与串口控制器模型)
// 功能描述：模拟大赛物理开发板板载 DDR3/SRAM 与 UART 串口外设：
//          1. 支持 AXI4 AR 通道 8 拍突发读取缓存行；
//          2. 支持 AXI4 AW/W 通道写入；
//          3. 当写操作寻址到 UART 寄存器 (0x1FE40000 或 0xBFD003F8) 时，
//             实时向控制台打印字符日志！
// =========================================================================
module axi_ram_uart #(
    parameter MEM_SIZE = 4096 // 4096 * 32bit = 16KB 模拟存储空间
)(
    input  wire         clk,
    input  wire         rst_n,

    // AXI AR 通道
    input  wire [31:0]  araddr,
    input  wire [7:0]   arlen,
    input  wire [2:0]   arsize,
    input  wire [1:0]   arburst,
    input  wire         arvalid,
    output reg          arready,

    // AXI R 通道
    output reg  [31:0]  rdata,
    output reg  [1:0]   rresp,
    output reg          rlast,
    output reg          rvalid,
    input  wire         rready,

    // AXI AW 通道
    input  wire [31:0]  awaddr,
    input  wire [7:0]   awlen,
    input  wire [2:0]   awsize,
    input  wire [1:0]   awburst,
    input  wire         awvalid,
    output reg          awready,

    // AXI W 通道
    input  wire [31:0]  wdata,
    input  wire [3:0]   wstrb,
    input  wire         wlast,
    input  wire         wvalid,
    output reg          wready,

    // AXI B 通道
    output reg  [1:0]   bresp,
    output reg          bvalid,
    input  wire         bready
);

    // 物理 RAM 定义
    reg [31:0] ram [0:MEM_SIZE-1];

    // --- 读突发状态机 ---
    localparam R_IDLE = 1'b0;
    localparam R_BURST= 1'b1;

    reg       r_state;
    reg [31:0] cur_raddr;
    reg [7:0] cur_beat;
    reg [7:0] total_len;

    wire [31:0] word_idx = (cur_raddr - 32'h1C000000) >> 2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= R_IDLE;
            arready <= 1'b1;
            rvalid  <= 1'b0;
            rlast   <= 1'b0;
            rdata   <= 32'd0;
            rresp   <= 2'b00;
        end else begin
            case (r_state)
                R_IDLE: begin
                    rlast <= 1'b0;
                    if (arvalid && arready) begin
                        arready   <= 1'b0;
                        r_state   <= R_BURST;
                        cur_raddr <= araddr;
                        cur_beat  <= 8'd0;
                        total_len <= arlen;
                        rvalid    <= 1'b1;
                        // 取第一个字
                        rdata     <= ( ((araddr - 32'h1C000000) >> 2) < MEM_SIZE ) ? ram[(araddr - 32'h1C000000) >> 2] : 32'h03400000;
                        if (arlen == 8'd0) rlast <= 1'b1;
                    end
                end
                R_BURST: begin
                    if (rvalid && rready) begin
                        if (cur_beat == total_len) begin
                            rvalid  <= 1'b0;
                            rlast   <= 1'b0;
                            arready <= 1'b1;
                            r_state <= R_IDLE;
                        end else begin
                            cur_beat  <= cur_beat + 8'd1;
                            cur_raddr <= cur_raddr + 32'd4;
                            rdata     <= ( ((cur_raddr + 32'd4 - 32'h1C000000) >> 2) < MEM_SIZE ) ? ram[(cur_raddr + 32'd4 - 32'h1C000000) >> 2] : 32'h03400000;
                            if (cur_beat + 8'd1 == total_len) begin
                                rlast <= 1'b1;
                            end
                        end
                    end
                end
            endcase
        end
    end

    // --- 写通道处理 ---
    reg [31:0] lat_awaddr;
    reg        got_aw;
    reg        got_w;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready <= 1'b1;
            wready  <= 1'b1;
            bvalid  <= 1'b0;
            bresp   <= 2'b00;
            got_aw  <= 1'b0;
            got_w   <= 1'b0;
        end else begin
            if (bvalid && bready) begin
                bvalid <= 1'b0;
            end

            if (awvalid && awready) begin
                lat_awaddr <= awaddr;
                got_aw     <= 1'b1;
            end

            if (wvalid && wready) begin
                got_w <= 1'b1;
                // 判断写地址是否为 UART 串口输出映射地址 (0x1FE40000 或 0xBFD003F8)
                if ((got_aw ? lat_awaddr : awaddr) == 32'h1FE40000 ||
                    (got_aw ? lat_awaddr : awaddr) == 32'hBFD003F8) begin
                    $write("%c", wdata[7:0]); // 实时输出串口字符
                end else begin
                    // 写入 RAM
                    if ( ((got_aw ? lat_awaddr : awaddr) - 32'h1C000000) >> 2 < MEM_SIZE ) begin
                        ram[((got_aw ? lat_awaddr : awaddr) - 32'h1C000000) >> 2] <= wdata;
                        $display("[AXI_RAM] WRITE addr=%h idx=%0d data=%h time=%0t", (got_aw ? lat_awaddr : awaddr), ((got_aw ? lat_awaddr : awaddr) - 32'h1C000000) >> 2, wdata, $time);
                    end
                end
            end

            if ((got_aw || (awvalid && awready)) && (got_w || (wvalid && wready))) begin
                bvalid <= 1'b1;
                got_aw <= 1'b0;
                got_w  <= 1'b0;
            end
        end
    end

endmodule
