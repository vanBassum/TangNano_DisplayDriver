module TOP
(
    input         Reset_Button,
    input         User_Button,
    input         XTAL_IN,

    output  [5:0] LED,

    // LCD panel interface
    output        LCD_CLK,
    output        LCD_HSYNC,
    output        LCD_VSYNC,
    output        LCD_DEN,
    output  [4:0] LCD_R,
    output  [5:0] LCD_G,
    output  [4:0] LCD_B,
    
    // UART (115200 baud for now)
    input         UART_RX,
    output        UART_TX,

    // PSRAM pins
    output [1:0]  O_psram_ck,
    output [1:0]  O_psram_ck_n,
    output [1:0]  O_psram_cs_n,
    output [1:0]  O_psram_reset_n,
    inout  [1:0]  IO_psram_rwds,
    inout  [15:0] IO_psram_dq
);

    // --- Clocks / reset ---
    wire clk_psram;
    wire clk_pixel;
    wire clk_sys = clk_pixel;

    wire pll_lock_psram, pll_lock_pixel, pll_lock;
    assign pll_lock = pll_lock_psram & pll_lock_pixel;
    wire rst_n = Reset_Button & pll_lock;

    pll33 pixelPll (
        .clkout (clk_pixel),
        .lock   (pll_lock_pixel),
        .clkin  (XTAL_IN)
    );

    pll162 ramPll (
        .clkout (clk_psram),
        .lock   (pll_lock_psram),
        .clkin  (XTAL_IN)
    );

    // --- PSRAM controller <-> arbiter bus ---
    wire [20:0] psram_addr;
    wire        psram_cmd, psram_cmd_en;
    wire [63:0] psram_wr_data, psram_rd_data;
    wire [7:0]  psram_mask;
    wire        psram_rd_valid, init_calib, clk_out;

    PSRAM_Memory_Interface_HS_Top psram_inst (
        .clk          (clk_sys),
        .memory_clk   (clk_psram),
        .pll_lock     (pll_lock),
        .rst_n        (rst_n),

        .O_psram_ck       (O_psram_ck),
        .O_psram_ck_n     (O_psram_ck_n),
        .IO_psram_dq      (IO_psram_dq),
        .IO_psram_rwds    (IO_psram_rwds),
        .O_psram_cs_n     (O_psram_cs_n),
        .O_psram_reset_n  (O_psram_reset_n),

        .wr_data      (psram_wr_data),
        .rd_data      (psram_rd_data),
        .rd_data_valid(psram_rd_valid),
        .addr         (psram_addr),
        .cmd          (psram_cmd),
        .cmd_en       (psram_cmd_en),
        .init_calib   (init_calib),
        .clk_out      (clk_out),
        .data_mask    (psram_mask)
    );

    // --- LCD timing generator ---
    wire [23:0] rgb_test;
    wire [10:0] x_pos;
    wire [9:0]  y_pos;

    LCD_Timing lcd (
        .PixelClk   (clk_pixel),
        .nRST       (rst_n),
        .LCD_CLK    (LCD_CLK),
        .LCD_DE     (LCD_DEN),
        .LCD_HSYNC  (LCD_HSYNC),
        .LCD_VSYNC  (LCD_VSYNC),
        .LCD_R      (LCD_R),
        .LCD_G      (LCD_G),
        .LCD_B      (LCD_B),
        .rgb        (rgb_test),
        .x_pos      (x_pos),
        .y_pos      (y_pos)
    );

endmodule
