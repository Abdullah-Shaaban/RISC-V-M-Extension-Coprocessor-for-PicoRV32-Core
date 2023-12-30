# Implementation of the RISC-V M Extension as a Coprocessor for the PicoRV32 RISC-V Core 
## Project Overview
This Coprocessor implements RISC-V M-Extension. It interfaces with the PicorRV32 core using its Pico Co-Processor Interface (PCPI).  
There is also a branch that contains custom instructions optimized for C-code of Number-Theoretic Transform algorithm. These custom instructions are:
+ Multiply-Remainder
+ Add-Remainder
+ Subtract-Remainder

## The Modules
### The multiplier
The mul module is designed for performing signed multiplication on 33-bit inputs. It allows differentiation between various instructions by preprocessing the inputs based on the specified operation mode. If the inputs are signed, the module performs sign-extension from 32-bit to 33-bit. If the inputs are unsigned, zero-extension is performed.

### The divider
There are two versions:
+ div: implements the restoring algorithm
+ div_non_rest: implements the non-restoring algorithm
The div_non_rest module is designed to perform division using the non-restoring serial division algorithm. The module supports both signed and unsigned division by "pre-processing" the inputs and "post-processing" the outputs accordingly. The division process assumes unsigned numbers, but it handles signed division by adjusting the signs of inputs and results.
It is advised to use div_non_rest because it is more updated. However, both modules work in a similar fashion.

### The divider's model
A C++ implementation fot the non-restoring division algorithm that was used for initial development of the divider. It can also be used for verification as a reference model.

### The testbenches
+ The divider's testbench:
It does both Random Test Scenarios (in a loop) and Special Cases (such as zero divisor and overflow conditions). The number of random cases can be changed using a parameter.
+ The co-processor's testbench:
It tests each instruction of the M extension (specific values without randomization) and the special cases.

## Directory Structure
+ /syn: contains the synthesizable RTL modules
    + riscv_pcp_sv.sv: the co-processor module.
    + mul.sv: multiplier.
    + div.sv: restoring divider.
    + div_non_rest.sv: non-restoring divider.
+ /sim: contains testbenches
    + co_proc_tb.sv: selfcheking testbench to test the whole co-processor
    + div_non_rest_tb.sv: selfcheking testbench for the divider
+ /cpp: contains C++ models
    + non_rest_div.cpp: C++ model for the non-restoring divider
