`default_nettype none

module tt_um_fep_core (
    input  wire [7:0] ui_in,    // 外部入力 (8bit): x_in (Q1.14 の上位 8bit)
    output wire [7:0] uo_out,   // 外部出力 (8bit): mu_out (Q1.14 の上位 8bit)
    input  wire [7:0] uio_in,   // 双方向IO (入力)
    output wire [7:0] uio_out,  // 双方向IO (出力): {alert_gate, error_outの上位7bit}
    output wire [7:0] uio_oe,   // 双方向IOの方向制御 (全ビット 1 で出力設定)
    input  wire       ena,      // チップ有効化信号 (使わない場合は無視)
    input  wire       clk,      // クロック信号
    input  wire       rst_n     // リセット信号 (Low アクティブ)
);

    // 双方向ピンを出力専用に設定
    assign uio_oe = 8'hFF;

    // --- 入出力のマッピング (16bit 固定小数点を 8bit ピンに接続) ---
    // 8bit 入力 ui_in を Q1.14 フォーマットの上位ビットに配置
    wire signed [15:0] x_in_16 = {ui_in, 8'b0};
    
    wire signed [15:0] mu_out_16;
    wire signed [15:0] error_out_16;
    wire alert_gate;

    // FEP コアのインスタンス化
    fep_core u_fep (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(x_in_16),
        .mu_out(mu_out_16),
        .error_out(error_out_16),
        .alert_gate(alert_gate)
    );

    // 演算結果の上位ビットを出力ピンへアサイン
    assign uo_out  = mu_out_16[15:8];
    assign uio_out = {alert_gate, error_out_16[14:8]};

endmodule


// =========================================================================
// FEP Core モジュール（自由エネルギー原理に基づく予測誤差最小化コア）
// =========================================================================
module fep_core (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] x_in,
    output reg signed [15:0] mu_out,
    output wire signed [15:0] error_out,
    output reg alert_gate
);

    // 予測誤差 e = x - mu
    assign error_out = x_in - mu_out;

    // 誤差絶対値の計算
    wire signed [15:0] abs_error = (error_out < 0) ? -error_out : error_out;

    // 勾配降下による内部状態 μ の更新処理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mu_out     <= 16'sh0000;
            alert_gate <= 1'b0;
        end else begin
            // 急激な環境変化（大きな予測誤差）に対する自己防衛・学習率制御
            if (abs_error > 16'sh2000) begin // 0.5 (Q1.14) 超過でアラート
                alert_gate <= 1'b1;
                // 学習率を絞る (>>> 6)
                mu_out <= mu_out + (error_out >>> 6);
            end else begin
                alert_gate <= 1'b0;
                // 通常学習率 (>>> 3)
                mu_out <= mu_out + (error_out >>> 3);
            end
        end
    end

endmodule
