`timescale 1ns / 1ps

module clock(
    input clk,
    input rst,

    output [6:0] seg,
    output [7:0] an,
    output reg colon 
    );

    wire tick_1Hz;
    wire tick_1kHz;

    wire [3:0] sec_0;
    wire [3:0] sec_1;
    wire [3:0] min_0;
    wire [3:0] min_1;
    wire [3:0] hour_0;
    wire [3:0] hour_1;

    clk_div_1Hz u_clk_div_1Hz(
        .clk(clk),
        .rst(rst),
        .tick_1Hz(tick_1Hz)
    );

    clk_div_1kHz u_clk_div_1kHz(
        .clk(clk),
        .rst(rst),
        .tick_1kHz(tick_1kHz)
    );

    time_counter u_time_counter(
        .clk(clk),
        .rst(rst),
        .tick_1Hz(tick_1Hz),
        .sec_0(sec_0),
        .sec_1(sec_1),
        .min_0(min_0),
        .min_1(min_1),
        .hour_0(hour_0),
        .hour_1(hour_1)
    );

    digit_display u_digit_display(
        .clk(clk),
        .rst(rst),
        .tick_1kHz(tick_1kHz),   
        .sec_0(sec_0),
        .sec_1(sec_1),
        .min_0(min_0),
        .min_1(min_1),
        .hour_0(hour_0),
        .hour_1(hour_1),
        .an(an),
        .seg(seg),
        .colon(colon)     
    );

endmodule

//将数字0-9转化为七段码
module seg_decoder(
    input [3:0] num,//输入用8421BCD码表示
    output reg [6:0] seg
);
    always @(*) begin
    case(num)
        4'd0: seg = 7'b1000000;
        4'd1: seg = 7'b1111001;
        4'd2: seg = 7'b0100100;
        4'd3: seg = 7'b0110000;
        4'd4: seg = 7'b0011001;
        4'd5: seg = 7'b0010010;
        4'd6: seg = 7'b0000010;
        4'd7: seg = 7'b1111000;
        4'd8: seg = 7'b0000000;
        4'd9: seg = 7'b0010000;
        default : seg = 7'b0000000;
    endcase
    end
endmodule

//分频:1Hz,用于计算一秒的时间间隔
module clk_div_1Hz(
    input clk,  // 开发板时钟信号,100 MHz
    input rst,  // 重置
    output reg tick_1Hz
);
    reg [26:0] count; //27位计数器,因为2^26 < 100M < 2^27
    always @(posedge clk)begin
        if(rst)begin//重置
            count <= 0;
            tick_1Hz <= 0;
        end
        else begin
            if(count == 27'99_999_999)begin//时钟走过100M-1时,tick_1Hz变为1一次,得到1Hz的分频,T = 1s
                count <= 0;
                tick_1Hz <= 1;
            end
        else begin
            count <= count + 1;
            tick_1Hz <= 0;
        end
    end
    end
endmodule

//分频:1kHz,用于数码管扫描显示数字,100M/1k = 100_000
module clk_div_1kHz(
    input clk,
    input rst,
    output reg tick_1kHz
);
    reg [16:0] count; // 2^16 < 100000 <2^17
    always @(posedge clk)begin
        if(rst)begin//重置
            count <= 0;
            tick_1kHz <= 0;
        end
        else begin
            if(count == 17'd99_999)begin // 100_000-1 得到1kHz分频,T = 1/1000 s
                count <= 0;
                tick_1kHz <= 1;
            end
        else begin
            count <= count + 1;
            tick_1kHz <= 0;
        end
    end
    end
endmodule

//实现时钟计数逻辑,先实现 模X计数器, 再套到时分秒的各位上
module digit_counter #(
    parameter MAX = 9 ;//自定义参数,也就是计数器的模数
)(
    input clk,
    input rst,
    input en, //设置使能端,用于级联
    output carry, //进位输出
    output reg [3:0] q //计数
)
    assign carry = en && (q == MAX) //q达到MAX且使能端有效时,输出进位

    always @(posedge clk)begin
        if(rst)begin
            q <= 4'd0;
        end
        else if(en) begin
            if (q == MAX)
                q <= 4'd0;
            else
                q <= q + 1'b1 ;
    end
    end
endmodule

//由于hour的最大值是23,故需给小时位单独设置模24计数器
module digit_counter_hour (
    input clk,
    input rst,
    input en,
    output carry,
    //用0表示hour的个位,1表示十位,分别处理
    output reg [3:0] hour_0,
    output reg [3:0] hour_1
);

    //hour = 23时进位(暂时没有更高位,也就是天数)
    assign carry = en && (hour_0 == 4'd3) && (hour_1 == 4'd2);

    always @(posedge clk)begin
        if(rst)begin
            hour_0 <= 4'd0;
            hour_1 <= 4'd0;
        end
        else if(en)begin
            if(hour_0 == 4'd3 && hour_1 == 4'd2)begin
                hour_0 <= 4'd0;
                hour_1 <= 4'd0;
            end
            //个位逢十进一
            else if(hour_0 == 4'd9)begin
                hour_1 <= hour_1 + 4'd1;
                hour_0 <= 4'd0;
            end
            else begin
                hour_0 <= hour_0 + 4'd1;
            end
        end
    end

endmodule


//实现完整的进位逻辑,只需调用前几个写好的模块并处理好级联进位即可
module time_counter(
    input clk,
    input rst,
    input tick_1Hz,
    //分别定义时分秒的个位和十位,0:个位 1:十位
    output [3:0] sec_0, 
    output [3:0] sec_1, 
    output [3:0] min_0, 
    output [3:0] min_1, 
    output [3:0] hour_0,
    output [3:0] hour_1
    );

    //分别定义来自各个位的进位
    wire carry_sec_0;
    wire carry_sec_1;
    wire carry_min_0;
    wire carry_min_1;
    wire carry_hour;

    //实例化各计数模块,每1秒更新一次sec_0,依次累加即可计时
    digit_counter #(.MAX(9)) u_sec_0(
        .clk(clk),
        .rst(rst),
        .en(tick_1Hz),
        .q(sec_0),
        .carry(carry_sec_0)
    );

    digit_counter #(.MAX(5)) u_sec_1(
        .clk(clk),
        .rst(rst),
        .en(carry_sec_0),//接受来自秒的个位的进位信号
        .q(sec_1),
        .carry(carry_sec_1)//输出当前位的进位信号
    );

    digit_counter #(.MAX(9)) u_min_0(
        .clk(clk),
        .rst(rst),
        .en(carry_sec_1),//链接前一位的进位信号,实现级联功能
        .q(min_0),
        .carry(carry_min_0)
    );

    digit_counter #(.MAX(5)) u_min_1(
        .clk(clk),
        .rst(rst),
        .en(carry_min_0),
        .q(min_1),
        .carry(carry_min_1)
    );

    digit_counter_hour u_hour(
        .clk(clk),
        .rst(rst),
        .en(carry_min_1),
        .hour_0(hour_0),
        .hour_1(hour_1)
        .carry(carry_hour)
    );

endmodule

//让数码管显示计数得到的结果
module digit_display(
    input clk,
    input rst,
    input tick_1kHz,

    input [3:0] sec_0,
    input [3:0] sec_1,
    input [3:0] min_0,
    input [3:0] min_1,
    input [3:0] hour_0,
    input [3:0] hour_1,

    output reg [7:0] an,//决定哪一位数码管被点亮,一共八位
    output reg [6:0] seg,//决定一个数码管的哪几段被点亮,一共七段
    output colon //冒号
);

    //以1kHz的频率对用到的六位数码管进行扫描
    reg [3:0] scan;
    always @(posedge clk) begin
        if (rst) begin
            scan <= 3'd0;
        end else if (tick_1kHz) begin
            if (scan == 3'd5)
                scan <= 3'd0;
            else
                scan <= scan + 1'b1;
        end
    end

    //根据位数对应的时间数字,点亮扫描到的位数的数码管
    reg [7:0] current_num;
    always @(*) begin
        an = 8'b11111111; 
        colon = 1'b1;
        current_num = 4'd0;

        case (scan) 
            3'd0: begin
                an = 8'b01111111; 
                current_num = hour_1;
            end
            3'd1: begin
                an = 8'b10111111;
                current_num = hour_0;
                colon = 1'b0;
            end
            3'd2: begin
                an = 8'b11011111;
                current_num = min_1;
            end
            3'd3: begin
                an = 8'b11101111;
                current_num = min_0;
                colon = 1'b0;
            end 
            3'd4: begin
                an = 8'b11110111;
                current_num = sec_1;
            end
            3'd5: begin
                an = 8'b11111011;
                current_num = sec_0;
            end
            default:begin
                an <= 8'b11111111;
                current_num = 4'd0;
            end
    endcase
    end

    //根据上面语句得到的应该显示的位置,将数字转化为七段码,最终点亮显示数字
    seg_decoder u_sec_decoder(
        .num(current_num),
        .seg(seg)
    );



endmodule