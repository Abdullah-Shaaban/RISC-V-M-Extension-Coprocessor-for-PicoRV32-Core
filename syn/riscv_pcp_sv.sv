
module riscv_pcp_sv(input logic clk, input logic resetn, PCP.Slave pcpi);
	import m_ext_pkg::*;
	
		//Internal signals
		logic instr_valid;
		logic [XLEN:0] result;
	
		
		// Multiplier instance
		op_sign_t operands_sign;
		logic [2*XLEN-1:0] mul_result;
		mul #(
			.WIDTH(XLEN) 
		) mul_u (
			.clk			(clk), 
			.rs1			(pcpi.rs1), 
			.rs2			(pcpi.rs2), 
			.operands_sign	(operands_sign),
			.res			(mul_result) 
		);
	
		// Divider instance
		logic [XLEN-1:0] div_result_Q, div_result_R;
		logic div_start, div_done, div_flag;
		// A flag to indicate whether the instruction invloves the divider (bit 14 indicates a divison/remainder when HIGH)
		assign div_flag = pcpi.instruction[14];
		// Start the division only if this is a div/rem instruction
		assign div_start = (state==BUSY) & (div_flag);
		div_non_rest #(
			.WIDTH(XLEN) 
		) div_u (
			.resetn			(resetn),
			.clk			(clk), 
			.a				(pcpi.rs1), 
			.b				(pcpi.rs2), 
			.start			(div_start), 
			.unsigned_div	(operands_sign[0]), 
			.q				(div_result_Q), 
			.r				(div_result_R), 
			.done			(div_done) 
		);
		
		// We have a valid instruction when the interface asserts 'valid' and if the instruction belongs to the M extension 
		assign instr_valid = pcpi.valid & get_func7(pcpi.instruction) == MULDIV;
	
		//State machine
		enum logic [1:0] { IDLE = 0, BUSY = 1, FINISHED = 2, RS1_SUB_RS2 = 3} state;
		always_ff@(posedge clk or negedge resetn) begin
			if(!resetn)
			   state <= IDLE;
			else
				case(state)
					IDLE: 
						if(instr_valid)
							state <= BUSY;
					BUSY: 
						// Either wait for divison OR do 1 cycle multplication
						if(div_done | ~div_flag)
							state <= FINISHED;
					FINISHED: 
						//Stay here until valid goes LOW to avoid a false new command
						if(~pcpi.valid)
							state <= IDLE;
					default : 
						state <= IDLE;
				endcase
		  end
	
		always_comb 
		begin
			// Determine if the operation is signed based on the instruction
			unique case (get_func3(pcpi.instruction))
				MUL, MULH, DIV, REM:
					operands_sign = RS1_RS2_SIGNED;
				MULHSU:
					operands_sign = RS1_SIGNED;
				default:
					operands_sign = RS1_RS2_UNSIGNED;
			endcase
	
			// Choose the result based on the instruction
			unique case(get_func3(pcpi.instruction))
				MUL:
					result = mul_result[31:0];
				MULH, MULHU, MULHSU:
					result = mul_result[63:32];
				DIV, DIVU:
					result = div_result_Q;
				REM, REMU:
					result = div_result_R;
			endcase
	
			// Interface outputs
			pcpi.wr 	= (state==FINISHED);
			pcpi.ready 	= (state==FINISHED);
			pcpi.rd 	= result;
			pcpi.busy 	= (state==BUSY);
		end
	
	endmodule