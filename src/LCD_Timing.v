module LCD_Timing
(
    input         PixelClk,   // pixel clock ~33 MHz
    input         nRST,       // active low reset

    output        LCD_CLK,
    output        LCD_DE,
    output        LCD_HSYNC,
    output        LCD_VSYNC,

    output [4:0]  LCD_R,
    output [5:0]  LCD_G,
    output [4:0]  LCD_B,

    input  [23:0] rgb,        // RGB888 pixel input

    output reg [10:0] x_pos,  // current X position (0..799)
    output reg [9:0]  y_pos   // current Y position (0..479)
);

    // --- Timing constants (from datasheet, typical values) ---
    localparam H_ACTIVE   = 800;   // pixels
    localparam H_FP       = 40;    // front porch
    localparam H_SYNC     = 48;    // sync pulse
    localparam H_BP       = 40;    // back porch
    localparam H_TOTAL    = H_ACTIVE + H_FP + H_SYNC + H_BP; // 928

    localparam V_ACTIVE   = 480;   // lines
    localparam V_FP       = 13;    // front porch
    localparam V_SYNC     = 1;     // sync pulse
    localparam V_BP       = 31;    // back porch
    localparam V_TOTAL    = V_ACTIVE + V_FP + V_SYNC + V_BP; // 525

    reg [10:0] pixel_count;
    reg [9:0]  line_count;

    // --- Counters ---
    always @(posedge PixelClk or negedge nRST) begin
        if (!nRST) begin
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

    // --- Sync signals (active HIGH per datasheet) ---
    assign LCD_HSYNC = (pixel_count >= H_ACTIVE + H_FP) &&
                       (pixel_count <  H_ACTIVE + H_FP + H_SYNC);

    assign LCD_VSYNC = (line_count >= V_ACTIVE + V_FP) &&
                       (line_count <  V_ACTIVE + V_FP + V_SYNC);

    // --- Data enable ---
    assign LCD_DE = (pixel_count < H_ACTIVE) &&
                    (line_count  < V_ACTIVE);

    // --- Current pixel position ---
    always @(posedge PixelClk or negedge nRST) begin
        if (!nRST) begin
            x_pos <= 0;
            y_pos <= 0;
        end else begin
            if (pixel_count < H_ACTIVE)
                x_pos <= pixel_count;
            else
                x_pos <= 0;

            if (line_count < V_ACTIVE)
                y_pos <= line_count;
            else
                y_pos <= 0;
        end
    end

    // --- RGB output (truncate 8-bit -> 5/6/5) ---
    assign LCD_R = rgb[23:19]; // top 5 bits
    assign LCD_G = rgb[15:10]; // top 6 bits
    assign LCD_B = rgb[7:3];   // top 5 bits
    
    assign LCD_CLK = PixelClk; 
endmodule
