

module riscv_pcp_sv(input logic clk, input logic resetn, PCP.Slave pcpi);

	//Internal signals
	logic [2*XLEN-1:0] mul_result;
	logic [XLEN-1:0] div_result_Z, div_result_R;
	logic		 div_start, div_finished;
	logic      	 div_unsigned; //bit that differentiates DIVU & REMU from DIV & REM
	logic [XLEN-1:0] A_div, B_div;
	logic		 calc_finished;
	logic		 instr_valid;
	logic		 is_custom_instr;
	enum logic [1:0] { IDLE = 0, BUSY = 1, FINISHED = 2, RS1_SUB_RS2 = 3} state;
	logic [XLEN-1:0] add_out;
	logic [XLEN-1:0] sub_out;
	logic 		 is_MUL_REM;
	logic 		 is_rs2_BT_rs1;

	
	assign is_custom_instr = get_func7(pcpi.instruction) == CUSTOM_Istr;
	assign is_MUL_REM = get_func3(pcpi.instruction) == eplrr0;
	assign is_ADD_REM = get_func3(pcpi.instruction) == eplrr1;
	assign is_SUB_REM = get_func3(pcpi.instruction) == eplrr2;
	assign is_rs2_BT_rs1 = sub_out[31];
	
	//Adder, Multiplier, and Divider instances
	op_sign_t operands_sign;
	mul mul1(clk, resetn, pcpi.rs1, pcpi.rs2, operands_sign,	mul_result);
	
	always_ff @(posedge clk)
	begin
		add_out <= (~is_ADD_REM)? (sub_out + 32'd12289) : (pcpi.rs1 + pcpi.rs2);
		sub_out <= pcpi.rs1 - pcpi.rs2;
	end

	always_comb
	begin
		if(is_custom_instr)
		begin
			case(get_func3(pcpi.instruction))
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

	assign B_div = is_custom_instr? 32'd12289 : pcpi.rs2;
	assign div_start = is_custom_instr? state==BUSY : pcpi.valid & pcpi.instruction[14] & (pcpi.ready != 1); //Start division when we get a new command and get_func3[2]==1	
																											 //Or wait for multiplier (1 cycle = go to busy state) to do custom instruction
	div div1(resetn, clk, A_div, B_div, div_start, div_unsigned, div_result_Z, div_result_R, div_finished);

	
	// Either wait for divison (custom instruction also), OR do 1 cycle multplication
	assign calc_finished = div_finished | (!pcpi.instruction[14] & get_func7(pcpi.instruction) == MULDIV); 
	assign instr_valid = pcpi.valid  & (get_func7(pcpi.instruction) == MULDIV | is_custom_instr);

	//State machine
	always_ff@(posedge clk or negedge resetn) begin
		if(!resetn)
		   state <= IDLE;
		else
		   case(state)
			IDLE: 
				// TODO: add condition to check for illegal instruction
				if(instr_valid)
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

	//Process that returns the result based on get_func3 -- assumes 1 cycle calculation of result
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
		operands_sign = RS1_RS2_UNSIGNED;
		// TODO: 2 levels of MUXing for the result is not really needed.
		if(is_custom_instr)
			result = div_result_R;
			if(get_func3(pcpi.instruction)==eplrr2)
				// When we do u-r%q, make operands of DIV signed
				operands_sign = RS1_RS2_SIGNED;
		else
		begin
			unique case(get_func3(pcpi.instruction))
				MUL:
					result = mul_result[31:0];
				MULH: begin
					operands_sign = RS1_RS2_SIGNED;
					result = mul_result[63:32];
				end
				MULHSU: begin
					operands_sign = RS1_SIGNED;
					result = mul_result[63:32];
				MULHU:
					result = mul_result[63:32];
				DIV: begin
					operands_sign = RS1_RS2_SIGNED;
					result = div_result_Z;
				DIVU:
					result = div_result_Z;
				REM: begin
					operands_sign = RS1_RS2_SIGNED;
					result = div_result_R;
				end
				REMU:
					result = div_result_R;
			endcase
		end
	end

endmodule