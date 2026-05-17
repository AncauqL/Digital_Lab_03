`timescale 1ns / 1ps

// 仿真目标：
// 1. 用很小的 CNT_MAX 加快消抖仿真
// 2. 观察原始按键有抖动时，btn_right_pulse 只出现一次
// 3. 观察 set_sel 随左右键变化
module tb_set_time_debounce;
    reg clk;
    reg rst;
    reg set_sw;
    reg btn_right_raw;
    reg btn_left_raw;
    reg btn_inc_raw;

    wire btn_right_pulse;
    wire btn_left_pulse;
    wire btn_inc_pulse;
    wire set_mode;
    wire [2:0] set_sel;
    wire inc_pulse;
    wire dec_pulse;

    button_debounce_pulse #(.CNT_MAX(21'd3)) u_right_db (
        .clk(clk),
        .rst(rst),
        .btn(btn_right_raw),
        .pulse(btn_right_pulse)
    );

    button_debounce_pulse #(.CNT_MAX(21'd3)) u_left_db (
        .clk(clk),
        .rst(rst),
        .btn(btn_left_raw),
        .pulse(btn_left_pulse)
    );

    button_debounce_pulse #(.CNT_MAX(21'd3)) u_inc_db (
        .clk(clk),
        .rst(rst),
        .btn(btn_inc_raw),
        .pulse(btn_inc_pulse)
    );

    set_time uut (
        .clk(clk),
        .rst(rst),
        .set_sw(set_sw),
        .btn_left_pulse(btn_left_pulse),
        .btn_right_pulse(btn_right_pulse),
        .btn_inc_pulse(btn_inc_pulse),
        .btn_dec_pulse(1'b0),
        .set_mode(set_mode),
        .set_sel(set_sel),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task bounce_right;
    begin
        btn_right_raw = 1'b1; @(negedge clk);
        btn_right_raw = 1'b0; @(negedge clk);
        btn_right_raw = 1'b1; repeat (6) @(negedge clk);
        btn_right_raw = 1'b0; repeat (6) @(negedge clk);
    end
    endtask

    task bounce_left;
    begin
        btn_left_raw = 1'b1; @(negedge clk);
        btn_left_raw = 1'b0; @(negedge clk);
        btn_left_raw = 1'b1; repeat (6) @(negedge clk);
        btn_left_raw = 1'b0; repeat (6) @(negedge clk);
    end
    endtask

    task bounce_inc;
    begin
        btn_inc_raw = 1'b1; @(negedge clk);
        btn_inc_raw = 1'b0; @(negedge clk);
        btn_inc_raw = 1'b1; repeat (6) @(negedge clk);
        btn_inc_raw = 1'b0; repeat (6) @(negedge clk);
    end
    endtask

    initial begin
        rst = 1'b1;
        set_sw = 1'b0;
        btn_right_raw = 1'b0;
        btn_left_raw = 1'b0;
        btn_inc_raw = 1'b0;

        repeat (4) @(negedge clk);
        rst = 1'b0;
        set_sw = 1'b1; // 进入校时模式
        repeat (3) @(negedge clk);

        bounce_right; // set_sel: 0 -> 1
        bounce_right; // set_sel: 1 -> 2
        bounce_left;  // set_sel: 2 -> 1
        bounce_inc;   // inc_pulse 输出一次

        set_sw = 1'b0; // 退出校时模式，set_sel 回到 0
        repeat (8) @(negedge clk);
        bounce_inc;    // 退出校时后，inc_pulse 不应该有效

        repeat (8) @(negedge clk);
        $finish;
    end
endmodule
