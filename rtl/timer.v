`timescale 1ns / 1ps

module timer (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] timecmp,
    output reg  [63:0] mtime_out,
    output wire        timer_interrupt
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mtime_out <= 64'd0;
        end else begin
            mtime_out <= mtime_out + 64'd1;
        end
    end

    // Trigger an interrupt if current time >= timecmp
    // Note: To "disable" the timer, software typically writes a very large value to timecmp (e.g., all 1s).
    assign timer_interrupt = (mtime_out >= timecmp);

endmodule
