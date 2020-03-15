// data0: high: 0.4us, low: 0.85us
// data1: high: 0.8us, low: 0.45us
// RESET: 50us 
module ws2812b_meter_ctrl(
        parameter DELAY = 1, // for simulation
        parameter CLK_PERIOD_NS = 10, // 100MHz
        parameter COLOR_N = 3, // 3色まで取り扱い可
    )(
        // system ctrl
        input clk,
        input reset_n,
        input enable,
        // IO pin
        output reg DOUT,
        // configurations
        input [23:0] colors [0:COLOR_N], // 表示する色設定
        input [15:0] visibleCounts [0:COLOR_N], // colorsの色ごとに点灯させるLEDの数、先頭から順に処理される
        input [15:0] onCount,  // 点灯数
        input [15:0] maxCount, // LED総数、onCount~maxCountの間はAll 0を送信する

    );
    // 周期設定
    localparam COUNT_T0H_NS  = (400/CLK_PERIOD_NS);    // 0.4us
    localparam COUNT_T0L_NS  = (850/CLK_PERIOD_NS);    // 0.85us
    localparam COUNT_T1H_NS  = (800/CLK_PERIOD_NS);    // 0.8us
    localparam COUNT_T1L_NS  = (450/CLK_PERIOD_NS);    // 0.45us
    localparam COUNT_RESET   = (100000/CLK_PERIOD_NS); // above 50us

    // 状態遷移
    // Idle       -> Send Reset : enable == true
    // Send Reset -> Send Data  : Reset送信完了時
    // Send Data  -> Send Reset : Data送信完了時
    // Send Reset -> Idle       : enable == false
    // Send Data  -> Idle       : enable == false
    localparam SATATE_IDLE      = 4'd0; // 何もしない
    localparam STATE_SEND_RESET = 4'd1; // WS2812にRESET Signal送信中
    localparam STATE_SEND_DATA  = 4'd2; // データ送信中

    reg [3:0]  state;            // 現在の動作モード
    reg [15:0] currentEncCount;  // 現在PWMエンコードしている周期カウント, COUNT_RESETが収まる必要がある(100MHzだと10000なので16bitあれば足りる)
    reg [15:0] currentLedCount;  // 現在処理しているLEDの位置
    reg [4:0]  currentBitCount;  // 現在処理している色データのbit位置
    reg [23:0] currentColor;     // 現在表示しようとしている色データ

    always @ (posedge clk or negedge reset_n) begin
        if (reset_n != 1'b1) begin
            DOUT <= #DELAY 1'd0;
            state <= #DELAY STATE_IDLE;
            currentEncCount <= #DELAY 16'd0;
            currentLedCount <= #DELAY 16'd0;
            currentBitCount <= #DELAY 5'd0;
            currentColor    <= #DELAY 24'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    DOUT <= #DELAY 1'd0;

                    // disableのときはIDLEを継続
                    if (enable == 1'd1) begin
                        currentEncCount <= #DELAY 16'd0;
                        state <= #DELAY STATE_SEND_RESET;
                    end
                end
                STATE_SEND_RESET: begin
                    if (currentEncCount < COUNT_RESET) begin
                        DOUT <= #DELAY 1'd0;
                        currentEncCount <= #DELAY currentEncCount + 16'd1;
                    else begin
                        currentEncCount <= #DELAY 16'd0;

                        // disableのときはIDLEに戻る
                        if (enable == 1'd1) begin
                            // TODO: 予め0番目のDOUT
                            currentLedCount <= #DELAY 16'd0;
                            currentBitCount <= #DELAY 5'd0;
                            currentColor    <= #DELAY 24'd0;
                            state <= #DELAY STATE_SEND_DATA;
                        end else begin
                            state <= #DELAY STATE_IDLE;
                        end
                    end
                end
                STATE_SEND_DATA: begin
                    // TODO: encCountでL,Hを出力する状態を入れる

                    // 色情報の読み込み
                    if (currentLedCount < maxCount) begin
                        if (currentBitCount < 5'd23) begin
                            // 現在の色を上位ビットから押し出して出力
                            DOUT <= #DELAY currentColor[23];
                            currentColor <= #DELAY { currentColor[22:0], 1'd0 };
                        end else begin
                            // TODO: 次の色をロード
                        end
                    end else begin
                        // 次また先頭から送れるようにresetを送る
                        state <= #DELAY STATE_SEND_RESET;
                    end
                end
                default: begin

                end
            endcase
            end
        end
    end

endmodule
