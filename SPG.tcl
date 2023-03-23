set input  top
set output after_floorplan_spg


#========== After preroute_standard_cells ===========
write_floorplan -create_terminal -row -track -preroute -placement {hard_macro terminal} -pin_guide ${input}.fp
write_def -version 5.8 -rows_tracks_gcells -all_vias -placed -pins -blockages -specialnets -output ${input}.def


#========== Read def & fp in DC_NXT topo=========
#dcnxt_shell -topo -gui
open_mw_lib /home/louis/soc/dff/SGDE
set_app_var link_library     "* slow.db fast.db typical.db dw_foundation.sldb"
set_tlu_plus_files   -max_tluplus /home/louis/soc/dff/t013s8mg_fsg_typical.tluplus  -tech2itf_map  /home/louis/soc/dff/t013s8mg_fsg.map
read_file -format verilog {/home/louis/soc/dff/SGDE_syn_dft.v}
current_design SGDE
read_floorplan ${input}.fp
extract_physical_constraints ${input}.def


#========== Re-syn with SPG =========
source ./syn_related/dft_setup.tcl
source ./syn_related/${design}.sdc
source ./syn_related/sta_setup.tcl
source ./syn_related/syn_setup.tcl
compile_ultra -gate_clock -scan -spg


#========= DFT & Re-syn===================
set_dft_configuration -fix_reset enable -connect_clock_gating enable
set_dft_clock_gating_pin -pin_name TE [get_cells -hier *clk_gate*]
insert_dft
set_placer_tns_driven_in_incremental_compile true
set spg_congestion_placement_in_incremental_compile true
compile_ultra -gate_clock -scan -spg -incremental


#======== Output ddc & def to ICC ================
source ./syn_related/change_name.tcl
write -hierarchy -format ddc -output ${output}.ddc
write_def -output ${output}.def
write_scan_def -output ${output}.scandef


#========= Return to ICC & Start from placement===============
import_designs -format ddc -top SGDE -cel SGDE {/home/louis/soc/dff/${output}.ddc}
read_def { "/home/louis/soc/dff/${output}.def"}
read_def { "/home/louis/soc/dff/${output}.scandef"}

set placer_disable_auto_bound_for_gated_clock false
set placer_gated_register_area_multiplier 5
place_opt -power -congestion -area_recovery -optimize_dft -optimize_icgs -spg