`timescale 1ns / 1ps

module alu (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [2:0]  alu_ctrl,
    output reg  [63:0] result,
    output wire        zero_flag
);

    // ALU Control Codes
    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_OR  = 3'b011;
    localparam ALU_XOR = 3'b100;
    localparam ALU_SHL = 3'b101;
    localparam ALU_SHR = 3'b110;

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_XOR: result = a ^ b;
            ALU_SHL: result = a << b[5:0]; // Shift by max 63
            ALU_SHR: result = a >> b[5:0];
            default: result = 64'd0;
        endcase
    end

    assign zero_flag = (result == 64'd0);

endmodule
