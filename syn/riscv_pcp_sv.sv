typedef bit [2:0] Type_func3;
typedef bit [6:0] Type_func7;
//Note: all combinations are used, there are no "unsupported" instructions for this co-processor.
parameter Type_func3 MUL    = 3'b000 ;
parameter Type_func3 MULH   = 3'b001 ;
parameter Type_func3 MULHSU = 3'b010 ;
parameter Type_func3 MULHU  = 3'b011 ;
parameter Type_func3 DIV    = 3'b100 ;
parameter Type_func3 DIVU   = 3'b101 ;
parameter Type_func3 REM    = 3'b110 ;
parameter Type_func3 REMU   = 3'b111 ;
parameter Type_func7 MULDIV = 7'b0000001;
parameter Type_func7 CUSTOM_Istr = 7'b0000000;
parameter Type_func3 eplrr0   = 3'b000 ;
parameter Type_func3 eplrr1   = 3'b001 ;
parameter Type_func3 eplrr2   = 3'b010 ;
/*
funct7  rs1	  rs2   func3 	rd 		opcode 
0000000 00001 01000 000	   	00111	0001011		eplrr0 	t2,s0,ra
0000000 00001 01000 001		00111	0001011 	eplrr1	t2,s0,ra
0000000 00001 01000 010     00111   0001011 	eplrr2	t2,s0,ra
*/
function unsigned [2:0] func3(unsigned [31:0]ir);
	return ir[14:12];
endfunction
function unsigned [2:0] func7(unsigned [31:0]ir);
	return ir[31:25]; 
endfunction

module riscv_pcp_sv(input logic clk, input logic resetn, PCP.Slave pcpi);

	//Internal signals
	logic [63:0] mul_result;
	logic [31:0] div_result_Z, div_result_R;
	logic		 div_start, div_finished;
	logic      	 div_unsigned; //bit that differentiates DIVU & REMU from DIV & REM
	logic [31:0] A_div, B_div;
	logic		 calc_finished;
	logic [1:0]  mul_type; //bits that differentiate between MUL,MULH,MULHSU,MULHU
	logic		 instr_valid;
	logic		 is_custom_instr;
	enum logic [1:0] { IDLE = 0, BUSY = 1, FINISHED = 2, RS1_SUB_RS2 = 3} state;
	logic [31:0] add_out;
	logic [31:0] sub_out;
	logic 		 is_MUL_REM;
	logic 		 is_rs2_BT_rs1;

	
	assign is_custom_instr = func7(pcpi.instruction) == CUSTOM_Istr;
	assign is_MUL_REM = func3(pcpi.instruction) == eplrr0;
	assign is_ADD_REM = func3(pcpi.instruction) == eplrr1;
	assign is_SUB_REM = func3(pcpi.instruction) == eplrr2;
	assign is_rs2_BT_rs1 = sub_out[31];
	assign mul_type = is_custom_instr? 2'b01 : pcpi.instruction[13:12];	//Custom instruction -> unsigned MUL
	assign div_unsigned = pcpi.instruction[12] & !is_custom_instr;		//When it's a custom instruction, we do signed REM
	//Adder, Multiplier, and Divider instances
	mul mul1(clk, resetn, pcpi.rs1, pcpi.rs2, mul_type,	mul_result);
	//
	// assign add_out = pcpi.rs1 + pcpi.rs2;
	// assign sub_out = pcpi.rs1 >= pcpi.rs2 ? pcpi.rs1 - pcpi.rs2 : pcpi.rs1 - pcpi.rs2 + 32'd12289  ;
	always_ff @(posedge clk)
	begin
		add_out <= (~is_ADD_REM)? (sub_out + 32'd12289) : (pcpi.rs1 + pcpi.rs2);
		//sub_out <= (pcpi.rs1 >= pcpi.rs2) ? (pcpi.rs1 - pcpi.rs2) : (pcpi.rs1 - pcpi.rs2 + 32'd12289)  ;
		sub_out <= pcpi.rs1 - pcpi.rs2;
	end
	//assign A_div = is_custom_instr? ( is_MUL_REM? mul_result[31:0] : ( is_ADD_REM|is_rs2_BT_rs1 ? add_out : sub_out) ) : pcpi.rs1;	//Input to divider from MUL, ADD, SUB, or Normal.
	always_comb
	begin
		if(is_custom_instr)
		begin
			case(func3(pcpi.instruction))
				eplrr0 : A_div = mul_result[31:0];
				eplrr1 : A_div = add_out;
				eplrr2 : 
					if(is_rs2_BT_rs1)
						A_div = add_out;
					else
						A_div = sub_out;
				default: A_div = pcpi.rs1;
			endcase
		end
		else
			A_div = pcpi.rs1;
	end
	//assign A_div = is_custom_instr? ( is_MUL_REM? mul_result[31:0] :  add_out) : pcpi.rs1;	//Input to divider from MUL, ADD, SUB, or Normal.
	//
	assign B_div = is_custom_instr? 32'd12289 : pcpi.rs2;
	assign div_start = is_custom_instr? state==BUSY : pcpi.valid & pcpi.instruction[14] & (pcpi.ready != 1); //Start division when we get a new command and func3[2]==1	
																											 //Or wait for multiplier (1 cycle = go to busy state) to do custom instruction
	div div1(resetn, clk, A_div, B_div, div_start, div_unsigned, div_result_Z, div_result_R, div_finished);

	
	//
	assign calc_finished = div_finished | (!pcpi.instruction[14] & func7(pcpi.instruction) == MULDIV); 	//Either wait for divison (custom instruction also), OR do 1 cycle multplication 
	assign instr_valid = pcpi.valid  & (func7(pcpi.instruction) == MULDIV | is_custom_instr);

	//State machine
	always_ff@(posedge clk or negedge resetn) begin
		if(!resetn)
		   state <= IDLE;
		else
		   case(state)
			IDLE: 
				if(instr_valid)		//NOTE: add condition to check for illegal instruction
					if (is_SUB_REM)
						state <= RS1_SUB_RS2;
					else
						state <= BUSY;
				else
					state <= IDLE;
			RS1_SUB_RS2:
					state <= BUSY;
			BUSY: 
				if(calc_finished)
					state <= FINISHED;
				else
					state <= BUSY;
			FINISHED: 
				if(pcpi.valid)
					state <= FINISHED;	//Stay here until valid goead LOW to avoid a false new command
				else
					state <= IDLE;
			default : state <= IDLE;
		   endcase
  	end

	//Process that returns the result based on func3 -- assumes 1 cycle calculation of result
	logic [31:0] result;

	always_ff@(posedge clk or negedge resetn) begin
		if(!resetn)
		begin
			pcpi.wr 	<= 0;
			pcpi.rd 	<= 0; 	
			pcpi.busy 	<= 0;
			pcpi.ready 	<= 0;
		end
		else
		   case(state)
			IDLE: 
				if(instr_valid)		//NOTE: add condition to check for illegal instruction
				begin
					pcpi.wr 	<= 0;
					pcpi.rd 	<= pcpi.rd; 	
					pcpi.busy 	<= 1;
					pcpi.ready 	<= 0;
				end
				else
				begin
					pcpi.wr 	<= 0;
					pcpi.rd 	<= pcpi.rd; 	
					pcpi.busy 	<= 0;
					pcpi.ready 	<= 0;
				end
			BUSY: 
				if(calc_finished)
				begin
					pcpi.wr 	<= 1;
					pcpi.rd 	<= result; 	
					pcpi.busy 	<= 0;
					pcpi.ready 	<= 1;
				end
				else
				begin 
					pcpi.wr 	<= 0;
					pcpi.rd 	<= pcpi.rd; 	
					pcpi.busy 	<= 1;
					pcpi.ready 	<= 0;
				end

				
		   endcase
  	end

	always_comb 
	begin
		if(is_custom_instr)
			result = div_result_R;
		else
		begin
			case(func3(pcpi.instruction) )
				MUL 	:	result = mul_result[31:0];
				MULH   	:	result = mul_result[63:32];
				MULHSU 	:	result = mul_result[63:32];
				MULHU  	:	result = mul_result[63:32];
				DIV    	:	result = div_result_Z;
				DIVU   	:	result = div_result_Z;
				REM    	:	result = div_result_R;
				REMU	:	result = div_result_R;
			endcase
		end
	end

endmodule