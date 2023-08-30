
gui?=0

ifeq ($(gui),1)
	sim_mode=
	do="do wave.do; run -all"
else
	sim_mode=-c
	do="run -all"
endif

all: VLOG VSIM

VLOG: 
	rm -r work
	vlib ./work
	vlog -sv ../if/PCPInterface.sv div.sv mul.sv co_proc_tb.sv 

VSIM: 
	vsim $(sim_mode) -t ps -voptargs="+acc" riscv_pcp_sv_tb -do $(do) 
