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
