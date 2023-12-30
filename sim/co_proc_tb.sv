module riscv_pcp_sv_tb import m_ext_pkg::*; ();

	//DUT instance
    logic clk;
    logic resetn;
    //To be driven any time, but assigned to interface at neg edge
    logic valid;
	logic [31:0] instruction;
	logic [31:0] rs1;
	logic [31:0] rs2;
	
    PCP intf();
    riscv_pcp_sv DUT(clk, resetn, intf.Slave);
    

    //Clock
    parameter clk_tick=10;
    always 
    begin
        clk = 1'b1; #(clk_tick/2); 
        clk = 1'b0; #(clk_tick/2); 
    end

    //Stimulus
    always@(negedge clk)
    begin
        intf.valid <= valid;
	    intf.instruction <= instruction;
	    intf.rs1 <= rs1; 
	    intf.rs2 <= rs2;
    end

    initial
    begin
        resetn =0;
        valid =0;
	    instruction = 0;
	    rs1 = 0; 
	    rs2 = 0;
        repeat (10) #clk_tick;
        resetn =1;
        repeat (10) #clk_tick;

        //------MUL------:
        rs1 = 32'h0000_0015;
	    rs2 = 32'h0000_0788;
        valid =1;
	    instruction = 32'b0000001_00000_00000_000_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //------MULH------:
        rs1 = 32'hFFF0_0015;
	    rs2 = 32'hFAA0_0788;
        valid =1;
	    instruction = 32'b0000001_00000_00000_001_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //------MULHSU------:
        rs1 = 32'hFFF0_0015;
	    rs2 = 32'hFAA0_0788;
        valid =1;
	    instruction = 32'b0000001_00000_00000_010_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //------MULHU------:
        rs1 = 32'hFFF0_0015;
	    rs2 = 32'hFAA0_0788;
        valid =1;
	    instruction = 32'b0000001_00000_00000_011_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //------REM by Zero------:
        rs1 = 32'h0000_0015;
	    rs2 = 32'h0000_0000;
        valid =1;
	    instruction = 32'b0000001_00000_00000_110_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //------DIV by Zero------:
        rs1 = 32'h9502_F900;
	    rs2 = 32'h0000_0000;
        valid =1;
	    instruction = 32'b0000001_00000_00000_100_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;      
        
        //DIV OVERFLOW
        rs1 = -2147483648;
	    rs2 = -1;
        valid =1;
	    instruction = 32'b0000001_00000_00000_100_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //REM OVERFLOW
        rs1 = -2147483648;
	    rs2 = -1;
        valid =1;
	    instruction = 32'b0000001_00000_00000_110_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //------REMU  by Zero------:
        rs1 = 32'h0000_0015;
	    rs2 = 32'h0000_0000;
        valid =1;
	    instruction = 32'b0000001_00000_00000_111_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //------DIVU by Zero------:
        rs1 = 32'h9502_F900;
	    rs2 = 32'h0000_0000;
        valid =1;
	    instruction = 32'b0000001_00000_00000_101_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;        
        
        //DIVU OVERFLOW
        rs1 = -2147483648;
	    rs2 = -1;
        valid =1;
	    instruction = 32'b0000001_00000_00000_101_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        //REMU OVERFLOW
        rs1 = -2147483648;
	    rs2 = -1;
        valid =1;
	    instruction = 32'b0000001_00000_00000_111_00000_0110011;
        @(posedge intf.ready) #clk_tick;
        valid = 0;
        repeat (10) #clk_tick;

        repeat (100) #clk_tick; 
        $stop;
    end


    logic [31:0] result=0;
    logic [65:0] tmp=0;
    always_ff @(posedge intf.busy) begin: co_proc_Model
        case(get_func3(intf.instruction))
			MUL 	:
			begin
				tmp = (signed'(rs1) * signed'(rs2));
				result = tmp[31:0];
			end	
			MULH   	:
			begin
                tmp = (signed'(rs1) * signed'(rs2)) ;
                result = tmp[63:32];
			end	
			MULHSU 	:	
			begin
                tmp = (signed'({rs1[31],rs1}) * signed'({1'b0,rs2}));
                result = tmp[63:32];
			end	
			MULHU  	:	
			begin
				tmp = (rs1*rs2);
                result = tmp[63:32];
			end
			DIV    	:
			begin
                if (rs2 == 0)
                begin
                result <= 32'hFFFF_FFFF ;
                end
                else
                begin
				result <= signed'(rs1)/signed'(rs2);
                end
			end
			DIVU   	:	
			begin
                if (rs2 == 0)
                begin
                result <= 32'hFFFF_FFFF ;
                end
                else
                begin
				result <= rs1/rs2;
                end
			end
			REM    	:
			begin
                if (rs2 == 0)
                begin
                result <= signed'(rs1);
                end
                else
                begin
				result <= signed'(rs1) % signed'(rs2);
                end
			end
			REMU	:	
			begin
                if (rs2 == 0)
                begin
                result <= rs1;
                end
                else
                begin
				result <= rs1 % rs2;
                end
			end
		endcase
    end: co_proc_Model
    //self check
    always @(posedge intf.ready) begin
        if(resetn)
        begin    
            $display("********************************\n\tTIME=%d",$time);
            $display("Instruction: %b", get_func3(instruction) );
            $display("rs1: %h", rs1);
            $display("rs2: %h", rs2);
            if(result==intf.rd)
                $display("Status: PASS ----- intf.rd: %h, tb_result: %h", intf.rd, result);
            else
                $display("Status: FAIL :( ----- intf.rd: %h, tb_result: %h", intf.rd, result);
        end
    end

endmodule

