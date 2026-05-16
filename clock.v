`timescale 1ns / 1ps

module clock(

    );
endmodule

//将数字0-9转化为七段码
module seg_decoder(
    input [3:0] num,//输入用8421BCD码表示
    output [6:0] seg
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
            if(count == 27'd 999_999_999)begin//时钟走过100M-1时,tick_1Hz变为1一次,得到1Hz的分频,T = 1s
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
    output carry; //进位输出
    output reg [3:0] q; //计数
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
    output reg [3:0] sec_0, 
    output reg [3:0] sec_1, 
    output reg [3:0] min_0, 
    output reg [3:0] min_1, 
    output reg [3:0] hour_0,
    output reg [3:0] hour_1
    );



endmodule