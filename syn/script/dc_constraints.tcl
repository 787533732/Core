#1. define var
#1.1 clock and reset
set CLK [get_ports clk_i]
set RST [get_ports rstn_i]
set clkPeriod_ns 4
set inDelay_ns   0
set outDelay_ns  0
#1.2 time analysis
set clkLatency_ns [expr $clkPeriod_ns*.02];
set clkSetup_ns   [expr $clkPeriod_ns*.1];
set clkHold_ns    [expr $clkPeriod_ns*.05];
#2. create and set clock
#2.1 createclock
create_clock -period $clkPeriod_ns $CLK;
#2.2 high fanout signal setting
set_dont_touch_network [list $CLK $RST];
set_ideal_network      [list $CLK $RST];
#2.3 clock skew
set_clock_uncertainty $clkSetup_ns -setup [get_clocks $CLK]
set_clock_uncertainty $clkHold_ns  -hold  [get_clocks $CLK]
#3. set wire load
#3.1 set the transition time of the drive port
set_input_transition [expr $clkPeriod_ns*.1] [all_inputs];
#3.2 set_wire_load_mode
set_wire_load_mode segmented;
set_app_var auto_wire_load_selection true;
#3.3 set output load
#set_load 0.1 [all_outputs]
#3.4 sets a derating factor on the current design
set_timing_derate -early 0.90
set_timing_derate -late  1.10
#3.5 set max transition and fanout
set_max_transition [expr $clkPeriod_ns*.1] $DESIGN_NAME;
set_max_fanout 16 $DESIGN_NAME;
#4 set min and max delay of input and output
#4.1 set min delay
set_input_delay -min 0 -clock $CLK [get_ports intr_i        ];
set_input_delay -min 0 -clock $CLK [get_ports reset_vector_i];
set_input_delay -min 0 -clock $CLK [get_ports cpu_id_i      ];
set_input_delay -min 0 -clock $CLK [get_ports mem_i_accept_i];
set_input_delay -min 0 -clock $CLK [get_ports mem_i_inst_i  ];
set_input_delay -min 0 -clock $CLK [get_ports mem_i_valid_i ];
set_input_delay -min 0 -clock $CLK [get_ports mem_i_error_i ];
set_input_delay -min 0 -clock $CLK [get_ports mem_d_data_rd_i ];
set_input_delay -min 0 -clock $CLK [get_ports mem_d_accept_i  ];
set_input_delay -min 0 -clock $CLK [get_ports mem_d_ack_i     ];
set_input_delay -min 0 -clock $CLK [get_ports mem_d_error_i   ];
set_input_delay -min 0 -clock $CLK [get_ports mem_d_resp_tag_i];
#
set_output_delay  -min 0 -clock $CLK [get_ports mem_i_rd_o         ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_i_pc_o         ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_i_flush_o      ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_i_invalidate_o ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_addr_o      ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_data_wr_o   ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_rd_o        ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_wr_o        ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_cacheable_o ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_req_tag_o   ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_invalidate_o];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_writeback_o ];
set_output_delay  -min 0 -clock $CLK [get_ports mem_d_flush_o];
#4.2 set max delay
set MAX_OUT_BUDGET [expr {0.5 * $clkPeriod_ns}];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports intr_i        ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports reset_vector_i];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports cpu_id_i      ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_accept_i];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_inst_i  ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_valid_i ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_error_i ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_data_rd_i ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_accept_i  ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_ack_i     ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_error_i   ];
set_input_delay -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_resp_tag_i];#

set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_rd_o         ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_pc_o         ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_flush_o      ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_i_invalidate_o ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_addr_o      ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_data_wr_o   ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_rd_o        ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_wr_o        ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_cacheable_o ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_req_tag_o   ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_invalidate_o];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_writeback_o ];
set_output_delay  -max $MAX_OUT_BUDGET -clock $CLK [get_ports mem_d_flush_o];
#5. other settings
set_app_var hdlin_check_no_latch true;
set_max_area 0;