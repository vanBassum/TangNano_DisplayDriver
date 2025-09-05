module LineBuffer (
    input         wr_clk,
    input  [9:0]  wr_addr,
    input  [23:0] wr_data,
    input         wr_en,

    input         rd_clk,
    input  [9:0]  rd_addr,
    output [23:0] rd_data
);

    Gowin_DPB dpb_inst (
        .clka   (wr_clk),
        .cea    (1'b1),
        .ocea   (1'b0),
        .reseta (1'b0),
        .wrea   (wr_en),
        .ada    (wr_addr),
        .dina   (wr_data),
        .douta  (),

        .clkb   (rd_clk),
        .ceb    (1'b1),
        .oceb   (1'b1),
        .resetb (1'b0),
        .wreb   (1'b0),
        .adb    (rd_addr),
        .dinb   (24'd0),
        .doutb  (rd_data)
    );

endmodule



module LineBuffers(
    input              clk_pixel,
    input              clk_psram,
    input              rst_n,

    // Buffer select (pixel domain)
    input              buf_switch,

    // Write interface (PSRAM domain)
    input      [9:0]   wr_addr,
    input      [23:0]  wr_data,
    input              wr_en,
    
    // Read interface (pixel domain)
    input      [9:0]   rd_addr,
    output     [23:0]  rd_data
);

    // --- Internal wires ---
    wire [23:0] bufA_rd, bufB_rd;

    // --- Line buffer A ---
    Gowin_DPB bufA (
        .clka   (clk_psram),
        .cea    (1'b1),
        .ocea   (1'b0),
        .reseta (1'b0),
        .wrea   (wr_en & ~buf_switch),
        .ada    (wr_addr),
        .dina   (wr_data),
        .douta  (),

        .clkb   (clk_pixel),
        .ceb    (1'b1),
        .oceb   (1'b1),
        .resetb (1'b0),
        .wreb   (1'b0),
        .adb    (rd_addr),
        .dinb   (24'd0),
        .doutb  (bufA_rd)
    );

    // --- Line buffer B ---
    Gowin_DPB bufB (
        .clka   (clk_psram),
        .cea    (1'b1),
        .ocea   (1'b0),
        .reseta (1'b0),
        .wrea   (wr_en & buf_switch),
        .ada    (wr_addr),
        .dina   (wr_data),
        .douta  (),

        .clkb   (clk_pixel),
        .ceb    (1'b1),
        .oceb   (1'b1),
        .resetb (1'b0),
        .wreb   (1'b0),
        .adb    (rd_addr),
        .dinb   (24'd0),
        .doutb  (bufB_rd)
    );

    // --- Output mux ---
    assign rd_data = buf_switch ? bufB_rd : bufA_rd;

endmodule