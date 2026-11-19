`timescale 1ns / 1ps

module digital_lock #(
    parameter integer CLOCK_HZ = 100_000_000,
    parameter [15:0] PASSWORD = 16'h6723  // 4 haneli BCD sifre: 6723
)(
    input  wire        clk,
    input  wire        btn_enter,
    input  wire        btn_reset,
    input  wire [15:0] sw,
    output reg         led_open,
    output reg         led_error,
    output reg         led_blocked,
    output reg  [6:0]  seg,
    output wire        dp,
    output reg  [7:0]  an
);
    // Nexys A7 ortak anot (active-low): nokta (DP) kapali
    assign dp = 1'b1;

    // 16 bitlik anahtari 4 adet 0-9 basamagina bolme
    wire [3:0] d3 = sw[15:12];
    wire [3:0] d2 = sw[11:8];
    wire [3:0] d1 = sw[7:4];
    wire [3:0] d0 = sw[3:0];

    // Tum basamaklarin gecerli (0-9) olup olmadigi kontrolu
    wire digits_valid = (d3 <= 4'd9) && (d2 <= 4'd9) &&
                        (d1 <= 4'd9) && (d0 <= 4'd9);

    // XNOR + AND mantigi ile sifre karsilastirma
    wire password_ok = digits_valid && (&(~(sw ^ PASSWORD)));

    // Buton filtreleme (10 ms debounce; simulasyonda minimum 2 cevrim)
    localparam integer DEBOUNCE_CYCLES =
        (CLOCK_HZ / 100 < 2) ? 2 : CLOCK_HZ / 100;
    localparam integer COUNTER_WIDTH =
        (DEBOUNCE_CYCLES <= 2) ? 1 : $clog2(DEBOUNCE_CYCLES);

    // 7-Segment tarama hizi (~1 kHz basamak gecisi; simulasyonda min 2 cevrim)
    localparam integer REFRESH_CYCLES =
        (CLOCK_HZ / 1000 < 2) ? 2 : CLOCK_HZ / 1000;
    localparam integer REFRESH_WIDTH =
        (REFRESH_CYCLES <= 2) ? 1 : $clog2(REFRESH_CYCLES);

    reg enter_meta;
    reg enter_sync;
    reg enter_stable;
    reg enter_stable_prev;
    reg [COUNTER_WIDTH-1:0] debounce_count;
    reg [1:0] wrong_count;

    reg [REFRESH_WIDTH-1:0] refresh_count;
    reg [1:0] digit_sel;
    reg [3:0] current_bcd;

    always @(posedge clk) begin
        if (btn_reset) begin
            enter_meta        <= 1'b0;
            enter_sync        <= 1'b0;
            enter_stable      <= 1'b0;
            enter_stable_prev <= 1'b0;
            debounce_count    <= {COUNTER_WIDTH{1'b0}};
            wrong_count       <= 2'd0;
            led_open          <= 1'b0;
            led_error         <= 1'b0;
            led_blocked       <= 1'b0;
            refresh_count     <= {REFRESH_WIDTH{1'b0}};
            digit_sel         <= 2'd0;
        end else begin
            // Asenkron buton icin 2-FF senkronizator
            enter_meta <= btn_enter;
            enter_sync <= enter_meta;

            // ENTER butonu debounce sayaci
            if (enter_sync == enter_stable) begin
                debounce_count <= {COUNTER_WIDTH{1'b0}};
            end else if (debounce_count == DEBOUNCE_CYCLES - 1) begin
                enter_stable   <= enter_sync;
                debounce_count <= {COUNTER_WIDTH{1'b0}};
            end else begin
                debounce_count <= debounce_count + 1'b1;
            end

            // Tek basista tek deneme uretme ve kilit durumu
            enter_stable_prev <= enter_stable;
            if (enter_stable && !enter_stable_prev &&
                !led_open && !led_blocked) begin
                if (password_ok) begin
                    led_open  <= 1'b1;
                    led_error <= 1'b0;
                end else begin
                    wrong_count <= wrong_count + 1'b1;
                    if (wrong_count == 2'd2) begin
                        led_error   <= 1'b0;
                        led_blocked <= 1'b1;
                    end else begin
                        led_error <= 1'b1;
                    end
                end
            end

            // 7-Segment coklama (time-multiplexing) sayaci
            if (refresh_count == REFRESH_CYCLES - 1) begin
                refresh_count <= {REFRESH_WIDTH{1'b0}};
                digit_sel     <= digit_sel + 2'd1;
            end else begin
                refresh_count <= refresh_count + 1'b1;
            end
        end
    end

    // Ortak Anot (Active-Low) 7-Segment kod cozucu
    // seg = {CG, CF, CE, CD, CC, CB, CA}
    always @(*) begin
        case (digit_sel)
            2'd0: begin
                an          = 8'b1111_1110; // Sagdaki 1. basamak aktif
                current_bcd = d0;
            end
            2'd1: begin
                an          = 8'b1111_1101; // 2. basamak aktif
                current_bcd = d1;
            end
            2'd2: begin
                an          = 8'b1111_1011; // 3. basamak aktif
                current_bcd = d2;
            end
            default: begin
                an          = 8'b1111_0111; // 4. basamak aktif
                current_bcd = d3;
            end
        endcase

        case (current_bcd)
            4'd0:    seg = 7'b100_0000; // 0
            4'd1:    seg = 7'b111_1001; // 1
            4'd2:    seg = 7'b010_0100; // 2
            4'd3:    seg = 7'b011_0000; // 3
            4'd4:    seg = 7'b001_1001; // 4
            4'd5:    seg = 7'b001_0010; // 5
            4'd6:    seg = 7'b000_0010; // 6
            4'd7:    seg = 7'b111_1000; // 7
            4'd8:    seg = 7'b000_0000; // 8
            4'd9:    seg = 7'b001_0000; // 9
            default: seg = 7'b000_0110; // 'E' (9'dan buyuk gecersiz rakam)
        endcase
    end
endmodule