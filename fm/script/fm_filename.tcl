#1.set reference related
#1.1 set design name  
set DESIGN_NAME "core"
#1.2 set rtl position
set RTL_FILE_DIR "../../syn/rtl/core"
set RTL_SOURCE_FILES [glob $RTL_FILE_DIR/*.v]

#2. set implementation related
#2.1 set syn position
set SYN_FILE_DIR "../../syn/"
#2.2 set lib,svf.netlist position
set TECH_LIB "../../syn/lib/smic18_ff.db"
set SVF_FILE "../../syn/result/core.mapped.svf"
set NETLIST_FILE "../../syn/netlist/core.v"

#3. set reports related
set REPORT_DIR "../reports/"
set FMRM_UNMATCHED_POINTS_REPORT ${DESIGN_NAME}.fmv_unmatched_points.rpt
set FMRM_FAILING_SESSION_NAME    ${DESIGN_NAME}
set FMRM_FAILING_POINTS_REPORT   ${DESIGN_NAME}.fmv_failing_points.rpt
set FMRM_ABORTED_POINTS_REPORT   ${DESIGN_NAME}.fmv_aborted_points.rpt
set FMRM_ANALYZE_POINTS_REPORT   ${DESIGN_NAME}.fmv_analyze_points.rpt