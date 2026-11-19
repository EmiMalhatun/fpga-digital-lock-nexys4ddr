`timescale 1ns / 1ps

module digital_lock_tb;
    logic clk = 1'b0;
    logic btn_enter = 1'b0;
    logic btn_reset = 1'b1;
    logic [15:0] sw = 16'h0000;
    wire led_open, led_error, led_blocked;
    wire [6:0] seg;
    wire dp;
    wire [7:0] an;

    digital_lock #(
        .CLOCK_HZ(1000),
        .PASSWORD(16'h6723)
    ) dut (
        .clk(clk),
        .btn_enter(btn_enter),
        .btn_reset(btn_reset),
        .sw(sw),
        .led_open(led_open),
        .led_error(led_error),
        .led_blocked(led_blocked),
        .seg(seg),
        .dp(dp),
        .an(an)
    );

    always #5 clk = ~clk;

    task automatic enter_code(input logic [15:0] code);
        @(negedge clk);
        sw = code;
        btn_enter = 1'b1;
        repeat (20) @(negedge clk);
        btn_enter = 1'b0;
        repeat (20) @(negedge clk);
    endtask

    task automatic expect_leds(
        input logic open_expected,
        input logic error_expected,
        input logic blocked_expected,
        input string scenario
    );
        if ({led_open, led_error, led_blocked} !==
            {open_expected, error_expected, blocked_expected}) begin
            $display("FAIL: %s (actual=%b%b%b; expected=%b%b%b)",
                     scenario, led_open, led_error, led_blocked,
                     open_expected, error_expected, blocked_expected);
            $fatal(1, "Test failed");
        end else begin
            $display("PASS: %s", scenario);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        btn_reset = 1'b0;
        repeat (2) @(negedge clk);
        expect_leds(0, 0, 0, "initial reset");

        // 1. yanlis sifre: 0000
        enter_code(16'h0000);
        expect_leds(0, 1, 0, "first wrong decimal code (0000)");

        // 2. yanlis sifre: 1234
        enter_code(16'h1234);
        expect_leds(0, 1, 0, "second wrong decimal code (1234)");

        // 3. yanlis sifre (9'dan buyuk gecersiz rakam iceren giris): blokaj
        enter_code(16'h672A);
        expect_leds(0, 0, 1, "third wrong/invalid code blocks the lock");

        // Bloke durumdayken dogru sifre (6723) acmamali
        enter_code(16'h6723);
        expect_leds(0, 0, 1, "correct code (6723) cannot bypass lockout");

        // Reset ile kilidi sifirlama
        @(negedge clk);
        btn_reset = 1'b1;
        repeat (3) @(negedge clk);
        btn_reset = 1'b0;
        repeat (2) @(negedge clk);
        expect_leds(0, 0, 0, "reset releases lockout");

        // Dogru sifre: 6723
        enter_code(16'h6723);
        expect_leds(1, 0, 0, "correct code (6723) opens the lock");

        // Acikken baska kod girisi durumu bozmamali
        enter_code(16'h5555);
        expect_leds(1, 0, 0, "lock stays open until reset");

        $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin
        #15000;
        $fatal(1, "Timeout: testbench did not complete");
    end
endmodule