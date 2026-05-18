imescale 1ns / 1ps

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
        default : seg = 7'b1111111;
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
            if(count == 27'd99_999_999)begin//时钟走过100M-1时,tick_1Hz变为1一次,得到1Hz的分频,T = 1s
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
    parameter MAX = 9 //自定义参数,也就是计数器的模数
)(
    input clk,
    input rst,
    input en, //设置使能端,用于级联

    //set_time
    input edit_en,
    input inc_pulse,
    input dec_pulse,

    output carry, //进位输出
    output reg [3:0] q //计数
);
    assign carry = en && (q == MAX); //q达到MAX且使能端有效时,输出进位

    //下面的写法是在原来的基础上增加了判断是否edit这一位的数值,并根据increase或decrease改变q的值,使得有普通计时en和手动校准edit_en两种方法计数
    always @(posedge clk)begin
        if(rst)begin
            q <= 4'd0;
        end else if(edit_en && inc_pulse) begin
            if(q == MAX)
                q <= 4'd0;
            else 
                q <= q + 1'b1;
        end else if(edit_en && dec_pulse) begin
            if(q == 4'd0)
                q <= MAX;
            else 
            q <= q - 1'b1;
        end else if(en) begin
            if(q == MAX)
                q <= 4'd0;
            else 
            q <= q + 1'b1;
        end
    end


endmodule

//由于hour的最大值是23,故需给小时位单独设置模24计数器
// 小时计数 / 调时模块：00~23
module digit_counter_hour (
    input clk,
    input rst,
    input en,              // 正常计时时的小时进位使能

    input set_mode,         // 是否进入调时模式
    input [2:0] set_sel,    // 选择当前调哪一位
    input inc_pulse,        // 加一按键脉冲
    input dec_pulse,        // 减一按键脉冲

    output carry,
    output reg [3:0] hour_0, // 小时个位
    output reg [3:0] hour_1  // 小时十位
);

    assign carry = (!set_mode) && en && (hour_1 == 4'd2) && (hour_0 == 4'd3);

    always @(posedge clk) begin
        if (rst) begin
            hour_0 <= 4'd0;
            hour_1 <= 4'd0;
        end

        // 调时模式
        else if (set_mode) begin

            // 调小时个位
            if (set_sel == 3'd4 && inc_pulse) begin
                if (hour_1 == 4'd2) begin
                    if (hour_0 == 4'd3)
                        hour_0 <= 4'd0;
                    else
                        hour_0 <= hour_0 + 1'b1;
                end else begin
                    if (hour_0 == 4'd9)
                        hour_0 <= 4'd0;
                    else
                        hour_0 <= hour_0 + 1'b1;
                end
            end else if (set_sel == 3'd4 && dec_pulse) begin
                if (hour_0 == 4'd0) begin
                    if (hour_1 == 4'd2)
                        hour_0 <= 4'd3;
                    else
                        hour_0 <= 4'd9;
                end else begin
                    hour_0 <= hour_0 - 1'b1;
                end
            end

            // 调小时十位
            else if (set_sel == 3'd5 && inc_pulse) begin
                if (hour_1 == 4'd2)
                    hour_1 <= 4'd0;
                else
                    hour_1 <= hour_1 + 1'b1;

                // 例如 19 调十位到 2 时，不能变成 29，修正为 23
                if (hour_1 == 4'd1 && hour_0 > 4'd3)
                    hour_0 <= 4'd3;
            end else if (set_sel == 3'd5 && dec_pulse) begin
                if (hour_1 == 4'd0)
                    hour_1 <= 4'd2;
                else
                    hour_1 <= hour_1 - 1'b1;

                // 例如 09 调十位减到 2 时，修正为 23
                if (hour_1 == 4'd0 && hour_0 > 4'd3)
                    hour_0 <= 4'd3;
            end
        end

        // 正常计时模式
        else if (en) begin
            if (hour_1 == 4'd2 && hour_0 == 4'd3) begin
                hour_0 <= 4'd0;
                hour_1 <= 4'd0;
            end else if (hour_0 == 4'd9) begin
                hour_0 <= 4'd0;
                hour_1 <= hour_1 + 1'b1;
            end else begin
                hour_0 <= hour_0 + 1'b1;
            end
        end
    end

endmodule



//实现完整的进位逻辑,只需调用前几个写好的模块并处理好级联进位即可
module time_counter(
    input clk,
    input rst,
    input tick_1Hz,

    //set_time
    input set_mode,
    input [2:0] set_sel,
    input inc_pulse,
    input dec_pulse,

    //分别定义时分秒的个位和十位,0:个位 1:十位
    output [3:0] sec_0, 
    output [3:0] sec_1, 
    output [3:0] min_0, 
    output [3:0] min_1, 
    output [3:0] hour_0,
    output [3:0] hour_1,
    //用于整点报时的输出端口
    output hour_tick
    );

    //分别定义来自各个位的进位
    wire carry_sec_0;
    wire carry_sec_1;
    wire carry_min_0;
    wire carry_min_1;
    wire carry_hour;

    //用于整点报时
    assign hour_tick = (!set_mode) && carry_min_1;


    //实例化各计数模块,每1秒更新一次sec_0,依次累加即可计时
    digit_counter #(.MAX(9)) u_sec_0(
        .clk(clk),
        .rst(rst),
        .en(!set_mode && tick_1Hz),
        .edit_en(set_mode && set_sel == 3'd0),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),
        .q(sec_0),
        .carry(carry_sec_0)
    );

    digit_counter #(.MAX(5)) u_sec_1(
        .clk(clk),
        .rst(rst),
        .en(!set_mode && carry_sec_0),//接受来自秒的个位的进位信号
        .edit_en(set_mode && set_sel == 3'd1),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),
        .q(sec_1),
        .carry(carry_sec_1)//输出当前位的进位信号
    );

    digit_counter #(.MAX(9)) u_min_0(
        .clk(clk),
        .rst(rst),
        .en(!set_mode && carry_sec_1),//链接前一位的进位信号,实现级联功能
        .edit_en(set_mode && set_sel == 3'd2),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),
        .q(min_0),
        .carry(carry_min_0)
    );

    digit_counter #(.MAX(5)) u_min_1(
        .clk(clk),
        .rst(rst),
        .en(!set_mode && carry_min_0),
        .edit_en(set_mode && set_sel == 3'd3),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),
        .q(min_1),
        .carry(carry_min_1)
    );

    digit_counter_hour u_hour(
    .clk(clk),
    .rst(rst),
    .en(carry_min_1),

    .set_mode(set_mode),
    .set_sel(set_sel),
    .inc_pulse(inc_pulse),
    .dec_pulse(dec_pulse),

    .hour_0(hour_0),
    .hour_1(hour_1),
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
    output  [6:0] seg,//决定一个数码管的哪几段被点亮,一共七段
    output reg colon //冒号(看手册发现板子没有冒号的引脚,用小数点代替)
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
    reg [3:0] current_num;
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
                an = 8'b11111111;
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

//调时控制模块:根据拨码开关进入调时模式,并用左右键选择要修改的数码管位
module set_time(
    input clk,
    input rst,
    input set_sw, //调时开关,为1时进入调时/闹钟设置模式

    input btn_left_pulse,  //左移选择位,已经过消抖并变成单周期脉冲
    input btn_right_pulse, //右移选择位,已经过消抖并变成单周期脉冲
    input btn_inc_pulse,   //当前位加一
    input btn_dec_pulse,   //当前位减一

    output set_mode,       //输出给计时/闹钟模块,表示现在是否允许手动修改
    output reg [2:0] set_sel, //当前选中的位,0-5依次为秒个位到小时十位
    output inc_pulse,      //只在set_mode有效时转发加一脉冲
    output dec_pulse       //只在set_mode有效时转发减一脉冲
);

    //set_mode直接由开关决定,后级模块通过它区分正常计时和手动设置
    assign set_mode = set_sw;

    //加减操作只能发生在调时模式下,普通计时时按键不会影响当前时间
    assign inc_pulse = set_mode && btn_inc_pulse;
    assign dec_pulse = set_mode && btn_dec_pulse;

    always @(posedge clk) begin
        if(rst)begin
            set_sel <= 3'd0;
        end else if(!set_mode)begin
            //退出调时模式后回到最低位,下次进入时从秒个位开始选
            set_sel <= 3'd0;
        end else begin
            //右移时选择更高一位,到hour_1后再绕回sec_0
            if(btn_right_pulse)begin //右移,状态+1
                if(set_sel == 3'd5)
                    set_sel <= 3'd0;
                else
                    set_sel <= set_sel+1'b1;
                    end
            //左移时选择更低一位,到sec_0后再绕回hour_1
            else if(btn_left_pulse)begin //左移,状态-1
                if(set_sel == 3'd0)
                    set_sel <= 3'd5;
                else
                    set_sel <= set_sel - 1'b1;
                    end
        end
    end

endmodule


//按键消抖:把机械按键的抖动输入变成稳定的单周期按下脉冲
module button_debounce_pulse #(
    parameter [20:0] CNT_MAX = 21'd1_999_999  // 100MHz 下约 20ms
)(
    input clk,
    input rst,
    input btn,        //原始按键信号,可能有抖动且和clk不同步
    output reg pulse  //检测到一次稳定按下后输出1个clk周期的脉冲
);

    reg btn_meta;  //第一级同步寄存器,降低亚稳态影响
    reg btn_sync;  //第二级同步寄存器,得到同步到clk的按键信号
    reg btn_state; //已经确认稳定的按键状态
    reg [20:0] cnt; //btn_sync和btn_state不一致时开始计数,用于判断是否稳定

    always @(posedge clk) begin
        if (rst) begin
            btn_meta <= 1'b0;
            btn_sync <= 1'b0;
            btn_state <= 1'b0;
            cnt <= 21'd0;
            pulse <= 1'b0;
        end else begin
            btn_meta <= btn;
            btn_sync <= btn_meta;
            pulse <= 1'b0;

            if (btn_sync == btn_state) begin
                //输入和已确认状态相同,说明没有新的稳定变化,计数器清零
                cnt <= 21'd0;
            end else begin
                //输入和已确认状态不同,只有持续CNT_MAX个周期后才接受这次变化
                if (cnt == CNT_MAX) begin
                    btn_state <= btn_sync;
                    cnt <= 21'd0;

                    //只在按键从松开稳定变为按下稳定时产生脉冲,松开时不产生
                    if (btn_sync == 1'b1)
                        pulse <= 1'b1;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

endmodule

//整点报时模块:检测到hour_tick后,输出持续约1秒的2kHz方波
module hour_chime(
    input clk,
    input rst,
    input set_mode,  //调时模式下关闭报时,避免手动修改时误触发
    input hour_tick, //由计时模块在分钟向小时进位时给出的单周期脉冲

    output reg alarm //整点报时输出,可接蜂鸣器或LED
);

    reg active; //报时正在进行的标志
    reg [26:0] duration_cnt; // 100MHz 下 1 秒需要 100_000_000 个周期
    reg [15:0] tone_cnt;     // 2kHz 方波半周期：100M / 2 / 2000 = 25000

    always @(posedge clk) begin
        if (rst || set_mode) begin
            //复位或调时期间都停止报时,并把计数器清零
            active <= 1'b0;
            duration_cnt <= 27'd0;
            tone_cnt <= 16'd0;
            alarm <= 1'b0;
        end else begin
            if (hour_tick) begin
                //整点到来时启动一次报时,装入1秒持续时间
                active <= 1'b1;
                duration_cnt <= 27'd99_999_999;
                tone_cnt <= 16'd0;
                alarm <= 1'b0;
            end else if (active) begin
                if (duration_cnt == 27'd0) begin
                    //持续时间结束后关闭输出,等待下一次hour_tick
                    active <= 1'b0;
                    alarm <= 1'b0;
                end else begin
                    duration_cnt <= duration_cnt - 1'b1;

                    //tone_cnt每到24999翻转一次alarm,两个半周期组成一个2kHz方波周期
                    if (tone_cnt == 16'd24_999) begin
                        tone_cnt <= 16'd0;
                        alarm <= ~alarm;
                    end else begin
                        tone_cnt <= tone_cnt + 1'b1;
                    end
                end
            end else begin
                //没有报时任务时保持低电平
                alarm <= 1'b0;
            end
        end
    end

endmodule


//闹钟模块:负责闹钟时间的设置、保存、比较以及响铃LED闪烁
module alarm_ctrl(
    input clk,
    input rst,
    input alarm_sw,      //闹钟设置开关,为1时显示并修改闹钟时间
    input time_set_mode, //普通调时模式,此时闹钟不响铃

    input [2:0] set_sel, //复用set_time产生的位选择信号
    input inc_pulse,     //当前选中位加一
    input dec_pulse,     //当前选中位减一

    //当前真实时间,用于进入闹钟设置时作为初值,也用于和闹钟时间比较
    input [3:0] cur_sec_0,
    input [3:0] cur_sec_1,
    input [3:0] cur_min_0,
    input [3:0] cur_min_1,
    input [3:0] cur_hour_0,
    input [3:0] cur_hour_1,

    //闹钟时间寄存器,同时送到显示模块,alarm_sw为1时显示这些值
    output reg [3:0] alarm_sec_0,
    output reg [3:0] alarm_sec_1,
    output reg [3:0] alarm_min_0,
    output reg [3:0] alarm_min_1,
    output reg [3:0] alarm_hour_0,
    output reg [3:0] alarm_hour_1,

    output reg alarm_valid, //退出闹钟设置后置1,表示当前闹钟时间有效
    output reg alarm_led    //闹钟触发后的闪烁输出
);

    reg alarm_sw_d; //alarm_sw打一拍,用于检测进入/退出闹钟设置模式
    reg match_d;    //alarm_match打一拍,用于只在匹配上升沿触发一次响铃
    reg ringing;    //响铃状态标志
    reg [28:0] ring_cnt;  //响铃持续时间计数器,100MHz下5秒需要500_000_000个周期
    reg [24:0] blink_cnt; //LED闪烁分频计数器,控制alarm_led翻转速度

    //检测alarm_sw的上升沿和下降沿,分别表示进入设置和退出保存
    wire alarm_enter = alarm_sw && !alarm_sw_d;
    wire alarm_exit  = !alarm_sw && alarm_sw_d;

    //闹钟只在已经设置有效、没有处于任何设置模式、且当前时间完全等于闹钟时间时匹配
    wire alarm_match =
        alarm_valid &&
        !alarm_sw &&
        !time_set_mode &&
        cur_sec_0  == alarm_sec_0  &&
        cur_sec_1  == alarm_sec_1  &&
        cur_min_0  == alarm_min_0  &&
        cur_min_1  == alarm_min_1  &&
        cur_hour_0 == alarm_hour_0 &&
        cur_hour_1 == alarm_hour_1;

    //进入时装载当前时间,设置时修改,退出时保存有效
    always @(posedge clk) begin
        if (rst) begin
            alarm_sw_d <= 1'b0;
            alarm_valid <= 1'b0;

            alarm_sec_0 <= 4'd0;
            alarm_sec_1 <= 4'd0;
            alarm_min_0 <= 4'd0;
            alarm_min_1 <= 4'd0;
            alarm_hour_0 <= 4'd0;
            alarm_hour_1 <= 4'd0;
        end else begin
            alarm_sw_d <= alarm_sw;

            if (alarm_enter) begin
                //刚进入闹钟设置时,先清除有效标志,并把当前时间复制为默认闹钟时间
                alarm_valid <= 1'b0;

                alarm_sec_0 <= cur_sec_0;
                alarm_sec_1 <= cur_sec_1;
                alarm_min_0 <= cur_min_0;
                alarm_min_1 <= cur_min_1;
                alarm_hour_0 <= cur_hour_0;
                alarm_hour_1 <= cur_hour_1;
            end else if (alarm_exit) begin
                //退出闹钟设置时认为用户已经确认,闹钟时间开始参与后续比较
                alarm_valid <= 1'b1;
            end else if (alarm_sw) begin
                //闹钟设置模式下,根据set_sel只修改当前选中的一位
                if (inc_pulse) begin
                    case (set_sel)
                        //秒和分的个位为0-9循环,十位为0-5循环
                        3'd0: alarm_sec_0 <= (alarm_sec_0 == 4'd9) ? 4'd0 : alarm_sec_0 + 1'b1;
                        3'd1: alarm_sec_1 <= (alarm_sec_1 == 4'd5) ? 4'd0 : alarm_sec_1 + 1'b1;
                        3'd2: alarm_min_0 <= (alarm_min_0 == 4'd9) ? 4'd0 : alarm_min_0 + 1'b1;
                        3'd3: alarm_min_1 <= (alarm_min_1 == 4'd5) ? 4'd0 : alarm_min_1 + 1'b1;

                        3'd4: begin
                            //小时个位受小时十位限制:十位为2时个位只能在0-3循环
                            if (alarm_hour_1 == 4'd2)
                                alarm_hour_0 <= (alarm_hour_0 == 4'd3) ? 4'd0 : alarm_hour_0 + 1'b1;
                            else
                                alarm_hour_0 <= (alarm_hour_0 == 4'd9) ? 4'd0 : alarm_hour_0 + 1'b1;
                        end

                        3'd5: begin
                            //小时十位只在0-2循环
                            alarm_hour_1 <= (alarm_hour_1 == 4'd2) ? 4'd0 : alarm_hour_1 + 1'b1;

                            //若从1加到2且个位大于3,例如19不能变成29,修正为23
                            if (alarm_hour_1 == 4'd1 && alarm_hour_0 > 4'd3)
                                alarm_hour_0 <= 4'd3;
                        end
                    endcase
                end else if (dec_pulse) begin
                    case (set_sel)
                        3'd0: alarm_sec_0 <= (alarm_sec_0 == 4'd0) ? 4'd9 : alarm_sec_0 - 1'b1;
                        3'd1: alarm_sec_1 <= (alarm_sec_1 == 4'd0) ? 4'd5 : alarm_sec_1 - 1'b1;
                        3'd2: alarm_min_0 <= (alarm_min_0 == 4'd0) ? 4'd9 : alarm_min_0 - 1'b1;
                        3'd3: alarm_min_1 <= (alarm_min_1 == 4'd0) ? 4'd5 : alarm_min_1 - 1'b1;

                        3'd4: begin
                            //小时个位减到0以下时回绕,十位为2时回到3,否则回到9
                            if (alarm_hour_0 == 4'd0)
                                alarm_hour_0 <= (alarm_hour_1 == 4'd2) ? 4'd3 : 4'd9;
                            else
                                alarm_hour_0 <= alarm_hour_0 - 1'b1;
                        end

                        3'd5: begin
                            //小时十位向下在0-2之间循环
                            alarm_hour_1 <= (alarm_hour_1 == 4'd0) ? 4'd2 : alarm_hour_1 - 1'b1;

                            //若从0减到2且个位大于3,例如09不能变成29,修正为23
                            if (alarm_hour_1 == 4'd0 && alarm_hour_0 > 4'd3)
                                alarm_hour_0 <= 4'd3;
                        end
                    endcase
                end
            end
        end
    end

    //闹钟触发后的输出:匹配一次后闪烁约5秒
    always @(posedge clk) begin
        if (rst || alarm_sw || time_set_mode) begin
            //复位、正在设置闹钟、正在设置当前时间时都不响铃
            match_d <= 1'b0;
            ringing <= 1'b0;
            ring_cnt <= 29'd0;
            blink_cnt <= 25'd0;
            alarm_led <= 1'b0;
        end else begin
            match_d <= alarm_match;

            if (alarm_match && !match_d && !ringing) begin
                //alarm_match上升沿说明第一次到达设定时间,启动5秒响铃
                ringing <= 1'b1;
                ring_cnt <= 29'd499_999_999;  
                blink_cnt <= 25'd0;
                alarm_led <= 1'b1;
            end else if (ringing) begin
                if (ring_cnt == 29'd0) begin
                    //响铃时间结束后停止闪烁
                    ringing <= 1'b0;
                    alarm_led <= 1'b0;
                    blink_cnt <= 25'd0;
                end else begin
                    ring_cnt <= ring_cnt - 1'b1;

                    //blink_cnt到24999999时翻转LED,约0.25s
                    if (blink_cnt == 25'd24_999_999) begin
                        blink_cnt <= 25'd0;
                        alarm_led <= ~alarm_led;
                    end else begin
                        blink_cnt <= blink_cnt + 1'b1;
                    end
                end
            end else begin
                //未匹配且不在响铃中时保持熄灭
                alarm_led <= 1'b0;
            end
        end
    end

endmodule


module clock(
    input clk,
    input rst,

    input set_sw,//进入校准时间模式
    input btn_left,//左移一位
    input btn_right,//右移一位
    input btn_inc,//increase
    input btn_dec,//decrease

    //闹钟
    input alarm_sw,

    output [6:0] seg,
    output [7:0] an,
    output  colon, 
    output [5:0] settime,
    output alarm, //整点报时用的led
    output alarm_led //闹钟响铃用的led 
    );

    wire tick_1Hz;
    wire tick_1kHz;

    wire [3:0] sec_0;
    wire [3:0] sec_1;
    wire [3:0] min_0;
    wire [3:0] min_1;
    wire [3:0] hour_0;
    wire [3:0] hour_1;

    //set_time
    wire set_mode;
    wire [2:0] set_sel;
    wire inc_pulse;
    wire dec_pulse; 

    //button_pulse
    wire btn_left_p;
    wire btn_right_p;
    wire btn_inc_p;
    wire btn_dec_p;

    //hour chime
    wire hour_tick;

    assign settime[5] = set_mode && (set_sel == 3'd5); // hour_1
    assign settime[4] = set_mode && (set_sel == 3'd4); // hour_0
    assign settime[3] = set_mode && (set_sel == 3'd3); // min_1
    assign settime[2] = set_mode && (set_sel == 3'd2); // min_0
    assign settime[1] = set_mode && (set_sel == 3'd1); // sec_1
    assign settime[0] = set_mode && (set_sel == 3'd0); // sec_0

    //闹钟
    wire time_set_mode;
    wire alarm_valid;

    wire [3:0] alarm_sec_0;
    wire [3:0] alarm_sec_1;
    wire [3:0] alarm_min_0;
    wire [3:0] alarm_min_1;
    wire [3:0] alarm_hour_0;
    wire [3:0] alarm_hour_1;

    wire [3:0] disp_sec_0;
    wire [3:0] disp_sec_1;
    wire [3:0] disp_min_0;
    wire [3:0] disp_min_1;
    wire [3:0] disp_hour_0;
    wire [3:0] disp_hour_1;

    assign time_set_mode = set_sw && !alarm_sw; // alarm_sw 优先

    assign disp_sec_0  = alarm_sw ? alarm_sec_0  : sec_0;
    assign disp_sec_1  = alarm_sw ? alarm_sec_1  : sec_1;
    assign disp_min_0  = alarm_sw ? alarm_min_0  : min_0;
    assign disp_min_1  = alarm_sw ? alarm_min_1  : min_1;
    assign disp_hour_0 = alarm_sw ? alarm_hour_0 : hour_0;
    assign disp_hour_1 = alarm_sw ? alarm_hour_1 : hour_1;



    //获得1Hz的分频
    clk_div_1Hz u_clk_div_1Hz(
        .clk(clk),
        .rst(rst),
        .tick_1Hz(tick_1Hz)
    );

    //获得1kHz的分频
    clk_div_1kHz u_clk_div_1kHz(
        .clk(clk),
        .rst(rst),
        .tick_1kHz(tick_1kHz)
    );

    //计数
    time_counter u_time_counter(
    .clk(clk),
    .rst(rst),
    .tick_1Hz(tick_1Hz),

    .set_mode(time_set_mode),
    .set_sel(set_sel),
    .inc_pulse(inc_pulse),
    .dec_pulse(dec_pulse),
    .hour_tick(hour_tick),

    .sec_0(sec_0),
    .sec_1(sec_1),
    .min_0(min_0),
    .min_1(min_1),
    .hour_0(hour_0),
    .hour_1(hour_1)
);


    //显示
    digit_display u_digit_display(
        .clk(clk),
        .rst(rst),
        .tick_1kHz(tick_1kHz),   
        .sec_0(disp_sec_0),
        .sec_1(disp_sec_1),
        .min_0(disp_min_0),
        .min_1(disp_min_1),
        .hour_0(disp_hour_0),
        .hour_1(disp_hour_1),//显示的数字可能是真实时间,也可能是闹钟时间
        .an(an),
        .seg(seg),
        .colon(colon)     
    );

    //校准时间
    set_time u_set_time(
        .clk(clk),
        .rst(rst),
        .set_sw(set_sw || alarm_sw),//兼容闹钟模式下的调时间

        .set_mode(set_mode),
        .set_sel(set_sel),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),

        .btn_left_pulse(btn_left_p),
        .btn_right_pulse(btn_right_p),
        .btn_inc_pulse(btn_inc_p),
        .btn_dec_pulse(btn_dec_p)

    );

    //消抖模块
    button_debounce_pulse u_btn_left(
    .clk(clk),
    .rst(rst),
    .btn(btn_left),
    .pulse(btn_left_p)
);

    button_debounce_pulse u_btn_right(
    .clk(clk),
    .rst(rst),
    .btn(btn_right),
    .pulse(btn_right_p)
);

    button_debounce_pulse u_btn_inc(
    .clk(clk),
    .rst(rst),
    .btn(btn_inc),
    .pulse(btn_inc_p)
);

    button_debounce_pulse u_btn_dec(
    .clk(clk),
    .rst(rst),
    .btn(btn_dec),
    .pulse(btn_dec_p)
);

//hour chime
    hour_chime u_hour_chime(
        .clk(clk),
        .rst(rst),
        .set_mode(set_mode),
        .hour_tick(hour_tick),
        .alarm(alarm)
);

//闹钟
    alarm_ctrl u_alarm_ctrl(
    .clk(clk),
    .rst(rst),
    .alarm_sw(alarm_sw),
    .time_set_mode(time_set_mode),

    .set_sel(set_sel),
    .inc_pulse(inc_pulse),
    .dec_pulse(dec_pulse),

    .cur_sec_0(sec_0),
    .cur_sec_1(sec_1),
    .cur_min_0(min_0),
    .cur_min_1(min_1),
    .cur_hour_0(hour_0),
    .cur_hour_1(hour_1),

    .alarm_sec_0(alarm_sec_0),
    .alarm_sec_1(alarm_sec_1),
    .alarm_min_0(alarm_min_0),
    .alarm_min_1(alarm_min_1),
    .alarm_hour_0(alarm_hour_0),
    .alarm_hour_1(alarm_hour_1),

    .alarm_valid(alarm_valid),
    .alarm_led(alarm_led)
);



endmodule
