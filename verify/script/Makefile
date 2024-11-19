all: clean com sim verdi
test: clean com sim

RTL_FILES   := $(shell find $(abspath ../../verify) -name "*.v")

SIM_FILES   := ${RTL_FILES}
SIM_OPTIONS := +v2k -debug_access+all -full64 -timescale=1ns/1ns -fsdb -sverilog  
SIM_INC	 	:= +incdir+"${RUN_DIR}/include"

WAVE_FILES  := ${RTL_FILES}
WAVE_OPTIONS:= -nologo -ssf *.fsdb
WAVE_INC    := +incdir+"${RUN_DIR}/include"

com:
	vcs $(SIM_OPTIONS) $(SIM_FILES) ${SIM_INC} -l com.log
	
sim:
	./simv -l sim.log

verdi:
	verdi $(WAVE_OPTIONS) $(WAVE_INC) $(WAVE_FILES) & 

clean:
	rm -rf *.vpd csrc *.log *.key *.vpd simv* DVE*
	rm -rf verdiLog *.fsdb *.bak *.conf


.PHONY: com sim verdi clean find