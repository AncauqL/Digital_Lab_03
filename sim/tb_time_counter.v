`timescale 1ns / 1ps

// 仿真目标：
// 1. 验证秒个位 0~9 循环，并向秒十位进位
// 2. 用校时输入快速设置到 23:59:58
// 3. 再给两个 tick，观察 23:59:59 -> 00:00:00
module tb_time_counter;
    reg clk;
    reg rst;
    reg tick_1Hz;
    reg set_mode;
    reg [2:0] set_sel;
    reg inc_pulse;
    reg dec_pulse;
    reg [7:0] phase;

    wire [3:0] sec_0;
    wire [3:0] sec_1;
    wire [3:0] min_0;
    wire [3:0] min_1;
    wire [3:0] hour_0;
    wire [3:0] hour_1;
    wire hour_tick;

    time_counter uut (
        .clk(clk),
        .rst(rst),
        .tick_1Hz(tick_1Hz),
        .set_mode(set_mode),
        .set_sel(set_sel),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),
        .sec_0(sec_0),
        .sec_1(sec_1),
        .min_0(min_0),
        .min_1(min_1),
        .hour_0(hour_0),
        .hour_1(hour_1),
        .hour_tick(hour_tick)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk; // 100MHz 时钟，周期 10ns

    task one_tick;
    begin
        @(negedge clk);
        tick_1Hz = 1'b1;
        @(negedge clk);
        tick_1Hz = 1'b0;
        @(negedge clk);
    end
    endtask

    task one_inc;
    begin
        @(negedge clk);
        inc_pulse = 1'b1;
        @(negedge clk);
        inc_pulse = 1'b0;
        @(negedge clk);
    end
    endtask

    task set_digit_by_inc;
        input [2:0] sel;
        input integer times;
        integer i;
    begin
        set_sel = sel;
        for (i = 0; i < times; i = i + 1)
            one_inc;
    end
    endtask

    integer k;

    initial begin
        rst = 1'b1;
        tick_1Hz = 1'b0;
        set_mode = 1'b0;
        set_sel = 3'd0;
        inc_pulse = 1'b0;
        dec_pulse = 1'b0;
        phase = 8'd0;

        repeat (3) @(negedge clk);
        rst = 1'b0;

        // 第一段：从 00:00:00 正常数 12 秒，看秒个位和秒十位进位
        phase = 8'd1;
        for (k = 0; k < 12; k = k + 1)
            one_tick;

        // 第二段：进入校时模式，快速调到 23:59:58
        phase = 8'd2;
        set_mode = 1'b1;
        set_digit_by_inc(3'd5, 2); // hour_1 = 2
        set_digit_by_inc(3'd4, 3); // hour_0 = 3
        set_digit_by_inc(3'd3, 5); // min_1 = 5
        set_digit_by_inc(3'd2, 9); // min_0 = 9
        set_digit_by_inc(3'd1, 5); // sec_1 = 5
        set_digit_by_inc(3'd0, 8); // sec_0 = 8

        // 第三段：退出校时，观察 23:59:58 后的两次计时
        phase = 8'd3;
        set_mode = 1'b0;
        set_sel = 3'd0;
        repeat (3) @(negedge clk);
        one_tick; // 23:59:58 -> 23:59:59
        one_tick; // 23:59:59 -> 00:00:00，同时 hour_tick 有效

        phase = 8'd4;
        repeat (5) @(negedge clk);
        $finish;
    end
endmodule
