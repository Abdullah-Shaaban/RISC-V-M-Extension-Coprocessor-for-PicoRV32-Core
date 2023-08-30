//  Module: div
//
module div
    #(
        parameter WIDTH = 32
    )(
        input   logic resetn,   //CPU_RESET
        input   logic clk,      
        input   logic [WIDTH-1:0] A, 
        input   logic [WIDTH-1:0] B,
        input   logic start, //start = pcpi.valid & pcpi.instruction[14]
        input   logic unsigned_div, //signed_div = pcpi.instruction[12]
        output  logic [WIDTH-1:0] Z,
        output  logic [WIDTH-1:0] R,
        output  logic div_finished
    );

    //Intermediate signals
    logic [WIDTH-1:0] A_in;
    logic [WIDTH-1:0] B_in;

    logic [2*WIDTH-1:0] R_sub_B; 
    logic [2*WIDTH-1:0] R_next; 
    logic [2*WIDTH-1:0] B_next;
    logic [WIDTH-1:0] Z_shift;
    logic [WIDTH-1:0] Z_next;

    //Data registers
    logic [2*WIDTH-1:0] R_reg;
    logic [2*WIDTH-1:0] B_reg;
    logic [WIDTH-1:0] Z_reg; 

    
    //Handling Inputs & Outputs according to signed/unsigend operations
    always_comb begin
        if (unsigned_div | B == 0) begin
            A_in = A;
            B_in = B;
            Z = Z_reg;
            R = R_reg[WIDTH-1:0];   
        end
        else begin
            A_in = A[WIDTH-1] ? -A : A;
            B_in = B[WIDTH-1] ? -B : B;
            Z = (A[WIDTH-1] ^ B[WIDTH-1]) ? -Z_reg : Z_reg;
            R = A[WIDTH-1] ? -R_reg[WIDTH-1:0] : R_reg[WIDTH-1:0];
        end
    end
    //Internal combinational data path
    always_comb
    begin
        B_next = B_reg>>1; 
        Z_shift = Z_reg<<1; 
        R_sub_B = R_reg - B_reg; 
        if(R_reg>=B_reg) 
        begin
            R_next = R_sub_B; 
            Z_next = Z_shift | 1; 
        end
        else 
        begin
            R_next = R_reg;
            Z_next = Z_shift;
        end
    end

    //Counter
    logic [4:0] count;
    logic count_en;
    enum bit [1:0] {IDLE, LOOP, FINISH} state;
    
    assign count_en = state==LOOP;

    always_ff @(posedge clk or negedge resetn)
    begin
        if(!resetn)
		   count <= 0;
		//else if (start)
        //    count<=0;
        else if(count_en)
            count <= count + 1;
        else if(state==FINISH)
            count <= 0;    
            /*
        else
            count <= count;
            */
    end

    logic calc_NOT_finished;
    logic [31:0] A_minus_B;
    assign A_minus_B = A_in - B_in;
    assign calc_NOT_finished = count != 31 & !(A_minus_B[31])  & B!=0;
    //FSM
	always_ff@(posedge clk or negedge resetn) begin
		if(!resetn)
		   state <= IDLE;
		else
		   case(state)
			IDLE: 
				if(start)
					state <= LOOP;
				else
					state <= IDLE;
			LOOP: 
                if(calc_NOT_finished)
                    state <= LOOP;
                else
                begin
                    state <= FINISH;
                end 
            FINISH: 
                if(start==1)
                    state <= FINISH; 
                else
                    state <= IDLE;
			default : state <= IDLE;
		   endcase
  	end
    
    //FSM outputs
    always_ff @(posedge clk, negedge resetn) 
    begin
        if (!resetn)
        begin
            R_reg <= 0;
            B_reg <= 0;
            Z_reg <= 0; 
            div_finished <= 0;
        end
        else begin
            case(state)
                IDLE:
                begin
                    div_finished <= 0;
                    if (start & !div_finished)  //To avoid doing the same instruction twice and missing with the outputs in R_reg and Z_reg 
                    begin
                        R_reg <= {{(WIDTH){1'b0}}, A_in};
                        B_reg <= {1'b0, B_in ,{(WIDTH-1){1'b0}}};
                        Z_reg <= 0;
                    end
                end
                LOOP:
                begin
                    if (count_en)
                    begin
                        if (B == 0)
                        begin
                        R_reg <= A;
                        Z_reg <= {(WIDTH){1'b1}} ;
                        div_finished <= 1;        
                        end
                        else if (A_minus_B[31]) begin
                            R_reg <= A_in;
                            Z_reg <= 32'b0;
                            B_reg <= B_reg;
                            div_finished <= 1;
                        end
                        else begin
                            R_reg <= R_next;
                            B_reg <= B_next;
                            Z_reg <= Z_next;
                            div_finished <= 0;
                        end
                    end
                    else
                        div_finished <= 1;
                end
                FINISH:
                begin
                    div_finished <= 1;
                end
            endcase
        end
    end




    // //Overflow
    // assign overflow = B == 0; // division by 0 would better be handled in riscv_pcp_sv

endmodule: div
