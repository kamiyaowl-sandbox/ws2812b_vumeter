module ws2812b_meter_ioctrl ();
    parameter DELAY = 1;
    parameter CLK_PERIOD_NS = 10;
    parameter COLOR_N = 3;

    reg clk;
    reg reset_n;
    reg enable;
    wire DOUT;
    reg [23:0] colors [0:COLOR_N];
    reg [15:0] visibleCounts [0:COLOR_N];
    reg [15:0] onCount;
    reg [15:0] maxCount;

    ws2812b_meter_ioctrl u1 (
        .clk(clk),
        .reset_n(reset_n),
        .enable(enable),
        .DOUT(DOUT),
        .colors(colors),
        .visibleCounts(visibleCounts),
        .onCount(onCount),
        .maxCount(maxCount),
    );

    // clk gen
    parameter CLK_HALF_PERIOD_NS = (CLK_PERIOD_NS/2);
    always begin
        clk = 0;
        #CLK_HALF_PERIOD_NS;
        clk = 1;
        #CLK_HALF_PERIOD_NS;
    end;

    initial begin
        reset_n = 0;
        enable = 0;
        colors[0] = 24'habcdef;
        colors[1] = 24'h123456;
        colors[2] = 24'h2468ac;
        visibleCounts[0] = 20;
        visibleCounts[1] = 10;
        visibleCounts[2] = 5;
        onCount = 0;
        maxCount = 50;
        #100000;

        reset_n = 1;
        #1000;

        onCount = 0;
        enable  = 1;
        #1000000;

        onCount = 10;
        enable  = 1;
        #1000000;

        onCount = 20;
        enable  = 1;
        #1000000;

        onCount = 25;
        enable  = 1;
        #1000000;

        onCount = 30;
        enable  = 1;
        #1000000;

        onCount = 35;
        enable  = 1;
        #1000000;

        onCount = 40;
        enable  = 1;
        #1000000;

        onCount = 50;
        enable  = 1;
        #1000000;

        onCount = 60;
        enable  = 1;
        #1000000;

        onCount = 60;
        enable  = 0;
        #1000000;

    end

endmodule
