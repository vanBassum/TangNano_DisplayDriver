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
    
    // UART
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

    // --- VideoSystem ---
    wire [9:0] y_pos;
    wire       line_request;

    reg  [9:0]  wr_addr;
    reg  [23:0] wr_data;
    reg         wr_en;

    VideoSystem #(.H_RES(800)) video (
        .clk_pixel    (clk_pixel),
        .clk_psram    (clk_psram),
        .rst_n        (rst_n),

        .wr_addr      (wr_addr),
        .wr_data      (wr_data),
        .wr_en        (wr_en),

        .LCD_CLK      (LCD_CLK),
        .LCD_HSYNC    (LCD_HSYNC),
        .LCD_VSYNC    (LCD_VSYNC),
        .LCD_DEN      (LCD_DEN),
        .LCD_R        (LCD_R),
        .LCD_G        (LCD_G),
        .LCD_B        (LCD_B),

        .y_pos        (y_pos),
        .line_request (line_request)
    );


    // --- Generator (test pattern in psram domain) ---
    reg [9:0] gen_cnt;   // counts 0..799
    reg       writing;

    always @(posedge clk_psram or negedge rst_n) begin
        if (!rst_n) begin
            gen_cnt  <= 0;
            wr_en    <= 0;
            wr_addr  <= 0;
            wr_data  <= 24'h000000;
            writing  <= 0;
        end else begin
            wr_en <= 0; // default

            if (line_request && !writing) begin
                // start generating a new line
                gen_cnt <= 0;
                writing <= 1;
            end else if (writing) begin
                wr_en   <= 1;
                wr_addr <= gen_cnt;

                // Checkerboard: alternate every 16 pixels
                if ((wr_addr[4] ^ y_pos[4]) == 1'b0)
                    wr_data <= 24'h444444; // red
                else
                    wr_data <= 24'hEEEEEE; // blue


                gen_cnt <= gen_cnt + 1;
                if (gen_cnt == 10'd799) begin
                    writing <= 0; // done with line
                end
            end
        end
    end



endmodule
