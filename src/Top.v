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

    // PSRAM pins (unused for now)
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

    // --- Generator FSM (checkerboard pattern) ---
    reg [9:0]  gen_count;
    reg [23:0] gen_data;
    reg        gen_wr_en;
    reg        writing;

    wire [9:0] line_idx;
    wire       line_req;

    always @(posedge clk_psram or negedge rst_n) begin
        if (!rst_n) begin
            gen_count <= 0;
            gen_wr_en <= 0;
            writing   <= 0;
        end else begin
            if (line_req && !writing) begin
                writing   <= 1;
                gen_count <= 0;
            end else if (writing) begin
                gen_wr_en <= 1;
                gen_data  <= (gen_count[3] ^ line_idx[3]) ? 24'h888888 : 24'h444444;
                gen_count <= gen_count + 1;

                if (gen_count == 10'd799) begin
                    writing   <= 0;
                    gen_wr_en <= 0;
                end
            end else begin
                gen_wr_en <= 0;
            end
        end
    end

    // --- Hook up VideoSystem ---
    VideoSystem video (
        .clk_pixel    (clk_pixel),
        .clk_psram    (clk_psram),
        .rst_n        (rst_n),

        .wr_addr      (gen_count),
        .wr_data      (gen_data),
        .wr_en        (gen_wr_en),
        .line_idx     (line_idx),
        .line_req     (line_req),
        
        .LCD_CLK      (LCD_CLK),
        .LCD_HSYNC    (LCD_HSYNC),
        .LCD_VSYNC    (LCD_VSYNC),
        .LCD_DEN      (LCD_DEN),
        .LCD_R        (LCD_R),
        .LCD_G        (LCD_G),
        .LCD_B        (LCD_B)
    );

endmodule
