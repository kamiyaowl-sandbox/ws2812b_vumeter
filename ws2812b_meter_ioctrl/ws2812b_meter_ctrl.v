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
    // Reset -> High  : Send Data遷移時
    // High  -> Low   : Send Data継続時
    // Low   -> High  : Send Data継続時
    // High  -> Reset : Idle遷移時
    // Low   -> Reset : Idle遷移時
    localparam ENC_STATE_RESET = 2'd0; // 0固定出力
    localparam ENC_STATE_HIGH  = 2'd1; // 1出力
    localparam ENC_STATE_LOW   = 2'd2; // 0出力

    reg [1:0] encState;          // 現在のエンコードステータス
    reg [15:0] currentEncCount;  // 現在PWMエンコードしている周期カウント, COUNT_RESETが収まる必要がある(100MHzだと10000なので16bitあれば足りる)
    reg [15:0] maxEncCount;      // DOUTを変更するまでのカウント数
    reg reloadFlag;              // currentEncCountが最大値のときにアサートされます。このタイミングで次のbitdataをcurrentDataBitにアサインする
    reg currentDataBit;          // 現在エンコード中のデータ

    // 状態遷移
    // Idle       -> Send Reset : enable == true
    // Send Reset -> Send Data  : Reset送信完了時
    // Send Data  -> Send Reset : Data送信完了時
    // Send Reset -> Idle       : enable == false
    // Send Data  -> Idle       : enable == false
    localparam RUN_STATE_IDLE       = 4'd0; // 何もしない
    localparam RUN_STATE_SEND_RESET = 4'd1; // WS2812にRESET Signal送信中
    localparam RUN_STATE_SEND_DATA  = 4'd2; // データ送信中

    reg [3:0]  runState;         // 現在の動作モード
    reg [15:0] currentLedCount;  // 現在処理しているLEDの位置
    reg [4:0]  currentBitCount;  // 現在処理している色データのbit位置
    reg [23:0] currentColor;     // 現在表示しようとしている色データ

    always @ (posedge clk or negedge reset_n) begin
        if (reset_n != 1'b1) begin
            DOUT <= #DELAY 1'd0;
            encState <= #DELAY ENC_STATE_RESET; 
            currentEncCount <= #DELAY 16'd0;
            maxEncCount <= #DELAY 16'd0;
            reloadFlag <= #DELAY 1'd0;
        end else begin
            case (state)
                STATE_SEND_RESET: begin
                    if (currentEncCount < (COUNT_RESET - 16'd1))
                        // RESET区間0を保つ
                        DOUT <= #DELAY 1'd0;
                        encState <= #DELAY ENC_STATE_RESET; 
                        currentEncCount <= #DELAY currentEncCount + 16'd1;
                        maxEncCount <= #DELAY 16'd0;
                        reloadFlag <= #DELAY 1'd0;
                    else if (currentEncCount == (COUNT_RESET - 16'd1)) begin
                        // reloadFlagを建てる
                        DOUT <= #DELAY 1'd0;
                        encState <= #DELAY ENC_STATE_RESET; 
                        currentEncCount <= #DELAY currentEncCount + 16'd1;
                        maxEncCount <= #DELAY 16'd0;
                        reloadFlag <= #DELAY 1'd1;
                    end else begin
                        // 初期状態に戻る
                        DOUT <= #DELAY 1'd0;
                        encState <= #DELAY ENC_STATE_RESET; 
                        currentEncCount <= #DELAY 16'd0;
                        maxEncCount <= #DELAY 16'd0;
                        reloadFlag <= #DELAY 1'd0;
                    end
                end
                STATE_SEND_DATA: begin
                    if (currentEncCount == 16'd0) begin
                        // 対象データ(currentDataBit)を見てデータを保持する区間を決定
                        case (encState)
                            ENC_STATE_RESET: begin
                                // Reset->Highに遷移する際にreloadフラグを立ててdata0を読むサイクルを与える
                                DOUT <= #DELAY 1'd0;
                                encState <= #DELAY ENC_STATE_LOW; 
                                currentEncCount <= #DELAY 16'd0;
                                maxEncCount <= #DELAY (currentDataBit) ? COUNT_T1H_NS : COUNT_T0H_NS;
                                reloadFlag <= #DELAY 1'd1;
                            end
                            ENC_STATE_HIGH: begin
                                DOUT <= #DELAY 1'd0;
                                encState <= #DELAY ENC_STATE_LOW; 
                                currentEncCount <= #DELAY currentEncCount + 16'd1;
                                maxEncCount <= #DELAY (currentDataBit) ? COUNT_T1H_NS : COUNT_T0H_NS;
                                reloadFlag <= #DELAY 1'd0;
                            end
                            default: begin // ENC_STATE_LOW含む
                                DOUT <= #DELAY 1'd1;
                                encState <= #DELAY ENC_STATE_HIGH; 
                                currentEncCount <= #DELAY currentEncCount + 16'd1;
                                maxEncCount <= #DELAY (currentDataBit) ? COUNT_T1L_NS : COUNT_T0L_NS;
                                reloadFlag <= #DELAY 1'd0;
                            end
                        endcase
                    end else if (currentEncCount < (maxEncCount - 16'd0)) begin
                        // DOUTを保持
                        currentEncCount <= #DELAY currentEncCount + 16'd1;
                        reloadFlag <= #DELAY 1'd0;
                    end else if (currentEncCount == (maxEncCount - 16'd0)) begin
                        //reloadFlagを建てる
                        currentEncCount <= #DELAY currentEncCount + 16'd1;
                        reloadFlag <= #DELAY 1'd1;
                    end else begin
                        // 最初に戻る
                        currentEncCount <= #DELAY currentEncCount + 16'd0;
                        reloadFlag <= #DELAY 1'd0;
                    end
                end
                default: begin // RUN_STATE_IDLE含む
                    DOUT <= #DELAY 1'd0;
                    encState <= #DELAY ENC_STATE_RESET; 
                    currentEncCount <= #DELAY 16'd0;
                    reloadFlag <= #DELAY 1'd0;
                end
            endcase
            end
        end
    end

    always @ (posedge clk or negedge reset_n) begin
        if (reset_n != 1'b1) begin
            state <= #DELAY STATE_IDLE;
            currentLedCount <= #DELAY 16'd0;
            currentBitCount <= #DELAY 5'd0;
            currentColor    <= #DELAY 24'd0;
        end else begin
            case (state)
                STATE_SEND_RESET: begin
                    // RESET区間が終わる時点でアサートされるので状態遷移する
                    if (reloadFlag == 1'd1) begin
                        // disableのときはIDLEに戻る
                        if (enable == 1'd1) begin
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
                    if (reloadFlag == 1'd1) begin
                        if (currentBitCount == 5'd0) begin
                            // 24bitごとに色情報を更新
                            if (currentLedCount < onCount) begin
                                // 色を決定して表示
                                if (currentLedCount < visibleCounts[0]) begin
                                    currentDataBit <= #DELAY colors[0][23];
                                    currentColor <= #DELAY { colors[0][22:0], 1'd0 };
                                end else if (currentLedCount < visibleCounts[1]) begin
                                    currentDataBit <= #DELAY colors[1][23];
                                    currentColor <= #DELAY { colors[1][22:0], 1'd0 };
                                end else if (currentLedCount < visibleCounts[2]) begin
                                    currentDataBit <= #DELAY colors[2][23];
                                    currentColor <= #DELAY { colors[2][22:0], 1'd0 };
                                end else begin
                                    // 定義範囲外は黒固定
                                    currentDataBit <= #DELAY 1'd0;
                                    currentColor <= #DELAY 24'd0;
                                end
                                // カウントもすすめる
                                currentBitCount <= #DELAY currentBitCount + 5'd1;
                            else if (currentLedCount < maxCount) begin
                                // 黒固定
                                currentDataBit <= #DELAY 1'd0;
                                currentColor <= #DELAY 24'd0;
                                currentBitCount <= #DELAY currentBitCount + 5'd1;
                            end else begin
                                // maxCountまで贈りきったらRESETに戻る
                                currentDataBit <= #DELAY 1'd0;
                                currentColor <= #DELAY 24'd0;
                                state <= #DELAY STATE_SEND_RESET;
                                currentBitCount <= #DELAY 5'd0;
                            end
                        end else if(currentBitCount < 5'd22) begin
                            // 現在の色を上位ビットから押し出して出力
                            currentDataBit <= #DELAY currentColor[23];
                            currentColor <= #DELAY { currentColor[22:0], 1'd0 };
                            currentBitCount <= #DELAY currentBitCount + 5'd1;
                        end else begin
                            // 最初に戻って次の色をロード
                            currentDataBit <= #DELAY currentColor[23];
                            currentColor <= #DELAY { currentColor[22:0], 1'd0 };
                            currentBitCount <= #DELAY 5'd0;
                        end
                    end
                end
                default: begin // STATE_IDLEを含む
                    // disableのときはIDLEを継続
                    DOUT <= #DELAY 1'd0;
                    state <= #DELAY (enable == 1'd1) ? STATE_SEND_RESET : STATE_IDLE;
                end
            endcase
        end
    end

endmodule
