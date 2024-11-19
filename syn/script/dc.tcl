#0 environment config
#0.1 set search path
set ADDITIONAL_SEARCH_PATH "../lib"
set_app_var search_path ".  ${ADDITIONAL_SEARCH_PATH}  $search_path"
#0.2 read the specified library
set tar_lib "smic18_ff.db"
           # "smic18_ff.db"
read_db $tar_lib
#0.3 show loaded lib
list_libs
#0.4 set library
set_app_var target_library $tar_lib
#set_app_var synthetic_library "dw_foundation.sldb";
set_app_var link_library $tar_lib
#set_app_var link_library "* $tar_lib $synthetic_library"
#0.5 set var for stopping running when an error occurs
set_app_var sh_script_stop_severity E;
set_app_var sh_continue_on_error false;
#1. config before compile
#1.0 set var name
set DESIGN_REF_DATA_PATH "../rtl/core";
set DESIGN_NAME "core"
#1.1 set source file dr
set RTL_FILE_DIR $DESIGN_REF_DATA_PATH
#1.2 set source file path 
set RTL_SOURCE_FILES [glob $RTL_FILE_DIR/*.v]
#1.3 setup for formality Verification
set_svf ../result/${DESIGN_NAME}.mapped.svf

#2 begin to compile
#2.1 map library to linux path
define_design_lib work -path ./work;
#2.2 compile and link
analyze -format verilog ${RTL_SOURCE_FILES} -lib work
elaborate ${DESIGN_NAME} -update -lib work
current_design $DESIGN_NAME
uniquify
link

#3 apply logical design constraints
source -echo -verbose ../script/dc_constraints.tcl

#4 create default path groups
#4.1 get root clock port
set ports_clock_root [filter_collection [get_attribute [get_clocks] sources] object_class==port]
#4.2 define different path
group_path -name REGOUT -to [all_outputs];
group_path -name REGIN -from [remove_from_collection [all_inputs] $ports_clock_root];
group_path -name FEEDTHROUGH -from [remove_from_collection [all_inputs] $ports_clock_root] -to [all_outputs];

#5 compile
#5.1 set buffer driver for each poet
set_fix_multiple_port_nets -all -buffer_constants
#5.2 check design and save log
check_design > ../log/check_design.log
#5.3 
remove_unconnected_ports [get_cells -hier {*}]
#
set_host_options -max_cores 1
#
compile_ultra -no_autoungroup -no_seq_output_inversion -no_boundary_optimization
#
change_names -rules verilog -hierarchy
#
write -hierarchy -format verilog -output ../netlist/core.v
#
set_svf -off
#reports
report_qor > ../reports/${DESIGN_NAME}.mapped.qor.rpt

report_timing -transition_time -nets -attribute -nworst 1 -max_paths 3000 > ../reports/${DESIGN_NAME}.mapped.timing.3000maxPaths.rpt
report_constraint -all > ../reports/${DESIGN_NAME}.mapped.timing.all_constraint.rpt
report_area -nosplit > ../reports/${DESIGN_NAME}.mapped.area.rpt
report_power -nosplit > ../reports/${DESIGN_NAME}.mapped.power.rpt
report_clock_gating -nosplit > ../reports/${DESIGN_NAME}.mapped.clock_gating.rpt