`timescale 1ns / 1ps

// =========================================================================
// 模块名称：soc_fpga_top (Xilinx Artix-7 FPGA 物理上板顶层模块)
// 功能描述：将 longxin_soc_top 与物理片上存储器 (axi_ram_uart) 集成，
//          内置两级异步复位同步释放电路 (遵守五戒之五)、
//          真正物理可上板的 UART 串口发送器 (TX Serializer, 115200 Baud)、
//          以及硬件 LED/数码管状态指示与跑分输出逻辑。
// =========================================================================
module soc_fpga_top #(
    parameter SYS_CLK_FREQ = 50_000_000, // 默认物理晶振输入主频 50MHz
    parameter UART_BAUD    = 115_200     // 串口波特率 115200
)(
    input  wire       clk_50m,      // FPGA 板载 50MHz 时钟输入
    input  wire       btn_reset_n,  // FPGA 板载低电平按键复位

    // 物理 UART TX 输出引脚 (接 PC CH340 串口转换芯片)
    output wire       uart_tx,

    // 板载状态与测试评测指示灯 (8 个 LED)
    // led[0]: 系统正常工作电源灯
    // led[1]: CPU 运行心跳灯 (每 2^24 周期翻转)
    // led[2]: L1 I-Cache 命中指示灯
    // led[3]: L1 D-Cache 命中指示灯
    // led[7:4]: CPU 运算阶段与评测跑分高四位展示
    output reg  [7:0] led
);

    // =========================================================================
    // 1. 异步复位，同步释放电路 (Asynchronous Reset, Synchronous Release)
    // =========================================================================
    reg [1:0] rst_sync_reg;
    always @(posedge clk_50m or negedge btn_reset_n) begin
        if (!btn_reset_n) begin
            rst_sync_reg <= 2'b00;
        end else begin
            rst_sync_reg <= {rst_sync_reg[0], 1'b1};
        end
    end
    wire sys_rst_n = rst_sync_reg[1];

    // =========================================================================
    // 2. AXI4 总线互联信号
    // =========================================================================
    wire [31:0] araddr;
    wire [7:0]  arlen;
    wire [2:0]  arsize;
    wire [1:0]  arburst;
    wire        arvalid;
    wire        arready;

    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rlast;
    wire        rvalid;
    wire        rready;

    wire [31:0] awaddr;
    wire [7:0]  awlen;
    wire [2:0]  awsize;
    wire [1:0]  awburst;
    wire        awvalid;
    wire        awready;

    wire [31:0] wdata;
    wire [3:0]  wstrb;
    wire        wlast;
    wire        wvalid;
    wire        wready;

    wire [1:0]  bresp;
    wire        bvalid;
    wire        bready;

    // 串口字符写入触发接口
    wire        uart_tx_en;
    wire [7:0]  uart_tx_char;

    // =========================================================================
    // 3. 实例化 CPU + L1 Cache + AXI4 Master 体系结构顶层
    // =========================================================================
    longxin_soc_top u_soc_top (
        .clk     (clk_50m),
        .rst_n   (sys_rst_n),
        .araddr  (araddr),
        .arlen   (arlen),
        .arsize  (arsize),
        .arburst (arburst),
        .arvalid (arvalid),
        .arready (arready),
        .rdata   (rdata),
        .rresp   (rresp),
        .rlast   (rlast),
        .rvalid  (rvalid),
        .rready  (rready),
        .awaddr  (awaddr),
        .awlen   (awlen),
        .awsize  (awsize),
        .awburst (awburst),
        .awvalid (awvalid),
        .awready (awready),
        .wdata   (wdata),
        .wstrb   (wstrb),
        .wlast   (wlast),
        .wvalid  (wvalid),
        .wready  (wready),
        .bresp   (bresp),
        .bvalid  (bvalid),
        .bready  (bready)
    );

    // =========================================================================
    // 4. 实例化片上存储与 UART 外设总线从设备 (Slave IP)
    // =========================================================================
    axi_ram_uart u_axi_ram_uart (
        .clk          (clk_50m),
        .rst_n        (sys_rst_n),
        .araddr       (araddr),
        .arlen        (arlen),
        .arsize       (arsize),
        .arburst      (arburst),
        .arvalid      (arvalid),
        .arready      (arready),
        .rdata        (rdata),
        .rresp        (rresp),
        .rlast        (rlast),
        .rvalid       (rvalid),
        .rready       (rready),
        .awaddr       (awaddr),
        .awlen        (awlen),
        .awsize       (awsize),
        .awburst      (awburst),
        .awvalid      (awvalid),
        .awready      (awready),
        .wdata        (wdata),
        .wstrb        (wstrb),
        .wlast        (wlast),
        .wvalid       (wvalid),
        .wready       (wready),
        .bresp        (bresp),
        .bvalid       (bvalid),
        .bready       (bready),
        .uart_tx_en   (uart_tx_en),
        .uart_tx_char (uart_tx_char)
    );

    // =========================================================================
    // 5. 硬件物理串口发送引擎 (UART Transmitter IP)
    //    波特率生成器与异步位序列发包逻辑 (1 起始位 + 8 数据位 + 1 停止位)
    // =========================================================================
    localparam CLKS_PER_BIT = SYS_CLK_FREQ / UART_BAUD;

    reg [15:0] clk_cnt;
    reg [3:0]  bit_idx;
    reg [9:0]  tx_shift_reg;
    reg        tx_busy;

    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            clk_cnt      <= 16'd0;
            bit_idx      <= 4'd0;
            tx_shift_reg <= 10'b1111111111;
            tx_busy      <= 1'b0;
        end else begin
            if (!tx_busy) begin
                if (uart_tx_en) begin
                    // 锁存发送序列：停止位(1) + 8bit数据 + 起始位(0)
                    tx_shift_reg <= {1'b1, uart_tx_char, 1'b0};
                    tx_busy      <= 1'b1;
                    clk_cnt      <= 16'd0;
                    bit_idx      <= 4'd0;
                end
            end else begin
                if (clk_cnt < CLKS_PER_BIT - 1) begin
                    clk_cnt <= clk_cnt + 16'd1;
                end else begin
                    clk_cnt <= 16'd0;
                    if (bit_idx < 4'd9) begin
                        bit_idx      <= bit_idx + 4'd1;
                        tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end
            end
        end
    end

    assign uart_tx = tx_shift_reg[0];

    // =========================================================================
    // 6. 运行状态、心跳指示与评测跑分硬件监控灯
    // =========================================================================
    reg [23:0] heartbeat_cnt;
    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            heartbeat_cnt <= 24'd0;
            led           <= 8'h01; // 电源正常点亮
        end else begin
            heartbeat_cnt <= heartbeat_cnt + 24'd1;
            led[0] <= 1'b1;                         // 系统工作电源灯
            led[1] <= heartbeat_cnt[23];            // CPU 运行心跳灯
            led[2] <= u_soc_top.icache_hit;         // I-Cache 实时命中状态
            led[3] <= u_soc_top.dcache_hit;         // D-Cache 实时命中状态
            if (uart_tx_en) begin
                led[7:4] <= uart_tx_char[3:0];      // 显示串口最近传出字符低四位状态
            end
        end
    end

endmodule
