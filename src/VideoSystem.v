module VideoSystem #(
    parameter H_RES = 800
)(
    input              clk_pixel,
    input              clk_psram,
    input              rst_n,

    // Write interface (psram domain)
    input      [9:0]   wr_addr,
    input      [23:0]  wr_data,
    input              wr_en,

    // LCD panel interface
    output             LCD_CLK,
    output             LCD_HSYNC,
    output             LCD_VSYNC,
    output             LCD_DEN,
    output      [4:0]  LCD_R,
    output      [5:0]  LCD_G,
    output      [4:0]  LCD_B,

    // status back to TOP
    output     [9:0]   y_pos,
    output reg         line_request   // pulse at end of each line
);

    // --- LCD timing generator ---
    wire [23:0] buf_pixel;
    wire [10:0] x_pos;
    wire [9:0]  y_pos_int;
    wire        lcd_de;

    LCD_Timing lcd (
        .PixelClk   (clk_pixel),
        .nRST       (rst_n),
        .LCD_CLK    (LCD_CLK),
        .LCD_DE     (lcd_de),
        .LCD_HSYNC  (LCD_HSYNC),
        .LCD_VSYNC  (LCD_VSYNC),
        .LCD_R      (LCD_R),
        .LCD_G      (LCD_G),
        .LCD_B      (LCD_B),
        .rgb        (buf_pixel),
        .x_pos      (x_pos),
        .y_pos      (y_pos_int)
    );

    assign y_pos   = y_pos_int;
    assign LCD_DEN = lcd_de;

    // --- buffer select (ping-pong), swap on falling edge of DE ---
    reg de_d;
    always @(posedge clk_pixel) de_d <= lcd_de;

    reg buf_select_r;
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            buf_select_r <= 0;
            line_request <= 0;
        end else begin
            line_request <= 0; // default
            if (de_d && !lcd_de) begin
                buf_select_r <= ~buf_select_r;
                line_request <= 1; // pulse: request new line
            end
        end
    end

    // --- sync buffer select into psram clock domain ---
    reg buf_sel_meta, buf_sel_sync;
    always @(posedge clk_psram or negedge rst_n) begin
        if (!rst_n) begin
            buf_sel_meta <= 0;
            buf_sel_sync <= 0;
        end else begin
            buf_sel_meta <= buf_select_r;
            buf_sel_sync <= buf_sel_meta;
        end
    end

    // --- two line buffers ---
    wire [23:0] bufA_rd, bufB_rd;

    LineBuffer bufA (
        .wr_clk (clk_psram),
        .wr_en  (wr_en & ~buf_sel_sync), // auto-select
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_clk (clk_pixel),
        .rd_addr(x_pos[9:0]),
        .rd_data(bufA_rd)
    );

    LineBuffer bufB (
        .wr_clk (clk_psram),
        .wr_en  (wr_en & buf_sel_sync),  // auto-select
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_clk (clk_pixel),
        .rd_addr(x_pos[9:0]),
        .rd_data(bufB_rd)
    );

    // --- mux to LCD ---
    assign buf_pixel = (buf_select_r) ? bufB_rd : bufA_rd;

endmodule
