#1.set filename
source -echo -verbose fm_filename.tcl
#2.Synopsys Auto Setup Mode
set_app_var synopsys_auto_setup true
#3.read in the svf file
set_svf $SVF_FILE
#4.read reference design
read_verilog -r $RTL_SOURCE_FILES -work_library WORK
set_top r:/WORK/$DESIGN_NAME
#5.read implementation design
read_db -i $TECH_LIB
read_verilog -i $NETLIST_FILE -work_library WORK
set_top -auto
#6.match compare points and report unmatch points
match
report_unmatched_points > ${REPORT_DIR}/${FMRM_UNMATCHED_POINTS_REPORT}
#7.verify and report
if {![verify]} {
    save_session -replace ${REPORT_DIR}/${FMRM_FAILING_SESSION_NAME}
    report_failing_points > ${REPORT_DIR}/${FMRM_FAILING_POINTS_REPORT}
    report_aborted > ${REPORT_DIR}/${FMRM_ABORTED_POINTS_REPORT}
    analyze_points -all > ${REPORT_DIR}/${FMRM_ANALYZE_POINTS_REPORT}
}