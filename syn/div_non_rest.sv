/***************Non-restoring 2's complement divider***************
The divider uses the non-restoring serial division algorithm.
The division process here assumes unsigned numbers, but when
signed division is needed, the inputs are "pre-processed" and 
the outputs are "post-processed" to change the signs such that
the output is correct.
Steps:
1a. Check for special cases of the ISA
    - Check whether the divisor is 0.
    - Check overflow: Dividend=-2^(WIDTH-1) and Divisor=-1
1b. At the same time, pre-process the inputs based on their signs.
    - Initialize the registers.
    - Initialize the sign of "partial remainder" to 0
2a. If a special case is true, produce the output immediately and signal that we're done.
2b. If no special cases, then we start the the division loop.
    - Shift the register pair (remainder,quotient) one bit left.
    - If sign of "partial remainder" is negative -> add the divisor
    - If sign of "partial remainder" is positive -> subtract the divisor
    - Get the new sign of "partial remainder"
    - Loop back N times
3. Final restoring step: If sign of "partial remainder" is negative -> add the divisor.
4. Post-process the results
    - If signs of the dividend and divisor do not match -> perform 2's complement on the Quotient
    - According to the sign of the dividend -> perform 2's complement on the Remainder to match.
*/
module div_non_rest
    #(
        parameter WIDTH = 32
    )(
        input   logic resetn,
        input   logic clk,
        input   logic unsigned_div,
        input   logic start,
        // Dividend
        input   logic [WIDTH-1:0] a, 
        // Divisor
        input   logic [WIDTH-1:0] b,
        // Quotient
        output  logic [WIDTH-1:0] q,
        // Remainder
        output  logic [WIDTH-1:0] r,
        // Signal finishing
        output  logic done
    );
    
    // State Machine and Counter
    logic [$clog2(WIDTH)-1 : 0] count;
    logic count_en;
    // FSM states and their mapping to the algorithm
        // Step 0 -> IDLE (load inputs)
        // Step 1 -> PRE_PROCESS
        // Step 2 -> LOOP (or DONE)
        // Step 3 -> FINAL_RESTORE
        // Step 4 -> POST_PROCESS
        // Step 5 -> DONE (wait there for ack)
    enum bit [2:0] {IDLE, PRE_PROCESS, LOOP, FINAL_RESTORE, POST_PROCESS, DONE} state, nxt_state;
    always_ff @(posedge clk or negedge resetn)
    begin
        if(!resetn) begin
		   count <= 0;
           state <= IDLE;
        end
        else begin
            state <= nxt_state;
            if(count_en)
                count <= count + 1;
            else
                count <= 0;
        end    
    end

    // Next State Logic
    assign count_en = (state==LOOP);
	always_comb begin    
        case(state)
            IDLE: 
                if(start)
                    nxt_state = PRE_PROCESS;
                else
                    nxt_state = IDLE;
            PRE_PROCESS:
                if(zero_divisor | overflow)
                    nxt_state = DONE;
                else
                    nxt_state = LOOP;
            LOOP: 
                if(count==WIDTH-1)
                    nxt_state = FINAL_RESTORE;                    
                else
                    nxt_state = LOOP;
            FINAL_RESTORE:
                // No need for post-processing when doing unsigned division
                if(unsigned_div)
                    nxt_state = DONE;
                else
                    nxt_state = POST_PROCESS;
            POST_PROCESS:
                nxt_state = DONE;
            DONE:
                if(start==1)
                    // Wait here until the output is acknoledged (start goes LOW)
                    nxt_state = DONE; 
                else
                    nxt_state = IDLE;
            default: 
                nxt_state = IDLE;
        endcase
  	end



    /*  r_q_reg: Merged register to hold the Partial Remainders and the Quotient
            It has an extra bit because the Partial Remainders can become "negative".
            Even though we do unsigned arithmetic, the carry-out of the operations
            is stored in that extra bit and used for the control logic to either
            add or subtract the divisor. */
    logic [2*WIDTH : 0] r_q_reg; 
    
    // b_reg: divisor register
    logic [WIDTH-1 : 0] b_reg;

    // Registers to hold the signs of inputs and special-case flags for pre/post-processing
    logic sign_dividend, sign_divisor, zero_divisor, overflow;

    // Signals for the adder
    logic carry_in;
    logic [WIDTH : 0] in1, in2;
    logic [WIDTH : 0] new_partial_rem;
    logic [WIDTH-1 : 0] new_quotient;
    logic [2*WIDTH : 0] r_q_reg_shifted;
    // Signs of current (in r_q_reg) and new (from the adder) partial remainder
    logic sign_partial_rem, sign_new_partial_rem;
    
    /*  NOTE: The step of "Shift the register pair (P,A) one bit left" is done before the addition by just selecting appropriate bits from r_q_reg.
             Therefore, the partial product (P) is 'shifted' before being assigned to the adder's input.
             The new quotient (A, which held the dividend initially) is also shifted and a new quotient bit is inserted.
             Finally, the {new_partial_rem, new_quotient} are just assigned to the register r_q_reg -> this completes 1 iteration of the algorithm.
        NOTE: According to Figure J.3 in H&P book, the r_q_reg should have 2 changes: shifting, and inserting a new quotient bit.
            Therefore, the new partial remainder and new quotient must be shifted on the fly before storing them into the register.
            The figure also shows that the new quotient depends on the sign of the newly calculated partial remainder, whereas
            the act of adding or subtracting the divisor depends on the sign of the partial remainder already in r_q_reg before 
            updating it.
    */
    always_comb begin
        // In the algoritm, checking the sign to add/sub happens before shifting. Here, we do it by reading the bit at '2*WIDTH' instead of '2*WIDTH-1' 
        sign_partial_rem = r_q_reg[2*WIDTH];
        
        // Shift the partial remainder before adding -> select MSB bit of A as LSB of in1, and ignore MSB of P
        r_q_reg_shifted = r_q_reg<<1;
        
        // NOTE: When doing the final, we don't use the shifted version
        // TODO: this adds an extra MUX, it seems unnecessary and the logic can be conveied in a different way
        in1 = state==FINAL_RESTORE? r_q_reg[2*WIDTH : WIDTH] : r_q_reg_shifted[2*WIDTH : WIDTH];
        
        // Add or Subtract the divisor (add 2's complement if sign of partial remainder is positive)
        in2 = sign_partial_rem? {1'b0 , b_reg} : ~{1'b0 , b_reg};
        carry_in = ~sign_partial_rem;
        
        // Adding the partial remainder
        new_partial_rem = unsigned'(in1) + unsigned'(in2) + carry_in;
        
        // Check the sign of the new partial rem -> Set Quotient bit to '1' when the NEW parial remainder is positive
        sign_new_partial_rem = new_partial_rem[WIDTH];
        new_quotient = {r_q_reg_shifted[WIDTH-1 : 1], ~sign_new_partial_rem};
    end

    // Logic for updating the registers, depending on the state
    always_ff @(posedge clk)begin
        case(state)
            IDLE: begin
                // Load A in lower WIDTH bits, others are zero (initial remainder and sign bit)
                r_q_reg <= {1'b0, {WIDTH{1'b0}}, a};
                b_reg <= b;
                sign_dividend <= a[WIDTH-1];
                sign_divisor <= b[WIDTH-1];
                zero_divisor <= (b==0);
                // NOTE: overflow can't happen when doing unsigned division
                overflow <= (signed'(a)==(-2**(WIDTH-1))) & (signed'(b)==-1) & ~unsigned_div;
            end
            PRE_PROCESS: begin
                // Perform 2's complement if necessary, when doing signed division
                if(sign_dividend & ~unsigned_div)
                    r_q_reg[WIDTH-1 : 0] <= -r_q_reg[WIDTH-1 : 0];
                if(sign_divisor & ~unsigned_div)
                    b_reg <= -b_reg;
            end
            LOOP: begin
                // Assemble the new partial remainder and quotient.
                r_q_reg <= {new_partial_rem, new_quotient};
            end
            FINAL_RESTORE: begin
                if(sign_partial_rem)
                    r_q_reg[2*WIDTH : WIDTH] <= new_partial_rem;
            end
            POST_PROCESS: begin
                // - If signs of the dividend and divisor do not match -> perform 2's complement on the Quotient
                if(sign_dividend!=sign_divisor)
                    r_q_reg[WIDTH-1 : 0] <= -r_q_reg[WIDTH-1 : 0];
                // - According to the sign of the dividend -> perform 2's complement on the Remainder to match.
                if(sign_dividend)
                    r_q_reg[2*WIDTH-1 : WIDTH] <= -r_q_reg[2*WIDTH-1 : WIDTH];
            end
        endcase
    end

    
    
    // Outputs
    always_comb begin
        done = (state==DONE);
        q = r_q_reg[WIDTH-1 : 0]; 
        r = r_q_reg[2*WIDTH-1 : WIDTH];
        // Special cases
        if(zero_divisor) begin
            // Remainder is the dividend when divisor is 0
            r = r_q_reg[WIDTH-1 : 0];
            unique if(unsigned_div)
                q = 2**(WIDTH) -1;
            else
                q = -1;
        end
        // NOTE: Can't have zero_divisor and overflow concurrently asserted -> ok to separate the if statement to avoid unnecessary priority 
        if(overflow) begin
            q = -2**(WIDTH-1);
            r = 0;
        end
    end

endmodule