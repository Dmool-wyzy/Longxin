`timescale 1ns / 1ps

// =========================================================================
// 模块名称：dcache (8KB 直接映射数据高速缓存 L1 D-Cache)
// 功能描述：实现 8KB 容量、32B 缓存行的直接映射 D-Cache。
//          读取缺失时向总线申请 32B 整行补回；
//          写入采用直写 (Write-Through) 策略，同步更新缓存行并发往总线写通道。
// =========================================================================
module dcache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_LINES = 256
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // CPU 侧访存接口
    input  wire                  cpu_re,      // 读使能
    input  wire                  cpu_we,      // 写使能
    input  wire [ADDR_WIDTH-1:0] cpu_addr,    // 访存物理地址
    input  wire [DATA_WIDTH-1:0] cpu_wdata,   // 写数据
    output reg  [DATA_WIDTH-1:0] cpu_rdata,   // 读数据
    output wire                  cpu_hit,     // 读写命中信号
    output wire                  cpu_stall,   // 暂停请求

    // AXI 总线读通道 (整行补回)
    output reg                   bus_rreq,    // 读请求
    output reg  [ADDR_WIDTH-1:0] bus_raddr,   // 读地址 (32B对齐)
    input  wire [255:0]          bus_rline,   // 返回行数据
    input  wire                  bus_rready,  // 读完成信号

    // AXI 总线写通道 (直写单字)
    output reg                   bus_wreq,    // 写请求
    output reg  [ADDR_WIDTH-1:0] bus_waddr,   // 写地址
    output reg  [DATA_WIDTH-1:0] bus_wdata,   // 写数据
    input  wire                  bus_wready   // 写完成握手
);

    reg [18:0] tag_ram   [0:CACHE_LINES-1];
    reg        valid_ram [0:CACHE_LINES-1];
    reg [31:0] data_ram  [0:CACHE_LINES-1][0:7];

    wire [18:0] req_tag    = cpu_addr[31:13];
    wire [7:0]  req_idx    = cpu_addr[12:5];
    wire [2:0]  req_offset = cpu_addr[4:2];

    wire line_valid = valid_ram[req_idx];
    wire tag_match  = (tag_ram[req_idx] == req_tag);

    // 读操作判定：有效且标签匹配
    wire read_hit   = cpu_re & line_valid & tag_match;
    // 写操作直写判定：写操作发起时判断缓冲行是否匹配
    wire write_hit  = cpu_we & line_valid & tag_match;

    assign cpu_hit   = read_hit | (cpu_we & bus_wready);

    localparam S_IDLE       = 2'b00;
    localparam S_READ_MISS  = 2'b01;
    localparam S_WRITE_BUS  = 2'b10;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= S_IDLE;
        else        state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (cpu_re && !read_hit) begin
                    next_state = S_READ_MISS;
                end else if (cpu_we && !bus_wready) begin
                    next_state = S_WRITE_BUS;
                end
            end
            S_READ_MISS: begin
                if (bus_rready) next_state = S_IDLE;
            end
            S_WRITE_BUS: begin
                if (bus_wready) next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    assign cpu_stall = (cpu_re && !read_hit) || (cpu_we && !(state == S_WRITE_BUS && bus_wready));

    always @(*) begin
        bus_rreq  = (state == S_READ_MISS);
        bus_raddr = {cpu_addr[31:5], 5'b0};

        bus_wreq  = (cpu_we && state == S_IDLE) || (state == S_WRITE_BUS);
        bus_waddr = cpu_addr;
        bus_wdata = cpu_wdata;

        cpu_rdata = data_ram[req_idx][req_offset];
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < CACHE_LINES; i = i + 1) begin
                valid_ram[i] <= 1'b0;
                tag_ram[i]   <= 19'd0;
            end
        end else begin
            if (cpu_we) $display("[DCACHE_REQ] WE addr=%h wdata=%h time=%0t", cpu_addr, cpu_wdata, $time);
            if (cpu_re) $display("[DCACHE_REQ] RE addr=%h time=%0t", cpu_addr, $time);
            if (state == S_READ_MISS && bus_rready) begin
                valid_ram[req_idx]   <= 1'b1;
                tag_ram[req_idx]     <= req_tag;
                data_ram[req_idx][0] <= bus_rline[31:0];
                data_ram[req_idx][1] <= bus_rline[63:32];
                data_ram[req_idx][2] <= bus_rline[95:64];
                data_ram[req_idx][3] <= bus_rline[127:96];
                data_ram[req_idx][4] <= bus_rline[159:128];
                data_ram[req_idx][5] <= bus_rline[191:160];
                data_ram[req_idx][6] <= bus_rline[223:192];
                data_ram[req_idx][7] <= bus_rline[255:224];
                $display("[DCACHE] REFILL idx=%0d word0=%h time=%0t", req_idx, bus_rline[31:0], $time);
            end else if (cpu_we && write_hit) begin
                data_ram[req_idx][req_offset] <= cpu_wdata;
            end
        end
    end

endmodule
