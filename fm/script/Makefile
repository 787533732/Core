fm_run_log=../log/fm_run_log

fm:
ifeq ($(fm_run_log), $(wildcard $(fm_run_log)))
	@echo "fm_run_log exist"
else 
	@echo "fm_run_log not exist, prepare to create it"
	touch $(fm_run_log)
endif
	fm_shell -f ../script/fm.tcl | tee ../log/fm_run.log

clean:
	rm $(fm_run_log) 
	rm -rf *.log
	ls|grep -v "makefile"|xargs rm -rf