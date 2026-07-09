`timescale 1ns / 1ps

// =========================================================================
// 模块名称：icache (8KB 直接映射指令高速缓存 L1 I-Cache)
// 功能描述：实现 8KB 容量、32B 缓存行 (256 行) 的直接映射 I-Cache。
//          支持命中时单周期零延迟指令吐出，缺失时暂停 CPU 申请总线补行。
// =========================================================================
module icache #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_LINES = 256         // 256 行 * 32B = 8KB
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // CPU 侧取指接口
    input  wire                  cpu_req,     // 取指请求使能
    input  wire [ADDR_WIDTH-1:0] cpu_addr,    // 取指地址 (字对齐)
    output reg  [DATA_WIDTH-1:0] cpu_rdata,   // 取回的指令编码
    output wire                  cpu_hit,     // 是否命中 (1:命中 0:缺失)
    output wire                  cpu_stall,   // 缺失引起的暂停流水线信号

    // AXI 总线侧接口 (请求补行)
    output reg                   bus_req,     // 向总线发起读取整行请求
    output reg  [ADDR_WIDTH-1:0] bus_addr,    // 32B 对齐的高速缓存行首地址
    input  wire [255:0]          bus_rline,   // 总线返回的整行数据 (8 * 32bit)
    input  wire                  bus_ready    // 总线补行完成握手信号
);

    // =========================================================================
    // Cache 存储体定义：Tag RAM、Valid RAM 与 Data RAM
    // 地址分解: [31:13] Tag (19位), [12:5] Index (8位), [4:2] Word Offset (3位)
    // =========================================================================
    reg [18:0] tag_ram   [0:CACHE_LINES-1];
    reg        valid_ram [0:CACHE_LINES-1];
    reg [31:0] data_ram  [0:CACHE_LINES-1][0:7];

    wire [18:0] req_tag    = cpu_addr[31:13];
    wire [7:0]  req_idx    = cpu_addr[12:5];
    wire [2:0]  req_offset = cpu_addr[4:2];

    // 组合逻辑命中查询
    wire line_valid = valid_ram[req_idx];
    wire tag_match  = (tag_ram[req_idx] == req_tag);
    assign cpu_hit   = cpu_req & line_valid & tag_match;
    assign cpu_stall = cpu_req & (~cpu_hit);

    // =========================================================================
    // 状态机编码定义
    // =========================================================================
    localparam S_IDLE   = 2'b00;
    localparam S_REFILL = 2'b01;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 状态转移逻辑
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (cpu_req && !cpu_hit) begin
                    next_state = S_REFILL;
                end
            end
            S_REFILL: begin
                if (bus_ready) begin
                    next_state = S_IDLE;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

    // =========================================================================
    // 组合输出控制
    // =========================================================================
    always @(*) begin
        bus_req   = (state == S_REFILL);
        bus_addr  = {cpu_addr[31:5], 5'b0};
        cpu_rdata = data_ram[req_idx][req_offset];
    end

    // =========================================================================
    // Cache 行填充时序更新逻辑
    // =========================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < CACHE_LINES; i = i + 1) begin
                valid_ram[i] <= 1'b0;
                tag_ram[i]   <= 19'd0;
            end
        end else if (state == S_REFILL && bus_ready) begin
            valid_ram[req_idx]    <= 1'b1;
            tag_ram[req_idx]      <= req_tag;
            data_ram[req_idx][0]  <= bus_rline[31:0];
            data_ram[req_idx][1]  <= bus_rline[63:32];
            data_ram[req_idx][2]  <= bus_rline[95:64];
            data_ram[req_idx][3]  <= bus_rline[127:96];
            data_ram[req_idx][4]  <= bus_rline[159:128];
            data_ram[req_idx][5]  <= bus_rline[191:160];
            data_ram[req_idx][6]  <= bus_rline[223:192];
            data_ram[req_idx][7]  <= bus_rline[255:224];
        end
    end

endmodule
