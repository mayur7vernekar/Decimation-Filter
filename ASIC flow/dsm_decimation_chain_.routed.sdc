################################################################################
#
# Design name:  floorplan_done
#
# Created by icc2 write_sdc on Thu Dec  4 19:10:13 2025
#
################################################################################

set sdc_version 2.1
set_units -time ns -resistance kOhm -capacitance pF -voltage V -current uA

################################################################################
#
# Units
# time_unit               : 1e-09
# resistance_unit         : 1000
# capacitive_load_unit    : 1e-12
# voltage_unit            : 1
# current_unit            : 1e-06
# power_unit              : 1e-12
################################################################################


# Mode: func
# Corner: nom
# Scenario: func::nom

# /home/student/Desktop/D_filteer_New/DC/ICC2/inputs/dsm_decimation_chain.mapped.sdc, \
#   line 9
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
set_propagated_clock [get_clocks {clk}]
# Warning: Libcell power domain derates are skipped!

# Set latency for io paths.
# -origin user
set_clock_latency 0.965004 [get_clocks {clk}]
# Set propagated on clock sources to avoid removing latency for IO paths.
set_propagated_clock  [get_ports {clk}]
