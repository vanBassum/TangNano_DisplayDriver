module SyncLevel (
    input  wire clk_dst,
    input  wire rst_n,
    input  wire level_in,  // async level
    output reg  level_out
);
    reg meta;
    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            meta      <= 0;
            level_out <= 0;
        end else begin
            meta      <= level_in;
            level_out <= meta;
        end
    end
endmodule
