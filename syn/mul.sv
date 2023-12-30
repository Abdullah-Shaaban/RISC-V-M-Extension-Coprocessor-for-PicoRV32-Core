/******************
- The multiplier always performs signed multiplication of 33-bit inputs.
- It differentiates between the different instructions by "pre-processing the inputs".
- If input is signed, we do sign-extension from 32-bit to 33-bit. Otherwise, we extend using a 0.
*******************/

module mul
    import m_ext_pkg::*;
    #(
        parameter WIDTH = 32
    )(
        input  logic clk,
        input  logic [WIDTH-1:0] rs1, 
        input  logic [WIDTH-1:0] rs2,
        input  op_sign_t operands_sign,
        output logic [2*WIDTH-1:0] res
    );
    // Multiplier Inputs
    logic [WIDTH:0] in1, in2;
    // Result Register
    logic [2*WIDTH : 0] res_reg;

    // Pre-processing the inputs
    always_comb begin
        // By default, assume both inputs are unsigned
        in1 = {1'b0, rs1};
        in2 = {1'b0, rs2};
        unique case (operands_sign)
            RS1_RS2_SIGNED: begin
                in1 = {rs1[WIDTH-1], rs1};
                in2 = {rs1[WIDTH-1], rs2};
            end
            RS1_SIGNED: begin
                in1 = {rs1[WIDTH-1], rs1};
            end
        endcase
    end

    // Do signed multplication, with a register before the output
    always_ff @(posedge clk)
        res_reg <= signed'(in2) * signed'(in1);
    assign res = res_reg;

endmodule: mul