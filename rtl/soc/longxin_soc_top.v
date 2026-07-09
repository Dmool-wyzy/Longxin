`timescale 1ns / 1ps

// =========================================================================
// 模块名称：longxin_soc_top (龙芯杯大赛体系架构与 SoC 顶层整合模块)
// 功能描述：将 5 级流水线内核、8KB L1 I-Cache、8KB L1 D-Cache 以及标准
//          AMBA AXI4 总线桥接控制器完美融合为一体！
// =========================================================================
module longxin_soc_top (
    input  wire         clk,
    input  wire         rst_n,

    // =========================================================================
    // 标准 AXI4 Master 接口对外引脚
    // =========================================================================
    // AR 读地址通道
    output wire [31:0]  araddr,
    output wire [7:0]   arlen,
    output wire [2:0]   arsize,
    output wire [1:0]   arburst,
    output wire         arvalid,
    input  wire         arready,

    // R 读数据通道
    input  wire [31:0]  rdata,
    input  wire [1:0]   rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,

    // AW 写地址通道
    output wire [31:0]  awaddr,
    output wire [7:0]   awlen,
    output wire [2:0]   awsize,
    output wire [1:0]   awburst,
    output wire         awvalid,
    input  wire         awready,

    // W 写数据通道
    output wire [31:0]  wdata,
    output wire [3:0]   wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,

    // B 写响应通道
    input  wire [1:0]   bresp,
    input  wire         bvalid,
    output wire         bready
);

    // =========================================================================
    // 内核与 Cache 交互连线
    // =========================================================================
    wire [31:0] core_imem_addr;
    wire [31:0] core_imem_data;
    wire        icache_hit;
    wire        icache_stall;

    wire        core_dmem_we;
    wire        core_dmem_re;
    wire [31:0] core_dmem_addr;
    wire [31:0] core_dmem_wdata;
    wire [31:0] core_dmem_rdata;
    wire        dcache_hit;
    wire        dcache_stall;

    wire        ext_stall = icache_stall | dcache_stall;

    // Cache 与 AXI 总线桥接连线
    wire        icache_bus_req;
    wire [31:0] icache_bus_addr;
    wire [255:0] icache_bus_rline;
    wire        icache_bus_ready;

    wire        dcache_bus_rreq;
    wire [31:0] dcache_bus_raddr;
    wire [255:0] dcache_bus_rline;
    wire        dcache_bus_rready;

    wire        dcache_bus_wreq;
    wire [31:0] dcache_bus_waddr;
    wire [31:0] dcache_bus_wdata;
    wire        dcache_bus_wready;

    // =========================================================================
    // 1. 龙芯架构 5 级流水线核心
    // =========================================================================
    pipelined_core_top u_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .imem_addr (core_imem_addr),
        .imem_data (core_imem_data),
        .dmem_we   (core_dmem_we),
        .dmem_re   (core_dmem_re),
        .dmem_addr (core_dmem_addr),
        .dmem_wdata(core_dmem_wdata),
        .dmem_rdata(core_dmem_rdata),
        .ext_stall (ext_stall)
    );

    // =========================================================================
    // 2. L1 指令高速缓存 (8KB Direct-Mapped I-Cache)
    // =========================================================================
    icache #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (32),
        .CACHE_LINES(256)
    ) u_icache (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_req   (1'b1), // CPU 持续发指令取指请求
        .cpu_addr  (core_imem_addr),
        .cpu_rdata (core_imem_data),
        .cpu_hit   (icache_hit),
        .cpu_stall (icache_stall),
        .bus_req   (icache_bus_req),
        .bus_addr  (icache_bus_addr),
        .bus_rline (icache_bus_rline),
        .bus_ready (icache_bus_ready)
    );

    // =========================================================================
    // 3. L1 数据高速缓存 (8KB Direct-Mapped D-Cache + Write-Through)
    // =========================================================================
    dcache #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (32),
        .CACHE_LINES(256)
    ) u_dcache (
        .clk       (clk),
        .rst_n     (rst_n),
        .cpu_re    (core_dmem_re),
        .cpu_we    (core_dmem_we),
        .cpu_addr  (core_dmem_addr),
        .cpu_wdata (core_dmem_wdata),
        .cpu_rdata (core_dmem_rdata),
        .cpu_hit   (dcache_hit),
        .cpu_stall (dcache_stall),
        .bus_rreq  (dcache_bus_rreq),
        .bus_raddr (dcache_bus_raddr),
        .bus_rline (dcache_bus_rline),
        .bus_rready(dcache_bus_rready),
        .bus_wreq  (dcache_bus_wreq),
        .bus_waddr (dcache_bus_waddr),
        .bus_wdata (dcache_bus_wdata),
        .bus_wready(dcache_bus_wready)
    );

    // =========================================================================
    // 4. AMBA AXI4 Master 总线控制接口
    // =========================================================================
    axi_master_if u_axi_master (
        .clk           (clk),
        .rst_n         (rst_n),
        .icache_req    (icache_bus_req),
        .icache_addr   (icache_bus_addr),
        .icache_rline  (icache_bus_rline),
        .icache_ready  (icache_bus_ready),
        .dcache_rreq   (dcache_bus_rreq),
        .dcache_raddr  (dcache_bus_raddr),
        .dcache_rline  (dcache_bus_rline),
        .dcache_rready (dcache_bus_rready),
        .dcache_wreq   (dcache_bus_wreq),
        .dcache_waddr  (dcache_bus_waddr),
        .dcache_wdata  (dcache_bus_wdata),
        .dcache_wready (dcache_bus_wready),
        .araddr        (araddr),
        .arlen         (arlen),
        .arsize        (arsize),
        .arburst       (arburst),
        .arvalid       (arvalid),
        .arready       (arready),
        .rdata         (rdata),
        .rresp         (rresp),
        .rlast         (rlast),
        .rvalid        (rvalid),
        .rready        (rready),
        .awaddr        (awaddr),
        .awlen         (awlen),
        .awsize        (awsize),
        .awburst       (awburst),
        .awvalid       (awvalid),
        .awready       (awready),
        .wdata         (wdata),
        .wstrb         (wstrb),
        .wlast         (wlast),
        .wvalid        (wvalid),
        .wready        (wready),
        .bresp         (bresp),
        .bvalid        (bvalid),
        .bready        (bready)
    );

endmodule
