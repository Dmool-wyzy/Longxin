`timescale 1ns / 1ps

// =========================================================================
// 模块名称：axi_master_if (工业级标准 AMBA AXI4 总线桥接与仲裁单元)
// 功能描述：将 I-Cache 与 D-Cache 的读取补行、写入请求高效转换为 AXI4 协议。
//          严格遵守工业界铁律：VALID 信号无条件发起，绝不等待 READY 拉高！
//          内置读写仲裁与 32B 突发传输 (Burst 8 beats) 接收组包。
// =========================================================================
module axi_master_if (
    input  wire         clk,
    input  wire         rst_n,

    // --- I-Cache 接口 ---
    input  wire         icache_req,
    input  wire [31:0]  icache_addr,
    output reg  [255:0] icache_rline,
    output reg          icache_ready,

    // --- D-Cache 读接口 ---
    input  wire         dcache_rreq,
    input  wire [31:0]  dcache_raddr,
    output reg  [255:0] dcache_rline,
    output reg          dcache_rready,

    // --- D-Cache 写接口 ---
    input  wire         dcache_wreq,
    input  wire [31:0]  dcache_waddr,
    input  wire [31:0]  dcache_wdata,
    output reg          dcache_wready,

    // =========================================================================
    // AMBA AXI4 Master 接口定义
    // =========================================================================
    // 1. 读地址通道 (AR Channel)
    output reg  [31:0]  araddr,
    output reg  [7:0]   arlen,      // 7 表示突发传输 8 次
    output reg  [2:0]   arsize,     // 3'b010 表示 4 Bytes
    output reg  [1:0]   arburst,    // 2'b01 表示 INCR 递增
    output reg          arvalid,
    input  wire         arready,

    // 2. 读数据通道 (R Channel)
    input  wire [31:0]  rdata,
    input  wire [1:0]   rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,

    // 3. 写地址通道 (AW Channel)
    output reg  [31:0]  awaddr,
    output reg  [7:0]   awlen,      // 0 表示突发 1 次 (单字直写)
    output reg  [2:0]   awsize,     // 3'b010 表示 4 Bytes
    output reg  [1:0]   awburst,    // 2'b01
    output reg          awvalid,
    input  wire         awready,

    // 4. 写数据通道 (W Channel)
    output reg  [31:0]  wdata,
    output reg  [3:0]   wstrb,      // 4'b1111
    output reg          wlast,
    output reg          wvalid,
    input  wire         wready,

    // 5. 写响应通道 (B Channel)
    input  wire [1:0]   bresp,
    input  wire         bvalid,
    output wire         bready
);

    // R / B 通道主设备无条件准备接收
    assign rready = 1'b1;
    assign bready = 1'b1;

    // =========================================================================
    // 读通道仲裁与处理状态机
    // =========================================================================
    localparam AR_IDLE     = 2'd0;
    localparam AR_SEND_REQ = 2'd1;
    localparam AR_WAIT_BEAT= 2'd2;

    reg [1:0] ar_state, ar_next_state;
    reg       ar_target; // 0: I-Cache, 1: D-Cache
    reg [2:0] beat_cnt;
    reg [255:0] line_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ar_state <= AR_IDLE;
        else        ar_state <= ar_next_state;
    end

    always @(*) begin
        ar_next_state = ar_state;
        case (ar_state)
            AR_IDLE: begin
                if (dcache_rreq || icache_req) ar_next_state = AR_SEND_REQ;
            end
            AR_SEND_REQ: begin
                if (arvalid && arready) ar_next_state = AR_WAIT_BEAT;
            end
            AR_WAIT_BEAT: begin
                if (rvalid && rlast) ar_next_state = AR_IDLE;
            end
            default: ar_next_state = AR_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arvalid      <= 1'b0;
            araddr       <= 32'd0;
            arlen        <= 8'd7;
            arsize       <= 3'b010;
            arburst      <= 2'b01;
            ar_target    <= 1'b0;
            beat_cnt     <= 3'd0;
            line_buf     <= 256'd0;
            icache_ready <= 1'b0;
            dcache_rready<= 1'b0;
        end else begin
            icache_ready <= 1'b0;
            dcache_rready<= 1'b0;

            case (ar_state)
                AR_IDLE: begin
                    beat_cnt <= 3'd0;
                    if (dcache_rreq) begin
                        arvalid   <= 1'b1; // 工业铁律：无条件拉高 VALID
                        araddr    <= dcache_raddr;
                        ar_target <= 1'b1; // 优先服务数据 Cache
                    end else if (icache_req) begin
                        arvalid   <= 1'b1;
                        araddr    <= icache_addr;
                        ar_target <= 1'b0;
                    end
                end
                AR_SEND_REQ: begin
                    if (arvalid && arready) begin
                        arvalid <= 1'b0;   // 握手完成后方可撤回 VALID
                    end
                end
                AR_WAIT_BEAT: begin
                    if (rvalid) begin
                        case (beat_cnt)
                            3'd0: line_buf[31:0]    <= rdata;
                            3'd1: line_buf[63:32]   <= rdata;
                            3'd2: line_buf[95:64]   <= rdata;
                            3'd3: line_buf[127:96]  <= rdata;
                            3'd4: line_buf[159:128] <= rdata;
                            3'd5: line_buf[191:160] <= rdata;
                            3'd6: line_buf[223:192] <= rdata;
                            3'd7: line_buf[255:224] <= rdata;
                        endcase
                        beat_cnt <= beat_cnt + 3'd1;

                        if (rlast) begin
                            if (ar_target == 1'b0) begin
                                icache_rline <= {rdata, line_buf[223:0]};
                                icache_ready <= 1'b1;
                            end else begin
                                dcache_rline <= {rdata, line_buf[223:0]};
                                dcache_rready<= 1'b1;
                            end
                        end
                    end
                end
                default: ;
            endcase
        end
    end

    // =========================================================================
    // 写通道状态机
    // =========================================================================
    localparam AW_IDLE     = 2'd0;
    localparam AW_SEND     = 2'd1;
    localparam AW_WAIT_B   = 2'd2;

    reg [1:0] aw_state, aw_next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) aw_state <= AW_IDLE;
        else        aw_state <= aw_next_state;
    end

    always @(*) begin
        aw_next_state = aw_state;
        case (aw_state)
            AW_IDLE:   if (dcache_wreq) aw_next_state = AW_SEND;
            AW_SEND:   if (((awvalid && awready) || !awvalid) && ((wvalid && wready) || !wvalid)) aw_next_state = AW_WAIT_B;
            AW_WAIT_B: if (bvalid) aw_next_state = AW_IDLE;
            default:   aw_next_state = AW_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awvalid       <= 1'b0;
            awaddr        <= 32'd0;
            awlen         <= 8'd0;
            awsize        <= 3'b010;
            awburst       <= 2'b01;
            wvalid        <= 1'b0;
            wdata         <= 32'd0;
            wstrb         <= 4'b1111;
            wlast         <= 1'b1;
            dcache_wready <= 1'b0;
        end else begin
            dcache_wready <= 1'b0;

            case (aw_state)
                AW_IDLE: begin
                    if (dcache_wreq) begin
                        awvalid <= 1'b1;
                        awaddr  <= dcache_waddr;
                        wvalid  <= 1'b1;
                        wdata   <= dcache_wdata;
                        wlast   <= 1'b1;
                        $display("[AXI_MST] AW_IDLE -> AW_SEND waddr=%h wdata=%h time=%0t", dcache_waddr, dcache_wdata, $time);
                    end
                end
                AW_SEND: begin
                    if (awvalid && awready) awvalid <= 1'b0;
                    if (wvalid && wready)   wvalid  <= 1'b0;
                end
                AW_WAIT_B: begin
                    if (bvalid) begin
                        dcache_wready <= 1'b1;
                        $display("[AXI_MST] AW_WAIT_B -> AW_IDLE time=%0t", $time);
                    end
                end
                default: ;
            endcase
        end
    end

endmodule
