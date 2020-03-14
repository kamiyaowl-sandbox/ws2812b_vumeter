
module ws2812b_meter_ctrl(
        parameter DELAY = 1,
        parameter COLOR_N = 3, // 3色まで取り扱い可
    )(
        // system ctrl
        input clk, // 100MHz
        input reset_n,
        input is_enable,
        // IO pin
        output reg DOUT,
        // configurations
        input [23:0] colors [0:COLOR_N], // 表示する色設定
        input [31:0] visibleCounts [0:COLOR_N], // colorsの色ごとに点灯させるLEDの数、先頭から順に処理される。合計値がmaxCountに満たない場合は残りは黒
        input [31:0] maxCount, // LEDの最大数

    );

    // 状態遷移
    // Idle       -> Send Reset : (is_enable == true)
    // Send Reset -> Send Data  : Reset送信完了時
    // Send Data  -> Send Reset : Data送信完了時
    // Send Reset -> Idle       : 同期リセット or (is_enable == false)
    // Send Data  -> Idle       : 同期リセット(データ送信途中でのenableネゲートでいきなり打ち切るとLEDが中途半端に光ったままになる)
    localparam SATATE_IDLE      = 4'd0; // 何もしない
    localparam STATE_SEND_RESET = 4'd1; // WS2812にRESET Signal送信中
    localparam STATE_SEND_DATA  = 4'd2; // データ送信中

    reg [3:0]  state;           // 現在の動作モード
    reg [31:0] currentLedCount; // 現在処理しているLEDの位置
    reg [7:0]  currentBitCount; // 現在処理している色データのbit位置
    reg [23:0] currentColor;    // 現在表示しようとしている色データ

    always @ (posedge clk or negedge reset_n) begin
        if (reset_n != 1'b1) begin
            state <= #DELAY STATE_IDLE;
        end else if (state == STATE_IDLE) begin
            state <= #DELAY STATE_SEND_RESET;
        end else begin
            // do nothing
        end
    end
endmodule