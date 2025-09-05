module VideoSystem #(
    parameter H_ACTIVE = 800,
    parameter V_ACTIVE = 480,
    parameter H_FP     = 40,
    parameter H_SYNC   = 48,
    parameter H_BP     = 40,
    parameter V_FP     = 13,
    parameter V_SYNC   = 1,
    parameter V_BP     = 31
)(
    input              clk_pixel,
    input              clk_psram,
    input              rst_n,

    // Write interface (PSRAM domain)
    input      [9:0]   wr_addr,
    input      [23:0]  wr_data,
    input              wr_en,
    output     [9:0]   line_idx,   // requested line index (visible+1, or 0 for preload)
    output             line_req,   // high during active/preload line window

    // LCD interface
    output             LCD_CLK,
    output             LCD_HSYNC,
    output             LCD_VSYNC,
    output             LCD_DEN,
    output      [4:0]  LCD_R,
    output      [5:0]  LCD_G,
    output      [4:0]  LCD_B
);

    // --- Derived constants ---
    localparam H_TOTAL = H_SYNC + H_BP + H_ACTIVE + H_FP;
    localparam V_TOTAL = V_SYNC + V_BP + V_ACTIVE + V_FP;

    // --- Counters ---
    reg [$clog2(H_TOTAL)-1:0] pixel_count;
    reg [$clog2(V_TOTAL)-1:0] line_count;

    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            pixel_count <= 0;
            line_count  <= 0;
        end else begin
            if (pixel_count == H_TOTAL-1) begin
                pixel_count <= 0;
                if (line_count == V_TOTAL-1)
                    line_count <= 0;
                else
                    line_count <= line_count + 1'b1;
            end else begin
                pixel_count <= pixel_count + 1'b1;
            end
        end
    end

    // --- Sync signals ---
    assign LCD_HSYNC = (pixel_count < H_SYNC);
    assign LCD_VSYNC = (line_count  < V_SYNC);
    assign LCD_CLK   = clk_pixel;

    // --- Data enable ---
    wire lcd_de = (pixel_count >= H_SYNC + H_BP) &&
                  (pixel_count <  H_SYNC + H_BP + H_ACTIVE) &&
                  (line_count  >= V_SYNC + V_BP) &&
                  (line_count  <  V_SYNC + V_BP + V_ACTIVE);
    assign LCD_DEN = lcd_de;

    // --- Requested line index (next visible, clamp to 0 for preload) ---
    assign line_idx = (line_count >= V_SYNC + V_BP) ?
                      (line_count - (V_SYNC + V_BP) + 1) :
                      10'd0;

    // --- Line request: high only during active pixels (H_ACTIVE wide) ---
    wire in_visible_line = (line_count >= V_SYNC + V_BP - 1) &&
                           (line_count <  V_SYNC + V_BP + V_ACTIVE);
    
    // --- Sync line_req into PSRAM domain (level) ---
    SyncLevel u_sync_line (
        .clk_dst   (clk_psram),
        .rst_n     (rst_n),
        .level_in  (in_visible_line && lcd_de),
        .level_out (line_req)
    );

    // toggle buffer at end of *visible* region
    reg buf_select_r;
    always @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n)
            buf_select_r <= 0;
        else if (pixel_count == 0 &&
                 line_count >= V_SYNC + V_BP &&
                 line_count <  V_SYNC + V_BP + V_ACTIVE)
            buf_select_r <= ~buf_select_r;
    end

    // --- Sync buffer select to PSRAM domain ---
    wire buf_sel_sync;
    SyncLevel u_sync_buf (
        .clk_dst   (clk_psram),
        .rst_n     (rst_n),
        .level_in  (buf_select_r),
        .level_out (buf_sel_sync)
    );

    // --- Line buffers ---
    wire [23:0] buf_pixel;
    wire [9:0] visPx = pixel_count - (H_SYNC + H_BP);


    LineBuffers buffers (
        .clk_pixel  (clk_pixel),
        .clk_psram  (clk_psram),
        .rst_n      (rst_n),
        .buf_switch (buf_sel_sync),
        .wr_addr    (wr_addr),
        .wr_data    (wr_data),
        .wr_en      (wr_en),
        .rd_addr    (visPx),
        .rd_data    (buf_pixel)
    );

    assign LCD_R = buf_pixel[23:19] | 5'b01111;   // take top 5 bits + bias
    assign LCD_G = buf_pixel[15:10] | 6'b011111;  // already 6 bits, add bias
    assign LCD_B = buf_pixel[7:3]   | 5'b01111;   // already 5 bits, add bias


endmodule
