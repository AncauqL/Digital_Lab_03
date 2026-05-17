`timescale 1ns / 1ps

// 仿真目标：
// 1. 进入闹钟设置模式时，闹钟时间先复制当前时间
// 2. 调整闹钟秒个位，把 12:34:56 改成 12:34:58
// 3. 退出设置后，当当前时间变为 12:34:58 时，alarm_led 变为 1
module tb_alarm_ctrl;
    reg clk;
    reg rst;
    reg alarm_sw;
    reg time_set_mode;
    reg [2:0] set_sel;
    reg inc_pulse;
    reg dec_pulse;

    reg [3:0] cur_sec_0;
    reg [3:0] cur_sec_1;
    reg [3:0] cur_min_0;
    reg [3:0] cur_min_1;
    reg [3:0] cur_hour_0;
    reg [3:0] cur_hour_1;

    wire [3:0] alarm_sec_0;
    wire [3:0] alarm_sec_1;
    wire [3:0] alarm_min_0;
    wire [3:0] alarm_min_1;
    wire [3:0] alarm_hour_0;
    wire [3:0] alarm_hour_1;
    wire alarm_valid;
    wire alarm_led;

    wire alarm_match_dbg;
    wire ringing_dbg;

    alarm_ctrl uut (
        .clk(clk),
        .rst(rst),
        .alarm_sw(alarm_sw),
        .time_set_mode(time_set_mode),
        .set_sel(set_sel),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),
        .cur_sec_0(cur_sec_0),
        .cur_sec_1(cur_sec_1),
        .cur_min_0(cur_min_0),
        .cur_min_1(cur_min_1),
        .cur_hour_0(cur_hour_0),
        .cur_hour_1(cur_hour_1),
        .alarm_sec_0(alarm_sec_0),
        .alarm_sec_1(alarm_sec_1),
        .alarm_min_0(alarm_min_0),
        .alarm_min_1(alarm_min_1),
        .alarm_hour_0(alarm_hour_0),
        .alarm_hour_1(alarm_hour_1),
        .alarm_valid(alarm_valid),
        .alarm_led(alarm_led)
    );

    assign alarm_match_dbg = uut.alarm_match;
    assign ringing_dbg = uut.ringing;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task one_inc;
    begin
        @(negedge clk);
        inc_pulse = 1'b1;
        @(negedge clk);
        inc_pulse = 1'b0;
        repeat (2) @(negedge clk);
    end
    endtask

    initial begin
        rst = 1'b1;
        alarm_sw = 1'b0;
        time_set_mode = 1'b0;
        set_sel = 3'd0;
        inc_pulse = 1'b0;
        dec_pulse = 1'b0;

        // 当前时间先设为 12:34:56
        cur_hour_1 = 4'd1;
        cur_hour_0 = 4'd2;
        cur_min_1 = 4'd3;
        cur_min_0 = 4'd4;
        cur_sec_1 = 4'd5;
        cur_sec_0 = 4'd6;

        repeat (4) @(negedge clk);
        rst = 1'b0;

        // 进入闹钟设置，闹钟时间复制当前时间 12:34:56
        alarm_sw = 1'b1;
        repeat (4) @(negedge clk);

        // 调秒个位两次，闹钟变成 12:34:58
        set_sel = 3'd0;
        one_inc;
        one_inc;

        // 退出闹钟设置，alarm_valid 变为 1
        alarm_sw = 1'b0;
        repeat (5) @(negedge clk);

        // 当前时间先到 12:34:57，还没有匹配
        cur_sec_0 = 4'd7;
        repeat (5) @(negedge clk);

        // 当前时间到 12:34:58，应该触发闹钟
        cur_sec_0 = 4'd8;
        repeat (12) @(negedge clk);

        $finish;
    end
endmodule
