`timescale 1ns / 1ps

module regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [63:0] wd,
    input  wire        we,
    output wire [63:0] rd1,
    output wire [63:0] rd2,
    // Debug ports
    output wire [63:0] r1_out,
    output wire [63:0] r2_out
);

    reg [63:0] registers [0:31];
    integer i;

    // Asynchronous read
    assign rd1 = (rs1 == 5'd0) ? 64'd0 : registers[rs1];
    assign rd2 = (rs2 == 5'd0) ? 64'd0 : registers[rs2];
    
    // For debugging
    assign r1_out = registers[1];
    assign r2_out = registers[2];

    // Synchronous write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 64'd0;
            end
        end else if (we && (rd != 5'd0)) begin // R0 is read-only 0
            registers[rd] <= wd;
        end
    end

endmodule
