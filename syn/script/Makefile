rpt_path = reports
netlist_file = core.v

syn:
ifeq ($(rpt_path), $(wildcard $(rpt_path)))
	@echo "reports path exsit"
else
	@echo "reports path not exsit"
	mkdir -p $(rpt_path)
endif
	dc_shell-t -f dc.tcl | tee ../log/dc_log

clean:
	rm -rf $(rpt_path)
	rm -rf ./work
	rm -rf alib-52
	rm -rf command.log
	rm -rf default.svf
	rm -rf filenames.log