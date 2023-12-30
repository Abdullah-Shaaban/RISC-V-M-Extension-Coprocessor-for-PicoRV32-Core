`timescale 1ns/1ns

module tb_div_non_rest;

  // Parameters
  parameter WIDTH = 32;
  parameter CLK_PERIOD = 10; // Clock period in time units
  parameter NUM_TESTS = 100;  // Number of test scenarios

  // Signals
  logic clk;
  logic resetn;
  logic unsigned_div;
  logic start;
  logic [WIDTH-1:0] a;
  logic sign_a;
  logic [WIDTH-1:0] b;
  logic sign_b;
  logic [WIDTH-1:0] q;
  logic [WIDTH-1:0] r;
  logic done;

  // Instantiate the div_non_rest module
  div_non_rest #(
    .WIDTH(WIDTH)
  ) uut (
    .clk(clk),
    .resetn(resetn),
    .unsigned_div(unsigned_div),
    .start(start),
    .a(a),
    .b(b),
    .q(q),
    .r(r),
    .done(done)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #((CLK_PERIOD)/2) clk = ~clk;
  end

  // Test stimulus
  initial begin
    // Apply reset
    resetn = 0;
    #20; 
    resetn = 1;
    #20; 

    // Loop for multiple random test scenarios
    repeat (NUM_TESTS) begin
      // Randomize or set test inputs for each iteration
      a = $urandom;
      b = $urandom;
      // Set unsigned_div to 1 for unsigned division
      unsigned_div = 1;
      // Display the current test scenario
      $display("Time=%0t: Test Scenario - a=%h, b=%h, unsigned_div=%b", $time, a, b, unsigned_div);
      // Start the division
      #20 start = 1;
      #10 start = 0;
      // Wait for the design to complete
      wait(done == 1);
      // Assertions for self-checking
      assert(q == a / b) else $error("Assertion failed: Quotient mismatch. Q_expected: %0h - Q_observed: %0h", a/b, q);
      assert(r == a % b) else $error("Assertion failed: Remainder mismatch. R_expected: %0h - R_observed: %0h", a%b, r);

      // Set unsigned_div to 0 for signed division
      unsigned_div = 0;
      // Randomly change the sign of A and B
      sign_a = $urandom;
      sign_b = $urandom;
      a[WIDTH-1] = sign_a;
      b[WIDTH-1] = sign_b;
      // Display the current test scenario
      $display("Time=%0t: Test Scenario - a=%h, b=%h, unsigned_div=%b", $time, a, b, unsigned_div);
      // Start the division
      #20 start = 1;
      #10 start = 0;
      // Wait for the design to complete
      wait(done == 1);
      // Assertions for self-checking
      assert(signed'(q) == signed'(a) / signed'(b)) else $error("Assertion failed: Quotient mismatch.  Q_expected: %0h - Q_observed: %0h", signed'(a) / signed'(b) , q);
      assert(signed'(r) == signed'(a) % signed'(b)) else $error("Assertion failed: Remainder mismatch. R_expected: %0h - R_observed: %0h",signed'(a) % signed'(b) , r);
    end

    // Testing special cases
    
    // 1. Zero divisor with unsigned division
    a = $urandom;
    b = 0;
    unsigned_div = 1;    
    #20 start = 1;
    $display("Time=%0t: Test Scenario - a=%h, b=%h, unsigned_div=%b", $time, a, b, unsigned_div);
    #10 start = 0;
    wait(done == 1);
    assert(q == (2**(WIDTH)-1)) else $error("Assertion failed: Quotient mismatch. Q_expected: %0h - Q_observed: %0h", a/b, q);
    
    // 2. Zero divisor with signed division
    a = $urandom;
    b = 0;
    unsigned_div = 0;    
    #20 start = 1;
    $display("Time=%0t: Test Scenario - a=%h, b=%h, unsigned_div=%b", $time, a, b, unsigned_div);
    #10 start = 0;
    wait(done == 1);
    assert(signed'(q) == signed'(-1)) else $error("Assertion failed: Quotient mismatch.  Q_expected: %0h - Q_observed: %0h", signed'(-1), q);
    
    // 3. Overflow with signed division
    a = -2**(WIDTH-1);
    b = -1;
    unsigned_div = 0;    
    $display("Time=%0t: Test Scenario - a=%h, b=%h, unsigned_div=%b", $time, a, b, unsigned_div);
    #20 start = 1;
    #10 start = 0;
    wait(done == 1);
    assert(signed'(q) == signed'(-2**(WIDTH-1))) else $error("Assertion failed: Quotient mismatch.  Q_expected: %0h - Q_observed: %0h", signed'(-2**(WIDTH-1)), q);
    assert(signed'(r) == 0) else $error("Assertion failed: Remainder mismatch. R_expected: %0h - R_observed: %0h", 0 , r);
      
    // End the simulation
    $finish;
  end

endmodule