`timescale 1ns / 1ps

// 仿真目标：
// 给定一个固定时间 23:45:06，观察动态扫描时：
// scan 从 0 到 5 循环，an 位选依次变化，current_num 依次为 2,3,4,5,0,6
module tb_digit_display;
    reg clk;
    reg rst;
    reg tick_1kHz;

    wire [7:0] an;
    wire [6:0] seg;
    wire colon;

    wire [3:0] scan_dbg;
    wire [3:0] current_num_dbg;

    digit_display uut (
        .clk(clk),
        .rst(rst),
        .tick_1kHz(tick_1kHz),
        .sec_0(4'd6),
        .sec_1(4'd0),
        .min_0(4'd5),
        .min_1(4'd4),
        .hour_0(4'd3),
        .hour_1(4'd2),
        .an(an),
        .seg(seg),
        .colon(colon)
    );

    assign scan_dbg = uut.scan;
    assign current_num_dbg = uut.current_num;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task one_scan_tick;
    begin
        @(negedge clk);
        tick_1kHz = 1'b1;
        @(negedge clk);
        tick_1kHz = 1'b0;
        repeat (2) @(negedge clk);
    end
    endtask

    integer i;

    initial begin
        rst = 1'b1;
        tick_1kHz = 1'b0;
        repeat (3) @(negedge clk);
        rst = 1'b0;

        for (i = 0; i < 12; i = i + 1)
            one_scan_tick;

        repeat (5) @(negedge clk);
        $finish;
    end
endmodule
