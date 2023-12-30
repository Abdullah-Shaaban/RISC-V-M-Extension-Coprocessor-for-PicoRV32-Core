
/* Package: m_ext_pkg
- A SV package for types and definitions required for the RISC-V M extension
- The 3 custom instructions are:
    funct7  rs1	  rs2   func3 	rd 		opcode 
    0000000 00001 01000 000	   	00111	0001011		eplrr0 	t2,s0,ra
    0000000 00001 01000 001		00111	0001011 	eplrr1	t2,s0,ra
    0000000 00001 01000 010     00111   0001011 	eplrr2	t2,s0,ra
*/
package m_ext_pkg;
    //Typedefs
    typedef enum bit [2:0] func3_t  {
                                    MUL    = 3'b000,
                                    MULH   = 3'b001,
                                    MULHSU = 3'b010,
                                    MULHU  = 3'b011,
                                    DIV    = 3'b100,
                                    DIVU   = 3'b101,
                                    REM    = 3'b110,
                                    REMU   = 3'b111,
                                    eplrr0 = 3'b000,
                                    eplrr1 = 3'b001,
                                    eplrr2 = 3'b010
                                    };
    typedef enum bit [6:0] func7_t  {
                                    MULDIV = 7'b0000001;
                                    CUSTOM_Istr = 7'b0000000;
                                    };
    typedef enum bit [1:0] custom_inst_t{
                                    eplrr0 = 3'b000,
                                    eplrr1 = 3'b001,
                                    eplrr2 = 3'b010
                                    };
    // Indicates whether the operands are signed or not 
    typedef enum bit [1:0] op_sign_t{
                                    RS1_RS2_UNSIGNED    = 2'b00,
                                    RS1_SIGNED          = 2'b10,
                                    RS1_RS2_SIGNED      = 2'b11
                                    };

    // Functions
    function func3_t get_func3(unsigned [31:0]ir);
        return ir[14:12];
    endfunction
    function func7_t get_func7(unsigned [31:0]ir);
        return ir[31:25]; 
    endfunction

    //Parameters
    parameter XLEN = 32;

    
endpackage: m_ext_pkg
