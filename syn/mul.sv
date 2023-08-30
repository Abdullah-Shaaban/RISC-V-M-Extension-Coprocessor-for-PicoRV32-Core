//  Module: mul
//
module mul
    #(
        parameter WIDTH = 32
    )(
        input clk,
        input resetn,
        input  logic [WIDTH-1:0] A, 
        input  logic [WIDTH-1:0] B,
        input logic [1:0] mul_type,
        output logic [2*WIDTH-1:0] res
        //output logic finished
    );

    logic           [2*WIDTH-1:0] res_ms;
    logic unsigned  [2*WIDTH-1:0] res_mu;
    logic           [2*WIDTH+1:0] res_msu;

    parameter MUL    = 2'b00 ;
	parameter MULH   = 2'b01 ;
	parameter MULHSU = 2'b10 ;
	parameter MULHU  = 2'b11 ;

    always_comb 
    begin
        res[WIDTH-1:0] = res_ms[WIDTH-1:0];
        case (mul_type)
            MULH:
                res[2*WIDTH-1:WIDTH] = res_ms[2*WIDTH-1:WIDTH];
            MULHSU:
                res[2*WIDTH-1:WIDTH] = res_msu[2*WIDTH-1:WIDTH];
            MULHU:
                res[2*WIDTH-1:WIDTH] = res_mu[2*WIDTH-1:WIDTH];
            default:
                res[2*WIDTH-1:WIDTH] = res_ms[2*WIDTH-1:WIDTH];
        endcase
    end

    always_ff @(posedge clk)
    begin
        if(~resetn)
        begin
            res_ms <= 0;
            res_msu <= 0;
            res_mu <= 0;
        end
        else
        begin
            res_ms <= signed'(A) * signed'(B);
            res_msu <= signed'({A[WIDTH-1],A}) * signed'({1'b0,B});
            res_mu <= unsigned'(A) * unsigned'(B);
        end
    end

endmodule: mul