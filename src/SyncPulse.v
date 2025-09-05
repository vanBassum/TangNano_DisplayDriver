module SyncPulse (
    input  wire clk_dst,
    input  wire rst_n,
    input  wire pulse_in,   // single-cycle in src domain
    output wire pulse_out   // single-cycle in dst domain
);
    reg meta, sync, last;
    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            meta <= 0;
            sync <= 0;
            last <= 0;
        end else begin
            meta <= pulse_in;
            sync <= meta;
            last <= sync;
        end
    end

    assign pulse_out = sync & ~last;
endmodule
