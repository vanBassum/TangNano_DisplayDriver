module VideoSystem #(
    parameter H_RES = 800
)(
    // LCD panel interface
    input              clk_pixel,
    output             LCD_CLK,
    output             LCD_HSYNC,
    output             LCD_VSYNC,
    output             LCD_DEN,
    output      [4:0]  LCD_R,
    output      [5:0]  LCD_G,
    output      [4:0]  LCD_B,

    // Write interface (psram domain)
    input              clk_psram,
    input              rst_n,
    input      [9:0]   wr_addr,
    input      [23:0]  wr_data,
    input              wr_en,
    output     [9:0]   y_pos,

    // request to producer (synchronized to psram clock)
    output             line_request
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
    reg line_req_pix; // in pixel domain
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            buf_select_r <= 0;
            line_req_pix <= 0;
        end else begin
            line_req_pix <= 0;
            if (de_d && !lcd_de) begin
                buf_select_r <= ~buf_select_r;
                line_req_pix <= 1; // pulse at end of line
            end
        end
    end

    // --- synchronize line_request into psram domain ---
    reg line_meta, line_sync, line_last;
    always @(posedge clk_psram or negedge rst_n) begin
        if (!rst_n) begin
            line_meta <= 0;
            line_sync <= 0;
            line_last <= 0;
        end else begin
            line_meta <= line_req_pix;
            line_sync <= line_meta;
            line_last <= line_sync;
        end
    end

    assign line_request = line_sync & ~line_last; // clean pulse in psram domain

    // --- synchronize buffer select into psram domain ---
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
        .wr_en  (wr_en & ~buf_sel_sync),
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_clk (clk_pixel),
        .rd_addr(x_pos[9:0]),
        .rd_data(bufA_rd)
    );

    LineBuffer bufB (
        .wr_clk (clk_psram),
        .wr_en  (wr_en & buf_sel_sync),
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_clk (clk_pixel),
        .rd_addr(x_pos[9:0]),
        .rd_data(bufB_rd)
    );

    // --- mux to LCD ---
    assign buf_pixel = (buf_select_r) ? bufB_rd : bufA_rd;

endmodule
