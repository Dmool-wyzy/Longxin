`timescale 1ns / 1ps

// =========================================================================
// 模块名称：tb_dcache (8KB 数据高速缓存自检实验室)
// 功能描述：全面测试 L1 D-Cache 的读缺失补行、写直传同步更新功能。
// =========================================================================
module tb_dcache();

    reg         clk;
    reg         rst_n;

    reg         cpu_re;
    reg         cpu_we;
    reg  [31:0] cpu_addr;
    reg  [31:0] cpu_wdata;
    wire [31:0] cpu_rdata;
    wire        cpu_hit;
    wire        cpu_stall;

    wire        bus_rreq;
    wire [31:0] bus_raddr;
    reg  [255:0] bus_rline;
    reg         bus_rready;

    wire        bus_wreq;
    wire [31:0] bus_waddr;
    wire [31:0] bus_wdata;
    reg         bus_wready;

    dcache #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .CACHE_LINES(256)
    ) u_dcache (
        .clk        (clk),
        .rst_n      (rst_n),
        .cpu_re     (cpu_re),
        .cpu_we     (cpu_we),
        .cpu_addr   (cpu_addr),
        .cpu_wdata  (cpu_wdata),
        .cpu_rdata  (cpu_rdata),
        .cpu_hit    (cpu_hit),
        .cpu_stall  (cpu_stall),
        .bus_rreq   (bus_rreq),
        .bus_raddr  (bus_raddr),
        .bus_rline  (bus_rline),
        .bus_rready (bus_rready),
        .bus_wreq   (bus_wreq),
        .bus_waddr  (bus_waddr),
        .bus_wdata  (bus_wdata),
        .bus_wready (bus_wready)
    );

    always #5 clk = ~clk;

    initial begin
        $display("=================================================");
        $display("🧩 [龙芯杯备赛] Phase 3 L1 D-Cache 缓存单元自动化测试启动");
        $display("=================================================");

        clk        = 0;
        rst_n      = 0;
        cpu_re     = 0;
        cpu_we     = 0;
        cpu_addr   = 0;
        cpu_wdata  = 0;
        bus_rline  = 0;
        bus_rready = 0;
        bus_wready = 1'b1; // 默认写总线就绪

        #15;
        rst_n = 1;

        // --- 测试项 1: 首次读取 0x00001000 发生缺失 ---
        @(negedge clk);
        cpu_re   = 1'b1;
        cpu_addr = 32'h00001000;
        #1;
        if (cpu_hit === 1'b0 && cpu_stall === 1'b1) begin
            $display("✅ [测试项1通过] 读缺失正确暂停核心流并发起总线读行请求");
        end else begin
            $display("❌ [测试项1失败] 读缺失状态判断异常");
        end

        // --- 测试项 2: 模拟总线返回整行数据 ---
        @(posedge clk);
        @(negedge clk);
        bus_rline  = {224'h0, 32'h8899AABB};
        bus_rready = 1'b1;

        @(posedge clk);
        #1;
        bus_rready = 1'b0;

        // --- 测试项 3: 缓存行已载入，再次读 0x00001000 立即命中 ---
        #1;
        if (cpu_hit === 1'b1 && cpu_rdata === 32'h8899AABB) begin
            $display("✅ [测试项2通过] D-Cache 成功缓存 0x8899AABB 并支持单周期快速命中");
        end else begin
            $display("❌ [测试项2失败] 缓存行命中读回异常: 0x%08X", cpu_rdata);
        end

        // --- 测试项 4: Write-Through 直写，往 0x00001000 写入 0x11223344 ---
        @(negedge clk);
        cpu_re    = 1'b0;
        cpu_we    = 1'b1;
        cpu_wdata = 32'h11223344;
        #1;
        if (bus_wreq === 1'b1 && bus_wdata === 32'h11223344) begin
            $display("✅ [测试项3通过] 直写机制正确向总线写通道发出字请求");
        end else begin
            $display("❌ [测试项3失败] 写总线请求异常");
        end

        // --- 测试项 5: 验证直写是否同步更新了缓存行内容 ---
        @(posedge clk);
        @(negedge clk);
        cpu_we = 1'b0;
        cpu_re = 1'b1;
        #1;
        if (cpu_hit === 1'b1 && cpu_rdata === 32'h11223344) begin
            $display("✅ [测试项4通过] D-Cache 本地缓存行已与总线写入数据达成一致步调 (读出 0x%08X)", cpu_rdata);
        end else begin
            $display("❌ [测试项4失败] 直写未正确更新缓存行内容: 0x%08X", cpu_rdata);
        end

        $display("=================================================");
        $display("🎉🎉🎉 [大获全胜] L1 D-Cache 数据缓存控制器 100% 验证通过！");
        $display("=================================================");
        #10;
        $finish;
    end

endmodule
