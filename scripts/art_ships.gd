extends RefCounted
# Each ship's signature machines (2026-10-20 rework, player: "parts you can name, drawn
# the way the real thing is built"): a drilling ship's top drive and triplex mud pumps,
# a cryoplant's turboexpanders, a telescope's wavefront sensor... Picked by the piece's
# kind (name_key), so every ship carrying one shows it; recorded once and replayed
# like the shared art (art_equip.gd, whose primitives these use).

const E = preload("res://scripts/art_equip.gd")
const LC = preload("res://scripts/liquid_colors.gd")
const M := 48.0

const BY_NAME := {
	# E002–E016 (2026-11-11): the fifteen that all drew as the shared aux valve
	"p_ark_amp": "rf_amp",
	"p_aux": "aux_rocket",
	"p_ax_gamma_monitor": "gamma_probe",
	"p_bl_feeder": "pellet_feeder",
	"p_bl_humidifier": "steam_cyl",
	"p_bl_mister": "fog_pump",
	"p_comms": "comms_desk",
	"p_dc_firewall": "fw_appliance",
	"p_dr_welder": "rig_welder",
	"p_e07": "e07_unit",
	"p_ev_shunt": "shunt_reg",
	"p_fx_gas_injector": "gas_puff",
	"p_hg_ioniser": "ion_grid",
	"p_qc_clock": "rb_clock",
	"p_st_daq": "daq_rail",
	# E018–E028 (2026-11-11): the batteries that all drew as the shared battery cabinet
	"p_ark_aux_battery": "ark_aux_pack",
	"p_ark_battery_cart": "battery_cart",
	"p_ark_emerg_light": "emerg_light",
	"p_ark_ring_battery": "ring_battery",
	"p_ark_shuttle_battery": "shuttle_pack",
	"p_aux_battery": "vrla_rack",
	"p_battery": "main_battery",
	"p_drone_pack": "drone_pack",
	"p_lc_courier_battery": "courier_stack",
	"p_lock_ups": "lock_ups",
	"p_pod_bat": "pod_ups",
	"p_st_battery": "race_pack",
	"p_standby_battery": "standby_bank",
	"p_ups": "ups_unit",
	# E036– (2026-11-11): the shared double-door cabinet, third batch
	"p_ark_brake_ctrl": "brake_ctrl",
	"p_ark_chem_dosing": "dosing_skid",
	"p_ark_material": "material_rack",
	"p_ark_process": "food_bench",
	"p_ark_transmitter": "tx_cabinet",
	"p_ark_turbine_ctrl": "turbine_ctrl",
	"p_drill": "bench_drill",
	"p_tool_cart": "tool_cart",
	"p_pack_rack": "pack_rack",
	"p_dispatch_log": "dispatch_log",
	"p_bms": "bms_cab",
	"p_cal_bench": "cal_bench",
	"p_survey_log": "survey_log",
	"p_crd": "crd_cab",
	"p_crypto": "crypto_rack",
	"p_hv_cabinet": "hv_switchgear",
	"p_gas_det": "gas_detector",
	"p_bl_herbarium": "herbarium",
	"p_bl_tool_shed": "garden_locker",
	"p_dr_chem_store": "chem_store",
	"p_dr_sample_cab": "core_store",
	"p_dr_tool_cab": "drill_tools",
	"p_dr_well_logs": "well_logs",
	"p_ev_calib": "ev_calib",
	"p_ev_dcdc": "dcdc",
	"p_fx_cdb": "cryo_cdb",
	"p_fx_cryo_spares": "cryo_spares",
	"p_fx_shot_archive": "shot_archive",
	"p_fx_spare_leads": "spare_leads",
	"p_hg_sample_cyl": "sample_cyl",
	"p_ob_cal": "ob_cal",
	"p_ob_plate_archive": "plate_archive",
	"p_ob_spare_cells": "spare_cells",
	"p_dc_spares": "server_spares",
	"p_batch_log": "batch_log",
	"p_cabinet": "shadow_board",
	"p_cargo_log": "cargo_log",
	"p_custody": "custody_reg",
	"p_evidence": "evidence_lockers",
	"p_flow_ctrl": "flow_ctrl",
	"p_lc_courier_mail": "mail_locker",
	"p_manifest": "manifest_term",
	"p_pharmacy": "drug_cabinet",
	"p_samples": "sample_trays",
	"p_seed_vault": "seed_vault",
	"p_smelt_log": "smelt_log",
	"p_st_spares": "cockpit_case",
	"p_stores": "supply_stack",
	"p_svc_cabinet": "svc_bench",
	"p_table": "dining_table",
	"p_towlog": "tow_log",
	# E089–E100 (2026-11-11): power and generation, fourth batch
	"p_fuel_cell": "fuel_cell_pm",
	"p_fuelcell": "fuel_cell_pm",
	"p_ark_backup_gen": "stirling_gen",
	"p_backup_gen": "turbine_genset",
	"p_standby_gen": "drups",
	"p_co2_gen": "co2_burner",
	"p_dr_generator": "diesel_genset",
	"p_gen": "rtg_module",
	"p_generator": "main_alternator",
	"p_ts_power": "ts_power",
	# E0xx–E158 (2026-11-12): fifth batch, the online catalog's ticks
	"p_s_bat": "s_bat",
	"p_sp_lock_backup": "lock_backup_box",
	"p_ark_charger": "charge_post",
	"p_bay_charger": "bay_charger",
	"p_brake_frame": "tether_brake_frame",
	"p_e07_socket": "wall_socket",
	"p_saddle_seat": "lift_saddle",
	"p_tether_root": "tether_root",
	"p_ts_bracket": "tank_bracket",
	"p_ts_manifold": "small_manifold",
	"p_ark_busbar": "busbar_box",
	"p_ark_irr_ctrl": "irrigation_ctrl",
	"p_ark_lift_call": "lift_call",
	"p_ark_low_dist": "standby_dist",
	"p_ark_panel": "room_panel",
	"p_ark_rod_panel": "rod_lock_panel",
	"p_bl_uv": "uv_tube",
	"p_dc_leak_panel": "leak_panel",
	"p_dr_brake_panel": "brake_handle_panel",
	"p_dr_slips_panel": "slips_panel",
	"p_esd": "esd_station",
	"p_ev_pcu": "solar_pcu",
	"p_ev_shield_sensor": "shield_probe",
	"p_fender": "push_fender",
	"p_frost_vent": "frost_vent",
	"p_frz_ctrl": "freezer_ctrl",
	"p_fx_cryo_panel": "cryo_ctrl_panel",
	"p_hg_cryo_manifold": "cryo_manifold",
	"p_hg_level_gauge": "level_gauge",
	"p_hg_process_panel": "process_panel",
	"p_lc_cradle_panel": "cradle_ctrl",
	"p_lc_engine_panel": "engine_panel",
	"p_monitor_panel": "monitor_wall",
	"p_ob_baffle_heater": "baffle_heater",
	"p_ob_pcu": "quiet_pcu",
	"p_panel": "control_strip",
	"p_purge_panel": "purge_panel",
	"p_pusher": "pusher_plate",
	"p_qc_fridge_ctl": "fridge_ctl",
	"p_qc_hemt_bias": "hemt_bias",
	"p_rail_panel": "rail_lock_board",
	"p_rcs_ctrl": "rcs_ctrl",
	"p_ref_valve": "recovery_valves",
	"p_release_panel": "release_board",
	"p_sp_cradle_panel": "cradle_lock",
	"p_sp_fw_panel": "flywheel_brake_panel",
	"p_sp_rail_panel": "rail_lock_square",
	"p_sp_release_panel": "release_cabinet",
	"p_st_ecu": "race_ecu",
	"p_support": "hull_support",
	"p_tank_temp": "tank_temp",
	"p_tension": "tension_link",
	# E167–E220 (2026-11-12): sixth batch, switchboards and engines
	"p_ark_switchgear": "vcb_panel",
	"p_armctl": "arm_base",
	"p_bearing_ctrl": "bearing_ctrl",
	"p_brake_ctrl": "brake_ctrl_box",
	"p_coil_pwr": "coil_supply",
	"p_dist_a": "dist_a",
	"p_dist_b": "dist_b",
	"p_dr_vfd": "vfd_cabinet",
	"p_e07_jb": "junction_box",
	"p_furnace_ctrl": "furnace_ctrl",
	"p_fx_mps": "magnet_psu",
	"p_fx_qps": "quench_prot",
	"p_lock_solenoid": "lock_solenoid",
	"p_lv_dist": "lv_board",
	"p_main_dist": "main_dist",
	"p_ob_mcc": "mirror_ctrl",
	"p_pdu": "rack_pdu",
	"p_power_board": "panelboard",
	"p_process_cabinet": "plc_cabinet",
	"p_pump_power": "pump_mcc",
	"p_s_swb": "small_db",
	"p_swb": "ship_swb",
	"p_train_bus": "train_bus",
	"p_ts_bus": "ts_busbox",
	"p_valve_box": "valve_box",
	"p_vault_ctrl": "vault_ctrl",
	"p_wdist": "weapons_dist",
	"p_ark_shuttle_engine": "shuttle_engine",
	"p_ark_spare_engine": "spare_engine",
	"p_engc": "engine_cluster",
	"p_engine": "main_engine",
	"p_engine_big": "big_engine",
	"p_engine_pod": "engine_pod",
	"p_engt": "tug_engine",
	"p_hl_motor": "hl_motor",
	"p_lc_main_engine": "gg_engine",
	"p_power_tail": "power_tail",
	"p_vib_drive": "vib_drive",
	"p_engf": "engine_front",
	"p_main": "small_thruster",
	"p_lc_courier_engine": "courier_engine",
	# E242–E267 (2026-11-12): seventh batch, nozzles, attitude thrusters, spheres (p_dr_bop, p_hg_intake_comp,
	# p_ob_wheel, p_spray, p_tether_damper repointed in place above)
	"p_engn": "plug_nozzle",
	"p_lc_nozzle": "ablative_nozzle",
	"p_nozzle": "regen_nozzle",
	"p_thrust_chamber": "thrust_nozzle",
	"p_vent_tower": "vent_stack",
	"p_att": "cold_gas_pair",
	"p_rcs": "rcs_pod",
	"p_rcs_q": "mono_cluster",
	"p_fx_dewar": "he_dewar",
	"p_spa": "zero_g_spa",
	"p_steam_drum": "steam_drum",
	"p_clamp_act": "clamp_actuator",
	"p_ob_actuator": "mirror_actuator",
	# E268–E295 (2026-11-12): eighth batch, the capacitor-art kinds, chillers, fans (p_heat_pump, p_dr_choke,
	# p_hg_cryocooler, p_reliq, p_ark_condenser, p_dr_degasser, p_dc_dry_cooler repointed in place above;
	# p_power_board keeps panelboard, which hands MD-160's capacitor-art piece to dc_power_board)
	"p_ark_brake_cap": "supercap_rack",
	"p_cap": "storage_can",
	"p_cap_bank": "film_bank",
	"p_capacitor": "pulse_cap",
	"p_ccap": "pfn_ladder",
	"p_charge_ctrl": "charge_supply",
	"p_firing_cap": "cdu_box",
	"p_pyro": "pyro_bolt",
	"p_s_cap": "arm_cap_pack",
	"p_st_igniter": "ignition_exciter",
	"p_survey_probe": "survey_probe",
	"p_ts_cap": "cap_board",
	"p_wcap": "weapon_cap_rack",
	"p_chiller": "scroll_chiller",
	"p_ark_duct_fan": "inline_fan",
	"p_deck_fan": "deck_exhaust_fan",
	# E311–E345 (2026-11-12): ninth batch, the gas bottles and tanks (p_compressor, p_h2, p_o2, p_lube_tank,
	# p_n2_header: only their gastank-art pieces; the others keep their own art)
	"p_accumulator": "piston_accumulator",
	"p_argon": "argon_bundle",
	"p_ark_n2_cart": "n2_cart",
	"p_ark_n2tank": "n2_vessel",
	"p_ark_o2tank": "o2_vessel",
	"p_ax_he_buffer": "copv_buffer",
	"p_ax_xenon_tank": "xenon_tank",
	"p_ba_bank": "ba_fill_bank",
	"p_bl_o2_store": "o2_dryer_store",
	"p_compressor": "air_compressor_tank",
	"p_coolant_tank": "coolant_tank",
	"p_dr_accumulator": "bladder_accumulator",
	"p_dr_air_receiver": "air_receiver",
	"p_dr_n2": "bottle_chained",
	"p_expansion_tank": "expansion_tank",
	"p_fx_he_buffer": "he_buffer_skirt",
	"p_gastank": "slim_bottle",
	"p_h2": "h2_type4",
	"p_halon": "halon_bank",
	"p_lift_accumulator": "lift_accu_bank",
	"p_lube_tank": "lube_box_tank",
	"p_medgas": "medgas_bank",
	"p_n2_bottle": "n2_purge_tube",
	"p_n2_header": "n2_header_bank",
	"p_o2": "o2_steel_bottle",
	"p_o2_bottle": "o2_bottle_pair",
	"p_o2_store": "o2_cryo_tank",
	"p_o2bottle": "o2_flow_bottle",
	"p_pressurant": "pressurant_pair",
	"p_qc_he_buffer": "qc_he_buffer",
	"p_qc_mix_tank": "mix_tank_cage",
	"p_ref_receiver": "ref_receiver",
	"p_st_n2o": "n2o_tank",
	"p_ts_cell": "reagent_bottle",
	"p_weld_gas": "weld_bottle",
	# E161–E370 (2026-11-12): ninth batch part two (p_ark_turbine, p_dc_core_switch, p_dr_mud_gas_sep, p_hyd_pump,
	# p_cross_manifold, p_manifold, p_valve_block repointed in place; p_decon, p_dust_filter, p_strainer, p_water_treat:
	# only their filter-art pieces, the others keep their own art; p_n2_header's pipe piece goes to n2_header_pipe)
	"p_ark_dc_main": "ark_main_board",
	"p_ark_hub_dist": "ark_hub_dist",
	"p_ark_local_dist": "ark_local_dist",
	"p_ark_ring_dist": "ark_ring_dist",
	"p_ark_filter": "cartridge_filter",
	"p_bl_oxygenator": "fibre_oxygenator",
	"p_decon": "decon_booth",
	"p_dust_filter": "baghouse",
	"p_fx_he_purifier": "he_purifier",
	"p_hg_filter_bank": "filter_bank3",
	"p_iso_filter": "bibo_filter",
	"p_ob_hepa": "fan_filter_unit",
	"p_strainer": "duplex_strainer",
	"p_water_treat": "water_treat_skid",
	"p_door_hpu": "door_hpu",
	"p_hpu": "main_hpu",
	"p_main_valves": "main_valve_pair",
	"p_bl_sprinkler": "sprinkler_line",
	"p_bl_water_main": "water_main",
	"p_dc_manifold": "rack_coolant_manifold",
	"p_dr_mud_line": "mud_line",
	"p_fx_he_line": "he_tube_pair",
	"p_lc_courier_line": "braided_hose",
	"p_lc_fuel_main": "fuel_main_dw",
	"p_ob_cryo_line": "vj_cryo_line",
	"p_riser": "riser_pipe",
	"p_sp_post": "rack_post",
	# E380–E425 (2026-11-13): tenth batch part one, the pumps and radiators (p_brake_cooler: its pump-art piece is
	# brake_oil_pack, its radiator-art pieces brake_oil_cooler; p_vent_valve: only its pump-art piece; p_compressor's
	# and p_strainer's pump-art pieces go to screw_compressor / auto_strainer through their existing arms)
	"p_ark_feed_pump": "feed_pump_ms",
	"p_ark_lube_skid": "lube_skid",
	"p_ark_main_pump": "inline_vpump",
	"p_ark_pump": "circulator",
	"p_bag_pump": "bag_blower",
	"p_ballast_pump": "ballast_primed",
	"p_belt_motor": "belt_drive",
	"p_bl_ball_pump": "diaphragm_pump",
	"p_bl_irrigation": "irrigation_head",
	"p_brake_cooler": "brake_oil_cooler",
	"p_coolant_pump": "monobloc_pump",
	"p_dc_main_pump": "twin_head_pump",
	"p_dc_pump": "portable_dc_pump",
	"p_dr_air_compressor": "piston_compressor",
	"p_dr_hpu": "compact_hpu",
	"p_drencher": "deluge_set",
	"p_hg_transfer_pump": "cryo_sump_pump",
	"p_lc_fuel_pump": "fuel_pump_xp",
	"p_lube_pump": "grease_station",
	"p_main_pump": "split_case_pump",
	"p_motor": "conveyor_drive",
	"p_nutrient_pump": "peristaltic_doser",
	"p_process_pump": "api_process_pump",
	"p_pump": "end_suction_pump",
	"p_return_pump": "self_priming_pump",
	"p_spa_pump": "spa_pump_set",
	"p_sump_pump": "sump_submersible",
	"p_svc_pump": "duty_standby_pumps",
	"p_tank_pump": "tank_lineshaft",
	"p_transfer_pump": "gear_transfer",
	"p_ts_pump": "mini_mag_pump",
	"p_vent_valve": "actuated_vent",
	"p_water_pump": "booster_set",
	"p_fin": "racing_fin",
	"p_ice_heater": "ice_heat_pad",
	"p_radiator": "radiator_panel",
	"p_radiator_fin": "radiator_wing",
	"p_radiator_petal": "petal_radiator",
	"p_s_rad": "osr_plate",
	"p_sensor_cooler": "stirling_cooler",
	"p_st_cooler": "battery_cold_plate",
	"p_thermal_unit": "thermal_stack",
	"p_wcool": "weapon_cooler",
	# E442–E537 (2026-11-13): tenth batch part two, water / environment / cold stores / oxygen cabinets (p_heater: only
	# its env-art piece; p_ark_fridge: its freezer-art piece upright_freezer, its fridge-art piece two_door_fridge;
	# p_decon's env-art piece -> decon_line and p_water_treat's water-art pieces -> ro_rack through their existing arms)
	"p_ark_dispenser": "water_dispenser",
	"p_ark_ecc_tank": "eccs_tank",
	"p_ark_water_tank": "sectional_tank",
	"p_ballast": "ballast_tank",
	"p_bio_tank": "bio_waste_tank",
	"p_bl_fish_tank": "fish_tank",
	"p_bl_nutrient_tank": "nutrient_mixer_tank",
	"p_bl_pond": "wetland_pond",
	"p_bl_water_recycler": "water_recovery",
	"p_dr_mud_tank": "mud_agitator_tank",
	"p_hyd_tank": "hyd_reservoir",
	"p_sanitation": "sanitary_module",
	"p_ts_lqtank": "coolant_bottle",
	"p_water_tank": "fresh_water_tank",
	"p_ahu": "ahu_sections",
	"p_air_plant": "o2_generator_plant",
	"p_air_regen": "twin_bed_regen",
	"p_ark_airmach": "axial_air_machine",
	"p_ark_rack_cooler": "inrow_cooler",
	"p_bl_co2_scrubber": "co2_canister_scrubber",
	"p_bl_dehumidifier": "dehumidifier_unit",
	"p_bl_life_support": "life_support_rack",
	"p_dc_crah": "crah_downflow",
	"p_dr_fume_hood": "fume_hood",
	"p_ecs": "ecs_pack",
	"p_ecs_big": "ecs_plantroom",
	"p_env": "compact_ecu",
	"p_env_control": "env_controller",
	"p_heater": "freeze_heater",
	"p_hvac": "hvac_package",
	"p_life_support": "life_support_master",
	"p_ob_cleanair": "clean_air_supply",
	"p_pod_air": "pod_circulator",
	"p_ark_chiller": "condensing_unit",
	"p_ark_fridge": "upright_freezer",
	"p_freezer": "ult_freezer",
	"p_qc_chiller": "lab_chiller",
	"p_sample_freezer": "sample_store",
	"p_vaccine_box": "vaccine_carrier",
	"p_bl_fridge": "lab_fridge",
	"p_ark_o2cab": "o2_outlet_station",
	"p_o2cab": "emergency_o2_box",
	# E435–E581 (2026-11-13): tenth batch part three, lockers / seats / berths / racks / planting / medical / galleys and the
	# rest (p_separator, p_dr_shaker, p_screener, p_dr_standpipe, p_hg_turboexpander, p_bl_compost, p_escape_pod,
	# p_uv_steriliser, p_pharmacy repointed in place; p_pharmacy's cabinet-art pieces keep pharmacy, p_vent's pump-art
	# piece keeps its pump; the seats, beds, medical carts and plant trays also left art_detail's shared drawings)
	"p_ark_bed": "berth_pod",
	"p_ark_medbed": "operating_table",
	"p_bed": "icu_bed",
	"p_bunk": "crew_berth",
	"p_crew_bunk": "double_bunk",
	"p_rest_pod": "rest_capsules",
	"p_ark_galley": "galley_counter",
	"p_crew_mess": "mess_serving_line",
	"p_galley": "ship_galley",
	"p_ark_emerg_locker": "emergency_kit_locker",
	"p_ark_locker": "tier_locker",
	"p_baggage": "baggage_hold",
	"p_bins": "overhead_bins",
	"p_charges": "explosives_magazine",
	"p_dc_locker": "dc_gear_locker",
	"p_emerg_cab": "hose_reel_cabinet",
	"p_guard_locker": "weapons_locker",
	"p_lashing": "lashing_store",
	"p_locker": "tool_locker",
	"p_rotor_spares": "rotor_blade_rack",
	"p_spill_kit": "spill_station",
	"p_anes": "anaesthesia_machine",
	"p_ark_medmon": "bedside_monitor",
	"p_defib": "defibrillator",
	"p_dose_probe": "dose_probe_meter",
	"p_vent": "icu_ventilator",
	"p_ark_plant_tray": "grow_tray",
	"p_bl_hydro_rack": "nft_rack",
	"p_bl_planter": "raised_planter",
	"p_bl_vertical_farm": "aero_tower",
	"p_culture_rack": "culture_racks",
	"p_artwork": "framed_artwork",
	"p_bl_fruit_tree": "fruit_tree",
	"p_bl_soil_bed": "soil_bed",
	"p_seedling_rack": "seedling_racks",
	"p_ark_chair": "task_chair",
	"p_seat_c": "copilot_seat",
	"p_seat_p": "pilot_bucket",
	"p_seat_pilot": "bridge_chair",
	"p_seat_row": "passenger_seat",
	"p_ark_shelf": "wall_shelf",
	"p_dc_spare_shelf": "drive_shelf",
	"p_dr_core_rack": "core_box_rack",
	"p_dr_sack_store": "sack_pallet",
	"p_dr_spares_rack": "rig_spares_rack",
	"p_parts_rack": "bin_parts_rack",
	# DR-150 Derrick
	"p_dr_top_drive": "top_drive", "p_dr_drawworks": "drawworks", "p_dr_crown_block": "crown_block",
	"p_dr_travel_block": "travel_block", "p_dr_rotary": "rotary_table", "p_dr_stand": "drillpipe",
	"p_dr_bha": "bha", "p_dr_mud_pump": "mud_pump", "p_dr_shaker": "shale_shaker", "p_dr_desander": "hydrocyclone",
	"p_dr_degasser": "vacuum_degasser", "p_dr_centrifuge": "decanter", "p_dr_mud_gas_sep": "poorboy_degasser",
	"p_dr_agitator": "agitator", "p_dr_roughneck": "roughneck", "p_dr_pipe_rack": "pipe_rack",
	"p_dr_casing": "pipe_bundle", "p_dr_bop": "bop_stack", "p_dr_lathe": "lathe", "p_dr_mill": "mill",
	"p_dr_standpipe": "standpipe_riser", "p_dr_choke": "choke_skid", "p_dr_bop_accumulator": "koomey",
	# HG-170 Gas Sea (and FX-70's helium compressors)
	"p_hg_intake_comp": "intake_axial",
	"p_fx_he_compressor": "screw_comp",
	"p_hg_sample_comp": "screw_comp",
	"p_hg_cryocooler": "gm_cold_head",
	"p_hg_ortho_para": "ortho_para",
	"p_hg_precooler": "precooler",
	"p_hg_separator": "psa",
	"p_hg_chromatograph": "gc",
	"p_hg_mass_spec": "mass_spec",
	"p_hg_turboexpander": "turbo_expander",
	# QC-30 Quantum
	"p_qc_stage_50k": "dr_stage",
	"p_qc_stage_4k": "dr_stage",
	"p_qc_stage_still": "dr_stage",
	"p_qc_stage_cp": "dr_stage",
	"p_qc_stage_mxc": "dr_stage",
	"p_qc_qpu": "qpu",
	"p_qc_pt_head": "pulse_tube",
	"p_qc_ghs": "ghs",
	"p_qc_vit": "iso_table",
	"p_qc_awg": "instrument_rack",
	"p_qc_readout": "instrument_rack",
	"p_qc_turbo": "turbo_pump",
	"p_qc_still_pump": "scroll_pump",
	"p_qc_compressor": "screw_comp",
	# OB-90 Observatory (and the cameras and spectrometers elsewhere)
	"p_ob_hexapod": "hexapod",
	"p_ob_aft_optics": "aft_optics",
	"p_ob_fsm": "fsm",
	"p_ob_nircam": "ir_camera",
	"p_ev_thermal_cam": "ir_camera",
	"p_ob_spectro": "spectrograph",
	"p_ev_spectrometer": "spectrograph",
	"p_ob_fgs": "fgs",
	"p_ob_wfs": "wfs",
	"p_ob_cryocooler": "pulse_tube",
	"p_ob_recoater": "recoater",
	"p_ob_wheel": "ob_reaction_wheel",
	"p_star_tracker": "star_tracker",
	# DC-84 Deep Mind
	"p_dc_rack": "immersion_rack",
	"p_dc_cdu": "cdu",
	"p_dc_dry_cooler": "vbank_cooler",
	"p_dc_array": "storage_array",
	"p_dc_core_switch": "core_switch",
	"p_dc_drive": "drive_carrier",
	# ARK-01 Voyager: the power core, the rings
	"p_reactor_core": "pwr_core",
	"p_ark_secondary_reactor": "pwr_core",
	"p_core_pump": "rcp",
	"p_ark_pressurizer": "pressurizer",
	"p_ark_crd": "crdm",
	"p_ark_turbine": "ark_turbine",
	"p_ark_condenser": "surface_condenser",
	"p_ark_despin": "despin_drive",
	"p_ark_slip_ring": "slip_ring",
	"p_ark_rotary_seal": "rotary_seal",
	"p_ark_spoke_lift": "spoke_lift",
	"p_lift_car": "spoke_lift",
	"p_ark_vehicle": "work_vehicle",
	"p_ark_food_module": "food_module",
	"p_cross_manifold": "cross_manifold",
	# ST-40, EV-55, BL-88, LC-140
	"p_st_turbopump": "turbopump",
	"p_ev_coronagraph": "coronagraph",
	"p_ev_particle": "particle_det",
	"p_ev_magnetometer": "magnetometer",
	"p_bl_electrolyser": "bl_electrolyser",
	"p_bl_compost": "drum_composter",
	"p_bl_beehive": "beehive",
	"p_lc_forklift": "forklift",
	"p_lc_hold_crane": "hold_crane",
	# R2 reference ships
	"p_scanner": "xray_scanner",
	"p_mail": "mail_sorter",
	"p_fdr": "blackbox",
	"p_winch": "tow_winch",
	"p_sail_winch": "tow_winch",
	"p_lathe": "lathe",
	"p_hyd_pump": "motor_pump_set",
	"p_spray": "spray_line",
	"p_microscope": "microscope",
	"p_co2": "co2_scrubber",
	"p_uv_steriliser": "uv_chamber",
	"p_humidity": "humidifier",
	"p_ref_plant": "ref_plant",
	"p_evaporator": "evaporator",
	"p_forklift": "forklift",
	"p_safe_box": "safe_deposit",
	"p_armory": "gun_rack",
	"p_biometric": "biometric",
	"p_separator": "three_phase_sep",
	"p_level_radar": "level_radar",
	"p_flow_meter": "coriolis",
	"p_manifold": "precision_manifold",
	"p_optics": "ir_camera",
	"p_inertial_unit": "imu",
	"p_align_bench": "iso_table",
	"p_furnace_core": "arc_furnace",
	"p_ingot_rack": "ingot_rack",
	"p_sorter": "eddy_sorter",
	"p_mag_sep": "mag_separator",
	"p_scrubber": "scrubber",
	"p_spectro": "spectrograph",
	"p_heat_pump": "heat_pump_set",
	"p_car": "car",
	"p_deck_tractor": "deck_tractor",
	"p_apu": "apu_mono",
	"p_escape_pod": "escape_capsule",
	# the odd-shaped ships
	"p_crane_trolley": "hold_crane",
	"p_ntr_core": "ntr_core",
	"p_control_drum": "control_drum",
	"p_rad_shield": "shadow_shield",
	"p_flywheel": "flywheel_rotor",
	"p_launch_cradle": "launch_cradle",
	"p_tether_damper": "tether_dashpot",
	"p_hyd_clamp": "hyd_clamp",
	"p_piano": "piano",
	"p_wine_wall": "wine_rack",
	"p_bar": "bar",
	# the early ships
	"p_reactor": "pwr_core",
	"p_crusher": "crusher",
	"p_screener": "crusher_trommel",
	"p_reliq": "reliq_coldbox",
	"p_n2gen": "psa",
	"p_o2_gen": "psa",
	"p_bog": "screw_comp",
	"p_valve_block": "tow_valve_block",
}

const DRAWN := ["top_drive", "drawworks", "crown_block", "travel_block", "rotary_table", "drillpipe", "bha", "mud_pump",
	"shaker", "hydrocyclone", "degasser", "decanter", "gas_buster", "agitator", "roughneck", "pipe_rack", "pipe_bundle",
	"bop", "lathe", "mill", "standpipe", "choke_manifold", "koomey", "axial_comp", "screw_comp", "cold_box_h2", "ortho_para", "precooler", "psa", "gc", "mass_spec", "turboexpander", "dr_stage", "qpu", "pulse_tube", "ghs", "iso_table", "instrument_rack", "turbo_pump", "scroll_pump", "hexapod", "aft_optics", "fsm", "ir_camera", "spectrograph", "fgs", "wfs", "recoater", "reaction_wheel", "star_tracker", "immersion_rack", "cdu", "dry_cooler", "storage_array", "switch_chassis", "drive_carrier", "pwr_core", "rcp", "pressurizer", "crdm", "steam_turbine", "condenser", "despin_brake", "slip_ring", "rotary_seal", "spoke_lift", "work_vehicle", "food_module", "turbopump", "coronagraph", "particle_det", "magnetometer", "electrolyser", "composter", "beehive", "forklift", "hold_crane", "xray_scanner", "mail_sorter", "tow_winch", "spray_bar", "microscope", "co2_scrubber", "uv_steriliser", "humidifier", "ref_plant", "evaporator", "safe_deposit", "gun_rack", "biometric", "separator_3ph", "level_radar", "coriolis", "imu", "arc_furnace", "ingot_rack", "eddy_sorter", "mag_separator", "scrubber", "car", "deck_tractor", "apu", "escape_pod", "ntr_core", "control_drum", "shadow_shield", "flywheel_rotor", "launch_cradle", "tether_damper", "hyd_clamp", "piano", "wine_rack", "bar", "crusher",
	"rf_amp", "aux_rocket", "gamma_probe", "pellet_feeder", "steam_cyl", "fog_pump", "comms_desk", "fw_appliance", "rig_welder", "e07_unit", "shunt_reg", "gas_puff", "ion_grid", "rb_clock", "daq_rail",
	"ark_aux_pack", "battery_cart", "emerg_light", "ring_battery", "shuttle_pack", "vrla_rack", "main_battery", "drone_pack", "courier_stack", "lock_ups", "pod_ups", "race_pack", "standby_bank", "ups_unit",
	"brake_ctrl", "dosing_skid", "material_rack", "food_bench", "tx_cabinet", "turbine_ctrl", "bench_drill", "tool_cart", "pack_rack", "dispatch_log", "bms_cab", "cal_bench", "survey_log", "crd_cab", "crypto_rack", "hv_switchgear", "gas_detector",
	"herbarium", "garden_locker", "chem_store", "core_store", "drill_tools", "well_logs", "ev_calib", "dcdc", "cryo_cdb", "cryo_spares", "shot_archive", "spare_leads", "sample_cyl", "ob_cal", "plate_archive", "spare_cells", "server_spares",
	"batch_log", "shadow_board", "cargo_log", "custody_reg", "evidence_lockers", "flow_ctrl", "mail_locker", "manifest_term", "pharmacy", "sample_trays", "seed_vault", "smelt_log", "cockpit_case", "supply_stack", "svc_bench", "dining_table", "tow_log",
	"bl_electrolyser", "fuel_cell_pm", "stirling_gen", "turbine_genset", "drups", "co2_burner", "diesel_genset", "rtg_module", "main_alternator", "ts_power",
	"apu_mono", "s_bat", "lock_backup_box", "charge_post", "bay_charger", "tether_brake_frame", "wall_socket", "lift_saddle", "tether_root", "tank_bracket", "small_manifold", "busbar_box", "irrigation_ctrl", "lift_call", "standby_dist", "room_panel", "rod_lock_panel", "uv_tube", "leak_panel", "brake_handle_panel", "slips_panel", "esd_station", "solar_pcu", "shield_probe", "push_fender", "frost_vent", "freezer_ctrl", "cryo_ctrl_panel", "cryo_manifold", "level_gauge", "process_panel", "cradle_ctrl", "engine_panel", "monitor_wall", "baffle_heater", "quiet_pcu", "control_strip", "purge_panel", "pusher_plate", "fridge_ctl", "hemt_bias", "rail_lock_board", "rcs_ctrl", "recovery_valves", "release_board", "cradle_lock", "flywheel_brake_panel", "rail_lock_square", "release_cabinet", "race_ecu", "hull_support", "tank_temp", "tension_link",
	"vcb_panel", "arm_base", "bearing_ctrl", "brake_ctrl_box", "coil_supply", "dist_a", "dist_b", "vfd_cabinet", "junction_box", "furnace_ctrl", "magnet_psu", "quench_prot", "lock_solenoid", "lv_board", "main_dist", "mirror_ctrl", "rack_pdu", "panelboard", "plc_cabinet", "pump_mcc", "small_db", "ship_swb", "train_bus", "ts_busbox", "valve_box", "vault_ctrl", "weapons_dist", "despin_drive", "shuttle_engine", "spare_engine", "engine_cluster", "main_engine", "big_engine", "engine_pod", "tug_engine", "hl_motor", "gg_engine", "power_tail", "vib_drive", "engine_front", "small_thruster", "courier_engine",
	"plug_nozzle", "ablative_nozzle", "regen_nozzle", "thrust_nozzle", "vent_stack", "cold_gas_pair", "rcs_pod", "mono_cluster", "he_dewar", "zero_g_spa", "steam_drum", "clamp_actuator", "mirror_actuator", "bop_stack", "intake_axial", "ob_reaction_wheel", "spray_line", "tether_dashpot",
	"supercap_rack", "storage_can", "film_bank", "pulse_cap", "pfn_ladder", "charge_supply", "cdu_box", "pyro_bolt", "arm_cap_pack", "ignition_exciter", "survey_probe", "cap_board", "weapon_cap_rack", "scroll_chiller", "inline_fan", "deck_exhaust_fan", "heat_pump_set", "choke_skid", "gm_cold_head", "reliq_coldbox", "surface_condenser", "vacuum_degasser", "vbank_cooler", "dc_power_board",
	"piston_accumulator", "argon_bundle", "n2_cart", "n2_vessel", "o2_vessel", "copv_buffer", "xenon_tank", "ba_fill_bank", "o2_dryer_store", "air_compressor_tank", "coolant_tank", "bladder_accumulator", "air_receiver", "bottle_chained", "expansion_tank", "he_buffer_skirt", "slim_bottle", "h2_type4", "halon_bank", "lift_accu_bank", "lube_box_tank", "medgas_bank", "n2_purge_tube", "n2_header_bank", "o2_steel_bottle", "o2_bottle_pair", "o2_cryo_tank", "o2_flow_bottle", "pressurant_pair", "qc_he_buffer", "mix_tank_cage", "ref_receiver", "n2o_tank", "reagent_bottle", "weld_bottle",
	"ark_turbine", "core_switch", "poorboy_degasser", "motor_pump_set", "cross_manifold", "precision_manifold", "tow_valve_block", "ark_main_board", "ark_hub_dist", "ark_local_dist", "ark_ring_dist", "cartridge_filter", "fibre_oxygenator", "decon_booth", "baghouse", "he_purifier", "filter_bank3", "bibo_filter", "fan_filter_unit", "duplex_strainer", "water_treat_skid", "door_hpu", "main_hpu", "main_valve_pair", "sprinkler_line", "water_main", "rack_coolant_manifold", "mud_line", "he_tube_pair", "braided_hose", "fuel_main_dw", "vj_cryo_line", "riser_pipe", "rack_post",
	"feed_pump_ms", "lube_skid", "inline_vpump", "circulator", "bag_blower", "ballast_primed", "belt_drive", "diaphragm_pump", "irrigation_head", "brake_oil_cooler", "monobloc_pump", "twin_head_pump", "portable_dc_pump", "piston_compressor", "compact_hpu", "deluge_set", "cryo_sump_pump", "fuel_pump_xp", "grease_station", "split_case_pump", "conveyor_drive", "peristaltic_doser", "api_process_pump", "end_suction_pump", "self_priming_pump", "spa_pump_set", "sump_submersible", "duty_standby_pumps", "tank_lineshaft", "gear_transfer", "mini_mag_pump", "actuated_vent", "booster_set", "racing_fin", "ice_heat_pad", "radiator_panel", "radiator_wing", "petal_radiator", "osr_plate", "stirling_cooler", "battery_cold_plate", "thermal_stack", "weapon_cooler", "brake_oil_pack", "screw_compressor", "auto_strainer",
	"water_dispenser", "eccs_tank", "sectional_tank", "ballast_tank", "bio_waste_tank", "fish_tank", "nutrient_mixer_tank", "wetland_pond", "water_recovery", "mud_agitator_tank", "hyd_reservoir", "sanitary_module", "coolant_bottle", "fresh_water_tank", "ahu_sections", "o2_generator_plant", "twin_bed_regen", "axial_air_machine", "inrow_cooler", "co2_canister_scrubber", "dehumidifier_unit", "life_support_rack", "crah_downflow", "fume_hood", "ecs_pack", "ecs_plantroom", "compact_ecu", "env_controller", "freeze_heater", "hvac_package", "life_support_master", "clean_air_supply", "pod_circulator", "condensing_unit", "upright_freezer", "ult_freezer", "lab_chiller", "sample_store", "vaccine_carrier", "lab_fridge", "o2_outlet_station", "emergency_o2_box", "two_door_fridge", "decon_line", "ro_rack",
	"drug_cabinet", "shale_shaker", "standpipe_riser", "turbo_expander", "drum_composter", "uv_chamber", "three_phase_sep", "escape_capsule", "crusher_trommel", "berth_pod", "operating_table", "icu_bed", "crew_berth", "double_bunk", "rest_capsules", "galley_counter", "mess_serving_line", "ship_galley", "emergency_kit_locker", "tier_locker", "baggage_hold", "overhead_bins", "explosives_magazine", "dc_gear_locker", "hose_reel_cabinet", "weapons_locker", "lashing_store", "tool_locker", "rotor_blade_rack", "spill_station", "anaesthesia_machine", "bedside_monitor", "defibrillator", "dose_probe_meter", "icu_ventilator", "grow_tray", "nft_rack", "raised_planter", "aero_tower", "culture_racks", "framed_artwork", "fruit_tree", "soil_bed", "seedling_racks", "task_chair", "copilot_seat", "pilot_bucket", "bridge_chair", "passenger_seat", "wall_shelf", "drive_shelf", "core_box_rack", "sack_pallet", "rig_spares_rack", "bin_parts_rack"]


static func L(ci: CanvasItem, a: Vector2, b: Vector2, al: float = 0.5, wd: float = 1.0) -> void:
	E.L(ci, a, b, al, wd)


static func R(ci: CanvasItem, r: Rect2, al: float = 0.5, wd: float = 1.0) -> void:
	E.R(ci, r, al, wd)


static func O(ci: CanvasItem, c: Vector2, r: float, al: float = 0.5, wd: float = 1.0) -> void:
	E.O(ci, c, r, al, wd)


static func A(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, al: float = 0.5, wd: float = 1.0) -> void:
	E.A(ci, c, r, a0, a1, al, wd)


static func D(ci: CanvasItem, c: Vector2, r: float = 1.1, al: float = 0.5) -> void:
	E.D(ci, c, r, al)


static func P(ci: CanvasItem, pts: PackedVector2Array, al: float = 0.5, wd: float = 1.0) -> void:
	E.P(ci, pts, al, wd)


static func S(ci: CanvasItem, segs: PackedVector2Array, al: float = 0.3, wd: float = 1.0) -> void:
	E.S(ci, segs, al, wd)


static func sub(r: Rect2, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return E.sub(r, x0, y0, x1, y1)


static func hatch(ci: CanvasItem, r: Rect2, pitch: float, vert: bool, al: float = 0.22, cap: int = 120) -> void:
	E.hatch(ci, r, pitch, vert, al, cap)


static func _draw_art(ci: CanvasItem, art: String, r: Rect2, p, font: Font) -> void:
	match art:
		"top_drive": top_drive(ci, r)
		"drawworks": drawworks(ci, r)
		"crown_block": crown_block(ci, r)
		"travel_block": travel_block(ci, r)
		"rotary_table": rotary_table(ci, r)
		"drillpipe": drillpipe(ci, r)
		"bha": bha(ci, r)
		"mud_pump": mud_pump(ci, r)
		"shaker": shaker(ci, r)
		"hydrocyclone": hydrocyclone(ci, r)
		"degasser": degasser(ci, r)
		"decanter": decanter(ci, r)
		"gas_buster": gas_buster(ci, r)
		"agitator": agitator(ci, r)
		"roughneck": roughneck(ci, r)
		"pipe_rack": pipe_rack(ci, r)
		"pipe_bundle": pipe_bundle(ci, r)
		"bop": bop(ci, r)
		"lathe": lathe(ci, r)
		"mill": mill(ci, r)
		"standpipe": standpipe(ci, r)
		"choke_manifold": choke_manifold(ci, r)
		"koomey": koomey(ci, r)
		"axial_comp": axial_comp(ci, r)
		"screw_comp": screw_comp(ci, r)
		"cold_box_h2": cold_box_h2(ci, r)
		"ortho_para": ortho_para(ci, r)
		"precooler": precooler(ci, r)
		"psa": psa(ci, r)
		"gc": gc(ci, r)
		"mass_spec": mass_spec(ci, r)
		"turboexpander": turboexpander(ci, r)
		"dr_stage": dr_stage(ci, r, p)
		"qpu": qpu(ci, r)
		"pulse_tube": pulse_tube(ci, r)
		"ghs": ghs(ci, r)
		"iso_table": iso_table(ci, r)
		"instrument_rack": instrument_rack(ci, r)
		"turbo_pump": turbo_pump(ci, r)
		"scroll_pump": scroll_pump(ci, r)
		"hexapod": hexapod(ci, r)
		"aft_optics": aft_optics(ci, r)
		"fsm": fsm(ci, r)
		"ir_camera": ir_camera(ci, r)
		"spectrograph": spectrograph(ci, r)
		"fgs": fgs(ci, r)
		"wfs": wfs(ci, r)
		"recoater": recoater(ci, r)
		"reaction_wheel": reaction_wheel(ci, r)
		"star_tracker": star_tracker(ci, r)
		"immersion_rack": immersion_rack(ci, r)
		"cdu": cdu(ci, r)
		"dry_cooler": dry_cooler(ci, r)
		"storage_array": storage_array(ci, r)
		"switch_chassis": switch_chassis(ci, r)
		"drive_carrier": drive_carrier(ci, r)
		"pwr_core": pwr_core(ci, r)
		"rcp": rcp(ci, r)
		"pressurizer": pressurizer(ci, r)
		"crdm": crdm(ci, r)
		"steam_turbine": steam_turbine(ci, r)
		"condenser": condenser(ci, r)
		"despin_brake": despin_brake(ci, r)
		"slip_ring": slip_ring(ci, r)
		"rotary_seal": rotary_seal(ci, r)
		"spoke_lift": spoke_lift(ci, r)
		"work_vehicle": work_vehicle(ci, r)
		"food_module": food_module(ci, r)
		"turbopump": turbopump(ci, r)
		"coronagraph": coronagraph(ci, r)
		"particle_det": particle_det(ci, r)
		"magnetometer": magnetometer(ci, r)
		"electrolyser": electrolyser(ci, r)
		"composter": composter(ci, r)
		"beehive": beehive(ci, r)
		"forklift": forklift(ci, r)
		"hold_crane": hold_crane(ci, r)
		"xray_scanner": xray_scanner(ci, r)
		"mail_sorter": mail_sorter(ci, r)
		"tow_winch": tow_winch(ci, r)
		"spray_bar": spray_bar(ci, r)
		"microscope": microscope(ci, r)
		"co2_scrubber": co2_scrubber(ci, r)
		"uv_steriliser": uv_steriliser(ci, r)
		"humidifier": humidifier(ci, r)
		"ref_plant": ref_plant(ci, r)
		"evaporator": evaporator(ci, r)
		"safe_deposit": safe_deposit(ci, r)
		"gun_rack": gun_rack(ci, r)
		"biometric": biometric(ci, r)
		"separator_3ph": separator_3ph(ci, r)
		"level_radar": level_radar(ci, r)
		"coriolis": coriolis(ci, r)
		"imu": imu(ci, r)
		"arc_furnace": arc_furnace(ci, r)
		"ingot_rack": ingot_rack(ci, r)
		"eddy_sorter": eddy_sorter(ci, r)
		"mag_separator": mag_separator(ci, r)
		"scrubber": scrubber(ci, r)
		"car": car(ci, r)
		"deck_tractor": deck_tractor(ci, r)
		"apu": apu(ci, r)
		"escape_pod": escape_pod(ci, r)
		"ntr_core": ntr_core(ci, r)
		"control_drum": control_drum(ci, r)
		"shadow_shield": shadow_shield(ci, r)
		"flywheel_rotor": flywheel_rotor(ci, r)
		"launch_cradle": launch_cradle(ci, r)
		"tether_damper": tether_damper(ci, r)
		"hyd_clamp": hyd_clamp(ci, r)
		"piano": piano(ci, r)
		"wine_rack": wine_rack(ci, r)
		"bar": bar(ci, r)
		"crusher": crusher(ci, r)
		"rf_amp": rf_amp(ci, r)
		"aux_rocket": aux_rocket(ci, r)
		"gamma_probe": gamma_probe(ci, r)
		"pellet_feeder": pellet_feeder(ci, r)
		"steam_cyl": steam_cyl(ci, r)
		"fog_pump": fog_pump(ci, r)
		"comms_desk": comms_desk(ci, r)
		"fw_appliance": fw_appliance(ci, r)
		"rig_welder": rig_welder(ci, r)
		"e07_unit": e07_unit(ci, r)
		"shunt_reg": shunt_reg(ci, r)
		"gas_puff": gas_puff(ci, r)
		"ion_grid": ion_grid(ci, r)
		"rb_clock": rb_clock(ci, r)
		"daq_rail": daq_rail(ci, r)
		"ark_aux_pack": ark_aux_pack(ci, r)
		"battery_cart": battery_cart(ci, r)
		"emerg_light": emerg_light(ci, r)
		"ring_battery": ring_battery(ci, r)
		"shuttle_pack": shuttle_pack(ci, r)
		"vrla_rack": vrla_rack(ci, r)
		"main_battery": main_battery(ci, r)
		"drone_pack": drone_pack(ci, r)
		"courier_stack": courier_stack(ci, r)
		"lock_ups": lock_ups(ci, r)
		"pod_ups": pod_ups(ci, r)
		"race_pack": race_pack(ci, r)
		"standby_bank": standby_bank(ci, r)
		"ups_unit": ups_unit(ci, r)
		"brake_ctrl": brake_ctrl(ci, r)
		"dosing_skid": dosing_skid(ci, r)
		"material_rack": material_rack(ci, r)
		"food_bench": food_bench(ci, r)
		"tx_cabinet": tx_cabinet(ci, r)
		"turbine_ctrl": turbine_ctrl(ci, r)
		"bench_drill": bench_drill(ci, r)
		"tool_cart": tool_cart(ci, r)
		"pack_rack": pack_rack(ci, r)
		"dispatch_log": dispatch_log(ci, r)
		"bms_cab": bms_cab(ci, r)
		"cal_bench": cal_bench(ci, r)
		"survey_log": survey_log(ci, r)
		"crd_cab": crd_cab(ci, r)
		"crypto_rack": crypto_rack(ci, r)
		"hv_switchgear": hv_switchgear(ci, r)
		"gas_detector": gas_detector(ci, r)
		"herbarium": herbarium(ci, r)
		"garden_locker": garden_locker(ci, r)
		"chem_store": chem_store(ci, r)
		"core_store": core_store(ci, r)
		"drill_tools": drill_tools(ci, r)
		"well_logs": well_logs(ci, r)
		"ev_calib": ev_calib(ci, r)
		"dcdc": dcdc(ci, r)
		"cryo_cdb": cryo_cdb(ci, r)
		"cryo_spares": cryo_spares(ci, r)
		"shot_archive": shot_archive(ci, r)
		"spare_leads": spare_leads(ci, r)
		"sample_cyl": sample_cyl(ci, r)
		"ob_cal": ob_cal(ci, r)
		"plate_archive": plate_archive(ci, r)
		"spare_cells": spare_cells(ci, r)
		"server_spares": server_spares(ci, r)
		"batch_log": batch_log(ci, r)
		"shadow_board": shadow_board(ci, r)
		"cargo_log": cargo_log(ci, r)
		"custody_reg": custody_reg(ci, r)
		"evidence_lockers": evidence_lockers(ci, r)
		"flow_ctrl": flow_ctrl(ci, r)
		"mail_locker": mail_locker(ci, r)
		"manifest_term": manifest_term(ci, r)
		"pharmacy": pharmacy(ci, r)
		"sample_trays": sample_trays(ci, r)
		"seed_vault": seed_vault(ci, r)
		"smelt_log": smelt_log(ci, r)
		"cockpit_case": cockpit_case(ci, r)
		"supply_stack": supply_stack(ci, r)
		"svc_bench": svc_bench(ci, r)
		"dining_table": dining_table(ci, r)
		"tow_log": tow_log(ci, r)
		"bl_electrolyser": bl_electrolyser(ci, r)
		"fuel_cell_pm": fuel_cell_pm(ci, r)
		"stirling_gen": stirling_gen(ci, r)
		"turbine_genset": turbine_genset(ci, r)
		"drups": drups(ci, r)
		"co2_burner": co2_burner(ci, r)
		"diesel_genset": diesel_genset(ci, r)
		"rtg_module": rtg_module(ci, r)
		"main_alternator": main_alternator(ci, r)
		"ts_power": ts_power(ci, r)
		"apu_mono": apu_mono(ci, r)
		"s_bat": s_bat(ci, r)
		"lock_backup_box": lock_backup_box(ci, r)
		"charge_post": charge_post(ci, r)
		"bay_charger": bay_charger(ci, r)
		"tether_brake_frame": tether_brake_frame(ci, r)
		"wall_socket": wall_socket(ci, r)
		"lift_saddle": lift_saddle(ci, r)
		"tether_root": tether_root(ci, r)
		"tank_bracket": tank_bracket(ci, r)
		"small_manifold": small_manifold(ci, r)
		"busbar_box": busbar_box(ci, r)
		"irrigation_ctrl": irrigation_ctrl(ci, r)
		"lift_call": lift_call(ci, r)
		"standby_dist": standby_dist(ci, r)
		"room_panel": room_panel(ci, r)
		"rod_lock_panel": rod_lock_panel(ci, r)
		"uv_tube": uv_tube(ci, r)
		"leak_panel": leak_panel(ci, r)
		"brake_handle_panel": brake_handle_panel(ci, r)
		"slips_panel": slips_panel(ci, r)
		"esd_station": esd_station(ci, r)
		"solar_pcu": solar_pcu(ci, r)
		"shield_probe": shield_probe(ci, r)
		"push_fender": push_fender(ci, r)
		"frost_vent": frost_vent(ci, r)
		"freezer_ctrl": freezer_ctrl(ci, r)
		"cryo_ctrl_panel": cryo_ctrl_panel(ci, r)
		"cryo_manifold": cryo_manifold(ci, r)
		"level_gauge": level_gauge(ci, r)
		"process_panel": process_panel(ci, r)
		"cradle_ctrl": cradle_ctrl(ci, r)
		"engine_panel": engine_panel(ci, r)
		"monitor_wall": monitor_wall(ci, r)
		"baffle_heater": baffle_heater(ci, r)
		"quiet_pcu": quiet_pcu(ci, r)
		"control_strip": control_strip(ci, r)
		"purge_panel": purge_panel(ci, r)
		"pusher_plate": pusher_plate(ci, r)
		"fridge_ctl": fridge_ctl(ci, r)
		"hemt_bias": hemt_bias(ci, r)
		"rail_lock_board": rail_lock_board(ci, r)
		"rcs_ctrl": rcs_ctrl(ci, r)
		"recovery_valves": recovery_valves(ci, r)
		"release_board": release_board(ci, r)
		"cradle_lock": cradle_lock(ci, r)
		"flywheel_brake_panel": flywheel_brake_panel(ci, r)
		"rail_lock_square": rail_lock_square(ci, r)
		"release_cabinet": release_cabinet(ci, r)
		"race_ecu": race_ecu(ci, r)
		"hull_support": hull_support(ci, r)
		"tank_temp": tank_temp(ci, r)
		"tension_link": tension_link(ci, r)
		"vcb_panel": vcb_panel(ci, r)
		"arm_base": arm_base(ci, r)
		"bearing_ctrl": bearing_ctrl(ci, r)
		"brake_ctrl_box": brake_ctrl_box(ci, r)
		"coil_supply": coil_supply(ci, r)
		"dist_a": dist_a(ci, r)
		"dist_b": dist_b(ci, r)
		"vfd_cabinet": vfd_cabinet(ci, r)
		"junction_box": junction_box(ci, r)
		"furnace_ctrl": furnace_ctrl(ci, r)
		"magnet_psu": magnet_psu(ci, r)
		"quench_prot": quench_prot(ci, r)
		"lock_solenoid": lock_solenoid(ci, r)
		"lv_board": lv_board(ci, r)
		"main_dist": main_dist(ci, r)
		"mirror_ctrl": mirror_ctrl(ci, r)
		"rack_pdu": rack_pdu(ci, r)
		"panelboard":
			if p != null and p.art == "cap":
				dc_power_board(ci, r)
			else:
				panelboard(ci, r)
		"plc_cabinet": plc_cabinet(ci, r)
		"pump_mcc": pump_mcc(ci, r)
		"small_db": small_db(ci, r)
		"ship_swb": ship_swb(ci, r)
		"train_bus": train_bus(ci, r)
		"ts_busbox": ts_busbox(ci, r)
		"valve_box": valve_box(ci, r)
		"vault_ctrl": vault_ctrl(ci, r)
		"weapons_dist": weapons_dist(ci, r)
		"despin_drive": despin_drive(ci, r)
		"shuttle_engine": shuttle_engine(ci, r)
		"supercap_rack": supercap_rack(ci, r)
		"storage_can": storage_can(ci, r)
		"film_bank": film_bank(ci, r)
		"pulse_cap": pulse_cap(ci, r)
		"pfn_ladder": pfn_ladder(ci, r)
		"charge_supply": charge_supply(ci, r)
		"cdu_box": cdu_box(ci, r)
		"pyro_bolt": pyro_bolt(ci, r)
		"arm_cap_pack": arm_cap_pack(ci, r)
		"ignition_exciter": ignition_exciter(ci, r)
		"survey_probe": survey_probe(ci, r)
		"cap_board": cap_board(ci, r)
		"weapon_cap_rack": weapon_cap_rack(ci, r)
		"scroll_chiller": scroll_chiller(ci, r)
		"inline_fan": inline_fan(ci, r)
		"deck_exhaust_fan": deck_exhaust_fan(ci, r)
		"drug_cabinet":
			if p != null and p.art != "locker":
				pharmacy(ci, r)
			else:
				drug_cabinet(ci, r)
		"shale_shaker": shale_shaker(ci, r)
		"standpipe_riser": standpipe_riser(ci, r)
		"turbo_expander": turbo_expander(ci, r)
		"drum_composter": drum_composter(ci, r)
		"uv_chamber": uv_chamber(ci, r)
		"three_phase_sep": three_phase_sep(ci, r)
		"escape_capsule": escape_capsule(ci, r)
		"crusher_trommel": crusher_trommel(ci, r)
		"berth_pod": berth_pod(ci, r)
		"operating_table": operating_table(ci, r)
		"icu_bed": icu_bed(ci, r)
		"crew_berth": crew_berth(ci, r)
		"double_bunk": double_bunk(ci, r)
		"rest_capsules": rest_capsules(ci, r)
		"galley_counter": galley_counter(ci, r)
		"mess_serving_line": mess_serving_line(ci, r)
		"ship_galley": ship_galley(ci, r)
		"emergency_kit_locker": emergency_kit_locker(ci, r)
		"tier_locker": tier_locker(ci, r)
		"baggage_hold": baggage_hold(ci, r)
		"overhead_bins": overhead_bins(ci, r)
		"explosives_magazine": explosives_magazine(ci, r)
		"dc_gear_locker": dc_gear_locker(ci, r)
		"hose_reel_cabinet": hose_reel_cabinet(ci, r)
		"weapons_locker": weapons_locker(ci, r)
		"lashing_store": lashing_store(ci, r)
		"tool_locker": tool_locker(ci, r)
		"rotor_blade_rack": rotor_blade_rack(ci, r)
		"spill_station": spill_station(ci, r)
		"anaesthesia_machine": anaesthesia_machine(ci, r)
		"bedside_monitor": bedside_monitor(ci, r)
		"defibrillator": defibrillator(ci, r)
		"dose_probe_meter": dose_probe_meter(ci, r)
		"icu_ventilator":
			if p != null and p.art == "pump":
				E._draw_art(ci, p.art, r, p, font)
			else:
				icu_ventilator(ci, r)
		"grow_tray": grow_tray(ci, r)
		"nft_rack": nft_rack(ci, r)
		"raised_planter": raised_planter(ci, r)
		"aero_tower": aero_tower(ci, r)
		"culture_racks": culture_racks(ci, r)
		"framed_artwork": framed_artwork(ci, r)
		"fruit_tree": fruit_tree(ci, r)
		"soil_bed": soil_bed(ci, r)
		"seedling_racks": seedling_racks(ci, r)
		"task_chair": task_chair(ci, r)
		"copilot_seat": copilot_seat(ci, r)
		"pilot_bucket": pilot_bucket(ci, r)
		"bridge_chair": bridge_chair(ci, r)
		"passenger_seat": passenger_seat(ci, r)
		"wall_shelf": wall_shelf(ci, r)
		"drive_shelf": drive_shelf(ci, r)
		"core_box_rack": core_box_rack(ci, r)
		"sack_pallet": sack_pallet(ci, r)
		"rig_spares_rack": rig_spares_rack(ci, r)
		"bin_parts_rack": bin_parts_rack(ci, r)
		"water_dispenser":
			_liquid(ci, p, "water_dispenser", r)
			water_dispenser(ci, r)
		"eccs_tank":
			_liquid(ci, p, "eccs_tank", r)
			eccs_tank(ci, r)
		"sectional_tank":
			_liquid(ci, p, "sectional_tank", r)
			sectional_tank(ci, r)
		"ballast_tank":
			_liquid(ci, p, "ballast_tank", r)
			ballast_tank(ci, r)
		"bio_waste_tank":
			_liquid(ci, p, "bio_waste_tank", r)
			bio_waste_tank(ci, r)
		"fish_tank":
			_liquid(ci, p, "fish_tank", r)
			fish_tank(ci, r)
		"nutrient_mixer_tank":
			_liquid(ci, p, "nutrient_mixer_tank", r)
			nutrient_mixer_tank(ci, r)
		"wetland_pond":
			_liquid(ci, p, "wetland_pond", r)
			wetland_pond(ci, r)
		"water_recovery":
			_liquid(ci, p, "water_recovery", r)
			water_recovery(ci, r)
		"mud_agitator_tank":
			_liquid(ci, p, "mud_agitator_tank", r)
			mud_agitator_tank(ci, r)
		"hyd_reservoir":
			_liquid(ci, p, "hyd_reservoir", r)
			hyd_reservoir(ci, r)
		"sanitary_module": sanitary_module(ci, r)
		"coolant_bottle":
			_liquid(ci, p, "coolant_bottle", r)
			coolant_bottle(ci, r)
		"fresh_water_tank":
			_liquid(ci, p, "fresh_water_tank", r)
			fresh_water_tank(ci, r)
		"ahu_sections": ahu_sections(ci, r)
		"o2_generator_plant": o2_generator_plant(ci, r)
		"twin_bed_regen": twin_bed_regen(ci, r)
		"axial_air_machine": axial_air_machine(ci, r)
		"inrow_cooler": inrow_cooler(ci, r)
		"co2_canister_scrubber": co2_canister_scrubber(ci, r)
		"dehumidifier_unit": dehumidifier_unit(ci, r)
		"life_support_rack": life_support_rack(ci, r)
		"crah_downflow": crah_downflow(ci, r)
		"fume_hood": fume_hood(ci, r)
		"ecs_pack": ecs_pack(ci, r)
		"ecs_plantroom": ecs_plantroom(ci, r)
		"compact_ecu": compact_ecu(ci, r)
		"env_controller": env_controller(ci, r)
		"freeze_heater":
			if p != null and p.art != "env":
				E._draw_art(ci, p.art, r, p, font)
			else:
				freeze_heater(ci, r)
		"hvac_package": hvac_package(ci, r)
		"life_support_master": life_support_master(ci, r)
		"clean_air_supply": clean_air_supply(ci, r)
		"pod_circulator": pod_circulator(ci, r)
		"condensing_unit": condensing_unit(ci, r)
		"upright_freezer":
			if p != null and p.art == "fridge":
				two_door_fridge(ci, r)
			else:
				upright_freezer(ci, r)
		"ult_freezer": ult_freezer(ci, r)
		"lab_chiller": lab_chiller(ci, r)
		"sample_store": sample_store(ci, r)
		"vaccine_carrier": vaccine_carrier(ci, r)
		"lab_fridge": lab_fridge(ci, r)
		"o2_outlet_station": o2_outlet_station(ci, r)
		"emergency_o2_box": emergency_o2_box(ci, r)
		"feed_pump_ms": feed_pump_ms(ci, r)
		"lube_skid": lube_skid(ci, r)
		"inline_vpump": inline_vpump(ci, r)
		"circulator": circulator(ci, r)
		"bag_blower": bag_blower(ci, r)
		"ballast_primed": ballast_primed(ci, r)
		"belt_drive": belt_drive(ci, r)
		"diaphragm_pump": diaphragm_pump(ci, r)
		"irrigation_head": irrigation_head(ci, r)
		"brake_oil_cooler":
			if p != null and p.art == "pump":
				brake_oil_pack(ci, r)
			else:
				brake_oil_cooler(ci, r)
		"monobloc_pump": monobloc_pump(ci, r)
		"twin_head_pump": twin_head_pump(ci, r)
		"portable_dc_pump": portable_dc_pump(ci, r)
		"piston_compressor": piston_compressor(ci, r)
		"compact_hpu": compact_hpu(ci, r)
		"deluge_set": deluge_set(ci, r)
		"cryo_sump_pump": cryo_sump_pump(ci, r)
		"fuel_pump_xp": fuel_pump_xp(ci, r)
		"grease_station": grease_station(ci, r)
		"split_case_pump": split_case_pump(ci, r)
		"conveyor_drive": conveyor_drive(ci, r)
		"peristaltic_doser": peristaltic_doser(ci, r)
		"api_process_pump": api_process_pump(ci, r)
		"end_suction_pump": end_suction_pump(ci, r)
		"self_priming_pump": self_priming_pump(ci, r)
		"spa_pump_set": spa_pump_set(ci, r)
		"sump_submersible": sump_submersible(ci, r)
		"duty_standby_pumps": duty_standby_pumps(ci, r)
		"tank_lineshaft": tank_lineshaft(ci, r)
		"gear_transfer": gear_transfer(ci, r)
		"mini_mag_pump": mini_mag_pump(ci, r)
		"actuated_vent":
			if p != null and p.art != "pump":
				E._draw_art(ci, p.art, r, p, font)
			else:
				actuated_vent(ci, r)
		"booster_set": booster_set(ci, r)
		"racing_fin": racing_fin(ci, r)
		"ice_heat_pad": ice_heat_pad(ci, r)
		"radiator_panel": radiator_panel(ci, r)
		"radiator_wing": radiator_wing(ci, r)
		"petal_radiator": petal_radiator(ci, r)
		"osr_plate": osr_plate(ci, r)
		"stirling_cooler": stirling_cooler(ci, r)
		"battery_cold_plate": battery_cold_plate(ci, r)
		"thermal_stack": thermal_stack(ci, r)
		"weapon_cooler": weapon_cooler(ci, r)
		"ark_turbine": ark_turbine(ci, r)
		"core_switch": core_switch(ci, r)
		"poorboy_degasser": poorboy_degasser(ci, r)
		"motor_pump_set": motor_pump_set(ci, r)
		"cross_manifold": cross_manifold(ci, r)
		"precision_manifold": precision_manifold(ci, r)
		"tow_valve_block": tow_valve_block(ci, r)
		"ark_main_board": ark_main_board(ci, r)
		"ark_hub_dist": ark_hub_dist(ci, r)
		"ark_local_dist": ark_local_dist(ci, r)
		"ark_ring_dist": ark_ring_dist(ci, r)
		"cartridge_filter": cartridge_filter(ci, r)
		"fibre_oxygenator": fibre_oxygenator(ci, r)
		"decon_booth":
			if p != null and p.art == "env":
				decon_line(ci, r)
			elif p != null and p.art != "filter":
				E._draw_art(ci, p.art, r, p, font)
			else:
				decon_booth(ci, r)
		"baghouse":
			if p != null and p.art != "filter":
				E._draw_art(ci, p.art, r, p, font)
			else:
				baghouse(ci, r)
		"he_purifier": he_purifier(ci, r)
		"filter_bank3": filter_bank3(ci, r)
		"bibo_filter": bibo_filter(ci, r)
		"fan_filter_unit": fan_filter_unit(ci, r)
		"duplex_strainer":
			if p != null and p.art == "pump":
				auto_strainer(ci, r)
			elif p != null and p.art != "filter":
				E._draw_art(ci, p.art, r, p, font)
			else:
				duplex_strainer(ci, r)
		"water_treat_skid":
			if p != null and p.art == "water":
				ro_rack(ci, r)
			elif p != null and p.art != "filter":
				E._draw_art(ci, p.art, r, p, font)
			else:
				water_treat_skid(ci, r)
		"door_hpu": door_hpu(ci, r)
		"main_hpu": main_hpu(ci, r)
		"main_valve_pair": main_valve_pair(ci, r)
		"sprinkler_line": sprinkler_line(ci, r)
		"water_main": water_main(ci, r)
		"rack_coolant_manifold": rack_coolant_manifold(ci, r)
		"mud_line": mud_line(ci, r)
		"he_tube_pair": he_tube_pair(ci, r)
		"braided_hose": braided_hose(ci, r)
		"fuel_main_dw": fuel_main_dw(ci, r)
		"vj_cryo_line": vj_cryo_line(ci, r)
		"riser_pipe": riser_pipe(ci, r)
		"rack_post": rack_post(ci, r)
		"piston_accumulator":
			_liquid(ci, p, "piston_accumulator", r)
			piston_accumulator(ci, r)
		"argon_bundle": argon_bundle(ci, r)
		"n2_cart": n2_cart(ci, r)
		"n2_vessel": n2_vessel(ci, r)
		"o2_vessel": o2_vessel(ci, r)
		"copv_buffer": copv_buffer(ci, r)
		"xenon_tank": xenon_tank(ci, r)
		"ba_fill_bank": ba_fill_bank(ci, r)
		"o2_dryer_store": o2_dryer_store(ci, r)
		"air_compressor_tank":
			if p != null and p.art == "pump":
				screw_compressor(ci, r)
			elif p != null and p.art != "gastank":
				E._draw_art(ci, p.art, r, p, font)
			else:
				air_compressor_tank(ci, r)
		"coolant_tank":
			_liquid(ci, p, "coolant_tank", r)
			coolant_tank(ci, r)
		"bladder_accumulator": bladder_accumulator(ci, r)
		"air_receiver": air_receiver(ci, r)
		"bottle_chained": bottle_chained(ci, r)
		"expansion_tank":
			_liquid(ci, p, "expansion_tank", r)
			expansion_tank(ci, r)
		"he_buffer_skirt": he_buffer_skirt(ci, r)
		"slim_bottle": slim_bottle(ci, r)
		"h2_type4":
			if p != null and p.art != "gastank":
				E._draw_art(ci, p.art, r, p, font)
			else:
				h2_type4(ci, r)
		"halon_bank": halon_bank(ci, r)
		"lift_accu_bank": lift_accu_bank(ci, r)
		"lube_box_tank":
			if p != null and p.art != "gastank":
				E._draw_art(ci, p.art, r, p, font)
			else:
				_liquid(ci, p, "lube_box_tank", r)
				lube_box_tank(ci, r)
		"medgas_bank": medgas_bank(ci, r)
		"n2_purge_tube": n2_purge_tube(ci, r)
		"n2_header_bank":
			if p != null and p.art == "pipe":
				n2_header_pipe(ci, r)
			elif p != null and p.art != "gastank":
				E._draw_art(ci, p.art, r, p, font)
			else:
				n2_header_bank(ci, r)
		"o2_steel_bottle":
			if p != null and p.art != "gastank":
				E._draw_art(ci, p.art, r, p, font)
			else:
				o2_steel_bottle(ci, r)
		"o2_bottle_pair": o2_bottle_pair(ci, r)
		"o2_cryo_tank": o2_cryo_tank(ci, r)
		"o2_flow_bottle": o2_flow_bottle(ci, r)
		"pressurant_pair": pressurant_pair(ci, r)
		"qc_he_buffer": qc_he_buffer(ci, r)
		"mix_tank_cage": mix_tank_cage(ci, r)
		"ref_receiver":
			_liquid(ci, p, "ref_receiver", r)
			ref_receiver(ci, r)
		"n2o_tank":
			_liquid(ci, p, "n2o_tank", r)
			n2o_tank(ci, r)
		"reagent_bottle": reagent_bottle(ci, r)
		"weld_bottle": weld_bottle(ci, r)
		"heat_pump_set": heat_pump_set(ci, r)
		"choke_skid": choke_skid(ci, r)
		"gm_cold_head": gm_cold_head(ci, r)
		"reliq_coldbox": reliq_coldbox(ci, r)
		"surface_condenser": surface_condenser(ci, r)
		"vacuum_degasser": vacuum_degasser(ci, r)
		"vbank_cooler": vbank_cooler(ci, r)
		"plug_nozzle": plug_nozzle(ci, r)
		"ablative_nozzle": ablative_nozzle(ci, r)
		"regen_nozzle": regen_nozzle(ci, r)
		"thrust_nozzle": thrust_nozzle(ci, r)
		"vent_stack": vent_stack(ci, r)
		"cold_gas_pair": cold_gas_pair(ci, r)
		"rcs_pod": rcs_pod(ci, r)
		"mono_cluster": mono_cluster(ci, r)
		"he_dewar": he_dewar(ci, r)
		"zero_g_spa": zero_g_spa(ci, r)
		"steam_drum": steam_drum(ci, r)
		"clamp_actuator": clamp_actuator(ci, r)
		"mirror_actuator": mirror_actuator(ci, r)
		"bop_stack": bop_stack(ci, r)
		"intake_axial": intake_axial(ci, r)
		"ob_reaction_wheel": ob_reaction_wheel(ci, r)
		"spray_line": spray_line(ci, r)
		"tether_dashpot": tether_dashpot(ci, r)
		"spare_engine": spare_engine(ci, r)
		"engine_cluster": engine_cluster(ci, r)
		"main_engine": main_engine(ci, r)
		"big_engine": big_engine(ci, r)
		"engine_pod": engine_pod(ci, r)
		"tug_engine": tug_engine(ci, r)
		"hl_motor": hl_motor(ci, r)
		"gg_engine": gg_engine(ci, r)
		"power_tail": power_tail(ci, r)
		"vib_drive": vib_drive(ci, r)
		"engine_front": engine_front(ci, r)
		"small_thruster": small_thruster(ci, r)
		"courier_engine": courier_engine(ci, r)


# ================================================================== DR-150 Derrick

# a top drive: the bails up to the travelling block, the gooseneck and wash pipe
# the mud comes in through, two drive motors on top of the gearbox, the main shaft
# with its two IBOP valves, the pipe handler (link-tilt arms, elevator) below, the
# guide dolly riding the derrick rail
static func top_drive(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.55
	# bails
	L(ci, Vector2(cx - w * 0.12, 0), Vector2(cx - w * 0.2, h * 0.18), 0.5, 1.4)
	L(ci, Vector2(cx + w * 0.12, 0), Vector2(cx + w * 0.2, h * 0.18), 0.5, 1.4)
	# motors with their fins
	for k in 2:
		var m := Rect2(cx - w * 0.3 + k * w * 0.32, h * 0.08, w * 0.26, h * 0.26)
		R(ci, m, 0.55)
		hatch(ci, E.inset(m, 2.0), 3.0, true, 0.22, 12)
		R(ci, Rect2(m.position.x + m.size.x * 0.3, m.position.y - h * 0.04, m.size.x * 0.4, h * 0.04), 0.45)
	# gooseneck and wash pipe
	P(ci, PackedVector2Array([Vector2(w * 0.04, h * 0.05), Vector2(w * 0.12, h * 0.02), Vector2(w * 0.2, h * 0.08), Vector2(w * 0.2, h * 0.36)]), 0.5, 1.4)
	L(ci, Vector2(w * 0.2, h * 0.36), Vector2(cx - w * 0.1, h * 0.36), 0.45)
	# gearbox
	var gb := Rect2(cx - w * 0.34, h * 0.34, w * 0.68, h * 0.2)
	R(ci, gb, 0.6, 1.2)
	O(ci, gb.get_center(), gb.size.y * 0.32, 0.45)
	O(ci, gb.get_center() + Vector2(-gb.size.x * 0.28, 0), gb.size.y * 0.2, 0.4)
	O(ci, gb.get_center() + Vector2(gb.size.x * 0.28, 0), gb.size.y * 0.2, 0.4)
	# shaft, IBOPs, saver sub
	L(ci, Vector2(cx - 2.0, gb.end.y), Vector2(cx - 2.0, h * 0.82), 0.55)
	L(ci, Vector2(cx + 2.0, gb.end.y), Vector2(cx + 2.0, h * 0.82), 0.55)
	for f in [0.6, 0.68]:
		R(ci, Rect2(cx - 4.0, h * f, 8.0, h * 0.05), 0.55)
		L(ci, Vector2(cx + 4.0, h * f + h * 0.025), Vector2(cx + 8.0, h * f + h * 0.025), 0.45)
	# pipe handler: link-tilt arms down to the elevator
	for s in [-1.0, 1.0]:
		L(ci, Vector2(cx + s * w * 0.14, gb.end.y), Vector2(cx + s * w * 0.18, h * 0.88), 0.45)
	var el := Rect2(cx - w * 0.2, h * 0.88, w * 0.4, h * 0.1)
	R(ci, el, 0.55)
	L(ci, Vector2(cx, el.position.y), Vector2(cx, el.end.y), 0.4)
	# guide dolly on the rail (left)
	var dl := Rect2(0, h * 0.3, w * 0.12, h * 0.4)
	R(ci, dl, 0.5)
	for f in [0.38, 0.62]:
		O(ci, Vector2(w * 0.06, h * f), minf(w * 0.04, 3.0), 0.5)
	L(ci, Vector2(dl.end.x, h * 0.44), Vector2(gb.position.x, h * 0.44), 0.45, 1.4)


# drawworks: the grooved drum between its flanges, the drill line spooled on it
# and running up to the crown, the disc brake with its calipers, the AC motor and
# gearbox driving it, the skid
static func drawworks(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var base_y: float = h * 0.92
	L(ci, Vector2(2, base_y), Vector2(w - 2, base_y), 0.55, 1.6)
	E.hatch(ci, Rect2(4, base_y + 1.0, w - 8, h - base_y - 2.0), 6.0, true, 0.2, 30)
	var dr: float = minf(h * 0.36, w * 0.24)
	var c := Vector2(w * 0.36, base_y - dr - h * 0.06)
	# brake disc behind the drum, calipers gripping its rim
	O(ci, c, dr * 1.12, 0.45)
	for a in [-PI * 0.5, -PI * 0.15]:
		var q: Vector2 = c + Vector2.from_angle(a) * dr * 1.12
		R(ci, Rect2(q - Vector2(4, 4), Vector2(8, 8)), 0.6)
	# the drum: flanges, grooves, wraps of line
	O(ci, c, dr, 0.6, 1.2)
	O(ci, c, dr * 0.62, 0.5)
	for k in 4:
		O(ci, c, dr * (0.68 + k * 0.07), 0.22)
	O(ci, c, dr * 0.14, 0.55)
	# the fast line leaving the top of the drum up to the crown
	L(ci, c + Vector2(dr * 0.2, -dr * 0.88), Vector2(w * 0.7, 0), 0.5, 1.4)
	# drum stand
	L(ci, c + Vector2(-dr * 0.5, dr * 0.85), Vector2(c.x - dr * 0.9, base_y), 0.45, 1.4)
	L(ci, c + Vector2(dr * 0.5, dr * 0.85), Vector2(c.x + dr * 0.9, base_y), 0.45, 1.4)
	# gearbox and motor
	var gb := Rect2(c.x + dr * 1.2, base_y - h * 0.42, w * 0.14, h * 0.4)
	R(ci, gb, 0.5)
	O(ci, gb.get_center(), gb.size.x * 0.3, 0.4)
	E.motor(ci, Rect2(gb.end.x, base_y - h * 0.4, w - gb.end.x - 4.0, h * 0.34), true, 0.5)


# the crown block: the row of sheaves on their shaft in the frame, the bumper
# timbers above, the line reeved over them
static func crown_block(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h * 0.16), 0.55)
	E.hatch(ci, Rect2(3, 2, w - 6, h * 0.14), 4.0, true, 0.2, 40)
	var n := clampi(int(w / maxf(h * 0.75, 10.0)), 2, 8)
	var sw: float = w / n
	var sr: float = minf(sw * 0.42, h * 0.36)
	for i in n:
		var c := Vector2((i + 0.5) * sw, h * 0.58)
		O(ci, c, sr, 0.55, 1.2)
		O(ci, c, sr * 0.82, 0.3)
		D(ci, c, 1.3, 0.6)
		L(ci, c + Vector2(-sr, 0), Vector2(c.x - sr, h), 0.35)
		L(ci, c + Vector2(sr, 0), Vector2(c.x + sr, h), 0.35)
	L(ci, Vector2(sw * 0.5, h * 0.58), Vector2(w - sw * 0.5, h * 0.58), 0.4)
	for x in [2.0, w - 2.0]:
		L(ci, Vector2(x, h * 0.16), Vector2(x, h - 1.0), 0.5, 1.4)


# the travelling block: the becket, cheek plates round the sheaves, the line
# running down and up over them, the bail at its foot
static func travel_block(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	var sr: float = minf(w * 0.38, h * 0.16)
	var body := PackedVector2Array([Vector2(cx - sr * 1.2, h * 0.12), Vector2(cx + sr * 1.2, h * 0.12), Vector2(cx + sr * 1.25, h * 0.62), Vector2(cx + sr * 0.6, h * 0.76), Vector2(cx - sr * 0.6, h * 0.76), Vector2(cx - sr * 1.25, h * 0.62), Vector2(cx - sr * 1.2, h * 0.12)])
	P(ci, body, 0.6, 1.2)
	for k in 2:
		var c := Vector2(cx, h * (0.26 + k * 0.22))
		O(ci, c, sr, 0.5)
		O(ci, c, sr * 0.78, 0.25)
		D(ci, c, 1.3, 0.6)
	# lines in and out of the top
	for s in [-0.7, -0.25, 0.25, 0.7]:
		L(ci, Vector2(cx + s * sr, 0), Vector2(cx + s * sr, h * 0.12), 0.4)
	# the bail and its clevis
	A(ci, Vector2(cx, h * 0.84), sr * 0.7, 0.0, PI, 0.55, 1.6)
	L(ci, Vector2(cx - sr * 0.7, h * 0.84), Vector2(cx - sr * 0.7, h * 0.76), 0.5, 1.4)
	L(ci, Vector2(cx + sr * 0.7, h * 0.84), Vector2(cx + sr * 0.7, h * 0.76), 0.5, 1.4)
	R(ci, Rect2(cx - sr * 0.3, h * 0.94, sr * 0.6, h * 0.05), 0.55)


# the rotary table set in the drill floor: its housing, the turntable with its
# ring gear, the master bushing round the string's bore, the drive pinion
static func rotary_table(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * (49.6 + 0.4 - 48.6) / 2.8
	var bore: float = w * 0.8 / 2.8 * 0.5 + 1.0
	R(ci, Rect2(w * 0.04, h * 0.2, w * 0.92, h * 0.7), 0.5)
	# turntable top and its ring gear
	L(ci, Vector2(cx - w * 0.36, h * 0.2), Vector2(cx + w * 0.36, h * 0.2), 0.65, 1.8)
	E.hatch(ci, Rect2(cx - w * 0.34, h * 0.32, w * 0.68, h * 0.22), 3.0, true, 0.3, 80)
	# master bushing round the bore, and the bore itself
	R(ci, Rect2(cx - bore - w * 0.06, h * 0.12, w * 0.12 + bore * 2.0, h * 0.4), 0.55)
	L(ci, Vector2(cx - bore, 0), Vector2(cx - bore, h), 0.45)
	L(ci, Vector2(cx + bore, 0), Vector2(cx + bore, h), 0.45)
	# drive pinion and its shaft out to the side
	O(ci, Vector2(w * 0.88, h * 0.55), h * 0.18, 0.5)
	L(ci, Vector2(w * 0.88, h * 0.55), Vector2(w - 1.0, h * 0.55), 0.5, 1.4)
	for x in [w * 0.12, w * 0.7]:
		D(ci, Vector2(x, h * 0.75), 1.1, 0.5)


# a stand of drill pipe: three joints, their tool joints (box above, pin below)
# with the hardbanding round them
static func drillpipe(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h >= w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var segs := PackedVector2Array()
	segs.append(X.call(0.0, th * 0.3))
	segs.append(X.call(ln, th * 0.3))
	segs.append(X.call(0.0, th * 0.7))
	segs.append(X.call(ln, th * 0.7))
	S(ci, segs, 0.55)
	var tj: float = minf(th * 0.5, ln * 0.06)
	for k in 4:
		var u: float = ln * k / 3.0
		var u0: float = clampf(u - tj * 0.5, 0.0, ln - tj)
		R(ci, Rect2(X.call(u0, th * 0.12), X.call(u0 + tj, th * 0.88) - X.call(u0, th * 0.12)).abs(), 0.6)
		L(ci, X.call(u0 + tj * 0.3, th * 0.12), X.call(u0 + tj * 0.3, th * 0.88), 0.3)
		L(ci, X.call(u0 + tj * 0.7, th * 0.12), X.call(u0 + tj * 0.7, th * 0.88), 0.3)
		if k > 0 and k < 3:
			L(ci, X.call(u0 - tj * 0.3, th * 0.3), X.call(u0, th * 0.12), 0.4)
			L(ci, X.call(u0 - tj * 0.3, th * 0.7), X.call(u0, th * 0.88), 0.4)
	L(ci, X.call(0.0, th * 0.5), X.call(ln, th * 0.5), 0.12)


# the bottom-hole assembly: drill collars, a stabiliser with its spiral blades,
# the MWD tool, the core barrel and at its foot the core bit
static func bha(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	var cw: float = w * 0.32
	L(ci, Vector2(cx - cw, 0), Vector2(cx - cw, h * 0.86), 0.6)
	L(ci, Vector2(cx + cw, 0), Vector2(cx + cw, h * 0.86), 0.6)
	# collar connections
	for f in [0.18, 0.36]:
		L(ci, Vector2(cx - cw, h * f), Vector2(cx + cw, h * f), 0.45)
	# MWD tool: its window and pulser
	E.R(ci, Rect2(cx - cw * 0.5, h * 0.04, cw, h * 0.1), 0.45)
	D(ci, Vector2(cx, h * 0.09), 1.2, 0.6)
	# stabiliser: wider, spiral blades
	var st := Rect2(cx - w * 0.46, h * 0.42, w * 0.92, h * 0.14)
	R(ci, st, 0.55)
	var segs := PackedVector2Array()
	for k in 3:
		var x0: float = st.position.x + st.size.x * (0.1 + k * 0.3)
		segs.append(Vector2(x0, st.position.y + 1.0))
		segs.append(Vector2(x0 + st.size.x * 0.22, st.end.y - 1.0))
	S(ci, segs, 0.45)
	# core barrel (inner tube shown)
	L(ci, Vector2(cx - cw * 0.45, h * 0.58), Vector2(cx - cw * 0.45, h * 0.86), 0.3)
	L(ci, Vector2(cx + cw * 0.45, h * 0.58), Vector2(cx + cw * 0.45, h * 0.86), 0.3)
	# core bit: the crown with its cutters, the throat for the core
	P(ci, PackedVector2Array([Vector2(cx - cw, h * 0.86), Vector2(cx - cw * 1.15, h * 0.92), Vector2(cx - cw * 0.9, h * 0.99), Vector2(cx - cw * 0.35, h * 0.99), Vector2(cx - cw * 0.35, h * 0.9)]), 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(cx + cw, h * 0.86), Vector2(cx + cw * 1.15, h * 0.92), Vector2(cx + cw * 0.9, h * 0.99), Vector2(cx + cw * 0.35, h * 0.99), Vector2(cx + cw * 0.35, h * 0.9)]), 0.6, 1.2)
	for k in 4:
		D(ci, Vector2(cx + (-0.85 + k * 0.55) * cw if k < 2 else cx + (0.35 + (k - 2) * 0.5) * cw, h * 0.98), 1.0, 0.7)


# a triplex mud pump side-on: the power end (crankcase, the bull gear and its
# pinion), the three crosshead extension rods, the fluid end with its three valve
# covers, the pulsation dampener on the discharge, the suction manifold below,
# the drive motor on top with its belt guard
static func mud_pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var base_y: float = h * 0.94
	L(ci, Vector2(2, base_y), Vector2(w - 2, base_y), 0.55, 1.6)
	# power end
	var pe := Rect2(w * 0.5, h * 0.38, w * 0.46, base_y - h * 0.38)
	R(ci, pe, 0.6, 1.2)
	var bg := Vector2(pe.position.x + pe.size.x * 0.58, pe.position.y + pe.size.y * 0.5)
	var br: float = minf(pe.size.x, pe.size.y) * 0.36
	O(ci, bg, br, 0.5)
	O(ci, bg, br * 0.86, 0.22)
	D(ci, bg, 1.4, 0.6)
	O(ci, bg + Vector2(-br * 1.0, -br * 0.65), br * 0.28, 0.45)
	# rods
	var segs := PackedVector2Array()
	for k in 3:
		var y: float = pe.position.y + pe.size.y * (0.25 + k * 0.25)
		segs.append(Vector2(w * 0.3, y))
		segs.append(Vector2(pe.position.x, y))
	S(ci, segs, 0.5, 1.4)
	# fluid end: block, three valve covers on top, discharge manifold, dampener
	var fe := Rect2(w * 0.06, h * 0.42, w * 0.26, base_y - h * 0.46)
	R(ci, fe, 0.6, 1.2)
	for k in 3:
		var y: float = pe.position.y + pe.size.y * (0.25 + k * 0.25)
		R(ci, Rect2(fe.end.x - 3.0, y - 3.0, 6.0, 6.0), 0.5)
	L(ci, Vector2(fe.position.x, h * 0.38), Vector2(fe.end.x, h * 0.38), 0.55, 1.6)
	for k in 3:
		var x: float = fe.position.x + fe.size.x * (0.2 + k * 0.3)
		L(ci, Vector2(x, h * 0.38), Vector2(x, fe.position.y), 0.45)
	var dc := Vector2(fe.position.x + fe.size.x * 0.5, h * 0.22)
	O(ci, dc, minf(w * 0.08, h * 0.1), 0.55, 1.2)
	L(ci, dc + Vector2(0, minf(w * 0.08, h * 0.1)), Vector2(dc.x, h * 0.38), 0.5, 1.4)
	L(ci, Vector2(fe.position.x, h * 0.38), Vector2(1, h * 0.38), 0.5)
	# suction manifold below the fluid end
	L(ci, Vector2(1, base_y - h * 0.06), Vector2(fe.end.x, base_y - h * 0.06), 0.45)
	# the motor on top with its belt guard down to the pinion
	E.motor(ci, Rect2(w * 0.52, h * 0.06, w * 0.42, h * 0.22), false, 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.9, h * 0.17), Vector2(w * 0.98, h * 0.2), Vector2(bg.x - br * 0.6 + br * 0.6, pe.position.y + 1.0)]), 0.35)


# a shale shaker: the basket on its springs, tilted, with its screen panels; the
# two vibrator motors on the basket, the feeder at the back, the discharge lip
# and the underflow tray beneath
static func shaker(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b0 := Vector2(w * 0.18, h * 0.4)
	var b1 := Vector2(w * 0.96, h * 0.3)
	P(ci, PackedVector2Array([b0, b1, b1 + Vector2(0, h * 0.2), b0 + Vector2(0, h * 0.22), b0]), 0.6, 1.2)
	# screens: zigzag panels along the deck
	var n := clampi(int(w / 14.0), 3, 8)
	for k in n:
		var a: Vector2 = b0.lerp(b1, float(k) / n) + Vector2(0, h * 0.04)
		var b: Vector2 = b0.lerp(b1, float(k + 1) / n) + Vector2(0, h * 0.04)
		var pts := PackedVector2Array()
		for e in 7:
			pts.append(a.lerp(b, e / 6.0) + Vector2(0, (1.5 if e % 2 == 0 else -1.5)))
		P(ci, pts, 0.35)
	# vibrators
	for f in [0.4, 0.72]:
		var q: Vector2 = b0.lerp(b1, f) + Vector2(0, -h * 0.1)
		O(ci, q, minf(w * 0.06, h * 0.08), 0.55)
		L(ci, q + Vector2(0, minf(w * 0.06, h * 0.08)), b0.lerp(b1, f), 0.45)
	# feeder (possum belly) at the back
	P(ci, PackedVector2Array([Vector2(2, h * 0.2), Vector2(w * 0.18, h * 0.2), Vector2(w * 0.18, h * 0.55), Vector2(w * 0.06, h * 0.55), Vector2(2, h * 0.4), Vector2(2, h * 0.2)]), 0.5)
	L(ci, Vector2(w * 0.04, 0), Vector2(w * 0.04, h * 0.2), 0.45, 1.4)
	# springs
	for f in [0.25, 0.85]:
		var q: Vector2 = b0.lerp(b1, f) + Vector2(0, h * 0.22)
		var pts := PackedVector2Array()
		for e in 6:
			pts.append(q + Vector2(2.5 if e % 2 == 0 else -2.5, e * h * 0.03))
		P(ci, pts, 0.45)
	# underflow tray and the frame
	P(ci, PackedVector2Array([Vector2(w * 0.14, h * 0.7), Vector2(w * 0.2, h * 0.92), Vector2(w * 0.9, h * 0.92), Vector2(w * 0.98, h * 0.7)]), 0.5)
	L(ci, Vector2(w * 0.5, h * 0.92), Vector2(w * 0.5, h), 0.45)
	L(ci, b1 + Vector2(0, h * 0.1), b1 + Vector2(w * 0.04, h * 0.18), 0.4)


# hydrocyclones (desander): the cones standing on the feed manifold's branches,
# their vortex finders up into the overflow header, the apexes over the trough
static func hydrocyclone(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / (h * 0.32)), 1, 6)
	var cw: float = w / n
	L(ci, Vector2(2, h * 0.08), Vector2(w - 2, h * 0.08), 0.55, 1.6)
	L(ci, Vector2(2, h * 0.24), Vector2(w - 2, h * 0.24), 0.5, 1.4)
	for i in n:
		var cx: float = (i + 0.5) * cw
		var rr: float = cw * 0.32
		R(ci, Rect2(cx - rr, h * 0.28, rr * 2.0, h * 0.12), 0.55)
		P(ci, PackedVector2Array([Vector2(cx - rr, h * 0.4), Vector2(cx - rr * 0.18, h * 0.84), Vector2(cx + rr * 0.18, h * 0.84), Vector2(cx + rr, h * 0.4)]), 0.55)
		L(ci, Vector2(cx, h * 0.08), Vector2(cx, h * 0.34), 0.45)
		L(ci, Vector2(cx - rr, h * 0.33), Vector2(cx - rr * 1.6, h * 0.24), 0.45)
		L(ci, Vector2(cx - rr * 0.1, h * 0.86), Vector2(cx - rr * 0.1, h * 0.9), 0.5)
	P(ci, PackedVector2Array([Vector2(2, h * 0.88), Vector2(w * 0.06, h * 0.98), Vector2(w * 0.94, h * 0.98), Vector2(w - 2, h * 0.88)]), 0.5)


# a vacuum degasser: the vessel with its inclined baffle plates the mud thins out
# over, the vacuum pump and its gas line, the jet discharge at the foot
static func degasser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.08, h * 0.04, w * 0.58, h * 0.82)
	var sh := E.vessel_v(ci, vs, 0.55)
	var n := clampi(int(sh.size.y / 9.0), 2, 8)
	for k in n:
		var y: float = sh.position.y + (k + 0.6) * sh.size.y / (n + 0.4)
		if k % 2 == 0:
			L(ci, Vector2(sh.position.x + 1.0, y), Vector2(sh.end.x - sh.size.x * 0.25, y + sh.size.y * 0.06), 0.4)
		else:
			L(ci, Vector2(sh.end.x - 1.0, y), Vector2(sh.position.x + sh.size.x * 0.25, y + sh.size.y * 0.06), 0.4)
	var pc := Vector2(w * 0.84, h * 0.3)
	E.volute(ci, pc, minf(w * 0.13, h * 0.1), true, 0.5)
	L(ci, Vector2(vs.end.x, vs.position.y + vs.size.y * 0.1), pc + Vector2(-minf(w * 0.13, h * 0.1), 0), 0.4)
	R(ci, Rect2(w * 0.72, h * 0.46, w * 0.24, h * 0.18), 0.45)
	L(ci, Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, h - 1.0), 0.5, 1.4)
	L(ci, Vector2(vs.get_center().x, h - 2.0), Vector2(w - 1.0, h - 2.0), 0.45)


# a decanter centrifuge on its skid: the bowl (cylinder into cone), the scroll
# flights inside it, the gearbox on one end, the feed tube in the other, the main
# motor below driving it by belts, the solids and liquid discharge chutes
static func decanter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.34
	var br: float = minf(h * 0.16, w * 0.14)
	var x0: float = w * 0.14
	var x1: float = w * 0.62
	var x2: float = w * 0.88
	P(ci, PackedVector2Array([Vector2(x0, ay - br), Vector2(x1, ay - br), Vector2(x2, ay - br * 0.45), Vector2(x2, ay + br * 0.45), Vector2(x1, ay + br), Vector2(x0, ay + br), Vector2(x0, ay - br)]), 0.6, 1.2)
	var segs := PackedVector2Array()
	var nf := clampi(int((x2 - x0) / 6.0), 3, 24)
	for k in nf:
		var x: float = x0 + 2.0 + k * (x2 - x0 - 4.0) / nf
		var rr: float = br * (1.0 if x < x1 else lerpf(1.0, 0.45, (x - x1) / (x2 - x1))) * 0.85
		segs.append(Vector2(x, ay - rr))
		segs.append(Vector2(x + 4.0, ay + rr))
	S(ci, segs, 0.3)
	L(ci, Vector2(x0, ay), Vector2(x2 + w * 0.08, ay), 0.3)
	# gearbox end and feed end
	R(ci, Rect2(w * 0.02, ay - br * 0.8, x0 - w * 0.02, br * 1.6), 0.55)
	O(ci, Vector2(w * 0.08, ay), br * 0.45, 0.45)
	L(ci, Vector2(x2, ay), Vector2(w - 1.0, ay), 0.5, 1.4)
	# the cover over it all and the chutes
	P(ci, PackedVector2Array([Vector2(x0 - 2.0, ay + br + 3.0), Vector2(x0 - 2.0, ay - br - 4.0), Vector2(x2 + 2.0, ay - br - 4.0), Vector2(x2 + 2.0, ay + br + 3.0)]), 0.35)
	L(ci, Vector2(x2 - 4.0, ay + br * 0.6), Vector2(x2 - 8.0, h * 0.62), 0.45)
	L(ci, Vector2(x0 + 6.0, ay + br), Vector2(x0 + 2.0, h * 0.62), 0.45)
	# skid, motor below, belts
	L(ci, Vector2(2, h * 0.62), Vector2(w - 2, h * 0.62), 0.5, 1.4)
	E.motor(ci, Rect2(w * 0.3, h * 0.66, w * 0.5, h * 0.24), false, 0.5)
	L(ci, Vector2(w * 0.08, ay + br * 0.45), Vector2(w * 0.26, h * 0.7), 0.35)
	L(ci, Vector2(w * 0.08, ay - br * 0.2), Vector2(w * 0.3, h * 0.82), 0.35)
	L(ci, Vector2(2, h * 0.97), Vector2(w - 2, h * 0.97), 0.5, 1.4)


# a mud-gas separator ("poor boy"): the tall vessel with its staggered baffle
# plates, the inlet on the side, the vent line up out of the top, the U-tube mud
# leg out of the bottom
static func gas_buster(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.24, h * 0.1, w * 0.46, h * 0.72)
	var sh := E.vessel_v(ci, vs, 0.6)
	var n := clampi(int(sh.size.y / 8.0), 3, 10)
	for k in n:
		var y: float = sh.position.y + sh.size.y * (0.2 + 0.7 * k / n)
		if k % 2 == 0:
			L(ci, Vector2(sh.position.x + 1.0, y), Vector2(sh.end.x - sh.size.x * 0.3, y), 0.4)
		else:
			L(ci, Vector2(sh.end.x - 1.0, y), Vector2(sh.position.x + sh.size.x * 0.3, y), 0.4)
	L(ci, Vector2(1, sh.position.y + sh.size.y * 0.15), Vector2(vs.position.x, sh.position.y + sh.size.y * 0.15), 0.5, 1.4)
	L(ci, Vector2(vs.get_center().x, vs.position.y), Vector2(vs.get_center().x, 0), 0.5, 1.4)
	P(ci, PackedVector2Array([Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, h * 0.96), Vector2(w * 0.86, h * 0.96), Vector2(w * 0.86, h * 0.7), Vector2(w - 1.0, h * 0.7)]), 0.5, 1.2)
	L(ci, Vector2(vs.position.x + 3.0, vs.end.y - 2.0), Vector2(vs.position.x - 2.0, h - 1.0), 0.45)
	L(ci, Vector2(vs.end.x - 3.0, vs.end.y - 2.0), Vector2(vs.end.x + 2.0, h - 1.0), 0.45)


# a mud agitator: the gearmotor on its mounting plate, the shaft down into the tank,
# the pitched-blade impeller at its foot
static func agitator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	E.motor(ci, Rect2(w * 0.08, h * 0.04, w * 0.5, h * 0.18), false, 0.5)
	var gb := Rect2(cx - w * 0.1, h * 0.06, w * 0.38, h * 0.22)
	R(ci, gb, 0.55)
	O(ci, gb.get_center(), gb.size.y * 0.3, 0.4)
	L(ci, Vector2(w * 0.06, h * 0.3), Vector2(w * 0.94, h * 0.3), 0.6, 2.0)
	L(ci, Vector2(gb.get_center().x, h * 0.3), Vector2(gb.get_center().x, h * 0.86), 0.55, 1.6)
	var ic := Vector2(gb.get_center().x, h * 0.86)
	for s in [-1.0, 1.0]:
		P(ci, PackedVector2Array([ic, ic + Vector2(s * w * 0.32, -h * 0.05), ic + Vector2(s * w * 0.34, h * 0.03), ic]), 0.55)
	O(ci, ic, 2.0, 0.6)
	# the tank wall it hangs in, dashed
	var segs := PackedVector2Array()
	for k in 8:
		var y: float = h * (0.34 + k * 0.08)
		segs.append(Vector2(w * 0.04, y))
		segs.append(Vector2(w * 0.04, y + h * 0.04))
		segs.append(Vector2(w * 0.96, y))
		segs.append(Vector2(w * 0.96, y + h * 0.04))
	S(ci, segs, 0.25)


# an iron roughneck: the carriage on its rail, the arm folding out on parallel links,
# the wrench head (spinner above with its rollers, torque wrench below, its jaws)
static func roughneck(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.84, w * 0.5, h * 0.14), 0.55)
	for f in [0.12, 0.44]:
		O(ci, Vector2(w * f, h * 0.98), minf(w * 0.04, 3.0), 0.5)
	var j := Vector2(w * 0.2, h * 0.84)
	var e := Vector2(w * 0.38, h * 0.36)
	L(ci, j, e, 0.55, 1.6)
	L(ci, j + Vector2(w * 0.12, 0), e + Vector2(w * 0.12, 0), 0.45, 1.2)
	L(ci, Vector2(w * 0.42, h * 0.84), Vector2(w * 0.32, h * 0.56), 0.45)
	R(ci, Rect2(w * 0.3, h * 0.56, w * 0.06, h * 0.14), 0.45)
	# the wrench head
	var hd := Rect2(w * 0.5, h * 0.06, w * 0.46, h * 0.62)
	R(ci, hd, 0.6, 1.2)
	var sp := sub(hd, 0.08, 0.06, 0.92, 0.36)
	R(ci, sp, 0.5)
	for f in [0.25, 0.75]:
		O(ci, sp.position + sp.size * Vector2(f, 0.5), sp.size.y * 0.32, 0.45)
	var tw := sub(hd, 0.08, 0.44, 0.92, 0.92)
	R(ci, tw, 0.5)
	L(ci, tw.position + tw.size * Vector2(0, 0.5), tw.position + tw.size * Vector2(1, 0.5), 0.4)
	for f in [0.3, 0.7]:
		P(ci, PackedVector2Array([tw.position + tw.size * Vector2(f - 0.12, 0.15), tw.position + tw.size * Vector2(f, 0.35), tw.position + tw.size * Vector2(f + 0.12, 0.15)]), 0.45)
	L(ci, e + Vector2(w * 0.06, 0), Vector2(hd.position.x, h * 0.36), 0.5, 1.4)
	L(ci, Vector2(hd.get_center().x, hd.position.y), Vector2(hd.get_center().x, hd.end.y), 0.2)


# a pipe rack: stanchions, the pipe stacked between them end-on (each with its
# bore), the chocks
static func pipe_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for x in [2.0, w - 2.0]:
		L(ci, Vector2(x, 1), Vector2(x, h - 1), 0.55, 1.6)
	L(ci, Vector2(2, h - 2.0), Vector2(w - 2, h - 2.0), 0.55, 1.6)
	var pr: float = clampf(h * 0.13, 3.0, 9.0)
	var rows := clampi(int((h - 4.0) / (pr * 1.75)), 1, 6)
	for k in rows:
		var y: float = h - 4.0 - pr - k * pr * 1.75
		var off: float = pr if k % 2 == 1 else 0.0
		var n := int((w - 8.0 - off) / (pr * 2.05))
		for i in n:
			var c := Vector2(5.0 + off + pr + i * pr * 2.05, y)
			O(ci, c, pr, 0.5)
			O(ci, c, pr * 0.55, 0.3)
	L(ci, Vector2(2, h * 0.5), Vector2(w - 2, h * 0.5), 0.2)


# a bundle of casing joints end-on, strapped
static func pipe_bundle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var pr: float = clampf(minf(w, h) * 0.16, 3.0, 10.0)
	var rows := clampi(int((h - 4.0) / (pr * 1.75)), 1, 6)
	for k in rows:
		var y: float = h - 3.0 - pr - k * pr * 1.75
		var off: float = pr if k % 2 == 1 else 0.0
		var n := int((w - 6.0 - off) / (pr * 2.05))
		for i in n:
			var c := Vector2(3.0 + off + pr + i * pr * 2.05, y)
			O(ci, c, pr, 0.5)
			O(ci, c, pr * 0.72, 0.28)
	for f in [0.2, 0.8]:
		L(ci, Vector2(w * f, 1), Vector2(w * f, h - 1), 0.45, 1.4)
	L(ci, Vector2(1, h - 1), Vector2(w - 1, h - 1), 0.5, 1.4)


# a blowout preventer stack on its skid: the annular preventer on top (its packing
# element), three ram preventers below it (pipe rams, the blind-shear rams with
# their bigger operators, pipe rams) each with bonnets and hydraulic cylinders
# out both sides, the choke and kill valves on the side outlets, the wellhead
# connector at the foot, the frame's guide posts and the two control pods
static func bop(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	var bw: float = w * 0.36
	# frame and guide posts
	for x in [w * 0.04, w * 0.96]:
		L(ci, Vector2(x, h * 0.04), Vector2(x, h * 0.97), 0.5, 1.4)
	L(ci, Vector2(w * 0.04, h * 0.97), Vector2(w * 0.96, h * 0.97), 0.55, 1.8)
	L(ci, Vector2(w * 0.04, h * 0.3), Vector2(w * 0.96, h * 0.3), 0.35)
	# riser adapter
	R(ci, Rect2(cx - bw * 0.3, 0, bw * 0.6, h * 0.05), 0.55)
	# annular preventer: domed head, the packing element donut
	var an := Rect2(cx - bw * 0.55, h * 0.05, bw * 1.1, h * 0.2)
	P(ci, PackedVector2Array([Vector2(an.position.x, an.end.y), Vector2(an.position.x, an.position.y + an.size.y * 0.4), Vector2(cx - bw * 0.3, an.position.y), Vector2(cx + bw * 0.3, an.position.y), Vector2(an.end.x, an.position.y + an.size.y * 0.4), Vector2(an.end.x, an.end.y), Vector2(an.position.x, an.end.y)]), 0.6, 1.2)
	A(ci, Vector2(cx, an.position.y + an.size.y * 0.62), bw * 0.32, PI, TAU, 0.45)
	L(ci, Vector2(cx - bw * 0.32, an.position.y + an.size.y * 0.62), Vector2(cx + bw * 0.32, an.position.y + an.size.y * 0.62), 0.45)
	# the rams
	var rams := [[0.28, 0.16, 0.42], [0.48, 0.18, 0.5], [0.7, 0.16, 0.42]]
	for e in rams:
		var y0: float = h * e[0]
		var rh: float = h * e[1]
		var reach: float = w * e[2]
		R(ci, Rect2(cx - bw * 0.5, y0, bw, rh), 0.6, 1.2)
		for s in [-1.0, 1.0]:
			var bx0: float = cx + s * bw * 0.5
			var bx1: float = cx + s * reach
			R(ci, Rect2(minf(bx0, bx1), y0 + rh * 0.15, absf(bx1 - bx0), rh * 0.7), 0.5)
			L(ci, Vector2(bx1, y0 + rh * 0.3), Vector2(bx1 + s * 3.0, y0 + rh * 0.3), 0.45)
			L(ci, Vector2(bx1, y0 + rh * 0.7), Vector2(bx1 + s * 3.0, y0 + rh * 0.7), 0.45)
			# the ram block inside, at its stroke
			R(ci, Rect2(cx + s * bw * 0.06 - (bw * 0.36 if s < 0 else 0.0), y0 + rh * 0.35, bw * 0.36, rh * 0.3), 0.35)
	# the bore through it all
	L(ci, Vector2(cx - 2.5, 0), Vector2(cx - 2.5, h * 0.94), 0.25)
	L(ci, Vector2(cx + 2.5, 0), Vector2(cx + 2.5, h * 0.94), 0.25)
	# choke and kill valves on the side outlets
	for s in [-1.0, 1.0]:
		var vy: float = h * 0.66
		var vx: float = cx + s * bw * 0.75
		L(ci, Vector2(cx + s * bw * 0.5, vy), Vector2(vx + s * 6.0, vy), 0.5)
		P(ci, PackedVector2Array([Vector2(vx - 3, vy - 3), Vector2(vx + 3, vy + 3), Vector2(vx + 3, vy - 3), Vector2(vx - 3, vy + 3), Vector2(vx - 3, vy - 3)]), 0.55)
	# wellhead connector
	var wc := Rect2(cx - bw * 0.42, h * 0.86, bw * 0.84, h * 0.1)
	R(ci, wc, 0.6, 1.2)
	E.hatch(ci, E.inset(wc, 1.5), 3.0, true, 0.3, 20)
	# control pods on the frame
	for s in [-1.0, 1.0]:
		R(ci, Rect2(cx + s * w * 0.38 - w * 0.06, h * 0.06, w * 0.12, h * 0.18), 0.5)
		D(ci, Vector2(cx + s * w * 0.38, h * 0.1), 1.2, 0.6)


# a lathe: the bed on its cabinet legs, the headstock with the chuck and its jaws,
# the carriage and tool post, the tailstock, the lead screw
static func lathe(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var by: float = h * 0.5
	R(ci, Rect2(w * 0.02, by, w * 0.96, h * 0.08), 0.6)
	for x in [0.04, 0.72]:
		var lg := Rect2(w * x, by + h * 0.08, w * 0.24, h * 0.4)
		R(ci, lg, 0.45)
		L(ci, lg.position + Vector2(lg.size.x * 0.5, 4.0), lg.position + Vector2(lg.size.x * 0.5, lg.size.y - 4.0), 0.3)
	L(ci, Vector2(w * 0.04, by + h * 0.14), Vector2(w * 0.96, by + h * 0.14), 0.4)
	var hs := Rect2(w * 0.03, h * 0.12, w * 0.24, by - h * 0.12)
	R(ci, hs, 0.6, 1.2)
	E.gauge(ci, hs.position + hs.size * Vector2(0.3, 0.35), minf(hs.size.y * 0.16, 5.0), 0.45)
	var cc := Vector2(hs.end.x + w * 0.03, by - h * 0.14)
	R(ci, Rect2(hs.end.x, cc.y - h * 0.12, w * 0.05, h * 0.24), 0.55)
	for s in [-1.0, 1.0]:
		L(ci, Vector2(hs.end.x + w * 0.05, cc.y + s * h * 0.06), Vector2(hs.end.x + w * 0.08, cc.y + s * h * 0.03), 0.5)
	L(ci, Vector2(hs.end.x + w * 0.05, cc.y), Vector2(w * 0.62, cc.y), 0.4, 1.4)
	var cr := Rect2(w * 0.44, by - h * 0.12, w * 0.16, h * 0.12)
	R(ci, cr, 0.55)
	R(ci, Rect2(cr.position.x + cr.size.x * 0.3, cr.position.y - h * 0.08, cr.size.x * 0.4, h * 0.08), 0.5)
	E.wheel(ci, Vector2(cr.get_center().x, by + h * 0.04), minf(h * 0.06, 4.0), 0.45)
	var ts := Rect2(w * 0.78, h * 0.26, w * 0.14, by - h * 0.26)
	R(ci, ts, 0.55)
	L(ci, Vector2(ts.position.x, cc.y), Vector2(w * 0.66, cc.y), 0.5, 1.4)
	E.wheel(ci, Vector2(ts.end.x + w * 0.03, cc.y), minf(h * 0.06, 4.0), 0.45)


# a milling machine: the column and base, the knee and saddle with the table and
# its T-slots and a vice, the head with its spindle and the motor on top
static func mill(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.9, w * 0.92, h * 0.08), 0.55)
	var col := Rect2(w * 0.62, h * 0.18, w * 0.3, h * 0.72)
	R(ci, col, 0.55)
	L(ci, Vector2(col.position.x + 3.0, col.position.y + 4.0), Vector2(col.position.x + 3.0, col.end.y - 4.0), 0.3)
	var hd := Rect2(w * 0.24, h * 0.1, w * 0.46, h * 0.2)
	R(ci, hd, 0.6, 1.2)
	E.motor(ci, Rect2(w * 0.3, 0, w * 0.4, h * 0.1), false, 0.45)
	L(ci, Vector2(w * 0.36, hd.end.y), Vector2(w * 0.36, h * 0.42), 0.55, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.34, h * 0.42), Vector2(w * 0.36, h * 0.46), Vector2(w * 0.38, h * 0.42)]), 0.5)
	E.wheel(ci, Vector2(w * 0.2, h * 0.2), minf(w * 0.05, 4.0), 0.45)
	var tb := Rect2(w * 0.06, h * 0.5, w * 0.56, h * 0.06)
	R(ci, tb, 0.6)
	for k in 3:
		L(ci, Vector2(tb.position.x + 2.0, tb.position.y + tb.size.y * (0.3 + k * 0.2)), Vector2(tb.end.x - 2.0, tb.position.y + tb.size.y * (0.3 + k * 0.2)), 0.25)
	R(ci, Rect2(w * 0.26, h * 0.44, w * 0.18, h * 0.06), 0.5)
	R(ci, Rect2(w * 0.16, h * 0.56, w * 0.46, h * 0.08), 0.45)
	R(ci, Rect2(w * 0.22, h * 0.64, w * 0.4, h * 0.26), 0.45)
	E.wheel(ci, Vector2(w * 0.12, h * 0.6), minf(w * 0.05, 4.0), 0.45)


# the standpipe manifold: the vertical standpipe, its gate valves and pressure
# gauges, the rotary hose's gooseneck off the top, the bleed-off line
static func standpipe(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.4
	L(ci, Vector2(cx - 3.0, h * 0.04), Vector2(cx - 3.0, h), 0.6)
	L(ci, Vector2(cx + 3.0, h * 0.04), Vector2(cx + 3.0, h), 0.6)
	A(ci, Vector2(cx + w * 0.2, h * 0.06), w * 0.2, PI, TAU, 0.55, 1.4)
	for f in [0.28, 0.6]:
		var vc := Vector2(cx, h * f)
		var vs: float = minf(w * 0.18, 6.0)
		P(ci, PackedVector2Array([vc + Vector2(-vs, -vs * 0.7), vc + Vector2(vs, vs * 0.7), vc + Vector2(vs, -vs * 0.7), vc + Vector2(-vs, vs * 0.7), vc + Vector2(-vs, -vs * 0.7)]), 0.6)
		L(ci, vc + Vector2(vs, 0), vc + Vector2(vs * 2.2, 0), 0.45)
		E.wheel(ci, vc + Vector2(vs * 2.8, 0), vs * 0.6, 0.45)
	E.gauge(ci, Vector2(cx - w * 0.22, h * 0.44), minf(w * 0.14, 6.0), 0.55)
	L(ci, Vector2(cx - w * 0.22 + minf(w * 0.14, 6.0), h * 0.44), Vector2(cx - 3.0, h * 0.44), 0.4)
	L(ci, Vector2(cx + 3.0, h * 0.82), Vector2(w - 1.0, h * 0.82), 0.5)


# the choke manifold: a header with its gate valves, the adjustable choke (its
# wedge body and actuator), the gauge
static func choke_manifold(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var y: float = h * 0.64
	L(ci, Vector2(1, y - 3.0), Vector2(w - 1, y - 3.0), 0.55)
	L(ci, Vector2(1, y + 3.0), Vector2(w - 1, y + 3.0), 0.55)
	for f in [0.18, 0.8]:
		var vc := Vector2(w * f, y)
		var vs: float = minf(w * 0.08, 6.0)
		P(ci, PackedVector2Array([vc + Vector2(-vs, -vs), vc + Vector2(vs, vs), vc + Vector2(-vs, vs), vc + Vector2(vs, -vs), vc + Vector2(-vs, -vs)]), 0.6)
		L(ci, vc + Vector2(0, -vs), vc + Vector2(0, -vs * 2.4), 0.45)
		E.wheel(ci, vc + Vector2(0, -vs * 2.8), vs * 0.55, 0.45)
	# the choke: angle body, its actuator box
	var cc := Vector2(w * 0.5, y)
	R(ci, Rect2(cc - Vector2(w * 0.1, h * 0.12), Vector2(w * 0.2, h * 0.24)), 0.6, 1.2)
	L(ci, cc + Vector2(0, -h * 0.12), cc + Vector2(0, -h * 0.3), 0.5, 1.4)
	R(ci, Rect2(cc + Vector2(-w * 0.12, -h * 0.5), Vector2(w * 0.24, h * 0.2)), 0.55)
	E.gauge(ci, Vector2(w * 0.5, h * 0.9), minf(h * 0.08, 5.0), 0.5)
	L(ci, Vector2(w * 0.5, h * 0.76), Vector2(w * 0.5, h * 0.82), 0.4)


# the BOP accumulator unit (Koomey): its racked bottles on the header, the
# electric and air pumps, the manifold of control valves with their gauges
static func koomey(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	E.gastank(ci, Rect2(0, h * 0.3, w, h * 0.7))
	var vb := Rect2(w * 0.06, h * 0.02, w * 0.88, h * 0.22)
	R(ci, vb, 0.55)
	var n := clampi(int(vb.size.x / 8.0), 2, 6)
	for k in n:
		var x: float = vb.position.x + (k + 0.5) * vb.size.x / n
		L(ci, Vector2(x, vb.position.y + 2.0), Vector2(x, vb.get_center().y), 0.6, 1.6)
		D(ci, Vector2(x, vb.end.y - 3.0), 1.1, 0.55)
	L(ci, Vector2(w * 0.5, vb.end.y), Vector2(w * 0.5, h * 0.3), 0.45)


# ================================================================== HG-170 Gas Sea

# an axial compressor stage on the scoop's throat: the casing narrowing aft, the
# rotor drum, rows of rotor blades between rows of stator vanes, the inlet guide
# vanes, the bearing struts, the drive shaft out the back
static func axial_comp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var c: float = th * 0.5
	# casing: wide at the inlet (u=0), narrow aft
	P(ci, PackedVector2Array([X.call(0.0, c - th * 0.48), X.call(ln * 0.85, c - th * 0.34), X.call(ln, c - th * 0.34)]), 0.6, 1.2)
	P(ci, PackedVector2Array([X.call(0.0, c + th * 0.48), X.call(ln * 0.85, c + th * 0.34), X.call(ln, c + th * 0.34)]), 0.6, 1.2)
	# rotor drum
	P(ci, PackedVector2Array([X.call(ln * 0.08, c - th * 0.12), X.call(ln * 0.85, c - th * 0.2), X.call(ln * 0.85, c + th * 0.2), X.call(ln * 0.08, c + th * 0.12), X.call(ln * 0.08, c - th * 0.12)]), 0.5)
	var n := clampi(int(ln / 7.0), 4, 18)
	var segs := PackedVector2Array()
	var vanes := PackedVector2Array()
	for k in n:
		var u: float = ln * (0.1 + 0.74 * (k + 0.5) / n)
		var t: float = u / (ln * 0.85)
		var outer: float = lerpf(th * 0.46, th * 0.35, t)
		var inner: float = lerpf(th * 0.12, th * 0.2, t)
		var arr: PackedVector2Array = segs if k % 2 == 0 else vanes
		for sg in [-1.0, 1.0]:
			arr.append(X.call(u, c + sg * inner))
			arr.append(X.call(u + (2.5 if k % 2 == 0 else -2.0), c + sg * (outer - 1.0)))
	S(ci, segs, 0.45)
	S(ci, vanes, 0.3)
	# inlet guide vanes and the nose cone
	P(ci, PackedVector2Array([X.call(ln * 0.08, c - th * 0.12), X.call(0.0, c), X.call(ln * 0.08, c + th * 0.12)]), 0.5)
	L(ci, X.call(ln * 0.85, c), X.call(ln, c), 0.55, 1.6)
	for sg in [-1.0, 1.0]:
		L(ci, X.call(ln * 0.92, c + sg * th * 0.04), X.call(ln * 0.92, c + sg * th * 0.33), 0.4, 1.4)


# a twin-screw compressor package: the male and female rotors in their housing, the
# motor driving them, the oil separator vessel, the oil cooler, the suction filter
static func screw_comp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var base_y: float = h * 0.94
	L(ci, Vector2(2, base_y), Vector2(w - 2, base_y), 0.55, 1.6)
	var hs := Rect2(w * 0.06, h * 0.42, w * 0.34, h * 0.36)
	R(ci, hs, 0.6, 1.2)
	for k in 2:
		var y: float = hs.position.y + hs.size.y * (0.3 + k * 0.4)
		var segs := PackedVector2Array()
		var nl := clampi(int(hs.size.x / 4.0), 3, 20)
		for i in nl:
			var x: float = hs.position.x + 2.0 + i * (hs.size.x - 4.0) / nl
			segs.append(Vector2(x, y - hs.size.y * 0.14))
			segs.append(Vector2(x + 3.0 * (1.0 if k == 0 else -1.0), y + hs.size.y * 0.14))
		S(ci, segs, 0.35)
		L(ci, Vector2(hs.position.x, y), Vector2(hs.end.x, y), 0.25)
	E.motor(ci, Rect2(hs.end.x, h * 0.46, w * 0.3, h * 0.28), true, 0.5)
	var os := Rect2(w * 0.74, h * 0.1, w * 0.2, h * 0.76)
	E.vessel_v(ci, os, 0.55)
	L(ci, Vector2(hs.get_center().x, hs.position.y), Vector2(hs.get_center().x, h * 0.18), 0.5, 1.4)
	L(ci, Vector2(hs.get_center().x, h * 0.18), Vector2(os.position.x, h * 0.18), 0.5, 1.4)
	R(ci, Rect2(w * 0.08, h * 0.08, w * 0.22, h * 0.22), 0.45)
	E.hatch(ci, Rect2(w * 0.1, h * 0.1, w * 0.18, h * 0.18), 3.0, true, 0.22, 20)
	E.gauge(ci, Vector2(w * 0.86, h * 0.92 - h * 0.5), minf(w * 0.05, 4.0), 0.5)


# a hydrogen cold box: the vacuum jacket, the plate-fin heat exchangers in series
# down its height, the turboexpanders between them, the Joule-Thomson valve and
# the liquid separator at the foot, the transfer lines out
static func cold_box_h2(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.02, w * 0.92, h * 0.96), 0.55, 1.2)
	R(ci, Rect2(w * 0.07, h * 0.04, w * 0.86, h * 0.92), 0.25)
	for k in 3:
		var hx := Rect2(w * 0.14, h * (0.07 + k * 0.24), w * 0.34, h * 0.2)
		R(ci, hx, 0.5)
		E.hatch(ci, E.inset(hx, 1.5), 2.5, true, 0.18, 40)
		if k < 2:
			var tc := Vector2(w * 0.7, hx.end.y)
			O(ci, tc, minf(w * 0.08, h * 0.05), 0.55)
			E.impeller(ci, tc, minf(w * 0.08, h * 0.05) * 0.8, 0.4)
			L(ci, Vector2(hx.end.x, hx.get_center().y), Vector2(tc.x, hx.get_center().y), 0.4)
			L(ci, Vector2(tc.x, hx.get_center().y), tc - Vector2(0, minf(w * 0.08, h * 0.05)), 0.4)
			L(ci, tc + Vector2(0, minf(w * 0.08, h * 0.05)), Vector2(tc.x, hx.end.y + h * 0.06), 0.4)
			L(ci, Vector2(tc.x, hx.end.y + h * 0.06), Vector2(hx.end.x, hx.end.y + h * 0.06), 0.4)
	# JT valve and separator
	var jv := Vector2(w * 0.31, h * 0.8)
	P(ci, PackedVector2Array([jv + Vector2(-3, -3), jv + Vector2(3, 3), jv + Vector2(3, -3), jv + Vector2(-3, 3), jv + Vector2(-3, -3)]), 0.6)
	var sp := Rect2(w * 0.5, h * 0.76, w * 0.36, h * 0.18)
	E.vessel_h(ci, sp, 0.5)
	L(ci, Vector2(sp.position.x + 2.0, sp.get_center().y + sp.size.y * 0.15), Vector2(sp.end.x - 2.0, sp.get_center().y + sp.size.y * 0.15), 0.3)
	L(ci, jv + Vector2(3, 0), Vector2(sp.position.x, jv.y), 0.4)
	for x in [0.3, 0.5, 0.7]:
		L(ci, Vector2(w * x, 0), Vector2(w * x, h * 0.07), 0.45)


# an ortho-para converter: the catalyst beds (hydrous iron oxide, dotted) packed in
# the passages of a heat exchanger, the cold bath round it, inlet and outlet
static func ortho_para(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.12, h * 0.06, w * 0.76, h * 0.86)
	var sh := E.vessel_v(ci, vs, 0.6)
	var n := 3
	for k in n:
		var b := Rect2(sh.position.x + sh.size.x * (0.08 + k * 0.3), sh.position.y + 3.0, sh.size.x * 0.24, sh.size.y - 6.0)
		R(ci, b, 0.45)
		var dots := PackedVector2Array()
		var ny := clampi(int(b.size.y / 4.0), 2, 30)
		var nx := clampi(int(b.size.x / 4.0), 1, 6)
		for j in ny:
			for i in nx:
				var q := b.position + Vector2((i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * b.size.x / (nx + 0.5), (j + 0.5) * b.size.y / ny)
				dots.append(q)
				dots.append(q + Vector2(0.8, 0))
		S(ci, dots, 0.45)
	# the coolant coil between the beds
	for k in 2:
		var x: float = sh.position.x + sh.size.x * (0.35 + k * 0.3)
		var pts := PackedVector2Array()
		var nz := clampi(int(sh.size.y / 6.0), 3, 20)
		for j in nz + 1:
			pts.append(Vector2(x + (2.0 if j % 2 == 0 else -2.0), sh.position.y + 2.0 + j * (sh.size.y - 4.0) / nz))
		P(ci, pts, 0.3)
	L(ci, Vector2(vs.get_center().x, vs.position.y), Vector2(vs.get_center().x, 0), 0.5, 1.4)
	L(ci, Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, h), 0.5, 1.4)
	L(ci, Vector2(vs.position.x, sh.get_center().y), Vector2(1, sh.get_center().y), 0.45)


# a liquid-nitrogen precooler: the LN2 bath vessel, the coiled tube bundle the gas
# runs through, the boil-off vent, the level probe
static func precooler(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.1, h * 0.08, w * 0.8, h * 0.84)
	var sh := E.vessel_v(ci, vs, 0.6)
	var lvl: float = sh.position.y + sh.size.y * 0.2
	var pts := PackedVector2Array()
	var nw := clampi(int(sh.size.x / 5.0), 3, 30)
	for k in nw + 1:
		pts.append(Vector2(sh.position.x + sh.size.x * k / nw, lvl + (1.0 if k % 2 == 0 else -1.0)))
	P(ci, pts, 0.4)
	var nc := clampi(int(sh.size.y * 0.7 / 5.0), 3, 24)
	for k in nc:
		var y: float = lvl + 4.0 + k * (sh.end.y - lvl - 8.0) / nc
		O(ci, Vector2(sh.position.x + sh.size.x * 0.32, y), 2.0, 0.35)
		O(ci, Vector2(sh.position.x + sh.size.x * 0.68, y), 2.0, 0.35)
	L(ci, Vector2(sh.position.x + sh.size.x * 0.32, lvl), Vector2(sh.position.x + sh.size.x * 0.32, 1.0), 0.45)
	L(ci, Vector2(sh.position.x + sh.size.x * 0.68, lvl), Vector2(sh.position.x + sh.size.x * 0.68, 1.0), 0.45)
	P(ci, PackedVector2Array([Vector2(vs.end.x - 4.0, vs.position.y), Vector2(vs.end.x - 4.0, 2.0), Vector2(w - 2.0, 2.0)]), 0.4)
	L(ci, Vector2(sh.get_center().x, vs.position.y), Vector2(sh.get_center().x, sh.end.y - 4.0), 0.25)


# a pressure-swing adsorption separator: two adsorber columns with their beds, the
# valve manifolds at their tops and bottoms switching between them
static func psa(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for k in 2:
		var col := Rect2(w * (0.1 + k * 0.46), h * 0.14, w * 0.34, h * 0.72)
		var sh := E.vessel_v(ci, col, 0.6)
		E.hatch(ci, Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.15, sh.size.x - 4.0, sh.size.y * 0.7), 3.0, false, 0.18, 40)
		L(ci, Vector2(sh.position.x, sh.position.y + sh.size.y * 0.15), Vector2(sh.end.x, sh.position.y + sh.size.y * 0.15), 0.4)
		L(ci, Vector2(sh.position.x, sh.position.y + sh.size.y * 0.85), Vector2(sh.end.x, sh.position.y + sh.size.y * 0.85), 0.4)
	for y in [h * 0.06, h * 0.94]:
		L(ci, Vector2(w * 0.1, y), Vector2(w * 0.9, y), 0.55, 1.4)
		for k in 2:
			var x: float = w * (0.27 + k * 0.46)
			L(ci, Vector2(x, y), Vector2(x, h * 0.14 if y < h * 0.5 else h * 0.86), 0.45)
			var vc := Vector2(x, (y + (h * 0.14 if y < h * 0.5 else h * 0.86)) * 0.5)
			P(ci, PackedVector2Array([vc + Vector2(-3, -2.5), vc + Vector2(3, 2.5), vc + Vector2(-3, 2.5), vc + Vector2(3, -2.5), vc + Vector2(-3, -2.5)]), 0.55)


# a gas chromatograph: the oven door with its window onto the coiled column, the
# injector port and autosampler turret on top, the detector block, the display
static func gc(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var b := Rect2(w * 0.04, h * 0.2, w * 0.92, h * 0.78)
	R(ci, b, 0.55)
	var ov := Rect2(b.position.x + b.size.x * 0.06, b.position.y + b.size.y * 0.12, b.size.x * 0.56, b.size.y * 0.76)
	R(ci, ov, 0.5)
	var cc := ov.get_center()
	for k in 4:
		O(ci, cc, minf(ov.size.x, ov.size.y) * (0.16 + k * 0.07), 0.3)
	L(ci, Vector2(ov.end.x - 3.0, ov.position.y + 4.0), Vector2(ov.end.x - 3.0, ov.end.y - 4.0), 0.6, 1.6)
	# autosampler turret and the injector
	var tc := Vector2(b.position.x + b.size.x * 0.3, h * 0.12)
	O(ci, tc, minf(w * 0.14, h * 0.1), 0.55)
	for k in 8:
		D(ci, tc + Vector2.from_angle(TAU * k / 8.0) * minf(w * 0.14, h * 0.1) * 0.7, 0.9, 0.5)
	L(ci, tc + Vector2(0, minf(w * 0.14, h * 0.1)), Vector2(tc.x, b.position.y), 0.5, 1.4)
	R(ci, Rect2(b.position.x + b.size.x * 0.7, b.position.y + b.size.y * 0.1, b.size.x * 0.24, b.size.y * 0.3), 0.5)
	E.screen_face(ci, Rect2(b.position.x + b.size.x * 0.7, b.position.y + b.size.y * 0.5, b.size.x * 0.24, b.size.y * 0.24), 0, 0.4)


# a quadrupole mass spectrometer: the vacuum chamber with the ion source, the four
# rods, the detector, the turbopump hanging under it, the electronics box
static func mass_spec(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ch := Rect2(w * 0.04, h * 0.18, w * 0.62, h * 0.34)
	R(ci, ch, 0.6, 1.2)
	R(ci, Rect2(ch.position.x + 3.0, ch.position.y + ch.size.y * 0.3, ch.size.x * 0.12, ch.size.y * 0.4), 0.5)
	for k in 4:
		var y: float = ch.position.y + ch.size.y * (0.2 + k * 0.2)
		L(ci, Vector2(ch.position.x + ch.size.x * 0.22, y), Vector2(ch.end.x - ch.size.x * 0.18, y), 0.45, 1.4)
	O(ci, Vector2(ch.end.x - ch.size.x * 0.08, ch.get_center().y), ch.size.y * 0.18, 0.5)
	L(ci, Vector2(ch.position.x + ch.size.x * 0.12, ch.get_center().y), Vector2(ch.end.x - ch.size.x * 0.1, ch.get_center().y), 0.15)
	# turbopump under the chamber
	var tp := Rect2(ch.position.x + ch.size.x * 0.35, ch.end.y, ch.size.x * 0.3, h * 0.42)
	R(ci, tp, 0.5)
	for k in 5:
		var y: float = tp.position.y + tp.size.y * (0.1 + k * 0.12)
		L(ci, Vector2(tp.position.x + 2.0, y), Vector2(tp.end.x - 2.0, y + 2.0), 0.3)
	R(ci, Rect2(tp.position.x + tp.size.x * 0.2, tp.end.y - tp.size.y * 0.28, tp.size.x * 0.6, tp.size.y * 0.24), 0.45)
	var eb := Rect2(w * 0.72, h * 0.1, w * 0.24, h * 0.84)
	R(ci, eb, 0.5)
	E.screen_face(ci, sub(eb, 0.1, 0.06, 0.9, 0.3), 1, 0.4)
	E.hatch(ci, sub(eb, 0.15, 0.4, 0.85, 0.9), 3.0, false, 0.2, 20)


# a turboexpander: the expansion turbine's volute and wheel, the shaft through its
# gas bearings, the brake compressor (or generator) on the other end, the inlet
# nozzle valve, on its skid
static func turboexpander(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := 2 if w > h * 1.6 else 1
	var uw: float = w / n
	for i in n:
		var x0: float = i * uw
		var ay: float = h * 0.46
		var vr: float = minf(uw * 0.16, h * 0.22)
		var tc := Vector2(x0 + uw * 0.22, ay)
		O(ci, tc, vr, 0.6, 1.2)
		E.impeller(ci, tc, vr * 0.75, 0.45)
		var bc := Vector2(x0 + uw * 0.78, ay)
		O(ci, bc, vr * 0.9, 0.55, 1.2)
		E.impeller(ci, bc, vr * 0.65, 0.4)
		var bh := Rect2(tc.x + vr, ay - vr * 0.45, bc.x - tc.x - vr * 1.9, vr * 0.9)
		R(ci, bh, 0.55)
		E.hatch(ci, E.inset(bh, 2.0), 3.0, true, 0.2, 20)
		L(ci, tc, bc, 0.3)
		# inlet with its nozzle valve, outlet down
		L(ci, tc + Vector2(0, -vr), Vector2(tc.x, h * 0.06), 0.5, 1.4)
		var vc := Vector2(tc.x, h * 0.14)
		P(ci, PackedVector2Array([vc + Vector2(-3, -3), vc + Vector2(3, 3), vc + Vector2(-3, 3), vc + Vector2(3, -3), vc + Vector2(-3, -3)]), 0.6)
		L(ci, tc + Vector2(-vr, 0), Vector2(x0 + 2.0, ay), 0.5, 1.4)
		L(ci, bc + Vector2(0, -vr * 0.9), Vector2(bc.x, h * 0.1), 0.45)
		L(ci, Vector2(x0 + uw * 0.1, h * 0.92), Vector2(x0 + uw * 0.9, h * 0.92), 0.55, 1.6)
		for f in [0.3, 0.7]:
			L(ci, Vector2(x0 + uw * f, ay + vr * 0.45), Vector2(x0 + uw * f, h * 0.92), 0.45)


# ================================================================== QC-30 Quantum

# a dilution refrigerator stage: the gold-plated copper plate with its bolt circle,
# the coax lines passing down through it with their attenuators or filters
# thermalised on it, the heat exchanger / pot on the colder stages, the supports
static func dr_stage(ci: CanvasItem, r: Rect2, p) -> void:
	var w := r.size.x
	var h := r.size.y
	var nk: String = p.name_key if p != null else ""
	R(ci, Rect2(1, h * 0.3, w - 2, h * 0.4), 0.65, 1.2)
	var nb := clampi(int(w / 9.0), 3, 30)
	E.bolts(ci, Vector2(3, h * 0.5), Vector2(w - 3, h * 0.5), nb, 0.45, 0.8)
	# coax lines through the plate, each with its component on the plate
	var nl := clampi(int(w * 0.5 / 7.0), 3, 14)
	for k in nl:
		var x: float = w * 0.25 + (k + 0.5) * w * 0.5 / nl
		L(ci, Vector2(x, 0), Vector2(x, h), 0.35)
		var comp := Rect2(x - 1.6, h * 0.04, 3.2, h * 0.24)
		R(ci, comp, 0.55)
	# the stage's own hardware
	match nk:
		"p_qc_stage_50k", "p_qc_stage_4k":
			# pulse-tube cold-head flange and the heat links
			R(ci, Rect2(w * 0.04, h * 0.0, w * 0.14, h * 0.3), 0.55)
			E.hatch(ci, Rect2(w * 0.05, h * 0.02, w * 0.12, h * 0.26), 2.5, true, 0.25, 12)
		"p_qc_stage_still":
			# the still pot and its heater
			R(ci, Rect2(w * 0.04, h * 0.7, w * 0.16, h * 0.28), 0.55)
			E.hatch(ci, Rect2(w * 0.06, h * 0.74, w * 0.12, h * 0.2), 3.0, false, 0.3, 6)
		"p_qc_stage_cp":
			# the continuous heat exchanger, a spiral
			for k in 3:
				O(ci, Vector2(w * 0.12, h * 0.84), h * (0.05 + k * 0.04), 0.35)
		"p_qc_stage_mxc":
			# the mixing chamber can and the step heat exchangers
			R(ci, Rect2(w * 0.04, h * 0.7, w * 0.18, h * 0.3), 0.6)
			for k in 3:
				R(ci, Rect2(w * (0.8 + k * 0.05), h * 0.72, w * 0.04, h * 0.24), 0.4)
		_:
			pass
	# the support rods to the stage above
	for x in [w * 0.02, w * 0.98]:
		L(ci, Vector2(x, 0), Vector2(x, h * 0.3), 0.5, 1.4)


# the processor package at the bottom of the fridge: the copper sample box, its
# lid screws, the SMA connectors along its edges, the chip seen through a window
static func qpu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.7, 1.4)
	E.corner_bolts(ci, Rect2(1, 1, w - 2, h - 2), 2.5, 0.6)
	var ch := Rect2(w * 0.32, h * 0.25, w * 0.36, h * 0.5)
	R(ci, ch, 0.65)
	E.hatch(ci, E.inset(ch, 1.0), 2.0, true, 0.35, 12)
	for k in 4:
		var x: float = w * (0.18 + k * 0.21)
		D(ci, Vector2(x, 1.5), 1.0, 0.7)
		D(ci, Vector2(x, h - 1.5), 1.0, 0.7)


# a pulse-tube cold head: the motor-driven rotary valve on top, the regenerator
# and the pulse tube side by side down to the first stage flange, then again to the
# second stage, the buffer volume and the helium flex lines
static func pulse_tube(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h >= w * 0.8
	var top := Rect2(w * 0.2, h * 0.02, w * 0.6, h * 0.2)
	R(ci, top, 0.6, 1.2)
	O(ci, top.get_center(), minf(top.size.y * 0.32, top.size.x * 0.2), 0.45)
	R(ci, Rect2(w * 0.08, h * 0.24, w * 0.84, h * 0.06), 0.6)
	var f1: float = h * (0.62 if vert else 0.66)
	for k in 2:
		var x: float = w * (0.35 + k * 0.3)
		L(ci, Vector2(x - 2.5, h * 0.3), Vector2(x - 2.5, f1), 0.5)
		L(ci, Vector2(x + 2.5, h * 0.3), Vector2(x + 2.5, f1), 0.5)
		if k == 0:
			E.hatch(ci, Rect2(x - 2.0, h * 0.32, 4.0, f1 - h * 0.34), 2.5, false, 0.3, 30)
	R(ci, Rect2(w * 0.18, f1, w * 0.64, h * 0.05), 0.6)
	var f2: float = h * 0.92
	L(ci, Vector2(w * 0.42, f1 + h * 0.05), Vector2(w * 0.42, f2), 0.5)
	L(ci, Vector2(w * 0.58, f1 + h * 0.05), Vector2(w * 0.58, f2), 0.5)
	R(ci, Rect2(w * 0.3, f2, w * 0.4, h * 0.06), 0.6)
	P(ci, PackedVector2Array([Vector2(top.end.x, top.get_center().y), Vector2(w - 2.0, top.get_center().y), Vector2(w - 2.0, h * 0.5)]), 0.4)


# the gas handling system: its mimic panel (the valves of the 3He/4He circuit drawn
# as a flow diagram, each with its indicator), the pressure gauges along the top,
# the cold trap and pumps behind the lower doors
static func ghs(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	var mp := Rect2(w * 0.06, h * 0.14, w * 0.88, h * 0.48)
	R(ci, mp, 0.45)
	var nx := clampi(int(mp.size.x / 14.0), 3, 10)
	var ny := 3
	var pts: Array = []
	for j in ny:
		for i in nx:
			pts.append(mp.position + Vector2((i + 0.5) * mp.size.x / nx, (j + 0.5) * mp.size.y / ny))
	var segs := PackedVector2Array()
	for j in ny:
		segs.append(pts[j * nx])
		segs.append(pts[j * nx + nx - 1])
	for i in range(0, nx, 2):
		segs.append(pts[i])
		segs.append(pts[(ny - 1) * nx + i])
	S(ci, segs, 0.3)
	for q in pts:
		var c: Vector2 = q
		P(ci, PackedVector2Array([c + Vector2(-2.5, -2), c + Vector2(2.5, 2), c + Vector2(2.5, -2), c + Vector2(-2.5, 2), c + Vector2(-2.5, -2)]), 0.55)
	var ng := clampi(int(w / 16.0), 2, 8)
	for i in ng:
		E.gauge(ci, Vector2(w * 0.06 + (i + 0.5) * w * 0.88 / ng, h * 0.07), minf(h * 0.05, 4.5), 0.5)
	for f in [0.25, 0.75]:
		E.door_leaf(ci, Rect2(w * (f - 0.22), h * 0.66, w * 0.44, h * 0.3), f < 0.5, 0.4)


# a vibration isolation table: the honeycomb top, the pneumatic legs with their
# bellows and level valves, the fridge's mounting ring through it
static func iso_table(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, h * 0.05, w - 2, h * 0.55), 0.6, 1.2)
	E.hatch(ci, Rect2(3, h * 0.12, w - 6, h * 0.4), 4.0, true, 0.15, 160)
	var dots := PackedVector2Array()
	for i in clampi(int(w / 8.0), 2, 120):
		var q := Vector2(4.0 + i * 8.0, h * 0.09)
		dots.append(q)
		dots.append(q + Vector2(0.7, 0))
	S(ci, dots, 0.5)
	R(ci, Rect2(w * 0.42, h * 0.02, w * 0.16, h * 0.62), 0.6)
	for f in [0.06, 0.94]:
		var lx: float = w * f
		R(ci, Rect2(lx - 4.0, h * 0.6, 8.0, h * 0.38), 0.55)
		var pts := PackedVector2Array()
		for k in 5:
			pts.append(Vector2(lx + (3.0 if k % 2 == 0 else -3.0), h * (0.64 + k * 0.06)))
		P(ci, pts, 0.4)


# a rack of room-temperature instruments: arbitrary waveform generators and
# digitisers, each a front panel with its screen, knobs and the row of SMA outputs
static func instrument_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(2, 1), Vector2(2, h - 1), 0.5)
	L(ci, Vector2(w - 2, 1), Vector2(w - 2, h - 1), 0.5)
	var uh: float = clampf(h / 7.0, 12.0, 26.0)
	var n := int((h - 4.0) / uh)
	for k in n:
		var b := Rect2(4, 2.0 + k * uh, w - 8, uh - 2.0)
		R(ci, b, 0.45)
		E.screen_face(ci, Rect2(b.position.x + 2.0, b.position.y + 2.0, b.size.x * 0.32, b.size.y - 4.0), k, 0.35)
		O(ci, Vector2(b.position.x + b.size.x * 0.45, b.get_center().y), minf(b.size.y * 0.22, 3.5), 0.45)
		var ns := clampi(int(b.size.x * 0.4 / 4.0), 2, 12)
		for i in ns:
			O(ci, Vector2(b.position.x + b.size.x * 0.56 + i * b.size.x * 0.4 / ns, b.get_center().y + b.size.y * 0.15), 1.2, 0.55)
		D(ci, Vector2(b.end.x - 3.0, b.position.y + 3.0), 0.8, 0.7)


# a turbomolecular pump: inlet flange, the stacked rotor and stator blade rows,
# the motor and bearings in the base, the backing port
static func turbo_pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.02, w * 0.92, h * 0.08), 0.6)
	var body := Rect2(w * 0.14, h * 0.1, w * 0.72, h * 0.56)
	R(ci, body, 0.55)
	var n := clampi(int(body.size.y / 4.5), 3, 14)
	for k in n:
		var y: float = body.position.y + (k + 0.5) * body.size.y / n
		var segs := PackedVector2Array()
		var nb := clampi(int(body.size.x / 5.0), 3, 20)
		for i in nb:
			var x: float = body.position.x + 2.0 + i * (body.size.x - 4.0) / nb
			var s: float = 2.0 if k % 2 == 0 else -2.0
			segs.append(Vector2(x, y - 1.5))
			segs.append(Vector2(x + s, y + 1.5))
		S(ci, segs, 0.3 if k % 2 == 0 else 0.2)
	L(ci, Vector2(w * 0.5, body.position.y), Vector2(w * 0.5, h * 0.92), 0.4)
	R(ci, Rect2(w * 0.24, h * 0.66, w * 0.52, h * 0.3), 0.5)
	R(ci, Rect2(w * 0.86, h * 0.72, w * 0.12, h * 0.1), 0.5)


# a scroll pump: the fixed and orbiting scrolls (two interleaved spirals) in their
# housing, the motor beside, the exhaust
static func scroll_pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.32, h * 0.5)
	var rad: float = minf(w * 0.26, h * 0.4)
	O(ci, c, rad, 0.6, 1.2)
	for k in 2:
		var pts := PackedVector2Array()
		for e in 28:
			var t: float = e / 27.0
			pts.append(c + Vector2.from_angle(t * TAU * 2.2 + k * PI) * rad * 0.9 * t)
		P(ci, pts, 0.45 if k == 0 else 0.3)
	E.motor(ci, Rect2(c.x + rad + 2.0, h * 0.28, w - c.x - rad - 4.0, h * 0.44), true, 0.5)
	L(ci, c + Vector2(0, -rad), Vector2(c.x, 2.0), 0.45, 1.4)
	L(ci, Vector2(2, h * 0.94), Vector2(w - 2, h * 0.94), 0.5, 1.4)


# ================================================================== OB-90 Observatory

# a hexapod: the top and bottom plates, six struts crossing between them in pairs,
# each a linear actuator with its motor and the universal joints at its ends
static func hexapod(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.08, 1, w * 0.84, h * 0.08), 0.6, 1.2)
	R(ci, Rect2(w * 0.02, h * 0.9, w * 0.96, h * 0.08), 0.6, 1.2)
	var tops := [0.18, 0.34, 0.66, 0.82]
	var bots := [0.08, 0.3, 0.7, 0.92]
	var pairs := [[0, 1], [1, 0], [2, 3], [3, 2], [1, 2], [2, 1]]
	for pr in pairs:
		var a := Vector2(w * tops[pr[0]], h * 0.09)
		var b := Vector2(w * bots[pr[1]], h * 0.9)
		L(ci, a, a.lerp(b, 0.55), 0.55, 1.6)
		L(ci, a.lerp(b, 0.5), b, 0.45, 1.0)
		var m: Vector2 = a.lerp(b, 0.6)
		var d: Vector2 = (b - a).normalized()
		P(ci, PackedVector2Array([m + d.orthogonal() * 2.5, m + d.orthogonal() * 2.5 + d * 7.0, m - d.orthogonal() * 2.5 + d * 7.0, m - d.orthogonal() * 2.5, m + d.orthogonal() * 2.5]), 0.45)
		O(ci, a, 1.6, 0.6)
		O(ci, b, 1.6, 0.6)


# the aft optics: the tertiary mirror, the fold mirrors and the fine steering mirror
# on the optical bench, the beam path threading them to the instrument ports, the
# baffles; the bench's mounts below
static func aft_optics(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var bench := Rect2(w * 0.02, h * 0.8, w * 0.96, h * 0.1)
	R(ci, bench, 0.6, 1.2)
	var dots := PackedVector2Array()
	for i in clampi(int(bench.size.x / 6.0), 2, 60):
		var q := Vector2(bench.position.x + 3.0 + i * 6.0, bench.get_center().y)
		dots.append(q)
		dots.append(q + Vector2(0.7, 0))
	S(ci, dots, 0.5)
	for f in [0.15, 0.85]:
		P(ci, PackedVector2Array([Vector2(w * f - 4.0, h), Vector2(w * f, bench.end.y), Vector2(w * f + 4.0, h)]), 0.45)
	# the beam: in from the top left, M3 down, fold, FSM, out to two ports
	var m3 := Vector2(w * 0.2, h * 0.55)
	var f1 := Vector2(w * 0.55, h * 0.6)
	var fsm := Vector2(w * 0.55, h * 0.25)
	var out1 := Vector2(w * 0.98, h * 0.25)
	var out2 := Vector2(w * 0.98, h * 0.6)
	P(ci, PackedVector2Array([Vector2(w * 0.2, 0), m3, f1, fsm, out1]), 0.3)
	L(ci, f1, out2, 0.18)
	# mirrors in their mounts
	for mm in [[m3, 0.6], [f1, -0.6], [fsm, 0.7]]:
		var c: Vector2 = mm[0]
		var a: float = mm[1]
		var t := Vector2.from_angle(a + PI * 0.5) * minf(w, h) * 0.08
		L(ci, c - t, c + t, 0.7, 2.2)
		var mt := Rect2(c.x - minf(w, h) * 0.05, c.y + minf(w, h) * 0.06, minf(w, h) * 0.1, bench.position.y - c.y - minf(w, h) * 0.06)
		if mt.size.y > 2.0:
			L(ci, Vector2(c.x, c.y + minf(w, h) * 0.06), Vector2(c.x, bench.position.y), 0.45, 1.4)
	# a beam splitter cube and the ports
	R(ci, Rect2(w * 0.72, h * 0.2, w * 0.06, w * 0.06), 0.55)
	for oy in [0.25, 0.6]:
		R(ci, Rect2(w * 0.9, h * oy - h * 0.06, w * 0.08, h * 0.12), 0.55)
	# baffles
	for x in [0.35, 0.65]:
		L(ci, Vector2(w * x, h * 0.05), Vector2(w * x, h * 0.18), 0.35, 1.4)


# a fast steering mirror: the mirror on its flexure, three piezo stacks behind it,
# the housing and its position sensors
static func fsm(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(w * 0.2, h * 0.08), Vector2(w * 0.2, h * 0.92), 0.8, 2.6)
	R(ci, Rect2(w * 0.24, h * 0.12, w * 0.12, h * 0.76), 0.5)
	for f in [0.25, 0.5, 0.75]:
		var y: float = h * f
		R(ci, Rect2(w * 0.36, y - h * 0.05, w * 0.34, h * 0.1), 0.5)
		E.hatch(ci, Rect2(w * 0.37, y - h * 0.045, w * 0.32, h * 0.09), 2.2, true, 0.3, 20)
	R(ci, Rect2(w * 0.7, h * 0.06, w * 0.26, h * 0.88), 0.55)
	D(ci, Vector2(w * 0.83, h * 0.2), 1.2, 0.6)
	D(ci, Vector2(w * 0.83, h * 0.8), 1.2, 0.6)


# an infrared camera: its dewar (vacuum jacket, the cold finger to the detector),
# the filter wheel, the lens barrel, the cryocooler on its back, the readout box
static func ir_camera(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var dw := Rect2(w * 0.3, h * 0.16, w * 0.46, h * 0.68)
	R(ci, dw, 0.6, 1.2)
	R(ci, E.inset(dw, 3.0), 0.25)
	var det := Rect2(dw.position.x + 4.0, dw.get_center().y - dw.size.y * 0.2, 3.0, dw.size.y * 0.4)
	R(ci, det, 0.7)
	L(ci, Vector2(det.end.x, dw.get_center().y), Vector2(dw.end.x - 4.0, dw.get_center().y), 0.45, 1.6)
	O(ci, Vector2(dw.position.x - w * 0.06, dw.get_center().y), minf(w * 0.08, h * 0.3), 0.5)
	for k in 6:
		O(ci, Vector2(dw.position.x - w * 0.06, dw.get_center().y) + Vector2.from_angle(TAU * k / 6.0) * minf(w * 0.08, h * 0.3) * 0.6, minf(w * 0.08, h * 0.3) * 0.22, 0.3)
	# lens barrel
	P(ci, PackedVector2Array([Vector2(dw.position.x - w * 0.14, dw.get_center().y - h * 0.16), Vector2(2, dw.get_center().y - h * 0.22), Vector2(2, dw.get_center().y + h * 0.22), Vector2(dw.position.x - w * 0.14, dw.get_center().y + h * 0.16)]), 0.55)
	for f in [0.25, 0.55]:
		A(ci, Vector2(w * f * 0.3 + 4.0, dw.get_center().y), h * 0.2, -0.9, 0.9, 0.4)
	# cryocooler and readout box
	R(ci, Rect2(dw.end.x, dw.get_center().y - h * 0.12, w * 0.16, h * 0.24), 0.5)
	E.hatch(ci, Rect2(dw.end.x + 2.0, dw.get_center().y - h * 0.1, w * 0.12, h * 0.2), 2.5, true, 0.25, 12)
	R(ci, Rect2(dw.position.x + dw.size.x * 0.2, dw.end.y, dw.size.x * 0.6, h * 0.12), 0.45)


# a spectrograph: the slit, the collimator mirror, the diffraction grating (ruled),
# the camera optics and the detector, all on its bench under the light-tight cover
static func spectrograph(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.45)
	L(ci, Vector2(1, h * 0.86), Vector2(w - 1, h * 0.86), 0.5, 1.4)
	var slit := Vector2(w * 0.06, h * 0.3)
	L(ci, slit + Vector2(0, -h * 0.08), slit + Vector2(0, -1.0), 0.7, 1.6)
	L(ci, slit + Vector2(0, 1.0), slit + Vector2(0, h * 0.08), 0.7, 1.6)
	var col := Vector2(w * 0.86, h * 0.3)
	A(ci, col + Vector2(w * 0.2, 0), w * 0.2, PI - 0.5, PI + 0.5, 0.65, 1.8)
	var gr := Vector2(w * 0.45, h * 0.62)
	var gt := Vector2.from_angle(0.5) * h * 0.18
	L(ci, gr - gt, gr + gt, 0.7, 2.0)
	var segs := PackedVector2Array()
	for k in 7:
		var q: Vector2 = (gr - gt).lerp(gr + gt, (k + 0.5) / 7.0)
		segs.append(q)
		segs.append(q + Vector2.from_angle(0.5 + PI * 0.5) * 2.5)
	S(ci, segs, 0.45)
	P(ci, PackedVector2Array([slit, col + Vector2(-2, 0), gr]), 0.25)
	var cam := Vector2(w * 0.16, h * 0.68)
	L(ci, gr, cam, 0.25)
	L(ci, gr, cam + Vector2(0, -h * 0.08), 0.2)
	L(ci, gr, cam + Vector2(0, h * 0.08), 0.2)
	for k in 2:
		A(ci, Vector2(w * (0.28 - k * 0.04) + h * 0.1, h * 0.68), h * 0.12, PI - 0.7, PI + 0.7, 0.45)
	R(ci, Rect2(w * 0.04, h * 0.58, w * 0.05, h * 0.2), 0.65)


# a fine guidance sensor: the pick-off mirror, the relay optics, the two guide
# detectors on their focus mechanisms, the electronics box
static func fgs(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.04, w * 0.92, h * 0.62), 0.5)
	L(ci, Vector2(w * 0.1, h * 0.1), Vector2(w * 0.24, h * 0.28), 0.7, 2.0)
	P(ci, PackedVector2Array([Vector2(w * 0.17, 0), Vector2(w * 0.17, h * 0.19), Vector2(w * 0.86, h * 0.19)]), 0.25)
	for f in [0.4, 0.55]:
		A(ci, Vector2(w * f + h * 0.12, h * 0.19), h * 0.12, PI - 0.6, PI + 0.6, 0.45)
	for k in 2:
		var d := Rect2(w * (0.66 + k * 0.14), h * 0.1, w * 0.1, h * 0.3)
		R(ci, d, 0.55)
		R(ci, Rect2(d.position.x + 1.5, d.position.y + d.size.y * 0.3, 2.0, d.size.y * 0.4), 0.7)
	L(ci, Vector2(w * 0.86, h * 0.19), Vector2(w * 0.86, h * 0.4), 0.2)
	var eb := Rect2(w * 0.1, h * 0.7, w * 0.8, h * 0.26)
	R(ci, eb, 0.45)
	E.hatch(ci, sub(eb, 0.05, 0.2, 0.5, 0.8), 3.0, true, 0.22, 20)
	for k in 3:
		O(ci, eb.position + eb.size * Vector2(0.62 + k * 0.12, 0.5), minf(eb.size.y * 0.2, 3.0), 0.5)


# a Shack-Hartmann wavefront sensor: the pick-off, the collimating lens, the
# lenslet array (a column of little lenses), the camera behind it seeing the spot
# grid, the reference source and the processing electronics, on a vertical bench
static func wfs(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.45)
	var ax: float = w * 0.45
	# the beam down the bench
	L(ci, Vector2(ax, 0), Vector2(ax, h * 0.62), 0.22)
	# collimator
	A(ci, Vector2(ax, h * 0.12 + w * 0.35), w * 0.35, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 0.55, 1.4)
	A(ci, Vector2(ax, h * 0.12 - w * 0.35 + 6.0), w * 0.35, PI * 0.5 - 0.6, PI * 0.5 + 0.6, 0.55, 1.4)
	# lenslet array: a row of small lenses across the beam
	var la: float = h * 0.36
	var n := clampi(int(w * 0.6 / 4.0), 4, 16)
	for k in n:
		var x: float = ax - w * 0.3 + (k + 0.5) * w * 0.6 / n
		A(ci, Vector2(x, la), w * 0.3 / n, PI, TAU, 0.55)
		L(ci, Vector2(x, la), Vector2(x, h * 0.5), 0.15)
	L(ci, Vector2(ax - w * 0.32, la), Vector2(ax + w * 0.32, la), 0.5)
	# camera with its spot grid
	var cam := Rect2(ax - w * 0.32, h * 0.5, w * 0.64, h * 0.16)
	R(ci, cam, 0.6, 1.2)
	var dots := PackedVector2Array()
	for k in n:
		for j in 2:
			var q := Vector2(cam.position.x + (k + 0.5) * cam.size.x / n + (0.8 if (k + j) % 3 == 0 else 0.0), cam.position.y + cam.size.y * (0.35 + j * 0.3))
			dots.append(q)
			dots.append(q + Vector2(0.8, 0))
	S(ci, dots, 0.7)
	# reference source and electronics
	R(ci, Rect2(w * 0.78, h * 0.16, w * 0.16, h * 0.1), 0.5)
	L(ci, Vector2(w * 0.78, h * 0.21), Vector2(ax, h * 0.21), 0.2)
	var eb := Rect2(w * 0.1, h * 0.72, w * 0.8, h * 0.24)
	R(ci, eb, 0.5)
	E.screen_face(ci, sub(eb, 0.06, 0.15, 0.5, 0.85), 2, 0.35)
	E.hatch(ci, sub(eb, 0.58, 0.2, 0.94, 0.8), 3.0, true, 0.22, 16)


# a mirror recoater: the vacuum chamber with its door, the evaporation sources and
# their shutter, the segment held face-down in its fixture, the pumps
static func recoater(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ch := Rect2(w * 0.06, h * 0.08, w * 0.7, h * 0.76)
	R(ci, ch, 0.6, 1.2)
	E.corner_bolts(ci, ch, 3.0, 0.5)
	var seg := Rect2(ch.position.x + ch.size.x * 0.2, ch.position.y + ch.size.y * 0.12, ch.size.x * 0.6, ch.size.y * 0.08)
	R(ci, seg, 0.55)
	L(ci, Vector2(seg.position.x, seg.end.y), Vector2(seg.end.x, seg.end.y), 0.8, 2.0)
	for k in 3:
		var sc := Vector2(ch.position.x + ch.size.x * (0.3 + k * 0.2), ch.end.y - ch.size.y * 0.15)
		A(ci, sc, ch.size.x * 0.05, PI, TAU, 0.6)
		L(ci, sc, sc + Vector2(0, ch.size.y * 0.1), 0.45)
		for e in [-0.3, 0.0, 0.3]:
			L(ci, sc + Vector2(0, -ch.size.x * 0.06), sc + Vector2.from_angle(-PI * 0.5 + e) * ch.size.y * 0.4, 0.12)
	L(ci, Vector2(ch.position.x + ch.size.x * 0.2, ch.position.y + ch.size.y * 0.6), Vector2(ch.end.x - ch.size.x * 0.2, ch.position.y + ch.size.y * 0.6), 0.4, 1.4)
	R(ci, Rect2(w * 0.78, h * 0.3, w * 0.18, h * 0.4), 0.5)
	E.hatch(ci, Rect2(w * 0.8, h * 0.34, w * 0.14, h * 0.32), 3.0, false, 0.25, 12)
	L(ci, Vector2(ch.end.x, h * 0.5), Vector2(w * 0.78, h * 0.5), 0.45, 1.4)
	L(ci, Vector2(2, h * 0.96), Vector2(w - 2, h * 0.96), 0.5, 1.4)


# a reaction wheel: the flywheel's rim and web in its housing, the hub on the
# motor's bearings, the stator coils, the housing's bolt flange
static func reaction_wheel(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.46
	O(ci, c, rad, 0.6, 1.2)
	for k in 12:
		D(ci, c + Vector2.from_angle(TAU * k / 12.0) * rad * 0.94, 0.8, 0.5)
	O(ci, c, rad * 0.8, 0.55, 1.4)
	O(ci, c, rad * 0.7, 0.3)
	for k in 6:
		var a: float = TAU * k / 6.0
		L(ci, c + Vector2.from_angle(a) * rad * 0.28, c + Vector2.from_angle(a) * rad * 0.7, 0.3)
	O(ci, c, rad * 0.28, 0.5)
	for k in 9:
		var a: float = TAU * k / 9.0
		R(ci, Rect2(c + Vector2.from_angle(a) * rad * 0.19 - Vector2(1.5, 1.5), Vector2(3, 3)), 0.4)
	D(ci, c, 1.4, 0.6)


# a star tracker: its long sun baffle with the vanes inside, the optical head and
# the electronics box at the root
static func star_tracker(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var bt := Rect2(w * 0.24, 1, w * 0.52, h * 0.6)
	P(ci, PackedVector2Array([Vector2(bt.position.x - w * 0.1, bt.position.y), Vector2(bt.position.x, bt.end.y), Vector2(bt.end.x, bt.end.y), Vector2(bt.end.x + w * 0.1, bt.position.y)]), 0.6)
	var segs := PackedVector2Array()
	for k in 4:
		var y: float = bt.position.y + bt.size.y * (0.2 + k * 0.2)
		var inset_x: float = w * 0.1 * (1.0 - (y - bt.position.y) / bt.size.y)
		segs.append(Vector2(bt.position.x - inset_x + 1.0, y))
		segs.append(Vector2(bt.position.x + bt.size.x * 0.3, y))
		segs.append(Vector2(bt.end.x - bt.size.x * 0.3, y))
		segs.append(Vector2(bt.end.x + inset_x - 1.0, y))
	S(ci, segs, 0.4)
	R(ci, Rect2(w * 0.18, h * 0.62, w * 0.64, h * 0.34), 0.6)
	O(ci, Vector2(w * 0.5, h * 0.62), w * 0.14, 0.5)


# ================================================================== DC-84 Deep Mind

# a server rack standing in its immersion tank: blade servers on edge, their heat
# sinks, the dielectric's surface across them, the lifting lugs and the power
# shelf above the fluid
static func immersion_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var fl: float = h * 0.18
	R(ci, Rect2(1, 1, w - 2, h * 0.1), 0.55)
	for f in [0.15, 0.85]:
		A(ci, Vector2(w * f, 1.0), minf(w * 0.04, 4.0), PI, TAU, 0.6, 1.4)
	var pts := PackedVector2Array()
	var nw := clampi(int(w / 6.0), 3, 60)
	for k in nw + 1:
		pts.append(Vector2(w * k / nw, fl + (1.0 if k % 2 == 0 else -1.0)))
	P(ci, pts, 0.45)
	E.F(ci, Rect2(1, fl, w - 2, h - fl - 1.0), 0.03)
	var n := clampi(int(w / 7.0), 3, 40)
	var bw: float = (w - 4.0) / n
	for k in n:
		var b := Rect2(2.0 + k * bw + 0.5, h * 0.14, bw - 1.0, h * 0.82)
		R(ci, b, 0.4)
		E.hatch(ci, Rect2(b.position.x + 1.0, b.position.y + b.size.y * 0.35, b.size.x - 2.0, b.size.y * 0.3), 2.0, false, 0.22, 20)
		D(ci, Vector2(b.get_center().x, b.position.y + 3.0), 0.8, 0.7)
		R(ci, Rect2(b.position.x + 1.0, b.end.y - b.size.y * 0.15, b.size.x - 2.0, b.size.y * 0.1), 0.3)


# a coolant distribution unit: the brazed plate heat exchanger (its plate stack),
# the two pumps, the filter, the expansion vessel, the controller with its display
static func cdu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.45)
	var hx := Rect2(w * 0.06, h * 0.08, w * 0.28, h * 0.6)
	R(ci, hx, 0.6, 1.2)
	E.hatch(ci, E.inset(hx, 1.5), 2.2, true, 0.3, 40)
	for f in [0.15, 0.85]:
		O(ci, Vector2(hx.get_center().x, hx.position.y + hx.size.y * f), minf(hx.size.x * 0.18, 4.0), 0.55)
	for k in 2:
		var pc := Vector2(w * (0.48 + k * 0.22), h * 0.74)
		var pr: float = minf(w * 0.08, h * 0.1)
		O(ci, pc, pr, 0.55)
		E.impeller(ci, pc, pr * 0.75, 0.4)
		R(ci, Rect2(pc.x - pr * 0.6, pc.y - pr * 3.2, pr * 1.2, pr * 2.2), 0.5)
		E.hatch(ci, Rect2(pc.x - pr * 0.5, pc.y - pr * 3.1, pr, pr * 2.0), 2.5, false, 0.2, 10)
	var ev := Rect2(w * 0.84, h * 0.08, w * 0.1, h * 0.36)
	E.vessel_v(ci, ev, 0.5)
	R(ci, Rect2(w * 0.08, h * 0.74, w * 0.22, h * 0.18), 0.5)
	E.pleats(ci, Rect2(w * 0.1, h * 0.76, w * 0.18, h * 0.14), 3.0, true, 0.3)
	E.screen_face(ci, Rect2(w * 0.42, h * 0.08, w * 0.34, h * 0.18), 0, 0.4)
	L(ci, Vector2(hx.end.x, hx.position.y + hx.size.y * 0.85), Vector2(w * 0.48, hx.position.y + hx.size.y * 0.85), 0.4, 1.4)


# a dry cooler: the finned coil in a V under its row of fans, the headers, the legs
static func dry_cooler(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / (h * 0.9)), 1, 8)
	var cw: float = w / n
	for i in n:
		var x0: float = i * cw
		var top: float = h * 0.18
		P(ci, PackedVector2Array([Vector2(x0 + cw * 0.06, top), Vector2(x0 + cw * 0.5, h * 0.8), Vector2(x0 + cw * 0.94, top)]), 0.6, 1.2)
		var segs := PackedVector2Array()
		for k in 7:
			var t: float = (k + 1) / 8.0
			var a := Vector2(x0 + cw * 0.06, top).lerp(Vector2(x0 + cw * 0.5, h * 0.8), t)
			var b := Vector2(x0 + cw * 0.94, top).lerp(Vector2(x0 + cw * 0.5, h * 0.8), t)
			segs.append(a + Vector2(-2, 0))
			segs.append(a + Vector2(2, 0))
			segs.append(b + Vector2(-2, 0))
			segs.append(b + Vector2(2, 0))
		S(ci, segs, 0.35)
		R(ci, Rect2(x0 + cw * 0.1, 1, cw * 0.8, top - 2.0), 0.5)
		E.fan(ci, Vector2(x0 + cw * 0.5, top * 0.5), minf(cw * 0.36, top * 0.42), 5, 0.4)
	L(ci, Vector2(2, h * 0.84), Vector2(w - 2, h * 0.84), 0.5, 1.4)
	for f in [0.05, 0.95]:
		L(ci, Vector2(w * f, h * 0.84), Vector2(w * f, h - 1.0), 0.5, 1.4)


# a storage array: disk shelves stacked, each a row of drive carriers with their
# lights, the controller shelf at the top
static func storage_array(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(2, 1), Vector2(2, h - 1), 0.5)
	L(ci, Vector2(w - 2, 1), Vector2(w - 2, h - 1), 0.5)
	var ctl := Rect2(4, 2, w - 8, h * 0.12)
	R(ci, ctl, 0.55)
	for k in 2:
		R(ci, Rect2(ctl.position.x + 2.0 + k * ctl.size.x * 0.5, ctl.position.y + 2.0, ctl.size.x * 0.46, ctl.size.y - 4.0), 0.4)
	var sh: float = clampf(h / 8.0, 10.0, 20.0)
	var y: float = ctl.end.y + 2.0
	while y + sh < h - 2.0:
		var b := Rect2(4, y, w - 8, sh - 2.0)
		R(ci, b, 0.42)
		var nd := clampi(int(b.size.x / 3.6), 4, 40)
		var segs := PackedVector2Array()
		for i in nd:
			var x: float = b.position.x + (i + 0.5) * b.size.x / nd
			segs.append(Vector2(x, b.position.y + 1.5))
			segs.append(Vector2(x, b.end.y - 3.0))
		S(ci, segs, 0.25)
		for i in range(0, nd, 2):
			D(ci, Vector2(b.position.x + (i + 0.5) * b.size.x / nd, b.end.y - 1.5), 0.6, 0.7)
		y += sh


# a core switch chassis: the supervisor modules, the line cards with their rows of
# ports and status lights, the fan trays, the power supplies at the foot
static func switch_chassis(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.5)
	E.hatch(ci, Rect2(4, 3, w - 8, h * 0.06), 3.0, true, 0.3, 40)
	var n := clampi(int(h * 0.74 / 9.0), 4, 18)
	var lh: float = h * 0.74 / n
	for k in n:
		var b := Rect2(4, h * 0.1 + k * lh, w - 8, lh - 1.5)
		R(ci, b, 0.4)
		if k < 2:
			E.screen_face(ci, Rect2(b.position.x + 2.0, b.position.y + 1.0, b.size.x * 0.3, b.size.y - 2.0), 3, 0.3)
			continue
		var np := clampi(int(b.size.x * 0.8 / 3.2), 4, 48)
		var segs := PackedVector2Array()
		for i in np:
			var x: float = b.position.x + b.size.x * 0.15 + i * b.size.x * 0.8 / np
			segs.append(Vector2(x, b.get_center().y - 1.0))
			segs.append(Vector2(x, b.get_center().y + 1.0))
		S(ci, segs, 0.5)
		D(ci, Vector2(b.position.x + 3.0, b.get_center().y), 0.7, 0.7)
	for k in 3:
		R(ci, Rect2(4 + k * (w - 8) / 3.0 + 1.0, h * 0.86, (w - 8) / 3.0 - 2.0, h * 0.11), 0.45)


# a drive in its carrier: the latch handle, the activity light, the label window
static func drive_carrier(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	R(ci, Rect2(w * 0.08, h * 0.2, w * 0.5, h * 0.6), 0.4)
	E.hatch(ci, Rect2(w * 0.1, h * 0.25, w * 0.46, h * 0.5), 2.5, true, 0.25, 12)
	L(ci, Vector2(w * 0.66, h * 0.3), Vector2(w * 0.94, h * 0.5), 0.6, 1.4)
	D(ci, Vector2(w * 0.8, h * 0.78), 0.8, 0.8)


# ================================================================== ARK-01 Voyager

# a pressurised-water reactor cut through: the vessel with its hemispherical bottom
# head and the bolted closure head (the stud ring), the control rod drive housings
# standing on the head, the inlet and outlet nozzles, the core barrel, the core of
# fuel assemblies (the rods in some of them pulled), the lower plenum
static func pwr_core(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vw: float = minf(w * 0.66, h * 0.6)
	var cx: float = w * 0.5
	var vx0: float = cx - vw * 0.5
	var vx1: float = cx + vw * 0.5
	var hry: float = minf(vw * 0.32, h * 0.1)
	var head_y: float = h * 0.2 + hry
	var top: float = head_y + h * 0.05
	var bry: float = minf(vw * 0.4, h * 0.12)
	var bot: float = h * 0.97 - bry
	# vessel walls and the bottom head (the cladding inside)
	for t in [0.0, 3.5]:
		var al: float = 0.6 if t == 0.0 else 0.32
		L(ci, Vector2(vx0 + t, top), Vector2(vx0 + t, bot), al, 1.4 if t == 0.0 else 1.0)
		L(ci, Vector2(vx1 - t, top), Vector2(vx1 - t, bot), al, 1.4 if t == 0.0 else 1.0)
		E._head(ci, Vector2(cx, bot), vw * 0.5 - t, bry - t, false, al)
	# the closure flange with its stud ring, the closure head
	R(ci, Rect2(vx0 - w * 0.04, head_y, vw + w * 0.08, top - head_y), 0.65, 1.4)
	E.bolts(ci, Vector2(vx0 - w * 0.02, (head_y + top) * 0.5), Vector2(vx1 + w * 0.02, (head_y + top) * 0.5), clampi(int(vw / 6.0), 6, 30), 0.6, 1.0)
	E._head(ci, Vector2(cx, head_y), vw * 0.5, hry, true, 0.6)
	# CRDM housings standing on the head, their cooling shroud's top ring
	var nd := clampi(int(vw / 9.0), 3, 13)
	var segs := PackedVector2Array()
	for k in nd:
		var x: float = vx0 + vw * (0.15 + 0.7 * (k + 0.5) / nd)
		var u: float = (x - cx) / (vw * 0.5)
		var y0: float = head_y - hry * sqrt(maxf(0.0, 1.0 - u * u))
		segs.append(Vector2(x - 1.5, y0))
		segs.append(Vector2(x - 1.5, h * 0.03))
		segs.append(Vector2(x + 1.5, y0))
		segs.append(Vector2(x + 1.5, h * 0.03))
	S(ci, segs, 0.4)
	L(ci, Vector2(vx0 + vw * 0.12, h * 0.03), Vector2(vx1 - vw * 0.12, h * 0.03), 0.5, 1.4)
	R(ci, Rect2(vx0 + vw * 0.1, h * 0.08, vw * 0.8, h * 0.05), 0.35)
	# nozzles: hot leg out one side, cold leg in the other
	for sg in [-1.0, 1.0]:
		var x: float = vx0 if sg < 0.0 else vx1
		var ny: float = top + (bot - top) * 0.12
		var nh: float = minf(h * 0.04, vw * 0.06)
		L(ci, Vector2(x, ny - nh), Vector2(x + sg * (w * 0.5 - vw * 0.5 - 2.0), ny - nh), 0.55, 1.2)
		L(ci, Vector2(x, ny + nh), Vector2(x + sg * (w * 0.5 - vw * 0.5 - 2.0), ny + nh), 0.55, 1.2)
	# core barrel and the core
	var cb0: float = vx0 + vw * 0.1
	var cb1: float = vx1 - vw * 0.1
	L(ci, Vector2(cb0, top + 2.0), Vector2(cb0, bot + bry * 0.3), 0.45)
	L(ci, Vector2(cb1, top + 2.0), Vector2(cb1, bot + bry * 0.3), 0.45)
	var core := Rect2(cb0 + 3.0, top + (bot - top) * 0.3, cb1 - cb0 - 6.0, (bot - top) * 0.6)
	R(ci, core, 0.55)
	var na := clampi(int(core.size.x / 7.0), 3, 15)
	var fa := PackedVector2Array()
	for k in na:
		var x0: float = core.position.x + k * core.size.x / na
		fa.append(Vector2(x0, core.position.y))
		fa.append(Vector2(x0, core.end.y))
		var nr := clampi(int(core.size.x / na / 2.2), 1, 4)
		for e in nr:
			var x: float = x0 + (e + 0.5) * core.size.x / na / nr
			fa.append(Vector2(x, core.position.y + 2.0))
			fa.append(Vector2(x, core.end.y - 2.0))
	S(ci, fa, 0.25)
	# control rods: some in, some drawn up into the upper internals
	for k in range(1, na, 2):
		var x: float = core.position.x + (k + 0.5) * core.size.x / na
		var tip: float = core.position.y + (core.size.y * 0.8 if k % 4 == 1 else -(bot - top) * 0.12)
		L(ci, Vector2(x, top + 2.0), Vector2(x, tip), 0.55, 1.4)
	# upper and lower core support plates
	L(ci, Vector2(cb0, core.position.y - 3.0), Vector2(cb1, core.position.y - 3.0), 0.4, 1.4)
	L(ci, Vector2(cb0, core.end.y + 3.0), Vector2(cb1, core.end.y + 3.0), 0.4, 1.4)


# a reactor coolant pump: the canned motor standing on top with its flywheel and
# cooling jacket, the seal housing, the pump casing with suction below and the
# discharge out the side
static func rcp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.45
	var mw: float = w * 0.42
	var mot := Rect2(cx - mw * 0.5, h * 0.06, mw, h * 0.42)
	R(ci, mot, 0.6, 1.2)
	E.hatch(ci, E.inset(mot, 2.0), 3.2, true, 0.2, 24)
	R(ci, Rect2(cx - mw * 0.6, h * 0.02, mw * 1.2, h * 0.05), 0.55)
	L(ci, Vector2(cx - mw * 0.55, h * 0.3), Vector2(cx + mw * 0.55, h * 0.3), 0.45, 1.4)
	R(ci, Rect2(cx - mw * 0.3, mot.end.y, mw * 0.6, h * 0.12), 0.55)
	L(ci, Vector2(cx, mot.end.y), Vector2(cx, mot.end.y + h * 0.12), 0.5, 1.4)
	var pc := Vector2(cx, h * 0.76)
	var pr: float = minf(w * 0.3, h * 0.18)
	P(ci, PackedVector2Array([pc + Vector2(-pr, -pr * 0.6), pc + Vector2(-pr * 0.8, -pr), pc + Vector2(pr * 0.8, -pr), pc + Vector2(pr, -pr * 0.6), pc + Vector2(pr, pr * 0.6), pc + Vector2(pr * 0.6, pr), pc + Vector2(-pr * 0.6, pr), pc + Vector2(-pr, pr * 0.6), pc + Vector2(-pr, -pr * 0.6)]), 0.6, 1.2)
	E.impeller(ci, pc, pr * 0.6, 0.45)
	L(ci, Vector2(pc.x - pr * 0.3, pc.y + pr), Vector2(pc.x - pr * 0.3, h), 0.5)
	L(ci, Vector2(pc.x + pr * 0.3, pc.y + pr), Vector2(pc.x + pr * 0.3, h), 0.5)
	L(ci, Vector2(pc.x + pr, pc.y - pr * 0.35), Vector2(w - 2.0, pc.y - pr * 0.35), 0.5, 1.2)
	L(ci, Vector2(pc.x + pr, pc.y + pr * 0.25), Vector2(w - 2.0, pc.y + pr * 0.25), 0.5, 1.2)
	E.flange(ci, Vector2(w - 3.0, pc.y - pr * 0.05), Vector2.RIGHT, pr * 0.42, 0.55)


# the pressuriser: its tall vessel, the steam space over the water line, the spray
# nozzle in the top head, the relief and safety valves on top, the immersion
# heaters through the bottom head, the surge line
static func pressurizer(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vs := Rect2(w * 0.18, h * 0.1, w * 0.64, h * 0.78)
	var sh := E.vessel_v(ci, vs, 0.6)
	var lv: float = sh.position.y + sh.size.y * 0.42
	var pts := PackedVector2Array()
	var nw := clampi(int(sh.size.x / 5.0), 3, 20)
	for k in nw + 1:
		pts.append(Vector2(sh.position.x + sh.size.x * k / nw, lv + (1.0 if k % 2 == 0 else -1.0)))
	P(ci, pts, 0.45)
	E.F(ci, Rect2(sh.position.x, lv, sh.size.x, sh.end.y - lv), 0.035)
	# heaters up from the bottom head
	var segs := PackedVector2Array()
	for k in 5:
		var x: float = sh.position.x + sh.size.x * (0.2 + k * 0.15)
		segs.append(Vector2(x, vs.end.y + h * 0.04))
		segs.append(Vector2(x, sh.end.y - sh.size.y * 0.3))
	S(ci, segs, 0.4)
	# spray nozzle and the valves on top
	L(ci, Vector2(w * 0.5, vs.position.y), Vector2(w * 0.5, sh.position.y + sh.size.y * 0.08), 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.44, sh.position.y + sh.size.y * 0.1), Vector2(w * 0.5, sh.position.y + sh.size.y * 0.06), Vector2(w * 0.56, sh.position.y + sh.size.y * 0.1)]), 0.45)
	for f in [0.32, 0.68]:
		L(ci, Vector2(w * f, vs.position.y + h * 0.02), Vector2(w * f, h * 0.03), 0.5)
		R(ci, Rect2(w * f - 3.0, h * 0.01, 6.0, h * 0.05), 0.55)
	L(ci, Vector2(w * 0.5, vs.end.y), Vector2(w * 0.5, h - 1.0), 0.55, 1.4)


# a control rod drive mechanism: the pressure housing, the latch and the lift and
# hold coil stacks round it, the rod position indicator coil above, the drive rod
static func crdm(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	L(ci, Vector2(cx - w * 0.12, 0), Vector2(cx - w * 0.12, h), 0.55)
	L(ci, Vector2(cx + w * 0.12, 0), Vector2(cx + w * 0.12, h), 0.55)
	L(ci, Vector2(cx, 0), Vector2(cx, h), 0.3)
	for k in 3:
		var c := Rect2(cx - w * 0.36, h * (0.52 + k * 0.14), w * 0.72, h * 0.11)
		R(ci, c, 0.55)
		E.hatch(ci, Rect2(c.position.x + 1.5, c.position.y + 1.0, c.size.x - 3.0, c.size.y - 2.0), 2.5, false, 0.25, 10)
	var rpi := Rect2(cx - w * 0.26, h * 0.08, w * 0.52, h * 0.36)
	R(ci, rpi, 0.5)
	E.hatch(ci, E.inset(rpi, 1.5), 3.0, false, 0.18, 30)
	R(ci, Rect2(cx - w * 0.4, h * 0.94, w * 0.8, h * 0.05), 0.6)


# a steam turbine set: the high-pressure cylinder and the bigger low-pressure one
# on one shaft, their blade rows growing longer toward the exhaust, the steam chest
# and governor valves on top, the bearings, the exhaust down to the condenser
static func steam_turbine(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.5
	var segs := PackedVector2Array()
	# HP: small, LP: double-flow, large
	var hp0: float = w * 0.04
	var hp1: float = w * 0.36
	var lp0: float = w * 0.42
	var lp1: float = w * 0.96
	P(ci, PackedVector2Array([Vector2(hp0, ay - h * 0.14), Vector2(hp1, ay - h * 0.24), Vector2(hp1, ay + h * 0.24), Vector2(hp0, ay + h * 0.14), Vector2(hp0, ay - h * 0.14)]), 0.6, 1.2)
	var lc: float = (lp0 + lp1) * 0.5
	P(ci, PackedVector2Array([Vector2(lp0, ay - h * 0.2), Vector2(lc - w * 0.04, ay - h * 0.26), Vector2(lc + w * 0.04, ay - h * 0.26), Vector2(lp1, ay - h * 0.2), Vector2(lp1, ay + h * 0.36), Vector2(lp0, ay + h * 0.36), Vector2(lp0, ay - h * 0.2)]), 0.6, 1.2)
	L(ci, Vector2(1, ay), Vector2(w - 1, ay), 0.35)
	var n := clampi(int((hp1 - hp0) / 5.0), 3, 14)
	for k in n:
		var x: float = hp0 + (k + 0.5) * (hp1 - hp0) / n
		var bl: float = lerpf(h * 0.1, h * 0.2, float(k) / n)
		segs.append(Vector2(x, ay - bl))
		segs.append(Vector2(x, ay + bl))
	n = clampi(int((lp1 - lp0) / 10.0), 2, 10)
	for k in n:
		var t: float = absf((k + 0.5) / n - 0.5) * 2.0
		var x: float = lp0 + (k + 0.5) * (lp1 - lp0) / n
		var bl: float = lerpf(h * 0.08, h * 0.24, t)
		segs.append(Vector2(x, ay - bl))
		segs.append(Vector2(x, ay + bl))
	S(ci, segs, 0.35)
	# steam chest and valves, crossover pipe
	R(ci, Rect2(hp0 + w * 0.04, h * 0.06, w * 0.14, h * 0.12), 0.55)
	for k in 2:
		E.wheel(ci, Vector2(hp0 + w * (0.07 + k * 0.08), h * 0.04), minf(h * 0.03, 4.0), 0.5)
	P(ci, PackedVector2Array([Vector2(hp1 - w * 0.04, ay - h * 0.24), Vector2(hp1 - w * 0.04, h * 0.1), Vector2(lc, h * 0.1), Vector2(lc, ay - h * 0.26)]), 0.5, 1.4)
	# bearings and the exhaust hood to the condenser
	for x in [hp0, hp1 + w * 0.03, lp1]:
		R(ci, Rect2(x - 3.0, ay - h * 0.06, 6.0, h * 0.12), 0.55)
	P(ci, PackedVector2Array([Vector2(lp0 + w * 0.06, ay + h * 0.36), Vector2(lp0 + w * 0.1, h - 1.0), Vector2(lp1 - w * 0.1, h - 1.0), Vector2(lp1 - w * 0.06, ay + h * 0.36)]), 0.45)


# a surface condenser: the shell, the tube bundle (its tubes end-on), the tube
# sheets and waterboxes at the ends, the exhaust neck in the top, the hotwell
static func condenser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var sh := E.vessel_h(ci, Rect2(w * 0.02, h * 0.18, w * 0.96, h * 0.6), 0.6)
	var dots := PackedVector2Array()
	var nx := clampi(int(sh.size.x / 5.0), 3, 60)
	var ny := clampi(int(sh.size.y * 0.6 / 5.0), 2, 12)
	for j in ny:
		for i in nx:
			var q := Vector2(sh.position.x + (i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * sh.size.x / (nx + 0.5), sh.position.y + sh.size.y * 0.25 + j * sh.size.y * 0.6 / ny)
			dots.append(q)
			dots.append(q + Vector2(0.9, 0))
	S(ci, dots, 0.4)
	P(ci, PackedVector2Array([Vector2(w * 0.3, sh.position.y), Vector2(w * 0.34, h * 0.02), Vector2(w * 0.66, h * 0.02), Vector2(w * 0.7, sh.position.y)]), 0.5)
	R(ci, Rect2(w * 0.35, sh.end.y, w * 0.3, h * 0.18), 0.5)
	L(ci, Vector2(w * 0.5, sh.end.y + h * 0.18), Vector2(w * 0.5, h), 0.5)


# a ring's despin brake: the brake disc on the hub, the calipers with their pads
# and hydraulic cylinders, the cooling fins on the disc
static func despin_brake(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.42, h * 0.5)
	var rad: float = minf(w * 0.4, h * 0.46)
	O(ci, c, rad, 0.6, 1.4)
	O(ci, c, rad * 0.62, 0.45)
	var segs := PackedVector2Array()
	for k in 24:
		var a: float = TAU * k / 24.0
		segs.append(c + Vector2.from_angle(a) * rad * 0.66)
		segs.append(c + Vector2.from_angle(a + 0.12) * rad * 0.96)
	S(ci, segs, 0.25)
	O(ci, c, rad * 0.2, 0.55)
	for k in 6:
		D(ci, c + Vector2.from_angle(TAU * k / 6.0) * rad * 0.42, 1.0, 0.55)
	for a in [-0.5, 0.5]:
		var q: Vector2 = c + Vector2.from_angle(a) * rad * 0.82
		var t := Vector2.from_angle(a)
		P(ci, PackedVector2Array([q - t * rad * 0.22 + t.orthogonal() * rad * 0.18, q + t * rad * 0.34 + t.orthogonal() * rad * 0.18, q + t * rad * 0.34 - t.orthogonal() * rad * 0.18, q - t * rad * 0.22 - t.orthogonal() * rad * 0.18, q - t * rad * 0.22 + t.orthogonal() * rad * 0.18]), 0.6, 1.2)
		L(ci, q + t * rad * 0.34, Vector2(w - 2.0, q.y), 0.4)


# a slip ring: the stack of rings on the rotating side, the brush block on the
# fixed side with a brush on each ring, the cables out of both
static func slip_ring(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var st := Rect2(w * 0.18, h * 0.08, w * 0.4, h * 0.84)
	R(ci, st, 0.55)
	var n := clampi(int(st.size.y / 5.0), 3, 14)
	for k in n:
		var y: float = st.position.y + (k + 0.5) * st.size.y / n
		L(ci, Vector2(st.position.x - 2.0, y), Vector2(st.end.x + 2.0, y), 0.55, 1.6)
		L(ci, Vector2(st.end.x + 2.0, y), Vector2(w * 0.74, y), 0.35)
	R(ci, Rect2(w * 0.74, h * 0.1, w * 0.16, h * 0.8), 0.55)
	L(ci, Vector2(w * 0.38, 0), Vector2(w * 0.38, h), 0.25)
	for f in [0.25, 0.75]:
		L(ci, Vector2(w * 0.9, h * f), Vector2(w - 1.0, h * f), 0.4)
		L(ci, Vector2(1, h * f), Vector2(st.position.x, h * f), 0.4)


# a rotary seal between the turning hub and the fixed spine: the labyrinth of teeth
# from either side, the buffer gas groove, the seal housing bolts
static func rotary_seal(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h * 0.3), 0.55)
	R(ci, Rect2(1, h * 0.7, w - 2, h * 0.29), 0.55)
	var n := clampi(int(w / 6.0), 3, 30)
	var segs := PackedVector2Array()
	for k in n:
		var x: float = (k + 0.5) * w / n
		if k % 2 == 0:
			segs.append(Vector2(x, h * 0.31))
			segs.append(Vector2(x, h * 0.6))
		else:
			segs.append(Vector2(x, h * 0.69))
			segs.append(Vector2(x, h * 0.4))
	S(ci, segs, 0.5)
	R(ci, Rect2(w * 0.45, h * 0.31, w * 0.1, h * 0.08), 0.5)
	L(ci, Vector2(w * 0.5, 0), Vector2(w * 0.5, h * 0.31), 0.4)
	E.bolts(ci, Vector2(3, h * 0.15), Vector2(w - 3, h * 0.15), clampi(int(w / 9.0), 2, 12), 0.5, 0.9)
	E.bolts(ci, Vector2(3, h * 0.85), Vector2(w - 3, h * 0.85), clampi(int(w / 9.0), 2, 12), 0.5, 0.9)


# a spoke elevator car: the cage with its doors, the rack and pinion drive on the
# guide rail, the drive motor on the roof, the safety gear under the floor
static func spoke_lift(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cg := Rect2(w * 0.12, h * 0.16, w * 0.76, h * 0.72)
	R(ci, cg, 0.6, 1.2)
	L(ci, Vector2(cg.get_center().x, cg.position.y + 3.0), Vector2(cg.get_center().x, cg.end.y - 3.0), 0.4)
	R(ci, E.inset(Rect2(cg.position, Vector2(cg.size.x * 0.5, cg.size.y)), 3.0), 0.3)
	R(ci, E.inset(Rect2(cg.position + Vector2(cg.size.x * 0.5, 0), Vector2(cg.size.x * 0.5, cg.size.y)), 3.0), 0.3)
	L(ci, Vector2(w * 0.04, 0), Vector2(w * 0.04, h), 0.5, 1.4)
	var segs := PackedVector2Array()
	for k in clampi(int(h / 4.0), 3, 60):
		var y: float = 2.0 + k * 4.0
		segs.append(Vector2(w * 0.04, y))
		segs.append(Vector2(w * 0.08, y))
	S(ci, segs, 0.35)
	O(ci, Vector2(w * 0.1, h * 0.3), minf(w * 0.05, 4.0), 0.55)
	O(ci, Vector2(w * 0.1, h * 0.75), minf(w * 0.05, 4.0), 0.55)
	E.motor(ci, Rect2(w * 0.2, h * 0.02, w * 0.5, h * 0.12), false, 0.5)
	R(ci, Rect2(w * 0.2, cg.end.y, w * 0.6, h * 0.08), 0.5)


# a work vehicle in its bay: the chassis on its wheels / landing pads, the cab with
# its window, the manipulator arm folded over the deck, the cargo bed
static func work_vehicle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ch := Rect2(w * 0.04, h * 0.58, w * 0.92, h * 0.2)
	R(ci, ch, 0.6, 1.2)
	for f in [0.18, 0.5, 0.82]:
		O(ci, Vector2(w * f, h * 0.86), minf(h * 0.12, w * 0.07), 0.55)
		O(ci, Vector2(w * f, h * 0.86), minf(h * 0.05, w * 0.03), 0.4)
	var cab := PackedVector2Array([Vector2(w * 0.66, ch.position.y), Vector2(w * 0.68, h * 0.14), Vector2(w * 0.86, h * 0.14), Vector2(w * 0.96, h * 0.36), Vector2(w * 0.96, ch.position.y)])
	P(ci, cab, 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(w * 0.71, h * 0.2), Vector2(w * 0.84, h * 0.2), Vector2(w * 0.91, h * 0.36), Vector2(w * 0.71, h * 0.36), Vector2(w * 0.71, h * 0.2)]), 0.45)
	var b := Vector2(w * 0.12, ch.position.y)
	var e := Vector2(w * 0.3, h * 0.2)
	var t := Vector2(w * 0.52, h * 0.34)
	L(ci, b, e, 0.55, 2.0)
	L(ci, e, t, 0.55, 1.6)
	O(ci, b, 2.5, 0.6)
	O(ci, e, 2.0, 0.6)
	P(ci, PackedVector2Array([t + Vector2(-2, 6), t, t + Vector2(4, 5)]), 0.55)
	R(ci, Rect2(w * 0.3, h * 0.42, w * 0.34, ch.position.y - h * 0.42), 0.4)


# a food production module: the rack of grow trays under their light bars, the
# nutrient film channels, the circulation pump and reservoir, the climate unit
static func food_module(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	var gw := Rect2(w * 0.04, h * 0.06, w * 0.66, h * 0.66)
	var nt := clampi(int(gw.size.y / 14.0), 2, 6)
	for k in nt:
		var y: float = gw.position.y + (k + 1) * gw.size.y / nt
		L(ci, Vector2(gw.position.x, y), Vector2(gw.end.x, y), 0.5, 1.4)
		var ly: float = y - gw.size.y / nt + 3.0
		R(ci, Rect2(gw.position.x + 4.0, ly, gw.size.x - 8.0, 2.5), 0.4)
		var segs := PackedVector2Array()
		var np := clampi(int(gw.size.x / 6.0), 3, 40)
		for i in np:
			var x: float = gw.position.x + 4.0 + (i + 0.5) * (gw.size.x - 8.0) / np
			segs.append(Vector2(x, y))
			segs.append(Vector2(x - 2.0, y - gw.size.y / nt * 0.45))
			segs.append(Vector2(x, y))
			segs.append(Vector2(x + 2.0, y - gw.size.y / nt * 0.4))
		S(ci, segs, 0.3)
	var rs := Rect2(w * 0.74, h * 0.5, w * 0.22, h * 0.44)
	R(ci, rs, 0.5)
	L(ci, Vector2(rs.position.x + 2.0, rs.position.y + rs.size.y * 0.3), Vector2(rs.end.x - 2.0, rs.position.y + rs.size.y * 0.3), 0.3)
	E.volute(ci, Vector2(w * 0.85, h * 0.32), minf(w * 0.06, h * 0.1), true, 0.5)
	E.louvres(ci, Rect2(w * 0.76, h * 0.06, w * 0.18, h * 0.14), 0.3)
	R(ci, Rect2(w * 0.04, h * 0.76, w * 0.66, h * 0.18), 0.4)
	E.hatch(ci, Rect2(w * 0.06, h * 0.78, w * 0.62, h * 0.14), 4.0, true, 0.2, 40)


# ================================================================== ST-40, EV-55, BL-88, LC-140

# a turbopump: the fuel and oxidiser pump housings on one shaft with the turbine
# between, its exhaust, the inlets and discharges
static func turbopump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.52
	var pr: float = minf(w * 0.2, h * 0.32)
	var p1 := Vector2(w * 0.22, ay)
	var p2 := Vector2(w * 0.78, ay)
	for pc in [p1, p2]:
		O(ci, pc, pr, 0.6, 1.2)
		E.impeller(ci, pc, pr * 0.72, 0.45)
		L(ci, pc + Vector2(0, -pr), Vector2(pc.x, 1.0), 0.5, 1.2)
	var tb := Rect2(w * 0.4, ay - pr * 0.75, w * 0.2, pr * 1.5)
	R(ci, tb, 0.6, 1.2)
	E.hatch(ci, E.inset(tb, 2.0), 2.5, true, 0.35, 16)
	L(ci, p1, p2, 0.35)
	P(ci, PackedVector2Array([Vector2(tb.get_center().x, tb.end.y), Vector2(tb.get_center().x, h - 2.0), Vector2(w * 0.62, h - 2.0)]), 0.45)
	L(ci, p1 + Vector2(-pr, 0), Vector2(1, ay), 0.5)
	L(ci, p2 + Vector2(pr, 0), Vector2(w - 1, ay), 0.5)


# a stellar coronagraph: the telescope tube with its baffle vanes, the occulting
# disc on its spider at the entrance, the Lyot stop, the field lens, the camera
static func coronagraph(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var tube := Rect2(w * 0.2, h * 0.02, w * 0.6, h * 0.74)
	L(ci, tube.position, Vector2(tube.position.x, tube.end.y), 0.6, 1.4)
	L(ci, Vector2(tube.end.x, tube.position.y), tube.end, 0.6, 1.4)
	var segs := PackedVector2Array()
	for k in clampi(int(tube.size.y / 10.0), 3, 20):
		var y: float = tube.position.y + (k + 0.5) * 10.0
		segs.append(Vector2(tube.position.x, y))
		segs.append(Vector2(tube.position.x + tube.size.x * 0.18, y + 3.0))
		segs.append(Vector2(tube.end.x, y))
		segs.append(Vector2(tube.end.x - tube.size.x * 0.18, y + 3.0))
	S(ci, segs, 0.35)
	var oc := Vector2(w * 0.5, tube.position.y + h * 0.04)
	O(ci, oc, tube.size.x * 0.12, 0.6)
	L(ci, Vector2(tube.position.x, oc.y), Vector2(tube.end.x, oc.y), 0.35)
	L(ci, Vector2(tube.position.x + tube.size.x * 0.25, tube.position.y + tube.size.y * 0.55), Vector2(tube.end.x - tube.size.x * 0.25, tube.position.y + tube.size.y * 0.55), 0.6, 2.0)
	A(ci, Vector2(w * 0.5, tube.position.y + tube.size.y * 0.75 + tube.size.x * 0.5), tube.size.x * 0.5, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 0.5, 1.4)
	var cam := Rect2(w * 0.24, tube.end.y + 2.0, w * 0.52, h * 0.2)
	R(ci, cam, 0.6, 1.2)
	R(ci, Rect2(cam.get_center().x - cam.size.x * 0.2, cam.position.y + 2.0, cam.size.x * 0.4, 3.0), 0.7)
	E.hatch(ci, Rect2(cam.position.x + 3.0, cam.position.y + cam.size.y * 0.5, cam.size.x - 6.0, cam.size.y * 0.4), 3.0, true, 0.22, 20)


# a particle detector: a stack of silicon detector planes behind its collimator,
# the absorber plates between them, the electronics box at the back
static func particle_det(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	P(ci, PackedVector2Array([Vector2(1, h * 0.1), Vector2(w * 0.3, h * 0.32), Vector2(w * 0.3, h * 0.68), Vector2(1, h * 0.9)]), 0.55)
	var n := 6
	for k in n:
		var x: float = w * (0.34 + k * 0.07)
		L(ci, Vector2(x, h * 0.26), Vector2(x, h * 0.74), 0.65 if k % 2 == 0 else 0.35, 1.6 if k % 2 == 0 else 1.0)
	R(ci, Rect2(w * 0.32, h * 0.22, w * 0.42, h * 0.56), 0.45)
	var eb := Rect2(w * 0.78, h * 0.18, w * 0.2, h * 0.64)
	R(ci, eb, 0.55)
	E.hatch(ci, E.inset(eb, 2.0), 3.0, false, 0.22, 20)


# a fluxgate magnetometer on its boom root: the sensor head (three orthogonal
# windings round their cores), the thermal can, the harness
static func magnetometer(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.36)
	var s: float = minf(w * 0.34, h * 0.28)
	R(ci, Rect2(c - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), 0.45)
	O(ci, c, s * 0.7, 0.55)
	E.hatch(ci, Rect2(c.x - s * 0.8, c.y - s * 0.18, s * 1.6, s * 0.36), 2.5, true, 0.35, 16)
	E.hatch(ci, Rect2(c.x - s * 0.18, c.y - s * 0.8, s * 0.36, s * 1.6), 2.5, false, 0.35, 16)
	D(ci, c, 1.6, 0.6)
	L(ci, c + Vector2(0, s), Vector2(c.x, h * 0.92), 0.5, 1.4)
	R(ci, Rect2(w * 0.3, h * 0.88, w * 0.4, h * 0.1), 0.5)


# a water electrolyser: the cell stack between its end plates and tie rods, the
# hydrogen and oxygen gas separators above it, the circulation pump, the rectifier
static func electrolyser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var st := Rect2(w * 0.06, h * 0.5, w * 0.6, h * 0.42)
	R(ci, Rect2(st.position.x, st.position.y, 5.0, st.size.y), 0.6)
	R(ci, Rect2(st.end.x - 5.0, st.position.y, 5.0, st.size.y), 0.6)
	E.hatch(ci, Rect2(st.position.x + 5.0, st.position.y + 2.0, st.size.x - 10.0, st.size.y - 4.0), 2.2, true, 0.3, 80)
	L(ci, Vector2(st.position.x - 2.0, st.position.y - 2.0), Vector2(st.end.x + 2.0, st.position.y - 2.0), 0.45)
	L(ci, Vector2(st.position.x - 2.0, st.end.y + 2.0), Vector2(st.end.x + 2.0, st.end.y + 2.0), 0.45)
	for k in 2:
		var vs := Rect2(w * (0.08 + k * 0.32), h * 0.06, w * 0.24, h * 0.36)
		E.vessel_v(ci, vs, 0.55)
		L(ci, Vector2(vs.get_center().x, vs.end.y), Vector2(vs.get_center().x, st.position.y), 0.45)
		L(ci, Vector2(vs.get_center().x, vs.position.y), Vector2(vs.get_center().x, 0), 0.45)
	var rc := Rect2(w * 0.72, h * 0.08, w * 0.24, h * 0.5)
	R(ci, rc, 0.5)
	E.hatch(ci, sub(rc, 0.15, 0.1, 0.85, 0.6), 3.0, true, 0.25, 12)
	E.volute(ci, Vector2(w * 0.84, h * 0.8), minf(w * 0.08, h * 0.1), true, 0.5)


# a composter: the rotating drum on its rollers, the paddles inside, the gear ring
# and drive motor, the biofilter on the vent
static func composter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.42, h * 0.46)
	var rad: float = minf(w * 0.36, h * 0.38)
	O(ci, c, rad, 0.6, 1.4)
	O(ci, c, rad * 0.9, 0.3)
	for k in 4:
		var a: float = TAU * k / 4.0 + 0.4
		L(ci, c + Vector2.from_angle(a) * rad * 0.15, c + Vector2.from_angle(a) * rad * 0.8, 0.45, 1.4)
	O(ci, c, rad * 0.15, 0.5)
	for f in [-0.6, 0.6]:
		O(ci, c + Vector2(rad * f, rad * 1.0), rad * 0.12, 0.55)
	L(ci, Vector2(c.x - rad, h * 0.96), Vector2(c.x + rad, h * 0.96), 0.5, 1.4)
	R(ci, Rect2(w * 0.82, h * 0.1, w * 0.14, h * 0.4), 0.5)
	E.hatch(ci, Rect2(w * 0.83, h * 0.12, w * 0.12, h * 0.36), 3.0, false, 0.3, 12)
	L(ci, c + Vector2(rad * 0.7, -rad * 0.7), Vector2(w * 0.82, h * 0.3), 0.4)


# a beehive: the stacked boxes (brood box, supers) with their frames, the roof,
# the entrance slot on the stand
static func beehive(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	P(ci, PackedVector2Array([Vector2(w * 0.04, h * 0.16), Vector2(w * 0.5, h * 0.02), Vector2(w * 0.96, h * 0.16)]), 0.6, 1.2)
	for k in 3:
		var b := Rect2(w * 0.1, h * (0.16 + k * 0.24), w * 0.8, h * 0.24)
		R(ci, b, 0.5)
		E.hatch(ci, Rect2(b.position.x + 3.0, b.position.y + 2.0, b.size.x - 6.0, b.size.y - 4.0), 3.0, true, 0.2, 20)
	L(ci, Vector2(w * 0.3, h * 0.88), Vector2(w * 0.7, h * 0.88), 0.6, 1.6)
	L(ci, Vector2(w * 0.16, h * 0.9), Vector2(w * 0.16, h), 0.45)
	L(ci, Vector2(w * 0.84, h * 0.9), Vector2(w * 0.84, h), 0.45)


# a forklift: the mast with its carriage and forks, the counterweighted body, the
# driver's overhead guard, the wheels
static func forklift(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var mx: float = w * 0.18
	L(ci, Vector2(mx, h * 0.04), Vector2(mx, h * 0.86), 0.6, 1.6)
	L(ci, Vector2(mx + 4.0, h * 0.04), Vector2(mx + 4.0, h * 0.86), 0.45)
	R(ci, Rect2(mx - 6.0, h * 0.5, 6.0, h * 0.2), 0.55)
	L(ci, Vector2(2, h * 0.7), Vector2(mx, h * 0.7), 0.6, 1.8)
	var body := PackedVector2Array([Vector2(mx + 6.0, h * 0.86), Vector2(mx + 6.0, h * 0.56), Vector2(w * 0.7, h * 0.56), Vector2(w * 0.96, h * 0.62), Vector2(w * 0.96, h * 0.86)])
	P(ci, body, 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(w * 0.3, h * 0.56), Vector2(w * 0.34, h * 0.14), Vector2(w * 0.74, h * 0.14), Vector2(w * 0.74, h * 0.56)]), 0.5)
	L(ci, Vector2(w * 0.5, h * 0.56), Vector2(w * 0.46, h * 0.38), 0.45)
	for f in [0.34, 0.8]:
		O(ci, Vector2(w * f, h * 0.88), minf(w * 0.1, h * 0.1), 0.55)


# a hold crane trolley: the trolley on its bridge rail, the hoist drum and motor,
# the rope falls to the hook block
static func hold_crane(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(1, h * 0.04), Vector2(w - 1, h * 0.04), 0.6, 1.8)
	var tr := Rect2(w * 0.1, h * 0.06, w * 0.8, h * 0.2)
	R(ci, tr, 0.6, 1.2)
	for f in [0.2, 0.8]:
		O(ci, Vector2(tr.position.x + tr.size.x * f, tr.position.y), minf(tr.size.y * 0.25, 4.0), 0.55)
	O(ci, tr.get_center(), tr.size.y * 0.32, 0.5)
	E.hatch(ci, Rect2(tr.get_center().x - tr.size.y * 0.3, tr.position.y + 2.0, tr.size.y * 0.6, tr.size.y - 4.0), 2.5, true, 0.25, 10)
	R(ci, Rect2(tr.end.x - tr.size.x * 0.28, tr.position.y + tr.size.y * 0.2, tr.size.x * 0.22, tr.size.y * 0.6), 0.45)
	var hb := Rect2(w * 0.32, h * 0.62, w * 0.36, h * 0.16)
	for x in [w * 0.4, w * 0.6]:
		L(ci, Vector2(x, tr.end.y), Vector2(x, hb.position.y), 0.45)
	R(ci, hb, 0.6)
	O(ci, hb.get_center(), hb.size.y * 0.32, 0.45)
	L(ci, Vector2(w * 0.5, hb.end.y), Vector2(w * 0.5, h * 0.84), 0.55, 1.4)
	A(ci, Vector2(w * 0.5, h * 0.9), minf(w * 0.1, h * 0.06), -PI * 0.5, PI * 1.1, 0.6, 1.6)


# ================================================================== R2 and the odd-shaped ships

# an X-ray parcel scanner: the tunnel with its lead curtains, the conveyor through
# it, the generator above, the detector array, the operator's screen; a big one is
# a flat-panel scanning array instead
static func xray_scanner(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w > 4.0 * M:
		E.radar(ci, r)
		return
	var tn := Rect2(w * 0.12, h * 0.3, w * 0.62, h * 0.5)
	R(ci, Rect2(w * 0.08, h * 0.08, w * 0.7, h * 0.8), 0.55, 1.2)
	R(ci, tn, 0.45)
	for x in [tn.position.x + 2.0, tn.end.x - 2.0]:
		var segs := PackedVector2Array()
		for k in 5:
			segs.append(Vector2(x - 1.5 + k * 0.8, tn.position.y + 1.0))
			segs.append(Vector2(x - 1.5 + k * 0.8, tn.end.y - 2.0))
		S(ci, segs, 0.3)
	L(ci, Vector2(1, tn.end.y), Vector2(w * 0.96, tn.end.y), 0.6, 1.6)
	for k in 6:
		O(ci, Vector2(w * (0.06 + k * 0.16), tn.end.y + 2.5), 2.0, 0.4)
	R(ci, Rect2(w * 0.3, h * 0.1, w * 0.26, h * 0.16), 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.43, h * 0.26), Vector2(w * 0.3, tn.end.y), Vector2(w * 0.56, tn.end.y), Vector2(w * 0.43, h * 0.26)]), 0.18)
	L(ci, Vector2(tn.end.x - 6.0, tn.position.y), Vector2(tn.end.x - 6.0, tn.end.y), 0.5, 1.6)
	E.screen_face(ci, Rect2(w * 0.8, h * 0.1, w * 0.18, h * 0.3), 1, 0.4)
	L(ci, Vector2(w * 0.89, h * 0.4), Vector2(w * 0.89, h * 0.92), 0.4)


# a mail sorting frame: rows of pigeonholes with their label strips and a few
# letters in them, the bag hooks along the foot
static func mail_sorter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h * 0.86), 0.5)
	var nx := clampi(int(w / 9.0), 2, 40)
	var ny := clampi(int(h * 0.86 / 10.0), 2, 30)
	var segs := PackedVector2Array()
	for i in range(1, nx):
		segs.append(Vector2(1 + i * (w - 2) / nx, 1))
		segs.append(Vector2(1 + i * (w - 2) / nx, h * 0.86))
	for j in range(1, ny):
		segs.append(Vector2(1, 1 + j * h * 0.86 / ny))
		segs.append(Vector2(w - 1, 1 + j * h * 0.86 / ny))
	S(ci, segs, 0.3)
	var lt := PackedVector2Array()
	for j in ny:
		for i in nx:
			if (i * 7 + j * 3) % 4 == 0:
				var c := Vector2(1 + (i + 0.5) * (w - 2) / nx, 1 + (j + 0.7) * h * 0.86 / ny)
				lt.append(c + Vector2(-(w - 2) / nx * 0.3, 0))
				lt.append(c + Vector2((w - 2) / nx * 0.3, -1.5))
	S(ci, lt, 0.5)
	for k in clampi(int(w / 20.0), 1, 12):
		var x: float = (k + 0.5) * w / clampi(int(w / 20.0), 1, 12)
		A(ci, Vector2(x, h * 0.93), 2.5, 0.0, PI, 0.5)


# a towing / sail winch: the drum between its flanges with the wire wound on,
# the level-wind carriage, the band brake round one flange, the hydraulic motor
static func tow_winch(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.55)
	var rad: float = minf(w * 0.42, h * 0.4)
	O(ci, c, rad, 0.6, 1.4)
	O(ci, c, rad * 0.45, 0.5)
	for k in 5:
		O(ci, c, rad * (0.5 + k * 0.08), 0.22)
	A(ci, c, rad * 1.06, PI * 0.15, PI * 0.95, 0.55, 2.0)
	L(ci, c + Vector2.from_angle(PI * 0.95) * rad * 1.06, c + Vector2(-rad * 1.1, rad * 0.9), 0.5)
	O(ci, c, rad * 0.14, 0.6)
	D(ci, c, 1.4, 0.6)
	# level wind across the top and the wire leaving
	L(ci, Vector2(c.x - rad, h * 0.06), Vector2(c.x + rad, h * 0.06), 0.5, 1.4)
	R(ci, Rect2(c.x - rad * 0.2, h * 0.02, rad * 0.4, h * 0.08), 0.55)
	L(ci, Vector2(c.x, h * 0.1), c + Vector2(0, -rad * 0.7), 0.45)
	R(ci, Rect2(c.x + rad * 0.55, c.y + rad * 0.55, rad * 0.4, rad * 0.4), 0.5)
	L(ci, Vector2(c.x - rad, h * 0.98), Vector2(c.x + rad, h * 0.98), 0.5, 1.4)


# a spray bar under the deckhead: the supply header, the drop pipes, the misting
# nozzles with their spray fans
static func spray_bar(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if w < 1.5 * M:
		# a hand spray can, not a bar
		E.fueltank(ci, r, null, null)
		return
	L(ci, Vector2(1, h * 0.2), Vector2(w - 1, h * 0.2), 0.55, 1.6)
	var n := clampi(int(w / 20.0), 2, 30)
	var segs := PackedVector2Array()
	for k in n:
		var x: float = (k + 0.5) * w / n
		L(ci, Vector2(x, h * 0.2), Vector2(x, h * 0.55), 0.45)
		R(ci, Rect2(x - 2.0, h * 0.55, 4.0, h * 0.12), 0.55)
		for e in [-0.5, 0.0, 0.5]:
			segs.append(Vector2(x, h * 0.67))
			segs.append(Vector2(x + e * w / n * 0.5, h * 0.98))
	S(ci, segs, 0.18)


# a microscope: the base and pillar, the stage with its slide, the objective turret,
# the binocular head and the camera port, the light source
static func microscope(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.1, h * 0.86, w * 0.7, h * 0.12), 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.62, h * 0.86), Vector2(w * 0.7, h * 0.2), Vector2(w * 0.56, h * 0.12)]), 0.6, 1.6)
	L(ci, Vector2(w * 0.2, h * 0.56), Vector2(w * 0.62, h * 0.56), 0.6, 1.8)
	L(ci, Vector2(w * 0.28, h * 0.54), Vector2(w * 0.48, h * 0.54), 0.5)
	O(ci, Vector2(w * 0.38, h * 0.8), minf(w * 0.06, h * 0.05), 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.3, h * 0.34), Vector2(w * 0.46, h * 0.34), Vector2(w * 0.42, h * 0.44), Vector2(w * 0.34, h * 0.44), Vector2(w * 0.3, h * 0.34)]), 0.55)
	L(ci, Vector2(w * 0.38, h * 0.44), Vector2(w * 0.38, h * 0.5), 0.55, 1.6)
	R(ci, Rect2(w * 0.28, h * 0.2, w * 0.3, h * 0.14), 0.55)
	L(ci, Vector2(w * 0.3, h * 0.2), Vector2(w * 0.18, h * 0.08), 0.55, 1.6)
	L(ci, Vector2(w * 0.34, h * 0.2), Vector2(w * 0.24, h * 0.06), 0.55, 1.6)
	R(ci, Rect2(w * 0.5, h * 0.04, w * 0.1, h * 0.16), 0.5)
	E.wheel(ci, Vector2(w * 0.72, h * 0.66), minf(w * 0.06, h * 0.05), 0.5)


# a CO2 scrubber: twin amine (or zeolite) beds in their canisters, the switching
# valves between them, the blower, the vacuum desorb line
static func co2_scrubber(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for k in 2:
		var cn := Rect2(w * (0.06 + k * 0.32), h * 0.14, w * 0.26, h * 0.74)
		R(ci, cn, 0.6, 1.2)
		var dots := PackedVector2Array()
		var ny := clampi(int(cn.size.y / 4.0), 3, 30)
		var nx := clampi(int(cn.size.x / 4.0), 2, 10)
		for j in ny:
			for i in nx:
				var q := cn.position + Vector2((i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * cn.size.x / (nx + 0.5), (j + 0.5) * cn.size.y / ny)
				dots.append(q)
				dots.append(q + Vector2(0.8, 0))
		S(ci, dots, 0.35)
		L(ci, Vector2(cn.get_center().x, cn.position.y), Vector2(cn.get_center().x, h * 0.06), 0.45)
		L(ci, Vector2(cn.get_center().x, cn.end.y), Vector2(cn.get_center().x, h * 0.96), 0.45)
	L(ci, Vector2(w * 0.19, h * 0.06), Vector2(w * 0.51, h * 0.06), 0.5, 1.4)
	L(ci, Vector2(w * 0.19, h * 0.96), Vector2(w * 0.51, h * 0.96), 0.5, 1.4)
	var vc := Vector2(w * 0.35, h * 0.06)
	P(ci, PackedVector2Array([vc + Vector2(-3, -2.5), vc + Vector2(3, 2.5), vc + Vector2(3, -2.5), vc + Vector2(-3, 2.5), vc + Vector2(-3, -2.5)]), 0.6)
	E.fan(ci, Vector2(w * 0.82, h * 0.3), minf(w * 0.12, h * 0.2), 6, 0.45)
	R(ci, Rect2(w * 0.72, h * 0.56, w * 0.22, h * 0.34), 0.5)
	E.hatch(ci, Rect2(w * 0.74, h * 0.6, w * 0.18, h * 0.26), 3.0, true, 0.22, 12)


# a UV steriliser: the stainless chamber with the lamp sleeve down its axis, the
# UV intensity sensor, the ballast box, inlet and outlet
static func uv_steriliser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var sh := E.vessel_h(ci, Rect2(w * 0.04, h * 0.3, w * 0.8, h * 0.4), 0.6)
	R(ci, Rect2(sh.position.x, sh.get_center().y - h * 0.05, sh.size.x, h * 0.1), 0.45)
	L(ci, Vector2(sh.position.x + 2.0, sh.get_center().y), Vector2(sh.end.x - 2.0, sh.get_center().y), 0.7, 1.4)
	for x in [0.25, 0.55]:
		L(ci, Vector2(w * x, sh.position.y), Vector2(w * x, h * 0.12), 0.5, 1.4)
	R(ci, Rect2(w * 0.86, h * 0.2, w * 0.12, h * 0.6), 0.5)
	D(ci, Vector2(w * 0.92, h * 0.28), 1.2, 0.7)
	E.gauge(ci, Vector2(w * 0.7, h * 0.18), minf(h * 0.08, 5.0), 0.5)


# a steam humidifier: the electrode boiling cylinder, the fill and drain valves, the
# steam hose up to the dispersion tube, the control box
static func humidifier(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.04, w * 0.6, h * 0.92), 0.45)
	var cyl := Rect2(w * 0.12, h * 0.26, w * 0.24, h * 0.6)
	E.vessel_v(ci, cyl, 0.55)
	for k in 3:
		L(ci, Vector2(cyl.position.x + cyl.size.x * (0.25 + k * 0.25), cyl.position.y + 2.0), Vector2(cyl.position.x + cyl.size.x * (0.25 + k * 0.25), cyl.end.y - cyl.size.y * 0.3), 0.45)
	P(ci, PackedVector2Array([Vector2(cyl.get_center().x, cyl.position.y), Vector2(cyl.get_center().x, h * 0.12), Vector2(w * 0.96, h * 0.12)]), 0.5, 1.4)
	var segs := PackedVector2Array()
	for k in clampi(int(w * 0.3 / 5.0), 2, 12):
		var x: float = w * 0.68 + k * 5.0
		segs.append(Vector2(x, h * 0.12))
		segs.append(Vector2(x + 1.5, h * 0.06))
	S(ci, segs, 0.3)
	R(ci, Rect2(w * 0.42, h * 0.3, w * 0.18, h * 0.3), 0.5)
	D(ci, Vector2(w * 0.51, h * 0.38), 1.2, 0.7)
	L(ci, Vector2(cyl.get_center().x, cyl.end.y), Vector2(cyl.get_center().x, h * 0.96), 0.45)


# a refrigeration plant: two semi-hermetic compressors on the receiver, the oil
# separator, the water-cooled condenser, the liquid line with its sight glass and
# filter-drier, the suction accumulator, the control panel
static func ref_plant(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var rc := E.vessel_h(ci, Rect2(w * 0.04, h * 0.74, w * 0.66, h * 0.16), 0.55)
	for k in 2:
		var cp := Rect2(w * (0.08 + k * 0.32), h * 0.44, w * 0.26, h * 0.26)
		R(ci, cp, 0.6, 1.2)
		E.hatch(ci, Rect2(cp.position.x + cp.size.x * 0.5, cp.position.y + 2.0, cp.size.x * 0.46, cp.size.y - 4.0), 3.0, true, 0.22, 16)
		for e in 3:
			O(ci, cp.position + cp.size * Vector2(0.12 + e * 0.13, 0.35), minf(cp.size.y * 0.12, 3.5), 0.45)
		L(ci, Vector2(cp.get_center().x, cp.end.y), Vector2(cp.get_center().x, rc.position.y), 0.45)
	var cd := E.vessel_h(ci, Rect2(w * 0.04, h * 0.08, w * 0.66, h * 0.22), 0.55)
	E.hatch(ci, E.inset(cd, 2.0), 4.0, false, 0.18, 10)
	E.vessel_v(ci, Rect2(w * 0.74, h * 0.08, w * 0.1, h * 0.4), 0.5)
	E.vessel_v(ci, Rect2(w * 0.74, h * 0.52, w * 0.1, h * 0.36), 0.5)
	L(ci, Vector2(w * 0.7, h * 0.36), Vector2(w * 0.04, h * 0.36), 0.45)
	O(ci, Vector2(w * 0.4, h * 0.36), 2.5, 0.6)
	R(ci, Rect2(w * 0.5, h * 0.34, w * 0.08, h * 0.04), 0.5)
	var pn := Rect2(w * 0.87, h * 0.1, w * 0.11, h * 0.8)
	R(ci, pn, 0.5)
	for k in 3:
		D(ci, pn.position + pn.size * Vector2(0.5, 0.12 + k * 0.08), 1.1, 0.6)


# an evaporator: the finned coil, the fans blowing through it, the drain pan and
# the expansion valve on its inlet
static func evaporator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h > w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var B := func(u0: float, v0: float, u1: float, v1: float) -> Rect2: return Rect2(X.call(u0, v0), X.call(u1, v1) - X.call(u0, v0)).abs()
	var coil: Rect2 = B.call(2.0, th * 0.08, ln - 2.0, th * 0.5)
	R(ci, coil, 0.55)
	E.hatch(ci, coil, 2.2, not vert, 0.22, 160)
	var nf := clampi(int(ln / maxf(th * 0.9, 12.0)), 1, 10)
	for k in nf:
		var fc: Vector2 = X.call((k + 0.5) * ln / nf, th * 0.74)
		E.fan(ci, fc, minf(ln / nf * 0.4, th * 0.22), 5, 0.4)
	L(ci, X.call(2.0, th * 0.97), X.call(ln - 2.0, th * 0.97), 0.45, 1.4)


# a wall of safe deposit boxes: the doors in rows and sizes, each with its two
# keyholes and hinge pins, the vault's guard lock panel
static func safe_deposit(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.6, 1.2)
	var y := 3.0
	var row := 0
	while y < h - 6.0:
		var rh: float = minf([10.0, 14.0, 20.0][row % 3], h - 3.0 - y)
		var bw: float = [16.0, 22.0, 16.0][row % 3]
		var n := maxi(1, int((w - 6.0) / bw))
		bw = (w - 6.0) / n
		for i in n:
			var b := Rect2(3.0 + i * bw + 0.5, y + 0.5, bw - 1.0, rh - 1.0)
			R(ci, b, 0.4)
			if b.size.x > 8.0 and b.size.y > 6.0:
				D(ci, b.position + Vector2(b.size.x * 0.35, b.size.y * 0.5), 0.8, 0.6)
				D(ci, b.position + Vector2(b.size.x * 0.65, b.size.y * 0.5), 0.8, 0.6)
		y += rh
		row += 1


# a gun rack: rifles stood in their cradles behind the locking bar, the ammunition
# drawers below
static func gun_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	var n := clampi(int(w / 9.0), 2, 30)
	for k in n:
		var x: float = (k + 0.5) * w / n
		P(ci, PackedVector2Array([Vector2(x - 1.0, h * 0.08), Vector2(x - 1.0, h * 0.5), Vector2(x - 3.0, h * 0.62), Vector2(x - 2.0, h * 0.68), Vector2(x + 2.0, h * 0.68), Vector2(x + 1.5, h * 0.5), Vector2(x + 1.0, h * 0.08)]), 0.5)
	L(ci, Vector2(3, h * 0.3), Vector2(w - 3, h * 0.3), 0.6, 1.8)
	O(ci, Vector2(w - 5.0, h * 0.3), 2.0, 0.6)
	for k in 2:
		var d := Rect2(3, h * (0.72 + k * 0.13), w - 6, h * 0.12)
		R(ci, d, 0.45)
		L(ci, d.get_center() + Vector2(-5, 0), d.get_center() + Vector2(5, 0), 0.6, 1.4)


# a biometric access panel: the palm reader with its hand outline, the iris camera,
# the keypad, the door strike's status lights
static func biometric(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.1, h * 0.04, w * 0.8, h * 0.92), 0.55, 1.2)
	O(ci, Vector2(w * 0.5, h * 0.14), minf(w * 0.1, h * 0.06), 0.55)
	D(ci, Vector2(w * 0.5, h * 0.14), 1.0, 0.7)
	var pr := Rect2(w * 0.22, h * 0.26, w * 0.56, h * 0.36)
	R(ci, pr, 0.45)
	var pc := pr.position + pr.size * Vector2(0.5, 0.72)
	O(ci, pc, pr.size.x * 0.18, 0.45)
	for k in 5:
		var a: float = -PI * 0.5 + (k - 2) * 0.32
		L(ci, pc + Vector2.from_angle(a) * pr.size.x * 0.18, pc + Vector2.from_angle(a) * pr.size.x * (0.42 if k != 0 else 0.3), 0.45, 1.4)
	for j in 3:
		for i in 3:
			R(ci, Rect2(w * (0.28 + i * 0.16), h * (0.68 + j * 0.08), w * 0.12, h * 0.06), 0.4)
	for k in 2:
		D(ci, Vector2(w * (0.4 + k * 0.2), h * 0.93), 1.0, 0.7)


# a three-phase separator: the horizontal vessel, the inlet diverter, the weir
# plate, the oil, water and gas levels, the mist eliminator before the gas outlet,
# its three outlets; stood up, a vertical separator with its demister pad
static func separator_3ph(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	if h > w:
		var sh := E.vessel_v(ci, Rect2(w * 0.12, h * 0.04, w * 0.76, h * 0.9), 0.6)
		var dm := Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.06, sh.size.x - 4.0, sh.size.y * 0.08)
		R(ci, dm, 0.45)
		E.hatch(ci, dm, 2.5, true, 0.3, 30)
		L(ci, Vector2(1, sh.position.y + sh.size.y * 0.35), Vector2(sh.position.x + sh.size.x * 0.4, sh.position.y + sh.size.y * 0.35), 0.5)
		L(ci, Vector2(sh.position.x + sh.size.x * 0.4, sh.position.y + sh.size.y * 0.3), Vector2(sh.position.x + sh.size.x * 0.4, sh.position.y + sh.size.y * 0.42), 0.55, 1.6)
		var lv: float = sh.position.y + sh.size.y * 0.62
		L(ci, Vector2(sh.position.x + 2.0, lv), Vector2(sh.end.x - 2.0, lv), 0.4)
		E.F(ci, Rect2(sh.position.x, lv, sh.size.x, sh.end.y - lv), 0.035)
		return
	var sh := E.vessel_h(ci, Rect2(w * 0.02, h * 0.16, w * 0.96, h * 0.68), 0.6)
	var wx: float = sh.position.x + sh.size.x * 0.68
	L(ci, Vector2(wx, sh.end.y), Vector2(wx, sh.position.y + sh.size.y * 0.45), 0.6, 1.6)
	var oil: float = sh.position.y + sh.size.y * 0.5
	var wat: float = sh.position.y + sh.size.y * 0.75
	L(ci, Vector2(sh.position.x + 2.0, oil), Vector2(wx, oil), 0.45)
	L(ci, Vector2(sh.position.x + 2.0, wat), Vector2(wx, wat), 0.3)
	L(ci, Vector2(wx, sh.position.y + sh.size.y * 0.6), Vector2(sh.end.x - 2.0, sh.position.y + sh.size.y * 0.6), 0.45)
	E.F(ci, Rect2(sh.position.x, oil, wx - sh.position.x, sh.end.y - oil), 0.035)
	L(ci, Vector2(sh.position.x + sh.size.x * 0.08, sh.position.y + sh.size.y * 0.2), Vector2(sh.position.x + sh.size.x * 0.08, sh.position.y + sh.size.y * 0.6), 0.55, 1.6)
	var dm := Rect2(sh.end.x - sh.size.x * 0.14, sh.position.y + 2.0, sh.size.x * 0.08, sh.size.y * 0.35)
	R(ci, dm, 0.45)
	E.hatch(ci, dm, 2.0, true, 0.3, 20)
	for nz in [[sh.position.x + sh.size.x * 0.05, sh.position.y, -1.0], [sh.end.x - sh.size.x * 0.05, sh.position.y, -1.0], [sh.position.x + sh.size.x * 0.4, sh.end.y, 1.0], [sh.end.x - sh.size.x * 0.12, sh.end.y, 1.0]]:
		L(ci, Vector2(nz[0], nz[1]), Vector2(nz[0], nz[1] + nz[2] * h * 0.12), 0.5, 1.4)
	for f in [0.25, 0.75]:
		P(ci, PackedVector2Array([Vector2(w * f - h * 0.1, h - 1.0), Vector2(w * f - h * 0.05, sh.end.y), Vector2(w * f + h * 0.05, sh.end.y), Vector2(w * f + h * 0.1, h - 1.0)]), 0.45)


# a radar level gauge: the horn antenna down through its flange into the tank, the
# electronics head with its display and cable entry
static func level_radar(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.5
	R(ci, Rect2(cx - w * 0.22, h * 0.04, w * 0.44, h * 0.32), 0.6, 1.2)
	O(ci, Vector2(cx, h * 0.2), minf(w * 0.12, h * 0.1), 0.5)
	L(ci, Vector2(cx + w * 0.22, h * 0.2), Vector2(w - 2.0, h * 0.26), 0.4)
	R(ci, Rect2(cx - w * 0.08, h * 0.36, w * 0.16, h * 0.12), 0.5)
	L(ci, Vector2(cx - w * 0.3, h * 0.5), Vector2(cx + w * 0.3, h * 0.5), 0.6, 2.0)
	P(ci, PackedVector2Array([Vector2(cx - w * 0.06, h * 0.5), Vector2(cx - w * 0.22, h * 0.86), Vector2(cx + w * 0.22, h * 0.86), Vector2(cx + w * 0.06, h * 0.5)]), 0.55)
	for e in [-0.3, 0.0, 0.3]:
		L(ci, Vector2(cx, h * 0.88), Vector2(cx + e * w, h), 0.15)


# a Coriolis flow meter: the two bent measuring tubes side by side between the
# process flanges, the driver and the pick-off coils, the transmitter on top
static func coriolis(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var fy: float = h * 0.82
	L(ci, Vector2(1, fy), Vector2(w - 1, fy), 0.55, 1.6)
	E.flange(ci, Vector2(3.0, fy), Vector2.LEFT, minf(h * 0.08, 6.0), 0.55)
	E.flange(ci, Vector2(w - 3.0, fy), Vector2.RIGHT, minf(h * 0.08, 6.0), 0.55)
	for k in 2:
		var o: float = k * 4.0
		P(ci, PackedVector2Array([Vector2(w * 0.2 + o, fy), Vector2(w * 0.2 + o, h * 0.42 + o), Vector2(w * 0.35, h * 0.3 + o), Vector2(w * 0.65, h * 0.3 + o), Vector2(w * 0.8 - o, h * 0.42 + o), Vector2(w * 0.8 - o, fy)]), 0.5 - k * 0.15, 1.2)
	R(ci, Rect2(w * 0.46, h * 0.26, w * 0.08, h * 0.1), 0.6)
	for f in [0.3, 0.7]:
		O(ci, Vector2(w * f, h * 0.42), 2.2, 0.6)
	R(ci, Rect2(w * 0.36, h * 0.02, w * 0.28, h * 0.18), 0.55)
	E.screen_face(ci, Rect2(w * 0.4, h * 0.04, w * 0.2, h * 0.12), 3, 0.35)
	L(ci, Vector2(w * 0.5, h * 0.2), Vector2(w * 0.5, h * 0.26), 0.45)


# an inertial measurement unit: three ring-laser gyros on the orthogonal faces of its
# block (each a triangle of mirrors), the accelerometers, the isolators, the box
static func imu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.5)
	var n := 3 if w > h * 1.6 else 1
	for k in n:
		var c := Vector2((k + 0.5) * w / n, h * 0.45)
		var s: float = minf(w / n * 0.36, h * 0.32)
		P(ci, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.87, s * 0.5), c + Vector2(-s * 0.87, s * 0.5), c + Vector2(0, -s)]), 0.6, 1.2)
		for q in [c + Vector2(0, -s), c + Vector2(s * 0.87, s * 0.5), c + Vector2(-s * 0.87, s * 0.5)]:
			D(ci, q, 1.6, 0.6)
		O(ci, c, s * 0.2, 0.4)
	for f in [0.1, 0.9]:
		for g in [0.12, 0.88]:
			O(ci, Vector2(w * f, h * g), 2.0, 0.4)
	R(ci, Rect2(w * 0.3, h * 0.82, w * 0.4, h * 0.12), 0.45)


# an electric arc furnace: the shell and its refractory lining, the molten bath with
# the slag over it, the three graphite electrodes down through the roof, the roof's
# water-cooled panels, the tap spout and the tilting rockers below
static func arc_furnace(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.46
	var sw: float = minf(w * 0.7, h * 1.4)
	var top: float = h * 0.36
	var bot: float = h * 0.86
	P(ci, PackedVector2Array([Vector2(cx - sw * 0.5, top), Vector2(cx - sw * 0.5, bot - h * 0.1), Vector2(cx - sw * 0.38, bot), Vector2(cx + sw * 0.38, bot), Vector2(cx + sw * 0.5, bot - h * 0.1), Vector2(cx + sw * 0.5, top)]), 0.65, 1.6)
	P(ci, PackedVector2Array([Vector2(cx - sw * 0.44, top), Vector2(cx - sw * 0.44, bot - h * 0.12), Vector2(cx - sw * 0.34, bot - h * 0.04), Vector2(cx + sw * 0.34, bot - h * 0.04), Vector2(cx + sw * 0.44, bot - h * 0.12), Vector2(cx + sw * 0.44, top)]), 0.35)
	var bath: float = bot - h * 0.2
	E.F(ci, Rect2(cx - sw * 0.43, bath, sw * 0.86, bot - h * 0.05 - bath), 0.05)
	var pts := PackedVector2Array()
	for k in 13:
		pts.append(Vector2(cx - sw * 0.43 + k * sw * 0.86 / 12.0, bath + (1.5 if k % 2 == 0 else -1.5)))
	P(ci, pts, 0.45)
	L(ci, Vector2(cx - sw * 0.43, bath - h * 0.04), Vector2(cx + sw * 0.43, bath - h * 0.04), 0.25)
	# roof and its cooling panels
	E._head(ci, Vector2(cx, top), sw * 0.5, minf(top - h * 0.08, sw * 0.22), true, 0.6)
	var segs := PackedVector2Array()
	for k in 8:
		var x: float = cx - sw * 0.45 + k * sw * 0.9 / 7.0
		segs.append(Vector2(x, top - h * 0.02))
		segs.append(Vector2(x, top - h * 0.08))
	S(ci, segs, 0.3)
	# electrodes and their arms
	for k in 3:
		var ex: float = cx + (k - 1) * sw * 0.16
		R(ci, Rect2(ex - 3.0, h * 0.04, 6.0, bath - h * 0.06 - h * 0.04), 0.6, 1.2)
		L(ci, Vector2(ex, h * 0.08), Vector2(w * 0.96, h * (0.06 + k * 0.04)), 0.4)
		L(ci, Vector2(ex - 4.0, bath - h * 0.03), Vector2(ex + 4.0, bath - h * 0.03), 0.6)
	L(ci, Vector2(w * 0.96, h * 0.04), Vector2(w * 0.96, h * 0.9), 0.5, 1.6)
	# tap spout and rockers
	P(ci, PackedVector2Array([Vector2(cx + sw * 0.5, bath), Vector2(cx + sw * 0.66, bath + h * 0.06), Vector2(cx + sw * 0.66, bath + h * 0.1), Vector2(cx + sw * 0.5, bath + h * 0.08)]), 0.55)
	for f in [-0.3, 0.3]:
		A(ci, Vector2(cx + sw * f, bot + h * 0.04), sw * 0.1, 0.2, PI - 0.2, 0.55, 1.4)
	L(ci, Vector2(cx - sw * 0.5, h * 0.98), Vector2(cx + sw * 0.5, h * 0.98), 0.5, 1.4)


# an ingot rack: the cast ingots (trapezoids) stacked in crossed layers between
# the uprights
static func ingot_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	for x in [2.0, w - 2.0]:
		L(ci, Vector2(x, 1), Vector2(x, h - 1), 0.55, 1.6)
	var ih: float = clampf(h / 8.0, 4.0, 10.0)
	var iw: float = ih * 3.0
	var rows := int((h - 4.0) / ih)
	for j in rows:
		var y: float = h - 3.0 - (j + 1) * ih
		if j % 2 == 0:
			var n := int((w - 8.0) / (iw + 2.0))
			for i in n:
				var x: float = 5.0 + i * (iw + 2.0)
				P(ci, PackedVector2Array([Vector2(x, y + ih), Vector2(x + iw * 0.12, y + 1.0), Vector2(x + iw * 0.88, y + 1.0), Vector2(x + iw, y + ih), Vector2(x, y + ih)]), 0.5)
		else:
			var n := int((w - 8.0) / (ih * 1.2))
			for i in n:
				var x: float = 5.0 + i * ih * 1.2
				R(ci, Rect2(x, y + 1.0, ih, ih - 1.0), 0.4)
	L(ci, Vector2(2, h - 2.0), Vector2(w - 2, h - 2.0), 0.55, 1.6)


# an eddy-current sorter: the feed conveyor, the magnetic head pulley spinning its
# rotor inside the belt's end, the splitter that the non-ferrous metal jumps over,
# the vibrating feeder at the start, the chutes below
static func eddy_sorter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var by: float = h * 0.42
	var hr: float = minf(h * 0.18, w * 0.08)
	var hc := Vector2(w * 0.68, by + hr)
	O(ci, Vector2(w * 0.08, by + hr), hr * 0.8, 0.5)
	O(ci, hc, hr, 0.6, 1.2)
	O(ci, hc, hr * 0.62, 0.45)
	for k in 8:
		var a: float = TAU * k / 8.0
		L(ci, hc + Vector2.from_angle(a) * hr * 0.25, hc + Vector2.from_angle(a) * hr * 0.6, 0.35)
	L(ci, Vector2(w * 0.08, by), Vector2(hc.x, by), 0.55, 1.4)
	L(ci, Vector2(w * 0.08, by + hr * 1.8), Vector2(hc.x, hc.y + hr), 0.45)
	var segs := PackedVector2Array()
	for k in clampi(int(w * 0.5 / 7.0), 3, 30):
		var x: float = w * 0.12 + k * 7.0
		segs.append(Vector2(x, by - 1.0))
		segs.append(Vector2(x + 3.0, by - 3.0))
	S(ci, segs, 0.4)
	# the trajectories: non-ferrous thrown far, the rest dropping close
	P(ci, PackedVector2Array([hc + Vector2(hr * 0.5, -hr), hc + Vector2(hr * 2.0, -hr * 1.1), hc + Vector2(hr * 3.0, hr * 0.4), hc + Vector2(hr * 3.4, hr * 2.0)]), 0.2)
	P(ci, PackedVector2Array([hc + Vector2(hr, 0), hc + Vector2(hr * 1.3, hr * 1.4), hc + Vector2(hr * 1.3, hr * 2.4)]), 0.2)
	L(ci, Vector2(hc.x + hr * 2.0, h * 0.62), Vector2(hc.x + hr * 2.2, h * 0.96), 0.6, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.02, h * 0.12), Vector2(w * 0.24, h * 0.12), Vector2(w * 0.2, by - 2.0), Vector2(w * 0.06, by - 2.0), Vector2(w * 0.02, h * 0.12)]), 0.5)
	E.motor(ci, Rect2(hc.x - hr * 1.6, h * 0.76, hr * 2.4, h * 0.18), true, 0.45)
	L(ci, Vector2(2, h * 0.98), Vector2(w - 2, h * 0.98), 0.5, 1.4)


# a magnetic drum separator: the rotating shell over the stationary magnet arc, the
# feed chute, the splitter between the magnetic and non-magnetic chutes
static func mag_separator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.45, h * 0.45)
	var rad: float = minf(w * 0.32, h * 0.34)
	O(ci, c, rad, 0.6, 1.4)
	A(ci, c, rad * 0.8, -PI * 0.2, PI * 0.7, 0.5, 2.0)
	var segs := PackedVector2Array()
	for k in 6:
		var a: float = -PI * 0.2 + k * PI * 0.18
		segs.append(c + Vector2.from_angle(a) * rad * 0.62)
		segs.append(c + Vector2.from_angle(a) * rad * 0.8)
	S(ci, segs, 0.4)
	O(ci, c, rad * 0.12, 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.05, h * 0.05), Vector2(w * 0.3, h * 0.05), c + Vector2(-rad * 0.3, -rad * 0.95)]), 0.5)
	L(ci, c + Vector2(rad * 0.2, rad * 1.0), Vector2(c.x + rad * 0.3, h * 0.97), 0.6, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.06, h * 0.97), c + Vector2(-rad * 0.9, rad * 0.8)]), 0.45)
	P(ci, PackedVector2Array([Vector2(w * 0.95, h * 0.97), c + Vector2(rad * 1.0, rad * 0.4)]), 0.45)


# a wet scrubber tower: the packed bed between its support grids, the spray header
# above it, the mist eliminator at the top, the sump and recirculation pump
static func scrubber(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var tw := Rect2(w * 0.12, h * 0.04, w * 0.5, h * 0.82)
	var sh := E.vessel_v(ci, tw, 0.6)
	var pb := Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.4, sh.size.x - 4.0, sh.size.y * 0.35)
	R(ci, pb, 0.45)
	var dots := PackedVector2Array()
	for j in clampi(int(pb.size.y / 4.0), 2, 30):
		for i in clampi(int(pb.size.x / 4.0), 2, 20):
			var q := pb.position + Vector2((i + 0.5 + (0.5 if j % 2 == 1 else 0.0)) * 4.0, (j + 0.5) * 4.0)
			if q.x < pb.end.x - 1.0:
				dots.append(q)
				dots.append(q + Vector2(1.0, 0.6))
	S(ci, dots, 0.4)
	var sy: float = sh.position.y + sh.size.y * 0.3
	L(ci, Vector2(sh.position.x + 2.0, sy), Vector2(sh.end.x - 2.0, sy), 0.5, 1.4)
	var segs := PackedVector2Array()
	for k in 4:
		var x: float = sh.position.x + sh.size.x * (0.15 + k * 0.23)
		segs.append(Vector2(x, sy))
		segs.append(Vector2(x - 3.0, sy + sh.size.y * 0.06))
		segs.append(Vector2(x, sy))
		segs.append(Vector2(x + 3.0, sy + sh.size.y * 0.06))
	S(ci, segs, 0.25)
	var me := Rect2(sh.position.x + 2.0, sh.position.y + sh.size.y * 0.08, sh.size.x - 4.0, sh.size.y * 0.08)
	R(ci, me, 0.45)
	E.hatch(ci, me, 2.5, true, 0.3, 30)
	E.volute(ci, Vector2(w * 0.82, h * 0.82), minf(w * 0.1, h * 0.08), true, 0.5)
	L(ci, Vector2(tw.end.x, h * 0.82), Vector2(w * 0.72, h * 0.82), 0.45)
	P(ci, PackedVector2Array([Vector2(w * 0.82, h * 0.7), Vector2(w * 0.82, h * 0.3), Vector2(tw.end.x, h * 0.3)]), 0.45)


# a car lashed on the deck, side-on: body, glasshouse, wheels with their chocks,
# the lashing straps to the deck rings
static func car(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var n := clampi(roundi(w / (h * 2.8)), 1, 8)
	var cw: float = w / n
	for i in n:
		var x0: float = i * cw + cw * 0.04
		var x1: float = (i + 1) * cw - cw * 0.04
		var lw: float = x1 - x0
		var by: float = h * 0.76
		P(ci, PackedVector2Array([Vector2(x0, by), Vector2(x0, h * 0.5), Vector2(x0 + lw * 0.22, h * 0.44), Vector2(x0 + lw * 0.32, h * 0.18), Vector2(x0 + lw * 0.7, h * 0.18), Vector2(x0 + lw * 0.84, h * 0.44), Vector2(x1, h * 0.5), Vector2(x1, by), Vector2(x0, by)]), 0.6, 1.2)
		L(ci, Vector2(x0 + lw * 0.5, h * 0.2), Vector2(x0 + lw * 0.5, h * 0.44), 0.4)
		L(ci, Vector2(x0 + lw * 0.26, h * 0.44), Vector2(x0 + lw * 0.82, h * 0.44), 0.35)
		for f in [0.2, 0.8]:
			var wc := Vector2(x0 + lw * f, by)
			O(ci, wc, h * 0.18, 0.6, 1.2)
			O(ci, wc, h * 0.08, 0.4)
			P(ci, PackedVector2Array([wc + Vector2(-h * 0.26, h * 0.22), wc + Vector2(-h * 0.2, h * 0.12), wc + Vector2(-h * 0.14, h * 0.22)]), 0.45)
		L(ci, Vector2(x0 + lw * 0.2, by), Vector2(x0 - 2.0, h - 1.0), 0.3)
		L(ci, Vector2(x0 + lw * 0.8, by), Vector2(x1 + 2.0, h - 1.0), 0.3)


# a deck tractor: the chassis, the cab, the fifth wheel / towing hook, the big
# low-pressure tyres
static func deck_tractor(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var by: float = h * 0.72
	R(ci, Rect2(w * 0.04, h * 0.48, w * 0.92, by - h * 0.48), 0.6, 1.2)
	P(ci, PackedVector2Array([Vector2(w * 0.08, h * 0.48), Vector2(w * 0.1, h * 0.08), Vector2(w * 0.42, h * 0.08), Vector2(w * 0.46, h * 0.48)]), 0.6, 1.2)
	R(ci, Rect2(w * 0.14, h * 0.14, w * 0.26, h * 0.2), 0.45)
	E.louvres(ci, Rect2(w * 0.54, h * 0.52, w * 0.2, by - h * 0.56), 0.3)
	O(ci, Vector2(w * 0.86, h * 0.44), minf(w * 0.05, h * 0.08), 0.55)
	L(ci, Vector2(w * 0.8, h * 0.48), Vector2(w * 0.92, h * 0.48), 0.6, 1.8)
	for f in [0.22, 0.76]:
		O(ci, Vector2(w * f, by + h * 0.04), minf(h * 0.22, w * 0.12), 0.6, 1.4)
		O(ci, Vector2(w * f, by + h * 0.04), minf(h * 0.1, w * 0.05), 0.4)


# an auxiliary power unit: the small gas turbine (intake, centrifugal compressor,
# can combustor, turbine, exhaust) and its gearbox with the generator on it
static func apu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.46
	P(ci, PackedVector2Array([Vector2(w * 0.02, ay - h * 0.3), Vector2(w * 0.14, ay - h * 0.18), Vector2(w * 0.14, ay + h * 0.18), Vector2(w * 0.02, ay + h * 0.3)]), 0.5)
	O(ci, Vector2(w * 0.24, ay), h * 0.22, 0.6, 1.2)
	E.impeller(ci, Vector2(w * 0.24, ay), h * 0.16, 0.45)
	R(ci, Rect2(w * 0.34, ay - h * 0.16, w * 0.22, h * 0.32), 0.55)
	A(ci, Vector2(w * 0.45, ay), h * 0.1, PI * 0.5, PI * 1.5, 0.45)
	var segs := PackedVector2Array()
	for k in 4:
		var x: float = w * (0.58 + k * 0.035)
		segs.append(Vector2(x, ay - h * 0.14))
		segs.append(Vector2(x + 3.0, ay + h * 0.14))
	S(ci, segs, 0.45)
	R(ci, Rect2(w * 0.56, ay - h * 0.18, w * 0.16, h * 0.36), 0.55)
	P(ci, PackedVector2Array([Vector2(w * 0.72, ay - h * 0.14), Vector2(w * 0.98, ay - h * 0.22), Vector2(w * 0.98, ay + h * 0.22), Vector2(w * 0.72, ay + h * 0.14)]), 0.5)
	L(ci, Vector2(w * 0.1, ay), Vector2(w * 0.72, ay), 0.3)
	var gb := Rect2(w * 0.1, h * 0.72, w * 0.4, h * 0.24)
	R(ci, gb, 0.55)
	L(ci, Vector2(w * 0.24, ay + h * 0.22), Vector2(w * 0.24, gb.position.y), 0.45, 1.4)
	E.motor(ci, Rect2(gb.end.x, h * 0.74, w * 0.36, h * 0.2), true, 0.5)
	# Skid, vibration isolators, accessory pipework and the generator terminal box.
	R(ci, sub(r, 0.06, 0.97, 0.94, 0.995), 0.55)
	for x in [0.15, 0.42, 0.75]:
		R(ci, sub(r, x, 0.94, x + 0.06, 0.97), 0.45)
	R(ci, sub(r, 0.62, 0.66, 0.76, 0.74), 0.5)
	P(ci, PackedVector2Array([Vector2(w * 0.5, h * 0.72), Vector2(w * 0.5, h * 0.65), Vector2(w * 0.3, h * 0.65), Vector2(w * 0.3, h * 0.61)]), 0.45)
	E.corner_bolts(ci, gb, 2.5, 0.45)


# an escape pod in its cradle: the capsule (heat shield, side hatch, window), the
# seats inside, the retro-rocket pack, the launch rails and the clamp
static func escape_pod(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cap := PackedVector2Array([Vector2(w * 0.08, h * 0.2), Vector2(w * 0.72, h * 0.1), Vector2(w * 0.9, h * 0.3), Vector2(w * 0.9, h * 0.7), Vector2(w * 0.72, h * 0.9), Vector2(w * 0.08, h * 0.8), Vector2(w * 0.08, h * 0.2)])
	P(ci, cap, 0.6, 1.4)
	A(ci, Vector2(w * 0.34, h * 0.5), h * 0.6, PI * 0.72, PI * 1.28, 0.6, 2.0)
	R(ci, Rect2(w * 0.4, h * 0.26, w * 0.18, h * 0.48), 0.5)
	D(ci, Vector2(w * 0.55, h * 0.5), 1.2, 0.6)
	O(ci, Vector2(w * 0.76, h * 0.42), h * 0.08, 0.5)
	for k in 2:
		var sx: float = w * (0.16 + k * 0.12)
		P(ci, PackedVector2Array([Vector2(sx, h * 0.3), Vector2(sx, h * 0.62), Vector2(sx + w * 0.08, h * 0.62)]), 0.45, 1.4)
	R(ci, Rect2(w * 0.9, h * 0.38, w * 0.08, h * 0.24), 0.55)
	for f in [0.42, 0.5, 0.58]:
		L(ci, Vector2(w * 0.98, h * f), Vector2(w, h * f), 0.5)
	L(ci, Vector2(w * 0.04, h * 0.97), Vector2(w * 0.96, h * 0.97), 0.55, 1.6)
	L(ci, Vector2(w * 0.04, h * 0.03), Vector2(w * 0.96, h * 0.03), 0.4)


# a nuclear thermal rocket's reactor, exhaust to the right: the pressure vessel, the
# hexagonal fuel elements with their hydrogen channels, the beryllium reflector
# round them with its control drums (each with its absorber plate), the inlet
# plenum and the core support plate, the throat at the outlet
static func ntr_core(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var v := Rect2(w * 0.06, h * 0.04, w * 0.84, h * 0.92)
	R(ci, v, 0.65, 1.4)
	var rf: float = v.size.y * 0.2
	var core := Rect2(v.position.x + v.size.x * 0.18, v.position.y + rf, v.size.x * 0.7, v.size.y - 2.0 * rf)
	R(ci, core, 0.55)
	var segs := PackedVector2Array()
	var nr := clampi(int(core.size.y / 4.0), 3, 30)
	for k in nr:
		var y: float = core.position.y + (k + 0.5) * core.size.y / nr
		segs.append(Vector2(core.position.x + 1.0, y))
		segs.append(Vector2(core.end.x - 1.0, y))
	S(ci, segs, 0.3)
	var ne := clampi(int(core.size.x / 10.0), 2, 12)
	for k in range(1, ne):
		L(ci, Vector2(core.position.x + k * core.size.x / ne, core.position.y), Vector2(core.position.x + k * core.size.x / ne, core.end.y), 0.2)
	# reflector bands top and bottom, the control drums in them
	for y0 in [v.position.y, core.end.y]:
		var band := Rect2(core.position.x, y0, core.size.x, rf)
		E.hatch(ci, band, 4.0, false, 0.12, 20)
		var nd := clampi(int(band.size.x / (rf * 1.2)), 2, 8)
		for k in nd:
			var dc := Vector2(band.position.x + (k + 0.5) * band.size.x / nd, band.get_center().y)
			O(ci, dc, rf * 0.38, 0.55)
			A(ci, dc, rf * 0.32, -PI * 0.3 + k, PI * 0.3 + k, 0.7, 2.0)
	# inlet plenum, support plate, the outlet throat
	L(ci, Vector2(core.position.x - 2.0, v.position.y + 2.0), Vector2(core.position.x - 2.0, v.end.y - 2.0), 0.55, 1.6)
	L(ci, Vector2(v.position.x - 0.0, h * 0.5), Vector2(core.position.x - 4.0, h * 0.5), 0.35)
	P(ci, PackedVector2Array([Vector2(v.end.x, h * 0.3), Vector2(w, h * 0.42), Vector2(w, h * 0.58), Vector2(v.end.x, h * 0.7)]), 0.6, 1.2)


# a control drum: the beryllium drum with its arc of boron carbide absorber, the shaft,
# the drive motor and its position resolver
static func control_drum(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.42
	O(ci, c, rad, 0.6, 1.2)
	A(ci, c, rad * 0.86, -PI * 0.35, PI * 0.35, 0.7, 3.0)
	E.hatch(ci, Rect2(c.x - rad * 0.6, c.y - rad * 0.6, rad * 1.2, rad * 1.2), 4.0, false, 0.08, 10)
	O(ci, c, rad * 0.18, 0.55)
	L(ci, c, c + Vector2.from_angle(0.0) * rad * 0.6, 0.45)
	R(ci, Rect2(c.x - rad * 0.25, c.y - rad * 0.25, rad * 0.5, rad * 0.5), 0.35)


# a shadow shield: alternating layers of tungsten (dense, cross-hatched) and lithium
# hydride (open) stacked across the line of sight, its tapered edges, the frame
static func shadow_shield(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var vert: bool = h >= w
	var ln: float = h if vert else w
	var th: float = w if vert else h
	var X := func(u: float, v: float) -> Vector2: return Vector2(v, u) if vert else Vector2(u, v)
	var nl := clampi(int(th / 5.0), 2, 10)
	for k in nl:
		var v0: float = k * th / nl
		var v1: float = (k + 1) * th / nl
		var rr := Rect2(X.call(1.0, v0), X.call(ln - 1.0, v1) - X.call(1.0, v0)).abs()
		R(ci, rr, 0.45)
		if k % 2 == 0:
			E.hatch(ci, rr, 3.0, not vert, 0.3, 300)
	E.bolts(ci, X.call(2.0, th * 0.5), X.call(ln - 2.0, th * 0.5), clampi(int(ln / 24.0), 2, 40), 0.5, 1.0)


# a flywheel energy store: the composite rim on its hub in the vacuum housing, the
# magnetic bearings top and bottom, the motor-generator in the middle, the vacuum
# pump port, the containment ring
static func flywheel_rotor(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var c := Vector2(w * 0.5, h * 0.5)
	var rad: float = minf(w, h) * 0.46
	O(ci, c, rad, 0.65, 1.6)
	O(ci, c, rad * 0.94, 0.3)
	for k in 5:
		O(ci, c, rad * (0.66 + k * 0.05), 0.22)
	O(ci, c, rad * 0.62, 0.55, 1.2)
	var segs := PackedVector2Array()
	for k in 6:
		var a: float = TAU * k / 6.0
		segs.append(c + Vector2.from_angle(a) * rad * 0.26)
		segs.append(c + Vector2.from_angle(a) * rad * 0.62)
	S(ci, segs, 0.35)
	O(ci, c, rad * 0.26, 0.55)
	var ns := 12
	for k in ns:
		var a: float = TAU * k / ns
		R(ci, Rect2(c + Vector2.from_angle(a) * rad * 0.18 - Vector2(1.5, 1.5), Vector2(3, 3)), 0.45)
	O(ci, c, rad * 0.08, 0.6)
	R(ci, Rect2(c.x + rad * 0.95, c.y - rad * 0.08, rad * 0.06, rad * 0.16), 0.5)


# a launch cradle: the sled on its rails, the shoes, the saddle pads the payload
# sits in, the release latches
static func launch_cradle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	L(ci, Vector2(1, h * 0.86), Vector2(w - 1, h * 0.86), 0.6, 2.0)
	R(ci, Rect2(w * 0.02, h * 0.44, w * 0.96, h * 0.3), 0.55)
	var n := clampi(int(w / 40.0), 2, 20)
	for k in n:
		var x: float = w * 0.02 + (k + 0.5) * w * 0.96 / n
		R(ci, Rect2(x - 5.0, h * 0.74, 10.0, h * 0.12), 0.5)
		P(ci, PackedVector2Array([Vector2(x - 8.0, h * 0.44), Vector2(x - 4.0, h * 0.12), Vector2(x + 4.0, h * 0.12), Vector2(x + 8.0, h * 0.44)]), 0.5)
		if k % 2 == 0:
			O(ci, Vector2(x, h * 0.3), 2.0, 0.6)
	E.hatch(ci, Rect2(w * 0.03, h * 0.5, w * 0.94, h * 0.18), 12.0, true, 0.2, 80)


# a tether damper: the hydraulic cylinder with its rod, the spring round it, the
# clevis eyes, the gas reservoir
static func tether_damper(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ay: float = h * 0.5
	O(ci, Vector2(h * 0.3, ay), h * 0.22, 0.55)
	O(ci, Vector2(w - h * 0.3, ay), h * 0.22, 0.55)
	R(ci, Rect2(h * 0.55, ay - h * 0.26, w * 0.46, h * 0.52), 0.6, 1.2)
	L(ci, Vector2(h * 0.55 + w * 0.46, ay), Vector2(w - h * 0.5, ay), 0.6, 1.8)
	var pts := PackedVector2Array()
	var nz := clampi(int(w * 0.6 / 4.0), 4, 30)
	for k in nz + 1:
		pts.append(Vector2(w * 0.2 + k * w * 0.6 / nz, ay + (h * 0.38 if k % 2 == 0 else -h * 0.38)))
	P(ci, pts, 0.3)
	R(ci, Rect2(h * 0.7, ay - h * 0.46, w * 0.18, h * 0.16), 0.45)


# a hydraulic clamp: the jaw (fixed and moving halves), the cylinder pushing the
# moving one, the hose connections, the base plate's bolts
static func hyd_clamp(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(w * 0.04, h * 0.84, w * 0.92, h * 0.12), 0.55)
	E.bolts(ci, Vector2(w * 0.08, h * 0.9), Vector2(w * 0.92, h * 0.9), 4, 0.5, 1.0)
	P(ci, PackedVector2Array([Vector2(w * 0.08, h * 0.84), Vector2(w * 0.08, h * 0.12), Vector2(w * 0.3, h * 0.12), Vector2(w * 0.3, h * 0.4), Vector2(w * 0.2, h * 0.4), Vector2(w * 0.2, h * 0.84)]), 0.6, 1.2)
	R(ci, Rect2(w * 0.32, h * 0.14, w * 0.16, h * 0.26), 0.6, 1.2)
	E.hatch(ci, Rect2(w * 0.3, h * 0.16, w * 0.02, h * 0.22), 2.0, false, 0.4, 10)
	L(ci, Vector2(w * 0.48, h * 0.27), Vector2(w * 0.6, h * 0.27), 0.6, 2.0)
	R(ci, Rect2(w * 0.6, h * 0.14, w * 0.34, h * 0.26), 0.6, 1.2)
	for f in [0.66, 0.88]:
		L(ci, Vector2(w * f, h * 0.4), Vector2(w * f, h * 0.84), 0.4)
		D(ci, Vector2(w * f, h * 0.42), 1.2, 0.55)


# a grand piano side-on: the case's long curve, the open lid on its prop, the
# keyboard and the music desk, the legs and the pedal lyre
static func piano(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var ty: float = h * 0.46
	P(ci, PackedVector2Array([Vector2(w * 0.04, ty), Vector2(w * 0.96, ty), Vector2(w * 0.96, ty + h * 0.16), Vector2(w * 0.04, ty + h * 0.16), Vector2(w * 0.04, ty)]), 0.6, 1.2)
	L(ci, Vector2(w * 0.1, ty), Vector2(w * 0.9, h * 0.06), 0.55, 1.4)
	L(ci, Vector2(w * 0.6, ty), Vector2(w * 0.62, h * 0.2), 0.45)
	R(ci, Rect2(w * 0.86, ty - h * 0.12, w * 0.1, h * 0.12), 0.5)
	E.hatch(ci, Rect2(w * 0.86, ty - h * 0.06, w * 0.1, h * 0.05), 2.0, true, 0.4, 20)
	L(ci, Vector2(w * 0.84, ty - h * 0.2), Vector2(w * 0.86, ty - h * 0.06), 0.45)
	for f in [0.08, 0.5, 0.9]:
		L(ci, Vector2(w * f, ty + h * 0.16), Vector2(w * f, h * 0.96), 0.55, 1.6)
	P(ci, PackedVector2Array([Vector2(w * 0.78, ty + h * 0.16), Vector2(w * 0.76, h * 0.9), Vector2(w * 0.8, h * 0.9), Vector2(w * 0.78, ty + h * 0.16)]), 0.45)
	var segs := PackedVector2Array()
	for k in 8:
		var x: float = w * (0.12 + k * 0.08)
		segs.append(Vector2(x, ty + 2.0))
		segs.append(Vector2(x + w * 0.06, ty + h * 0.14))
	S(ci, segs, 0.15)


# a wine wall: the diamond lattice of bottle bins, the bottle ends in them, the
# climate unit's grille at the top
static func wine_rack(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	R(ci, Rect2(1, 1, w - 2, h - 2), 0.55)
	E.louvres(ci, Rect2(4, 3, w - 8, h * 0.08), 0.3)
	var top: float = h * 0.12
	var s: float = clampf(w / 6.0, 8.0, 20.0)
	var segs := PackedVector2Array()
	var k := -int(h / s) - 2
	while k * s < w + h:
		segs.append(Vector2(k * s, top))
		segs.append(Vector2(k * s + (h - top), h))
		segs.append(Vector2(k * s + (h - top), top))
		segs.append(Vector2(k * s, h))
		k += 1
	# clip to the frame by drawing only the inner segments
	var clipped := PackedVector2Array()
	for i in range(0, segs.size(), 2):
		var res := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([segs[i], segs[i + 1]]), PackedVector2Array([Vector2(2, top), Vector2(w - 2, top), Vector2(w - 2, h - 2), Vector2(2, h - 2)]))
		for seg in res:
			if seg.size() >= 2:
				clipped.append(seg[0])
				clipped.append(seg[seg.size() - 1])
	S(ci, clipped, 0.4)
	for j in int((h - top) / s):
		for i in int(w / s):
			var c := Vector2((i + 0.5) * s, top + (j + 0.5) * s)
			if c.x < w - 4.0 and c.y < h - 4.0:
				O(ci, c, s * 0.12, 0.5)


# a bar: the counter with its foot rail, the beer taps, the back bar's shelves of
# bottles, the glass rack
static func bar(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cy: float = h * 0.56
	L(ci, Vector2(1, cy), Vector2(w - 1, cy), 0.65, 2.2)
	R(ci, Rect2(w * 0.04, cy, w * 0.92, h * 0.42), 0.5)
	L(ci, Vector2(w * 0.04, h * 0.92), Vector2(w * 0.96, h * 0.92), 0.45, 1.4)
	for k in 3:
		var x: float = w * (0.5 + k * 0.08)
		L(ci, Vector2(x, cy), Vector2(x, cy - h * 0.12), 0.55, 1.4)
		L(ci, Vector2(x, cy - h * 0.12), Vector2(x + 3.0, cy - h * 0.1), 0.55)
	for row in 2:
		var y: float = h * (0.12 + row * 0.18)
		L(ci, Vector2(w * 0.04, y + h * 0.12), Vector2(w * 0.96, y + h * 0.12), 0.45)
		var n := clampi(int(w / 7.0), 3, 40)
		for i in n:
			var x: float = w * 0.06 + i * w * 0.88 / n
			var bh: float = h * (0.08 + 0.03 * fposmod(i * 0.37 + row, 1.0))
			P(ci, PackedVector2Array([Vector2(x, y + h * 0.12), Vector2(x, y + h * 0.12 - bh * 0.6), Vector2(x + 1.0, y + h * 0.12 - bh), Vector2(x + 2.0, y + h * 0.12 - bh), Vector2(x + 3.0, y + h * 0.12 - bh * 0.6), Vector2(x + 3.0, y + h * 0.12)]), 0.4)


# a cone crusher: the bowl liner and the mantle gyrating inside it, the eccentric
# and main shaft, the feed hopper on top, the countershaft to the motor, the frame
static func crusher(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cx: float = w * 0.46
	var s: float = minf(w * 0.4, h * 0.42)
	# hopper
	P(ci, PackedVector2Array([Vector2(cx - s * 0.9, h * 0.04), Vector2(cx - s * 0.4, h * 0.22), Vector2(cx + s * 0.4, h * 0.22), Vector2(cx + s * 0.9, h * 0.04)]), 0.55, 1.2)
	# bowl (outer) and mantle (inner cone)
	P(ci, PackedVector2Array([Vector2(cx - s * 0.5, h * 0.22), Vector2(cx - s, h * 0.6), Vector2(cx - s, h * 0.72), Vector2(cx + s, h * 0.72), Vector2(cx + s, h * 0.6), Vector2(cx + s * 0.5, h * 0.22)]), 0.65, 1.4)
	P(ci, PackedVector2Array([Vector2(cx - s * 0.12, h * 0.3), Vector2(cx - s * 0.78, h * 0.66), Vector2(cx + s * 0.82, h * 0.64), Vector2(cx + s * 0.16, h * 0.3), Vector2(cx - s * 0.12, h * 0.3)]), 0.55, 1.2)
	var segs := PackedVector2Array()
	for k in 5:
		var t: float = (k + 1) / 6.0
		segs.append(Vector2(lerpf(cx - s * 0.12, cx - s * 0.78, t), lerpf(h * 0.3, h * 0.66, t)))
		segs.append(Vector2(lerpf(cx + s * 0.16, cx + s * 0.82, t), lerpf(h * 0.3, h * 0.64, t)))
	S(ci, segs, 0.15)
	L(ci, Vector2(cx, h * 0.26), Vector2(cx, h * 0.86), 0.55, 1.6)
	R(ci, Rect2(cx - s * 0.3, h * 0.72, s * 0.6, h * 0.12), 0.55)
	O(ci, Vector2(cx, h * 0.78), s * 0.1, 0.5)
	# countershaft to the motor
	L(ci, Vector2(cx + s * 0.3, h * 0.78), Vector2(w * 0.86, h * 0.78), 0.5, 1.4)
	E.motor(ci, Rect2(w * 0.8, h * 0.62, w * 0.18, h * 0.2), true, 0.5)
	# frame and discharge
	L(ci, Vector2(cx - s, h * 0.72), Vector2(cx - s * 1.1, h * 0.97), 0.5, 1.4)
	L(ci, Vector2(cx + s, h * 0.72), Vector2(cx + s * 1.1, h * 0.97), 0.5, 1.4)
	L(ci, Vector2(cx - s * 1.2, h * 0.97), Vector2(w - 2, h * 0.97), 0.55, 1.6)


# ================================================================== named auxiliaries (E002–E016)
# 2026-11-11, the user on the 零件图鉴: fifteen machines all drew as the same shared "aux" valve
# ("不要有重复…精度要做到和目前的这些一样高"). Each is drawn here as the machine it is, in the
# piece's own rect (r.position honoured), at the fidelity of apu / the battery cabinet.

static func _u(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + r.size * Vector2(x, y)


static func _pu(ci: CanvasItem, r: Rect2, pts: Array, al: float = 0.5, wd: float = 1.0, closed: bool = false) -> void:
	var q := PackedVector2Array()
	for p in pts:
		q.append(_u(r, p.x, p.y))
	if closed and q.size() > 2:
		q.append(q[0])
	P(ci, q, al, wd)


static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, al: float = 0.5, wd: float = 1.0, a0: float = 0.0, a1: float = TAU) -> void:
	var n := clampi(int(maxf(rx, ry) * absf(a1 - a0) * 0.25) + 6, 8, 36)
	var q := PackedVector2Array()
	for k in n + 1:
		var a: float = a0 + (a1 - a0) * k / n
		q.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	P(ci, q, al, wd)


# a small coloured indicator (the one place these drawings use the signal tints)
static func _lamp(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	E.Rc(ci, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), col, 1.0)


# a ribbed stand-off insulator from base up to top
static func _insulator(ci: CanvasItem, base: Vector2, top: Vector2, rad: float, al: float = 0.5) -> void:
	L(ci, base, top, al * 0.8)
	var n := clampi(int(base.distance_to(top) / 3.0), 2, 6)
	var segs := PackedVector2Array()
	for k in n:
		var c: Vector2 = base.lerp(top, (k + 0.5) / n)
		var rr: float = rad * (1.0 if k % 2 == 0 else 0.7)
		segs.append(c - Vector2(rr, 0))
		segs.append(c + Vector2(rr, 0))
	S(ci, segs, al)


# ---------------------------------------------------------------- ARK-01: RF power amplifier
# a rack amplifier: power meter and key switch up top, three transistor pallets on their
# finned sinks feeding a combiner, the rigid-coax RF output out of the roof, the mains
# transformer and the cooling fan underneath, rack ears with their screws
static func rf_amp(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cab := sub(r, 0.1, 0.05, 0.9, 0.95)
	R(ci, cab, 0.62, 1.2)
	for x in [0.04, 0.9]:
		R(ci, sub(r, x, 0.07, x + 0.06, 0.93), 0.42)
		for y in [0.12, 0.5, 0.88]:
			D(ci, _u(r, x + 0.03, y), 0.9, 0.5)
	R(ci, sub(r, 0.12, 0.95, 0.88, 0.985), 0.5)
	# control strip: forward-power meter, RF-on lamp, key switch, reset
	R(ci, sub(r, 0.14, 0.08, 0.72, 0.2), 0.45)
	var mc := _u(r, 0.27, 0.175)
	var mr: float = r.size.x * 0.1
	A(ci, mc, mr, PI * 1.15, PI * 1.85, 0.5)
	L(ci, mc, mc + Vector2.from_angle(PI * 1.38) * mr * 0.95, 0.6)
	_lamp(ci, _u(r, 0.46, 0.135), maxf(1.6, ms * 0.045), Pal.tint(Pal.VOLT, 0.85))
	O(ci, _u(r, 0.57, 0.14), maxf(1.4, ms * 0.04), 0.5)
	L(ci, _u(r, 0.545, 0.14), _u(r, 0.595, 0.14), 0.5)
	D(ci, _u(r, 0.66, 0.14), 1.0, 0.5)
	# three amplifier pallets: fins, the transistor on its flange, matching lines, coax jumper
	for i in 3:
		var y0: float = 0.235 + i * 0.145
		R(ci, sub(r, 0.14, y0, 0.74, y0 + 0.125), 0.5)
		hatch(ci, sub(r, 0.15, y0 + 0.012, 0.36, y0 + 0.113), 2.4, true, 0.28, 14)
		var tr := sub(r, 0.44, y0 + 0.035, 0.52, y0 + 0.09)
		R(ci, tr, 0.58)
		D(ci, tr.get_center(), 0.9, 0.6)
		L(ci, _u(r, 0.37, y0 + 0.0625), _u(r, 0.44, y0 + 0.0625), 0.4)
		_pu(ci, r, [Vector2(0.52, y0 + 0.0625), Vector2(0.6, y0 + 0.0625), Vector2(0.6, y0 + 0.04), Vector2(0.67, y0 + 0.04)], 0.4)
		_pu(ci, r, [Vector2(0.67, y0 + 0.04), Vector2(0.74, y0 + 0.04), Vector2(0.78, y0 + 0.06)], 0.5, 1.3)
	# the combiner up the right side; the rigid-coax output leaves through the roof
	R(ci, sub(r, 0.77, 0.23, 0.86, 0.67), 0.55)
	for i in 3:
		D(ci, _u(r, 0.815, 0.295 + i * 0.145), 1.0, 0.55)
	L(ci, _u(r, 0.815, 0.23), _u(r, 0.815, 0.055), 0.6, 1.6)
	E.flange(ci, _u(r, 0.815, 0.055), Vector2.UP, r.size.x * 0.07, 0.6)
	L(ci, _u(r, 0.815, 0.03), _u(r, 0.815, 0.0), 0.5, 1.4)
	# power supply: transformer (core window, winding) and the fan
	var ps := sub(r, 0.14, 0.7, 0.86, 0.92)
	R(ci, ps, 0.5)
	R(ci, sub(r, 0.18, 0.725, 0.42, 0.895), 0.45)
	R(ci, sub(r, 0.24, 0.75, 0.36, 0.87), 0.4)
	hatch(ci, sub(r, 0.245, 0.755, 0.355, 0.865), 2.0, false, 0.25, 12)
	var fr: float = minf(r.size.x * 0.15, r.size.y * 0.095)
	E.fan(ci, _u(r, 0.65, 0.81), fr, 5, 0.45)
	E.corner_bolts(ci, ps, 2.0, 0.4)
	L(ci, _u(r, 0.82, 0.92), _u(r, 0.82, 0.95), 0.5, 1.4)


# ---------------------------------------------------------------- GR-7: auxiliary thruster
# a small bipropellant thruster, exhaust to the right: fuel and oxidiser lines each through
# a solenoid valve into the injector head, the chamber with its cooling rings and
# pressure transducer, throat, bell with stiffening rings, the mount struts beneath
static func aux_rocket(ci: CanvasItem, r: Rect2) -> void:
	for s in [-1.0, 1.0]:
		var yl: float = 0.5 + s * 0.34
		L(ci, _u(r, 0.0, yl), _u(r, 0.1, yl), 0.5, 1.3)
		var vb := sub(r, 0.1, yl - 0.1, 0.17, yl + 0.1)
		R(ci, vb, 0.55)
		hatch(ci, vb.grow(-1.5), 2.0, true, 0.3, 10)
		D(ci, _u(r, 0.135, yl - s * 0.13), 0.8, 0.5)
		_pu(ci, r, [Vector2(0.17, yl), Vector2(0.2, yl), Vector2(0.225, 0.5 + s * 0.22)], 0.5, 1.3)
	# injector head and its bolt ring
	R(ci, sub(r, 0.22, 0.17, 0.27, 0.83), 0.6, 1.3)
	E.bolts(ci, _u(r, 0.245, 0.2), _u(r, 0.245, 0.8), 4, 0.5, 0.8)
	# chamber, throat, bell
	var up := PackedVector2Array([_u(r, 0.27, 0.26), _u(r, 0.48, 0.26), _u(r, 0.56, 0.42), _u(r, 0.6, 0.42)])
	var dn := PackedVector2Array([_u(r, 0.27, 0.74), _u(r, 0.48, 0.74), _u(r, 0.56, 0.58), _u(r, 0.6, 0.58)])
	var rings := PackedVector2Array()
	for k in 13:
		var t: float = k / 12.0
		var half: float = 0.08 + 0.4 * pow(t, 0.62)
		var x: float = 0.6 + 0.38 * t
		up.append(_u(r, x, 0.5 - half))
		dn.append(_u(r, x, 0.5 + half))
		if k == 4 or k == 8:
			rings.append(_u(r, x, 0.5 - half))
			rings.append(_u(r, x, 0.5 + half))
	P(ci, up, 0.62, 1.2)
	P(ci, dn, 0.62, 1.2)
	S(ci, rings, 0.3)
	L(ci, up[up.size() - 1], dn[dn.size() - 1], 0.55, 1.5)
	L(ci, _u(r, 0.6, 0.42), _u(r, 0.6, 0.58), 0.4)
	hatch(ci, sub(r, 0.29, 0.27, 0.46, 0.73), 4.0, true, 0.22, 14)
	L(ci, _u(r, 0.52, 0.5), _u(r, 0.95, 0.5), 0.15)
	# chamber pressure transducer on its stub
	L(ci, _u(r, 0.41, 0.26), _u(r, 0.41, 0.12), 0.5)
	R(ci, sub(r, 0.395, 0.03, 0.425, 0.12), 0.5)
	# mount: two struts down to the bracket plate
	_pu(ci, r, [Vector2(0.3, 0.74), Vector2(0.33, 0.95), Vector2(0.43, 0.95), Vector2(0.46, 0.74)], 0.5, 1.2)
	R(ci, sub(r, 0.29, 0.95, 0.47, 1.0), 0.5)


# ---------------------------------------------------------------- AX-40: gamma monitor
# an area gamma monitor: the readout with its log-scale dial, alarm beacon, lamps and reset,
# beside the detector probe in its wall clamp (end cap, crystal, window grille), the signal
# cable looping up from the probe into the readout
static func gamma_probe(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var box := sub(r, 0.04, 0.26, 0.58, 0.95)
	R(ci, box, 0.62, 1.2)
	R(ci, sub(r, 0.09, 0.34, 0.53, 0.68), 0.35)
	var dc := _u(r, 0.31, 0.64)
	var dr: float = r.size.x * 0.19
	A(ci, dc, dr, PI * 1.12, PI * 1.88, 0.55)
	var segs := PackedVector2Array()
	for k in 6:
		var a: float = PI * 1.12 + PI * 0.76 * pow(k / 5.0, 0.7)
		segs.append(dc + Vector2.from_angle(a) * dr)
		segs.append(dc + Vector2.from_angle(a) * dr * (0.7 if k % 2 == 0 else 0.84))
	S(ci, segs, 0.4)
	L(ci, dc, dc + Vector2.from_angle(PI * 1.3) * dr * 0.92, 0.65)
	D(ci, dc, 1.0, 0.6)
	_lamp(ci, _u(r, 0.15, 0.81), maxf(1.4, ms * 0.06), Pal.tint(Pal.FLUID, 0.85))
	_lamp(ci, _u(r, 0.27, 0.81), maxf(1.4, ms * 0.06), Pal.heat(0.9))
	R(ci, sub(r, 0.37, 0.76, 0.52, 0.87), 0.45)
	# the alarm beacon on top
	var bc := _u(r, 0.31, 0.26)
	A(ci, bc, r.size.x * 0.1, PI, TAU, 0.55)
	_lamp(ci, bc - Vector2(0, r.size.x * 0.045), maxf(1.2, ms * 0.05), Pal.heat(0.75))
	L(ci, bc - Vector2(r.size.x * 0.14, 0), bc + Vector2(r.size.x * 0.14, 0), 0.55, 1.3)
	# the detector probe in its clamp
	R(ci, sub(r, 0.7, 0.1, 0.9, 0.76), 0.6, 1.2)
	R(ci, sub(r, 0.68, 0.05, 0.92, 0.13), 0.5)
	L(ci, _u(r, 0.7, 0.58), _u(r, 0.9, 0.58), 0.45)
	hatch(ci, sub(r, 0.72, 0.6, 0.88, 0.75), 2.0, true, 0.35, 8)
	L(ci, _u(r, 0.8, 0.16), _u(r, 0.8, 0.55), 0.25)
	R(ci, sub(r, 0.66, 0.3, 0.94, 0.38), 0.45)
	L(ci, _u(r, 0.94, 0.34), _u(r, 1.0, 0.34), 0.45, 1.3)
	_pu(ci, r, [Vector2(0.8, 0.05), Vector2(0.8, 0.02), Vector2(0.63, 0.02), Vector2(0.63, 0.5), Vector2(0.58, 0.5)], 0.42, 1.2)


# ---------------------------------------------------------------- BL-88: fish feeder
# an automatic fish feeder over the tank rim: lidded hopper with its pellets, the auger tube
# and its gear motor, the drop chute onto the spinner that throws the feed, the timer box,
# the frame clamped to the rim, the water below
static func pellet_feeder(ci: CanvasItem, r: Rect2) -> void:
	_pu(ci, r, [Vector2(0.14, 0.1), Vector2(0.14, 0.3), Vector2(0.36, 0.5), Vector2(0.52, 0.5), Vector2(0.74, 0.3), Vector2(0.74, 0.1)], 0.62, 1.2)
	_pu(ci, r, [Vector2(0.12, 0.1), Vector2(0.76, 0.1), Vector2(0.76, 0.06), Vector2(0.12, 0.06)], 0.55, 1.0, true)
	D(ci, _u(r, 0.12, 0.08), 1.1, 0.55)
	_pu(ci, r, [Vector2(0.4, 0.06), Vector2(0.4, 0.035), Vector2(0.48, 0.035), Vector2(0.48, 0.06)], 0.5)
	L(ci, _u(r, 0.15, 0.2), _u(r, 0.73, 0.2), 0.28)
	for i in 16:
		var y: float = 0.23 + fposmod(i * 0.611, 1.0) * 0.24
		var cut: float = maxf(0.0, y - 0.3) / 0.2 * 0.22
		var x: float = lerpf(0.17 + cut, 0.71 - cut, fposmod(i * 0.377 + 0.13, 1.0))
		D(ci, _u(r, x, y), 0.85, 0.42)
	# auger: tube, flights, shaft, the gear motor driving it
	R(ci, sub(r, 0.24, 0.5, 0.86, 0.62), 0.58)
	var fl := PackedVector2Array()
	for k in 12:
		fl.append(_u(r, 0.27 + k * 0.05, 0.515 if k % 2 == 0 else 0.605))
	P(ci, fl, 0.38)
	L(ci, _u(r, 0.25, 0.56), _u(r, 0.85, 0.56), 0.25)
	E.motor(ci, sub(r, 0.02, 0.51, 0.23, 0.62), false, 0.5)
	# chute and spinner
	L(ci, _u(r, 0.78, 0.62), _u(r, 0.78, 0.72), 0.5)
	L(ci, _u(r, 0.86, 0.62), _u(r, 0.86, 0.72), 0.5)
	L(ci, _u(r, 0.72, 0.76), _u(r, 0.92, 0.76), 0.55, 1.6)
	R(ci, sub(r, 0.78, 0.77, 0.86, 0.85), 0.5)
	for q in [Vector2(0.95, 0.72), Vector2(0.98, 0.79), Vector2(0.68, 0.73), Vector2(0.64, 0.8)]:
		D(ci, _u(r, q.x, q.y), 0.8, 0.35)
	# timer box: display, two buttons, its cable to the motor
	R(ci, sub(r, 0.03, 0.68, 0.29, 0.86), 0.5)
	E.Rc(ci, sub(r, 0.06, 0.71, 0.19, 0.77), Pal.tint(Pal.FLUID, 0.7), 1.0)
	D(ci, _u(r, 0.24, 0.73), 1.0, 0.5)
	D(ci, _u(r, 0.24, 0.81), 1.0, 0.5)
	L(ci, _u(r, 0.12, 0.68), _u(r, 0.12, 0.62), 0.35)
	# frame to the rim clamp, the water
	L(ci, _u(r, 0.36, 0.62), _u(r, 0.36, 0.9), 0.5, 1.3)
	L(ci, _u(r, 0.7, 0.62), _u(r, 0.7, 0.9), 0.5, 1.3)
	R(ci, sub(r, 0.0, 0.9, 1.0, 0.935), 0.55)
	D(ci, _u(r, 0.36, 0.918), 1.0, 0.6)
	D(ci, _u(r, 0.7, 0.918), 1.0, 0.6)
	var wv := PackedVector2Array()
	for k in 11:
		wv.append(_u(r, k * 0.1, 0.968 + (0.012 if k % 2 == 0 else -0.012)))
	P(ci, wv, 0.3)


# ---------------------------------------------------------------- BL-88: steam humidifier
# an electrode-boiler humidifier: control side (display, contactor, terminals, cable gland)
# beside the steam cylinder (electrodes, the boiling water in it), its fill valve and
# drain, the steam hose up to the dispersion tube puffing into the garden air
static func steam_cyl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cab := sub(r, 0.04, 0.14, 0.96, 0.92)
	R(ci, cab, 0.6, 1.2)
	L(ci, _u(r, 0.4, 0.14), _u(r, 0.4, 0.92), 0.4)
	R(ci, sub(r, 0.08, 0.2, 0.34, 0.31), 0.45)
	_lamp(ci, _u(r, 0.28, 0.255), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.8))
	L(ci, _u(r, 0.11, 0.255), _u(r, 0.22, 0.255), 0.35)
	R(ci, sub(r, 0.1, 0.37, 0.32, 0.55), 0.45)
	L(ci, _u(r, 0.21, 0.39), _u(r, 0.21, 0.53), 0.35)
	for x in [0.13, 0.21, 0.29]:
		D(ci, _u(r, x, 0.63), 0.9, 0.5)
	L(ci, _u(r, 0.2, 0.92), _u(r, 0.2, 1.0), 0.5, 1.3)
	# the steam cylinder and its water
	E.Rc(ci, sub(r, 0.52, 0.56, 0.84, 0.78), Pal.tint(Pal.FLUID, 0.32), 1.0)
	_pu(ci, r, [Vector2(0.5, 0.31), Vector2(0.54, 0.25), Vector2(0.82, 0.25), Vector2(0.86, 0.31), Vector2(0.86, 0.76), Vector2(0.82, 0.82), Vector2(0.54, 0.82), Vector2(0.5, 0.76)], 0.62, 1.2, true)
	for x in [0.6, 0.68, 0.76]:
		L(ci, _u(r, x, 0.27), _u(r, x, 0.72), 0.42)
		D(ci, _u(r, x, 0.27), 1.0, 0.55)
	for q in [Vector2(0.64, 0.66), Vector2(0.72, 0.6), Vector2(0.81, 0.7)]:
		O(ci, _u(r, q.x, q.y), maxf(0.8, ms * 0.018), 0.35)
	# fill solenoid and drain valve
	_pu(ci, r, [Vector2(0.58, 0.82), Vector2(0.58, 0.88), Vector2(0.5, 0.88)], 0.45)
	R(ci, sub(r, 0.44, 0.85, 0.5, 0.91), 0.5)
	L(ci, _u(r, 0.47, 0.91), _u(r, 0.47, 1.0), 0.45)
	L(ci, _u(r, 0.78, 0.82), _u(r, 0.78, 1.0), 0.45)
	_pu(ci, r, [Vector2(0.74, 0.86), Vector2(0.82, 0.9), Vector2(0.82, 0.86), Vector2(0.74, 0.9)], 0.5, 1.0, true)
	# steam hose to the dispersion tube
	_pu(ci, r, [Vector2(0.68, 0.25), Vector2(0.68, 0.08)], 0.55, 1.6)
	L(ci, _u(r, 0.26, 0.06), _u(r, 0.98, 0.06), 0.55, 1.4)
	for x in [0.34, 0.5, 0.84]:
		A(ci, _u(r, x, 0.035), maxf(1.2, ms * 0.03), PI * 1.1, PI * 1.9, 0.3)


# ---------------------------------------------------------------- BL-88: high-pressure mister
# a fogging set for the plant beds: inlet filter bowl, the motor driving a triplex plunger
# pump, pressure gauge, the riser to the nozzle bar, each nozzle with its fine spray cone
static func fog_pump(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.04, 0.1), _u(r, 0.94, 0.1), 0.6, 1.6)
	R(ci, sub(r, 0.94, 0.075, 0.98, 0.125), 0.5)
	for x in [0.14, 0.36, 0.58, 0.8]:
		D(ci, _u(r, x, 0.125), 1.1, 0.6)
		var segs := PackedVector2Array([_u(r, x, 0.14), _u(r, x - 0.07, 0.27), _u(r, x, 0.14), _u(r, x + 0.07, 0.27)])
		S(ci, segs, 0.26)
		D(ci, _u(r, x - 0.03, 0.24), 0.6, 0.28)
		D(ci, _u(r, x + 0.04, 0.21), 0.6, 0.28)
	# riser from the pump discharge, gauge on its tee
	_pu(ci, r, [Vector2(0.72, 0.48), Vector2(0.72, 0.36), Vector2(0.9, 0.36), Vector2(0.9, 0.1)], 0.5, 1.3)
	L(ci, _u(r, 0.72, 0.42), _u(r, 0.64, 0.42), 0.45)
	E.gauge(ci, _u(r, 0.58, 0.41), maxf(2.5, ms * 0.065), 0.55)
	# triplex plunger pump: crankcase, three heads under the discharge manifold
	R(ci, sub(r, 0.36, 0.58, 0.82, 0.78), 0.58)
	for i in 3:
		R(ci, sub(r, 0.4 + i * 0.14, 0.5, 0.5 + i * 0.14, 0.58), 0.5)
	L(ci, _u(r, 0.38, 0.48), _u(r, 0.8, 0.48), 0.55, 1.4)
	O(ci, _u(r, 0.59, 0.68), maxf(1.6, ms * 0.045), 0.45)
	D(ci, _u(r, 0.59, 0.68), 0.8, 0.5)
	E.motor(ci, sub(r, 0.04, 0.6, 0.33, 0.78), false, 0.5)
	# inlet filter: head, bowl, pleated element, the water in it
	R(ci, sub(r, 0.1, 0.32, 0.28, 0.36), 0.55)
	E.Rc(ci, sub(r, 0.13, 0.45, 0.25, 0.53), Pal.tint(Pal.FLUID, 0.35), 1.0)
	_pu(ci, r, [Vector2(0.12, 0.36), Vector2(0.12, 0.5), Vector2(0.16, 0.54), Vector2(0.22, 0.54), Vector2(0.26, 0.5), Vector2(0.26, 0.36)], 0.55)
	E.pleats(ci, sub(r, 0.15, 0.38, 0.23, 0.5), 2.0, true, 0.3)
	L(ci, _u(r, 0.0, 0.34), _u(r, 0.1, 0.34), 0.5, 1.3)
	_pu(ci, r, [Vector2(0.28, 0.34), Vector2(0.345, 0.34), Vector2(0.345, 0.835), Vector2(0.45, 0.835), Vector2(0.45, 0.78)], 0.45)
	# skid and its feet
	R(ci, sub(r, 0.02, 0.87, 0.98, 0.93), 0.55)
	for x in [0.08, 0.92]:
		R(ci, sub(r, x - 0.04, 0.93, x + 0.04, 0.98), 0.45)


# ---------------------------------------------------------------- the radio / comms console
# fleet-wide (17 ships, 1 x 0.7 m to 3.6 x 1.5 m): a desk console where it is wider than
# tall, a 19-inch radio rack where it is tall
static func comms_desk(ci: CanvasItem, r: Rect2) -> void:
	if r.size.x < r.size.y * 0.8:
		_comms_rack(ci, r)
		return
	var ms := minf(r.size.x, r.size.y)
	# the coax feeds to the antennas leave through the ceiling
	for x in [0.74, 0.82]:
		L(ci, _u(r, x, 0.12), _u(r, x, 0.0), 0.5, 1.3)
		E.flange(ci, _u(r, x, 0.12), Vector2.DOWN, maxf(1.5, r.size.x * 0.02), 0.5)
	# upright panel with its screens, speaker grille
	var up := sub(r, 0.08, 0.14, 0.92, 0.58)
	R(ci, up, 0.58, 1.2)
	var n := clampi(int(r.size.x / 46.0), 1, 3)
	var sw: float = 0.62 / n
	for i in n:
		E.screen_face(ci, sub(r, 0.12 + i * sw, 0.19, 0.12 + (i + 1) * sw - 0.025, 0.52), [0, 3, 1][i % 3], 0.35)
	hatch(ci, sub(r, 0.76, 0.2, 0.88, 0.36), 2.2, false, 0.3, 10)
	R(ci, sub(r, 0.76, 0.2, 0.88, 0.36), 0.4)
	_lamp(ci, _u(r, 0.79, 0.46), maxf(1.4, ms * 0.04), Pal.tint(Pal.AIR, 0.85))
	_lamp(ci, _u(r, 0.85, 0.46), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.7))
	# sloped transceiver strip: frequency readout, tuning knob, small knobs
	_pu(ci, r, [Vector2(0.04, 0.72), Vector2(0.08, 0.6), Vector2(0.92, 0.6), Vector2(0.96, 0.72)], 0.58, 1.2, true)
	E.Rc(ci, sub(r, 0.12, 0.63, 0.32, 0.68), Pal.tint(Pal.AIR, 0.6), 1.0)
	var kc := _u(r, 0.42, 0.66)
	O(ci, kc, maxf(1.8, ms * 0.05), 0.55)
	D(ci, kc, 0.8, 0.55)
	for i in 4:
		D(ci, _u(r, 0.5 + i * 0.05, 0.66), 1.0, 0.5)
	# gooseneck microphone and the handset on its hook
	_pu(ci, r, [Vector2(0.72, 0.6), Vector2(0.72, 0.54), Vector2(0.69, 0.48), Vector2(0.66, 0.46)], 0.5, 1.2)
	R(ci, sub(r, 0.62, 0.44, 0.67, 0.48), 0.55)
	R(ci, sub(r, 0.92, 0.3, 0.96, 0.5), 0.5)
	_pu(ci, r, [Vector2(0.94, 0.5), Vector2(0.92, 0.56), Vector2(0.96, 0.6), Vector2(0.93, 0.66)], 0.35)
	# desk: pedestal with drawers, legs, kick plate
	L(ci, _u(r, 0.04, 0.72), _u(r, 0.96, 0.72), 0.55, 1.3)
	R(ci, sub(r, 0.6, 0.72, 0.94, 0.96), 0.5)
	for y in [0.8, 0.88]:
		L(ci, _u(r, 0.6, y), _u(r, 0.94, y), 0.4)
		L(ci, _u(r, 0.74, y - 0.04), _u(r, 0.8, y - 0.04), 0.5)
	L(ci, _u(r, 0.08, 0.72), _u(r, 0.08, 0.96), 0.5, 1.3)
	L(ci, _u(r, 0.04, 0.96), _u(r, 0.96, 0.96), 0.5)


# the radio rack: patch panel of coax connectors under the roof feed-through, transceivers
# (display, tuning knob, small knobs), the speaker, a handset on its coiled cord, the PSU
static func _comms_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.1, 0.05, 0.9, 0.97), 0.62, 1.2)
	for x in [0.14, 0.86]:
		var segs := PackedVector2Array()
		for k in 14:
			var y: float = 0.08 + k * 0.064
			segs.append(_u(r, x, y))
			segs.append(_u(r, x, y + 0.012))
		S(ci, segs, 0.4, 1.2)
	# coax up through the roof gland
	for x in [0.35, 0.5, 0.65]:
		L(ci, _u(r, x, 0.1), _u(r, x, 0.0), 0.5, 1.2)
	R(ci, sub(r, 0.3, 0.035, 0.7, 0.06), 0.5)
	R(ci, sub(r, 0.18, 0.08, 0.82, 0.15), 0.5)
	for i in 5:
		O(ci, _u(r, 0.25 + i * 0.125, 0.115), maxf(1.2, ms * 0.035), 0.5)
	# transceivers
	var y := 0.18
	var units := clampi(int(r.size.y / 34.0), 2, 4)
	var uh: float = 0.5 / units
	for i in units:
		var u := sub(r, 0.18, y, 0.82, y + uh - 0.015)
		R(ci, u, 0.52)
		E.Rc(ci, sub(r, 0.22, y + uh * 0.2, 0.5, y + uh * 0.55), Pal.tint(Pal.AIR, 0.6), 1.0)
		var kc := _u(r, 0.66, y + uh * 0.45)
		O(ci, kc, minf(r.size.x * 0.07, r.size.y * uh * 0.32), 0.55)
		D(ci, kc, 0.8, 0.55)
		for k in 3:
			D(ci, _u(r, 0.25 + k * 0.08, y + uh * 0.75), 0.9, 0.5)
		y += uh
	# speaker
	var sp := sub(r, 0.18, y, 0.82, y + 0.1)
	R(ci, sp, 0.45)
	hatch(ci, sp.grow(-2.0), 2.4, true, 0.28, 20)
	# PSU and its louvres
	var psu := sub(r, 0.18, y + 0.12, 0.82, 0.93)
	R(ci, psu, 0.5)
	E.louvres(ci, sub(r, 0.22, y + 0.15, 0.56, 0.9), 0.3)
	_lamp(ci, _u(r, 0.72, y + 0.17), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.75))
	# the handset hanging on the side
	R(ci, sub(r, 0.9, 0.3, 0.98, 0.46), 0.55)
	var cord := PackedVector2Array()
	for k in 8:
		cord.append(_u(r, 0.92 + (0.04 if k % 2 == 0 else 0.0), 0.46 + k * 0.025))
	P(ci, cord, 0.35)


# ---------------------------------------------------------------- DC-84: firewall
# a short open rack: two firewall appliances (port bank with link lamps, one port blocked;
# SFP cages; fan grille and status display on the second), a patch panel, the PDU strip,
# the patch cords dressed into a tied bundle out of the side
static func fw_appliance(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	for x in [0.02, 0.93]:
		R(ci, sub(r, x, 0.02, x + 0.05, 0.98), 0.5)
		var segs := PackedVector2Array()
		for k in 9:
			var y: float = 0.07 + k * 0.105
			segs.append(_u(r, x + 0.015, y))
			segs.append(_u(r, x + 0.035, y))
		S(ci, segs, 0.4, 1.4)
	# appliance 1: console + mgmt ports, 2x4 data ports with link lamps, two SFP cages
	var a1 := sub(r, 0.08, 0.08, 0.92, 0.32)
	R(ci, a1, 0.6, 1.2)
	R(ci, sub(r, 0.11, 0.13, 0.17, 0.2), 0.45)
	R(ci, sub(r, 0.11, 0.22, 0.17, 0.28), 0.45)
	for row in 2:
		for c in 4:
			var x0: float = 0.22 + c * 0.095
			var y0: float = 0.12 + row * 0.1
			R(ci, sub(r, x0, y0, x0 + 0.07, y0 + 0.07), 0.5)
			var col := Pal.heat(0.9) if row == 1 and c == 2 else Pal.tint(Pal.FLUID, 0.8)
			_lamp(ci, _u(r, x0 + 0.035, y0 + 0.09), maxf(1.0, ms * 0.025), col)
	for c in 2:
		var s := sub(r, 0.62 + c * 0.13, 0.13, 0.73 + c * 0.13, 0.25)
		R(ci, s, 0.5)
		L(ci, s.position + Vector2(1.5, s.size.y * 0.5), s.end - Vector2(1.5, s.size.y * 0.5), 0.3)
	# appliance 2: fan grille, status display, power button
	var a2 := sub(r, 0.08, 0.36, 0.92, 0.56)
	R(ci, a2, 0.58, 1.2)
	for x in [0.17, 0.33]:
		var c2 := _u(r, x, 0.46)
		var fr: float = minf(r.size.x * 0.065, r.size.y * 0.075)
		O(ci, c2, fr, 0.45)
		O(ci, c2, fr * 0.5, 0.3)
		L(ci, c2 - Vector2(fr, 0), c2 + Vector2(fr, 0), 0.3)
		L(ci, c2 - Vector2(0, fr), c2 + Vector2(0, fr), 0.3)
	E.Rc(ci, sub(r, 0.46, 0.4, 0.7, 0.5), Pal.tint(Pal.VOLT, 0.55), 1.0)
	L(ci, _u(r, 0.49, 0.43), _u(r, 0.63, 0.43), 0.35)
	L(ci, _u(r, 0.49, 0.47), _u(r, 0.58, 0.47), 0.35)
	O(ci, _u(r, 0.82, 0.46), maxf(1.4, ms * 0.04), 0.55)
	# patch panel
	R(ci, sub(r, 0.08, 0.6, 0.92, 0.71), 0.5)
	var pp := PackedVector2Array()
	for k in 12:
		var x: float = 0.13 + k * 0.064
		pp.append(_u(r, x, 0.64))
		pp.append(_u(r, x + 0.035, 0.64))
	S(ci, pp, 0.55, 2.0)
	# PDU
	R(ci, sub(r, 0.08, 0.83, 0.92, 0.93), 0.5)
	for k in 5:
		R(ci, sub(r, 0.14 + k * 0.15, 0.855, 0.2 + k * 0.15, 0.905), 0.42)
	# the patch cords: down out of the ports, dressed right into a tied bundle
	for k in 4:
		var x: float = 0.255 + k * 0.095
		var y: float = 0.745 + k * 0.018
		_pu(ci, r, [Vector2(x, 0.3), Vector2(x, 0.34)], 0.35)
		_pu(ci, r, [Vector2(0.15 + k * 0.1, 0.71), Vector2(0.15 + k * 0.1, y), Vector2(0.98, y)], 0.38)
	for x in [0.62, 0.8]:
		L(ci, _u(r, x, 0.735), _u(r, x, 0.81), 0.55, 1.3)


# ---------------------------------------------------------------- DR-150: rig welder
# an engine-driven welding set on its trolley: the case (louvres, exhaust stack, lifting
# eye), front panel (amperage dial, lamp, switch), the + and - output sockets; the torch
# lead coiled on its hook with the electrode holder hanging, the earth lead to its clamp
static func rig_welder(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cs := sub(r, 0.08, 0.14, 0.7, 0.62)
	R(ci, cs, 0.62, 1.2)
	A(ci, _u(r, 0.39, 0.14), r.size.x * 0.05, PI, TAU, 0.55, 1.3)
	L(ci, _u(r, 0.6, 0.14), _u(r, 0.6, 0.05), 0.55, 1.6)
	L(ci, _u(r, 0.56, 0.04), _u(r, 0.65, 0.06), 0.5)
	E.louvres(ci, sub(r, 0.12, 0.19, 0.29, 0.45), 0.32)
	R(ci, sub(r, 0.12, 0.18, 0.3, 0.46), 0.4)
	var pn := sub(r, 0.34, 0.18, 0.66, 0.46)
	R(ci, pn, 0.45)
	E.gauge(ci, _u(r, 0.47, 0.3), maxf(2.5, ms * 0.08), 0.55)
	_lamp(ci, _u(r, 0.61, 0.23), maxf(1.4, ms * 0.04), Pal.heat(0.9))
	R(ci, sub(r, 0.57, 0.36, 0.63, 0.42), 0.5)
	D(ci, _u(r, 0.4, 0.42), 0.9, 0.5)
	# output sockets: + and -
	var tp := _u(r, 0.22, 0.54)
	var tn := _u(r, 0.42, 0.54)
	var tr: float = maxf(1.6, ms * 0.04)
	O(ci, tp, tr, 0.6)
	O(ci, tn, tr, 0.6)
	L(ci, tp + Vector2(tr * 1.8, -tr * 1.3), tp + Vector2(tr * 3.0, -tr * 1.3), 0.45)
	L(ci, tp + Vector2(tr * 2.4, -tr * 1.9), tp + Vector2(tr * 2.4, -tr * 0.7), 0.45)
	L(ci, tn + Vector2(tr * 1.8, -tr * 1.3), tn + Vector2(tr * 3.0, -tr * 1.3), 0.45)
	# torch lead: from + round to the hook, coiled, the holder hanging below
	_pu(ci, r, [Vector2(0.7, 0.2), Vector2(0.79, 0.2), Vector2(0.79, 0.26)], 0.55, 1.3)
	for k in 3:
		_ell(ci, _u(r, 0.8 + k * 0.025, 0.42 + k * 0.012), r.size.x * 0.12, r.size.y * 0.15, 0.45, 1.2)
	_pu(ci, r, [Vector2(0.22, 0.54), Vector2(0.22, 0.68), Vector2(0.62, 0.68), Vector2(0.72, 0.56)], 0.45, 1.3)
	_pu(ci, r, [Vector2(0.87, 0.58), Vector2(0.88, 0.7)], 0.45, 1.3)
	L(ci, _u(r, 0.88, 0.7), _u(r, 0.93, 0.84), 0.6, 2.2)
	_pu(ci, r, [Vector2(0.91, 0.85), Vector2(0.95, 0.9), Vector2(0.95, 0.85)], 0.55)
	L(ci, _u(r, 0.95, 0.88), _u(r, 0.99, 0.97), 0.6)
	# earth lead and clamp lying on the deck
	_pu(ci, r, [Vector2(0.42, 0.54), Vector2(0.42, 0.74), Vector2(0.58, 0.8), Vector2(0.66, 0.9)], 0.45, 1.3)
	_pu(ci, r, [Vector2(0.66, 0.9), Vector2(0.8, 0.9), Vector2(0.86, 0.93)], 0.55, 1.4)
	_pu(ci, r, [Vector2(0.66, 0.96), Vector2(0.8, 0.96), Vector2(0.86, 0.93)], 0.55, 1.4)
	O(ci, _u(r, 0.71, 0.93), maxf(1.2, ms * 0.03), 0.45)
	# trolley: chassis, axle, wheels, the push handle
	R(ci, sub(r, 0.06, 0.62, 0.72, 0.665), 0.5)
	var wr: float = minf(r.size.x * 0.13, r.size.y * 0.11)
	var ay: float = _u(r, 0, 0.665).y + wr * 0.8
	for x in [0.18, 0.56]:
		var wc := Vector2(_u(r, x, 0.0).x, ay)
		O(ci, wc, wr, 0.58, 1.3)
		O(ci, wc, wr * 0.45, 0.35)
		D(ci, wc, 1.0, 0.55)
	L(ci, Vector2(_u(r, 0.18, 0).x, ay), Vector2(_u(r, 0.56, 0).x, ay), 0.4, 1.3)
	_pu(ci, r, [Vector2(0.08, 0.32), Vector2(0.025, 0.32), Vector2(0.025, 0.06), Vector2(0.1, 0.06)], 0.5, 1.4)


# ---------------------------------------------------------------- E-07: the exam aux unit
# a compact motor-pump set on its skid, the same in all four E-07 bays: terminal box with
# the cable gland where the power cable lands (top left), motor, coupling guard, pump
# volute, discharge up through its isolation valve to the pipe stub (top right), the
# accumulator on its tee, the pressure gauge, four hold-down bolts you can count
static func e07_unit(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.88, 0.98, 0.95), 0.58, 1.2)
	for x in [0.08, 0.36, 0.64, 0.92]:
		R(ci, sub(r, x - 0.03, 0.83, x + 0.03, 0.88), 0.45)
		D(ci, _u(r, x, 0.915), 1.1, 0.65)
	# terminal box and gland
	var tb := sub(r, 0.03, 0.08, 0.2, 0.3)
	R(ci, tb, 0.55)
	R(ci, sub(r, 0.0, 0.12, 0.03, 0.18), 0.5)
	for k in 3:
		D(ci, _u(r, 0.07 + k * 0.045, 0.19), 0.9, 0.5)
	E.corner_bolts(ci, tb, 1.8, 0.4)
	L(ci, _u(r, 0.11, 0.3), _u(r, 0.11, 0.44), 0.45, 1.3)
	# motor, coupling guard, pump
	E.motor(ci, sub(r, 0.04, 0.46, 0.36, 0.83), false, 0.52)
	var cg := sub(r, 0.37, 0.55, 0.44, 0.75)
	R(ci, cg, 0.45)
	hatch(ci, cg.grow(-1.0), 2.4, true, 0.25, 8)
	var vr: float = minf(r.size.y * 0.16, r.size.x * 0.09)
	var tip: Vector2 = E.volute(ci, Vector2(_u(r, 0.53, 0).x, r.end.y - r.size.y * 0.17 - vr), vr, true, 0.58)
	var py: float = _u(r, 0, 0.15).y
	P(ci, PackedVector2Array([tip, Vector2(tip.x, py), _u(r, 0.97, 0.15)]), 0.55, 1.4)
	E.flange(ci, _u(r, 0.97, 0.15), Vector2.RIGHT, maxf(2.0, ms * 0.05), 0.55)
	# isolation valve and its handwheel
	var vc := Vector2(_u(r, 0.76, 0).x, py)
	var vs: float = maxf(2.0, ms * 0.06)
	P(ci, PackedVector2Array([vc + Vector2(-vs, -vs), vc + Vector2(vs, vs), vc + Vector2(vs, -vs), vc + Vector2(-vs, vs), vc + Vector2(-vs, -vs)]), 0.55)
	L(ci, vc, vc - Vector2(0, vs * 1.8), 0.45)
	L(ci, vc - Vector2(vs * 1.2, vs * 1.8), vc + Vector2(vs * 1.2, -vs * 1.8), 0.55, 1.3)
	# pressure gauge on its stem
	var gc := Vector2(_u(r, 0.66, 0).x, py + ms * 0.16)
	L(ci, Vector2(gc.x, py), gc - Vector2(0, ms * 0.08), 0.45)
	E.gauge(ci, gc, maxf(2.5, ms * 0.08), 0.55)
	# accumulator on its tee
	E.vessel_v(ci, sub(r, 0.78, 0.42, 0.92, 0.83), 0.52)
	L(ci, _u(r, 0.85, 0.42), Vector2(_u(r, 0.85, 0).x, py), 0.45, 1.2)


# ---------------------------------------------------------------- EV-55: shunt regulator
# a linear shunt regulator on its heat-sink plate: + and - busbars with bolted cable lugs,
# three shunt legs (load resistor, pass transistor) between them, the measuring shunt on
# the - bar wired to its ammeter, the control card lamp, the fins down the right
static func shunt_reg(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var pl := sub(r, 0.04, 0.06, 0.96, 0.94)
	R(ci, pl, 0.6, 1.2)
	hatch(ci, sub(r, 0.8, 0.1, 0.94, 0.9), 2.2, false, 0.3, 24)
	L(ci, _u(r, 0.78, 0.08), _u(r, 0.78, 0.92), 0.4)
	for y in [0.16, 0.84]:
		L(ci, _u(r, 0.08, y), _u(r, 0.74, y), 0.62, 2.4)
		R(ci, sub(r, 0.0, y - 0.04, 0.08, y + 0.04), 0.5)
		D(ci, _u(r, 0.12, y), 1.2, 0.6)
	# + / - marks
	L(ci, _u(r, 0.18, 0.1), _u(r, 0.24, 0.1), 0.4)
	L(ci, _u(r, 0.21, 0.07), _u(r, 0.21, 0.13), 0.4)
	L(ci, _u(r, 0.18, 0.9), _u(r, 0.24, 0.9), 0.4)
	for x in [0.34, 0.49, 0.64]:
		L(ci, _u(r, x, 0.16), _u(r, x, 0.25), 0.5)
		var zz := PackedVector2Array()
		for k in 7:
			zz.append(_u(r, x + (0.035 if k % 2 == 1 else -0.035) * (0.0 if k == 0 or k == 6 else 1.0), 0.25 + k * 0.045))
		P(ci, zz, 0.5)
		var tr := sub(r, x - 0.045, 0.57, x + 0.045, 0.67)
		R(ci, tr, 0.55)
		D(ci, tr.get_center(), 0.9, 0.6)
		L(ci, _u(r, x, 0.67), _u(r, x, 0.84), 0.5)
	# ammeter and its measuring shunt
	var gc := _u(r, 0.17, 0.5)
	E.gauge(ci, gc, maxf(2.5, ms * 0.09), 0.55)
	R(ci, sub(r, 0.15, 0.81, 0.24, 0.87), 0.6)
	_pu(ci, r, [Vector2(0.16, 0.81), Vector2(0.16, 0.6)], 0.3)
	_pu(ci, r, [Vector2(0.23, 0.81), Vector2(0.23, 0.6)], 0.3)
	_lamp(ci, _u(r, 0.72, 0.5), maxf(1.4, ms * 0.045), Pal.tint(Pal.VOLT, 0.85))


# ---------------------------------------------------------------- FX-70: gas injection valve box
# the fuelling gas-puff box: the bottle's pigtail into its CGA inlet, the two-stage
# regulator (bonnet, knob, inlet and outlet gauges), the manifold block with its three
# fast valves (coil, lamp), the vent valve, the capillary out the roof to the vessel
static func gas_puff(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.06, 0.12, 0.96, 0.94)
	R(ci, bx, 0.6, 1.2)
	E.corner_bolts(ci, bx, 2.0, 0.4)
	# pigtail and CGA nut
	var pg := PackedVector2Array()
	for k in 7:
		pg.append(_u(r, k * 0.015, 0.7 + (0.04 if k % 2 == 0 else -0.04)))
	P(ci, pg, 0.45)
	var nc := _u(r, 0.1, 0.7)
	var nr: float = maxf(1.6, ms * 0.04)
	var hx := PackedVector2Array()
	for k in 7:
		hx.append(nc + Vector2.from_angle(TAU * k / 6.0) * nr)
	P(ci, hx, 0.55)
	E.Rc(ci, Rect2(nc - Vector2(nr, nr) * 0.45, Vector2(nr, nr) * 0.9), Pal.tint(Pal.AIR, 0.6), 1.0)
	# regulator
	R(ci, sub(r, 0.14, 0.58, 0.3, 0.8), 0.55)
	A(ci, _u(r, 0.22, 0.58), r.size.x * 0.08, PI, TAU, 0.55)
	L(ci, _u(r, 0.22, 0.58 - 0.08 * r.size.x / r.size.y), _u(r, 0.22, 0.42), 0.5)
	R(ci, sub(r, 0.18, 0.36, 0.26, 0.42), 0.55)
	L(ci, nc, _u(r, 0.14, 0.7), 0.5, 1.3)
	E.gauge(ci, _u(r, 0.13, 0.24), maxf(2.5, ms * 0.065), 0.5)
	E.gauge(ci, _u(r, 0.31, 0.24), maxf(2.5, ms * 0.065), 0.5)
	_pu(ci, r, [Vector2(0.13, 0.3), Vector2(0.13, 0.62), Vector2(0.14, 0.62)], 0.35)
	_pu(ci, r, [Vector2(0.31, 0.3), Vector2(0.31, 0.62), Vector2(0.3, 0.62)], 0.35)
	# manifold and its fast valves
	L(ci, _u(r, 0.3, 0.72), _u(r, 0.38, 0.72), 0.5, 1.3)
	R(ci, sub(r, 0.38, 0.68, 0.88, 0.78), 0.58)
	for i in 3:
		var x: float = 0.42 + i * 0.15
		var vb := sub(r, x, 0.44, x + 0.1, 0.68)
		R(ci, vb, 0.5)
		hatch(ci, vb.grow(-1.4), 2.0, false, 0.28, 10)
		D(ci, _u(r, x + 0.05, 0.4), 0.9, 0.5)
		_lamp(ci, _u(r, x + 0.05, 0.34), maxf(1.2, ms * 0.035), Pal.tint(Pal.VOLT, 0.8))
	# capillary out through the roof gland, and the vent valve
	_pu(ci, r, [Vector2(0.88, 0.73), Vector2(0.92, 0.73), Vector2(0.92, 0.0)], 0.55, 1.2)
	R(ci, sub(r, 0.9, 0.1, 0.94, 0.14), 0.55)
	L(ci, _u(r, 0.6, 0.78), _u(r, 0.6, 0.94), 0.45)
	var vc := _u(r, 0.6, 0.86)
	var vs: float = maxf(1.6, ms * 0.04)
	P(ci, PackedVector2Array([vc + Vector2(-vs, -vs), vc + Vector2(vs, vs), vc + Vector2(-vs, vs), vc + Vector2(vs, -vs), vc + Vector2(-vs, -vs)]), 0.5)


# ---------------------------------------------------------------- HG-170: ioniser grid
# an electrostatic ioniser in the gas stream: two mesh grid electrodes in their frame with
# the discharge wire between them (its faint glow), the HV bus on two ribbed insulators,
# the HV supply with its warning mark, the collecting hopper under it, the earth strap
static func ion_grid(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var fr := sub(r, 0.18, 0.22, 0.96, 0.84)
	R(ci, fr, 0.62, 1.3)
	E.corner_bolts(ci, fr, 2.5, 0.45)
	E.Rc(ci, sub(r, 0.555, 0.27, 0.605, 0.8), Pal.tint(Pal.VOLT, 0.28), 1.0)
	for g in [Vector2(0.22, 0.55), Vector2(0.61, 0.92)]:
		var gr := sub(r, g.x, 0.27, g.y, 0.8)
		R(ci, gr, 0.55)
		hatch(ci, gr.grow(-1.0), 3.2, true, 0.2, 60)
		hatch(ci, gr.grow(-1.0), 3.2, false, 0.2, 40)
	L(ci, _u(r, 0.58, 0.25), _u(r, 0.58, 0.82), 0.5)
	for y in [0.25, 0.82]:
		D(ci, _u(r, 0.58, y), 1.0, 0.55)
	# HV bus on its insulators, feed-through bushings into the frame
	L(ci, _u(r, 0.24, 0.1), _u(r, 0.92, 0.1), 0.6, 1.8)
	for x in [0.36, 0.8]:
		_insulator(ci, _u(r, x, 0.22), _u(r, x, 0.105), maxf(2.0, r.size.x * 0.018), 0.55)
	for x in [0.3, 0.58, 0.72]:
		L(ci, _u(r, x, 0.1), _u(r, x, 0.22), 0.45)
		O(ci, _u(r, x, 0.22), maxf(1.4, ms * 0.025), 0.5)
	# HV supply: louvres, warning bolt, lamp; its cable to the end of the bus
	var ps := sub(r, 0.02, 0.32, 0.15, 0.8)
	R(ci, ps, 0.58)
	E.louvres(ci, sub(r, 0.04, 0.56, 0.13, 0.76), 0.3)
	_pu(ci, r, [Vector2(0.075, 0.37), Vector2(0.095, 0.43), Vector2(0.07, 0.43), Vector2(0.09, 0.5)], 0.6)
	_lamp(ci, _u(r, 0.125, 0.37), maxf(1.4, ms * 0.035), Pal.tint(Pal.VOLT, 0.9))
	_pu(ci, r, [Vector2(0.085, 0.32), Vector2(0.085, 0.1), Vector2(0.24, 0.1)], 0.5, 1.5)
	# hopper and drain, earth strap
	_pu(ci, r, [Vector2(0.2, 0.84), Vector2(0.5, 0.95), Vector2(0.66, 0.95), Vector2(0.94, 0.84)], 0.5)
	L(ci, _u(r, 0.58, 0.95), _u(r, 0.58, 1.0), 0.45, 1.3)
	_pu(ci, r, [Vector2(0.96, 0.78), Vector2(0.985, 0.82), Vector2(0.965, 0.86), Vector2(0.985, 0.9)], 0.4)
	for k in 3:
		L(ci, _u(r, 0.975 - 0.02 * (2 - k) * 0.5, 0.93 + k * 0.025), _u(r, 0.975 + 0.02 * (2 - k) * 0.5 + 0.005, 0.93 + k * 0.025), 0.45)


# ---------------------------------------------------------------- QC-30: rubidium clock
# a rubidium frequency standard: the physics package in its magnetic shield (lamp, filter
# cell, resonance cell under the C-field winding, photodiode, the faint pumping light),
# the oven wall, the synthesiser board with its crystal can, the 10 MHz and 1 PPS outputs
# and the lock lamp on the face, the heat-sink fins on the lid
static func rb_clock(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var ch := sub(r, 0.04, 0.12, 0.96, 0.94)
	R(ci, ch, 0.62, 1.2)
	hatch(ci, sub(r, 0.1, 0.03, 0.9, 0.12), 2.2, true, 0.32, 30)
	# physics package
	R(ci, sub(r, 0.09, 0.19, 0.67, 0.53), 0.55)
	R(ci, sub(r, 0.12, 0.22, 0.64, 0.5), 0.3)
	O(ci, _u(r, 0.19, 0.36), maxf(1.4, ms * 0.045), 0.55)
	R(ci, sub(r, 0.27, 0.29, 0.34, 0.43), 0.45)
	var cell := sub(r, 0.38, 0.26, 0.55, 0.46)
	R(ci, cell, 0.5)
	hatch(ci, cell.grow(-0.5), 2.0, true, 0.25, 14)
	D(ci, _u(r, 0.59, 0.36), 1.1, 0.6)
	E.Rc(ci, Rect2(_u(r, 0.22, 0.355), Vector2(r.size.x * 0.35, 0.8)), Pal.tint(Pal.VOLT, 0.5), 1.0)
	# synthesiser board
	R(ci, sub(r, 0.09, 0.6, 0.67, 0.86), 0.42)
	O(ci, _u(r, 0.19, 0.73), maxf(1.4, ms * 0.045), 0.5)
	R(ci, sub(r, 0.3, 0.66, 0.42, 0.78), 0.42)
	R(ci, sub(r, 0.47, 0.68, 0.6, 0.76), 0.42)
	L(ci, _u(r, 0.42, 0.72), _u(r, 0.47, 0.72), 0.3)
	L(ci, _u(r, 0.3, 0.53), _u(r, 0.3, 0.6), 0.3)
	# front: outputs, lock lamp, power connector
	for y in [0.3, 0.5]:
		var c := _u(r, 0.82, y)
		O(ci, c, maxf(1.6, ms * 0.06), 0.55)
		D(ci, c, 0.8, 0.6)
		L(ci, c + Vector2(maxf(1.6, ms * 0.06), 0), Vector2(r.end.x, c.y), 0.45, 1.2)
	_lamp(ci, _u(r, 0.82, 0.68), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.85))
	R(ci, sub(r, 0.75, 0.78, 0.89, 0.87), 0.5)
	L(ci, _u(r, 0.71, 0.14), _u(r, 0.71, 0.92), 0.3)


# ---------------------------------------------------------------- ST-40: data acquisition unit
# a DIN-rail DAQ: head module (display, two network ports, lamps), I/O modules each with
# its rows of terminal screws and channel lamps, the sensor leads off the top dressed into
# a tied harness, the power feed out of the bottom, the rail with its end stops
static func daq_rail(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.04, 0.98, 0.96), 0.42)
	L(ci, _u(r, 0.04, 0.53), _u(r, 0.96, 0.53), 0.5, 1.2)
	L(ci, _u(r, 0.04, 0.58), _u(r, 0.96, 0.58), 0.5, 1.2)
	for x in [0.04, 0.92]:
		R(ci, sub(r, x, 0.5, x + 0.04, 0.61), 0.5)
	var hd := sub(r, 0.08, 0.24, 0.28, 0.88)
	R(ci, hd, 0.6, 1.2)
	E.Rc(ci, sub(r, 0.11, 0.3, 0.25, 0.42), Pal.tint(Pal.AIR, 0.65), 1.0)
	R(ci, sub(r, 0.11, 0.66, 0.175, 0.75), 0.5)
	R(ci, sub(r, 0.185, 0.66, 0.25, 0.75), 0.5)
	_lamp(ci, _u(r, 0.13, 0.5), maxf(1.2, ms * 0.035), Pal.tint(Pal.FLUID, 0.85))
	D(ci, _u(r, 0.2, 0.5), 0.9, 0.45)
	var n := clampi(int(r.size.x * 0.66 / 5.0), 4, 8)
	var mw: float = 0.66 / n
	for i in n:
		var mx: float = 0.29 + i * mw
		var md := sub(r, mx, 0.24, mx + mw - 0.008, 0.88)
		R(ci, md, 0.52)
		var cx: float = mx + (mw - 0.008) * 0.5
		for k in 3:
			D(ci, _u(r, cx, 0.28 + k * 0.05), 0.8, 0.55)
			D(ci, _u(r, cx, 0.74 + k * 0.05), 0.8, 0.55)
		if (i * 3 + 1) % 4 != 0:
			_lamp(ci, _u(r, cx, 0.45), maxf(1.0, ms * 0.03), Pal.tint(Pal.FLUID, 0.8))
		else:
			D(ci, _u(r, cx, 0.45), 0.8, 0.35)
		_pu(ci, r, [Vector2(cx, 0.24), Vector2(cx, 0.17), Vector2(0.6 + (cx - 0.6) * 0.25, 0.1)], 0.35)
	L(ci, _u(r, 0.6, 0.11), _u(r, 0.6, 0.0), 0.55, 2.0)
	for y in [0.04, 0.09]:
		L(ci, _u(r, 0.56, y), _u(r, 0.64, y), 0.5)
	_pu(ci, r, [Vector2(0.18, 0.88), Vector2(0.18, 0.93), Vector2(0.4, 0.93), Vector2(0.4, 1.0)], 0.45, 1.3)


# ================================================================== batteries (E018–E028)
# 2026-11-11, second batch from the 零件图鉴: eleven kinds that all drew as the shared battery
# cabinet. Each its own form: liquid-cooled trays, a cart, a luminaire, a pack on the ring's
# curved deck, a flight pack, lead-acid racks, the ship's main battery bank (sized to the
# ship), a drone pack in its cradle, a pouch stack, a door-lock UPS, a pod's bedside unit.

# a cell end seen end-on: a hexagon (a sixth of a circle's strokes, for the packs of many)
static func _hex(ci: CanvasItem, c: Vector2, rad: float, al: float = 0.5) -> void:
	var q := PackedVector2Array()
	for k in 7:
		q.append(c + Vector2.from_angle(TAU * k / 6.0 + PI / 6.0) * rad)
	P(ci, q, al)


# ---------------------------------------------------------------- ARK-01: aux grid battery
# a liquid-cooled lithium cabinet: BMS strip up top, five trays of cylindrical cells each on
# its coolant quick-connects, the supply/return manifold down the side and out the roof,
# the DC isolator, the main DC cables out of the top, the plinth
static func ark_aux_pack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cab := sub(r, 0.04, 0.08, 0.8, 0.94)
	R(ci, cab, 0.62, 1.2)
	R(ci, sub(r, 0.08, 0.1, 0.76, 0.17), 0.45)
	E.Rc(ci, sub(r, 0.11, 0.115, 0.3, 0.155), Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 4:
		D(ci, _u(r, 0.38 + k * 0.06, 0.135), 1.0, 0.55)
	E.Rc(ci, sub(r, 0.845, 0.1, 0.935, 0.92), Pal.tint(Pal.FLUID, 0.22), 1.0)
	for x in [0.86, 0.92]:
		L(ci, _u(r, x, 0.92), _u(r, x, 0.0), 0.55, 1.4)
		E.flange(ci, _u(r, x, 0.05), Vector2.UP, maxf(1.5, ms * 0.02), 0.5)
	for i in 5:
		var y0: float = 0.2 + i * 0.128
		var tr := sub(r, 0.08, y0, 0.76, y0 + 0.11)
		R(ci, tr, 0.5)
		var cr: float = minf(tr.size.y * 0.22, 3.2)
		var n := clampi(int(tr.size.x / (cr * 2.6)), 4, 24)
		for k in n:
			_hex(ci, Vector2(tr.position.x + (k + 0.5) * tr.size.x / n, tr.get_center().y), cr, 0.32)
		L(ci, Vector2(tr.position.x + 2.0, tr.position.y + 1.5), Vector2(tr.end.x - 2.0, tr.position.y + 1.5), 0.3)
		for k in 2:
			var qy: float = y0 + 0.03 + k * 0.05
			D(ci, _u(r, 0.78, qy), 1.0, 0.55)
			L(ci, _u(r, 0.78, qy), _u(r, 0.86 + k * 0.06, qy), 0.4)
	var iso := sub(r, 0.08, 0.85, 0.3, 0.92)
	R(ci, iso, 0.5)
	var ic := iso.get_center()
	O(ci, ic, minf(iso.size.y * 0.4, 4.0), 0.55)
	L(ci, ic, ic + Vector2(minf(iso.size.y * 0.4, 4.0) * 1.6, 0), 0.6, 1.4)
	for x in [0.2, 0.28]:
		L(ci, _u(r, x, 0.08), _u(r, x, 0.0), 0.55, 1.8)
	R(ci, sub(r, 0.02, 0.94, 0.98, 0.99), 0.55)


# ---------------------------------------------------------------- ARK-01: shuttle battery cart
# a battery box on a low two-wheeled cart: posts, lifting cut-outs, the charge gauge, the
# tow handle with the charging lead coiled over it and its plug, the hitch ring
static func battery_cart(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.1, 0.3, 0.8, 0.68)
	R(ci, bx, 0.62, 1.2)
	L(ci, _u(r, 0.1, 0.36), _u(r, 0.8, 0.36), 0.4)
	for x in [0.16, 0.62]:
		R(ci, sub(r, x, 0.42, x + 0.12, 0.47), 0.4)
	for x in [0.3, 0.6]:
		L(ci, _u(r, x, 0.3), _u(r, x, 0.24), 0.6, 1.6)
		D(ci, _u(r, x, 0.235), 1.1, 0.6)
	L(ci, _u(r, 0.33, 0.27), _u(r, 0.57, 0.27), 0.25)
	var g := sub(r, 0.4, 0.53, 0.72, 0.6)
	R(ci, g, 0.45)
	E.Rc(ci, Rect2(g.position + Vector2(1.0, 1.0), Vector2(g.size.x * 0.62, g.size.y - 2.0)), Pal.tint(Pal.FLUID, 0.75), 1.0)
	R(ci, sub(r, 0.06, 0.68, 0.86, 0.75), 0.58)
	var wr: float = ms * 0.1
	for x in [0.24, 0.66]:
		var wc := Vector2(_u(r, x, 0).x, _u(r, 0, 0.75).y + wr * 0.95)
		O(ci, wc, wr, 0.6, 1.3)
		D(ci, wc, 1.0, 0.55)
	_pu(ci, r, [Vector2(0.86, 0.72), Vector2(0.92, 0.72), Vector2(0.96, 0.32)], 0.55, 1.4)
	R(ci, sub(r, 0.93, 0.24, 0.99, 0.32), 0.55)
	_ell(ci, _u(r, 0.9, 0.5), r.size.x * 0.06, r.size.y * 0.1, 0.4)
	_ell(ci, _u(r, 0.91, 0.52), r.size.x * 0.06, r.size.y * 0.1, 0.4)
	R(ci, sub(r, 0.86, 0.6, 0.92, 0.66), 0.55)
	O(ci, _u(r, 0.035, 0.715), maxf(1.4, ms * 0.03), 0.5)


# ---------------------------------------------------------------- ARK-01: emergency light
# a twin-spot emergency luminaire on its wall bracket: the two lamp heads (amber lenses) on
# their pivots, the housing with its battery pack behind a window, test button, charge lamp
static func emerg_light(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var hs := sub(r, 0.06, 0.34, 0.94, 0.9)
	R(ci, hs, 0.62, 1.2)
	for x in [0.28, 0.72]:
		_pu(ci, r, [Vector2(x - 0.13, 0.3), Vector2(x - 0.11, 0.1), Vector2(x + 0.11, 0.06), Vector2(x + 0.13, 0.26)], 0.6, 1.0, true)
		E.Rc(ci, sub(r, x - 0.09, 0.1, x + 0.09, 0.2), Pal.heat(0.7), 1.0)
		D(ci, _u(r, x, 0.32), 1.0, 0.6)
	var bw := sub(r, 0.14, 0.46, 0.58, 0.82)
	R(ci, bw, 0.42)
	for x in [0.25, 0.36, 0.47]:
		L(ci, _u(r, x, 0.48), _u(r, x, 0.8), 0.35)
	D(ci, _u(r, 0.76, 0.52), maxf(1.0, ms * 0.04), 0.6)
	_lamp(ci, _u(r, 0.76, 0.72), maxf(1.2, ms * 0.06), Pal.tint(Pal.FLUID, 0.85))
	L(ci, _u(r, 0.0, 0.62), _u(r, 0.06, 0.62), 0.5, 1.3)
	L(ci, _u(r, 0.94, 0.62), _u(r, 1.0, 0.62), 0.5, 1.3)
	L(ci, _u(r, 0.5, 0.9), _u(r, 0.5, 1.0), 0.45, 1.2)


# ---------------------------------------------------------------- ARK-01: ring battery
# the battery in the spinning ring: modules stood radially on the ring's curved deck (spin
# gravity points out, down here), strapped down against the spin-up with a ratchet buckle,
# flexible links between them, the junction box its cable leaves from, the spin arrow
static func ring_battery(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cc := _u(r, 0.5, -2.2)
	var rad: float = cc.distance_to(_u(r, 0.5, 0.95))
	var deck := PackedVector2Array()
	var deck2 := PackedVector2Array()
	var a_half: float = asin(clampf(r.size.x * 0.49 / rad, -1.0, 1.0))
	for k in 17:
		var a: float = PI * 0.5 + lerpf(a_half, -a_half, k / 16.0)
		deck.append(cc + Vector2.from_angle(a) * rad)
		deck2.append(cc + Vector2.from_angle(a) * (rad + r.size.y * 0.035))
	P(ci, deck, 0.62, 1.3)
	P(ci, deck2, 0.45)
	var tops := PackedVector2Array()
	var n := 5
	for i in n:
		var a: float = PI * 0.5 + a_half * 0.8 * (1.0 - 2.0 * (i + 0.5) / n)
		var b := cc + Vector2.from_angle(a) * rad
		var up: Vector2 = (cc - b).normalized()
		var sd := up.orthogonal()
		var hw: float = r.size.x * 0.072
		var hh: float = r.size.y * 0.4
		var q := PackedVector2Array([b - sd * hw, b - sd * hw + up * hh, b + sd * hw + up * hh, b + sd * hw, b - sd * hw])
		P(ci, q, 0.58, 1.1)
		for f in [0.3, 0.55, 0.8]:
			L(ci, b - sd * hw * 0.8 + up * hh * f, b + sd * hw * 0.8 + up * hh * f, 0.28)
		D(ci, b + up * hh * 0.9 - sd * hw * 0.45, 1.0, 0.55)
		D(ci, b + up * hh * 0.9 + sd * hw * 0.45, 1.0, 0.55)
		tops.append(b + up * (hh + 2.5))
		if i > 0:
			var pt: Vector2 = tops[i - 1]
			var mid := (pt + tops[i]) * 0.5 + (cc - (pt + tops[i]) * 0.5).normalized() * 3.0
			P(ci, PackedVector2Array([pt, mid, tops[i]]), 0.4)
	var strap := PackedVector2Array([deck[0]])
	strap.append_array(tops)
	strap.append(deck[deck.size() - 1])
	P(ci, strap, 0.45, 1.2)
	var bk: Vector2 = tops[n - 1].lerp(deck[deck.size() - 1], 0.5)
	E.Rc(ci, Rect2(bk - Vector2(2.5, 2.5), Vector2(5, 5)), Pal.ink(0.55), 1.0)
	var jb := sub(r, 0.42, 0.34, 0.58, 0.46)
	R(ci, jb, 0.55)
	D(ci, jb.get_center(), 1.0, 0.55)
	_pu(ci, r, [Vector2(0.42, 0.4), Vector2(0.0, 0.4)], 0.55, 1.6)
	L(ci, _u(r, 0.5, 0.46), tops[2], 0.4)
	var sp := PackedVector2Array()
	for k in 9:
		var t: float = k / 8.0
		sp.append(_u(r, 0.2 + 0.6 * t, 0.14 - 0.06 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
	P(ci, sp, 0.3)
	var tip: Vector2 = sp[8]
	L(ci, tip, tip + Vector2(-ms * 0.05, -ms * 0.03), 0.3)
	L(ci, tip, tip + Vector2(-ms * 0.05, ms * 0.03), 0.3)


# ---------------------------------------------------------------- ARK-01: shuttle battery
# a flight battery: ribbed sealed case, carry handle, pressure relief valve, the circular
# connector with its backshell and harness, data plate, tie-down lugs on the mounting rail
static func shuttle_pack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.08, 0.2, 0.92, 0.86)
	R(ci, bx, 0.62, 1.2)
	var segs := PackedVector2Array()
	for k in 6:
		var x: float = 0.16 + k * 0.136
		segs.append(_u(r, x, 0.23))
		segs.append(_u(r, x, 0.83))
	S(ci, segs, 0.25)
	L(ci, _u(r, 0.08, 0.54), _u(r, 0.92, 0.54), 0.42, 1.2)
	_pu(ci, r, [Vector2(0.3, 0.2), Vector2(0.3, 0.1), Vector2(0.56, 0.1), Vector2(0.56, 0.2)], 0.55, 1.5)
	var pv := _u(r, 0.2, 0.32)
	O(ci, pv, maxf(1.6, ms * 0.04), 0.55)
	L(ci, pv - Vector2(ms * 0.025, 0), pv + Vector2(ms * 0.025, 0), 0.5)
	var cc := _u(r, 0.74, 0.36)
	var cr: float = ms * 0.09
	O(ci, cc, cr, 0.62, 1.2)
	O(ci, cc, cr * 0.6, 0.4)
	for k in 3:
		D(ci, cc + Vector2.from_angle(TAU * k / 3.0 + 0.5) * cr * 0.35, 0.8, 0.6)
	R(ci, Rect2(cc + Vector2(-cr * 0.55, -cr * 2.0), Vector2(cr * 1.1, cr * 1.0)), 0.5)
	P(ci, PackedVector2Array([cc - Vector2(0, cr * 2.0), Vector2(cc.x, _u(r, 0, 0.06).y), _u(r, 0.98, 0.06)]), 0.55, 1.5)
	var dp := sub(r, 0.2, 0.62, 0.6, 0.78)
	R(ci, dp, 0.35)
	hatch(ci, dp.grow(-1.5), 3.0, false, 0.22, 6)
	L(ci, _u(r, 0.02, 0.92), _u(r, 0.98, 0.92), 0.55, 1.4)
	for x in [0.02, 0.86]:
		R(ci, sub(r, x, 0.8, x + 0.12, 0.92), 0.5)
		D(ci, _u(r, x + 0.06, 0.86), 1.0, 0.55)


# ---------------------------------------------------------------- PS-12: aux battery (lead-acid)
# a three-tier rack of sealed lead-acid blocks: each block's lid, posts and vent caps, the
# links in series along a tier and the jumpers between tiers, the restraint rail across each
# tier, the battery monitor on the post with its sense leads, the main cables out of the top
static func vrla_rack(ci: CanvasItem, r: Rect2) -> void:
	for x in [0.03, 0.8]:
		L(ci, _u(r, x, 0.04), _u(r, x, 0.98), 0.6, 1.5)
	var tiers := [0.34, 0.64, 0.94]
	var n := clampi(int(r.size.x * 0.74 / 20.0), 3, 8)
	var bw: float = 0.74 / n
	var ends := []
	for ti in 3:
		var sy: float = tiers[ti]
		L(ci, _u(r, 0.02, sy), _u(r, 0.81, sy), 0.6, 1.6)
		var by: float = sy - 0.24
		for i in n:
			var x0: float = 0.05 + i * bw
			var blk := sub(r, x0 + 0.006, by, x0 + bw - 0.006, sy)
			R(ci, blk, 0.52)
			L(ci, _u(r, x0 + 0.006, by + 0.04), _u(r, x0 + bw - 0.006, by + 0.04), 0.35)
			for f in [0.25, 0.75]:
				var tp := _u(r, x0 + bw * f, by)
				R(ci, Rect2(tp - Vector2(1.5, 2.5), Vector2(3, 2.5)), 0.55)
			D(ci, _u(r, x0 + bw * 0.43, by + 0.02), 0.8, 0.4)
			D(ci, _u(r, x0 + bw * 0.57, by + 0.02), 0.8, 0.4)
			if i + 1 < n:
				L(ci, _u(r, x0 + bw * 0.75, by - 0.012), _u(r, x0 + bw * 1.25, by - 0.012), 0.55, 1.5)
		L(ci, _u(r, 0.04, by + 0.16), _u(r, 0.79, by + 0.16), 0.25)
		ends.append([_u(r, 0.05 + bw * 0.25, by - 0.012), _u(r, 0.05 + (n - 1) * bw + bw * 0.75, by - 0.012)])
	# serpentine jumpers between tiers
	P(ci, PackedVector2Array([ends[0][1], ends[0][1] + Vector2(r.size.x * 0.02, 0), Vector2(ends[0][1].x + r.size.x * 0.02, ends[1][1].y), ends[1][1]]), 0.45, 1.3)
	P(ci, PackedVector2Array([ends[1][0], ends[1][0] - Vector2(r.size.x * 0.03, 0), Vector2(ends[1][0].x - r.size.x * 0.03, ends[2][0].y), ends[2][0]]), 0.45, 1.3)
	L(ci, ends[0][0], Vector2(ends[0][0].x, r.position.y), 0.55, 1.8)
	L(ci, ends[2][1], Vector2(_u(r, 0.86, 0).x, ends[2][1].y), 0.5, 1.6)
	L(ci, Vector2(_u(r, 0.86, 0).x, ends[2][1].y), _u(r, 0.86, 0.0), 0.5, 1.6)
	var mon := sub(r, 0.84, 0.08, 0.98, 0.26)
	R(ci, mon, 0.58)
	E.Rc(ci, sub(r, 0.86, 0.11, 0.96, 0.16), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp(ci, _u(r, 0.88, 0.21), 2.0, Pal.tint(Pal.FLUID, 0.8))
	var sl := PackedVector2Array()
	for ti in 3:
		sl.append(_u(r, 0.84, 0.2))
		sl.append(_u(r, 0.8, tiers[ti] - 0.2))
	S(ci, sl, 0.22)


# ---------------------------------------------------------------- the ship's main battery
# fleet-wide (64 pieces, 0.7 x 0.6 m to 13 x 2.55 m), always the bank that backs the
# switchboard: two monoblocks when small; otherwise racks of slide-in lithium modules (handle,
# lamp, series links), a fuse per string, the DC trunk along the top, and the BMS and DC
# switchgear cabinet (display, breaker, isolator, louvres) at the end, on its plinth
static func main_battery(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	if ms < 44.0 or r.size.x < 56.0:
		_battery_blocks(ci, r)
		return
	var h := r.size.y
	R(ci, Rect2(r.position + Vector2(0, h * 0.95), Vector2(r.size.x, h * 0.05)), 0.55)
	var cw: float = clampf(r.size.x * 0.2, 20.0, 0.9 * M)
	var cab := Rect2(r.end.x - cw, r.position.y + h * 0.12, cw - 1.0, h * 0.83)
	R(ci, cab, 0.62, 1.2)
	E.Rc(ci, Rect2(cab.position + Vector2(cab.size.x * 0.15, cab.size.y * 0.06), Vector2(cab.size.x * 0.7, minf(cab.size.y * 0.1, 10.0))), Pal.tint(Pal.AIR, 0.6), 1.0)
	E.breaker(ci, Rect2(cab.position + Vector2(cab.size.x * 0.2, cab.size.y * 0.24), Vector2(cab.size.x * 0.6, minf(cab.size.y * 0.2, 18.0))), true, 0.5)
	var ic := cab.position + Vector2(cab.size.x * 0.5, cab.size.y * 0.58)
	var ir: float = minf(cab.size.x * 0.18, 6.0)
	O(ci, ic, ir, 0.55)
	L(ci, ic - Vector2(ir * 1.3, 0), ic + Vector2(ir * 1.3, 0), 0.6, 1.5)
	E.louvres(ci, Rect2(cab.position + Vector2(cab.size.x * 0.15, cab.size.y * 0.74), Vector2(cab.size.x * 0.7, cab.size.y * 0.2)), 0.3)
	# the racks
	var ax0: float = r.position.x + 1.0
	var ax1: float = cab.position.x - 3.0
	var top: float = r.position.y + h * 0.16
	var bot: float = r.position.y + h * 0.95
	var nr := clampi(int((ax1 - ax0) / (0.75 * M)), 1, 14)
	var rw: float = (ax1 - ax0) / nr
	var nm := clampi(int((bot - top) / 11.0), 2, 14)
	var mh: float = (bot - top) / nm
	# modules share their separators; each keeps its handle and its series link, each rack a
	# status lamp and a string fuse (cheap enough for the 13 m banks: a stroke or two a module)
	var segs := PackedVector2Array()
	var links := PackedVector2Array()
	for i in nr:
		var rk := Rect2(ax0 + i * rw + 1.0, top, rw - 2.0, bot - top)
		R(ci, rk, 0.55)
		var lx: float = rk.end.x - 3.0
		if nr * nm <= 40:
			# few modules: each its own case, handle, lamp, cooling slots, terminals, series link
			for k in nm:
				var m := Rect2(rk.position.x + 2.0, top + k * mh + 1.0, rk.size.x - 4.0, mh - 2.0)
				R(ci, m, 0.42)
				var cy0: float = m.get_center().y
				segs.append(Vector2(m.position.x + 2.0, cy0))
				segs.append(Vector2(m.position.x + minf(7.0, m.size.x * 0.15), cy0))
				_lamp(ci, Vector2(m.position.x + m.size.x * 0.24, cy0), 2.0, Pal.tint(Pal.FLUID, 0.75) if k % 4 != 3 else Pal.ink(0.3))
				for f in [0.42, 0.5, 0.58, 0.66]:
					segs.append(Vector2(m.position.x + m.size.x * f, m.position.y + 2.0))
					segs.append(Vector2(m.position.x + m.size.x * f, m.end.y - 2.0))
				D(ci, Vector2(m.end.x - 2.5, m.position.y + 2.0), 0.9, 0.55)
				D(ci, Vector2(m.end.x - 2.5, m.end.y - 2.0), 0.9, 0.55)
				if k + 1 < nm:
					links.append(Vector2(m.end.x - 2.5, m.end.y - 2.0))
					links.append(Vector2(m.end.x - 2.5, m.end.y + 3.0))
			var fz0 := Rect2(rk.get_center().x - 3.0, r.position.y + h * 0.075, 6.0, h * 0.05)
			R(ci, fz0, 0.5)
			L(ci, Vector2(rk.get_center().x, fz0.end.y), Vector2(rk.get_center().x, top), 0.45)
			continue
		for k in nm:
			var y0: float = top + k * mh
			if k > 0:
				segs.append(Vector2(rk.position.x + 1.5, y0))
				segs.append(Vector2(rk.end.x - 1.5, y0))
			var cy: float = y0 + mh * 0.5
			segs.append(Vector2(rk.position.x + 3.0, cy))
			segs.append(Vector2(rk.position.x + minf(7.0, rk.size.x * 0.18), cy))
			if k + 1 < nm:
				links.append(Vector2(lx, cy))
				links.append(Vector2(lx, cy + mh))
		var fz := Rect2(rk.get_center().x - 3.0, r.position.y + h * 0.075, 6.0, h * 0.05)
		R(ci, fz, 0.5)
		L(ci, Vector2(rk.get_center().x, fz.end.y), Vector2(rk.get_center().x, top), 0.45)
		_lamp(ci, Vector2(rk.position.x + rk.size.x * 0.35, top + mh * 0.5), 2.0, Pal.tint(Pal.FLUID, 0.75))
	S(ci, segs, 0.4)
	S(ci, links, 0.45, 1.3)
	L(ci, Vector2(ax0 + rw * 0.5, r.position.y + h * 0.075), Vector2(cab.get_center().x, r.position.y + h * 0.075), 0.55, 2.0)
	L(ci, Vector2(cab.get_center().x, r.position.y + h * 0.075), Vector2(cab.get_center().x, cab.position.y), 0.55, 2.0)


# a small battery: two monoblocks under their hold-down bar, posts, vent caps, the link
static func _battery_blocks(ci: CanvasItem, r: Rect2) -> void:
	for x in [0.04, 0.52]:
		var b := sub(r, x, 0.3, x + 0.44, 0.92)
		R(ci, b, 0.6, 1.2)
		L(ci, _u(r, x, 0.38), _u(r, x + 0.44, 0.38), 0.38)
		for f in [0.1, 0.34]:
			R(ci, sub(r, x + f - 0.035, 0.22, x + f + 0.035, 0.3), 0.6)
		D(ci, _u(r, x + 0.22, 0.34), 0.8, 0.4)
	L(ci, _u(r, 0.38, 0.22), _u(r, 0.6, 0.22), 0.55, 1.5)
	L(ci, _u(r, 0.0, 0.6), _u(r, 1.0, 0.6), 0.4, 1.3)
	L(ci, _u(r, 0.14, 0.22), _u(r, 0.14, 0.0), 0.55, 1.5)
	L(ci, _u(r, 0.86, 0.22), _u(r, 0.86, 0.0), 0.55, 1.5)
	L(ci, _u(r, 0.0, 0.96), _u(r, 1.0, 0.96), 0.5, 1.3)


# ---------------------------------------------------------------- CV-138: drone battery pack
# a swappable drone pack in its charging cradle: chamfered case with the carry strap and its
# buckles, the four-bar charge gauge, the blade quick-connect and its latch lever into the
# dock (contacts, lamp, charging lead out of the side), guide rollers on the rail
static func drone_pack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.02, 0.92), _u(r, 0.86, 0.92), 0.55, 1.5)
	R(ci, sub(r, 0.02, 0.36, 0.06, 0.92), 0.5)
	var dk := sub(r, 0.86, 0.2, 0.98, 0.94)
	R(ci, dk, 0.6, 1.2)
	for y in [0.48, 0.56, 0.64]:
		L(ci, _u(r, 0.86, y), _u(r, 0.9, y), 0.5, 1.4)
	_lamp(ci, _u(r, 0.92, 0.28), maxf(1.6, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	L(ci, _u(r, 0.98, 0.5), _u(r, 1.0, 0.5), 0.55, 1.5)
	var c := 0.03
	_pu(ci, r, [Vector2(0.08 + c, 0.26), Vector2(0.8 - c, 0.26), Vector2(0.8, 0.26 + c * 2.0), Vector2(0.8, 0.86 - c * 2.0), Vector2(0.8 - c, 0.86), Vector2(0.08 + c, 0.86), Vector2(0.08, 0.86 - c * 2.0), Vector2(0.08, 0.26 + c * 2.0)], 0.62, 1.2, true)
	L(ci, _u(r, 0.1, 0.34), _u(r, 0.78, 0.34), 0.3)
	hatch(ci, sub(r, 0.38, 0.4, 0.74, 0.8), 4.0, true, 0.16, 30)
	_pu(ci, r, [Vector2(0.22, 0.26), Vector2(0.26, 0.08), Vector2(0.62, 0.08), Vector2(0.66, 0.26)], 0.5, 2.0)
	for x in [0.2, 0.64]:
		R(ci, sub(r, x, 0.22, x + 0.04, 0.3), 0.55)
	for k in 4:
		var s := sub(r, 0.13 + k * 0.05, 0.68, 0.17 + k * 0.05, 0.78)
		if k < 3:
			E.Rc(ci, s, Pal.tint(Pal.FLUID, 0.75), 1.0)
		else:
			R(ci, s, 0.3)
	R(ci, sub(r, 0.8, 0.42, 0.86, 0.68), 0.58)
	var pv := _u(r, 0.78, 0.38)
	D(ci, pv, 1.0, 0.6)
	L(ci, pv, _u(r, 0.84, 0.3), 0.6, 1.5)
	for x in [0.2, 0.62]:
		O(ci, _u(r, x, 0.89), maxf(1.4, ms * 0.03), 0.5)


# ---------------------------------------------------------------- LC-140: courier battery
# a pouch-cell stack between compression end plates with their tie rods and nuts, the tabs
# welded to the bus strip, the cell-monitor board and its harness, the main fuse and
# connector, all bolted to the honeycomb panel it is mounted on
static func courier_stack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var hp := sub(r, 0.02, 0.86, 0.98, 0.97)
	R(ci, hp, 0.55)
	for row in 2:
		var z := PackedVector2Array()
		var n := clampi(int(hp.size.x / 5.0), 6, 40)
		for k in n + 1:
			z.append(Vector2(hp.position.x + k * hp.size.x / n, hp.position.y + hp.size.y * ((0.3 if (k + row) % 2 == 0 else 0.55) + row * 0.2)))
		P(ci, z, 0.22)
	for x in [0.08, 0.86]:
		R(ci, sub(r, x, 0.18, x + 0.06, 0.86), 0.62, 1.2)
	for y in [0.22, 0.8]:
		L(ci, _u(r, 0.04, y), _u(r, 0.96, y), 0.5)
		D(ci, _u(r, 0.05, y), 1.1, 0.6)
		D(ci, _u(r, 0.95, y), 1.1, 0.6)
	var nc := clampi(int(r.size.x * 0.72 / 4.0), 6, 22)
	var segs := PackedVector2Array()
	var tabs := PackedVector2Array()
	for k in nc:
		var x: float = 0.16 + (k + 0.5) * 0.68 / nc
		segs.append(_u(r, x, 0.3))
		segs.append(_u(r, x, 0.76))
		tabs.append(_u(r, x, 0.27))
		tabs.append(_u(r, x, 0.3))
	S(ci, segs, 0.38)
	S(ci, tabs, 0.5, 1.4)
	L(ci, _u(r, 0.15, 0.27), _u(r, 0.85, 0.27), 0.45)
	var bd := sub(r, 0.3, 0.06, 0.68, 0.15)
	R(ci, bd, 0.48)
	_lamp(ci, bd.position + Vector2(bd.size.x * 0.82, bd.size.y * 0.5), maxf(1.2, ms * 0.035), Pal.tint(Pal.FLUID, 0.8))
	var hs := PackedVector2Array()
	for k in 4:
		hs.append(_u(r, 0.34 + k * 0.08, 0.15))
		hs.append(_u(r, 0.22 + k * 0.17, 0.27))
	S(ci, hs, 0.22)
	R(ci, sub(r, 0.74, 0.04, 0.86, 0.13), 0.55)
	L(ci, _u(r, 0.86, 0.085), _u(r, 1.0, 0.085), 0.55, 1.5)
	L(ci, _u(r, 0.8, 0.13), _u(r, 0.8, 0.27), 0.45, 1.3)


# ---------------------------------------------------------------- ES-112: door-lock UPS
# the door locks' backup supply, tall on the wall: the UPS box up top (display, lamps, key
# switch, hinge, the terminal strip whose lock circuits leave by the gland), the relay strip
# that holds each lock, the conduit down on its saddles, the vented battery box at the foot
static func lock_ups(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.12, 0.05, 0.88, 0.34)
	R(ci, bx, 0.62, 1.2)
	for y in [0.09, 0.3]:
		D(ci, _u(r, 0.12, y), 1.1, 0.55)
	E.Rc(ci, sub(r, 0.2, 0.09, 0.52, 0.15), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp(ci, _u(r, 0.6, 0.12), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_lamp(ci, _u(r, 0.68, 0.12), maxf(1.4, ms * 0.04), Pal.heat(0.85))
	var kc := _u(r, 0.78, 0.2)
	O(ci, kc, maxf(2.0, ms * 0.07), 0.6)
	L(ci, kc - Vector2(0, ms * 0.04), kc + Vector2(0, ms * 0.04), 0.6, 1.3)
	R(ci, sub(r, 0.18, 0.24, 0.66, 0.31), 0.45)
	for k in 6:
		D(ci, _u(r, 0.22 + k * 0.08, 0.275), 0.9, 0.55)
	R(ci, sub(r, 0.07, 0.12, 0.12, 0.16), 0.5)
	L(ci, _u(r, 0.0, 0.14), _u(r, 0.07, 0.14), 0.55, 1.4)
	_pu(ci, r, [Vector2(0.22, 0.24), Vector2(0.22, 0.19), Vector2(0.14, 0.19), Vector2(0.14, 0.15)], 0.35)
	L(ci, _u(r, 0.47, 0.05), _u(r, 0.47, 0.0), 0.55, 1.4)
	# relay strip on the wall
	var rs := sub(r, 0.14, 0.42, 0.62, 0.52)
	R(ci, rs, 0.5)
	for k in 4:
		var m := sub(r, 0.17 + k * 0.11, 0.435, 0.26 + k * 0.11, 0.505)
		R(ci, m, 0.42)
		_lamp(ci, m.position + Vector2(m.size.x * 0.5, m.size.y * 0.3), maxf(1.0, ms * 0.03), Pal.tint(Pal.VOLT, 0.75))
	_pu(ci, r, [Vector2(0.38, 0.34), Vector2(0.38, 0.42)], 0.45, 1.2)
	# conduit and saddles
	for x in [0.76, 0.82]:
		L(ci, _u(r, x, 0.34), _u(r, x, 0.62), 0.5)
	for k in 5:
		var y: float = 0.37 + k * 0.055
		L(ci, _u(r, 0.73, y), _u(r, 0.85, y), 0.45, 1.3)
	# battery box
	var bb := sub(r, 0.14, 0.62, 0.86, 0.96)
	R(ci, bb, 0.6, 1.2)
	E.louvres(ci, sub(r, 0.2, 0.645, 0.8, 0.69), 0.3)
	for x in [0.2, 0.52]:
		var b := sub(r, x, 0.72, x + 0.28, 0.93)
		R(ci, b, 0.5)
		L(ci, _u(r, x, 0.75), _u(r, x + 0.28, 0.75), 0.3)
		for f in [0.25, 0.75]:
			D(ci, _u(r, x + 0.28 * f, 0.715), 1.1, 0.6)
	L(ci, _u(r, 0.41, 0.715), _u(r, 0.59, 0.715), 0.55, 1.5)
	L(ci, _u(r, 0.0, 0.98), _u(r, 1.0, 0.98), 0.45, 1.3)


# ---------------------------------------------------------------- MED-47: pod battery
# each isolation pod's own medical UPS on its bedside bracket: carry handle, the display
# with its charge bars, buttons, the three outlets (air, monitors, bed) its leads leave
# from, the battery bay with its two cells and their link
static func pod_ups(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cs := sub(r, 0.12, 0.08, 0.88, 0.94)
	R(ci, cs, 0.62, 1.2)
	_pu(ci, r, [Vector2(0.32, 0.08), Vector2(0.32, 0.025), Vector2(0.68, 0.025), Vector2(0.68, 0.08)], 0.55, 1.4)
	var lcd := sub(r, 0.2, 0.13, 0.8, 0.27)
	E.Rc(ci, lcd, Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 4:
		var bar := sub(r, 0.26 + k * 0.08, 0.17, 0.31 + k * 0.08, 0.23)
		if k < 3:
			hatch(ci, bar, 2.0, false, 0.40, 30)
		R(ci, bar, 0.4)
	L(ci, _u(r, 0.6, 0.2), _u(r, 0.74, 0.2), 0.4)
	L(ci, _u(r, 0.67, 0.165), _u(r, 0.67, 0.235), 0.4)
	for x in [0.3, 0.46]:
		D(ci, _u(r, x, 0.33), maxf(1.0, ms * 0.035), 0.55)
	for x in [0.25, 0.5, 0.75]:
		var s := sub(r, x - 0.07, 0.44, x + 0.07, 0.54)
		R(ci, s, 0.5)
		D(ci, s.get_center(), 0.8, 0.6)
	var bay := sub(r, 0.2, 0.62, 0.8, 0.88)
	R(ci, bay, 0.42)
	for x in [0.24, 0.52]:
		R(ci, sub(r, x, 0.66, x + 0.24, 0.85), 0.45)
		D(ci, _u(r, x + 0.06, 0.69), 0.8, 0.55)
		D(ci, _u(r, x + 0.18, 0.69), 0.8, 0.55)
	L(ci, _u(r, 0.42, 0.69), _u(r, 0.58, 0.69), 0.5, 1.3)
	L(ci, _u(r, 0.88, 0.3), _u(r, 1.0, 0.3), 0.5, 1.3)
	L(ci, _u(r, 0.88, 0.75), _u(r, 1.0, 0.75), 0.5, 1.3)


# ---------------------------------------------------------------- ST-40: 800 V race battery
# a low racing pack: the carbon case (twill weave), modules under the lid, the orange HV
# leads and the orange-handled service disconnect, the pyro fuse, the coolant in/out at the
# middle where its pipe and the PDU cable meet it, the mounting feet
static func race_pack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cs := sub(r, 0.04, 0.3, 0.96, 0.86)
	R(ci, cs, 0.62, 1.3)
	var tw := PackedVector2Array()
	var n := clampi(int(cs.size.x / 6.0), 6, 30)
	for k in n:
		var x: float = cs.position.x + (k + 0.5) * cs.size.x / n
		tw.append(Vector2(x - 2.0, cs.end.y - 1.5))
		tw.append(Vector2(x + 2.0, cs.end.y - cs.size.y * 0.18))
	S(ci, tw, 0.18)
	for i in 4:
		var m := sub(r, 0.08 + i * 0.21, 0.36, 0.27 + i * 0.21, 0.66)
		R(ci, m, 0.45)
		L(ci, m.position + Vector2(2.0, m.size.y * 0.5), m.end - Vector2(2.0, m.size.y * 0.5), 0.25)
		D(ci, m.position + Vector2(2.5, 2.5), 0.8, 0.5)
		D(ci, Vector2(m.end.x - 2.5, m.position.y + 2.5), 0.8, 0.5)
	# HV leads (orange) out of the top to the disconnect and on
	E.Rc(ci, sub(r, 0.12, 0.2, 0.42, 0.24), Pal.heat(0.8), 1.0)
	E.Rc(ci, sub(r, 0.58, 0.2, 0.88, 0.24), Pal.heat(0.8), 1.0)
	var sd := sub(r, 0.42, 0.12, 0.58, 0.3)
	R(ci, sd, 0.6)
	E.Rc(ci, sub(r, 0.45, 0.06, 0.55, 0.12), Pal.heat(0.9), 1.0)
	R(ci, sub(r, 0.8, 0.12, 0.92, 0.2), 0.5)
	D(ci, _u(r, 0.86, 0.16), 0.9, 0.6)
	# coolant in/out and the PDU cable at the middle
	for x in [0.46, 0.54]:
		O(ci, _u(r, x, 0.5), maxf(1.6, ms * 0.035), 0.55)
	L(ci, _u(r, 0.5, 0.42), _u(r, 0.5, 0.58), 0.3)
	_lamp(ci, _u(r, 0.12, 0.76), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	for x in [0.1, 0.9]:
		R(ci, sub(r, x - 0.05, 0.86, x + 0.05, 0.94), 0.5)
		D(ci, _u(r, x, 0.9), 1.0, 0.55)


# ---------------------------------------------------------------- ARK-01 / MT-140: standby battery
# a vented standby bank kept on float: tall flooded cells in their clear jars (plates,
# electrolyte level), the intercell links, all in a spill tray; the float charger on the
# wall with its meter, the hydrogen hood and vent duct over the cells
static func standby_bank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_pu(ci, r, [Vector2(0.02, 0.84), Vector2(0.04, 0.96), Vector2(0.96, 0.96), Vector2(0.98, 0.84)], 0.55, 1.2)
	var n := clampi(int(r.size.x * 0.92 / 18.0), 3, 10)
	var cw: float = 0.92 / n
	var tops := []
	for i in n:
		var x0: float = 0.04 + i * cw
		var jar := sub(r, x0 + 0.008, 0.46, x0 + cw - 0.008, 0.94)
		E.Rc(ci, sub(r, x0 + 0.012, 0.58, x0 + cw - 0.012, 0.935), Pal.tint(Pal.FLUID, 0.18), 1.0)
		R(ci, jar, 0.55)
		L(ci, _u(r, x0 + 0.012, 0.58), _u(r, x0 + cw - 0.012, 0.58), 0.4)
		var pl := PackedVector2Array()
		for f in [0.3, 0.45, 0.6, 0.75]:
			pl.append(_u(r, x0 + cw * f, 0.62))
			pl.append(_u(r, x0 + cw * f, 0.9))
		S(ci, pl, 0.25)
		R(ci, sub(r, x0 + cw * 0.15, 0.43, x0 + cw * 0.85, 0.46), 0.5)
		D(ci, _u(r, x0 + cw * 0.5, 0.425), 0.9, 0.5)
		tops.append([_u(r, x0 + cw * 0.25, 0.43), _u(r, x0 + cw * 0.75, 0.43)])
	for i in n - 1:
		L(ci, tops[i][1], tops[i + 1][0], 0.55, 1.6)
	# hood and vent duct
	_pu(ci, r, [Vector2(0.04, 0.38), Vector2(0.12, 0.3), Vector2(0.88, 0.3), Vector2(0.96, 0.38)], 0.5, 1.2)
	_pu(ci, r, [Vector2(0.62, 0.3), Vector2(0.62, 0.0)], 0.5, 1.2)
	_pu(ci, r, [Vector2(0.72, 0.3), Vector2(0.72, 0.0)], 0.5, 1.2)
	# float charger on the wall, its lead down to the first cell
	var ch := sub(r, 0.06, 0.04, 0.42, 0.24)
	R(ci, ch, 0.58)
	E.gauge(ci, _u(r, 0.15, 0.14), maxf(2.5, ms * 0.06), 0.5)
	E.Rc(ci, sub(r, 0.24, 0.09, 0.38, 0.13), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp(ci, _u(r, 0.36, 0.19), maxf(1.4, ms * 0.035), Pal.tint(Pal.FLUID, 0.85))
	E.louvres(ci, sub(r, 0.22, 0.16, 0.32, 0.22), 0.25)
	_pu(ci, r, [Vector2(0.1, 0.24), Vector2(0.1, 0.3)], 0.45, 1.3)
	P(ci, PackedVector2Array([_u(r, 0.1, 0.3), _u(r, 0.02, 0.3), Vector2(_u(r, 0.02, 0).x, tops[0][0].y), tops[0][0]]), 0.45, 1.3)


# ---------------------------------------------------------------- the UPS (7 ships)
# a double-conversion UPS: rectifier/charger, inverter and static-bypass sections (each its
# fans, meters, breakers) beside its battery string; a tower when small, a cabinet line-up
# when large (more battery cabinets the bigger it is), the mimic panel showing the path
static func ups_unit(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	if r.size.x < 60.0:
		# a tower: display, mimic, fans; battery drawers below
		var tw := sub(r, 0.1, 0.04, 0.9, 0.96)
		R(ci, tw, 0.62, 1.2)
		E.Rc(ci, sub(r, 0.2, 0.08, 0.8, 0.18), Pal.tint(Pal.AIR, 0.6), 1.0)
		_ups_mimic(ci, sub(r, 0.2, 0.22, 0.8, 0.32))
		var fr: float = minf(r.size.x * 0.16, r.size.y * 0.08)
		E.fan(ci, _u(r, 0.5, 0.42), fr, 5, 0.42)
		for k in 3:
			var d := sub(r, 0.18, 0.54 + k * 0.13, 0.82, 0.65 + k * 0.13)
			R(ci, d, 0.45)
			L(ci, d.position + Vector2(d.size.x * 0.4, d.size.y * 0.5), d.position + Vector2(d.size.x * 0.6, d.size.y * 0.5), 0.55, 1.3)
		return
	# a line-up: power cabinet (rectifier, inverter, bypass) + battery cabinets
	var h := r.size.y
	R(ci, Rect2(r.position + Vector2(0, h * 0.95), Vector2(r.size.x, h * 0.05)), 0.55)
	var pw: float = clampf(r.size.x * 0.42, 40.0, 2.4 * M)
	var pc := Rect2(r.position + Vector2(1.0, h * 0.06), Vector2(pw - 2.0, h * 0.89))
	R(ci, pc, 0.62, 1.2)
	var mp := Rect2(pc.position + Vector2(pc.size.x * 0.08, pc.size.y * 0.04), Vector2(pc.size.x * 0.84, minf(pc.size.y * 0.16, 26.0)))
	R(ci, mp, 0.45)
	_ups_mimic(ci, mp.grow(-2.0))
	var y0: float = mp.end.y + pc.size.y * 0.04
	var secs := 3
	var sw: float = pc.size.x / secs
	for i in secs:
		var s := Rect2(pc.position.x + i * sw + 2.0, y0, sw - 4.0, pc.end.y - y0 - 3.0)
		R(ci, s, 0.45)
		var fr: float = minf(s.size.x * 0.32, s.size.y * 0.14)
		if fr >= 3.0:
			E.fan(ci, Vector2(s.get_center().x, s.position.y + fr + 3.0), fr, 5, 0.4)
		else:
			var vc := Vector2(s.get_center().x, s.position.y + 5.0)
			O(ci, vc, 2.6, 0.4)
			L(ci, vc - Vector2(2.6, 0), vc + Vector2(2.6, 0), 0.3)
		_lamp(ci, Vector2(s.get_center().x, s.position.y + s.size.y * 0.34), 1.6, Pal.tint(Pal.FLUID, 0.8) if i != 2 else Pal.ink(0.35))
		E.breaker(ci, Rect2(s.position + Vector2(s.size.x * 0.2, s.size.y * 0.42), Vector2(s.size.x * 0.6, minf(s.size.y * 0.14, 14.0))), i != 2, 0.45)
		E.louvres(ci, Rect2(s.position + Vector2(s.size.x * 0.15, s.size.y * 0.66), Vector2(s.size.x * 0.7, s.size.y * 0.28)), 0.25)
	# battery cabinets
	var bx0: float = pc.end.x + 3.0
	var nb := clampi(int((r.end.x - bx0) / (0.9 * M)), 1, 8)
	var bw: float = (r.end.x - bx0) / nb
	var bus := PackedVector2Array()
	for i in nb:
		var bc := Rect2(bx0 + i * bw, r.position.y + h * 0.1, bw - 2.0, h * 0.85)
		R(ci, bc, 0.58, 1.1)
		var nt := clampi(int(bc.size.y / 14.0), 2, 12)
		var segs := PackedVector2Array()
		for k in nt:
			var y: float = bc.position.y + (k + 1) * bc.size.y / (nt + 1)
			segs.append(Vector2(bc.position.x + 2.0, y))
			segs.append(Vector2(bc.end.x - 2.0, y))
			segs.append(Vector2(bc.position.x + bc.size.x * 0.2, y - 2.0))
			segs.append(Vector2(bc.position.x + bc.size.x * 0.2, y - minf(6.0, bc.size.y / (nt + 1) - 2.0)))
			segs.append(Vector2(bc.position.x + bc.size.x * 0.75, y - 2.0))
			segs.append(Vector2(bc.position.x + bc.size.x * 0.75, y - minf(6.0, bc.size.y / (nt + 1) - 2.0)))
		S(ci, segs, 0.35)
		L(ci, Vector2(bc.end.x - 3.0, bc.get_center().y - bc.size.y * 0.08), Vector2(bc.end.x - 3.0, bc.get_center().y + bc.size.y * 0.08), 0.6, 1.5)
		var dc := Rect2(bc.position + Vector2(bc.size.x * 0.3, 3.0), Vector2(bc.size.x * 0.4, minf(bc.size.y * 0.06, 8.0)))
		R(ci, dc, 0.5)
		bus.append(Vector2(dc.get_center().x, dc.position.y))
		bus.append(Vector2(dc.get_center().x, r.position.y + h * 0.04))
	S(ci, bus, 0.5, 1.4)
	L(ci, Vector2(pc.get_center().x, pc.position.y), Vector2(pc.get_center().x, r.position.y + h * 0.04), 0.5, 1.4)
	L(ci, Vector2(pc.get_center().x, r.position.y + h * 0.04), Vector2(bus[bus.size() - 1].x, r.position.y + h * 0.04), 0.55, 1.8)
	_lamp(ci, pc.position + Vector2(pc.size.x * 0.9, pc.size.y * 0.02 + 2.0), maxf(1.6, ms * 0.03), Pal.tint(Pal.FLUID, 0.85))


# the UPS mimic: mains -> rectifier -> inverter -> load, the battery on the DC link, the bypass
static func _ups_mimic(ci: CanvasItem, m: Rect2) -> void:
	var y: float = m.position.y + m.size.y * 0.6
	var bw: float = m.size.x * 0.16
	var bh: float = m.size.y * 0.5
	for f in [0.18, 0.55]:
		R(ci, Rect2(m.position.x + m.size.x * f, y - bh * 0.5, bw, bh), 0.45)
	L(ci, Vector2(m.position.x, y), Vector2(m.position.x + m.size.x * 0.18, y), 0.4)
	L(ci, Vector2(m.position.x + m.size.x * 0.18 + bw, y), Vector2(m.position.x + m.size.x * 0.55, y), 0.4)
	L(ci, Vector2(m.position.x + m.size.x * 0.55 + bw, y), Vector2(m.end.x, y), 0.4)
	L(ci, Vector2(m.position.x + m.size.x * 0.44, y), Vector2(m.position.x + m.size.x * 0.44, m.end.y), 0.4)
	P(ci, PackedVector2Array([Vector2(m.position.x + m.size.x * 0.08, y), Vector2(m.position.x + m.size.x * 0.08, m.position.y + 1.0), Vector2(m.position.x + m.size.x * 0.88, m.position.y + 1.0), Vector2(m.position.x + m.size.x * 0.88, y)]), 0.25)


# ================================================================== the shared "cabinet" (E036–E086)
# 2026-11-11, third batch from the 零件图鉴: fifty-one kinds all drew as the same double-door
# cabinet, most of them not cabinets at all. Each drawn as what it is.

# a cabinet's carcass: faint fill, frame, plinth; returns the body rect
static func _carcass(ci: CanvasItem, r: Rect2, x0: float = 0.06, y0: float = 0.04, x1: float = 0.94, y1: float = 0.95) -> Rect2:
	var b := sub(r, x0, y0, x1, y1)
	R(ci, b, 0.62, 1.2)
	R(ci, sub(r, x0 - 0.02, y1, x1 + 0.02, minf(y1 + 0.04, 1.0)), 0.5)
	return b


# a row of n small lamps across a rect's middle; every k-th dark
static func _lamp_row(ci: CanvasItem, r: Rect2, n: int, col: Color, dark_every: int = 0) -> void:
	for k in n:
		var c := Vector2(r.position.x + (k + 0.5) * r.size.x / n, r.get_center().y)
		if dark_every > 0 and k % dark_every == dark_every - 1:
			D(ci, c, 0.8, 0.35)
		else:
			_lamp(ci, c, maxf(1.4, minf(r.size.y * 0.6, 2.4)), col)


# ---------------------------------------------------------------- ARK-01: despin brake control
# the ring brake's control cabinet: the ring mimic with its two calipers and the speed
# readout, torque bargraph, PLC card rack, the brake contactors, the cooling-pump starter,
# the guarded emergency release, cable glands up top
static func brake_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r)
	var mp := sub(r, 0.12, 0.08, 0.88, 0.3)
	R(ci, mp, 0.45)
	var rc := _u(r, 0.36, 0.19)
	var rr: float = minf(mp.size.y * 0.38, mp.size.x * 0.22)
	O(ci, rc, rr, 0.55)
	O(ci, rc, rr * 0.35, 0.4)
	for a in [-0.4, PI + 0.4]:
		var cp: Vector2 = rc + Vector2.from_angle(a) * rr
		R(ci, Rect2(cp - Vector2(2.0, 2.5), Vector2(4.0, 5.0)), 0.6)
	A(ci, rc, rr * 1.25, -PI * 0.8, -PI * 0.3, 0.4)
	E.Rc(ci, sub(r, 0.6, 0.11, 0.84, 0.17), Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 6:
		var bar := sub(r, 0.6 + k * 0.04, 0.27 - 0.015 * (k + 1), 0.63 + k * 0.04, 0.27)
		if k < 4:
			hatch(ci, bar, 2.0, false, 0.45, 30)
		R(ci, bar, 0.35)
	var pl := sub(r, 0.12, 0.35, 0.88, 0.52)
	R(ci, pl, 0.45)
	var cards := PackedVector2Array()
	for k in 8:
		var x: float = pl.position.x + (k + 0.5) * pl.size.x / 8.0
		cards.append(Vector2(x, pl.position.y + 2.0))
		cards.append(Vector2(x, pl.end.y - 2.0))
	S(ci, cards, 0.3)
	_lamp_row(ci, Rect2(pl.position + Vector2(0, 2.0), Vector2(pl.size.x, 4.0)), 8, Pal.tint(Pal.FLUID, 0.8), 5)
	for x in [0.14, 0.4]:
		var ct := sub(r, x, 0.57, x + 0.2, 0.74)
		R(ci, ct, 0.5)
		L(ci, ct.position + Vector2(ct.size.x * 0.25, ct.size.y * 0.3), ct.position + Vector2(ct.size.x * 0.75, ct.size.y * 0.3), 0.4)
		D(ci, ct.get_center() + Vector2(0, ct.size.y * 0.15), 1.0, 0.5)
	E.breaker(ci, sub(r, 0.66, 0.57, 0.86, 0.68), true, 0.45)
	var es := _u(r, 0.76, 0.84)
	A(ci, es, maxf(3.0, ms * 0.1), PI, TAU, 0.5, 1.3)
	_lamp(ci, es - Vector2(0, ms * 0.03), maxf(2.0, ms * 0.08), Pal.heat(0.9))
	E.louvres(ci, sub(r, 0.14, 0.8, 0.5, 0.92), 0.28)
	for x in [0.3, 0.5, 0.7]:
		R(ci, Rect2(_u(r, x, 0.0) + Vector2(-1.5, b.position.y - r.position.y - 3.0), Vector2(3.0, 3.0)), 0.5)


# ---------------------------------------------------------------- ARK-01: chemical dosing
# the primary-water chemistry dosing cabinet: two chemical tanks (their levels) in the
# bunded bottom, a diaphragm metering pump on each with its stroke knob, the injection lines
# up through check valves, the controller with its readout, the hazard diamond
static func dosing_skid(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	_pu(ci, r, [Vector2(0.1, 0.72), Vector2(0.1, 0.92), Vector2(0.9, 0.92), Vector2(0.9, 0.72)], 0.45)
	for x in [0.14, 0.52]:
		var t := sub(r, x, 0.62, x + 0.34, 0.9)
		E.Rc(ci, sub(r, x + 0.01, 0.72, x + 0.33, 0.895), Pal.tint(Pal.FLUID, 0.22), 1.0)
		R(ci, t, 0.55)
		L(ci, _u(r, x + 0.01, 0.72), _u(r, x + 0.33, 0.72), 0.4)
		R(ci, sub(r, x + 0.12, 0.59, x + 0.22, 0.62), 0.5)
		# the metering pump on its bracket
		var pc := _u(r, x + 0.17, 0.46)
		var pr: float = minf(r.size.x * 0.09, r.size.y * 0.05)
		O(ci, pc, pr, 0.58)
		O(ci, pc, pr * 0.45, 0.4)
		R(ci, Rect2(pc + Vector2(-pr * 0.6, pr), Vector2(pr * 1.2, pr * 1.4)), 0.45)
		O(ci, pc + Vector2(0, -pr * 1.5), maxf(1.4, pr * 0.4), 0.5)
		L(ci, _u(r, x + 0.17, 0.59), pc + Vector2(0, pr * 2.4), 0.4)
		# injection line with its check valve
		P(ci, PackedVector2Array([pc + Vector2(pr, 0), Vector2(_u(r, x + 0.3, 0).x, pc.y), _u(r, x + 0.3, 0.0)]), 0.5, 1.2)
		var cv := _u(r, x + 0.3, 0.3)
		P(ci, PackedVector2Array([cv + Vector2(-2.5, -2.5), cv + Vector2(2.5, 2.5), cv + Vector2(2.5, -2.5), cv + Vector2(-2.5, 2.5), cv + Vector2(-2.5, -2.5)]), 0.5)
	var ct := sub(r, 0.12, 0.08, 0.5, 0.26)
	R(ci, ct, 0.5)
	E.Rc(ci, sub(r, 0.15, 0.11, 0.38, 0.16), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp_row(ci, sub(r, 0.15, 0.19, 0.45, 0.23), 3, Pal.tint(Pal.FLUID, 0.85))
	var hd := _u(r, 0.68, 0.17)
	var hs: float = maxf(3.0, ms * 0.08)
	P(ci, PackedVector2Array([hd + Vector2(0, -hs), hd + Vector2(hs, 0), hd + Vector2(0, hs), hd + Vector2(-hs, 0), hd + Vector2(0, -hs)]), 0.55)
	E.Rc(ci, Rect2(hd - Vector2(hs, hs) * 0.35, Vector2(hs, hs) * 0.7), Pal.heat(0.6), 1.0)


# ---------------------------------------------------------------- ARK-01: material rack
# the industrial deck's raw-stock rack: an upright with cantilever arms, round bar and
# square tube racked on them (end on), a slot of plate sheets down the side, the offcut bin
static func material_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.08, 0.02), _u(r, 0.08, 0.96), 0.62, 2.0)
	L(ci, _u(r, 0.02, 0.97), _u(r, 0.98, 0.97), 0.55, 1.5)
	for i in 4:
		var y: float = 0.18 + i * 0.17
		L(ci, _u(r, 0.08, y), _u(r, 0.62, y - 0.02), 0.58, 1.6)
		L(ci, _u(r, 0.62, y - 0.02), _u(r, 0.62, y - 0.05), 0.5, 1.3)
		var rad: float = maxf(1.6, ms * (0.035 + 0.008 * (i % 2)))
		var n := clampi(int(r.size.x * 0.5 / (rad * 2.3)), 3, 10)
		for k in n:
			var c := _u(r, 0.12 + (k + 0.5) * 0.48 / n, 0.0)
			c.y = _u(r, 0, y).y - rad - 1.0 - k * r.size.y * 0.02 / n
			# round bar ends as dots, square tube as a box: 17 of these racks on ARK-01
			if i == 2:
				R(ci, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), 0.45)
			else:
				D(ci, c, rad, 0.4)
		D(ci, _u(r, 0.08, y), 1.0, 0.55)
	# plate slot
	R(ci, sub(r, 0.7, 0.12, 0.96, 0.8), 0.5)
	var pl := PackedVector2Array()
	for k in 7:
		var x: float = 0.73 + k * 0.032
		pl.append(_u(r, x, 0.16 + (k % 3) * 0.03))
		pl.append(_u(r, x + 0.01, 0.79))
	S(ci, pl, 0.42)
	# offcut bin
	var bn := sub(r, 0.66, 0.84, 0.98, 0.96)
	R(ci, bn, 0.55)
	for q in [Vector2(0.72, 0.84), Vector2(0.8, 0.82), Vector2(0.9, 0.83)]:
		L(ci, _u(r, q.x, q.y), _u(r, q.x + 0.05, q.y - 0.05), 0.45)


# ---------------------------------------------------------------- ARK-01: food processing bench
# a stainless prep bench in the ring's galley: backsplash with the utensil rail, the sink
# and its swan-neck tap, the cutting board and knife, the slicer (blade, guard, carriage),
# the undershelf of lidded containers, legs on levelling feet
static func food_bench(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.02, 0.46), _u(r, 0.98, 0.46), 0.62, 1.8)
	L(ci, _u(r, 0.02, 0.46), _u(r, 0.02, 0.18), 0.5)
	L(ci, _u(r, 0.02, 0.18), _u(r, 0.98, 0.18), 0.4)
	L(ci, _u(r, 0.98, 0.18), _u(r, 0.98, 0.46), 0.5)
	L(ci, _u(r, 0.06, 0.24), _u(r, 0.4, 0.24), 0.45)
	for x in [0.1, 0.17, 0.24, 0.31]:
		L(ci, _u(r, x, 0.24), _u(r, x, 0.34), 0.35)
	# sink and tap
	_pu(ci, r, [Vector2(0.05, 0.46), Vector2(0.07, 0.58), Vector2(0.24, 0.58), Vector2(0.26, 0.46)], 0.55)
	E.Rc(ci, sub(r, 0.08, 0.5, 0.23, 0.56), Pal.tint(Pal.FLUID, 0.25), 1.0)
	_pu(ci, r, [Vector2(0.2, 0.46), Vector2(0.2, 0.3), Vector2(0.15, 0.3), Vector2(0.15, 0.36)], 0.55, 1.3)
	# board and knife
	R(ci, sub(r, 0.32, 0.4, 0.52, 0.46), 0.5)
	L(ci, _u(r, 0.36, 0.38), _u(r, 0.48, 0.36), 0.55, 1.4)
	L(ci, _u(r, 0.48, 0.36), _u(r, 0.52, 0.355), 0.6, 2.0)
	# slicer
	var sc := _u(r, 0.73, 0.3)
	var sr: float = ms * 0.14
	O(ci, sc, sr, 0.58, 1.2)
	A(ci, sc, sr * 1.15, PI * 0.9, PI * 1.9, 0.45)
	D(ci, sc, 1.2, 0.6)
	R(ci, sub(r, 0.6, 0.38, 0.92, 0.46), 0.5)
	L(ci, _u(r, 0.86, 0.38), _u(r, 0.86, 0.26), 0.45)
	_lamp(ci, _u(r, 0.9, 0.42), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.8))
	# undershelf and containers
	L(ci, _u(r, 0.04, 0.8), _u(r, 0.96, 0.8), 0.5, 1.3)
	for k in 5:
		var x: float = 0.08 + k * 0.17
		R(ci, sub(r, x, 0.63, x + 0.13, 0.8), 0.42)
		L(ci, _u(r, x - 0.005, 0.66), _u(r, x + 0.135, 0.66), 0.4)
	for x in [0.04, 0.96]:
		L(ci, _u(r, x, 0.46), _u(r, x, 0.95), 0.58, 1.5)
		L(ci, _u(r, x - 0.02, 0.97), _u(r, x + 0.02, 0.97), 0.55, 1.4)


# ---------------------------------------------------------------- ARK-01: transmitter
# the long-range transmitter: exciter drawer with its frequency readout, the final stage
# behind a viewing window (the finned power tube in its cavity), forward/reflected/plate
# meters, the HV supply (transformer, filter capacitors), the rigid coax and directional
# coupler out of the roof, the door interlock
static func tx_cabinet(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r)
	var ex := sub(r, 0.1, 0.07, 0.9, 0.17)
	R(ci, ex, 0.5)
	E.Rc(ci, sub(r, 0.14, 0.095, 0.48, 0.145), Pal.tint(Pal.AIR, 0.6), 1.0)
	for x in [0.6, 0.7, 0.8]:
		D(ci, _u(r, x, 0.12), 1.0, 0.55)
	for k in 3:
		E.gauge(ci, _u(r, 0.22 + k * 0.28, 0.23), maxf(2.5, ms * 0.08), 0.5)
	var wn := sub(r, 0.16, 0.31, 0.84, 0.62)
	R(ci, wn, 0.55)
	R(ci, wn.grow(-2.0), 0.3)
	var tc := wn.get_center()
	var tw: float = wn.size.x * 0.22
	var th: float = wn.size.y * 0.7
	R(ci, Rect2(tc - Vector2(tw * 0.5, th * 0.5), Vector2(tw, th)), 0.58)
	var fins := PackedVector2Array()
	for k in 6:
		var y: float = tc.y - th * 0.4 + k * th * 0.16
		fins.append(Vector2(tc.x - tw * 0.8, y))
		fins.append(Vector2(tc.x + tw * 0.8, y))
	S(ci, fins, 0.35)
	L(ci, tc + Vector2(0, -th * 0.5), Vector2(tc.x, wn.position.y + 2.0), 0.5, 1.4)
	var ps := sub(r, 0.1, 0.67, 0.9, 0.92)
	R(ci, ps, 0.5)
	R(ci, sub(r, 0.14, 0.7, 0.42, 0.89), 0.45)
	hatch(ci, sub(r, 0.2, 0.72, 0.36, 0.87), 2.2, false, 0.25, 12)
	for x in [0.52, 0.64, 0.76]:
		R(ci, sub(r, x, 0.72, x + 0.08, 0.88), 0.45)
		L(ci, _u(r, x, 0.75), _u(r, x + 0.08, 0.75), 0.3)
	L(ci, _u(r, 0.82, 0.07), _u(r, 0.82, 0.0), 0.62, 2.2)
	R(ci, Rect2(_u(r, 0.82, 0.0) + Vector2(-2.5, 1.0), Vector2(5.0, b.position.y - r.position.y - 1.0)), 0.55)
	R(ci, sub(r, 0.9, 0.42, 0.94, 0.5), 0.5)
	E.Rc(ci, sub(r, 0.66, 0.45, 0.76, 0.48), Pal.heat(0.7), 1.0)


# ---------------------------------------------------------------- ARK-01: turbine control
# the turbine governor cabinet: the train mimic (turbine, generator, valves), the big speed
# dial, steam valve position bargraphs, the triple-redundant controllers each with its
# lamps, the trip and reset pushbuttons
static func turbine_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var mp := sub(r, 0.12, 0.07, 0.88, 0.25)
	R(ci, mp, 0.45)
	_pu(ci, r, [Vector2(0.28, 0.12), Vector2(0.48, 0.1), Vector2(0.48, 0.22), Vector2(0.28, 0.2)], 0.55, 1.0, true)
	O(ci, _u(r, 0.66, 0.16), minf(mp.size.y * 0.32, mp.size.x * 0.1), 0.55)
	L(ci, _u(r, 0.48, 0.16), _u(r, 0.6, 0.16), 0.45, 1.3)
	L(ci, _u(r, 0.16, 0.13), _u(r, 0.28, 0.13), 0.4)
	var vc := _u(r, 0.22, 0.13)
	P(ci, PackedVector2Array([vc + Vector2(-2.5, -2), vc + Vector2(2.5, 2), vc + Vector2(2.5, -2), vc + Vector2(-2.5, 2), vc + Vector2(-2.5, -2)]), 0.5)
	E.gauge(ci, _u(r, 0.3, 0.37), maxf(3.0, ms * 0.17), 0.58)
	for k in 4:
		var bar := sub(r, 0.56 + k * 0.08, 0.29, 0.61 + k * 0.08, 0.45)
		R(ci, bar, 0.4)
		hatch(ci, Rect2(bar.position + Vector2(0, bar.size.y * (0.2 + 0.15 * k)), Vector2(bar.size.x, bar.size.y * (0.8 - 0.15 * k))), 2.0, false, 0.35, 30)
	for k in 3:
		var cc := sub(r, 0.12 + k * 0.26, 0.52, 0.34 + k * 0.26, 0.76)
		R(ci, cc, 0.48)
		hatch(ci, Rect2(cc.position + Vector2(2, cc.size.y * 0.4), cc.size * Vector2(1, 0.55) - Vector2(4, 0)), 3.0, true, 0.25, 8)
		_lamp_row(ci, Rect2(cc.position + Vector2(2, 2), Vector2(cc.size.x - 4, cc.size.y * 0.25)), 3, Pal.tint(Pal.FLUID, 0.85))
	for q in [[0.3, Pal.heat(0.9)], [0.5, Pal.tint(Pal.FLUID, 0.8)], [0.7, Pal.ink(0.5)]]:
		var c := _u(r, q[0], 0.85)
		O(ci, c, maxf(2.0, ms * 0.06), 0.5)
		_lamp(ci, c, maxf(1.6, ms * 0.05), q[1])


# ---------------------------------------------------------------- bench drill (ARK-01, TW-64)
# a pillar drill: base with its T-slots, the column, the table on its collar and crank,
# the vice, the head with the motor behind, the belt guard, the quill, chuck and bit,
# the three-spoke feed handle, the work lamp
static func bench_drill(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.1, 0.92, 0.9, 0.99), 0.6, 1.2)
	for x in [0.35, 0.65]:
		L(ci, _u(r, x, 0.925), _u(r, x, 0.985), 0.35)
	R(ci, sub(r, 0.62, 0.12, 0.72, 0.92), 0.58)
	R(ci, sub(r, 0.15, 0.6, 0.68, 0.64), 0.55)
	R(ci, sub(r, 0.6, 0.58, 0.76, 0.68), 0.5)
	O(ci, _u(r, 0.82, 0.63), maxf(1.4, ms * 0.04), 0.5)
	L(ci, _u(r, 0.76, 0.63), _u(r, 0.82, 0.63), 0.45)
	R(ci, sub(r, 0.24, 0.54, 0.5, 0.6), 0.5)
	L(ci, _u(r, 0.37, 0.54), _u(r, 0.37, 0.5), 0.4)
	var hd := sub(r, 0.12, 0.14, 0.78, 0.34)
	R(ci, hd, 0.6, 1.2)
	R(ci, sub(r, 0.12, 0.04, 0.78, 0.14), 0.5)
	L(ci, _u(r, 0.2, 0.09), _u(r, 0.7, 0.09), 0.3)
	E.motor(ci, sub(r, 0.62, 0.17, 0.98, 0.31), false, 0.45)
	R(ci, sub(r, 0.3, 0.34, 0.42, 0.42), 0.55)
	_pu(ci, r, [Vector2(0.31, 0.42), Vector2(0.33, 0.46), Vector2(0.39, 0.46), Vector2(0.41, 0.42)], 0.55)
	L(ci, _u(r, 0.36, 0.46), _u(r, 0.36, 0.53), 0.6, 1.3)
	var hc := _u(r, 0.5, 0.3)
	for a in [0.4, 2.5, 4.6]:
		L(ci, hc, hc + Vector2.from_angle(a) * ms * 0.2, 0.5, 1.2)
		D(ci, hc + Vector2.from_angle(a) * ms * 0.2, 1.4, 0.55)
	_pu(ci, r, [Vector2(0.12, 0.2), Vector2(0.04, 0.2), Vector2(0.04, 0.36), Vector2(0.12, 0.4)], 0.45)
	_lamp(ci, _u(r, 0.12, 0.4), maxf(1.4, ms * 0.05), Pal.heat(0.6))
	_lamp(ci, _u(r, 0.22, 0.24), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- tool cart (ARK-01, CV-138)
# a mechanic's roll cab: the tray top with its tools (spanner, hammer, screwdriver), the
# drawers and their pull bars (more of them the taller it is), the push handle, casters
static func tool_cart(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var tall: bool = r.size.y > r.size.x * 0.95
	if not tall:
		_service_cart(ci, r)
		return
	var top: float = 0.28 if tall else 0.36
	var bx := sub(r, 0.06, top, 0.84, 0.86)
	R(ci, bx, 0.62, 1.2)
	_pu(ci, r, [Vector2(0.04, top - 0.08), Vector2(0.06, top), Vector2(0.84, top), Vector2(0.86, top - 0.08)], 0.55)
	if tall:
		var tb := sub(r, 0.1, 0.04, 0.8, top - 0.1)
		R(ci, tb, 0.55)
		L(ci, tb.position + Vector2(0, tb.size.y * 0.3), Vector2(tb.end.x, tb.position.y + tb.size.y * 0.3), 0.4)
		D(ci, tb.position + Vector2(tb.size.x * 0.5, tb.size.y * 0.3), 1.2, 0.55)
	var ty: float = top - 0.08
	L(ci, _u(r, 0.12, ty), _u(r, 0.32, ty - 0.02), 0.6, 1.5)
	O(ci, _u(r, 0.1, ty + 0.005), maxf(1.4, ms * 0.04), 0.5)
	L(ci, _u(r, 0.4, ty), _u(r, 0.58, ty), 0.55, 1.2)
	R(ci, Rect2(_u(r, 0.56, ty) + Vector2(0, -3.0), Vector2(r.size.x * 0.07, 4.5)), 0.6)
	L(ci, _u(r, 0.64, ty), _u(r, 0.74, ty - 0.01), 0.55, 1.6)
	L(ci, _u(r, 0.74, ty - 0.01), _u(r, 0.8, ty - 0.012), 0.5)
	var n := clampi(int(bx.size.y / 9.0), 3, 9)
	for k in n:
		var y: float = bx.position.y + k * bx.size.y / n
		if k > 0:
			L(ci, Vector2(bx.position.x, y), Vector2(bx.end.x, y), 0.45)
		var hy: float = y + bx.size.y / n * 0.4
		L(ci, Vector2(bx.position.x + bx.size.x * 0.3, hy), Vector2(bx.position.x + bx.size.x * 0.7, hy), 0.55, 1.3)
	_pu(ci, r, [Vector2(0.84, top + 0.04), Vector2(0.96, top + 0.04), Vector2(0.96, 0.8), Vector2(0.84, 0.8)], 0.5, 1.4)
	var wr: float = ms * 0.06
	for x in [0.16, 0.74]:
		var wc := Vector2(_u(r, x, 0).x, _u(r, 0, 0.86).y + wr + 1.5)
		O(ci, wc, wr, 0.55, 1.2)
		L(ci, wc, Vector2(wc.x, _u(r, 0, 0.86).y), 0.45)


# ---------------------------------------------------------------- CV-138: drone battery pack rack
# the charging rack for the drones' packs: six shelves, each with its packs (chamfered,
# strapped, a charge lamp: charging orange, full green), the charge leads to the bus duct up
# the side, the extinguishing nozzle line over the top, the cable tray
static func pack_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	for x in [0.04, 0.84]:
		L(ci, _u(r, x, 0.06), _u(r, x, 0.99), 0.6, 1.6)
	var nsh := clampi(int(r.size.y / 34.0), 3, 8)
	var sh: float = 0.9 / nsh
	for i in nsh:
		var y: float = 0.08 + (i + 1) * sh
		L(ci, _u(r, 0.03, y), _u(r, 0.85, y), 0.58, 1.4)
		for k in 2:
			var x0: float = 0.08 + k * 0.38
			var c := 0.02
			var y0: float = y - sh * 0.75
			_pu(ci, r, [Vector2(x0 + c, y0), Vector2(x0 + 0.34 - c, y0), Vector2(x0 + 0.34, y0 + c), Vector2(x0 + 0.34, y - 0.005), Vector2(x0, y - 0.005), Vector2(x0, y0 + c)], 0.52, 1.0, true)
			_pu(ci, r, [Vector2(x0 + 0.08, y0), Vector2(x0 + 0.1, y0 - sh * 0.15), Vector2(x0 + 0.24, y0 - sh * 0.15), Vector2(x0 + 0.26, y0)], 0.4)
			var full: bool = (i * 2 + k) % 3 != 1
			_lamp(ci, _u(r, x0 + 0.05, y - sh * 0.3), maxf(1.6, ms * 0.04), Pal.tint(Pal.FLUID, 0.85) if full else Pal.heat(0.85))
			L(ci, _u(r, x0 + 0.34, y - sh * 0.35), _u(r, 0.86, y - sh * 0.35), 0.35)
	R(ci, sub(r, 0.86, 0.06, 0.96, 0.98), 0.55)
	L(ci, _u(r, 0.91, 0.08), _u(r, 0.91, 0.96), 0.3)
	L(ci, _u(r, 0.04, 0.04), _u(r, 0.84, 0.04), 0.5, 1.3)
	for x in [0.2, 0.44, 0.68]:
		var c := _u(r, x, 0.04)
		L(ci, c, c + Vector2(0, r.size.y * 0.02), 0.5)
		_pu(ci, r, [Vector2(x - 0.03, 0.075), Vector2(x, 0.06), Vector2(x + 0.03, 0.075)], 0.3)
	hatch(ci, sub(r, 0.04, 0.0, 0.96, 0.025), 4.0, true, 0.3, 40)


# ---------------------------------------------------------------- CV-138: dispatch recorder
# the drone dispatch recorder: the bay status board (a grid of bays, the out ones lit), the
# ticket printer with its tear bar and a ticket hanging, the keyboard shelf, the headset on
# its hook, the recorder drawer with its media slot
static func dispatch_log(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.04, 0.94, 0.95)
	var bd := sub(r, 0.1, 0.08, 0.9, 0.42)
	R(ci, bd, 0.55)
	for row in 3:
		for c in 6:
			var cell := sub(r, 0.13 + c * 0.125, 0.11 + row * 0.1, 0.22 + c * 0.125, 0.18 + row * 0.1)
			if (row * 6 + c) % 4 == 1:
				E.Rc(ci, cell, Pal.tint(Pal.FLUID, 0.7), 1.0)
			elif (row * 6 + c) % 7 == 3:
				E.Rc(ci, cell, Pal.heat(0.7), 1.0)
			else:
				R(ci, cell, 0.35)
	var pr := sub(r, 0.1, 0.47, 0.5, 0.58)
	R(ci, pr, 0.5)
	L(ci, _u(r, 0.13, 0.58), _u(r, 0.47, 0.58), 0.6, 1.5)
	_pu(ci, r, [Vector2(0.18, 0.58), Vector2(0.18, 0.68), Vector2(0.38, 0.68), Vector2(0.38, 0.58)], 0.4)
	for y in [0.62, 0.65]:
		L(ci, _u(r, 0.21, y), _u(r, 0.34, y), 0.25)
	R(ci, sub(r, 0.08, 0.72, 0.62, 0.78), 0.5)
	hatch(ci, sub(r, 0.1, 0.73, 0.6, 0.77), 3.0, true, 0.25, 40)
	R(ci, sub(r, 0.86, 0.48, 0.94, 0.52), 0.5)
	A(ci, _u(r, 0.82, 0.6), r.size.x * 0.08, PI, TAU, 0.5, 1.4)
	O(ci, _u(r, 0.74, 0.62), maxf(1.6, ms * 0.04), 0.5)
	O(ci, _u(r, 0.9, 0.62), maxf(1.6, ms * 0.04), 0.5)
	var dr := sub(r, 0.1, 0.82, 0.9, 0.92)
	R(ci, dr, 0.5)
	L(ci, _u(r, 0.2, 0.87), _u(r, 0.5, 0.87), 0.55, 1.5)
	_lamp(ci, _u(r, 0.8, 0.87), maxf(1.4, ms * 0.035), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- the battery management cabinet (SV-122, MF-126)
# string monitors (per-cell voltage bars), the main contactors and the precharge resistor,
# the current shunt on the busbar, the insulation monitor, the smoke detector; tall it
# stacks them, wide it lays them side by side
static func bms_cab(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r)
	var wide: bool = r.size.x > r.size.y * 1.3
	var nmon := 3 if wide else clampi(int(b.size.y * 0.5 / 18.0), 2, 6)
	for i in nmon:
		var m := sub(r, 0.1 + i * 0.27, 0.1, 0.33 + i * 0.27, 0.55) if wide else sub(r, 0.1, 0.08 + i * 0.5 / nmon, 0.9, 0.08 + (i + 1) * 0.5 / nmon - 0.02)
		R(ci, m, 0.48)
		var nb := clampi(int(m.size.x / 4.0), 4, 16)
		var bars := PackedVector2Array()
		for k in nb:
			var x: float = m.position.x + (k + 0.6) * m.size.x / (nb + 0.2)
			bars.append(Vector2(x, m.end.y - 2.0))
			bars.append(Vector2(x, m.end.y - 2.0 - (m.size.y - 6.0) * (0.55 + 0.35 * fposmod(k * 0.37 + i * 0.2, 1.0))))
		S(ci, bars, 0.4, 1.4)
		_lamp(ci, m.position + Vector2(3.0, 3.0), 1.8, Pal.tint(Pal.FLUID, 0.85))
	var y0: float = 0.6
	for k in 2:
		var ct := sub(r, 0.12 + k * 0.2, y0, 0.28 + k * 0.2, y0 + 0.22)
		R(ci, ct, 0.5)
		L(ci, ct.position + Vector2(ct.size.x * 0.25, ct.size.y * 0.3), ct.position + Vector2(ct.size.x * 0.75, ct.size.y * 0.3), 0.4)
	var pz := PackedVector2Array()
	for k in 7:
		pz.append(_u(r, 0.56 + k * 0.025, y0 + (0.04 if k % 2 == 0 else 0.1)))
	P(ci, pz, 0.45)
	L(ci, _u(r, 0.54, y0 + 0.16), _u(r, 0.88, y0 + 0.16), 0.6, 2.0)
	R(ci, sub(r, 0.66, y0 + 0.13, 0.76, y0 + 0.19), 0.55)
	E.Rc(ci, sub(r, 0.72, y0 - 0.0, 0.88, y0 + 0.07), Pal.tint(Pal.AIR, 0.6), 1.0)
	O(ci, _u(r, 0.82, 0.88), maxf(2.0, ms * 0.05), 0.45)
	D(ci, _u(r, 0.82, 0.88), 1.0, 0.45)


# ---------------------------------------------------------------- SV-122: calibration bench
# the survey instruments' calibration bench: the total station on its calibration mount
# sighting along the collimator on its rail, the reference standards (meter, generator) on
# the shelf above, the anti-static mat, the drawers, the bench legs
static func cal_bench(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.02, 0.56), _u(r, 0.98, 0.56), 0.62, 1.8)
	R(ci, sub(r, 0.04, 0.53, 0.6, 0.56), 0.3)
	for x in [0.04, 0.96]:
		L(ci, _u(r, x, 0.56), _u(r, x, 0.98), 0.55, 1.5)
	var dw := sub(r, 0.66, 0.6, 0.94, 0.94)
	R(ci, dw, 0.5)
	for k in 3:
		var y: float = 0.6 + k * 0.113
		L(ci, _u(r, 0.66, y), _u(r, 0.94, y), 0.4)
		L(ci, _u(r, 0.76, y + 0.055), _u(r, 0.84, y + 0.055), 0.55, 1.3)
	# shelf and standards
	L(ci, _u(r, 0.04, 0.2), _u(r, 0.96, 0.2), 0.55, 1.4)
	for x in [0.04, 0.96]:
		L(ci, _u(r, x, 0.02), _u(r, x, 0.2), 0.45)
	R(ci, sub(r, 0.08, 0.06, 0.3, 0.2), 0.5)
	E.Rc(ci, sub(r, 0.1, 0.09, 0.22, 0.13), Pal.tint(Pal.AIR, 0.6), 1.0)
	R(ci, sub(r, 0.34, 0.08, 0.58, 0.2), 0.5)
	E.screen_face(ci, sub(r, 0.36, 0.1, 0.48, 0.18), 0, 0.35)
	for x in [0.52, 0.55]:
		D(ci, _u(r, x, 0.14), 1.0, 0.55)
	# total station on its mount
	var ts := _u(r, 0.18, 0.4)
	R(ci, sub(r, 0.12, 0.47, 0.24, 0.53), 0.55)
	L(ci, _u(r, 0.18, 0.47), _u(r, 0.18, 0.44), 0.5, 1.3)
	R(ci, Rect2(ts - Vector2(r.size.x * 0.04, ms * 0.12), Vector2(r.size.x * 0.08, ms * 0.16)), 0.58)
	R(ci, Rect2(ts + Vector2(r.size.x * 0.03, -ms * 0.08), Vector2(r.size.x * 0.05, ms * 0.07)), 0.55)
	# collimator on its rail
	L(ci, _u(r, 0.3, 0.52), _u(r, 0.9, 0.52), 0.5, 1.3)
	R(ci, sub(r, 0.56, 0.33, 0.88, 0.43), 0.58)
	L(ci, _u(r, 0.56, 0.38), _u(r, 0.26, 0.38), 0.25)
	for x in [0.62, 0.82]:
		L(ci, _u(r, x, 0.43), _u(r, x, 0.52), 0.45, 1.2)
	O(ci, _u(r, 0.56, 0.38), maxf(1.6, ms * 0.04), 0.5)
	_lamp(ci, _u(r, 0.86, 0.38), maxf(1.4, ms * 0.035), Pal.heat(0.75))


# ---------------------------------------------------------------- SV-122: survey data store
# the survey data store: the roll plotter on top with a contour map coming off it, the
# disk shelves of hot-swap drives with their activity lamps, the tape library slot, the
# controller with its readout
static func survey_log(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r, 0.06, 0.2, 0.94, 0.95)
	R(ci, sub(r, 0.04, 0.12, 0.96, 0.2), 0.58)
	O(ci, _u(r, 0.12, 0.16), maxf(1.6, ms * 0.03), 0.5)
	O(ci, _u(r, 0.88, 0.16), maxf(1.6, ms * 0.03), 0.5)
	var mp := sub(r, 0.14, 0.0, 0.86, 0.12)
	R(ci, mp, 0.4)
	var cc := mp.get_center() + Vector2(mp.size.x * 0.1, 0)
	for k in 3:
		_ell(ci, cc, mp.size.x * (0.12 + k * 0.09), mp.size.y * (0.2 + k * 0.12), 0.3)
	L(ci, mp.position + Vector2(2, mp.size.y * 0.7), mp.position + Vector2(mp.size.x * 0.3, mp.size.y * 0.3), 0.35)
	var ns := clampi(int(b.size.y * 0.55 / 14.0), 2, 6)
	for i in ns:
		var s := sub(r, 0.1, 0.24 + i * 0.5 / ns, 0.9, 0.24 + (i + 1) * 0.5 / ns - 0.015)
		R(ci, s, 0.48)
		var nd := clampi(int(s.size.x / 6.0), 4, 16)
		var dd := PackedVector2Array()
		for k in nd:
			var x: float = s.position.x + (k + 0.5) * s.size.x / nd
			dd.append(Vector2(x - s.size.x / nd * 0.35, s.position.y + 2.0))
			dd.append(Vector2(x - s.size.x / nd * 0.35, s.end.y - 2.0))
		S(ci, dd, 0.3)
		_lamp_row(ci, Rect2(s.position + Vector2(0, s.size.y - 4.0), Vector2(s.size.x, 3.0)), mini(nd, 8), Pal.tint(Pal.FLUID, 0.8), 3)
	var tl := sub(r, 0.1, 0.78, 0.6, 0.9)
	R(ci, tl, 0.5)
	L(ci, _u(r, 0.15, 0.84), _u(r, 0.55, 0.84), 0.55, 1.5)
	E.Rc(ci, sub(r, 0.66, 0.79, 0.88, 0.85), Pal.tint(Pal.AIR, 0.6), 1.0)


# ---------------------------------------------------------------- PT-34: control rod drive cabinet
# the patrol ship reactor's rod drive cabinet: a rod position column per rod, the stepper
# drive cards, the two scram breakers with their trip lamps, the key switch
static func crd_cab(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.03, 0.06, 0.97, 0.93)
	var n := clampi(int(r.size.x * 0.56 / 8.0), 6, 16)
	for k in n:
		var x: float = 0.06 + (k + 0.5) * 0.56 / n
		var col := sub(r, x - 0.012, 0.12, x + 0.012, 0.62)
		R(ci, col, 0.4)
		var lv: float = 0.55 + 0.35 * fposmod(k * 0.43, 1.0)
		hatch(ci, Rect2(col.position + Vector2(0, col.size.y * (1.0 - lv)), Vector2(col.size.x, col.size.y * lv)), 2.0, false, 0.40, 30)
		_lamp(ci, _u(r, x, 0.7), 1.6, Pal.tint(Pal.FLUID, 0.8))
	var cards := PackedVector2Array()
	for k in n:
		var x: float = 0.06 + (k + 0.5) * 0.56 / n
		cards.append(_u(r, x, 0.76))
		cards.append(_u(r, x, 0.88))
	S(ci, cards, 0.3, 1.4)
	for k in 2:
		var br := sub(r, 0.66 + k * 0.14, 0.14, 0.78 + k * 0.14, 0.62)
		R(ci, br, 0.55)
		E.breaker(ci, Rect2(br.position + Vector2(2, br.size.y * 0.3), Vector2(br.size.x - 4, br.size.y * 0.3)), true, 0.5)
		_lamp(ci, br.position + Vector2(br.size.x * 0.5, br.size.y * 0.15), maxf(1.8, ms * 0.06), Pal.heat(0.9))
	var kc := _u(r, 0.8, 0.8)
	O(ci, kc, maxf(2.0, ms * 0.07), 0.55)
	L(ci, kc - Vector2(0, ms * 0.04), kc + Vector2(0, ms * 0.04), 0.6, 1.3)


# ---------------------------------------------------------------- PT-34: crypto rack
# the crypto equipment, red/black separated: the black-side units (network), a red line
# across, the red-side units (keypad, display), the key fill port with its cap on a chain,
# the guarded zeroize button, the shielded door mesh and tamper seals
static func crypto_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r)
	E.Rc(ci, Rect2(_u(r, 0.06, 0.47), Vector2(b.size.x, 1.2)), Pal.heat(0.6), 1.0)
	for k in 2:
		var u := sub(r, 0.1, 0.08 + k * 0.17, 0.9, 0.22 + k * 0.17)
		R(ci, u, 0.48)
		for j in 4:
			R(ci, Rect2(u.position + Vector2(u.size.x * (0.45 + j * 0.12), u.size.y * 0.3), Vector2(u.size.x * 0.08, u.size.y * 0.4)), 0.42)
		_lamp(ci, u.position + Vector2(u.size.x * 0.12, u.size.y * 0.5), 1.8, Pal.tint(Pal.FLUID, 0.8))
	var ru := sub(r, 0.1, 0.52, 0.9, 0.8)
	R(ci, ru, 0.52)
	E.Rc(ci, sub(r, 0.14, 0.56, 0.5, 0.63), Pal.tint(Pal.AIR, 0.6), 1.0)
	var kp := PackedVector2Array()
	for row in 3:
		for c in 3:
			kp.append(_u(r, 0.18 + c * 0.1, 0.67 + row * 0.04))
	for q in kp:
		D(ci, q, 0.9, 0.5)
	var fp := _u(r, 0.68, 0.62)
	O(ci, fp, maxf(2.0, ms * 0.06), 0.58)
	O(ci, fp, maxf(1.0, ms * 0.025), 0.45)
	_pu(ci, r, [Vector2(0.72, 0.62), Vector2(0.8, 0.66), Vector2(0.78, 0.72)], 0.3)
	var zb := _u(r, 0.72, 0.74)
	A(ci, zb, maxf(2.2, ms * 0.06), PI, TAU, 0.55, 1.2)
	_lamp(ci, zb, maxf(1.6, ms * 0.045), Pal.heat(0.9))
	hatch(ci, sub(r, 0.12, 0.84, 0.88, 0.92), 2.4, true, 0.25, 40)
	hatch(ci, sub(r, 0.12, 0.84, 0.88, 0.92), 2.4, false, 0.25, 10)
	for x in [0.08, 0.92]:
		R(ci, Rect2(_u(r, x, 0.3) - Vector2(1.5, 3.0), Vector2(3.0, 6.0)), 0.45)


# ---------------------------------------------------------------- HV power distribution cabinet (FR-26, M-14)
# a metal-clad switchgear panel: the relay compartment (protection relay screen, meters,
# lamps), the breaker compartment (racking slot, ON/OFF flag, spring indicator), the cable
# compartment window (terminations with stress cones), the single-line mimic and the earth
# switch handle, the HV warning sign
static func hv_switchgear(ci: CanvasItem, r: Rect2) -> void:
	# a line-up when there is room (M-14's 1.9 m: three panels side by side, each its own
	# meters, breaker truck and cable box, a common busbar chamber over them); one panel else
	var n := clampi(int(r.size.x / (0.6 * M)), 1, 5) if r.size.x >= 1.7 * M else 1
	if n == 1:
		_hv_panel(ci, r)
		return
	var bb := sub(r, 0.02, 0.0, 0.98, 0.06)
	R(ci, bb, 0.55)
	L(ci, bb.position + Vector2(2, bb.size.y * 0.5), bb.end - Vector2(2, bb.size.y * 0.5), 0.5, 1.6)
	var pw: float = r.size.x / n
	for i in n:
		_hv_panel(ci, Rect2(r.position + Vector2(i * pw, r.size.y * 0.06), Vector2(pw, r.size.y * 0.94)))


static func _hv_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var rc := sub(r, 0.1, 0.07, 0.9, 0.3)
	R(ci, rc, 0.5)
	E.Rc(ci, sub(r, 0.14, 0.1, 0.46, 0.2), Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 2:
		E.gauge(ci, _u(r, 0.6 + k * 0.18, 0.15), maxf(2.5, ms * 0.07), 0.5)
	_lamp_row(ci, sub(r, 0.14, 0.23, 0.6, 0.27), 4, Pal.tint(Pal.FLUID, 0.8), 4)
	var bc := sub(r, 0.1, 0.34, 0.9, 0.62)
	R(ci, bc, 0.55)
	R(ci, sub(r, 0.44, 0.4, 0.56, 0.44), 0.5)
	var fl := sub(r, 0.18, 0.48, 0.34, 0.56)
	R(ci, fl, 0.5)
	hatch(ci, fl.grow(-1.0), 2.0, false, 0.45, 30)
	O(ci, _u(r, 0.72, 0.52), maxf(2.0, ms * 0.05), 0.5)
	L(ci, _u(r, 0.72, 0.52), _u(r, 0.75, 0.49), 0.5)
	# spring-charged flag, operation counter, the charging-handle socket, shutter seams
	E.Rc(ci, sub(r, 0.38, 0.48, 0.48, 0.52), Pal.tint(Pal.FLUID, 0.7), 1.0)
	var oc := sub(r, 0.52, 0.48, 0.64, 0.53)
	R(ci, oc, 0.45)
	hatch(ci, oc.grow(-0.8), 2.0, true, 0.3, 6)
	O(ci, _u(r, 0.26, 0.42), maxf(1.4, ms * 0.035), 0.5)
	for y in [0.575, 0.6]:
		L(ci, _u(r, 0.14, y), _u(r, 0.86, y), 0.22)
	for k in 4:
		O(ci, _u(r, 0.66 + k * 0.06, 0.25), maxf(1.0, ms * 0.022), 0.45)
	var cw := sub(r, 0.2, 0.68, 0.8, 0.92)
	R(ci, cw, 0.5)
	for k in 3:
		var x: float = 0.3 + k * 0.2
		L(ci, _u(r, x, 0.68), _u(r, x, 0.78), 0.55, 1.4)
		_pu(ci, r, [Vector2(x - 0.03, 0.82), Vector2(x, 0.78), Vector2(x + 0.03, 0.82), Vector2(x - 0.03, 0.82)], 0.5)
		L(ci, _u(r, x, 0.82), _u(r, x, 0.92), 0.5, 1.6)
	var ml := PackedVector2Array([_u(r, 0.93, 0.08), _u(r, 0.93, 0.92)])
	S(ci, ml, 0.3)
	D(ci, _u(r, 0.93, 0.48), 1.2, 0.5)
	var wt := _u(r, 0.82, 0.76)
	var ws: float = maxf(3.0, ms * 0.07)
	P(ci, PackedVector2Array([wt + Vector2(0, -ws), wt + Vector2(ws, ws * 0.8), wt + Vector2(-ws, ws * 0.8), wt + Vector2(0, -ws)]), 0.6)
	E.Rc(ci, Rect2(wt - Vector2(ws * 0.25, ws * 0.1), Vector2(ws * 0.5, ws * 0.6)), Pal.heat(0.7), 1.0)


# ---------------------------------------------------------------- gas detector (FL-116, FR-26, MY-48)
# the detection controller where there is room (channel bargraphs, the alarm beacon and
# horn on top, a detector head beside it on its conduit), the detector head alone when small
# (sinter grille, the lamp ring, its junction box)
static func gas_detector(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	if ms < 44.0:
		_gas_head(ci, sub(r, 0.15, 0.05, 0.85, 0.95))
		return
	var b := _carcass(ci, r, 0.06, 0.2, 0.7, 0.95)
	A(ci, _u(r, 0.25, 0.2), b.size.x * 0.14, PI, TAU, 0.55, 1.2)
	E.Rc(ci, Rect2(_u(r, 0.25, 0.2) - Vector2(b.size.x * 0.06, b.size.x * 0.09), Vector2(b.size.x * 0.12, b.size.x * 0.06)), Pal.heat(0.75), 1.0)
	_pu(ci, r, [Vector2(0.48, 0.2), Vector2(0.5, 0.1), Vector2(0.6, 0.06), Vector2(0.6, 0.2)], 0.5)
	var n := 4
	for k in n:
		var ch := sub(r, 0.1 + k * 0.145, 0.26, 0.21 + k * 0.145, 0.62)
		R(ci, ch, 0.45)
		var lv: float = 0.2 + 0.5 * fposmod(k * 0.41, 1.0)
		hatch(ci, Rect2(ch.position + Vector2(1.5, ch.size.y * (1.0 - lv)), Vector2(ch.size.x - 3.0, ch.size.y * lv - 1.5)), 2.0, false, 0.40, 30)
		L(ci, ch.position + Vector2(0, ch.size.y * 0.3), Vector2(ch.end.x, ch.position.y + ch.size.y * 0.3), 0.4)
		_lamp(ci, Vector2(ch.get_center().x, ch.end.y + 4.0), 1.8, Pal.heat(0.85) if k == 2 else Pal.tint(Pal.FLUID, 0.8))
	E.Rc(ci, sub(r, 0.1, 0.72, 0.5, 0.8), Pal.tint(Pal.AIR, 0.6), 1.0)
	for x in [0.56, 0.63]:
		O(ci, _u(r, x, 0.76), maxf(1.6, ms * 0.04), 0.5)
	_pu(ci, r, [Vector2(0.7, 0.86), Vector2(0.84, 0.86), Vector2(0.84, 0.6)], 0.45, 1.3)
	_gas_head(ci, sub(r, 0.74, 0.22, 0.96, 0.6))


static func _gas_head(ci: CanvasItem, r0: Rect2) -> void:
	# kept no wider than 0.8 of its height so a wide box still gets an upright head
	var r := r0
	if r0.size.x > r0.size.y * 0.8:
		r = Rect2(r0.get_center().x - r0.size.y * 0.4, r0.position.y, r0.size.y * 0.8, r0.size.y)
	var ms := minf(r.size.x, r.size.y)
	var jb := sub(r, 0.1, 0.05, 0.9, 0.45)
	R(ci, jb, 0.6, 1.2)
	E.corner_bolts(ci, jb, 2.0, 0.45)
	_lamp(ci, jb.get_center(), maxf(1.6, ms * 0.08), Pal.tint(Pal.FLUID, 0.85))
	R(ci, sub(r, 0.3, 0.45, 0.7, 0.55), 0.55)
	R(ci, sub(r, 0.22, 0.55, 0.78, 0.82), 0.58)
	hatch(ci, sub(r, 0.26, 0.6, 0.74, 0.8), 2.0, true, 0.3, 20)
	L(ci, _u(r, 0.25, 0.86), _u(r, 0.75, 0.86), 0.45)
	L(ci, _u(r, 0.5, 0.05), _u(r, 0.5, 0.0), 0.5, 1.4)


# ---------------------------------------------------------------- BL-88: herbarium cabinet
# a herbarium case: the glazed top door showing a pressed fern on its mounting sheet (label,
# tape straps), the stack of shallow specimen drawers with their card holders, the
# desiccant tray, the gasketed seam
static func herbarium(ci: CanvasItem, r: Rect2) -> void:
	_carcass(ci, r)
	var gl := sub(r, 0.12, 0.07, 0.88, 0.45)
	R(ci, gl, 0.55)
	L(ci, gl.position + Vector2(3, 3), gl.position + Vector2(gl.size.x * 0.3, 3), 0.25)
	var sh := sub(r, 0.2, 0.1, 0.8, 0.42)
	R(ci, sh, 0.4)
	var st := _u(r, 0.48, 0.38)
	var tip := _u(r, 0.56, 0.14)
	L(ci, st, tip, 0.5)
	var leaf := PackedVector2Array()
	for k in 7:
		var t: float = (k + 1) / 8.0
		var c: Vector2 = st.lerp(tip, t)
		var ln: float = r.size.x * 0.13 * (1.0 - t * 0.7)
		leaf.append(c)
		leaf.append(c + Vector2(-ln, ln * 0.35))
		leaf.append(c)
		leaf.append(c + Vector2(ln, -ln * 0.05))
	S(ci, leaf, 0.45)
	R(ci, sub(r, 0.6, 0.34, 0.77, 0.4), 0.4)
	for y in [0.22, 0.32]:
		L(ci, _u(r, 0.42, y), _u(r, 0.54, y), 0.3, 1.5)
	var n := 6
	for k in n:
		var y0: float = 0.48 + k * 0.07
		R(ci, sub(r, 0.12, y0, 0.88, y0 + 0.06), 0.45)
		R(ci, sub(r, 0.42, y0 + 0.015, 0.58, y0 + 0.045), 0.4)
	E.Rc(ci, sub(r, 0.14, 0.9, 0.86, 0.93), Pal.tint(Pal.FLUID, 0.35), 1.0)


# ---------------------------------------------------------------- BL-88: garden tool locker
# an open garden-tool locker: pegboard back, the rake, spade, hoe and loppers on their
# hooks, the watering can and the coiled hose on the floor shelf, the seed-tray shelf
static func garden_locker(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := sub(r, 0.06, 0.04, 0.94, 0.96)
	R(ci, b, 0.62, 1.2)
	var pegs := PackedVector2Array()
	for row in 8:
		for c in 5:
			pegs.append(_u(r, 0.16 + c * 0.17, 0.1 + row * 0.07))
	for q in pegs:
		D(ci, q, 0.6, 0.25)
	L(ci, _u(r, 0.06, 0.66), _u(r, 0.94, 0.66), 0.55, 1.3)
	# rake
	L(ci, _u(r, 0.2, 0.1), _u(r, 0.2, 0.6), 0.55, 1.3)
	L(ci, _u(r, 0.12, 0.6), _u(r, 0.28, 0.6), 0.55, 1.3)
	for k in 5:
		L(ci, _u(r, 0.13 + k * 0.035, 0.6), _u(r, 0.13 + k * 0.035, 0.64), 0.45)
	# spade
	L(ci, _u(r, 0.4, 0.08), _u(r, 0.4, 0.46), 0.55, 1.3)
	_pu(ci, r, [Vector2(0.36, 0.08), Vector2(0.44, 0.08)], 0.55, 1.3)
	_pu(ci, r, [Vector2(0.35, 0.46), Vector2(0.45, 0.46), Vector2(0.45, 0.58), Vector2(0.4, 0.63), Vector2(0.35, 0.58)], 0.55, 1.0, true)
	# hoe
	L(ci, _u(r, 0.6, 0.08), _u(r, 0.6, 0.6), 0.55, 1.3)
	_pu(ci, r, [Vector2(0.6, 0.58), Vector2(0.68, 0.6), Vector2(0.68, 0.64)], 0.55, 1.3)
	# loppers
	L(ci, _u(r, 0.76, 0.12), _u(r, 0.84, 0.36), 0.5, 1.3)
	L(ci, _u(r, 0.88, 0.12), _u(r, 0.8, 0.36), 0.5, 1.3)
	D(ci, _u(r, 0.82, 0.24), 1.0, 0.55)
	# watering can, hose reel
	_pu(ci, r, [Vector2(0.14, 0.94), Vector2(0.14, 0.8), Vector2(0.36, 0.8), Vector2(0.36, 0.94)], 0.55)
	A(ci, _u(r, 0.25, 0.8), r.size.x * 0.07, PI, TAU, 0.5)
	L(ci, _u(r, 0.36, 0.84), _u(r, 0.46, 0.74), 0.5, 1.2)
	E.Rc(ci, sub(r, 0.15, 0.86, 0.35, 0.93), Pal.tint(Pal.FLUID, 0.3), 1.0)
	var hc := _u(r, 0.7, 0.83)
	for k in 3:
		O(ci, hc, ms * (0.08 + k * 0.035), 0.4)
	D(ci, hc, 1.2, 0.55)


# ---------------------------------------------------------------- DR-150: chemical store
# the mud-chemical store: the vented cabinet (louvres, exhaust duct out the top), the door
# open to show its shelves of jerrycans and acid bottles, the hazard diamonds, the spill
# sump with its grating
static func chem_store(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.08, 0.94, 0.95)
	_pu(ci, r, [Vector2(0.7, 0.08), Vector2(0.7, 0.0)], 0.5, 1.5)
	_pu(ci, r, [Vector2(0.82, 0.08), Vector2(0.82, 0.0)], 0.5, 1.5)
	E.louvres(ci, sub(r, 0.12, 0.11, 0.5, 0.18), 0.3)
	L(ci, _u(r, 0.5, 0.08), _u(r, 0.5, 0.95), 0.45)
	for y in [0.42, 0.68]:
		L(ci, _u(r, 0.06, y), _u(r, 0.5, y), 0.5, 1.3)
	for k in 2:
		var x0: float = 0.1 + k * 0.19
		_pu(ci, r, [Vector2(x0, 0.41), Vector2(x0, 0.27), Vector2(x0 + 0.04, 0.24), Vector2(x0 + 0.15, 0.24), Vector2(x0 + 0.15, 0.41)], 0.5)
		R(ci, sub(r, x0 + 0.02, 0.21, x0 + 0.06, 0.24), 0.5)
	for k in 3:
		var x0: float = 0.09 + k * 0.13
		_pu(ci, r, [Vector2(x0, 0.67), Vector2(x0, 0.56), Vector2(x0 + 0.03, 0.52), Vector2(x0 + 0.03, 0.48), Vector2(x0 + 0.07, 0.48), Vector2(x0 + 0.07, 0.52), Vector2(x0 + 0.1, 0.56), Vector2(x0 + 0.1, 0.67)], 0.48)
	for q in [Vector2(0.72, 0.32), Vector2(0.72, 0.56)]:
		var c := _u(r, q.x, q.y)
		var hs: float = maxf(3.0, ms * 0.12)
		P(ci, PackedVector2Array([c + Vector2(0, -hs), c + Vector2(hs, 0), c + Vector2(0, hs), c + Vector2(-hs, 0), c + Vector2(0, -hs)]), 0.58)
		E.Rc(ci, Rect2(c - Vector2(hs, hs) * 0.3, Vector2(hs, hs) * 0.6), Pal.heat(0.7), 1.0)
	L(ci, _u(r, 0.56, 0.44), _u(r, 0.56, 0.54), 0.6, 1.5)
	var sp := sub(r, 0.08, 0.76, 0.92, 0.93)
	R(ci, sp, 0.5)
	hatch(ci, Rect2(sp.position + Vector2(2, 2), Vector2(sp.size.x - 4, sp.size.y * 0.4)), 3.0, true, 0.3, 40)
	E.Rc(ci, Rect2(sp.position + Vector2(2, sp.size.y * 0.65), Vector2(sp.size.x - 4, sp.size.y * 0.3)), Pal.tint(Pal.FLUID, 0.25), 1.0)


# ---------------------------------------------------------------- DR-150: core sample cabinet
# the core store: slide-out racks of core boxes, each box's channels holding the core
# lengths (the breaks between them), depth tags, one box pulled out
static func core_store(ci: CanvasItem, r: Rect2) -> void:
	_carcass(ci, r)
	var n := 7
	for k in n:
		var y0: float = 0.07 + k * 0.124
		var out: float = 0.06 if k == 2 else 0.0
		var bx := sub(r, 0.1 - out, y0, 0.9 - out, y0 + 0.11)
		R(ci, bx, 0.5)
		var segs := PackedVector2Array()
		for c in 2:
			var cy: float = bx.position.y + bx.size.y * (0.32 + c * 0.38)
			var x: float = bx.position.x + 2.0
			var j := 0
			while x < bx.end.x - 3.0:
				var ln: float = minf(bx.size.x * (0.14 + 0.18 * fposmod((k * 3 + c * 5 + j) * 0.37, 1.0)), bx.end.x - 3.0 - x)
				segs.append(Vector2(x, cy - 1.2))
				segs.append(Vector2(x + ln, cy - 1.2))
				segs.append(Vector2(x, cy + 1.2))
				segs.append(Vector2(x + ln, cy + 1.2))
				x += ln + 1.5
				j += 1
		S(ci, segs, 0.42)
		R(ci, Rect2(Vector2(bx.end.x - bx.size.x * 0.14, bx.position.y - 1.0), Vector2(bx.size.x * 0.12, 3.0)), 0.5)
	L(ci, _u(r, 0.04, 0.38), _u(r, 0.04, 0.44), 0.55, 1.4)


# ---------------------------------------------------------------- DR-150: drill tool cabinet
# the drill-floor tool cabinet: the pipe wrenches and chain tong on the back board, the
# tricone bit and the thread protectors on the shelf, the tong dies in their tray, the
# thread dope bucket with its brush
static func drill_tools(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	for k in 3:
		var x: float = 0.18 + k * 0.17
		var ln: float = 0.22 + k * 0.05
		L(ci, _u(r, x, 0.08), _u(r, x, 0.08 + ln), 0.58, 1.6)
		_pu(ci, r, [Vector2(x - 0.04, 0.08 + ln), Vector2(x + 0.05, 0.08 + ln), Vector2(x + 0.05, 0.12 + ln), Vector2(x - 0.02, 0.12 + ln)], 0.55)
	var cs := PackedVector2Array()
	for k in 9:
		cs.append(_u(r, 0.76 + (0.03 if k % 2 == 0 else -0.03), 0.08 + k * 0.04))
	P(ci, cs, 0.45, 1.3)
	L(ci, _u(r, 0.06, 0.48), _u(r, 0.94, 0.48), 0.55, 1.4)
	var bc := _u(r, 0.3, 0.38)
	var br: float = ms * 0.12
	_pu(ci, r, [Vector2(0.24, 0.47), Vector2(0.24, 0.4), Vector2(0.36, 0.4), Vector2(0.36, 0.47)], 0.5)
	for a in [-0.6, 0.0, 0.6]:
		O(ci, bc + Vector2(sin(a) * br * 0.7, -br * 0.4 + absf(a) * br * 0.3), br * 0.38, 0.5)
	for k in 2:
		var x: float = 0.56 + k * 0.17
		R(ci, sub(r, x, 0.36, x + 0.12, 0.48), 0.5)
		hatch(ci, sub(r, x + 0.01, 0.37, x + 0.11, 0.47), 2.0, false, 0.3, 8)
	L(ci, _u(r, 0.06, 0.72), _u(r, 0.94, 0.72), 0.55, 1.4)
	var tr := sub(r, 0.12, 0.62, 0.5, 0.72)
	R(ci, tr, 0.5)
	for k in 5:
		R(ci, sub(r, 0.14 + k * 0.07, 0.64, 0.19 + k * 0.07, 0.7), 0.42)
	_pu(ci, r, [Vector2(0.6, 0.72), Vector2(0.62, 0.58), Vector2(0.84, 0.58), Vector2(0.86, 0.72)], 0.55)
	L(ci, _u(r, 0.8, 0.58), _u(r, 0.88, 0.5), 0.5, 1.3)
	E.louvres(ci, sub(r, 0.12, 0.78, 0.88, 0.92), 0.25)


# ---------------------------------------------------------------- DR-150: well log archive
# the well-history archive: pigeonholes of rolled log charts (each roll's end), a log strip
# hanging out with its curve, the fire-safe lower half with its dial and handle
static func well_logs(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	for row in 4:
		for c in 4:
			var cell := sub(r, 0.1 + c * 0.2, 0.07 + row * 0.1, 0.29 + c * 0.2, 0.16 + row * 0.1)
			R(ci, cell, 0.35)
			if (row * 4 + c) % 5 != 3:
				O(ci, cell.get_center(), minf(cell.size.x, cell.size.y) * 0.32, 0.5)
				D(ci, cell.get_center(), 0.8, 0.45)
	var lg := sub(r, 0.52, 0.27, 0.66, 0.56)
	R(ci, lg, 0.45)
	var cv := PackedVector2Array()
	for k in 12:
		var t: float = k / 11.0
		cv.append(Vector2(lg.position.x + lg.size.x * (0.5 + 0.35 * sin(t * 13.0 + 1.0) * (0.4 + 0.6 * fposmod(t * 3.7, 1.0))), lg.position.y + lg.size.y * t))
	P(ci, cv, 0.45)
	var sf := sub(r, 0.1, 0.5, 0.9, 0.92)
	R(ci, sf, 0.6, 1.3)
	R(ci, sf.grow(-3.0), 0.3)
	var dc := _u(r, 0.42, 0.7)
	O(ci, dc, ms * 0.14, 0.55)
	O(ci, dc, ms * 0.05, 0.45)
	var tk := PackedVector2Array()
	for k in 12:
		var a: float = TAU * k / 12.0
		tk.append(dc + Vector2.from_angle(a) * ms * 0.12)
		tk.append(dc + Vector2.from_angle(a) * ms * 0.14)
	S(ci, tk, 0.35)
	L(ci, _u(r, 0.7, 0.62), _u(r, 0.7, 0.78), 0.58, 2.0)
	E.corner_bolts(ci, sf, 3.0, 0.4)


# ---------------------------------------------------------------- EV-55: calibration light source
# the spectrometer's calibration source: the integrating sphere (its baffle, exit port, the
# fibre out), the halogen lamp house with its fins feeding it, the filter wheel, the
# constant-current supply with its readout
static func ev_calib(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var sc := _u(r, 0.5, 0.36)
	var sr: float = ms * 0.24
	O(ci, sc, sr, 0.6, 1.3)
	O(ci, sc, sr * 0.88, 0.25)
	L(ci, sc + Vector2(-sr * 0.2, -sr * 0.5), sc + Vector2(-sr * 0.2, sr * 0.1), 0.4)
	R(ci, Rect2(sc + Vector2(sr * 0.85, -3.0), Vector2(5.0, 6.0)), 0.55)
	P(ci, PackedVector2Array([sc + Vector2(sr + 5.0, 0), _u(r, 0.9, 0.36), _u(r, 0.9, 0.04), _u(r, 0.96, 0.0)]), 0.5, 1.3)
	var lh := Rect2(sc + Vector2(-sr * 2.0, -sr * 0.35), Vector2(sr * 0.8, sr * 0.7))
	R(ci, lh, 0.55)
	var fins := PackedVector2Array()
	for k in 4:
		var x: float = lh.position.x + (k + 0.5) * lh.size.x / 4.0
		fins.append(Vector2(x, lh.position.y - 3.0))
		fins.append(Vector2(x, lh.position.y))
	S(ci, fins, 0.45)
	E.Rc(ci, Rect2(lh.get_center() - Vector2(2, 2), Vector2(4, 4)), Pal.heat(0.85), 1.0)
	var fw := sc + Vector2(-sr * 1.1, 0)
	O(ci, fw, sr * 0.3, 0.5)
	for k in 4:
		D(ci, fw + Vector2.from_angle(TAU * k / 4.0 + 0.4) * sr * 0.18, 0.8, 0.45)
	var ps := sub(r, 0.12, 0.66, 0.88, 0.9)
	R(ci, ps, 0.5)
	E.Rc(ci, sub(r, 0.16, 0.7, 0.5, 0.77), Pal.tint(Pal.AIR, 0.6), 1.0)
	O(ci, _u(r, 0.66, 0.78), maxf(2.0, ms * 0.05), 0.5)
	_lamp(ci, _u(r, 0.8, 0.73), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	E.louvres(ci, sub(r, 0.16, 0.8, 0.5, 0.88), 0.25)


# ---------------------------------------------------------------- DC-DC converter (EV-55 and nine more)
# a DC-DC converter: finned heat-sink case, the two magnetics (toroids) and the filter
# capacitors seen through the cover cut-out, input and output terminal blocks, status lamp;
# small ones are a sealed brick on its base plate
static func dcdc(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	if ms < 46.0:
		_dcdc_brick(ci, r)
		return
	var b := sub(r, 0.06, 0.12, 0.94, 0.88)
	R(ci, b, 0.62, 1.2)
	hatch(ci, sub(r, 0.06, 0.02, 0.94, 0.12), 2.6, true, 0.35, 30)
	var win := sub(r, 0.14, 0.22, 0.86, 0.62)
	R(ci, win, 0.42)
	for x in [0.32, 0.56]:
		var c := _u(r, x, 0.42)
		var tr: float = minf(win.size.y * 0.36, win.size.x * 0.14)
		O(ci, c, tr, 0.55)
		O(ci, c, tr * 0.45, 0.4)
	for x in [0.72, 0.8]:
		var c2 := _u(r, x, 0.42)
		R(ci, Rect2(c2 - Vector2(1.8, win.size.y * 0.3), Vector2(3.6, win.size.y * 0.6)), 0.45)
	for x in [0.12, 0.88]:
		var tb := Rect2(_u(r, x, 0.7) - Vector2(ms * 0.08, ms * 0.05), Vector2(ms * 0.16, ms * 0.1))
		R(ci, tb, 0.55)
		D(ci, tb.get_center() - Vector2(tb.size.x * 0.22, 0), 0.9, 0.55)
		D(ci, tb.get_center() + Vector2(tb.size.x * 0.22, 0), 0.9, 0.55)
	_lamp(ci, _u(r, 0.5, 0.72), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.85))
	R(ci, sub(r, 0.02, 0.88, 0.98, 0.96), 0.5)


# ---------------------------------------------------------------- FX-70: liquid helium distribution box
# the cryogenic distribution box: the vacuum-jacketed can, its three bayonet ports (from
# the cold box, to the two coil sets), the long-stemmed cryogenic valves with handwheels on
# top, the pressure gauges, the burst disc, the frost line
static func cryo_cdb(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var can := sub(r, 0.12, 0.3, 0.88, 0.9)
	R(ci, can, 0.62, 1.3)
	R(ci, can.grow(-3.0), 0.3)
	E.Rc(ci, can.grow(-3.0), Pal.tint(Pal.AIR, 0.22), 1.0)
	for k in 3:
		var x: float = 0.26 + k * 0.24
		L(ci, _u(r, x, 0.3), _u(r, x, 0.1), 0.5, 1.2)
		L(ci, _u(r, x, 0.1), _u(r, x, 0.06), 0.55)
		var wc := _u(r, x, 0.06)
		E.wheel(ci, wc, maxf(2.5, ms * 0.07), 0.55)
		R(ci, sub(r, x - 0.04, 0.2, x + 0.04, 0.3), 0.5)
	for k in 3:
		var y: float = 0.45 + k * 0.15
		var bp := _u(r, 0.88, y)
		R(ci, Rect2(bp + Vector2(0, -3.5), Vector2(r.size.x * 0.06, 7.0)), 0.58)
		L(ci, bp + Vector2(r.size.x * 0.06, 0), Vector2(r.end.x, bp.y), 0.55, 1.6)
	E.gauge(ci, _u(r, 0.3, 0.5), maxf(2.5, ms * 0.08), 0.5)
	E.gauge(ci, _u(r, 0.3, 0.68), maxf(2.5, ms * 0.08), 0.5)
	var bd := _u(r, 0.6, 0.6)
	O(ci, bd, maxf(2.0, ms * 0.06), 0.55)
	L(ci, bd - Vector2(ms * 0.04, ms * 0.04), bd + Vector2(ms * 0.04, ms * 0.04), 0.45)
	E.Rc(ci, Rect2(_u(r, 0.12, 0.84), Vector2(can.size.x, 1.0)), Pal.tint(Pal.AIR, 0.7), 1.0)
	R(ci, sub(r, 0.08, 0.9, 0.92, 0.97), 0.5)


# ---------------------------------------------------------------- FX-70 / HG-170: cryogenic spares
# the cryo spares locker: a small dewar flask with its neck and cap, a spare cold head in its
# cradle, bagged seal kits on hooks, the labelled bin shelf
static func cryo_spares(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	L(ci, _u(r, 0.06, 0.5), _u(r, 0.94, 0.5), 0.55, 1.3)
	_pu(ci, r, [Vector2(0.14, 0.49), Vector2(0.14, 0.22), Vector2(0.2, 0.16), Vector2(0.26, 0.16), Vector2(0.26, 0.1), Vector2(0.34, 0.1), Vector2(0.34, 0.16), Vector2(0.4, 0.16), Vector2(0.46, 0.22), Vector2(0.46, 0.49)], 0.58)
	R(ci, sub(r, 0.25, 0.07, 0.35, 0.1), 0.55)
	_pu(ci, r, [Vector2(0.17, 0.46), Vector2(0.17, 0.24), Vector2(0.43, 0.24), Vector2(0.43, 0.46)], 0.3)
	E.Rc(ci, sub(r, 0.18, 0.36, 0.42, 0.45), Pal.tint(Pal.AIR, 0.3), 1.0)
	var ch := sub(r, 0.56, 0.14, 0.84, 0.46)
	R(ci, sub(r, 0.62, 0.14, 0.78, 0.3), 0.5)
	R(ci, sub(r, 0.66, 0.3, 0.74, 0.44), 0.5)
	E.flange(ci, _u(r, 0.7, 0.44), Vector2.DOWN, ch.size.x * 0.3, 0.5)
	for k in 2:
		var x: float = 0.18 + k * 0.3
		_pu(ci, r, [Vector2(x, 0.54), Vector2(x - 0.07, 0.6), Vector2(x - 0.07, 0.72), Vector2(x + 0.07, 0.72), Vector2(x + 0.07, 0.6), Vector2(x, 0.54)], 0.42)
		O(ci, _u(r, x, 0.66), maxf(1.4, ms * 0.04), 0.4)
	for k in 3:
		var bn := sub(r, 0.1 + k * 0.27, 0.78, 0.33 + k * 0.27, 0.92)
		R(ci, bn, 0.5)
		R(ci, sub(r, 0.15 + k * 0.27, 0.8, 0.27 + k * 0.27, 0.84), 0.35)


# ---------------------------------------------------------------- FX-70: shot data archive
# the discharge-data archive: the drive with a plasma-current trace on its screen (ramp,
# flat-top, the disruption spike), the cartridge shelves numbered by shot, the index drawer
static func shot_archive(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var sc := sub(r, 0.12, 0.07, 0.88, 0.26)
	R(ci, sc, 0.55)
	var q := sc.grow(-2.0)
	var tr := PackedVector2Array([Vector2(q.position.x, q.end.y), Vector2(q.position.x + q.size.x * 0.2, q.position.y + q.size.y * 0.3), Vector2(q.position.x + q.size.x * 0.62, q.position.y + q.size.y * 0.28), Vector2(q.position.x + q.size.x * 0.66, q.position.y), Vector2(q.position.x + q.size.x * 0.7, q.end.y), Vector2(q.end.x, q.end.y)])
	E.Rc(ci, q, Pal.tint(Pal.AIR, 0.25), 1.0)
	P(ci, tr, 0.6)
	for row in 4:
		var y0: float = 0.3 + row * 0.12
		L(ci, _u(r, 0.1, y0 + 0.11), _u(r, 0.9, y0 + 0.11), 0.5, 1.2)
		var segs := PackedVector2Array()
		var n := clampi(int(r.size.x * 0.8 / 4.0), 6, 18)
		for k in n:
			var x: float = 0.11 + (k + 0.5) * 0.78 / n
			var top: float = y0 + 0.02 + 0.015 * float(k % 3)
			segs.append(_u(r, x, top))
			segs.append(_u(r, x, y0 + 0.105))
		S(ci, segs, 0.4, 1.6)
	var dr := sub(r, 0.12, 0.8, 0.88, 0.92)
	R(ci, dr, 0.5)
	R(ci, sub(r, 0.42, 0.83, 0.58, 0.87), 0.45)
	_lamp(ci, _u(r, 0.8, 0.165), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- FX-70: spare current leads
# the spare current-lead crate: the lid propped open, the two HTS current leads (copper
# terminal, the long conductor, the cold end flange, the voltage taps) laid in their foam
# cradles, the desiccant bag and the shock indicator
static func spare_leads(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.08, 0.2, 0.92, 0.96)
	R(ci, bx, 0.62, 1.3)
	_pu(ci, r, [Vector2(0.08, 0.2), Vector2(0.02, 0.02), Vector2(0.86, 0.02), Vector2(0.92, 0.2)], 0.5, 1.2)
	L(ci, _u(r, 0.9, 0.2), _u(r, 0.86, 0.04), 0.4)
	for k in 2:
		var x: float = 0.32 + k * 0.36
		var fm := sub(r, x - 0.12, 0.25, x + 0.12, 0.92)
		R(ci, fm, 0.3)
		R(ci, sub(r, x - 0.06, 0.27, x + 0.06, 0.36), 0.6)
		D(ci, _u(r, x, 0.315), 1.2, 0.6)
		R(ci, sub(r, x - 0.035, 0.36, x + 0.035, 0.82), 0.55)
		for y in [0.48, 0.6, 0.72]:
			D(ci, _u(r, x + 0.05, y), 0.8, 0.45)
		E.flange(ci, _u(r, x, 0.84), Vector2.DOWN, r.size.x * 0.08, 0.55)
		E.Rc(ci, sub(r, x - 0.02, 0.4, x + 0.02, 0.8), Pal.heat(0.35), 1.0)
	R(ci, sub(r, 0.44, 0.5, 0.56, 0.62), 0.4)
	_lamp(ci, _u(r, 0.5, 0.75), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- HG-170: sample gas cylinder cabinet
# the gas-sample cylinder cabinet: two sample cylinders on their straps (valve, cap), the
# regulators and the pigtails to the manifold, the gas detector and the vent duct, the
# window in the door
static func sample_cyl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	_pu(ci, r, [Vector2(0.8, 0.04), Vector2(0.8, 0.0)], 0.5, 1.5)
	for k in 2:
		var x: float = 0.3 + k * 0.36
		var cy := sub(r, x - 0.12, 0.34, x + 0.12, 0.92)
		_pu(ci, r, [Vector2(x - 0.12, 0.92), Vector2(x - 0.12, 0.4), Vector2(x - 0.06, 0.34), Vector2(x + 0.06, 0.34), Vector2(x + 0.12, 0.4), Vector2(x + 0.12, 0.92)], 0.58, 1.2)
		R(ci, sub(r, x - 0.03, 0.28, x + 0.03, 0.34), 0.55)
		E.wheel(ci, _u(r, x, 0.26), maxf(2.0, ms * 0.05), 0.5)
		for y in [0.52, 0.76]:
			L(ci, _u(r, 0.08, y), _u(r, 0.92, y), 0.4, 1.3)
		E.Rc(ci, Rect2(cy.position + Vector2(2, cy.size.y * 0.15), Vector2(cy.size.x - 4, 1.2)), Pal.tint(Pal.AIR, 0.6), 1.0)
		O(ci, _u(r, x, 0.17), maxf(2.0, ms * 0.05), 0.5)
		_pu(ci, r, [Vector2(x, 0.24), Vector2(x, 0.21)], 0.45)
		_pu(ci, r, [Vector2(x + 0.04, 0.15), Vector2(x + 0.1, 0.1), Vector2(0.5, 0.1)], 0.4)
	L(ci, _u(r, 0.2, 0.1), _u(r, 0.8, 0.1), 0.5, 1.3)
	var gd := sub(r, 0.42, 0.18, 0.58, 0.28)
	R(ci, gd, 0.5)
	_lamp(ci, gd.get_center(), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- OB-90: telescope calibration source
# the telescope's arc-lamp unit: a turret of four hollow-cathode lamps (thorium-argon, their
# glass envelopes and electrodes), the shutter in front, the fibre bundle to the telescope,
# the flat-field lamp and the lamp controller with its selector
static func ob_cal(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var tc := _u(r, 0.42, 0.3)
	var tr: float = ms * 0.3
	O(ci, tc, tr, 0.5)
	for k in 4:
		var c: Vector2 = tc + Vector2.from_angle(TAU * k / 4.0 + PI * 0.25) * tr * 0.6
		O(ci, c, tr * 0.28, 0.55)
		L(ci, c + Vector2(-tr * 0.1, 0), c + Vector2(tr * 0.1, 0), 0.4)
		if k == 0:
			E.Rc(ci, Rect2(c - Vector2(2, 2), Vector2(4, 4)), Pal.tint(Pal.VOLT, 0.85), 1.0)
	D(ci, tc, 1.2, 0.55)
	R(ci, sub(r, 0.74, 0.18, 0.8, 0.42), 0.55)
	P(ci, PackedVector2Array([_u(r, 0.8, 0.3), _u(r, 0.9, 0.3), _u(r, 0.9, 0.0)]), 0.55, 1.6)
	var ff := sub(r, 0.14, 0.58, 0.5, 0.7)
	R(ci, ff, 0.5)
	E.Rc(ci, ff.grow(-2.0), Pal.heat(0.45), 1.0)
	var ct := sub(r, 0.14, 0.76, 0.86, 0.92)
	R(ci, ct, 0.5)
	var sl := _u(r, 0.3, 0.84)
	O(ci, sl, maxf(2.0, ms * 0.06), 0.55)
	L(ci, sl, sl + Vector2.from_angle(-0.8) * maxf(2.0, ms * 0.06), 0.55)
	_lamp_row(ci, sub(r, 0.44, 0.82, 0.82, 0.86), 4, Pal.tint(Pal.VOLT, 0.8), 0)


# ---------------------------------------------------------------- OB-90: star plate archive
# the photographic plate archive: the light box on top with a glass plate on it (its star
# images, the reference marks), the shallow flat drawers below with their label frames, one
# drawer open showing the plates standing in their sleeves
static func plate_archive(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.2, 0.94, 0.95)
	var lb := sub(r, 0.04, 0.12, 0.96, 0.2)
	R(ci, lb, 0.55)
	E.Rc(ci, lb.grow(-1.5), Pal.ink(0.25), 1.0)
	var pl := sub(r, 0.2, 0.0, 0.8, 0.12)
	R(ci, pl, 0.5)
	for i in 14:
		var u: float = fposmod(i * 0.618, 1.0)
		var v: float = fposmod(i * 0.414 + 0.2, 1.0)
		var c := pl.position + Vector2(pl.size.x * (0.06 + u * 0.88), pl.size.y * (0.15 + v * 0.7))
		D(ci, c, 0.6 + 0.6 * float(i % 3 == 0), 0.6)
	for k in 6:
		var y0: float = 0.24 + k * 0.1
		R(ci, sub(r, 0.1, y0, 0.9, y0 + 0.08), 0.45)
		R(ci, sub(r, 0.42, y0 + 0.02, 0.58, y0 + 0.05), 0.4)
		L(ci, _u(r, 0.46, y0 + 0.065), _u(r, 0.54, y0 + 0.065), 0.5, 1.3)
	var od := sub(r, 0.02, 0.85, 0.82, 0.93)
	R(ci, od, 0.5)
	var segs := PackedVector2Array()
	for k in 10:
		var x: float = od.position.x + 4.0 + k * (od.size.x - 8.0) / 10.0
		segs.append(Vector2(x, od.position.y - 3.0))
		segs.append(Vector2(x + 1.0, od.end.y - 1.0))
	S(ci, segs, 0.35)


# ---------------------------------------------------------------- OB-90: spare cell cabinet
# the fireproof spare-cell cabinet: trays of cylindrical cells standing in rows, the trickle
# charger shelf with its lamps, the thermometer strip, the vent and the fire blanket pouch
static func spare_cells(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r)
	R(ci, b.grow(-2.5), 0.3)
	for t in 3:
		var y0: float = 0.1 + t * 0.2
		L(ci, _u(r, 0.1, y0 + 0.17), _u(r, 0.9, y0 + 0.17), 0.55, 1.3)
		var n := clampi(int(r.size.x * 0.76 / 5.0), 5, 14)
		var segs := PackedVector2Array()
		for k in n:
			var x: float = 0.12 + (k + 0.5) * 0.76 / n
			var cw: float = 0.76 / n * 0.35
			segs.append(_u(r, x - cw, y0 + 0.17))
			segs.append(_u(r, x - cw, y0 + 0.06))
			segs.append(_u(r, x + cw, y0 + 0.17))
			segs.append(_u(r, x + cw, y0 + 0.06))
			segs.append(_u(r, x - cw, y0 + 0.06))
			segs.append(_u(r, x + cw, y0 + 0.06))
		S(ci, segs, 0.42)
	var chg := sub(r, 0.12, 0.72, 0.88, 0.8)
	R(ci, chg, 0.5)
	_lamp_row(ci, chg, 5, Pal.tint(Pal.FLUID, 0.85), 4)
	E.Rc(ci, sub(r, 0.86, 0.12, 0.89, 0.6), Pal.tint(Pal.AIR, 0.4), 1.0)
	R(ci, sub(r, 0.12, 0.84, 0.42, 0.93), 0.45)
	E.louvres(ci, sub(r, 0.5, 0.84, 0.88, 0.93), 0.28)


# ---------------------------------------------------------------- DC-84: server spares
# the data centre's spares cabinet: blade servers stacked in their sleeves, a grid of drive
# caddies, memory sticks in their trays, a spare power supply, the ESD wrist-strap jack
static func server_spares(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	for k in 4:
		var bl := sub(r, 0.1, 0.07 + k * 0.065, 0.9, 0.125 + k * 0.065)
		R(ci, bl, 0.48)
		L(ci, bl.position + Vector2(bl.size.x * 0.75, 1.5), Vector2(bl.position.x + bl.size.x * 0.75, bl.end.y - 1.5), 0.35)
		D(ci, bl.position + Vector2(bl.size.x * 0.85, bl.size.y * 0.5), 0.8, 0.55)
	L(ci, _u(r, 0.06, 0.36), _u(r, 0.94, 0.36), 0.55, 1.3)
	for row in 2:
		for c in 5:
			var dc := sub(r, 0.1 + c * 0.16, 0.39 + row * 0.11, 0.24 + c * 0.16, 0.48 + row * 0.11)
			R(ci, dc, 0.45)
			L(ci, dc.position + Vector2(2, dc.size.y * 0.75), Vector2(dc.end.x - 2, dc.position.y + dc.size.y * 0.75), 0.35)
	L(ci, _u(r, 0.06, 0.62), _u(r, 0.94, 0.62), 0.55, 1.3)
	for k in 2:
		var tr := sub(r, 0.1 + k * 0.4, 0.65, 0.46 + k * 0.4, 0.73)
		R(ci, tr, 0.42)
		var segs := PackedVector2Array()
		for j in 6:
			var x: float = tr.position.x + (j + 0.5) * tr.size.x / 6.0
			segs.append(Vector2(x, tr.position.y + 1.5))
			segs.append(Vector2(x, tr.end.y - 1.5))
		S(ci, segs, 0.4)
	var psu := sub(r, 0.1, 0.78, 0.6, 0.92)
	R(ci, psu, 0.5)
	E.fan(ci, psu.position + Vector2(psu.size.y * 0.5 + 2, psu.size.y * 0.5), psu.size.y * 0.38, 5, 0.4)
	L(ci, psu.position + Vector2(psu.size.x * 0.7, psu.size.y * 0.5), Vector2(psu.end.x - 3, psu.get_center().y), 0.5, 1.3)
	var j2 := _u(r, 0.8, 0.85)
	O(ci, j2, maxf(1.6, ms * 0.04), 0.55)
	_pu(ci, r, [Vector2(0.8, 0.88), Vector2(0.78, 0.94), Vector2(0.84, 0.94)], 0.35)


# ---------------------------------------------------------------- FL-116: batch record terminal
# the process ship's batch recorder: the multi-pen chart recorder (paper, three traces), the
# operator screen with the batch table, the label printer with a label curling out, the
# batch-ticket rack, the barcode scanner in its holster
static func batch_log(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var cr := sub(r, 0.1, 0.08, 0.52, 0.5)
	R(ci, cr, 0.55)
	var pp := cr.grow(-3.0)
	for k in 3:
		var tr := PackedVector2Array()
		for j in 10:
			var t: float = j / 9.0
			tr.append(Vector2(pp.position.x + pp.size.x * (0.25 + 0.22 * k + 0.08 * sin(t * 9.0 + k * 2.0)), pp.position.y + pp.size.y * t))
		P(ci, tr, 0.4 + 0.1 * k)
	var hs := PackedVector2Array()
	for j in 5:
		var y: float = pp.position.y + (j + 0.5) * pp.size.y / 5.0
		hs.append(Vector2(pp.position.x, y))
		hs.append(Vector2(pp.end.x, y))
	S(ci, hs, 0.15)
	var sc := sub(r, 0.58, 0.08, 0.9, 0.32)
	R(ci, sc, 0.55)
	E.screen_face(ci, sc.grow(-1.5), 3, 0.35)
	var lp := sub(r, 0.58, 0.38, 0.9, 0.5)
	R(ci, lp, 0.5)
	_pu(ci, r, [Vector2(0.66, 0.5), Vector2(0.66, 0.58), Vector2(0.78, 0.6), Vector2(0.8, 0.5)], 0.4)
	_lamp(ci, _u(r, 0.86, 0.44), maxf(1.4, ms * 0.03), Pal.tint(Pal.FLUID, 0.85))
	for k in 5:
		var x: float = 0.12 + k * 0.08
		R(ci, sub(r, x, 0.58, x + 0.06, 0.74), 0.4)
		L(ci, _u(r, x + 0.01, 0.62), _u(r, x + 0.05, 0.62), 0.3)
	L(ci, _u(r, 0.1, 0.75), _u(r, 0.52, 0.75), 0.55, 1.3)
	R(ci, sub(r, 0.82, 0.62, 0.88, 0.78), 0.5)
	_pu(ci, r, [Vector2(0.8, 0.6), Vector2(0.86, 0.58), Vector2(0.9, 0.62)], 0.5, 1.3)
	E.louvres(ci, sub(r, 0.12, 0.8, 0.88, 0.92), 0.25)


# ---------------------------------------------------------------- GR-7: tool cabinet
# a small wall tool cabinet, both doors open: the shadow board inside (each tool on its
# painted outline: spanners, pliers, screwdrivers, hammer, one outline empty), the door
# racks of bits, the latch and hinges
static func shadow_board(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bd := sub(r, 0.2, 0.06, 0.8, 0.92)
	R(ci, bd, 0.62, 1.2)
	for s in [0, 1]:
		var dx: float = 0.04 if s == 0 else 0.8
		_pu(ci, r, [Vector2(0.2 if s == 0 else 0.8, 0.06), Vector2(dx, 0.1), Vector2(dx, 0.88), Vector2(0.2 if s == 0 else 0.8, 0.92)], 0.55, 1.1)
		for k in 6:
			D(ci, _u(r, dx + (0.08 if s == 0 else 0.08), 0.18 + k * 0.11), 1.0, 0.45)
		D(ci, _u(r, 0.2 if s == 0 else 0.8, 0.2), 1.1, 0.55)
		D(ci, _u(r, 0.2 if s == 0 else 0.8, 0.78), 1.1, 0.55)
	# shadow outlines (faint) with the tools in them
	for k in 3:
		var x: float = 0.3 + k * 0.08
		E.Rc(ci, sub(r, x - 0.015, 0.12, x + 0.015, 0.4 + k * 0.04), Pal.ink(0.18), 1.0)
		L(ci, _u(r, x, 0.14), _u(r, x, 0.38 + k * 0.04), 0.55, 1.4)
		O(ci, _u(r, x, 0.13), maxf(1.4, ms * 0.03), 0.5)
	_pu(ci, r, [Vector2(0.6, 0.12), Vector2(0.62, 0.3), Vector2(0.66, 0.3), Vector2(0.7, 0.12)], 0.5)
	for k in 4:
		var x: float = 0.3 + k * 0.07
		L(ci, _u(r, x, 0.5), _u(r, x, 0.6), 0.6, 2.0)
		L(ci, _u(r, x, 0.6), _u(r, x, 0.72), 0.45)
	E.Rc(ci, sub(r, 0.6, 0.48, 0.74, 0.54), Pal.ink(0.2), 1.0)
	R(ci, sub(r, 0.6, 0.48, 0.74, 0.54), 0.5)
	L(ci, _u(r, 0.67, 0.54), _u(r, 0.67, 0.74), 0.55, 1.4)
	E.Rc(ci, sub(r, 0.3, 0.78, 0.7, 0.84), Pal.heat(0.35), 1.0)
	L(ci, _u(r, 0.2, 0.92), _u(r, 0.8, 0.92), 0.55, 1.4)


# ---------------------------------------------------------------- RO-128: load log terminal
# the ro-ro's load recorder: the deck-plan screen (lanes, the parked vehicles, one lit as
# just loaded), the axle-weight readout, the RFID reader paddle on its coiled lead, the
# ticket printer
static func cargo_log(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var sc := sub(r, 0.1, 0.07, 0.9, 0.48)
	R(ci, sc, 0.55)
	for ln in 3:
		var y0: float = 0.11 + ln * 0.12
		L(ci, _u(r, 0.13, y0 + 0.11), _u(r, 0.87, y0 + 0.11), 0.25)
		for k in 5:
			var x0: float = 0.14 + k * 0.145 + (0.03 if ln == 1 else 0.0)
			if x0 + 0.11 > 0.87:
				continue
			var car := sub(r, x0, y0 + 0.02, x0 + 0.11, y0 + 0.09)
			if ln == 2 and k == 3:
				E.Rc(ci, car, Pal.tint(Pal.FLUID, 0.75), 1.0)
			else:
				R(ci, car, 0.4)
	E.Rc(ci, sub(r, 0.1, 0.53, 0.5, 0.62), Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 4:
		var bar := sub(r, 0.12 + k * 0.09, 0.66, 0.18 + k * 0.09, 0.74)
		hatch(ci, Rect2(bar.position + Vector2(0, bar.size.y * (0.6 - 0.12 * k)), Vector2(bar.size.x, bar.size.y * (0.4 + 0.12 * k))), 2.0, false, 0.40, 30)
		R(ci, bar, 0.35)
	R(ci, sub(r, 0.66, 0.55, 0.78, 0.72), 0.55)
	O(ci, _u(r, 0.72, 0.6), maxf(1.6, ms * 0.04), 0.45)
	var cord := PackedVector2Array()
	for k in 7:
		cord.append(_u(r, 0.72 + (0.025 if k % 2 == 0 else -0.025), 0.72 + k * 0.025))
	P(ci, cord, 0.35)
	var pr := sub(r, 0.1, 0.8, 0.9, 0.92)
	R(ci, pr, 0.5)
	L(ci, _u(r, 0.3, 0.8), _u(r, 0.7, 0.8), 0.6, 1.5)
	_pu(ci, r, [Vector2(0.4, 0.8), Vector2(0.4, 0.76), Vector2(0.58, 0.76), Vector2(0.58, 0.8)], 0.35)


# ---------------------------------------------------------------- ES-112: custody registration
# the custody desk unit: the camera on its gooseneck, the screen with the ID card being
# registered (photo box, lines), the fingerprint pad, the wristband printer with a band
# hanging out, the tamper-seal tag dispenser
static func custody_reg(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.22, 0.94, 0.95)
	_pu(ci, r, [Vector2(0.8, 0.22), Vector2(0.8, 0.12), Vector2(0.72, 0.06)], 0.5, 1.4)
	R(ci, sub(r, 0.62, 0.02, 0.74, 0.1), 0.58)
	O(ci, _u(r, 0.66, 0.06), maxf(1.4, ms * 0.03), 0.55)
	var sc := sub(r, 0.1, 0.26, 0.62, 0.56)
	R(ci, sc, 0.55)
	var cd := sub(r, 0.16, 0.31, 0.56, 0.51)
	E.Rc(ci, cd, Pal.tint(Pal.AIR, 0.55), 1.0)
	R(ci, sub(r, 0.19, 0.34, 0.29, 0.48), 0.45)
	for y in [0.36, 0.41, 0.46]:
		L(ci, _u(r, 0.32, y), _u(r, 0.52, y), 0.35)
	var fp := sub(r, 0.68, 0.3, 0.88, 0.46)
	R(ci, fp, 0.55)
	var fc := fp.get_center()
	for k in 3:
		A(ci, fc + Vector2(0, fp.size.y * 0.15), fp.size.y * (0.12 + k * 0.1), PI * 1.1, PI * 1.9, 0.4)
	_lamp(ci, fp.position + Vector2(fp.size.x * 0.85, 3.0), 1.8, Pal.tint(Pal.FLUID, 0.85))
	var wp := sub(r, 0.1, 0.62, 0.5, 0.74)
	R(ci, wp, 0.5)
	_pu(ci, r, [Vector2(0.2, 0.74), Vector2(0.2, 0.86), Vector2(0.3, 0.88), Vector2(0.32, 0.8)], 0.45, 1.3)
	var sd := sub(r, 0.6, 0.62, 0.88, 0.86)
	R(ci, sd, 0.5)
	for k in 3:
		var t := sub(r, 0.63 + k * 0.08, 0.66, 0.69 + k * 0.08, 0.76)
		R(ci, t, 0.42)
		O(ci, t.position + Vector2(t.size.x * 0.5, 2.5), 1.0, 0.45)
	E.Rc(ci, sub(r, 0.63, 0.78, 0.85, 0.8), Pal.heat(0.6), 1.0)


# ---------------------------------------------------------------- ES-112: evidence lockers
# the evidence store, floor to ceiling: a grid of small numbered lockers each with its
# keypad lock and seal tag (the sealed ones marked), a couple of tall ones for long items,
# the CCTV dome on top, the drop-box slot
static func evidence_lockers(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r, 0.04, 0.06, 0.96, 0.96)
	var dc := _u(r, 0.5, 0.06)
	A(ci, dc, ms * 0.08, 0.0, PI, 0.55, 1.2)
	D(ci, dc + Vector2(0, ms * 0.03), 1.2, 0.55)
	var cols := clampi(int(r.size.x / 30.0), 2, 5)
	var rows := clampi(int(r.size.y * 0.7 / 26.0), 4, 12)
	var cw: float = 0.84 / cols
	var rh: float = 0.68 / rows
	for row in rows:
		for c in cols:
			var cell := sub(r, 0.08 + c * cw, 0.1 + row * rh, 0.08 + (c + 1) * cw - 0.012, 0.1 + (row + 1) * rh - 0.008)
			R(ci, cell, 0.45)
			var kp := Rect2(cell.position + Vector2(cell.size.x * 0.68, cell.size.y * 0.25), Vector2(cell.size.x * 0.2, cell.size.y * 0.45))
			R(ci, kp, 0.4)
			L(ci, cell.position + Vector2(3.0, 3.5), cell.position + Vector2(cell.size.x * 0.35, 3.5), 0.35)
			if (row * cols + c) % 3 == 1:
				E.Rc(ci, Rect2(Vector2(cell.position.x + cell.size.x * 0.6, cell.position.y + 1.0), Vector2(1.2, cell.size.y - 2.0)), Pal.heat(0.6), 1.0)
	for c in 2:
		var tl := sub(r, 0.08 + c * 0.43, 0.8, 0.49 + c * 0.43, 0.94)
		R(ci, tl, 0.5)
		L(ci, Vector2(tl.end.x - 4.0, tl.position.y + 3.0), Vector2(tl.end.x - 4.0, tl.end.y - 3.0), 0.55, 1.3)
	R(ci, sub(r, 0.36, 0.785, 0.64, 0.795), 0.4)


# ---------------------------------------------------------------- flow controller (VT-80, MF-126)
# a flow control station: the pipe spool along the bottom with its flowmeter (the body and
# transmitter head) and the control valve (body, diaphragm actuator, positioner), block
# valves either side, the controller above with its setpoint/flow bars
static func flow_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var py: float = 0.78
	L(ci, _u(r, 0.0, py - 0.04), _u(r, 1.0, py - 0.04), 0.55, 1.3)
	L(ci, _u(r, 0.0, py + 0.04), _u(r, 1.0, py + 0.04), 0.55, 1.3)
	for x in [0.08, 0.92]:
		var c := _u(r, x, py)
		var vs: float = maxf(2.5, ms * 0.05)
		P(ci, PackedVector2Array([c + Vector2(-vs, -vs), c + Vector2(vs, vs), c + Vector2(vs, -vs), c + Vector2(-vs, vs), c + Vector2(-vs, -vs)]), 0.55)
		L(ci, c, c - Vector2(0, vs * 2.2), 0.45)
		L(ci, c - Vector2(vs, vs * 2.2), c + Vector2(vs, -vs * 2.2), 0.5, 1.3)
	var fm := sub(r, 0.2, py - 0.08, 0.38, py + 0.08)
	R(ci, fm, 0.58)
	E.flange(ci, Vector2(fm.position.x, _u(r, 0, py).y), Vector2.LEFT, fm.size.y * 0.6, 0.5)
	E.flange(ci, Vector2(fm.end.x, _u(r, 0, py).y), Vector2.RIGHT, fm.size.y * 0.6, 0.5)
	L(ci, _u(r, 0.29, py - 0.08), _u(r, 0.29, py - 0.16), 0.5)
	var th := _u(r, 0.29, py - 0.2)
	O(ci, th, maxf(2.5, ms * 0.06), 0.55)
	E.Rc(ci, Rect2(th - Vector2(2, 1), Vector2(4, 2)), Pal.tint(Pal.AIR, 0.7), 1.0)
	var vc := _u(r, 0.62, py)
	var vs2: float = maxf(3.0, ms * 0.07)
	P(ci, PackedVector2Array([vc + Vector2(-vs2, -vs2), vc + Vector2(vs2, vs2), vc + Vector2(vs2, -vs2), vc + Vector2(-vs2, vs2), vc + Vector2(-vs2, -vs2)]), 0.6, 1.2)
	L(ci, vc, vc - Vector2(0, vs2 * 2.2), 0.5, 1.3)
	A(ci, vc - Vector2(0, vs2 * 2.2), vs2 * 1.6, PI, TAU, 0.58, 1.2)
	L(ci, vc - Vector2(vs2 * 1.6, vs2 * 2.2), vc + Vector2(vs2 * 1.6, -vs2 * 2.2), 0.58, 1.2)
	R(ci, Rect2(vc + Vector2(vs2 * 0.8, -vs2 * 2.0), Vector2(vs2 * 1.2, vs2 * 1.0)), 0.5)
	var ct := sub(r, 0.1, 0.06, 0.9, 0.42)
	R(ci, ct, 0.6, 1.2)
	E.Rc(ci, sub(r, 0.15, 0.1, 0.5, 0.2), Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 2:
		var bar := sub(r, 0.58 + k * 0.12, 0.1, 0.66 + k * 0.12, 0.36)
		R(ci, bar, 0.42)
		hatch(ci, Rect2(bar.position + Vector2(1, bar.size.y * (0.35 + 0.15 * k)), Vector2(bar.size.x - 2, bar.size.y * (0.65 - 0.15 * k) - 1)), 2.0, false, 0.40, 30)
	for k in 4:
		D(ci, _u(r, 0.18 + k * 0.08, 0.3), 1.1, 0.5)
	_lamp(ci, _u(r, 0.84, 0.13), maxf(1.4, ms * 0.035), Pal.tint(Pal.FLUID, 0.85))
	_pu(ci, r, [Vector2(0.62, 0.42), Vector2(0.62, 0.5)], 0.35)
	_pu(ci, r, [Vector2(0.29, 0.42), Vector2(0.29, 0.52)], 0.35)


# ---------------------------------------------------------------- LC-140: mail locker
# the courier ship's mail locker: pigeonholes with letters and small parcels, the locked
# drop slot, a mail sack on its hook, the parcel scale on the shelf
static func mail_locker(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	R(ci, sub(r, 0.3, 0.07, 0.7, 0.11), 0.5)
	O(ci, _u(r, 0.76, 0.09), maxf(1.4, ms * 0.03), 0.5)
	for row in 4:
		for c in 3:
			var cell := sub(r, 0.1 + c * 0.27, 0.15 + row * 0.1, 0.35 + c * 0.27, 0.24 + row * 0.1)
			R(ci, cell, 0.38)
			var k: int = (row * 3 + c) % 4
			if k == 0 or k == 2:
				for j in 2 + (k / 2):
					L(ci, cell.position + Vector2(2.0 + j * 2.0, cell.size.y - 1.5), cell.position + Vector2(3.5 + j * 2.0, 2.0), 0.45)
			elif k == 1:
				var pk := Rect2(cell.position + Vector2(cell.size.x * 0.25, cell.size.y * 0.3), cell.size * Vector2(0.5, 0.7) - Vector2(0, 1))
				R(ci, pk, 0.45)
				L(ci, pk.position + Vector2(pk.size.x * 0.5, 0), pk.position + Vector2(pk.size.x * 0.5, pk.size.y), 0.3)
	L(ci, _u(r, 0.06, 0.58), _u(r, 0.94, 0.58), 0.55, 1.3)
	var sc := sub(r, 0.58, 0.5, 0.88, 0.58)
	R(ci, sc, 0.5)
	E.Rc(ci, sub(r, 0.62, 0.52, 0.76, 0.56), Pal.tint(Pal.AIR, 0.6), 1.0)
	R(ci, sub(r, 0.62, 0.46, 0.84, 0.5), 0.45)
	D(ci, _u(r, 0.2, 0.62), 1.2, 0.55)
	_pu(ci, r, [Vector2(0.2, 0.62), Vector2(0.14, 0.7), Vector2(0.12, 0.88), Vector2(0.18, 0.92), Vector2(0.36, 0.92), Vector2(0.42, 0.86), Vector2(0.38, 0.7), Vector2(0.2, 0.62)], 0.5)
	L(ci, _u(r, 0.16, 0.72), _u(r, 0.38, 0.72), 0.35)
	E.Rc(ci, sub(r, 0.5, 0.66, 0.88, 0.92), Pal.ink(0.12), 1.0)
	for y in [0.72, 0.8, 0.88]:
		L(ci, _u(r, 0.54, y), _u(r, 0.84, y), 0.3)


# ---------------------------------------------------------------- manifest terminal (CL-104, LC-140)
# the manifest printer: the screen with the manifest table and the cold-chain temperature
# log beside it, the document printer with its paper stack, the rack of sealed manifest
# pouches; small, it is the printer and the pouch rack alone
static func manifest_term(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var big: bool = r.size.x > r.size.y * 0.9
	_carcass(ci, r)
	if big:
		var sc := sub(r, 0.1, 0.08, 0.6, 0.42)
		R(ci, sc, 0.55)
		var q := sc.grow(-3.0)
		var segs := PackedVector2Array()
		for k in 6:
			var y: float = q.position.y + (k + 0.5) * q.size.y / 6.0
			segs.append(Vector2(q.position.x, y))
			segs.append(Vector2(q.end.x, y))
		for f in [0.35, 0.65]:
			segs.append(Vector2(q.position.x + q.size.x * f, q.position.y))
			segs.append(Vector2(q.position.x + q.size.x * f, q.end.y))
		S(ci, segs, 0.25)
		var tl := sub(r, 0.66, 0.08, 0.9, 0.42)
		R(ci, tl, 0.5)
		var tc := PackedVector2Array()
		for j in 8:
			tc.append(Vector2(tl.position.x + 3.0 + j * (tl.size.x - 6.0) / 7.0, tl.position.y + tl.size.y * (0.6 + 0.08 * sin(j * 1.7))))
		P(ci, tc, 0.5)
		E.Rc(ci, Rect2(Vector2(tl.position.x + 2.0, tl.position.y + tl.size.y * 0.35), Vector2(tl.size.x - 4.0, 1.0)), Pal.tint(Pal.AIR, 0.75), 1.0)
	var y0: float = 0.5 if big else 0.08
	var pr := sub(r, 0.1, y0, 0.9 if not big else 0.6, y0 + 0.14)
	R(ci, pr, 0.55)
	L(ci, Vector2(pr.position.x + pr.size.x * 0.15, pr.position.y + pr.size.y * 0.5), Vector2(pr.end.x - pr.size.x * 0.15, pr.position.y + pr.size.y * 0.5), 0.55, 1.4)
	for k in 3:
		L(ci, Vector2(pr.position.x + pr.size.x * 0.2, pr.end.y + 2.0 + k * 1.6), Vector2(pr.end.x - pr.size.x * 0.2, pr.end.y + 2.0 + k * 1.6), 0.4)
	_lamp(ci, pr.position + Vector2(pr.size.x * 0.9, pr.size.y * 0.3), 1.8, Pal.tint(Pal.FLUID, 0.85))
	var y1: float = 0.72 if big else 0.34
	var n := clampi(int(r.size.x * 0.8 / 9.0), 3, 10)
	for k in n:
		var x0: float = 0.1 + k * 0.8 / n
		var pc := sub(r, x0 + 0.01, y1, x0 + 0.8 / n - 0.01, 0.92)
		R(ci, pc, 0.45)
		_pu(ci, r, [Vector2(x0 + 0.01, y1 + 0.04), Vector2(x0 + 0.4 / n, y1 + 0.08), Vector2(x0 + 0.8 / n - 0.01, y1 + 0.04)], 0.4)
		E.Rc(ci, Rect2(_u(r, x0 + 0.4 / n, y1 + 0.1) - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Pal.heat(0.7), 1.0)


# ---------------------------------------------------------------- pharmacy store (CH-110, MT-140, MED-47, PT-34)
# a pharmacy cabinet: glazed shelves of bottles and blister boxes, the locked controlled-drug
# safe with its key, the drug fridge with its temperature readout, the cross on the door;
# wider ones get more shelf columns
static func pharmacy(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var cols := clampi(int(r.size.x / 40.0), 1, 4)
	var cw: float = 0.84 / (cols + 1)
	for c in cols:
		var x0: float = 0.08 + c * cw
		var gl := sub(r, x0, 0.07, x0 + cw - 0.01, 0.6)
		R(ci, gl, 0.5)
		L(ci, gl.position + Vector2(2, 2), gl.position + Vector2(gl.size.x * 0.4, 2), 0.25)
		for s in 3:
			var sy: float = 0.07 + (s + 1) * 0.53 / 3.0
			L(ci, _u(r, x0, sy), _u(r, x0 + cw - 0.01, sy), 0.45)
			var nb := clampi(int(gl.size.x / 7.0), 2, 8)
			for k in nb:
				var bx: float = x0 + (k + 0.5) * (cw - 0.01) / nb
				if (k + s + c) % 3 == 0:
					R(ci, sub(r, bx - 0.25 * cw / nb, sy - 0.1, bx + 0.25 * cw / nb, sy), 0.42)
				else:
					_pu(ci, r, [Vector2(bx - 0.2 * cw / nb, sy), Vector2(bx - 0.2 * cw / nb, sy - 0.08), Vector2(bx - 0.08 * cw / nb, sy - 0.11), Vector2(bx + 0.08 * cw / nb, sy - 0.11), Vector2(bx + 0.2 * cw / nb, sy - 0.08), Vector2(bx + 0.2 * cw / nb, sy)], 0.42)
	var xf: float = 0.08 + cols * cw
	var sf := sub(r, xf, 0.07, 0.92, 0.36)
	R(ci, sf, 0.6, 1.2)
	R(ci, sf.grow(-2.5), 0.3)
	var kc := sf.get_center()
	O(ci, kc, maxf(2.0, ms * 0.05), 0.55)
	L(ci, kc, kc + Vector2(0, maxf(2.0, ms * 0.05) * 1.6), 0.55, 1.3)
	var fr := sub(r, xf, 0.4, 0.92, 0.9)
	R(ci, fr, 0.58)
	E.Rc(ci, Rect2(fr.position + Vector2(fr.size.x * 0.15, 3.0), Vector2(fr.size.x * 0.7, minf(fr.size.y * 0.12, 7.0))), Pal.tint(Pal.AIR, 0.65), 1.0)
	L(ci, Vector2(fr.end.x - 3.0, fr.position.y + fr.size.y * 0.3), Vector2(fr.end.x - 3.0, fr.position.y + fr.size.y * 0.6), 0.55, 1.5)
	var cc := _u(r, 0.08 + cols * cw * 0.5, 0.76)
	var cs: float = maxf(3.0, ms * 0.08)
	E.Rc(ci, Rect2(cc - Vector2(cs * 0.3, cs), Vector2(cs * 0.6, cs * 2.0)), Pal.tint(Pal.FLUID, 0.75), 1.0)
	E.Rc(ci, Rect2(cc - Vector2(cs, cs * 0.3), Vector2(cs * 2.0, cs * 0.6)), Pal.tint(Pal.FLUID, 0.75), 1.0)
	for c in cols:
		L(ci, _u(r, 0.08 + c * cw + cw * 0.5 - 0.03, 0.66), _u(r, 0.08 + c * cw + cw * 0.5 + 0.03, 0.66), 0.5, 1.3)


# ---------------------------------------------------------------- sample cabinet (FL-116, M-14, MF-126)
# the sample cabinet: tray rows of capped sample jars with their label bands, a row of
# bagged samples with their tags, the bin drawers below with label holders
static func sample_trays(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.04, 0.05, 0.96, 0.94)
	var rows := clampi(int(r.size.y * 0.55 / 18.0), 1, 4)
	var rh: float = 0.55 / rows
	for row in rows:
		var y1: float = 0.08 + (row + 1) * rh
		L(ci, _u(r, 0.06, y1), _u(r, 0.94, y1), 0.5, 1.3)
		var n := clampi(int(r.size.x * 0.86 / 8.0), 3, 30)
		for k in n:
			var x: float = 0.08 + (k + 0.5) * 0.84 / n
			var hw: float = 0.84 / n * 0.32
			if row % 2 == 1 and k % 2 == 1:
				_pu(ci, r, [Vector2(x - hw, y1), Vector2(x - hw * 1.1, y1 - rh * 0.5), Vector2(x, y1 - rh * 0.72), Vector2(x + hw * 1.1, y1 - rh * 0.5), Vector2(x + hw, y1)], 0.4)
				D(ci, _u(r, x, y1 - rh * 0.72), 0.8, 0.5)
				continue
			R(ci, sub(r, x - hw, y1 - rh * 0.62, x + hw, y1), 0.45)
			R(ci, sub(r, x - hw * 1.15, y1 - rh * 0.72, x + hw * 1.15, y1 - rh * 0.62), 0.5)
			L(ci, _u(r, x - hw, y1 - rh * 0.3), _u(r, x + hw, y1 - rh * 0.3), 0.3)
	var nd := clampi(int(r.size.x / 30.0), 2, 6)
	for k in nd:
		var dr := sub(r, 0.06 + k * 0.88 / nd, 0.68, 0.06 + (k + 1) * 0.88 / nd - 0.01, 0.92)
		R(ci, dr, 0.48)
		R(ci, Rect2(dr.position + Vector2(dr.size.x * 0.3, dr.size.y * 0.2), Vector2(dr.size.x * 0.4, dr.size.y * 0.2)), 0.4)
		L(ci, dr.position + Vector2(dr.size.x * 0.4, dr.size.y * 0.6), dr.position + Vector2(dr.size.x * 0.6, dr.size.y * 0.6), 0.55, 1.3)


# ---------------------------------------------------------------- HB-86: seed vault
# the seed bank freezer: the thick insulated door ajar on its heavy hinges (gasket, the
# lever latch), inside the drawers of foil seed packets, the frost, the -18 readout, the
# condensing unit below with its fan grille
static func seed_vault(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r, 0.06, 0.04, 0.94, 0.78)
	R(ci, b.grow(-4.0), 0.35)
	E.Rc(ci, b.grow(-4.0), Pal.tint(Pal.AIR, 0.2), 1.0)
	for k in 6:
		var dr := sub(r, 0.14, 0.08 + k * 0.105, 0.72, 0.17 + k * 0.105)
		R(ci, dr, 0.45)
		var n := clampi(int(dr.size.x / 6.0), 4, 14)
		var segs := PackedVector2Array()
		for j in n:
			var x: float = dr.position.x + (j + 0.5) * dr.size.x / n
			segs.append(Vector2(x, dr.position.y + 2.0))
			segs.append(Vector2(x, dr.end.y - 1.5))
		S(ci, segs, 0.3)
		L(ci, dr.position + Vector2(dr.size.x * 0.4, dr.size.y * 0.5), dr.position + Vector2(dr.size.x * 0.6, dr.size.y * 0.5), 0.55, 1.2)
	_pu(ci, r, [Vector2(0.94, 0.06), Vector2(0.99, 0.1), Vector2(0.99, 0.72), Vector2(0.94, 0.76)], 0.58, 1.3)
	for y in [0.16, 0.66]:
		R(ci, sub(r, 0.92, y, 0.97, y + 0.05), 0.55)
	L(ci, _u(r, 0.98, 0.38), _u(r, 0.98, 0.46), 0.6, 2.0)
	var fr := PackedVector2Array()
	for k in 9:
		fr.append(_u(r, 0.12 + k * 0.08, 0.075 + (0.012 if k % 2 == 0 else 0.0)))
	P(ci, fr, 0.35)
	E.Rc(ci, sub(r, 0.76, 0.1, 0.88, 0.16), Pal.tint(Pal.AIR, 0.75), 1.0)
	var cu := sub(r, 0.06, 0.8, 0.94, 0.96)
	R(ci, cu, 0.55)
	var fc := Vector2(cu.position.x + cu.size.y * 0.5 + 3.0, cu.get_center().y)
	E.fan(ci, fc, cu.size.y * 0.38, 5, 0.42)
	E.louvres(ci, Rect2(cu.position + Vector2(cu.size.x * 0.35, 2.0), Vector2(cu.size.x * 0.6, cu.size.y - 4.0)), 0.25)


# ---------------------------------------------------------------- MF-126: heat log recorder
# the smelter's heat recorder: the strip chart with the furnace temperature curve (charge,
# melt, tap), the thermocouple jacks below, the heat-number punch with its tags hanging
static func smelt_log(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var ch := sub(r, 0.12, 0.07, 0.88, 0.46)
	R(ci, ch, 0.55)
	var q := ch.grow(-3.0)
	var gs := PackedVector2Array()
	for j in 4:
		var y: float = q.position.y + (j + 0.5) * q.size.y / 4.0
		gs.append(Vector2(q.position.x, y))
		gs.append(Vector2(q.end.x, y))
	S(ci, gs, 0.15)
	var tr := PackedVector2Array([Vector2(q.position.x, q.end.y - 2.0), Vector2(q.position.x + q.size.x * 0.3, q.position.y + q.size.y * 0.45), Vector2(q.position.x + q.size.x * 0.45, q.position.y + q.size.y * 0.2), Vector2(q.position.x + q.size.x * 0.75, q.position.y + q.size.y * 0.15), Vector2(q.position.x + q.size.x * 0.8, q.position.y + q.size.y * 0.7), Vector2(q.end.x, q.position.y + q.size.y * 0.8)])
	for i in tr.size() - 1:
		E.Rc(ci, Rect2(tr[i], Vector2(0.8, 0.8)), Pal.heat(0.8), 1.0)
	P(ci, tr, 0.45, 1.2)
	for k in 4:
		var jc := _u(r, 0.2 + k * 0.12, 0.54)
		R(ci, Rect2(jc - Vector2(2.5, 2.0), Vector2(5.0, 4.0)), 0.5)
		D(ci, jc, 0.7, 0.55)
	var pn := sub(r, 0.12, 0.62, 0.5, 0.78)
	R(ci, pn, 0.55)
	L(ci, _u(r, 0.31, 0.62), _u(r, 0.31, 0.56), 0.55, 1.5)
	L(ci, _u(r, 0.24, 0.56), _u(r, 0.4, 0.56), 0.55, 1.5)
	L(ci, _u(r, 0.6, 0.62), _u(r, 0.88, 0.62), 0.5, 1.2)
	for k in 4:
		var x: float = 0.63 + k * 0.065
		L(ci, _u(r, x, 0.62), _u(r, x, 0.66), 0.4)
		R(ci, sub(r, x - 0.022, 0.66, x + 0.022, 0.76), 0.45)
		D(ci, _u(r, x, 0.685), 0.7, 0.45)
	E.louvres(ci, sub(r, 0.12, 0.82, 0.88, 0.92), 0.25)


# ---------------------------------------------------------------- ST-40: cockpit spares case
# the racer's spares: a hard case with its two latches and handle, the lid up showing the
# foam cut-outs (a spare visor, gloves, fuses, a small tool roll)
static func cockpit_case(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.04, 0.42, 0.96, 0.96)
	R(ci, bx, 0.62, 1.3)
	_pu(ci, r, [Vector2(0.04, 0.42), Vector2(0.08, 0.04), Vector2(0.92, 0.04), Vector2(0.96, 0.42)], 0.5, 1.2)
	E.Rc(ci, sub(r, 0.1, 0.1, 0.9, 0.38), Pal.ink(0.12), 1.0)
	A(ci, _u(r, 0.32, 0.38), ms * 0.4, PI * 1.1, PI * 1.9, 0.5, 1.2)
	E.Rc(ci, sub(r, 0.2, 0.2, 0.44, 0.3), Pal.tint(Pal.AIR, 0.4), 1.0)
	for k in 2:
		var x: float = 0.56 + k * 0.16
		_pu(ci, r, [Vector2(x, 0.34), Vector2(x, 0.16), Vector2(x + 0.04, 0.12), Vector2(x + 0.08, 0.16), Vector2(x + 0.1, 0.34)], 0.45)
	var fz := PackedVector2Array()
	for k in 5:
		fz.append(_u(r, 0.14 + k * 0.08, 0.58))
		fz.append(_u(r, 0.14 + k * 0.08, 0.7))
	S(ci, fz, 0.5, 1.6)
	R(ci, sub(r, 0.58, 0.54, 0.88, 0.76), 0.42)
	for x in [0.25, 0.75]:
		R(ci, sub(r, x - 0.05, 0.38, x + 0.05, 0.48), 0.6)
	L(ci, _u(r, 0.4, 0.96), _u(r, 0.6, 0.96), 0.55, 1.6)


# ---------------------------------------------------------------- supply crates (JD-38, TW-64, CH-110, PT-34)
# a stack of supply crates (ribbed lids, stencil bands, their handles), a pair of water
# jerrycans, all under the cargo net and its ratchet strap; the stack grows with the space
static func supply_stack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cols := clampi(int(r.size.x / 34.0), 1, 5)
	var rows := clampi(int(r.size.y / 30.0), 1, 4)
	var cw: float = 0.78 / cols
	var rh: float = 0.9 / rows
	for row in rows:
		for c in cols:
			var cr := sub(r, 0.02 + c * cw, 0.08 + row * rh, 0.02 + (c + 1) * cw - 0.01, 0.08 + (row + 1) * rh - 0.01)
			R(ci, cr, 0.58, 1.1)
			L(ci, cr.position + Vector2(2.0, 3.0), Vector2(cr.end.x - 2.0, cr.position.y + 3.0), 0.35)
			E.Rc(ci, Rect2(cr.position + Vector2(3.0, cr.size.y * 0.45), Vector2(cr.size.x - 6.0, 1.5)), Pal.heat(0.45) if (row + c) % 2 == 0 else Pal.tint(Pal.FLUID, 0.5), 1.0)
			R(ci, Rect2(cr.position + Vector2(cr.size.x * 0.35, cr.size.y * 0.62), Vector2(cr.size.x * 0.3, cr.size.y * 0.1)), 0.42)
	for k in 2:
		var x0: float = 0.82 + k * 0.08
		_pu(ci, r, [Vector2(x0, 0.98), Vector2(x0, 0.62), Vector2(x0 + 0.02, 0.58), Vector2(x0 + 0.07, 0.58), Vector2(x0 + 0.07, 0.98)], 0.5)
		E.Rc(ci, sub(r, x0 + 0.005, 0.75, x0 + 0.065, 0.97), Pal.tint(Pal.FLUID, 0.25), 1.0)
		R(ci, sub(r, x0 + 0.01, 0.55, x0 + 0.03, 0.58), 0.5)
	var net := PackedVector2Array()
	var n := clampi(int(r.size.x * 0.8 / 10.0), 3, 20)
	for k in n + 1:
		var x: float = 0.02 + k * 0.78 / n
		net.append(_u(r, x, 0.06))
		net.append(_u(r, x + 0.78 / n * 0.5, 0.98))
		net.append(_u(r, x + 0.78 / n * 0.5, 0.06))
		net.append(_u(r, x, 0.98))
	S(ci, net, 0.15)
	L(ci, _u(r, 0.0, 0.5), _u(r, 0.82, 0.5), 0.55, 1.5)
	R(ci, sub(r, 0.36, 0.47, 0.44, 0.53), 0.6)


# ---------------------------------------------------------------- the maintenance cabinet (17 on 11 ships)
# a bench-height maintenance cabinet: on top the cordless drill on its charger, the
# multimeter with its leads, a tape roll; below the drawers and the consumables door; the
# big ones add the wall shelves of boxed spares above
static func svc_bench(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var tall: bool = r.size.y > r.size.x * 0.6
	var top: float = 0.55 if tall else 0.3
	if tall:
		for s in 2:
			var sy: float = 0.18 + s * 0.17
			L(ci, _u(r, 0.04, sy), _u(r, 0.96, sy), 0.5, 1.3)
			var n := clampi(int(r.size.x / 22.0), 3, 10)
			for k in n:
				var x0: float = 0.06 + k * 0.88 / n
				R(ci, sub(r, x0, sy - 0.12, x0 + 0.88 / n * 0.8, sy), 0.42)
				L(ci, _u(r, x0 + 0.02, sy - 0.08), _u(r, x0 + 0.88 / n * 0.6, sy - 0.08), 0.3)
	var bd := sub(r, 0.04, top, 0.96, 0.96)
	R(ci, bd, 0.62, 1.2)
	L(ci, _u(r, 0.02, top), _u(r, 0.98, top), 0.6, 1.6)
	var nd := 2 if not tall else 3
	for k in nd:
		var dr := sub(r, 0.08, top + 0.06 + k * (0.86 - top) / (nd + 0.5), 0.5, top + 0.06 + (k + 1) * (0.86 - top) / (nd + 0.5) - 0.02)
		R(ci, dr, 0.45)
		L(ci, dr.position + Vector2(dr.size.x * 0.35, dr.size.y * 0.5), dr.position + Vector2(dr.size.x * 0.65, dr.size.y * 0.5), 0.55, 1.3)
	var dd := sub(r, 0.54, top + 0.06, 0.92, 0.92)
	R(ci, dd, 0.45)
	L(ci, Vector2(dd.position.x + 3.0, dd.get_center().y - 2.0), Vector2(dd.position.x + 3.0, dd.get_center().y + 2.0), 0.6, 1.4)
	E.louvres(ci, Rect2(dd.position + Vector2(dd.size.x * 0.3, dd.size.y * 0.6), Vector2(dd.size.x * 0.6, dd.size.y * 0.3)), 0.25)
	var ty: float = _u(r, 0, top).y
	var h0: float = minf(r.size.y * (top - 0.04), 22.0)
	R(ci, Rect2(_u(r, 0.08, 0) + Vector2(0, ty - r.position.y - h0 * 0.25), Vector2(r.size.x * 0.16, h0 * 0.25)), 0.5)
	var dg := Vector2(_u(r, 0.14, 0).x, ty - h0 * 0.25)
	P(ci, PackedVector2Array([dg, dg - Vector2(0, h0 * 0.45), dg + Vector2(r.size.x * 0.08, -h0 * 0.6), dg + Vector2(r.size.x * 0.1, -h0 * 0.45), dg + Vector2(r.size.x * 0.04, -h0 * 0.4)]), 0.55)
	_lamp(ci, _u(r, 0.21, 0) + Vector2(0, ty - r.position.y - h0 * 0.12), 1.6, Pal.tint(Pal.FLUID, 0.85))
	var mm := Rect2(_u(r, 0.36, 0) + Vector2(0, ty - r.position.y - h0 * 0.7), Vector2(r.size.x * 0.12, h0 * 0.7))
	R(ci, mm, 0.55)
	E.Rc(ci, Rect2(mm.position + Vector2(2, 2), Vector2(mm.size.x - 4, mm.size.y * 0.3)), Pal.tint(Pal.AIR, 0.6), 1.0)
	O(ci, mm.position + Vector2(mm.size.x * 0.5, mm.size.y * 0.68), minf(mm.size.x * 0.25, 3.0), 0.5)
	_pu(ci, r, [Vector2(0.48, top - 0.02), Vector2(0.58, top - 0.01), Vector2(0.62, top - 0.04)], 0.45)
	_pu(ci, r, [Vector2(0.48, top - 0.03), Vector2(0.55, top - 0.005), Vector2(0.68, top - 0.02)], 0.35)
	O(ci, Vector2(_u(r, 0.82, 0).x, ty - h0 * 0.25), h0 * 0.25, 0.5)
	O(ci, Vector2(_u(r, 0.82, 0).x, ty - h0 * 0.25), h0 * 0.1, 0.4)


# ---------------------------------------------------------------- dining table (MY-48, FR-26)
# a dining table: the top with its edge, the pedestal (or legs), the place settings (plates,
# glasses, cutlery), a small vase in the middle
static func dining_table(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var ty: float = 0.42
	R(ci, sub(r, 0.02, ty, 0.98, ty + 0.08), 0.62, 1.3)
	L(ci, _u(r, 0.5, ty + 0.08), _u(r, 0.5, 0.9), 0.6, 2.2)
	_pu(ci, r, [Vector2(0.3, 0.98), Vector2(0.36, 0.9), Vector2(0.64, 0.9), Vector2(0.7, 0.98)], 0.55, 1.3)
	L(ci, _u(r, 0.28, 0.98), _u(r, 0.72, 0.98), 0.5, 1.3)
	for x in [0.18, 0.82]:
		_ell(ci, _u(r, x, ty - 0.02), r.size.x * 0.1, r.size.y * 0.025, 0.5)
		_ell(ci, _u(r, x, ty - 0.03), r.size.x * 0.06, r.size.y * 0.015, 0.35)
		var gx: float = x + (0.12 if x < 0.5 else -0.12)
		_pu(ci, r, [Vector2(gx - 0.02, ty - 0.2), Vector2(gx - 0.015, ty - 0.12), Vector2(gx + 0.015, ty - 0.12), Vector2(gx + 0.02, ty - 0.2)], 0.45)
		L(ci, _u(r, gx, ty - 0.12), _u(r, gx, ty - 0.01), 0.4)
		L(ci, _u(r, gx - 0.02, ty - 0.005), _u(r, gx + 0.02, ty - 0.005), 0.4)
		L(ci, _u(r, x - 0.13, ty - 0.01), _u(r, x - 0.13, ty - 0.08), 0.4)
	_pu(ci, r, [Vector2(0.47, ty), Vector2(0.46, ty - 0.12), Vector2(0.48, ty - 0.18), Vector2(0.52, ty - 0.18), Vector2(0.54, ty - 0.12), Vector2(0.53, ty)], 0.5)
	L(ci, _u(r, 0.5, ty - 0.18), _u(r, 0.48, ty - 0.32), 0.4)
	L(ci, _u(r, 0.5, ty - 0.18), _u(r, 0.54, ty - 0.3), 0.4)
	E.Rc(ci, Rect2(_u(r, 0.48, ty - 0.33) - Vector2(1.5, 1.5), Vector2(3, 3)), Pal.heat(0.6), 1.0)
	E.Rc(ci, Rect2(_u(r, 0.54, ty - 0.31) - Vector2(1.5, 1.5), Vector2(3, 3)), Pal.tint(Pal.FLUID, 0.6), 1.0)


# ---------------------------------------------------------------- TW-64: tow log recorder
# the tug's tow recorder: the tension drum chart (its trace and the peak), the tow-line
# payout counter, the log book open on its lectern, the printer, the alarm lamp
static func tow_log(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r)
	var dm := sub(r, 0.12, 0.08, 0.6, 0.42)
	R(ci, dm, 0.55)
	O(ci, dm.get_center(), minf(dm.size.x, dm.size.y) * 0.45, 0.45)
	var tr := PackedVector2Array()
	var cc := dm.get_center()
	var rr: float = minf(dm.size.x, dm.size.y) * 0.4
	for k in 17:
		var a: float = -PI * 0.9 + k * PI * 1.8 / 16.0
		var rv: float = rr * (0.45 + 0.35 * fposmod(k * 0.37, 1.0) + (0.2 if k == 11 else 0.0))
		tr.append(cc + Vector2.from_angle(a) * rv)
	P(ci, tr, 0.5)
	D(ci, cc, 1.2, 0.55)
	var ct := sub(r, 0.66, 0.1, 0.9, 0.2)
	E.Rc(ci, ct, Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 4:
		L(ci, ct.position + Vector2(ct.size.x * (0.15 + k * 0.22), 2.0), ct.position + Vector2(ct.size.x * (0.15 + k * 0.22), ct.size.y - 2.0), 0.5)
	_lamp(ci, _u(r, 0.78, 0.3), maxf(1.6, ms * 0.05), Pal.heat(0.9))
	_pu(ci, r, [Vector2(0.12, 0.62), Vector2(0.3, 0.52), Vector2(0.48, 0.62), Vector2(0.66, 0.52), Vector2(0.84, 0.62)], 0.55, 1.2)
	L(ci, _u(r, 0.48, 0.62), _u(r, 0.48, 0.66), 0.5)
	for k in 3:
		L(ci, _u(r, 0.18, 0.6 - k * 0.025), _u(r, 0.42, 0.55 - k * 0.025), 0.3)
		L(ci, _u(r, 0.54, 0.55 - k * 0.025), _u(r, 0.78, 0.6 - k * 0.025), 0.3)
	var pr := sub(r, 0.12, 0.72, 0.88, 0.86)
	R(ci, pr, 0.5)
	L(ci, _u(r, 0.25, 0.79), _u(r, 0.75, 0.79), 0.55, 1.4)
	_pu(ci, r, [Vector2(0.35, 0.72), Vector2(0.35, 0.68), Vector2(0.65, 0.68), Vector2(0.65, 0.72)], 0.35)


# ================================================================== power and generation (fourth batch)
# 2026-11-11: the generators all drew as the same stator wheel; each now its own machine.

# an inline engine seen from the side: block, rocker covers, sump, the exhaust manifold
static func _engine_side(ci: CanvasItem, r: Rect2, cyl: int, al: float = 0.55) -> void:
	R(ci, Rect2(r.position + Vector2(0, r.size.y * 0.3), Vector2(r.size.x, r.size.y * 0.5)), al, 1.2)
	_pu(ci, r, [Vector2(0.06, 0.8), Vector2(0.12, 0.98), Vector2(0.88, 0.98), Vector2(0.94, 0.8)], al * 0.9)
	var cw: float = 1.0 / cyl
	for k in cyl:
		var c := sub(r, k * cw + 0.02, 0.06, (k + 1) * cw - 0.02, 0.3)
		R(ci, c, al * 0.9)
		D(ci, c.get_center(), 1.0, al)
	var ex := PackedVector2Array()
	for k in cyl:
		ex.append(_u(r, (k + 0.5) * cw, 0.42))
		ex.append(_u(r, (k + 0.5) * cw, 0.5))
	S(ci, ex, al * 0.7, 1.4)
	L(ci, _u(r, 0.04, 0.5), _u(r, 0.96, 0.5), al * 0.8, 1.6)


# a large alternator lying along x in r: ribbed frame, end shields, the shaft out of the
# drive end (left), the exciter (right), the terminal box on top
static func _alternator(ci: CanvasItem, r: Rect2, al: float = 0.58) -> void:
	var fr := sub(r, 0.08, 0.12, 0.8, 0.92)
	R(ci, fr, al, 1.3)
	var rib := PackedVector2Array()
	var n := clampi(int(fr.size.x / 5.0), 4, 40)
	for k in n:
		var x: float = fr.position.x + (k + 0.5) * fr.size.x / n
		rib.append(Vector2(x, fr.position.y + 2.0))
		rib.append(Vector2(x, fr.end.y - 2.0))
	S(ci, rib, 0.22)
	for x in [0.02, 0.8]:
		_pu(ci, r, [Vector2(x + 0.06 if x < 0.5 else x, 0.2), Vector2(x if x < 0.5 else x + 0.06, 0.3), Vector2(x if x < 0.5 else x + 0.06, 0.74), Vector2(x + 0.06 if x < 0.5 else x, 0.84)], al)
	L(ci, _u(r, 0.0, 0.52), _u(r, 0.02, 0.52), al, 2.0)
	R(ci, sub(r, 0.86, 0.32, 1.0, 0.72), al * 0.9)
	hatch(ci, sub(r, 0.87, 0.34, 0.99, 0.7), 2.2, true, 0.25, 12)
	R(ci, sub(r, 0.36, 0.0, 0.56, 0.12), al)
	for k in 3:
		D(ci, _u(r, 0.4 + k * 0.06, 0.06), 1.0, al)


# ---------------------------------------------------------------- BL-88: oxygen electrolyser
# the dome's PEM electrolyser: the cell stack between its end plates and tie rods, the
# deionised-water tank (its level) and the polishing cartridge, the O2 and H2 gas/water
# separators with their level glasses, the O2 line up to the dome, the H2 vent, the DC
# rectifier with its current meter
static func bl_electrolyser(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.95, 0.98, 1.0), 0.55)
	var st := sub(r, 0.08, 0.56, 0.58, 0.94)
	for x in [0.08, 0.53]:
		R(ci, sub(r, x, 0.56, x + 0.05, 0.94), 0.6, 1.2)
	hatch(ci, sub(r, 0.13, 0.58, 0.53, 0.92), 2.2, true, 0.32, 60)
	for y in [0.6, 0.9]:
		L(ci, _u(r, 0.06, y), _u(r, 0.6, y), 0.5)
		D(ci, _u(r, 0.06, y), 1.0, 0.55)
		D(ci, _u(r, 0.6, y), 1.0, 0.55)
	# separators
	for k in 2:
		var x: float = 0.14 + k * 0.24
		E.vessel_v(ci, sub(r, x, 0.14, x + 0.14, 0.48), 0.55)
		E.Rc(ci, sub(r, x + 0.02, 0.3, x + 0.12, 0.44), Pal.tint(Pal.AIR if k == 0 else Pal.FLUID, 0.3), 1.0)
		L(ci, _u(r, x + 0.155, 0.2), _u(r, x + 0.155, 0.42), 0.45, 1.3)
		_pu(ci, r, [Vector2(x + 0.07, 0.56), Vector2(x + 0.07, 0.48)], 0.45)
	_pu(ci, r, [Vector2(0.21, 0.14), Vector2(0.21, 0.04), Vector2(0.21, 0.0)], 0.55, 1.4)
	E.Rc(ci, sub(r, 0.205, 0.0, 0.215, 0.12), Pal.tint(Pal.AIR, 0.6), 1.0)
	_pu(ci, r, [Vector2(0.45, 0.14), Vector2(0.45, 0.08), Vector2(0.52, 0.04)], 0.4)
	# water tank and polisher
	var wt := sub(r, 0.66, 0.5, 0.94, 0.94)
	R(ci, wt, 0.55)
	E.Rc(ci, sub(r, 0.67, 0.64, 0.93, 0.93), Pal.tint(Pal.FLUID, 0.25), 1.0)
	L(ci, _u(r, 0.67, 0.64), _u(r, 0.93, 0.64), 0.4)
	R(ci, sub(r, 0.62, 0.62, 0.65, 0.88), 0.45)
	_pu(ci, r, [Vector2(0.66, 0.9), Vector2(0.6, 0.9)], 0.45)
	# rectifier
	var rc := sub(r, 0.66, 0.06, 0.94, 0.42)
	R(ci, rc, 0.58)
	E.gauge(ci, _u(r, 0.8, 0.18), maxf(2.5, ms * 0.07), 0.55)
	E.louvres(ci, sub(r, 0.7, 0.28, 0.9, 0.38), 0.28)
	_pu(ci, r, [Vector2(0.66, 0.38), Vector2(0.58, 0.38), Vector2(0.58, 0.56)], 0.5, 1.6)


# ---------------------------------------------------------------- fuel cell power module (p_fuel_cell, p_fuelcell)
# a PEM fuel-cell module: one to three stacks (end plates, the cells, tie rods), the air
# blower and the membrane humidifier, the hydrogen train (regulator, purge valve), the
# coolant pump and its stubs, the DC/DC output box, the product-water drain
static func fuel_cell_pm(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := sub(r, 0.02, 0.06, 0.98, 0.94)
	R(ci, b, 0.45)
	R(ci, sub(r, 0.0, 0.94, 1.0, 1.0), 0.55)
	var ns := clampi(int(r.size.x / (1.1 * M)), 1, 3)
	var sw: float = 0.56 / ns
	for i in ns:
		var x0: float = 0.06 + i * sw
		R(ci, sub(r, x0, 0.36, x0 + 0.03, 0.9), 0.6, 1.2)
		R(ci, sub(r, x0 + sw - 0.05, 0.36, x0 + sw - 0.02, 0.9), 0.6, 1.2)
		hatch(ci, sub(r, x0 + 0.03, 0.38, x0 + sw - 0.05, 0.88), 2.0, true, 0.32, 60)
		for y in [0.4, 0.86]:
			L(ci, _u(r, x0 - 0.01, y), _u(r, x0 + sw - 0.01, y), 0.45)
	# air blower and humidifier
	var bc := _u(r, 0.16, 0.2)
	var br: float = minf(r.size.x * 0.1, r.size.y * 0.12)
	E.fan(ci, bc, br, 6, 0.48)
	var hu := sub(r, 0.3, 0.1, 0.6, 0.3)
	R(ci, hu, 0.5)
	E.pleats(ci, hu.grow(-2.0), 2.4, true, 0.3)
	L(ci, bc + Vector2(br, 0), Vector2(hu.position.x, bc.y), 0.45, 1.3)
	_pu(ci, r, [Vector2(0.45, 0.3), Vector2(0.45, 0.36)], 0.45, 1.3)
	# hydrogen train
	var hy: float = 0.18
	L(ci, _u(r, 0.66, hy), _u(r, 1.0, hy), 0.55, 1.3)
	O(ci, _u(r, 0.76, hy), maxf(2.0, ms * 0.05), 0.55)
	A(ci, _u(r, 0.76, hy - 0.05), maxf(2.0, ms * 0.05), PI, TAU, 0.5)
	var pv := _u(r, 0.88, hy)
	var vs: float = maxf(2.0, ms * 0.035)
	P(ci, PackedVector2Array([pv + Vector2(-vs, -vs), pv + Vector2(vs, vs), pv + Vector2(vs, -vs), pv + Vector2(-vs, vs), pv + Vector2(-vs, -vs)]), 0.55)
	E.Rc(ci, Rect2(_u(r, 0.66, hy) - Vector2(0, 0.6), Vector2(r.size.x * 0.34, 1.2)), Pal.tint(Pal.AIR, 0.5), 1.0)
	_pu(ci, r, [Vector2(0.66, hy), Vector2(0.62, hy), Vector2(0.62, 0.36)], 0.45)
	# coolant pump and stubs
	var cp := _u(r, 0.76, 0.5)
	O(ci, cp, maxf(2.5, ms * 0.07), 0.55)
	E.impeller(ci, cp, maxf(2.0, ms * 0.05), 0.4)
	for y in [0.44, 0.56]:
		L(ci, _u(r, 0.86, y), _u(r, 1.0, y), 0.5, 1.4)
	_pu(ci, r, [Vector2(0.62, 0.5), Vector2(0.72, 0.5)], 0.45, 1.3)
	# DC/DC and drain
	var dc := sub(r, 0.66, 0.66, 0.94, 0.9)
	R(ci, dc, 0.58)
	hatch(ci, Rect2(dc.position + Vector2(2, 2), Vector2(dc.size.x * 0.4, dc.size.y - 4)), 2.2, true, 0.3, 10)
	_lamp(ci, dc.position + Vector2(dc.size.x * 0.75, dc.size.y * 0.3), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	L(ci, Vector2(dc.end.x, dc.position.y + dc.size.y * 0.6), Vector2(r.end.x, dc.position.y + dc.size.y * 0.6), 0.55, 1.6)
	_pu(ci, r, [Vector2(0.3, 0.9), Vector2(0.3, 0.98)], 0.4)
	E.Rc(ci, sub(r, 0.29, 0.92, 0.31, 0.94), Pal.tint(Pal.FLUID, 0.7), 1.0)


# ---------------------------------------------------------------- ARK-01: backup generator (free-piston Stirling)
# the ring's backup: two opposed free-piston Stirling engines on a common heat source (the
# heater heads, regenerators, the linear alternators at the outer ends), the balancer, the
# cold-side coolant jacket and lines, the controller, the skid
static func stirling_gen(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.9, 0.98, 0.97), 0.58, 1.2)
	for x in [0.12, 0.88]:
		R(ci, sub(r, x - 0.04, 0.84, x + 0.04, 0.9), 0.5)
	var cy: float = 0.58
	var hs := sub(r, 0.42, cy - 0.16, 0.58, cy + 0.16)
	R(ci, hs, 0.62, 1.3)
	E.Rc(ci, hs.grow(-3.0), Pal.heat(0.4), 1.0)
	for s in [-1.0, 1.0]:
		var hx: float = 0.5 + s * 0.08
		var x1: float = 0.5 + s * 0.16
		var fins := PackedVector2Array()
		for k in 4:
			var x: float = hx + s * (k + 0.5) * 0.02
			fins.append(_u(r, x, cy - 0.13))
			fins.append(_u(r, x, cy + 0.13))
		S(ci, fins, 0.45)
		var rg := sub(r, minf(x1, x1 + s * 0.06), cy - 0.1, maxf(x1, x1 + s * 0.06), cy + 0.1)
		R(ci, rg, 0.5)
		hatch(ci, rg.grow(-1.0), 1.6, false, 0.3, 12)
		var cj := sub(r, minf(x1 + s * 0.06, x1 + s * 0.12), cy - 0.12, maxf(x1 + s * 0.06, x1 + s * 0.12), cy + 0.12)
		R(ci, cj, 0.55)
		var la := sub(r, minf(x1 + s * 0.12, x1 + s * 0.3), cy - 0.15, maxf(x1 + s * 0.12, x1 + s * 0.3), cy + 0.15)
		R(ci, la, 0.6, 1.2)
		var coil := PackedVector2Array()
		for k in 6:
			var x: float = la.position.x + (k + 0.5) * la.size.x / 6.0
			coil.append(Vector2(x, la.position.y + 2.0))
			coil.append(Vector2(x, la.end.y - 2.0))
		S(ci, coil, 0.3)
		L(ci, Vector2(la.get_center().x, la.position.y), Vector2(la.get_center().x, _u(r, 0, 0.34).y), 0.45)
		_pu(ci, r, [Vector2(x1 + s * 0.09, cy - 0.12), Vector2(x1 + s * 0.09, 0.3), Vector2(0.5, 0.3)], 0.4, 1.3)
	E.Rc(ci, sub(r, 0.3, 0.295, 0.7, 0.305), Pal.tint(Pal.FLUID, 0.5), 1.0)
	var ct := sub(r, 0.06, 0.04, 0.38, 0.26)
	R(ci, ct, 0.58)
	E.Rc(ci, sub(r, 0.09, 0.07, 0.27, 0.13), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp_row(ci, sub(r, 0.09, 0.17, 0.35, 0.22), 4, Pal.tint(Pal.FLUID, 0.85), 4)
	E.louvres(ci, sub(r, 0.62, 0.06, 0.94, 0.24), 0.28)
	R(ci, sub(r, 0.62, 0.04, 0.94, 0.26), 0.5)


# ---------------------------------------------------------------- MED-47 / PT-34: backup generator (gas turbine set)
# a gas-turbine generator in its acoustic enclosure (cut away): the intake filter louvres and
# splitter silencer, the turbine (compressor, combustor, power turbine), the reduction
# gearbox, the alternator, the exhaust silencer and stack up through the roof
static func turbine_genset(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var en := sub(r, 0.02, 0.16, 0.98, 0.94)
	R(ci, en, 0.6, 1.3)
	R(ci, en.grow(-3.0), 0.25)
	R(ci, sub(r, 0.0, 0.94, 1.0, 1.0), 0.55)
	var il := sub(r, 0.05, 0.22, 0.17, 0.86)
	R(ci, il, 0.5)
	E.louvres(ci, il.grow(-2.0), 0.3)
	var sp := PackedVector2Array()
	for k in 3:
		var y: float = 0.32 + k * 0.18
		sp.append(_u(r, 0.19, y))
		sp.append(_u(r, 0.26, y))
	S(ci, sp, 0.4, 2.0)
	var cy: float = 0.6
	_pu(ci, r, [Vector2(0.28, cy - 0.06), Vector2(0.4, cy - 0.12), Vector2(0.5, cy - 0.12), Vector2(0.56, cy - 0.08), Vector2(0.56, cy + 0.08), Vector2(0.5, cy + 0.12), Vector2(0.4, cy + 0.12), Vector2(0.28, cy + 0.06)], 0.6, 1.2, true)
	var bl := PackedVector2Array()
	for k in 4:
		var x: float = 0.31 + k * 0.025
		var hh: float = 0.07 + k * 0.012
		bl.append(_u(r, x, cy - hh))
		bl.append(_u(r, x, cy + hh))
	S(ci, bl, 0.35)
	O(ci, _u(r, 0.45, cy - 0.12), maxf(1.6, ms * 0.035), 0.5)
	_lamp(ci, _u(r, 0.45, cy), maxf(1.6, ms * 0.05), Pal.heat(0.75))
	R(ci, sub(r, 0.57, cy - 0.1, 0.66, cy + 0.12), 0.55)
	O(ci, _u(r, 0.615, cy - 0.03), maxf(1.6, ms * 0.04), 0.4)
	O(ci, _u(r, 0.615, cy + 0.06), maxf(1.0, ms * 0.025), 0.4)
	_alternator(ci, sub(r, 0.66, cy - 0.17, 0.95, cy + 0.17), 0.55)
	_pu(ci, r, [Vector2(0.5, cy - 0.12), Vector2(0.5, 0.26)], 0.5, 1.4)
	var es := sub(r, 0.42, 0.04, 0.58, 0.26)
	R(ci, es, 0.58)
	hatch(ci, es.grow(-2.0), 2.4, false, 0.3, 10)
	R(ci, sub(r, 0.46, 0.0, 0.54, 0.04), 0.55)
	R(ci, sub(r, 0.72, 0.22, 0.94, 0.36), 0.5)
	E.Rc(ci, sub(r, 0.74, 0.25, 0.84, 0.3), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp(ci, _u(r, 0.9, 0.29), maxf(1.4, ms * 0.035), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- ES-112 / PS-12: standby set (diesel rotary UPS)
# a diesel rotary UPS: the diesel (rocker covers, turbo), the clutch, the heavy flywheel that
# rides through the gap, the motor-generator, the choke on the input, the control cabinet;
# the engine train along the bottom, the choke and controls above it
static func drups(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.94, 0.98, 1.0), 0.58, 1.2)
	var ly: float = 0.5
	_engine_side(ci, sub(r, 0.04, ly, 0.36, 0.92), 4, 0.55)
	var tc := _u(r, 0.38, ly + 0.08)
	A(ci, tc, ms * 0.06, PI * 0.5, PI * 2.0, 0.5)
	R(ci, sub(r, 0.36, ly + 0.2, 0.42, ly + 0.36), 0.55)
	hatch(ci, sub(r, 0.365, ly + 0.21, 0.415, ly + 0.35), 1.8, true, 0.35, 6)
	var fc := _u(r, 0.52, ly + 0.27)
	var fr: float = minf(r.size.y * 0.2, r.size.x * 0.1)
	O(ci, fc, fr, 0.62, 1.4)
	O(ci, fc, fr * 0.8, 0.35)
	O(ci, fc, fr * 0.25, 0.45)
	for k in 6:
		var a: float = TAU * k / 6.0
		D(ci, fc + Vector2.from_angle(a) * fr * 0.55, 0.9, 0.45)
	L(ci, _u(r, 0.42, ly + 0.28), fc - Vector2(fr, 0), 0.55, 2.0)
	_alternator(ci, sub(r, 0.62, ly + 0.08, 0.98, ly + 0.44), 0.55)
	var ch := sub(r, 0.06, 0.08, 0.36, 0.42)
	R(ci, ch, 0.55)
	for k in 3:
		var cc := Vector2(ch.position.x + (k + 0.5) * ch.size.x / 3.0, ch.get_center().y)
		R(ci, Rect2(cc - Vector2(ch.size.x * 0.12, ch.size.y * 0.32), Vector2(ch.size.x * 0.24, ch.size.y * 0.64)), 0.5)
		hatch(ci, Rect2(cc - Vector2(ch.size.x * 0.1, ch.size.y * 0.28), Vector2(ch.size.x * 0.2, ch.size.y * 0.56)), 2.0, false, 0.3, 20)
	var cb := sub(r, 0.44, 0.06, 0.96, 0.42)
	R(ci, cb, 0.6, 1.2)
	E.Rc(ci, sub(r, 0.48, 0.1, 0.7, 0.18), Pal.tint(Pal.AIR, 0.6), 1.0)
	_ups_mimic(ci, sub(r, 0.48, 0.22, 0.92, 0.32))
	_lamp_row(ci, sub(r, 0.74, 0.12, 0.92, 0.16), 3, Pal.tint(Pal.FLUID, 0.85), 3)
	E.breaker(ci, sub(r, 0.5, 0.34, 0.66, 0.4), true, 0.45)
	E.breaker(ci, sub(r, 0.72, 0.34, 0.88, 0.4), true, 0.45)
	_pu(ci, r, [Vector2(0.21, 0.42), Vector2(0.21, 0.5)], 0.5, 1.6)


# ---------------------------------------------------------------- HB-86: CO2 enrichment burner
# the greenhouse CO2 generator: the gas train (regulator, double solenoid valves), the
# burner box with its flame window, the combustion blower, the heat exchanger, the
# perforated distribution tube along the top, the CO2 sensor head
static func co2_burner(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.92, 0.98, 0.99), 0.55)
	var dt := sub(r, 0.04, 0.04, 0.96, 0.14)
	R(ci, dt, 0.55)
	for k in 14:
		D(ci, Vector2(dt.position.x + (k + 0.5) * dt.size.x / 14.0, dt.end.y + 1.5), 0.7, 0.4)
	_pu(ci, r, [Vector2(0.42, 0.14), Vector2(0.42, 0.3)], 0.5, 1.6)
	var bx := sub(r, 0.3, 0.3, 0.58, 0.9)
	R(ci, bx, 0.62, 1.2)
	var fw := sub(r, 0.36, 0.5, 0.52, 0.7)
	R(ci, fw, 0.55)
	E.Rc(ci, fw.grow(-2.0), Pal.heat(0.65), 1.0)
	_pu(ci, r, [Vector2(0.38, 0.68), Vector2(0.41, 0.58), Vector2(0.44, 0.66), Vector2(0.47, 0.56), Vector2(0.5, 0.68)], 0.55)
	var hx := sub(r, 0.6, 0.34, 0.8, 0.86)
	R(ci, hx, 0.55)
	var tb := PackedVector2Array()
	for k in 5:
		var x: float = hx.position.x + (k + 0.5) * hx.size.x / 5.0
		tb.append(Vector2(x, hx.position.y + 3.0))
		tb.append(Vector2(x, hx.end.y - 3.0))
	S(ci, tb, 0.35)
	var fc := _u(r, 0.89, 0.6)
	var fr: float = minf(r.size.x * 0.08, r.size.y * 0.2)
	E.fan(ci, fc, fr, 6, 0.5)
	L(ci, _u(r, 0.0, 0.66), _u(r, 0.06, 0.66), 0.55, 1.4)
	O(ci, _u(r, 0.1, 0.66), maxf(2.0, ms * 0.07), 0.55)
	A(ci, _u(r, 0.1, 0.56), maxf(2.0, ms * 0.07), PI, TAU, 0.5)
	for x in [0.17, 0.23]:
		R(ci, sub(r, x - 0.025, 0.56, x + 0.025, 0.66), 0.55)
		hatch(ci, sub(r, x - 0.02, 0.57, x + 0.02, 0.65), 1.8, false, 0.35, 6)
	L(ci, _u(r, 0.14, 0.7), _u(r, 0.3, 0.7), 0.5, 1.3)
	E.Rc(ci, Rect2(_u(r, 0.04, 0.7) - Vector2(0, 0.6), Vector2(r.size.x * 0.26, 1.2)), Pal.heat(0.4), 1.0)
	var sn := sub(r, 0.08, 0.22, 0.2, 0.4)
	R(ci, sn, 0.55)
	hatch(ci, sub(r, 0.1, 0.32, 0.18, 0.38), 1.8, true, 0.3, 8)
	_lamp(ci, sn.position + Vector2(sn.size.x * 0.5, sn.size.y * 0.25), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- DR-150 / HG-170: diesel generator set
# a diesel genset on its base tank: the radiator and fan at the free end, the engine (rocker
# covers, turbo, the exhaust riser to the muffler on top), the alternator and its terminal
# box, the AVR / control panel, the fuel day tank in the base frame
static func diesel_genset(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bt := sub(r, 0.02, 0.84, 0.98, 0.98)
	R(ci, bt, 0.6, 1.2)
	E.Rc(ci, sub(r, 0.04, 0.91, 0.6, 0.965), Pal.heat(0.3), 1.0)
	O(ci, _u(r, 0.8, 0.91), maxf(1.6, ms * 0.03), 0.5)
	var rd := sub(r, 0.02, 0.34, 0.12, 0.84)
	R(ci, rd, 0.58)
	hatch(ci, rd.grow(-1.5), 2.0, false, 0.32, 40)
	E.fan(ci, _u(r, 0.15, 0.58), minf(r.size.x * 0.03, r.size.y * 0.2), 5, 0.4)
	_engine_side(ci, sub(r, 0.18, 0.36, 0.56, 0.84), 4, 0.58)
	var tc := _u(r, 0.6, 0.42)
	O(ci, tc, ms * 0.06, 0.55)
	A(ci, tc, ms * 0.09, -PI * 0.5, PI * 0.6, 0.45)
	_pu(ci, r, [Vector2(0.56, 0.42), Vector2(0.6, 0.36), Vector2(0.6, 0.22)], 0.5, 1.4)
	var mf := sub(r, 0.22, 0.12, 0.66, 0.22)
	R(ci, mf, 0.58)
	for x in [0.3, 0.44, 0.58]:
		L(ci, _u(r, x, 0.12), _u(r, x, 0.22), 0.3)
	L(ci, _u(r, 0.24, 0.12), _u(r, 0.24, 0.02), 0.55, 1.6)
	_alternator(ci, sub(r, 0.62, 0.44, 0.98, 0.84), 0.55)
	var cp := sub(r, 0.72, 0.06, 0.96, 0.36)
	R(ci, cp, 0.55)
	E.gauge(ci, _u(r, 0.8, 0.15), maxf(2.5, ms * 0.06), 0.5)
	E.gauge(ci, _u(r, 0.9, 0.15), maxf(2.5, ms * 0.06), 0.5)
	_lamp_row(ci, sub(r, 0.75, 0.25, 0.93, 0.29), 3, Pal.tint(Pal.FLUID, 0.85), 0)
	L(ci, _u(r, 0.84, 0.36), _u(r, 0.84, 0.44), 0.45, 1.3)


# ---------------------------------------------------------------- GR-7: main power module (radioisotope)
# the small ship's radioisotope power module: the finned converter shell, the heat-source
# modules stacked inside (cut away), the thermocouple rows, the coolant jacket and its two
# lines, the trefoil, the output cable, its mounting saddles
static func rtg_module(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sh := sub(r, 0.2, 0.14, 0.8, 0.86)
	R(ci, sh, 0.62, 1.3)
	var fins := PackedVector2Array()
	for k in 7:
		var y: float = 0.2 + k * 0.1
		fins.append(_u(r, 0.06, y))
		fins.append(_u(r, 0.2, y))
		fins.append(_u(r, 0.8, y))
		fins.append(_u(r, 0.94, y))
	S(ci, fins, 0.5, 1.4)
	var core := sub(r, 0.36, 0.22, 0.64, 0.78)
	R(ci, core, 0.5)
	for k in 3:
		var hs := sub(r, 0.39, 0.25 + k * 0.175, 0.61, 0.4 + k * 0.175)
		R(ci, hs, 0.5)
		E.Rc(ci, hs.grow(-2.0), Pal.heat(0.45), 1.0)
	var tcs := PackedVector2Array()
	for k in 10:
		var y: float = 0.24 + k * 0.055
		tcs.append(_u(r, 0.25, y))
		tcs.append(_u(r, 0.33, y))
		tcs.append(_u(r, 0.67, y))
		tcs.append(_u(r, 0.75, y))
	S(ci, tcs, 0.28)
	for y in [0.3, 0.7]:
		L(ci, _u(r, 0.8, y), _u(r, 1.0, y), 0.55, 1.5)
		E.flange(ci, _u(r, 0.94, y), Vector2.RIGHT, maxf(2.0, ms * 0.04), 0.5)
	var tf := _u(r, 0.5, 0.06)
	var tr: float = maxf(3.0, ms * 0.06)
	D(ci, tf, tr * 0.25, 0.6)
	for k in 3:
		A(ci, tf, tr, -PI * 0.5 + k * TAU / 3.0 - 0.5, -PI * 0.5 + k * TAU / 3.0 + 0.5, 0.6, 1.5)
	L(ci, _u(r, 0.5, 0.86), _u(r, 0.5, 0.98), 0.55, 1.6)
	for x in [0.28, 0.72]:
		_pu(ci, r, [Vector2(x - 0.08, 0.98), Vector2(x - 0.05, 0.86), Vector2(x + 0.05, 0.86), Vector2(x + 0.08, 0.98)], 0.5)


# ---------------------------------------------------------------- the main generator (ARK-01, CH-110, IC-120, MD-160, MT-140, TB-180)
# a large alternator on its bed: the ribbed stator frame, the bearing pedestals and the shaft
# from the prime mover with its coupling guard, the exciter, the air-to-water cooler on top
# (tubes, water in and out), the line terminal box with its three cables, anchor bolts
static func main_alternator(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.9, 0.98, 0.97), 0.6, 1.3)
	for x in [0.06, 0.34, 0.66, 0.94]:
		D(ci, _u(r, x, 0.935), 1.2, 0.6)
	var cy: float = 0.62
	var fr := sub(r, 0.18, 0.36, 0.78, 0.88)
	R(ci, fr, 0.62, 1.4)
	var rib := PackedVector2Array()
	var n := clampi(int(fr.size.x / 6.0), 6, 40)
	for k in n:
		var x: float = fr.position.x + (k + 0.5) * fr.size.x / n
		rib.append(Vector2(x, fr.position.y + 3.0))
		rib.append(Vector2(x, fr.end.y - 3.0))
	S(ci, rib, 0.22)
	for x in [0.12, 0.84]:
		R(ci, sub(r, x - 0.035, cy - 0.1, x + 0.035, 0.9), 0.55)
		O(ci, _u(r, x, cy), maxf(2.0, ms * 0.04), 0.5)
	L(ci, _u(r, 0.0, cy), _u(r, 0.18, cy), 0.6, 2.4)
	R(ci, sub(r, 0.0, cy - 0.07, 0.08, cy + 0.07), 0.45)
	R(ci, sub(r, 0.88, cy - 0.14, 0.98, cy + 0.14), 0.55)
	hatch(ci, sub(r, 0.89, cy - 0.12, 0.97, cy + 0.12), 2.2, true, 0.3, 10)
	var cl := sub(r, 0.24, 0.12, 0.72, 0.36)
	R(ci, cl, 0.58)
	var tubes := PackedVector2Array()
	for k in 5:
		var y: float = cl.position.y + (k + 0.5) * cl.size.y / 5.0
		tubes.append(Vector2(cl.position.x + 3.0, y))
		tubes.append(Vector2(cl.end.x - 3.0, y))
	S(ci, tubes, 0.3)
	E.Rc(ci, Rect2(cl.position + Vector2(3.0, cl.size.y * 0.45), Vector2(cl.size.x - 6.0, 1.0)), Pal.tint(Pal.FLUID, 0.5), 1.0)
	for x in [0.32, 0.64]:
		L(ci, _u(r, x, 0.12), _u(r, x, 0.02), 0.55, 1.5)
		E.flange(ci, _u(r, x, 0.06), Vector2.UP, maxf(2.0, ms * 0.03), 0.5)
	var tb := sub(r, 0.76, 0.2, 0.92, 0.36)
	R(ci, tb, 0.58)
	for k in 3:
		var x: float = 0.79 + k * 0.05
		D(ci, _u(r, x, 0.3), 1.2, 0.6)
		L(ci, _u(r, x, 0.2), _u(r, x, 0.02), 0.55, 1.8)
	R(ci, sub(r, 0.4, 0.74, 0.56, 0.82), 0.4)


# ---------------------------------------------------------------- TS-1: main power module
# the training ship's compact power module: two converter bricks on their heat sink, the
# capacitor bank, the bus terminals and the main breaker, the status lamps
static func ts_power(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.04, 0.08, 0.96, 0.92)
	R(ci, bx, 0.62, 1.2)
	hatch(ci, sub(r, 0.08, 0.12, 0.92, 0.22), 2.2, true, 0.32, 30)
	for k in 2:
		var bk := sub(r, 0.08 + k * 0.22, 0.26, 0.28 + k * 0.22, 0.56)
		R(ci, bk, 0.55)
		L(ci, bk.position + Vector2(2, bk.size.y * 0.3), Vector2(bk.end.x - 2, bk.position.y + bk.size.y * 0.3), 0.35)
		_lamp(ci, bk.position + Vector2(bk.size.x * 0.5, bk.size.y * 0.7), maxf(1.2, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	for k in 3:
		D(ci, _u(r, 0.62 + k * 0.1, 0.36), maxf(1.6, ms * 0.04), 0.5)
		D(ci, _u(r, 0.62 + k * 0.1, 0.48), maxf(1.6, ms * 0.04), 0.5)
	E.breaker(ci, sub(r, 0.1, 0.62, 0.46, 0.86), true, 0.5)
	for k in 2:
		var tp := _u(r, 0.62 + k * 0.18, 0.74)
		R(ci, Rect2(tp - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), 0.55)
		D(ci, tp, 1.0, 0.6)
	L(ci, _u(r, 0.71, 0.74), _u(r, 0.71, 0.92), 0.5, 1.6)


# ================================================================== fifth batch (online catalog, 2026-11-12)
# fifty-five kinds the user ticked in the online 图鉴: the panels, modules, chargers and small
# packs that still drew as the shared panel / module / charger / battery

# a wall-mounted box: the frame, its four fixing screws, the cable gland under it; returns the face
static func _wallbox(ci: CanvasItem, r: Rect2, x0: float = 0.08, y0: float = 0.06, x1: float = 0.92, y1: float = 0.9) -> Rect2:
	var b := sub(r, x0, y0, x1, y1)
	R(ci, b, 0.62, 1.2)
	var ins: float = minf(3.0, minf(b.size.x, b.size.y) * 0.12)
	E.corner_bolts(ci, b, ins, 0.45)
	var gx: float = b.get_center().x
	L(ci, Vector2(gx, b.end.y), Vector2(gx, r.end.y), 0.5, 1.4)
	R(ci, Rect2(Vector2(gx - 2.0, b.end.y), Vector2(4.0, minf(3.0, r.end.y - b.end.y))), 0.5)
	return b


# a bowtie valve symbol on a line at c, size s
static func _bowtie(ci: CanvasItem, c: Vector2, s: float, vertical: bool = false, al: float = 0.55) -> void:
	if vertical:
		P(ci, PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(-s, s), c + Vector2(s, s), c + Vector2(-s, -s)]), al)
	else:
		P(ci, PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, s), c + Vector2(s, -s), c + Vector2(-s, s), c + Vector2(-s, -s)]), al)


# a guarded toggle: the switch body, its lever, the flip guard
static func _toggle(ci: CanvasItem, c: Vector2, s: float, up: bool = true, guard: bool = false) -> void:
	O(ci, c, s * 0.6, 0.5)
	L(ci, c, c + Vector2(s * 0.3, -s * 1.3 if up else s * 1.3), 0.6, 1.4)
	if guard:
		P(ci, PackedVector2Array([c + Vector2(-s, s * 0.6), c + Vector2(-s, -s * 1.6), c + Vector2(s, -s * 1.6), c + Vector2(s, s * 0.6)]), 0.45)


# ---------------------------------------------------------------- VT-80: auxiliary power unit
# a monopropellant APU on its skid: the propellant feed through its isolation valves and filter
# into the gas generator (catalyst bed), the turbine wheel in its scroll, the exhaust duct up
# and out, the reduction gearbox with the hydraulic pump under it, the alternator, the lube
# tank and cooler, the controller
static func apu_mono(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.92, 0.98, 0.98), 0.6, 1.3)
	for x in [0.08, 0.36, 0.64, 0.92]:
		D(ci, _u(r, x, 0.95), 1.2, 0.6)
	# feed
	L(ci, _u(r, 0.0, 0.2), _u(r, 0.14, 0.2), 0.55, 1.4)
	for x in [0.04, 0.09]:
		_bowtie(ci, _u(r, x, 0.2), maxf(2.0, ms * 0.025))
	R(ci, sub(r, 0.11, 0.16, 0.15, 0.26), 0.5)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.2) - Vector2(0, 0.6), Vector2(r.size.x * 0.11, 1.2)), Pal.tint(Pal.FLUID, 0.5), 1.0)
	# gas generator
	var gg := sub(r, 0.14, 0.22, 0.24, 0.62)
	R(ci, gg, 0.62, 1.2)
	hatch(ci, sub(r, 0.15, 0.3, 0.23, 0.44), 2.0, false, 0.35, 12)
	E.Rc(ci, sub(r, 0.155, 0.46, 0.225, 0.6), Pal.heat(0.4), 1.0)
	_pu(ci, r, [Vector2(0.14, 0.2), Vector2(0.19, 0.2), Vector2(0.19, 0.22)], 0.5, 1.3)
	# turbine
	var tc := _u(r, 0.34, 0.5)
	var tr: float = ms * 0.16
	O(ci, tc, tr, 0.62, 1.3)
	E.impeller(ci, tc, tr * 0.75, 0.45)
	L(ci, _u(r, 0.24, 0.5), tc - Vector2(tr, 0), 0.55, 1.6)
	_pu(ci, r, [Vector2(0.3, 0.35), Vector2(0.3, 0.06), Vector2(0.46, 0.0)], 0.55, 1.5)
	_pu(ci, r, [Vector2(0.38, 0.35), Vector2(0.38, 0.1), Vector2(0.5, 0.06)], 0.55, 1.5)
	# gearbox, hydraulic pump
	var gb := sub(r, 0.44, 0.36, 0.58, 0.66)
	R(ci, gb, 0.6, 1.2)
	O(ci, _u(r, 0.51, 0.44), ms * 0.04, 0.45)
	O(ci, _u(r, 0.51, 0.58), ms * 0.06, 0.45)
	L(ci, tc + Vector2(tr, 0), Vector2(gb.position.x, tc.y), 0.55, 1.8)
	var hp := sub(r, 0.46, 0.7, 0.58, 0.88)
	R(ci, hp, 0.55)
	hatch(ci, hp.grow(-2.0), 2.4, true, 0.3, 10)
	L(ci, _u(r, 0.52, 0.66), _u(r, 0.52, 0.7), 0.55, 1.6)
	_alternator(ci, sub(r, 0.6, 0.3, 0.98, 0.72), 0.58)
	# lube tank, cooler, controller
	var lt := sub(r, 0.04, 0.68, 0.24, 0.9)
	R(ci, lt, 0.55)
	E.Rc(ci, sub(r, 0.05, 0.8, 0.23, 0.89), Pal.heat(0.25), 1.0)
	L(ci, _u(r, 0.05, 0.8), _u(r, 0.23, 0.8), 0.35)
	var cl := sub(r, 0.27, 0.7, 0.42, 0.9)
	R(ci, cl, 0.5)
	hatch(ci, cl.grow(-1.5), 2.0, false, 0.3, 14)
	var cb := sub(r, 0.62, 0.06, 0.95, 0.24)
	R(ci, cb, 0.58)
	E.Rc(ci, sub(r, 0.65, 0.09, 0.8, 0.15), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp_row(ci, sub(r, 0.65, 0.18, 0.92, 0.22), 4, Pal.tint(Pal.FLUID, 0.85), 4)


# ---------------------------------------------------------------- S-09: battery pack
# the shuttle's little sealed pack: the case and its lid ridge, the two posts (positive
# capped orange), the cell dividers, the tie-down strap across it, the vent plug
static func s_bat(ci: CanvasItem, r: Rect2) -> void:
	var bx := sub(r, 0.06, 0.26, 0.94, 0.96)
	R(ci, bx, 0.62, 1.2)
	L(ci, _u(r, 0.06, 0.36), _u(r, 0.94, 0.36), 0.4)
	for x in [0.28, 0.5, 0.72]:
		L(ci, _u(r, x, 0.4), _u(r, x, 0.92), 0.25)
	for k in 2:
		var x: float = 0.2 + k * 0.6
		R(ci, sub(r, x - 0.06, 0.12, x + 0.06, 0.26), 0.6)
		if k == 0:
			E.Rc(ci, sub(r, x - 0.05, 0.13, x + 0.05, 0.2), Pal.heat(0.8), 1.0)
	L(ci, _u(r, 0.0, 0.62), _u(r, 1.0, 0.62), 0.5, 1.6)
	R(ci, sub(r, 0.44, 0.57, 0.56, 0.67), 0.55)
	D(ci, _u(r, 0.5, 0.31), 1.0, 0.5)


# ---------------------------------------------------------------- SP-ISOLATE: lock backup supply
# the isolation pod's lock backup: a square wall box, lid hinged open on the left showing two
# round cells in their holder and the little charger board, the key switch and lamp on the
# lid, the cable to the lock out of the gland
static func lock_backup_box(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.3, 0.08, 0.94, 0.86)
	for k in 2:
		var c := _u(r, 0.48 + k * 0.22, 0.32)
		O(ci, c, ms * 0.09, 0.55)
		O(ci, c, ms * 0.03, 0.45)
	R(ci, sub(r, 0.38, 0.5, 0.86, 0.78), 0.45)
	for k in 4:
		R(ci, sub(r, 0.42 + k * 0.1, 0.58, 0.48 + k * 0.1, 0.66), 0.35)
	_pu(ci, r, [Vector2(0.3, 0.08), Vector2(0.06, 0.14), Vector2(0.06, 0.8), Vector2(0.3, 0.86)], 0.55, 1.2)
	var kc := _u(r, 0.18, 0.36)
	O(ci, kc, ms * 0.06, 0.55)
	L(ci, kc - Vector2(0, ms * 0.035), kc + Vector2(0, ms * 0.035), 0.6, 1.2)
	_lamp(ci, _u(r, 0.18, 0.6), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- ARK-01: work vehicle charger
# a charging post for the work vehicles: the pedestal and plinth, the screen and card pad,
# the lamp ring, the charge lead coiled on its hook and the plug in its holster
static func charge_post(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.92, 0.94, 0.99), 0.58, 1.2)
	_pu(ci, r, [Vector2(0.24, 0.92), Vector2(0.24, 0.1), Vector2(0.3, 0.04), Vector2(0.7, 0.04), Vector2(0.76, 0.1), Vector2(0.76, 0.92)], 0.62, 1.3)
	E.Rc(ci, sub(r, 0.32, 0.12, 0.68, 0.26), Pal.tint(Pal.AIR, 0.6), 1.0)
	R(ci, sub(r, 0.38, 0.3, 0.62, 0.38), 0.45)
	O(ci, _u(r, 0.5, 0.34), ms * 0.04, 0.35)
	var rc := _u(r, 0.5, 0.5)
	for k in 8:
		var a: float = TAU * k / 8.0
		_lamp(ci, rc + Vector2.from_angle(a) * ms * 0.11, 1.4, Pal.tint(Pal.FLUID, 0.8) if k < 5 else Pal.ink(0.3))
	R(ci, sub(r, 0.36, 0.64, 0.64, 0.74), 0.55)
	D(ci, _u(r, 0.5, 0.69), 1.2, 0.6)
	L(ci, _u(r, 0.76, 0.5), _u(r, 0.86, 0.5), 0.55, 1.4)
	for k in 3:
		_ell(ci, _u(r, 0.86 + k * 0.015, 0.62), r.size.x * 0.1, r.size.y * 0.1, 0.45, 1.3)
	_pu(ci, r, [Vector2(0.5, 0.74), Vector2(0.5, 0.8), Vector2(0.82, 0.86), Vector2(0.86, 0.72)], 0.45, 1.3)


# ---------------------------------------------------------------- CV-138: drone bay charging module
# a drone bay's charger: the rectifier cabinet (fans, lamps, output meter) on the wall, the
# boom with the spring reel and the lead down to the docking plug, the inductive floor pad
# with its coil, the contact guides
static func bay_charger(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cb := sub(r, 0.02, 0.06, 0.34, 0.86)
	R(ci, cb, 0.62, 1.2)
	for k in 2:
		E.fan(ci, _u(r, 0.12 + k * 0.13, 0.2), minf(r.size.x * 0.05, r.size.y * 0.07), 5, 0.42)
	E.Rc(ci, sub(r, 0.06, 0.34, 0.3, 0.42), Pal.tint(Pal.AIR, 0.6), 1.0)
	E.gauge(ci, _u(r, 0.12, 0.54), maxf(3.0, ms * 0.07), 0.5)
	_lamp_row(ci, sub(r, 0.2, 0.5, 0.31, 0.58), 3, Pal.tint(Pal.FLUID, 0.85), 3)
	E.louvres(ci, sub(r, 0.06, 0.66, 0.3, 0.82), 0.28)
	# boom, reel, lead, plug
	L(ci, _u(r, 0.34, 0.12), _u(r, 0.86, 0.12), 0.6, 1.8)
	L(ci, _u(r, 0.34, 0.2), _u(r, 0.5, 0.12), 0.45, 1.2)
	var rc := _u(r, 0.72, 0.18)
	O(ci, rc, ms * 0.07, 0.55)
	O(ci, rc, ms * 0.03, 0.4)
	_pu(ci, r, [Vector2(0.72, 0.25), Vector2(0.72, 0.5), Vector2(0.7, 0.52), Vector2(0.74, 0.55), Vector2(0.72, 0.58)], 0.5, 1.3)
	R(ci, sub(r, 0.68, 0.58, 0.76, 0.66), 0.6)
	# floor pad, coil, guides
	var pd := sub(r, 0.4, 0.86, 0.98, 0.97)
	R(ci, pd, 0.6, 1.2)
	var pc := pd.get_center()
	for k in 3:
		_ell(ci, pc, pd.size.x * (0.14 + k * 0.1), pd.size.y * (0.15 + k * 0.1), 0.35)
	for x in [0.44, 0.94]:
		_pu(ci, r, [Vector2(x, 0.86), Vector2(x, 0.76), Vector2(x + (0.03 if x < 0.5 else -0.03), 0.72)], 0.5, 1.3)


# ---------------------------------------------------------------- TB-180: tether brake frame
# the tether brake's frame: the truss (chords, diagonals), the two brake drums with their
# calipers and pads, the tether run over the guide sheaves through the frame, the hydraulic
# cylinders that set the brake, the anchor feet
static func tether_brake_frame(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.0, 0.06), _u(r, 1.0, 0.06), 0.6, 1.8)
	L(ci, _u(r, 0.0, 0.94), _u(r, 1.0, 0.94), 0.6, 1.8)
	var tr := PackedVector2Array()
	var n := clampi(int(r.size.x / 40.0), 4, 12)
	for k in n + 1:
		var x: float = k / float(n)
		tr.append(_u(r, x, 0.06))
		tr.append(_u(r, x, 0.94))
		if k < n:
			tr.append(_u(r, x, 0.06 if k % 2 == 0 else 0.94))
			tr.append(_u(r, x + 1.0 / n, 0.94 if k % 2 == 0 else 0.06))
	S(ci, tr, 0.3)
	for x in [0.3, 0.7]:
		var c := _u(r, x, 0.5)
		var dr: float = ms * 0.3
		O(ci, c, dr, 0.62, 1.4)
		O(ci, c, dr * 0.85, 0.35)
		O(ci, c, dr * 0.2, 0.5)
		for s in [-1.0, 1.0]:
			var cp := c + Vector2(0, s * dr * 1.05)
			R(ci, Rect2(cp - Vector2(dr * 0.4, ms * 0.04), Vector2(dr * 0.8, ms * 0.08)), 0.6)
			L(ci, cp + Vector2(dr * 0.4, 0), cp + Vector2(dr * 0.9, 0), 0.55, 1.6)
			R(ci, Rect2(cp + Vector2(dr * 0.9, -ms * 0.03), Vector2(dr * 0.45, ms * 0.06)), 0.55)
	var ty: float = _u(r, 0, 0.5).y - ms * 0.3
	L(ci, _u(r, 0.0, 0.5) + Vector2(0, -ms * 0.3), Vector2(r.end.x, ty), 0.62, 2.2)
	for x in [0.08, 0.5, 0.92]:
		O(ci, Vector2(_u(r, x, 0).x, ty - ms * 0.06), ms * 0.06, 0.5)
	for x in [0.04, 0.96]:
		R(ci, sub(r, x - 0.03, 0.94, x + 0.03, 1.0), 0.55)


# ---------------------------------------------------------------- E-07: wall socket
# a wall socket plate: two outlets (their pins), the rocker switch, the screws
static func wall_socket(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := sub(r, 0.1, 0.04, 0.9, 0.96)
	R(ci, b, 0.62, 1.2)
	for y in [0.3, 0.62]:
		var c := _u(r, 0.5, y)
		R(ci, Rect2(c - Vector2(r.size.x * 0.28, r.size.y * 0.1), Vector2(r.size.x * 0.56, r.size.y * 0.2)), 0.5)
		D(ci, c - Vector2(r.size.x * 0.12, 0), 0.8, 0.6)
		D(ci, c + Vector2(r.size.x * 0.12, 0), 0.8, 0.6)
	R(ci, sub(r, 0.3, 0.8, 0.7, 0.9), 0.55)
	_lamp(ci, _u(r, 0.5, 0.85), maxf(1.0, ms * 0.25), Pal.tint(Pal.FLUID, 0.8))
	D(ci, _u(r, 0.5, 0.1), 0.8, 0.5)


# ---------------------------------------------------------------- IC-120: lifting saddle
# a lifting saddle for the hold's loads: the curved saddle face and its rubber liner, the
# base plate and its bolts, the side lifting lugs, the load cell under the cradle
static func lift_saddle(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cc := _u(r, 0.5, -0.5)
	var rad: float = cc.distance_to(_u(r, 0.5, 0.42))
	var a0: float = asin(clampf(r.size.x * 0.42 / rad, -1.0, 1.0))
	var inner := PackedVector2Array()
	var liner := PackedVector2Array()
	for k in 13:
		var a: float = PI * 0.5 + lerpf(a0, -a0, k / 12.0)
		inner.append(cc + Vector2.from_angle(a) * rad)
		liner.append(cc + Vector2.from_angle(a) * (rad - ms * 0.05))
	P(ci, inner, 0.62, 1.4)
	P(ci, liner, 0.4)
	var hs := PackedVector2Array()
	for k in 12:
		hs.append(liner[k])
		hs.append(inner[k + 1])
	S(ci, hs, 0.25)
	P(ci, PackedVector2Array([inner[0], _u(r, 0.06, 0.72), _u(r, 0.94, 0.72), inner[12]]), 0.58, 1.2)
	R(ci, sub(r, 0.4, 0.72, 0.6, 0.86), 0.55)
	hatch(ci, sub(r, 0.42, 0.74, 0.58, 0.84), 2.0, true, 0.3, 10)
	_pu(ci, r, [Vector2(0.43, 0.84), Vector2(0.43, 0.88)], 0.4)
	R(ci, sub(r, 0.02, 0.88, 0.98, 0.98), 0.6, 1.3)
	for x in [0.08, 0.3, 0.7, 0.92]:
		D(ci, _u(r, x, 0.93), 1.2, 0.6)
	for x in [0.06, 0.94]:
		var lc := _u(r, x, 0.52)
		O(ci, lc, ms * 0.07, 0.58, 1.3)
		O(ci, lc, ms * 0.03, 0.45)


# ---------------------------------------------------------------- TB-180: tether root anchor
# the tether's root: the anchor block bolted to the deck, the clevis and its pin, the swivel,
# the braided tether going up out of its strain-relief cone
static func tether_root(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.84, 0.96, 0.98), 0.62, 1.3)
	for x in [0.14, 0.86]:
		D(ci, _u(r, x, 0.91), 1.4, 0.6)
	_pu(ci, r, [Vector2(0.16, 0.84), Vector2(0.24, 0.64), Vector2(0.76, 0.64), Vector2(0.84, 0.84)], 0.6, 1.2)
	for x in [0.32, 0.68]:
		R(ci, sub(r, x - 0.06, 0.5, x + 0.06, 0.64), 0.58)
	var pc := _u(r, 0.5, 0.56)
	L(ci, _u(r, 0.22, 0.56), _u(r, 0.78, 0.56), 0.62, 2.0)
	D(ci, pc, 1.4, 0.6)
	R(ci, sub(r, 0.4, 0.4, 0.6, 0.5), 0.58)
	O(ci, _u(r, 0.5, 0.36), ms * 0.08, 0.55)
	_pu(ci, r, [Vector2(0.38, 0.3), Vector2(0.44, 0.2), Vector2(0.56, 0.2), Vector2(0.62, 0.3)], 0.55, 1.2)
	var br := PackedVector2Array()
	for k in 10:
		var y: float = 0.2 - k * 0.022
		br.append(_u(r, 0.44, y))
		br.append(_u(r, 0.56, y - 0.02))
	S(ci, br, 0.45)
	L(ci, _u(r, 0.44, 0.2), _u(r, 0.44, 0.0), 0.55, 1.4)
	L(ci, _u(r, 0.56, 0.2), _u(r, 0.56, 0.0), 0.55, 1.4)


# ---------------------------------------------------------------- TS-1: tank bracket
# a tank's support bracket: the cradle hugging the tank, the strap round it with its
# tensioning bolt, the base and its two bolts
static func tank_bracket(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var tc := _u(r, 0.5, 0.0)
	var tr: float = r.size.x * 0.4
	A(ci, tc, tr, 0.15, PI - 0.15, 0.62, 1.4)
	A(ci, tc, tr + ms * 0.1, 0.25, PI - 0.25, 0.45)
	P(ci, PackedVector2Array([_u(r, 0.14, 0.4), _u(r, 0.2, 0.86), _u(r, 0.8, 0.86), _u(r, 0.86, 0.4)]), 0.58, 1.2)
	L(ci, _u(r, 0.02, 0.88), _u(r, 0.98, 0.88), 0.6, 1.4)
	for x in [0.1, 0.9]:
		D(ci, _u(r, x, 0.94), 1.0, 0.6)
	R(ci, sub(r, 0.84, 0.18, 0.96, 0.34), 0.55)


# ---------------------------------------------------------------- E-07 / TS-1: small manifold
# a small vertical header: the header pipe, three branches each with its valve and handle,
# the gauge on top, the drain cap below, the wall clamps
static func small_manifold(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var hx: float = 0.36
	R(ci, sub(r, hx - 0.1, 0.16, hx + 0.1, 0.88), 0.62, 1.2)
	E.gauge(ci, _u(r, hx, 0.08), maxf(2.5, ms * 0.14), 0.55)
	R(ci, sub(r, hx - 0.07, 0.88, hx + 0.07, 0.95), 0.55)
	for k in 3:
		var y: float = 0.3 + k * 0.2
		L(ci, _u(r, hx + 0.1, y), _u(r, 1.0, y), 0.55, 1.3)
		_bowtie(ci, _u(r, 0.68, y), maxf(1.8, ms * 0.07))
		L(ci, _u(r, 0.68, y), _u(r, 0.68, y - 0.07), 0.45)
		L(ci, _u(r, 0.6, y - 0.07), _u(r, 0.76, y - 0.07), 0.55, 1.3)
	for y in [0.22, 0.82]:
		L(ci, _u(r, 0.0, y), _u(r, hx - 0.1, y), 0.45, 1.3)


# ---------------------------------------------------------------- ARK-01: busbar tap-off box
# the riser's tap-off box: the three phase bars and the neutral running up behind the clear
# cover on their insulators, two tap-off units with their fuse carriers, the cable outlets
static func busbar_box(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.06, 0.02, 0.94, 0.96)
	for k in 4:
		var x: float = 0.2 + k * 0.1
		L(ci, _u(r, x, 0.0), _u(r, x, 0.98), 0.55 if k < 3 else 0.35, 2.4 if k < 3 else 1.4)
		for y in [0.18, 0.5, 0.82]:
			R(ci, Rect2(_u(r, x, y) - Vector2(2.5, 1.5), Vector2(5.0, 3.0)), 0.4)
	for k in 2:
		var t := sub(r, 0.56, 0.14 + k * 0.4, 0.9, 0.44 + k * 0.4)
		R(ci, t, 0.55)
		for j in 3:
			var f := Rect2(t.position + Vector2(t.size.x * (0.12 + j * 0.28), t.size.y * 0.2), Vector2(t.size.x * 0.2, t.size.y * 0.45))
			R(ci, f, 0.45)
			L(ci, f.position + Vector2(f.size.x * 0.5, 2.0), f.position + Vector2(f.size.x * 0.5, f.size.y - 2.0), 0.5)
		_lamp(ci, t.position + Vector2(t.size.x * 0.5, t.size.y * 0.82), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
		L(ci, Vector2(t.end.x, t.get_center().y), Vector2(r.end.x, t.get_center().y), 0.55, 1.6)
	L(ci, _u(r, 0.12, 0.04), _u(r, 0.52, 0.04), 0.25)


# ---------------------------------------------------------------- ARK-01: irrigation controller
# the farm ring's irrigation controller: the schedule dial and the readout, the moisture
# lead, and below it the zone valves on their manifold with the water through it
static func irrigation_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := sub(r, 0.08, 0.04, 0.92, 0.56)
	R(ci, b, 0.62, 1.2)
	var dc := _u(r, 0.34, 0.28)
	var dr: float = ms * 0.2
	O(ci, dc, dr, 0.58)
	var tk := PackedVector2Array()
	for k in 12:
		var a: float = TAU * k / 12.0
		tk.append(dc + Vector2.from_angle(a) * dr * 0.78)
		tk.append(dc + Vector2.from_angle(a) * dr * (0.92 if k % 3 else 1.0))
	S(ci, tk, 0.4)
	A(ci, dc, dr * 0.6, -0.5, 1.4, 0.55, 2.0)
	L(ci, dc, dc + Vector2.from_angle(0.9) * dr * 0.7, 0.6)
	E.Rc(ci, sub(r, 0.6, 0.12, 0.86, 0.22), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp_row(ci, sub(r, 0.6, 0.3, 0.86, 0.36), 4, Pal.tint(Pal.FLUID, 0.85), 3)
	_pu(ci, r, [Vector2(0.86, 0.44), Vector2(0.98, 0.44), Vector2(0.98, 0.56)], 0.4)
	# manifold and zone valves
	L(ci, _u(r, 0.0, 0.86), _u(r, 1.0, 0.86), 0.58, 1.6)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.86) - Vector2(0, 0.6), Vector2(r.size.x, 1.2)), Pal.tint(Pal.FLUID, 0.55), 1.0)
	for k in 4:
		var x: float = 0.16 + k * 0.22
		_bowtie(ci, _u(r, x, 0.86), maxf(2.0, ms * 0.05))
		R(ci, sub(r, x - 0.05, 0.68, x + 0.05, 0.8), 0.5)
		hatch(ci, sub(r, x - 0.04, 0.7, x + 0.04, 0.78), 1.8, false, 0.3, 6)
		L(ci, _u(r, x, 0.8), _u(r, x, 0.86), 0.45)
		L(ci, _u(r, x, 0.56), _u(r, x, 0.68), 0.25)
		L(ci, _u(r, x, 0.9), _u(r, x, 1.0), 0.45)


# ---------------------------------------------------------------- ARK-01: lift call panel
# the lift landing's call panel: the floor indicator above, the up and down buttons with
# their arrows (up lit), the plate screws
static func lift_call(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.12, 0.04, 0.88, 0.96), 0.62, 1.2)
	E.Rc(ci, sub(r, 0.24, 0.1, 0.76, 0.28), Pal.tint(Pal.AIR, 0.6), 1.0)
	L(ci, _u(r, 0.4, 0.19), _u(r, 0.6, 0.19), 0.5)
	for k in 2:
		var c := _u(r, 0.5, 0.48 + k * 0.28)
		var br: float = ms * 0.15
		O(ci, c, br, 0.58, 1.2)
		var s: float = br * 0.5 * (1.0 if k == 0 else -1.0)
		P(ci, PackedVector2Array([c + Vector2(-absf(s), s * 0.6), c + Vector2(0, -s * 0.8), c + Vector2(absf(s), s * 0.6), c + Vector2(-absf(s), s * 0.6)]), 0.6)
		if k == 0:
			_lamp(ci, c, br * 0.9, Pal.tint(Pal.FLUID, 0.55))
	for y in [0.08, 0.92]:
		D(ci, _u(r, 0.5, y), 0.8, 0.45)


# ---------------------------------------------------------------- ARK-01: lower-deck standby distribution
# the standby distribution board: the automatic changeover switch (big rotary, normal/standby
# lamps), rows of miniature breakers on their rails (one tripped), the incomer meter, the
# outgoing cable glands
static func standby_dist(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _carcass(ci, r, 0.06, 0.03, 0.94, 0.96)
	var cs := sub(r, 0.12, 0.07, 0.88, 0.3)
	R(ci, cs, 0.55)
	var rc := _u(r, 0.36, 0.185)
	var rr: float = minf(cs.size.y * 0.4, cs.size.x * 0.18)
	O(ci, rc, rr, 0.6, 1.3)
	L(ci, rc - Vector2.from_angle(0.6) * rr * 1.1, rc + Vector2.from_angle(0.6) * rr * 1.1, 0.62, 2.2)
	_lamp(ci, _u(r, 0.62, 0.14), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_lamp(ci, _u(r, 0.62, 0.24), maxf(1.4, ms * 0.04), Pal.ink(0.35))
	E.gauge(ci, _u(r, 0.78, 0.185), maxf(2.5, ms * 0.07), 0.5)
	for row in 4:
		var y0: float = 0.34 + row * 0.13
		L(ci, _u(r, 0.12, y0 + 0.055), _u(r, 0.88, y0 + 0.055), 0.3, 1.4)
		var n := clampi(int(r.size.x * 0.7 / 7.0), 4, 12)
		for k in n:
			var x0: float = 0.14 + k * 0.72 / n
			E.breaker(ci, sub(r, x0, y0, x0 + 0.72 / n - 0.01, y0 + 0.11), not (row == 2 and k == 3), 0.45)
	for k in 5:
		var x: float = 0.18 + k * 0.16
		R(ci, sub(r, x - 0.03, 0.9, x + 0.03, 0.96), 0.45)


# ---------------------------------------------------------------- ARK-01: room control panel (96 of them)
# a compartment's local panel: the small status screen, the lighting dimmer, three guarded
# toggles (doors, vent, alarm), the intercom grille and its call button
static func room_panel(ci: CanvasItem, r: Rect2) -> void:
	# kept to the old panel's weight or less: ARK-01 carries 95 of these (one batched
	# stroke list, one frame, one screen, one lamp)
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.08, 0.04, 0.92, 0.9), 0.62, 1.2)
	var sc := sub(r, 0.16, 0.1, 0.84, 0.32)
	E.Rc(ci, sc, Pal.tint(Pal.AIR, 0.55), 1.0)
	var sl := PackedVector2Array()
	for k in 2:
		var y: float = sc.position.y + sc.size.y * (0.35 + k * 0.3)
		sl.append(Vector2(sc.position.x + 3.0, y))
		sl.append(Vector2(sc.position.x + sc.size.x * (0.45 + 0.25 * k), y))
	var dc := _u(r, 0.3, 0.47)
	sl.append(dc - Vector2.from_angle(-0.9) * ms * 0.06)
	sl.append(dc + Vector2.from_angle(-0.9) * ms * 0.1)
	for k in 3:
		var tc := _u(r, 0.54 + k * 0.12, 0.5)
		D(ci, tc + Vector2(0, ms * 0.04), maxf(1.2, ms * 0.035), 0.5)
		sl.append(tc + Vector2(0, ms * 0.04))
		sl.append(tc + Vector2(1.0, -ms * (0.07 if k != 1 else -0.02)))
	for k in 3:
		var y: float = 0.66 + k * 0.06
		sl.append(_u(r, 0.18, y))
		sl.append(_u(r, 0.48, y))
	sl.append(_u(r, 0.5, 0.9))
	sl.append(_u(r, 0.5, 1.0))
	S(ci, sl, 0.45)
	D(ci, _u(r, 0.68, 0.72), maxf(1.4, ms * 0.05), 0.55)
	_lamp(ci, _u(r, 0.8, 0.72), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- ARK-01: control rod lock panel
# the rod lock panel: the core map (each rod a circle, the locked ones filled), the row of
# interlock keys in their barrels, the lock lamps, the guarded master lock lever
static func rod_lock_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.03, 0.94, 0.96)
	var cm := sub(r, 0.14, 0.07, 0.86, 0.46)
	R(ci, cm, 0.55)
	var cc := cm.get_center()
	var cr: float = minf(cm.size.x, cm.size.y) * 0.08
	for row in range(-2, 3):
		for c in range(-2, 3):
			if absi(row) + absi(c) > 3:
				continue
			var p := cc + Vector2(c * cr * 2.3 + (cr * 1.15 if row % 2 != 0 else 0.0), row * cr * 2.0)
			O(ci, p, cr, 0.45)
			if (row * 5 + c) % 3 == 0:
				D(ci, p, cr * 0.6, 0.6)
	for k in 4:
		var kc := _u(r, 0.2 + k * 0.2, 0.56)
		O(ci, kc, ms * 0.06, 0.55)
		L(ci, kc - Vector2(0, ms * 0.04), kc + Vector2(0, ms * 0.04), 0.6, 1.3)
		_lamp(ci, _u(r, 0.2 + k * 0.2, 0.65), maxf(1.4, ms * 0.04), Pal.heat(0.85) if k == 3 else Pal.tint(Pal.FLUID, 0.85))
	var lv := sub(r, 0.3, 0.72, 0.7, 0.92)
	R(ci, lv, 0.5)
	L(ci, _u(r, 0.5, 0.9), _u(r, 0.62, 0.76), 0.62, 2.2)
	D(ci, _u(r, 0.62, 0.76), 1.6, 0.62)
	P(ci, PackedVector2Array([_u(r, 0.28, 0.92), _u(r, 0.28, 0.7), _u(r, 0.72, 0.7), _u(r, 0.72, 0.92)]), 0.35)


# ---------------------------------------------------------------- BL-88: UV steriliser
# the UV water steriliser: the stainless chamber, the lamp in its quartz sleeve (its violet
# glow), the inlet and outlet nozzles, the intensity sensor port, the ballast box
static func uv_tube(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var ch := sub(r, 0.22, 0.08, 0.66, 0.84)
	R(ci, ch, 0.62, 1.3)
	R(ci, sub(r, 0.18, 0.04, 0.7, 0.08), 0.55)
	R(ci, sub(r, 0.18, 0.84, 0.7, 0.88), 0.55)
	R(ci, sub(r, 0.38, 0.1, 0.5, 0.82), 0.45)
	E.Rc(ci, sub(r, 0.415, 0.12, 0.465, 0.8), Pal.tint(Pal.VOLT, 0.85), 1.0)
	for y in [0.2, 0.7]:
		var x0: float = 0.66 if y > 0.5 else 0.0
		L(ci, _u(r, x0, y), _u(r, x0 + 0.22, y) if y < 0.5 else _u(r, 0.86, y), 0.55, 1.6)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.2) - Vector2(0, 0.6), Vector2(r.size.x * 0.22, 1.2)), Pal.tint(Pal.FLUID, 0.5), 1.0)
	O(ci, _u(r, 0.66, 0.42), ms * 0.08, 0.55)
	var bb := sub(r, 0.72, 0.1, 0.98, 0.5)
	R(ci, bb, 0.55)
	_lamp(ci, _u(r, 0.85, 0.2), maxf(1.4, ms * 0.08), Pal.tint(Pal.VOLT, 0.85))
	hatch(ci, sub(r, 0.75, 0.28, 0.95, 0.46), 2.0, false, 0.3, 8)
	L(ci, _u(r, 0.72, 0.16), _u(r, 0.5, 0.06), 0.35)


# ---------------------------------------------------------------- DC-84: leak detection panel
# the leak detection panel: the floor map with the sensing cable's route snaking under the
# racks, the zone lamps (one alarmed), the buzzer grille, the sensing cable out of the bottom
static func leak_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.08, 0.04, 0.92, 0.88)
	var mp := sub(r, 0.16, 0.1, 0.84, 0.5)
	R(ci, mp, 0.5)
	for k in 3:
		R(ci, sub(r, 0.22 + k * 0.2, 0.15, 0.34 + k * 0.2, 0.44), 0.3)
	var rt := PackedVector2Array()
	for k in 7:
		rt.append(_u(r, 0.19 + k * 0.1, 0.47 if k % 2 == 0 else 0.13))
	P(ci, rt, 0.5)
	E.Rc(ci, Rect2(_u(r, 0.49, 0.3) - Vector2(2, 2), Vector2(4, 4)), Pal.heat(0.85), 1.0)
	for k in 3:
		_lamp(ci, _u(r, 0.26 + k * 0.24, 0.6), maxf(1.4, ms * 0.05), Pal.heat(0.85) if k == 1 else Pal.tint(Pal.FLUID, 0.85))
	var bz := _u(r, 0.5, 0.75)
	for k in 3:
		O(ci, bz, ms * (0.03 + k * 0.035), 0.4)
	_pu(ci, r, [Vector2(0.5, 0.88), Vector2(0.5, 0.94), Vector2(0.62, 0.97), Vector2(0.74, 0.94), Vector2(0.86, 0.97)], 0.45)


# ---------------------------------------------------------------- DR-150: drawworks brake panel
# the driller's brake control: the long brake handle on its toothed quadrant, the two brake
# pressure gauges, the band brake diagram, the guarded emergency set button
static func brake_handle_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.06, 0.04, 0.94, 0.9)
	for k in 2:
		E.gauge(ci, _u(r, 0.28 + k * 0.32, 0.18), maxf(3.0, ms * 0.11), 0.55)
	var bc := _u(r, 0.72, 0.5)
	O(ci, bc, ms * 0.12, 0.5)
	A(ci, bc, ms * 0.15, PI * 0.3, PI * 1.9, 0.5, 1.6)
	L(ci, bc + Vector2.from_angle(PI * 0.3) * ms * 0.15, bc + Vector2(ms * 0.2, ms * 0.14), 0.45)
	var qc := _u(r, 0.32, 0.82)
	A(ci, qc, ms * 0.3, PI * 1.2, PI * 1.65, 0.55, 1.4)
	var tk := PackedVector2Array()
	for k in 7:
		var a: float = PI * 1.2 + k * PI * 0.45 / 6.0
		tk.append(qc + Vector2.from_angle(a) * ms * 0.3)
		tk.append(qc + Vector2.from_angle(a) * ms * 0.34)
	S(ci, tk, 0.45)
	var hd := qc + Vector2.from_angle(PI * 1.4) * ms * 0.42
	L(ci, qc, hd, 0.62, 2.4)
	O(ci, hd, ms * 0.05, 0.6, 1.3)
	D(ci, qc, 1.6, 0.6)
	var es := _u(r, 0.76, 0.8)
	A(ci, es, ms * 0.08, PI, TAU, 0.55, 1.2)
	_lamp(ci, es, maxf(2.0, ms * 0.07), Pal.heat(0.9))


# ---------------------------------------------------------------- DR-150: slips control panel
# the power slips control: the bank of air valves with their ball-knob levers (in / out /
# hold), the slips position flags, the air supply gauge and filter bowl, the air hoses off it
static func slips_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.06, 0.04, 0.94, 0.9)
	for k in 3:
		var x: float = 0.24 + k * 0.26
		var vb := sub(r, x - 0.08, 0.4, x + 0.08, 0.56)
		R(ci, vb, 0.55)
		var ang: float = [-0.4, 0.0, 0.4][k]
		var top := _u(r, x, 0.4) + Vector2(sin(ang), -cos(ang)) * ms * 0.2
		L(ci, _u(r, x, 0.4), top, 0.6, 1.6)
		O(ci, top, ms * 0.04, 0.6, 1.3)
		L(ci, _u(r, x, 0.56), _u(r, x, 0.98), 0.4, 1.3)
	for k in 2:
		var f := sub(r, 0.16 + k * 0.4, 0.62, 0.44 + k * 0.4, 0.72)
		R(ci, f, 0.45)
		E.Rc(ci, Rect2(f.position + Vector2(f.size.x * (0.05 if k == 0 else 0.5), 1.5), Vector2(f.size.x * 0.45, f.size.y - 3.0)), Pal.tint(Pal.FLUID, 0.7), 1.0)
	E.gauge(ci, _u(r, 0.3, 0.16), maxf(3.0, ms * 0.1), 0.55)
	_pu(ci, r, [Vector2(0.62, 0.08), Vector2(0.62, 0.22), Vector2(0.66, 0.28), Vector2(0.74, 0.28), Vector2(0.78, 0.22), Vector2(0.78, 0.08)], 0.5)
	R(ci, sub(r, 0.6, 0.05, 0.8, 0.08), 0.5)
	E.Rc(ci, sub(r, 0.64, 0.2, 0.76, 0.26), Pal.tint(Pal.FLUID, 0.3), 1.0)


# ---------------------------------------------------------------- emergency shutdown module (FL-116, H-22)
# the emergency shutdown station: the big push button under its flip cover, the cause and
# effect matrix of lamps, the key reset, the beacon and horn on top; small, the station alone
static func esd_station(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var small: bool = ms < 60.0
	var b := _carcass(ci, r, 0.06, 0.12 if not small else 0.04, 0.94, 0.95)
	var pc := _u(r, 0.5, 0.36 if not small else 0.42)
	var pr: float = ms * (0.12 if not small else 0.22)
	O(ci, pc, pr * 1.3, 0.55)
	_lamp(ci, pc, pr * 1.2, Pal.heat(0.9))
	O(ci, pc, pr * 0.6, 0.6)
	P(ci, PackedVector2Array([pc + Vector2(-pr * 1.5, pr * 1.5), pc + Vector2(-pr * 1.5, -pr * 1.6), pc + Vector2(pr * 1.5, -pr * 1.6), pc + Vector2(pr * 1.5, pr * 1.5)]), 0.45)
	var kc := _u(r, 0.5, 0.82) if small else _u(r, 0.86, 0.36)
	O(ci, kc, ms * 0.05, 0.55)
	L(ci, kc - Vector2(0, ms * 0.03), kc + Vector2(0, ms * 0.03), 0.6, 1.3)
	if small:
		return
	# the shutdown trip relays (their flags), the reset and the terminal strip under the matrix
	for k in 5:
		E.breaker(ci, sub(r, 0.14 + k * 0.15, 0.81, 0.26 + k * 0.15, 0.88), k != 2, 0.45)
	var ts := PackedVector2Array()
	for k in 14:
		var x: float = 0.14 + (k + 0.5) * 0.72 / 14.0
		ts.append(_u(r, x, 0.9))
		ts.append(_u(r, x, 0.93))
	S(ci, ts, 0.45, 1.4)
	_lamp(ci, _u(r, 0.14, 0.36), maxf(1.6, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	hatch(ci, sub(r, 0.08, 0.2, 0.2, 0.3), 2.0, false, 0.3, 6)
	A(ci, _u(r, 0.3, 0.12), ms * 0.06, PI, TAU, 0.55, 1.2)
	_lamp(ci, _u(r, 0.3, 0.09), ms * 0.04, Pal.heat(0.8))
	_pu(ci, r, [Vector2(0.62, 0.12), Vector2(0.64, 0.04), Vector2(0.76, 0.02), Vector2(0.76, 0.12)], 0.5)
	for row in 4:
		for c in 6:
			var lc := _u(r, 0.18 + c * 0.128, 0.56 + row * 0.065)
			if (row * 6 + c) % 5 == 2:
				_lamp(ci, lc, ms * 0.03, Pal.heat(0.85))
			else:
				R(ci, Rect2(lc - Vector2(ms * 0.015, ms * 0.015), Vector2(ms * 0.03, ms * 0.03)), 0.35)


# ---------------------------------------------------------------- EV-55: power control unit (solar)
# the solar array's power control unit: the array string bargraphs, the three MPPT converter
# slots with their heat sinks, the battery charge regulator readout, the main relay
static func solar_pcu(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.04, 0.94, 0.95)
	var n := 6
	for k in n:
		var bar := sub(r, 0.14 + k * 0.12, 0.08, 0.22 + k * 0.12, 0.3)
		R(ci, bar, 0.4)
		var lv: float = 0.4 + 0.5 * fposmod(k * 0.37, 1.0)
		hatch(ci, Rect2(bar.position + Vector2(1, bar.size.y * (1.0 - lv)), Vector2(bar.size.x - 2, bar.size.y * lv - 1)), 1.6, false, 0.45, 20)
	for k in 3:
		var s := sub(r, 0.12 + k * 0.26, 0.36, 0.34 + k * 0.26, 0.66)
		R(ci, s, 0.55)
		hatch(ci, Rect2(s.position + Vector2(2, 2), Vector2(s.size.x - 4, s.size.y * 0.5)), 2.2, true, 0.3, 12)
		_lamp(ci, s.position + Vector2(s.size.x * 0.5, s.size.y * 0.78), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	E.Rc(ci, sub(r, 0.14, 0.72, 0.56, 0.8), Pal.tint(Pal.AIR, 0.6), 1.0)
	var rl := sub(r, 0.64, 0.7, 0.86, 0.88)
	R(ci, rl, 0.55)
	L(ci, rl.position + Vector2(3, rl.size.y * 0.5), rl.end - Vector2(3, rl.size.y * 0.5), 0.45)
	hatch(ci, sub(r, 0.14, 0.84, 0.56, 0.9), 2.0, false, 0.3, 4)


# ---------------------------------------------------------------- EV-55: heat shield temperature probe
# a thermocouple head on the heat shield: the probe in its well, its tip against the hatched
# shield plate (glowing), the transmitter head with its lid screws and cable gland
static func shield_probe(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sp := sub(r, 0.0, 0.84, 1.0, 1.0)
	R(ci, sp, 0.55)
	hatch(ci, sp.grow(-1.0), 2.2, true, 0.3, 20)
	E.Rc(ci, sub(r, 0.36, 0.8, 0.64, 0.86), Pal.heat(0.8), 1.0)
	R(ci, sub(r, 0.42, 0.46, 0.58, 0.84), 0.6)
	L(ci, _u(r, 0.5, 0.48), _u(r, 0.5, 0.82), 0.35)
	var hd := sub(r, 0.18, 0.12, 0.82, 0.46)
	R(ci, hd, 0.62, 1.2)
	A(ci, _u(r, 0.5, 0.12), r.size.x * 0.32, PI, TAU, 0.5)
	E.corner_bolts(ci, hd, 2.0, 0.45)
	R(ci, sub(r, 0.82, 0.24, 0.94, 0.34), 0.5)
	L(ci, _u(r, 0.94, 0.29), _u(r, 1.0, 0.29), 0.5, 1.3)


# ---------------------------------------------------------------- pushing fender block (BELT, TUG)
# a tug's push fender: the hollow cylindrical rubber (its bore), the steel face plate with
# its wear pads and bolts, the mounting chains to the bow
static func push_fender(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_pu(ci, r, [Vector2(0.1, 0.04), Vector2(0.9, 0.04), Vector2(0.98, 0.18), Vector2(0.98, 0.82), Vector2(0.9, 0.96), Vector2(0.1, 0.96), Vector2(0.02, 0.82), Vector2(0.02, 0.18)], 0.62, 1.4, true)
	O(ci, _u(r, 0.5, 0.5), ms * 0.26, 0.55)
	O(ci, _u(r, 0.5, 0.5), ms * 0.18, 0.35)
	var rib := PackedVector2Array()
	for k in 4:
		var y: float = 0.14 + k * 0.24
		rib.append(_u(r, 0.06, y))
		rib.append(_u(r, 0.22, y))
		rib.append(_u(r, 0.78, y))
		rib.append(_u(r, 0.94, y))
	S(ci, rib, 0.3)
	R(ci, sub(r, 0.24, 0.0, 0.76, 0.06), 0.6)
	for x in [0.3, 0.5, 0.7]:
		D(ci, _u(r, x, 0.03), 0.9, 0.6)


# ---------------------------------------------------------------- FR-26: frost vent
# the frost discharge port: the bayonet coupling, the vent nozzle and its flapper, the heater
# coil wound round it, the frost on the lip, the drain cup
static func frost_vent(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.18, 0.02, 0.82, 0.14), 0.6, 1.2)
	for x in [0.26, 0.74]:
		D(ci, _u(r, x, 0.08), 1.0, 0.55)
	_pu(ci, r, [Vector2(0.3, 0.14), Vector2(0.3, 0.62), Vector2(0.16, 0.82), Vector2(0.84, 0.82), Vector2(0.7, 0.62), Vector2(0.7, 0.14)], 0.62, 1.2)
	var coil := PackedVector2Array()
	for k in 9:
		coil.append(_u(r, 0.26 if k % 2 == 0 else 0.74, 0.18 + k * 0.05))
	P(ci, coil, 0.45)
	E.Rc(ci, Rect2(_u(r, 0.26, 0.18), Vector2(r.size.x * 0.48, r.size.y * 0.42)), Pal.heat(0.3), 1.0)
	L(ci, _u(r, 0.16, 0.82), _u(r, 0.5, 0.7), 0.5, 1.3)
	var fr := PackedVector2Array()
	for k in 6:
		var x: float = 0.2 + k * 0.12
		fr.append(_u(r, x, 0.84))
		fr.append(_u(r, x + 0.03, 0.88))
	E.Rc(ci, sub(r, 0.16, 0.83, 0.84, 0.86), Pal.tint(Pal.AIR, 0.6), 1.0)
	S(ci, fr, 0.4)
	_pu(ci, r, [Vector2(0.36, 0.9), Vector2(0.4, 0.98), Vector2(0.6, 0.98), Vector2(0.64, 0.9)], 0.5)


# ---------------------------------------------------------------- MED-47: freezer control
# the medical freezer's controller: the temperature readout, the round chart recorder with
# its trace, the door alarm lamp and the backup battery, the key lock
static func freezer_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.04, 0.06, 0.96, 0.88)
	var cc := _u(r, 0.28, 0.46)
	var cr: float = ms * 0.32
	O(ci, cc, cr, 0.58, 1.2)
	for k in 3:
		O(ci, cc, cr * (0.35 + k * 0.2), 0.2)
	var tr := PackedVector2Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		tr.append(cc + Vector2.from_angle(a) * cr * (0.62 + 0.08 * sin(a * 3.0) + (0.15 if k == 9 else 0.0)))
	P(ci, tr, 0.5)
	D(ci, cc, 1.2, 0.6)
	E.Rc(ci, sub(r, 0.56, 0.16, 0.9, 0.34), Pal.tint(Pal.AIR, 0.7), 1.0)
	_lamp(ci, _u(r, 0.62, 0.48), maxf(1.4, ms * 0.06), Pal.heat(0.85))
	R(ci, sub(r, 0.7, 0.42, 0.9, 0.56), 0.45)
	var kc := _u(r, 0.8, 0.72)
	O(ci, kc, ms * 0.06, 0.55)
	L(ci, kc - Vector2(0, ms * 0.035), kc + Vector2(0, ms * 0.035), 0.6, 1.2)


# ---------------------------------------------------------------- FX-70: cryo control panel
# the helium compressor's panel: the supply and return pressure gauges, the cold-head
# temperature readout, the rotameter (glass tube, float), start and stop buttons
static func cryo_ctrl_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.06, 0.04, 0.94, 0.9)
	for k in 2:
		E.gauge(ci, _u(r, 0.3 + k * 0.38, 0.16), maxf(3.0, ms * 0.12), 0.55)
	E.Rc(ci, sub(r, 0.16, 0.32, 0.84, 0.42), Pal.tint(Pal.AIR, 0.7), 1.0)
	var rt := sub(r, 0.24, 0.48, 0.36, 0.84)
	R(ci, rt, 0.55)
	var tk := PackedVector2Array()
	for k in 6:
		var y: float = rt.position.y + (k + 0.5) * rt.size.y / 6.0
		tk.append(Vector2(rt.end.x, y))
		tk.append(Vector2(rt.end.x + 3.0, y))
	S(ci, tk, 0.4)
	D(ci, Vector2(rt.get_center().x, rt.position.y + rt.size.y * 0.4), maxf(1.4, ms * 0.04), 0.65)
	for k in 2:
		var c := _u(r, 0.62, 0.56 + k * 0.2)
		O(ci, c, ms * 0.08, 0.55)
		_lamp(ci, c, ms * 0.08, Pal.tint(Pal.FLUID, 0.8) if k == 0 else Pal.heat(0.8))


# ---------------------------------------------------------------- HG-170: cryogenic distribution manifold
# an open cryogenic manifold on its frame: the vacuum-jacketed header, three branch lines to
# the tanks each with its long-bonnet cryo valve and handwheel, the bayonets, the frost
static func cryo_manifold(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.06, 0.02), _u(r, 0.06, 0.98), 0.55, 1.6)
	L(ci, _u(r, 0.94, 0.02), _u(r, 0.94, 0.98), 0.55, 1.6)
	var hd := sub(r, 0.16, 0.04, 0.4, 0.96)
	R(ci, hd, 0.62, 1.3)
	R(ci, hd.grow(-3.0), 0.3)
	E.Rc(ci, hd.grow(-3.0), Pal.tint(Pal.AIR, 0.22), 1.0)
	for k in 3:
		var y: float = 0.22 + k * 0.28
		L(ci, _u(r, 0.4, y), _u(r, 1.0, y), 0.58, 1.6)
		L(ci, _u(r, 0.4, y + 0.03), _u(r, 1.0, y + 0.03), 0.3)
		var vc := _u(r, 0.6, y)
		_bowtie(ci, vc, maxf(2.5, ms * 0.06))
		L(ci, vc, vc - Vector2(0, r.size.y * 0.12), 0.5, 1.3)
		E.wheel(ci, vc - Vector2(0, r.size.y * 0.12), maxf(2.0, ms * 0.07), 0.55)
		R(ci, Rect2(_u(r, 0.8, y) - Vector2(2.0, 3.5), Vector2(r.size.x * 0.08, 7.0)), 0.55)
		E.Rc(ci, Rect2(_u(r, 0.4, y + 0.04), Vector2(r.size.x * 0.15, 1.0)), Pal.tint(Pal.AIR, 0.6), 1.0)
	O(ci, _u(r, 0.28, 0.08), ms * 0.06, 0.5)


# ---------------------------------------------------------------- HG-170: level gauge
# a magnetic level indicator: the float chamber, the roller flags showing the level (lit
# below it), the scale, the process connections top and bottom to the tank
static func level_gauge(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var ch := sub(r, 0.28, 0.04, 0.48, 0.96)
	R(ci, ch, 0.62, 1.2)
	var fl := sub(r, 0.54, 0.08, 0.7, 0.92)
	R(ci, fl, 0.5)
	var n := clampi(int(fl.size.y / 3.0), 6, 20)
	for k in n:
		var y: float = fl.position.y + (k + 0.5) * fl.size.y / n
		if k > n * 0.45:
			E.Rc(ci, Rect2(Vector2(fl.position.x + 1.5, y - 0.6), Vector2(fl.size.x - 3.0, 1.2)), Pal.tint(Pal.FLUID, 0.75), 1.0)
		else:
			L(ci, Vector2(fl.position.x + 1.5, y), Vector2(fl.end.x - 1.5, y), 0.25)
	var tk := PackedVector2Array()
	for k in 6:
		var y: float = fl.position.y + k * fl.size.y / 5.0
		tk.append(Vector2(fl.end.x, y))
		tk.append(Vector2(fl.end.x + (4.0 if k % 5 == 0 else 2.5), y))
	S(ci, tk, 0.45)
	for y in [0.12, 0.88]:
		L(ci, _u(r, 0.0, y), _u(r, 0.28, y), 0.55, 1.5)
		_bowtie(ci, _u(r, 0.14, y), maxf(1.8, ms * 0.06))
	R(ci, Rect2(_u(r, 0.38, 0.45) - Vector2(r.size.x * 0.08, 2.5), Vector2(r.size.x * 0.16, 5.0)), 0.55)


# ---------------------------------------------------------------- HG-170: process control panel
# the gas plant's panel: the P&ID mimic (two vessels, the lines, valve lamps on them), two
# PID controller faceplates with their setpoint and process bars, hand/auto selectors
static func process_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.03, 0.94, 0.96)
	var mp := sub(r, 0.12, 0.06, 0.88, 0.42)
	R(ci, mp, 0.5)
	E.vessel_v(ci, sub(r, 0.18, 0.12, 0.32, 0.36), 0.45)
	E.vessel_v(ci, sub(r, 0.66, 0.16, 0.8, 0.36), 0.45)
	_pu(ci, r, [Vector2(0.32, 0.18), Vector2(0.5, 0.18), Vector2(0.5, 0.3), Vector2(0.66, 0.3)], 0.4)
	_pu(ci, r, [Vector2(0.25, 0.36), Vector2(0.25, 0.4), Vector2(0.73, 0.4), Vector2(0.73, 0.36)], 0.4)
	for q in [Vector2(0.41, 0.18), Vector2(0.58, 0.3), Vector2(0.5, 0.4)]:
		_lamp(ci, _u(r, q.x, q.y), maxf(1.6, ms * 0.05), Pal.tint(Pal.FLUID, 0.85) if q.x < 0.5 else Pal.heat(0.85))
	for k in 2:
		var fp := sub(r, 0.12 + k * 0.4, 0.46, 0.48 + k * 0.4, 0.74)
		R(ci, fp, 0.55)
		E.Rc(ci, Rect2(fp.position + Vector2(2, 2), Vector2(fp.size.x - 4, fp.size.y * 0.18)), Pal.tint(Pal.AIR, 0.6), 1.0)
		for j in 2:
			var bar := Rect2(fp.position + Vector2(fp.size.x * (0.2 + j * 0.35), fp.size.y * 0.3), Vector2(fp.size.x * 0.18, fp.size.y * 0.6))
			R(ci, bar, 0.4)
			var lv: float = 0.5 + 0.2 * j
			hatch(ci, Rect2(bar.position + Vector2(1, bar.size.y * (1.0 - lv)), Vector2(bar.size.x - 2, bar.size.y * lv - 1)), 1.6, false, 0.45, 20)
	for k in 3:
		_toggle(ci, _u(r, 0.26 + k * 0.24, 0.84), maxf(2.0, ms * 0.05), k % 2 == 0)


# ---------------------------------------------------------------- LC-140: cradle control panel
# the carried ship's cradle panel: the ship outline with its four clamps (lamps on each),
# the clamp hydraulic gauge, the release lever with its safety pin on a lanyard
static func cradle_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.06, 0.04, 0.94, 0.9)
	var sh := PackedVector2Array([_u(r, 0.5, 0.08), _u(r, 0.66, 0.16), _u(r, 0.7, 0.42), _u(r, 0.6, 0.48), _u(r, 0.4, 0.48), _u(r, 0.3, 0.42), _u(r, 0.34, 0.16), _u(r, 0.5, 0.08)])
	P(ci, sh, 0.5)
	for q in [Vector2(0.26, 0.22), Vector2(0.74, 0.22), Vector2(0.26, 0.42), Vector2(0.74, 0.42)]:
		var c := _u(r, q.x, q.y)
		R(ci, Rect2(c - Vector2(3, 2), Vector2(6, 4)), 0.55)
		_lamp(ci, c, 2.0, Pal.tint(Pal.FLUID, 0.85))
	E.gauge(ci, _u(r, 0.3, 0.64), maxf(3.0, ms * 0.11), 0.55)
	var lp := _u(r, 0.68, 0.8)
	L(ci, lp, lp + Vector2(0, -r.size.y * 0.2), 0.62, 2.2)
	O(ci, lp + Vector2(0, -r.size.y * 0.2), ms * 0.05, 0.6)
	R(ci, Rect2(lp - Vector2(ms * 0.08, ms * 0.04), Vector2(ms * 0.16, ms * 0.08)), 0.5)
	D(ci, lp + Vector2(ms * 0.06, -r.size.y * 0.08), 1.2, 0.6)
	_pu(ci, r, [Vector2(0.74, 0.72), Vector2(0.86, 0.76), Vector2(0.84, 0.84)], 0.3)


# ---------------------------------------------------------------- engine control panel (LC-140, DR-150, HG-170)
# a generator engine's local panel: the big tachometer, the exhaust temperature bargraph,
# fuel and oil pressure gauges, the start key, the speed lever in its gate
static func engine_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.06, 0.04, 0.94, 0.9)
	E.gauge(ci, _u(r, 0.38, 0.22), maxf(4.0, ms * 0.2), 0.58)
	var eg := sub(r, 0.72, 0.08, 0.84, 0.38)
	R(ci, eg, 0.45)
	hatch(ci, Rect2(eg.position + Vector2(1, eg.size.y * 0.35), Vector2(eg.size.x - 2, eg.size.y * 0.65 - 1)), 1.6, false, 0.45, 20)
	for k in 2:
		E.gauge(ci, _u(r, 0.26 + k * 0.24, 0.52), maxf(2.5, ms * 0.08), 0.5)
	var kc := _u(r, 0.76, 0.52)
	O(ci, kc, ms * 0.07, 0.55)
	L(ci, kc - Vector2(0, ms * 0.04), kc + Vector2(ms * 0.02, ms * 0.04), 0.6, 1.3)
	var gt := sub(r, 0.3, 0.66, 0.7, 0.84)
	R(ci, gt, 0.45)
	L(ci, gt.position + Vector2(4, gt.size.y * 0.5), gt.end - Vector2(4, gt.size.y * 0.5), 0.3)
	L(ci, _u(r, 0.58, 0.75), _u(r, 0.62, 0.6), 0.62, 2.0)
	O(ci, _u(r, 0.62, 0.6), ms * 0.04, 0.6)


# ---------------------------------------------------------------- monitoring panel (CH-110, DC-84, IH-55)
# a wall of monitors: screens showing a camera view (horizon and a load), trends, a rack
# map, the KVM switch with its channel lamps, the keyboard ledge; more screens the wider
static func monitor_wall(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var n := clampi(int(r.size.x / (0.8 * M)), 1, 5)
	var sw: float = 0.94 / n
	for k in n:
		var s := sub(r, 0.03 + k * sw, 0.04, 0.03 + (k + 1) * sw - 0.015, 0.7)
		R(ci, s, 0.6, 1.2)
		var q := s.grow(-2.5)
		match k % 4:
			0:
				L(ci, Vector2(q.position.x, q.position.y + q.size.y * 0.6), Vector2(q.end.x, q.position.y + q.size.y * 0.55), 0.4)
				R(ci, Rect2(q.position + Vector2(q.size.x * 0.4, q.size.y * 0.3), q.size * Vector2(0.2, 0.28)), 0.45)
				L(ci, q.position + Vector2(q.size.x * 0.5, 0), q.position + Vector2(q.size.x * 0.5, q.size.y * 0.3), 0.3)
				_lamp(ci, q.position + Vector2(4, 4), 1.6, Pal.heat(0.85))
			1:
				E.screen_face(ci, q, 0, 0.35)
			2:
				for j in 4:
					R(ci, Rect2(q.position + Vector2(q.size.x * (0.06 + j * 0.24), q.size.y * 0.15), Vector2(q.size.x * 0.18, q.size.y * 0.7)), 0.35)
				E.Rc(ci, Rect2(q.position + Vector2(q.size.x * 0.54, q.size.y * 0.15), Vector2(q.size.x * 0.18, q.size.y * 0.7)), Pal.tint(Pal.FLUID, 0.6), 1.0)
			_:
				E.screen_face(ci, q, 3, 0.35)
	L(ci, _u(r, 0.02, 0.82), _u(r, 0.98, 0.82), 0.58, 1.6)
	R(ci, sub(r, 0.3, 0.76, 0.7, 0.82), 0.45)
	hatch(ci, sub(r, 0.31, 0.77, 0.69, 0.81), 3.0, true, 0.25, 40)
	var kv := sub(r, 0.76, 0.86, 0.96, 0.98)
	R(ci, kv, 0.5)
	_lamp_row(ci, kv, 4, Pal.tint(Pal.FLUID, 0.85), 4)


# ---------------------------------------------------------------- OB-90: baffle heater strip
# a thin film heater on the sun baffle: the strip, its etched serpentine element, the
# thermostat disc, the two leads
static func baffle_heater(ci: CanvasItem, r: Rect2) -> void:
	var st := sub(r, 0.04, 0.2, 0.96, 0.8)
	R(ci, st, 0.6, 1.2)
	E.Rc(ci, st.grow(-1.0), Pal.heat(0.3), 1.0)
	var sp := PackedVector2Array()
	var n := clampi(int(st.size.x / 4.0), 4, 20)
	for k in n + 1:
		var x: float = st.position.x + 3.0 + k * (st.size.x * 0.7 - 6.0) / n
		sp.append(Vector2(x, st.position.y + 2.0 if k % 2 == 0 else st.end.y - 2.0))
	P(ci, sp, 0.45)
	O(ci, _u(r, 0.84, 0.5), minf(r.size.y * 0.2, r.size.x * 0.08), 0.55)
	for y in [0.38, 0.62]:
		L(ci, _u(r, 0.96, y), _u(r, 1.0, y), 0.5)


# ---------------------------------------------------------------- OB-90: telescope power control unit
# the telescope's quiet supply: linear regulators (transformers, their heat sinks), the
# sequencer relay lamps, the mains EMI filter, the star-point ground bar with its lugs
static func quiet_pcu(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.04, 0.94, 0.95)
	for k in 2:
		var t := sub(r, 0.12 + k * 0.4, 0.08, 0.46 + k * 0.4, 0.4)
		R(ci, t, 0.5)
		var tc := Vector2(t.position.x + t.size.x * 0.35, t.get_center().y)
		O(ci, tc, minf(t.size.x, t.size.y) * 0.28, 0.55)
		O(ci, tc, minf(t.size.x, t.size.y) * 0.12, 0.4)
		hatch(ci, Rect2(t.position + Vector2(t.size.x * 0.68, 3), Vector2(t.size.x * 0.28, t.size.y - 6)), 1.8, false, 0.3, 12)
	_lamp_row(ci, sub(r, 0.14, 0.46, 0.86, 0.52), 6, Pal.tint(Pal.FLUID, 0.85), 0)
	var ef := sub(r, 0.12, 0.58, 0.5, 0.76)
	R(ci, ef, 0.55)
	var cz := PackedVector2Array()
	for k in 6:
		cz.append(ef.position + Vector2(ef.size.x * (0.15 + k * 0.14), ef.size.y * (0.35 if k % 2 == 0 else 0.65)))
	P(ci, cz, 0.45)
	L(ci, _u(r, 0.56, 0.84), _u(r, 0.9, 0.84), 0.62, 2.4)
	for k in 5:
		D(ci, _u(r, 0.59 + k * 0.07, 0.84), 1.2, 0.6)
		L(ci, _u(r, 0.59 + k * 0.07, 0.84), _u(r, 0.59 + k * 0.07, 0.92), 0.4)


# ---------------------------------------------------------------- the electrical control strip (38 on 25 ships)
# a long low panel: the slotted cable duct over it, the DIN rail of breakers and indicator
# modules repeated along it (a lamp each), the terminal strip under it, a small meter at the end
static func control_strip(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.0, 0.0, 1.0, 1.0), 0.6, 1.2)
	var du := sub(r, 0.02, 0.06, 0.98, 0.24)
	R(ci, du, 0.45)
	var sl := PackedVector2Array()
	var nd := clampi(int(du.size.x / 5.0), 4, 80)
	for k in nd:
		var x: float = du.position.x + (k + 0.5) * du.size.x / nd
		sl.append(Vector2(x, du.position.y + 1.0))
		sl.append(Vector2(x, du.end.y - 1.0))
	S(ci, sl, 0.22)
	var mw: float = minf(r.size.y * 0.7, r.size.x * 0.2)
	var mt := Rect2(Vector2(r.position.x + 3.0, r.position.y + r.size.y * 0.3), Vector2(mw, r.size.y * 0.5))
	R(ci, mt, 0.5)
	A(ci, mt.position + Vector2(mt.size.x * 0.5, mt.size.y * 0.85), mt.size.y * 0.55, PI * 1.15, PI * 1.85, 0.45)
	L(ci, mt.position + Vector2(mt.size.x * 0.5, mt.size.y * 0.85), mt.position + Vector2(mt.size.x * 0.68, mt.size.y * 0.35), 0.55)
	var x0: float = mt.end.x + 3.0
	var x1: float = r.end.x - 3.0
	var n := clampi(int((x1 - x0) / 7.0), 3, 70)
	var mwid: float = (x1 - x0) / n
	var leds := PackedVector2Array()
	for k in n:
		var m := Rect2(Vector2(x0 + k * mwid + 0.5, r.position.y + r.size.y * 0.3), Vector2(mwid - 1.0, r.size.y * 0.42))
		R(ci, m, 0.42)
		L(ci, m.position + Vector2(m.size.x * 0.5, m.size.y * 0.2), m.position + Vector2(m.size.x * 0.5, m.size.y * (0.45 if k % 5 != 3 else 0.75)), 0.55, 1.3)
		if k % 3 == 0:
			leds.append(m.position + Vector2(m.size.x * 0.5, m.size.y * 0.85))
	for c in leds:
		E.Rc(ci, Rect2(c - Vector2(0.8, 0.8), Vector2(1.6, 1.6)), Pal.tint(Pal.FLUID, 0.8), 1.0)
	var ts := PackedVector2Array()
	for k in n:
		var x: float = x0 + (k + 0.5) * mwid
		ts.append(Vector2(x, r.position.y + r.size.y * 0.8))
		ts.append(Vector2(x, r.position.y + r.size.y * 0.92))
	S(ci, ts, 0.4, 1.4)


# ---------------------------------------------------------------- VT-80: nitrogen purge panel
# the propellant transporter's purge panel: the nitrogen header with its regulator and gauge
# off the bottle connection, a row of purge points (needle valve, rotameter, outlet each)
static func purge_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.0, 0.02, 1.0, 0.98), 0.6, 1.2)
	L(ci, _u(r, 0.02, 0.24), _u(r, 0.98, 0.24), 0.58, 1.6)
	E.Rc(ci, Rect2(_u(r, 0.02, 0.24) - Vector2(0, 0.6), Vector2(r.size.x * 0.96, 1.2)), Pal.tint(Pal.AIR, 0.5), 1.0)
	O(ci, _u(r, 0.05, 0.24), ms * 0.08, 0.55)
	R(ci, sub(r, 0.09, 0.12, 0.15, 0.36), 0.55)
	E.gauge(ci, _u(r, 0.2, 0.24), maxf(2.5, ms * 0.12), 0.5)
	var n := clampi(int(r.size.x * 0.7 / 18.0), 3, 10)
	for k in n:
		var x: float = 0.3 + (k + 0.5) * 0.68 / n
		_bowtie(ci, _u(r, x, 0.24), maxf(1.6, ms * 0.05))
		L(ci, _u(r, x, 0.24), _u(r, x, 0.32), 0.4)
		var rt := sub(r, x - 0.02, 0.36, x + 0.02, 0.76)
		R(ci, rt, 0.5)
		D(ci, Vector2(rt.get_center().x, rt.position.y + rt.size.y * (0.3 + 0.4 * fposmod(k * 0.37, 1.0))), 1.0, 0.65)
		L(ci, _u(r, x, 0.76), _u(r, x, 0.98), 0.45, 1.2)
		D(ci, _u(r, x, 0.86), 1.0, 0.5)


# ---------------------------------------------------------------- MD-160: pusher plate
# the tall push plate: the plate with its vertical stiffeners, the rubber face strips
# (hatched), the two ram lugs at the back with the cylinder rods, the wear-plate bolts
static func pusher_plate(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	# the plate and its box stiffeners
	var pl := sub(r, 0.22, 0.0, 0.62, 1.0)
	R(ci, pl, 0.62, 1.4)
	var n := clampi(int(r.size.y / 28.0), 3, 14)
	var st := PackedVector2Array()
	for k in n + 1:
		var y: float = float(k) / n
		st.append(_u(r, 0.22, y))
		st.append(_u(r, 0.62, y))
	S(ci, st, 0.4, 1.2)
	for x in [0.36, 0.48]:
		L(ci, _u(r, x, 0.01), _u(r, x, 0.99), 0.3)
	# rubber face pads, each bolted, with its wear line
	for k in n:
		var y0: float = (k + 0.1) / n
		var y1: float = (k + 0.9) / n
		var pd := sub(r, 0.62, y0, 0.92, y1)
		R(ci, pd, 0.55)
		hatch(ci, sub(r, 0.66, y0 + 0.01, 0.9, y1 - 0.01), 2.4, false, 0.28, 30)
		L(ci, _u(r, 0.88, y0), _u(r, 0.88, y1), 0.35)
		D(ci, _u(r, 0.66, (y0 + y1) * 0.5), 1.0, 0.6)
	# the two ram lugs, rods and cylinders behind
	for y in [0.25, 0.75]:
		R(ci, sub(r, 0.12, y - 0.04, 0.22, y + 0.04), 0.6)
		O(ci, _u(r, 0.17, y), ms * 0.07, 0.55)
		D(ci, _u(r, 0.17, y), 1.2, 0.6)
		L(ci, _u(r, 0.0, y), _u(r, 0.12, y), 0.62, 2.6)
		R(ci, sub(r, 0.0, y - 0.025, 0.06, y + 0.025), 0.5)


# ---------------------------------------------------------------- QC-30: dilution refrigerator control
# the fridge's gas handling panel: the mimic of the circuit (pumps as circles, the cold trap,
# valves as squares lit open), the five-stage temperature readout, the pressure gauges
static func fridge_ctl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.03, 0.94, 0.96)
	var mp := sub(r, 0.12, 0.07, 0.88, 0.48)
	R(ci, mp, 0.5)
	var nodes := [Vector2(0.2, 0.15), Vector2(0.5, 0.15), Vector2(0.8, 0.15), Vector2(0.8, 0.4), Vector2(0.5, 0.4), Vector2(0.2, 0.4)]
	var loop := PackedVector2Array()
	for q in nodes:
		loop.append(_u(r, q.x, q.y))
	loop.append(loop[0])
	P(ci, loop, 0.4)
	for k in 2:
		O(ci, _u(r, nodes[k * 3].x, nodes[k * 3].y), ms * 0.05, 0.55)
	R(ci, Rect2(_u(r, 0.5, 0.4) - Vector2(ms * 0.04, ms * 0.05), Vector2(ms * 0.08, ms * 0.1)), 0.55)
	for q in [Vector2(0.35, 0.15), Vector2(0.65, 0.15), Vector2(0.65, 0.4), Vector2(0.35, 0.4), Vector2(0.8, 0.28)]:
		var c := _u(r, q.x, q.y)
		if q.x != 0.65:
			_lamp(ci, c, maxf(1.6, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
		else:
			R(ci, Rect2(c - Vector2(1.6, 1.6), Vector2(3.2, 3.2)), 0.5)
	var td := sub(r, 0.12, 0.54, 0.54, 0.88)
	E.Rc(ci, td, Pal.tint(Pal.AIR, 0.6), 1.0)
	for k in 5:
		var y: float = td.position.y + (k + 0.5) * td.size.y / 5.0
		L(ci, Vector2(td.position.x + 2.0, y), Vector2(td.position.x + td.size.x * (0.4 + 0.1 * k), y), 0.45)
	for k in 2:
		E.gauge(ci, _u(r, 0.7 + k * 0.0, 0.62 + k * 0.2), maxf(2.5, ms * 0.08), 0.5)


# ---------------------------------------------------------------- QC-30: HEMT bias supply
# the amplifiers' bias box: the shielded case, the row of coax ports on top, the ten-turn
# potentiometers (counting dials) per channel, the channel lamps, the filtered feedthroughs
static func hemt_bias(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.06, 0.16, 0.94, 0.94)
	R(ci, bx, 0.62, 1.3)
	R(ci, bx.grow(-2.5), 0.3)
	for k in 4:
		var x: float = 0.18 + k * 0.21
		R(ci, sub(r, x - 0.04, 0.06, x + 0.04, 0.16), 0.55)
		O(ci, _u(r, x, 0.06), ms * 0.04, 0.5)
		var pc := _u(r, x, 0.4)
		O(ci, pc, ms * 0.07, 0.55)
		R(ci, Rect2(pc + Vector2(-ms * 0.05, ms * 0.09), Vector2(ms * 0.1, ms * 0.06)), 0.45)
		L(ci, pc, pc + Vector2.from_angle(-1.0 + k * 0.5) * ms * 0.06, 0.6)
		_lamp(ci, _u(r, x, 0.66), maxf(1.2, ms * 0.035), Pal.tint(Pal.FLUID, 0.85))
		D(ci, _u(r, x, 0.84), 1.0, 0.55)
		L(ci, _u(r, x, 0.84), _u(r, x, 0.98), 0.4)


# ---------------------------------------------------------------- JD-38: rail lock board
# the courier's rail lock board: the track diagram along it with a lock pin icon at each
# station (in / out), the key switches under them, the lamps
static func rail_lock_board(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.0, 0.04, 1.0, 0.96), 0.6, 1.2)
	L(ci, _u(r, 0.04, 0.28), _u(r, 0.96, 0.28), 0.5, 1.4)
	L(ci, _u(r, 0.04, 0.36), _u(r, 0.96, 0.36), 0.5, 1.4)
	var n := clampi(int(r.size.x / 22.0), 3, 8)
	for k in n:
		var x: float = 0.08 + (k + 0.5) * 0.84 / n
		var locked: bool = k % 3 != 1
		R(ci, Rect2(_u(r, x, 0.32) - Vector2(2.5, ms * (0.18 if locked else 0.08)), Vector2(5.0, ms * (0.36 if locked else 0.16))), 0.6)
		var kc := _u(r, x, 0.62)
		O(ci, kc, ms * 0.1, 0.55)
		L(ci, kc - Vector2(0, ms * 0.06), kc + Vector2(0, ms * 0.06), 0.6, 1.2)
		_lamp(ci, _u(r, x, 0.84), maxf(1.4, ms * 0.06), Pal.tint(Pal.FLUID, 0.85) if locked else Pal.heat(0.85))


# ---------------------------------------------------------------- TB-180: RCS controller
# the reaction control system's controller: the quad mimic (four thrusters round the body,
# the firing ones lit), the valve driver card rack, the propellant pressure gauges, the
# pump starter
static func rcs_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_carcass(ci, r, 0.06, 0.03, 0.94, 0.96)
	var mc := _u(r, 0.5, 0.2)
	var mr: float = ms * 0.12
	R(ci, Rect2(mc - Vector2(mr, mr), Vector2(mr, mr) * 2.0), 0.5)
	for k in 4:
		var d := Vector2.from_angle(k * PI * 0.5)
		var base := mc + d * mr
		var tip := mc + d * mr * 1.9
		var sd := d.orthogonal() * mr * 0.4
		P(ci, PackedVector2Array([base - sd * 0.4, tip - sd, tip + sd, base + sd * 0.4, base - sd * 0.4]), 0.5)
		if k % 2 == 0:
			E.Rc(ci, Rect2(tip - Vector2(2, 2), Vector2(4, 4)), Pal.heat(0.8), 1.0)
	var cr := sub(r, 0.12, 0.42, 0.88, 0.66)
	R(ci, cr, 0.5)
	var segs := PackedVector2Array()
	for k in 8:
		var x: float = cr.position.x + (k + 0.5) * cr.size.x / 8.0
		segs.append(Vector2(x, cr.position.y + 2.0))
		segs.append(Vector2(x, cr.end.y - 2.0))
	S(ci, segs, 0.35, 1.4)
	_lamp_row(ci, Rect2(cr.position + Vector2(0, 1), Vector2(cr.size.x, 3)), 8, Pal.tint(Pal.FLUID, 0.85), 5)
	for k in 2:
		E.gauge(ci, _u(r, 0.28 + k * 0.24, 0.78), maxf(3.0, ms * 0.09), 0.5)
	E.breaker(ci, sub(r, 0.7, 0.72, 0.86, 0.84), true, 0.5)


# ---------------------------------------------------------------- CL-104: refrigerant recovery valves
# the cold-chain ship's recovery set: the manifold with its valves, the low- and high-side
# gauges (cool and warm rims), the sight glass with the refrigerant in it, the filter drier,
# the hose to the recovery cylinder
static func recovery_valves(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.02, 0.6), _u(r, 0.98, 0.6), 0.58, 1.8)
	for k in 2:
		var gc := _u(r, 0.14 + k * 0.18, 0.28)
		E.gauge(ci, gc, ms * 0.2, 0.55)
		E.Rc(ci, Rect2(gc - Vector2(ms * 0.21, ms * 0.21), Vector2(ms * 0.42, ms * 0.42)), Pal.tint(Pal.AIR, 0.4) if k == 0 else Pal.heat(0.4), 1.0)
		L(ci, gc + Vector2(0, ms * 0.2), Vector2(gc.x, _u(r, 0, 0.6).y), 0.45)
	for x in [0.5, 0.62, 0.88]:
		_bowtie(ci, _u(r, x, 0.6), maxf(2.0, ms * 0.07))
		L(ci, _u(r, x, 0.6), _u(r, x, 0.42), 0.45)
		L(ci, _u(r, x - 0.03, 0.42), _u(r, x + 0.03, 0.42), 0.55, 1.4)
	var sg := _u(r, 0.74, 0.6)
	O(ci, sg, ms * 0.08, 0.6, 1.2)
	E.Rc(ci, Rect2(sg - Vector2(ms * 0.05, 0), Vector2(ms * 0.1, ms * 0.05)), Pal.tint(Pal.FLUID, 0.75), 1.0)
	R(ci, sub(r, 0.38, 0.54, 0.46, 0.66), 0.55)
	_pu(ci, r, [Vector2(0.98, 0.6), Vector2(0.98, 0.84), Vector2(0.86, 0.94), Vector2(0.7, 0.9)], 0.45, 1.4)
	for x in [0.1, 0.9]:
		L(ci, _u(r, x, 0.6), _u(r, x, 0.98), 0.4, 1.3)


# ---------------------------------------------------------------- ES-112: mechanical release board
# the armoured ship's mechanical release board: a column of T-handles each pulling its
# Bowden cable (one already pulled), the cables bundled down the side, the guard rails
static func release_board(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	var n := clampi(int(r.size.y / 26.0), 3, 8)
	for k in n:
		var y: float = 0.08 + (k + 0.5) * 0.84 / n
		var pulled: bool = k == 1
		var hx: float = 0.24 if not pulled else 0.1
		R(ci, sub(r, 0.3, y - 0.025, 0.42, y + 0.025), 0.5)
		L(ci, _u(r, hx + 0.06, y), _u(r, 0.3, y), 0.55, 1.3)
		L(ci, _u(r, hx, y - 0.04), _u(r, hx, y + 0.04), 0.62, 2.2)
		if pulled:
			E.Rc(ci, sub(r, hx - 0.03, y - 0.05, hx + 0.03, y + 0.05), Pal.heat(0.8), 1.0)
		_pu(ci, r, [Vector2(0.42, y), Vector2(0.7 + k * 0.03, y), Vector2(0.7 + k * 0.03, 0.98)], 0.4)
		D(ci, _u(r, 0.5, y), 1.0, 0.55)
	L(ci, _u(r, 0.16, 0.04), _u(r, 0.16, 0.96), 0.3)


# ---------------------------------------------------------------- SP-ISOLATE: cradle lock panel
# the pod cradle's lock panel: the two lock cylinders with their pistons (engaged), the hand
# pump and its handle, the lock / unlock lever, the pressure gauge
static func cradle_lock(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.08, 0.03, 0.92, 0.92)
	for k in 2:
		var y: float = 0.12 + k * 0.2
		var cy := sub(r, 0.16, y, 0.84, y + 0.1)
		R(ci, cy, 0.55)
		R(ci, sub(r, 0.16, y + 0.02, 0.6, y + 0.08), 0.4)
		L(ci, _u(r, 0.6, y + 0.05), _u(r, 0.9, y + 0.05), 0.6, 2.0)
		_lamp(ci, _u(r, 0.26, y + 0.05), maxf(1.2, ms * 0.06), Pal.tint(Pal.FLUID, 0.85))
	E.gauge(ci, _u(r, 0.5, 0.56), maxf(2.5, ms * 0.18), 0.55)
	R(ci, sub(r, 0.3, 0.68, 0.7, 0.78), 0.55)
	L(ci, _u(r, 0.5, 0.68), _u(r, 0.8, 0.62), 0.6, 1.6)
	L(ci, _u(r, 0.4, 0.86), _u(r, 0.6, 0.8), 0.62, 2.0)
	D(ci, _u(r, 0.6, 0.8), 1.4, 0.6)


# ---------------------------------------------------------------- SP-ENERGY: flywheel brake panel
# the flywheel's braking panel: the speed dial, the braking resistor grid behind its mesh, the
# brake lever in its quadrant, the brake-on and overspeed lamps
static func flywheel_brake_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.08, 0.03, 0.92, 0.92)
	E.gauge(ci, _u(r, 0.5, 0.16), maxf(3.0, ms * 0.2), 0.58)
	var rg := sub(r, 0.16, 0.32, 0.84, 0.58)
	R(ci, rg, 0.5)
	var zz := PackedVector2Array()
	for k in 9:
		zz.append(_u(r, 0.2 + k * 0.075, 0.35 if k % 2 == 0 else 0.55))
	P(ci, zz, 0.5)
	hatch(ci, rg.grow(-1.0), 3.0, true, 0.15, 30)
	var qc := _u(r, 0.5, 0.86)
	A(ci, qc, ms * 0.3, PI * 1.25, PI * 1.75, 0.5, 1.3)
	L(ci, qc, qc + Vector2.from_angle(PI * 1.35) * ms * 0.38, 0.62, 2.2)
	O(ci, qc + Vector2.from_angle(PI * 1.35) * ms * 0.38, ms * 0.05, 0.6)
	_lamp(ci, _u(r, 0.26, 0.66), maxf(1.4, ms * 0.06), Pal.heat(0.85))
	_lamp(ci, _u(r, 0.74, 0.66), maxf(1.4, ms * 0.06), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- SP-LOAD: rail lock panel
# the load pod's rail lock: the three-position selector, the pin window showing the lock pin
# in, the key, the lamp
static func rail_lock_square(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := _wallbox(ci, r, 0.08, 0.06, 0.92, 0.88)
	var sc := _u(r, 0.36, 0.38)
	O(ci, sc, ms * 0.16, 0.58, 1.2)
	L(ci, sc - Vector2.from_angle(-0.5) * ms * 0.14, sc + Vector2.from_angle(-0.5) * ms * 0.14, 0.62, 2.2)
	for a in [-PI * 0.75, -PI * 0.5, -PI * 0.25]:
		D(ci, sc + Vector2.from_angle(a) * ms * 0.22, 1.0, 0.55)
	var pw := sub(r, 0.62, 0.18, 0.82, 0.58)
	R(ci, pw, 0.55)
	R(ci, sub(r, 0.67, 0.22, 0.77, 0.5), 0.5)
	E.Rc(ci, sub(r, 0.68, 0.36, 0.76, 0.49), Pal.tint(Pal.FLUID, 0.75), 1.0)
	var kc := _u(r, 0.36, 0.72)
	O(ci, kc, ms * 0.07, 0.55)
	L(ci, kc - Vector2(0, ms * 0.04), kc + Vector2(0, ms * 0.04), 0.6, 1.2)
	_lamp(ci, _u(r, 0.72, 0.72), maxf(1.4, ms * 0.06), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- SP-ISOLATE: mechanical release cabinet
# a small break-glass release cabinet: the glazed door (its crack lines), the big pull ring
# inside, the conduit to the release mechanism up out of the top, the little hammer on its chain
static func release_cabinet(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var b := sub(r, 0.1, 0.14, 0.9, 0.94)
	R(ci, b, 0.62, 1.3)
	var gl := sub(r, 0.18, 0.22, 0.82, 0.74)
	R(ci, gl, 0.5)
	L(ci, gl.position + Vector2(2, 2), gl.position + Vector2(gl.size.x * 0.3, 2), 0.25)
	var rc := _u(r, 0.5, 0.46)
	O(ci, rc, ms * 0.2, 0.62, 1.6)
	E.Rc(ci, Rect2(rc - Vector2(ms * 0.2, ms * 0.2), Vector2(ms * 0.4, ms * 0.4)), Pal.heat(0.6), 1.0)
	L(ci, rc - Vector2(0, ms * 0.2), _u(r, 0.5, 0.22), 0.55, 1.4)
	L(ci, _u(r, 0.5, 0.14), _u(r, 0.5, 0.0), 0.55, 1.6)
	R(ci, sub(r, 0.42, 0.06, 0.58, 0.14), 0.5)
	_pu(ci, r, [Vector2(0.9, 0.3), Vector2(0.96, 0.4), Vector2(0.96, 0.6)], 0.35)
	R(ci, sub(r, 0.92, 0.6, 1.0, 0.66), 0.5)
	R(ci, sub(r, 0.3, 0.8, 0.7, 0.88), 0.4)


# ---------------------------------------------------------------- ST-40: engine control unit
# the racer's ECU: the finned alloy case on its rubber mounts, the two big circular
# multi-pin connectors with their harness, the CAN lead, the status lamp
static func race_ecu(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.08, 0.2, 0.92, 0.84)
	R(ci, bx, 0.62, 1.3)
	var fn := PackedVector2Array()
	for k in 8:
		var x: float = bx.position.x + (k + 0.5) * bx.size.x / 8.0
		fn.append(Vector2(x, bx.position.y + 2.0))
		fn.append(Vector2(x, bx.position.y + bx.size.y * 0.35))
	S(ci, fn, 0.35)
	for k in 2:
		var c := _u(r, 0.3 + k * 0.4, 0.66)
		O(ci, c, ms * 0.13, 0.6, 1.2)
		for j in 6:
			D(ci, c + Vector2.from_angle(TAU * j / 6.0) * ms * 0.07, 0.7, 0.6)
		D(ci, c, 0.7, 0.6)
		_pu(ci, r, [Vector2(0.3 + k * 0.4, 0.79), Vector2(0.3 + k * 0.4, 0.98)], 0.55, 2.0)
	_lamp(ci, _u(r, 0.82, 0.3), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.85))
	for x in [0.16, 0.84]:
		O(ci, _u(r, x, 0.14), ms * 0.05, 0.5)
		L(ci, _u(r, x, 0.14 + 0.05), _u(r, x, 0.2), 0.5)
	_pu(ci, r, [Vector2(0.92, 0.5), Vector2(1.0, 0.5)], 0.45)


# ---------------------------------------------------------------- TW-64: hull support point
# a hull support for the tug's grip: the column, the screw jack head with its thread and the
# swivel pad, the locking ring, the base plate bolted down, the height marks
static func hull_support(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_pu(ci, r, [Vector2(0.1, 0.04), Vector2(0.9, 0.04), Vector2(0.8, 0.08), Vector2(0.2, 0.08), Vector2(0.1, 0.04)], 0.62, 1.3)
	R(ci, sub(r, 0.38, 0.08, 0.62, 0.3), 0.55)
	var th := PackedVector2Array()
	for k in 8:
		var y: float = 0.1 + k * 0.025
		th.append(_u(r, 0.38, y))
		th.append(_u(r, 0.62, y + 0.012))
	S(ci, th, 0.35)
	R(ci, sub(r, 0.26, 0.3, 0.74, 0.34), 0.6)
	R(ci, sub(r, 0.32, 0.34, 0.68, 0.92), 0.6, 1.3)
	var tk := PackedVector2Array()
	for k in 8:
		var y: float = 0.4 + k * 0.065
		tk.append(_u(r, 0.68, y))
		tk.append(_u(r, 0.68 + (0.14 if k % 4 == 0 else 0.07), y))
	S(ci, tk, 0.4)
	R(ci, sub(r, 0.04, 0.92, 0.96, 0.99), 0.62, 1.3)
	for x in [0.12, 0.88]:
		D(ci, _u(r, x, 0.955), 1.2, 0.6)


# ---------------------------------------------------------------- FR-26: tank temperature sensor
# a temperature sensor on the tank: the thermowell boss on the tank wall, the round head,
# its cable
static func tank_temp(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	A(ci, _u(r, 0.5, 2.2), r.size.y * 1.3, PI * 1.35, PI * 1.65, 0.5, 1.3)
	R(ci, sub(r, 0.36, 0.62, 0.64, 0.92), 0.6)
	var hc := _u(r, 0.5, 0.38)
	O(ci, hc, ms * 0.26, 0.62, 1.2)
	D(ci, hc, 1.0, 0.6)
	_lamp(ci, hc + Vector2(ms * 0.12, -ms * 0.08), 1.2, Pal.tint(Pal.AIR, 0.8))
	_pu(ci, r, [Vector2(0.76, 0.38), Vector2(1.0, 0.38)], 0.5, 1.2)


# ---------------------------------------------------------------- H-22: tension load cell
# a tension link: the two clevis eyes with their pins, the load cell body (the strain web),
# the gauge cable
static func tension_link(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	for x in [0.12, 0.88]:
		var c := _u(r, x, 0.5)
		O(ci, c, ms * 0.4, 0.62, 1.3)
		O(ci, c, ms * 0.16, 0.5)
	R(ci, sub(r, 0.3, 0.14, 0.7, 0.86), 0.62, 1.2)
	R(ci, sub(r, 0.4, 0.34, 0.6, 0.66), 0.4)
	L(ci, _u(r, 0.22, 0.5), _u(r, 0.3, 0.5), 0.55, 1.6)
	L(ci, _u(r, 0.7, 0.5), _u(r, 0.78, 0.5), 0.55, 1.6)
	L(ci, _u(r, 0.5, 0.86), _u(r, 0.5, 1.0), 0.45)


# ---------------------------------------------------------------- ARK-01: service cart (the small tool cart)
# a two-tier service cart: the top tray with its lip and the tools in it (spanner, hammer,
# screwdriver rack), the lower shelf with a toolbox and parts bins, the push handle, casters
static func _service_cart(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	for y in [0.36, 0.74]:
		_pu(ci, r, [Vector2(0.04, y - 0.08), Vector2(0.06, y), Vector2(0.84, y), Vector2(0.86, y - 0.08)], 0.6, 1.3)
	for x in [0.08, 0.82]:
		L(ci, _u(r, x, 0.36), _u(r, x, 0.84), 0.55, 1.4)
	L(ci, _u(r, 0.12, 0.26), _u(r, 0.36, 0.24), 0.6, 1.5)
	O(ci, _u(r, 0.1, 0.265), maxf(1.4, ms * 0.04), 0.5)
	L(ci, _u(r, 0.42, 0.28), _u(r, 0.58, 0.28), 0.55, 1.2)
	R(ci, Rect2(_u(r, 0.56, 0.28) + Vector2(0, -3.0), Vector2(r.size.x * 0.07, 4.5)), 0.6)
	R(ci, sub(r, 0.66, 0.16, 0.8, 0.27), 0.45)
	for k in 4:
		L(ci, _u(r, 0.68 + k * 0.035, 0.16), _u(r, 0.68 + k * 0.035, 0.08), 0.5, 1.3)
	var tb := sub(r, 0.12, 0.52, 0.48, 0.73)
	R(ci, tb, 0.58)
	A(ci, _u(r, 0.3, 0.52), r.size.x * 0.08, PI, TAU, 0.55, 1.3)
	L(ci, tb.position + Vector2(0, tb.size.y * 0.35), Vector2(tb.end.x, tb.position.y + tb.size.y * 0.35), 0.4)
	for k in 3:
		var bn := sub(r, 0.52 + k * 0.1, 0.6, 0.6 + k * 0.1, 0.73)
		R(ci, bn, 0.45)
		L(ci, bn.position + Vector2(1.5, 2.0), Vector2(bn.end.x - 1.5, bn.position.y + 2.0), 0.3)
	_pu(ci, r, [Vector2(0.84, 0.32), Vector2(0.96, 0.24), Vector2(0.96, 0.12)], 0.55, 1.4)
	var wr: float = ms * 0.06
	for x in [0.14, 0.76]:
		var wc := Vector2(_u(r, x, 0).x, _u(r, 0, 0.84).y + wr + 1.0)
		O(ci, wc, wr, 0.55, 1.2)
		L(ci, wc, Vector2(wc.x, _u(r, 0, 0.84).y), 0.45)


# ---------------------------------------------------------------- the small DC-DC converter (panel-mounted, six ships)
# a DIN-rail power brick: the finned top, the input and output screw terminals top and
# bottom, the trim potentiometer, the output lamp, the rail clip
static func _dcdc_brick(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.0, 0.5), _u(r, 1.0, 0.5), 0.4, 1.4)
	L(ci, _u(r, 0.0, 0.56), _u(r, 1.0, 0.56), 0.4, 1.4)
	var bx := sub(r, 0.18, 0.06, 0.82, 0.94)
	R(ci, bx, 0.62, 1.2)
	var fn := PackedVector2Array()
	for k in 5:
		var x: float = 0.24 + k * 0.13
		fn.append(_u(r, x, 0.06))
		fn.append(_u(r, x, 0.0))
	S(ci, fn, 0.45)
	for y in [0.16, 0.84]:
		for k in 3:
			var c := _u(r, 0.32 + k * 0.18, y)
			R(ci, Rect2(c - Vector2(ms * 0.06, ms * 0.05), Vector2(ms * 0.12, ms * 0.1)), 0.5)
			D(ci, c, 0.8, 0.6)
	var pc := _u(r, 0.38, 0.5)
	O(ci, pc, ms * 0.07, 0.55)
	L(ci, pc - Vector2(ms * 0.05, 0), pc + Vector2(ms * 0.05, 0), 0.55)
	_lamp(ci, _u(r, 0.64, 0.5), maxf(1.4, ms * 0.07), Pal.tint(Pal.FLUID, 0.85))


# ================================================================== sixth batch: engines and switchboards (2026-11-12)
# Engines exhaust to +x. Where the ship has a separate nozzle piece the core ends in its throat
# flange at the right edge's middle (the nozzle piece carries the bell); the rest draw their bell.

# a combustion chamber lying along x: injector face at x0, the cylinder, the convergent to the
# throat at x1 (half-height th), regen-cooling channels along it, the throat flange
static func _chamber(ci: CanvasItem, r: Rect2, x0: float, xc: float, x1: float, cy: float, ch: float, th: float, flange: bool = true, lite: bool = false) -> void:
	var up := PackedVector2Array([_u(r, x0, cy - ch), _u(r, xc, cy - ch), _u(r, x1, cy - th)])
	var dn := PackedVector2Array([_u(r, x0, cy + ch), _u(r, xc, cy + ch), _u(r, x1, cy + th)])
	P(ci, up, 0.68, 1.6)
	P(ci, dn, 0.68, 1.6)
	L(ci, _u(r, x0, cy - ch), _u(r, x0, cy + ch), 0.62, 1.6)
	var cc := PackedVector2Array()
	for k in 4:
		var y: float = cy - ch * 0.7 + k * ch * 0.47
		cc.append(_u(r, x0 + 0.02, y))
		cc.append(_u(r, xc - 0.01, y))
	S(ci, cc, 0.22)
	if flange:
		var fx: float = _u(r, x1, 0).x
		L(ci, Vector2(fx - 1.0, _u(r, 0, cy - th * 1.6).y), Vector2(fx - 1.0, _u(r, 0, cy + th * 1.6).y), 0.62, 2.0)
	# the injector dome and its bolt ring, the jacket manifolds, coolant stubs, taps, the
	# insulation ticks on the convergent
	var hh: float = r.size.y * ch
	A(ci, _u(r, x0, cy), hh * 0.9, PI * 0.5, PI * 1.5, 0.5, 1.2)
	if not lite:
		E.bolts(ci, _u(r, x0, cy - ch * 0.85), _u(r, x0, cy + ch * 0.85), 6, 0.55, 0.9)
	var dr := PackedVector2Array()
	for f in [0.3, 0.75]:
		var x: float = lerpf(x0, xc, f)
		dr.append(_u(r, x, cy - ch - 0.02))
		dr.append(_u(r, x, cy + ch + 0.02))
	var xs: float = lerpf(xc, x1, 0.25)
	dr.append(_u(r, xs, cy - ch * 0.9))
	dr.append(_u(r, xs, cy - ch * 1.4))
	dr.append(_u(r, xs, cy + ch * 0.9))
	dr.append(_u(r, xs, cy + ch * 1.4))
	for f in [0.2, 0.5]:
		var x: float = lerpf(x0, xc, f)
		dr.append(_u(r, x, cy - ch))
		dr.append(_u(r, x, cy - ch * 1.3))
	for k in 4:
		var t: float = (k + 0.5) / 4.0
		var x: float = lerpf(xc, x1, t)
		var hy: float = lerpf(ch, th, t)
		dr.append(_u(r, x, cy - hy))
		dr.append(_u(r, x - 0.015, cy - hy - 0.04))
		dr.append(_u(r, x, cy + hy))
		dr.append(_u(r, x - 0.015, cy + hy + 0.04))
	S(ci, dr, 0.42, 1.2)
	for f in ([] if lite else [0.2, 0.5]):
		D(ci, _u(r, lerpf(x0, xc, f), cy - ch * 1.3), 1.0, 0.55)
	for sgn in [-1.0, 1.0]:
		R(ci, Rect2(_u(r, xs, cy + sgn * ch * 1.4) - Vector2(2.5, 1.5), Vector2(5.0, 3.0)), 0.5)


# a turbopump: the pump volute, the shaft to the turbine wheel, the turbine exhaust stub
static func _tpump(ci: CanvasItem, c: Vector2, rad: float, up: bool = true) -> void:
	O(ci, c, rad, 0.46, 1.0)
	D(ci, c, maxf(1.0, rad * 0.25), 0.55)
	var tc := c + Vector2(rad * 2.0, 0)
	R(ci, Rect2(c + Vector2(rad, -rad * 0.25), Vector2(rad * 0.6, rad * 0.5)), 0.4)
	R(ci, Rect2(tc - Vector2(rad * 0.4, rad * 0.75), Vector2(rad * 0.8, rad * 1.5)), 0.46)
	L(ci, tc + Vector2(0, -rad * 0.75 if up else rad * 0.75), tc + Vector2(rad * 0.6, -rad * 1.5 if up else rad * 1.5), 0.4, 1.1)


# a bell from (x0, cy±h0) to (x1, cy±h1), drawn with its stiffening rings
static func _bell(ci: CanvasItem, r: Rect2, x0: float, x1: float, cy: float, h0: float, h1: float, rings: int = 2) -> void:
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	var rg := PackedVector2Array()
	for k in 9:
		var t: float = k / 8.0
		var h: float = h0 + (h1 - h0) * pow(t, 0.6)
		var x: float = lerpf(x0, x1, t)
		up.append(_u(r, x, cy - h))
		dn.append(_u(r, x, cy + h))
		if rings > 0 and (k == 3 or (rings > 1 and k == 6)):
			rg.append(_u(r, x, cy - h))
			rg.append(_u(r, x, cy + h))
	P(ci, up, 0.62, 1.3)
	P(ci, dn, 0.62, 1.3)
	rg.append(up[8])
	rg.append(dn[8])
	S(ci, rg, 0.35)


# ---------------------------------------------------------------- the main engine (31 on many ships; ARK-01 x5)
# a staged-combustion main engine core, nozzle piece to the right: the two turbopumps (fuel
# below, oxidiser above) and the preburner between them, the hot-gas manifold into the
# injector, the chamber with its cooling channels to the throat flange, the gimbal block and
# its two actuators on top, the feed line in from the left
static func main_engine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cy: float = 0.5
	_chamber(ci, r, 0.46, 0.8, 1.0, cy, 0.22, 0.12)
	var pr: float = ms * 0.12
	_tpump(ci, _u(r, 0.12, 0.24), pr, true)
	_tpump(ci, _u(r, 0.12, 0.76), pr, false)
	var pb := sub(r, 0.3, 0.38, 0.42, 0.62)
	R(ci, pb, 0.6, 1.2)
	E.Rc(ci, pb.grow(-2.0), Pal.heat(0.4), 1.0)
	var ln := PackedVector2Array([_u(r, 0.12, 0.24) + Vector2(0, pr), _u(r, 0.12, 0.38), _u(r, 0.12, 0.76) - Vector2(0, pr), _u(r, 0.12, 0.62),
		_u(r, 0.12, 0.38), _u(r, 0.3, 0.45), _u(r, 0.12, 0.62), _u(r, 0.3, 0.55), _u(r, 0.42, 0.5), _u(r, 0.46, 0.5)])
	S(ci, ln, 0.5, 1.4)
	L(ci, _u(r, 0.0, 0.5), _u(r, 0.06, 0.5), 0.55, 1.6)
	var gb := sub(r, 0.56, 0.06, 0.7, 0.2)
	R(ci, gb, 0.6, 1.2)
	D(ci, gb.get_center(), 1.4, 0.6)
	S(ci, PackedVector2Array([_u(r, 0.6, 0.2), _u(r, 0.6, 0.28), _u(r, 0.66, 0.2), _u(r, 0.66, 0.28),
		_u(r, 0.5, 0.06), _u(r, 0.6, 0.06), _u(r, 0.76, 0.06), _u(r, 0.86, 0.06)]), 0.5, 1.4)
	for x in [0.5, 0.86]:
		R(ci, Rect2(_u(r, x, 0.06) - Vector2(2.5, 0), Vector2(5.0, r.size.y * 0.16)), 0.5)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.5) - Vector2(0, 0.6), Vector2(r.size.x * 0.06, 1.2)), Pal.tint(Pal.FLUID, 0.55), 1.0)
	# main valves on the pump discharges, the gimbal actuator rods, the pump inlet flanges
	for y in [0.33, 0.67]:
		_bowtie(ci, _u(r, 0.12, y), maxf(2.0, ms * 0.04), true)
		E.flange(ci, _u(r, 0.06, 0.24 if y < 0.5 else 0.76), Vector2.LEFT, ms * 0.06, 0.5)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.2), _u(r, 0.54, 0.28), _u(r, 0.86, 0.2), _u(r, 0.76, 0.28)]), 0.55, 1.6)
	L(ci, _u(r, 0.0, 0.24), _u(r, 0.06, 0.24), 0.5, 1.4)
	L(ci, _u(r, 0.0, 0.76), _u(r, 0.06, 0.76), 0.5, 1.4)


# ---------------------------------------------------------------- the big main engine (FL-116, MF-126, PT-34)
# a large closed-cycle engine core: the ring manifold round the injector, two preburners
# feeding it, the regenerative jacket's tube bundle along the chamber, the turbopump pair set
# low, the heat exchanger loop, the thrust frame struts back to the hull
static func big_engine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cy: float = 0.45
	_chamber(ci, r, 0.42, 0.78, 1.0, cy, 0.26, 0.14)
	var tb := PackedVector2Array()
	for k in 7:
		var y: float = cy - 0.24 + k * 0.08
		tb.append(_u(r, 0.44, y))
		tb.append(_u(r, 0.76, y))
	S(ci, tb, 0.18)
	R(ci, sub(r, 0.37, cy - 0.3, 0.42, cy + 0.3), 0.6, 1.3)
	for s in [-1.0, 1.0]:
		var pbr := sub(r, 0.22, cy + s * 0.2 - 0.07, 0.34, cy + s * 0.2 + 0.07)
		R(ci, pbr, 0.58)
		E.Rc(ci, pbr.grow(-2.0), Pal.heat(0.4), 1.0)
		L(ci, pbr.position + Vector2(pbr.size.x, pbr.size.y * 0.5), _u(r, 0.37, cy + s * 0.2), 0.5, 1.4)
	var pr: float = ms * 0.08
	_tpump(ci, _u(r, 0.06, 0.82), pr, false)
	_tpump(ci, _u(r, 0.28, 0.82), pr, false)
	S(ci, PackedVector2Array([_u(r, 0.06, 0.82) - Vector2(0, pr), _u(r, 0.22, 0.65), _u(r, 0.28, 0.82) - Vector2(0, pr), _u(r, 0.28, 0.32)]), 0.45, 1.3)
	var hx := sub(r, 0.5, 0.78, 0.72, 0.92)
	R(ci, hx, 0.5)
	var hz := PackedVector2Array()
	for k in 7:
		hz.append(_u(r, 0.52 + k * 0.03, 0.8 if k % 2 == 0 else 0.9))
	P(ci, hz, 0.4)
	S(ci, PackedVector2Array([_u(r, 0.61, 0.78), _u(r, 0.61, cy + 0.26), _u(r, 0.0, 0.1), _u(r, 0.42, cy - 0.3), _u(r, 0.0, 0.9), _u(r, 0.42, cy + 0.3)]), 0.4, 1.4)


# ---------------------------------------------------------------- TW-64: engine pod
# an external engine pod: the streamlined nacelle (its access panels and the inlet lip), the
# engine core inside it (turbopump, chamber to the throat flange at the tail), the pylon up
# to the hull with its two attachment pins
static func engine_pod(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var nc := PackedVector2Array()
	for k in 13:
		var t: float = k / 12.0
		nc.append(_u(r, 0.02 + 0.96 * t, 0.5 - 0.36 * sin(PI * clampf(t * 0.9 + 0.1, 0.0, 1.0)) - 0.04))
	for k in 13:
		var t: float = 1.0 - k / 12.0
		nc.append(_u(r, 0.02 + 0.96 * t, 0.5 + 0.34 * sin(PI * clampf(t * 0.9 + 0.1, 0.0, 1.0)) + 0.04))
	nc.append(nc[0])
	P(ci, nc, 0.62, 1.4)
	var pn := PackedVector2Array()
	for x in [0.28, 0.5, 0.72]:
		pn.append(_u(r, x, 0.16))
		pn.append(_u(r, x, 0.84))
	S(ci, pn, 0.25)
	_chamber(ci, r, 0.46, 0.8, 1.0, 0.5, 0.16, 0.1)
	_tpump(ci, _u(r, 0.2, 0.5), ms * 0.1, true)
	L(ci, _u(r, 0.2, 0.5) + Vector2(ms * 0.1 * 2.4, 0), _u(r, 0.46, 0.5), 0.5, 1.4)
	_pu(ci, r, [Vector2(0.4, 0.14), Vector2(0.44, 0.0), Vector2(0.62, 0.0), Vector2(0.66, 0.14)], 0.58, 1.3)
	for x in [0.46, 0.6]:
		D(ci, _u(r, x, 0.04), 1.4, 0.6)
	# inlet louvres in the nose, the feed tank, the access hatches
	var lv := PackedVector2Array()
	for k in 4:
		var y: float = 0.38 + k * 0.08
		lv.append(_u(r, 0.04, y))
		lv.append(_u(r, 0.09, y + 0.03))
	S(ci, lv, 0.4)
	E.vessel_h(ci, sub(r, 0.06, 0.62, 0.3, 0.76), 0.45)
	for x in [0.3, 0.56]:
		R(ci, sub(r, x, 0.16, x + 0.1, 0.24), 0.4)


# ---------------------------------------------------------------- CL-104: separable power tail
# the power tail module: the forward tank dome, the separation ring with its pyro bolts, the
# thrust structure (cone of struts), the engine core between them to the throat flange, the
# umbilical plate
static func power_tail(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.04, 0.08, 0.96), 0.62, 1.4)
	var pb := PackedVector2Array()
	for k in 7:
		pb.append(_u(r, 0.05, 0.1 + k * 0.133))
	for c in pb:
		D(ci, c, 1.4, 0.6)
	A(ci, _u(r, 0.08, 0.5), r.size.y * 0.4, -PI * 0.5, PI * 0.5, 0.55, 1.3)
	_chamber(ci, r, 0.5, 0.8, 1.0, 0.5, 0.18, 0.1)
	S(ci, PackedVector2Array([_u(r, 0.08, 0.06), _u(r, 0.5, 0.32), _u(r, 0.08, 0.94), _u(r, 0.5, 0.68),
		_u(r, 0.08, 0.3), _u(r, 0.5, 0.32), _u(r, 0.08, 0.7), _u(r, 0.5, 0.68), _u(r, 0.5, 0.32), _u(r, 0.5, 0.68)]), 0.45, 1.3)
	_tpump(ci, _u(r, 0.56, 0.16), ms * 0.06, true)
	_tpump(ci, _u(r, 0.56, 0.84), ms * 0.06, false)
	var up := sub(r, 0.1, 0.84, 0.22, 0.94)
	R(ci, up, 0.55)
	S(ci, PackedVector2Array([up.position + Vector2(3, up.size.y * 0.5), up.end - Vector2(3, up.size.y * 0.5)]), 0.4)
	for k in 3:
		D(ci, up.position + Vector2(up.size.x * (0.25 + k * 0.25), up.size.y * 0.3), 0.9, 0.55)
	for f in [0.6, 0.8]:
		A(ci, _u(r, 0.08, 0.5), r.size.y * 0.4 * f, -PI * 0.42, PI * 0.42, 0.25)


# ---------------------------------------------------------------- GR-7: central propulsion assembly
# the small ship's centre section: three small thrust chambers on a common thrust plate fed by
# the propellant manifold, their valve blocks, the central outlet flange to the nozzle
static func engine_cluster(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.1, 0.1, 0.9), 0.62, 1.3)
	L(ci, _u(r, 0.18, 0.08), _u(r, 0.18, 0.92), 0.5, 1.4)
	for k in 3:
		var cy: float = 0.22 + k * 0.28
		R(ci, sub(r, 0.12, cy - 0.06, 0.18, cy + 0.06), 0.55)
		_chamber(ci, r, 0.22, 0.6, 0.86, cy, 0.09, 0.05, false)
		L(ci, _u(r, 0.86, cy), _u(r, 0.96, 0.5), 0.45, 1.3)
	L(ci, _u(r, 0.99, 0.32), _u(r, 0.99, 0.68), 0.62, 2.0)
	E.Rc(ci, Rect2(_u(r, 0.18, 0.08) - Vector2(0.6, 0), Vector2(1.2, r.size.y * 0.84)), Pal.tint(Pal.FLUID, 0.5), 1.0)


# ---------------------------------------------------------------- GR-7: engine front interface
# the front end of the engine: the injector head plate and its bolt circle, the fuel inlet and
# its valve, the coolant in and out to the generator and radiator, the gimbal ring
static func engine_front(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var hp := sub(r, 0.62, 0.2, 0.78, 0.8)
	R(ci, hp, 0.62, 1.3)
	E.bolts(ci, _u(r, 0.7, 0.24), _u(r, 0.7, 0.76), 5, 0.55, 1.0)
	R(ci, sub(r, 0.78, 0.26, 1.0, 0.74), 0.55)
	O(ci, _u(r, 0.89, 0.5), ms * 0.14, 0.5)
	O(ci, _u(r, 0.89, 0.5), ms * 0.08, 0.4)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.5), _u(r, 0.62, 0.5), _u(r, 0.0, 0.2), _u(r, 0.4, 0.2), _u(r, 0.4, 0.2), _u(r, 0.4, 0.3),
		_u(r, 0.0, 0.8), _u(r, 0.4, 0.8), _u(r, 0.4, 0.8), _u(r, 0.4, 0.7)]), 0.55, 1.4)
	_bowtie(ci, _u(r, 0.3, 0.5), maxf(2.0, ms * 0.05))
	L(ci, _u(r, 0.3, 0.5), _u(r, 0.3, 0.4), 0.45)
	R(ci, sub(r, 0.34, 0.3, 0.46, 0.38), 0.5)
	R(ci, sub(r, 0.34, 0.62, 0.46, 0.7), 0.5)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.5) - Vector2(0, 0.6), Vector2(r.size.x * 0.3, 1.2)), Pal.tint(Pal.FLUID, 0.5), 1.0)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.2) - Vector2(0, 0.6), Vector2(r.size.x * 0.4, 1.2)), Pal.tint(Pal.AIR, 0.5), 1.0)


# ---------------------------------------------------------------- the small main thruster (eng_front; FR-26, H-22, M-14, MED-47, S-09)
# a pressure-fed thruster head, nozzle piece to the right: the twin propellant valves, the
# injector, the short chamber to the throat flange, the gimbal pivot (kept light: M-14, S-09;
# the chamber drawn without its bolt circle and tap dots)
static func small_thruster(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_chamber(ci, r, 0.4, 0.72, 1.0, 0.5, 0.2, 0.12, true, true)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 0.3, 0.3), _u(r, 0.0, 0.7), _u(r, 0.3, 0.7),
		_u(r, 0.3, 0.3), _u(r, 0.4, 0.42), _u(r, 0.3, 0.7), _u(r, 0.4, 0.58)]), 0.55, 1.3)
	for y in [0.3, 0.7]:
		R(ci, sub(r, 0.12, y - 0.08, 0.24, y + 0.08), 0.55)
	L(ci, _u(r, 0.56, 0.2), _u(r, 0.56, 0.02), 0.5, 1.4)


# ---------------------------------------------------------------- ARK-01: shuttle engine (own bell)
# the shuttle's pressure-fed pintle engine, no pumps at all: two propellant spheres strapped
# to the thrust plate behind (drawn back), the helium bottle that pushes them, the valve tree
# and its two actuators, the pintle rod through a flat injector face into a short squat
# chamber, the gimbal ring at the throat with two actuator rods, the short wide bell
static func shuttle_engine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var back := PackedVector2Array()
	for y in [0.26, 0.74]:
		var c := _u(r, 0.15, y)
		O(ci, c, ms * 0.14, 0.4, 1.0)
		back.append(c - Vector2(ms * 0.14, 0))
		back.append(c + Vector2(ms * 0.14, 0))
		back.append(c + Vector2(-ms * 0.05, -ms * 0.135))
		back.append(c + Vector2(-ms * 0.05, ms * 0.135))
	# straps to the thrust plate, the plate, the helium bottle and its regulator line
	back.append_array(PackedVector2Array([_u(r, 0.15, 0.26) + Vector2(ms * 0.1, -ms * 0.1), _u(r, 0.33, 0.12),
		_u(r, 0.15, 0.74) + Vector2(ms * 0.1, ms * 0.1), _u(r, 0.33, 0.88), _u(r, 0.33, 0.06), _u(r, 0.33, 0.94),
		_u(r, 0.06, 0.47), _u(r, 0.06, 0.53), _u(r, 0.06, 0.5), _u(r, 0.27, 0.5)]))
	S(ci, back, 0.36, 1.0)
	_ell(ci, _u(r, 0.06, 0.5), ms * 0.03, ms * 0.085, 0.45)
	# the valve tree: two lines from the spheres into the bipropellant valve, its actuators
	var vt := sub(r, 0.27, 0.42, 0.36, 0.58)
	R(ci, vt, 0.6, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.22, 0.34), _u(r, 0.3, 0.42), _u(r, 0.22, 0.66), _u(r, 0.3, 0.58),
		_u(r, 0.29, 0.42), _u(r, 0.29, 0.34), _u(r, 0.34, 0.58), _u(r, 0.34, 0.66)]), 0.55, 1.4)
	R(ci, sub(r, 0.26, 0.29, 0.32, 0.34), 0.5)
	R(ci, sub(r, 0.31, 0.66, 0.37, 0.71), 0.5)
	# the chamber: flat injector face, the pintle rod through it, the short barrel, the throat
	var ch := PackedVector2Array([_u(r, 0.42, 0.3), _u(r, 0.56, 0.3), _u(r, 0.63, 0.42), _u(r, 0.63, 0.58), _u(r, 0.56, 0.7), _u(r, 0.42, 0.7), _u(r, 0.42, 0.3)])
	P(ci, ch, 0.66, 1.5)
	L(ci, _u(r, 0.36, 0.5), _u(r, 0.5, 0.5), 0.62, 2.2)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.47), _u(r, 0.53, 0.44), _u(r, 0.5, 0.53), _u(r, 0.53, 0.56),
		_u(r, 0.44, 0.3), _u(r, 0.44, 0.7), _u(r, 0.49, 0.3), _u(r, 0.49, 0.36), _u(r, 0.49, 0.64), _u(r, 0.49, 0.7)]), 0.45, 1.1)
	E.bolts(ci, _u(r, 0.42, 0.33), _u(r, 0.42, 0.67), 5, 0.55, 0.9)
	# the gimbal ring round the throat, its two actuators back to the plate
	_ell(ci, _u(r, 0.635, 0.5), ms * 0.035, ms * 0.12, 0.6, 1.4)
	S(ci, PackedVector2Array([_u(r, 0.33, 0.12), _u(r, 0.6, 0.3), _u(r, 0.33, 0.88), _u(r, 0.6, 0.7)]), 0.55, 1.8)
	D(ci, _u(r, 0.6, 0.3), 1.2, 0.6)
	D(ci, _u(r, 0.6, 0.7), 1.2, 0.6)
	# the short, wide bell
	_bell(ci, r, 0.63, 0.98, 0.5, 0.08, 0.46, 1)
	L(ci, _u(r, 0.98, 0.04), _u(r, 0.98, 0.96), 0.62, 1.8)


# ---------------------------------------------------------------- ARK-01: spare shuttle engine
# the same pintle engine as a spare, stood bell-down in its transport cage: the cage with its
# diagonals, the lifting eye on top, the engine hung on four shock mounts (zig-zag springs),
# the gimbal actuators pinned in the stowed position (pin flags), the protective cap over the
# bell's mouth, the cap's strap and the desiccant plug
static func spare_engine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cg := sub(r, 0.06, 0.06, 0.94, 0.96)
	R(ci, cg, 0.5, 1.3)
	S(ci, PackedVector2Array([_u(r, 0.06, 0.06), _u(r, 0.22, 0.4), _u(r, 0.94, 0.06), _u(r, 0.78, 0.4),
		_u(r, 0.06, 0.96), _u(r, 0.2, 0.7), _u(r, 0.94, 0.96), _u(r, 0.8, 0.7), _u(r, 0.06, 0.5), _u(r, 0.94, 0.5),
		_u(r, 0.5, 0.06), _u(r, 0.5, 0.0), _u(r, 0.0, 0.96), _u(r, 1.0, 0.96)]), 0.38, 1.0)
	O(ci, _u(r, 0.5, 0.025), ms * 0.025, 0.55)
	# the engine, bell down: injector face, pintle stub, squat chamber, throat, bell
	var ch := PackedVector2Array([_u(r, 0.38, 0.16), _u(r, 0.62, 0.16), _u(r, 0.62, 0.3), _u(r, 0.56, 0.38), _u(r, 0.44, 0.38), _u(r, 0.38, 0.3), _u(r, 0.38, 0.16)])
	P(ci, ch, 0.66, 1.5)
	L(ci, _u(r, 0.5, 0.1), _u(r, 0.5, 0.24), 0.6, 2.0)
	E.bolts(ci, _u(r, 0.4, 0.16), _u(r, 0.6, 0.16), 5, 0.55, 0.9)
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	for k in 7:
		var t: float = k / 6.0
		var w: float = 0.06 + 0.26 * pow(t, 0.6)
		var y: float = lerpf(0.38, 0.86, t)
		up.append(_u(r, 0.5 - w, y))
		dn.append(_u(r, 0.5 + w, y))
	P(ci, up, 0.62, 1.3)
	P(ci, dn, 0.62, 1.3)
	L(ci, up[3], dn[3], 0.35)
	_ell(ci, _u(r, 0.5, 0.38), ms * 0.085, ms * 0.03, 0.6, 1.3)
	# the cap over the mouth, its strap and plug
	R(ci, sub(r, 0.16, 0.86, 0.84, 0.91), 0.62, 1.4)
	E.Rc(ci, sub(r, 0.46, 0.865, 0.54, 0.905), Pal.tint(Pal.AIR, 0.6), 1.0)
	S(ci, PackedVector2Array([_u(r, 0.18, 0.86), _u(r, 0.44, 0.38), _u(r, 0.82, 0.86), _u(r, 0.56, 0.38)]), 0.3, 1.0)
	# four shock mounts from the cage to the chamber's hard points
	for sx in [-1.0, 1.0]:
		for y in [0.2, 0.32]:
			var a := _u(r, 0.5 + sx * 0.12, y)
			var b := _u(r, 0.5 + sx * 0.4, y)
			var z := PackedVector2Array()
			for k in 7:
				z.append(a.lerp(b, k / 6.0) + Vector2(0, ms * 0.025 * (1 if k % 2 else -1) * (0 if k == 0 or k == 6 else 1)))
			P(ci, z, 0.5, 1.0)
	# the stowed actuators and their pin flags
	S(ci, PackedVector2Array([_u(r, 0.22, 0.5), _u(r, 0.4, 0.6), _u(r, 0.78, 0.5), _u(r, 0.6, 0.6)]), 0.55, 1.8)
	for x in [0.2, 0.8]:
		_lamp(ci, _u(r, x, 0.55), maxf(1.4, ms * 0.04), Pal.heat(0.8))


# ---------------------------------------------------------------- BELT / TUG: tug main engine
# the tug's rugged pressure-fed engine: the ablative chamber (its liner hatched), the
# throttling valve and the propellant valve block, the heat shield plate, the short bell
static func tug_engine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	_chamber(ci, r, 0.3, 0.52, 0.62, 0.5, 0.2, 0.1, false)
	hatch(ci, sub(r, 0.32, 0.36, 0.5, 0.64), 2.4, false, 0.25, 14)
	_bell(ci, r, 0.62, 0.98, 0.5, 0.1, 0.36, 1)
	R(ci, sub(r, 0.08, 0.32, 0.24, 0.68), 0.6, 1.2)
	for y in [0.4, 0.6]:
		D(ci, _u(r, 0.16, y), 1.4, 0.6)
	S(ci, PackedVector2Array([_u(r, 0.24, 0.42), _u(r, 0.3, 0.42), _u(r, 0.24, 0.58), _u(r, 0.3, 0.58), _u(r, 0.0, 0.4), _u(r, 0.08, 0.4)]), 0.5, 1.3)
	var tv := _u(r, 0.16, 0.2)
	O(ci, tv, ms * 0.07, 0.55)
	L(ci, tv, tv + Vector2(ms * 0.08, -ms * 0.06), 0.55, 1.3)
	L(ci, _u(r, 0.16, 0.27), _u(r, 0.16, 0.32), 0.45)
	L(ci, _u(r, 0.27, 0.1), _u(r, 0.27, 0.9), 0.5, 2.0)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.4) - Vector2(0, 0.6), Vector2(r.size.x * 0.08, 1.2)), Pal.tint(Pal.FLUID, 0.55), 1.0)


# ---------------------------------------------------------------- LC-140 / DR-150 / HG-170: main engine (own bell)
# a gas-generator engine laid out for a tall bay: the thrust frame (a truss from the bay's top
# to the gimbal bearing), the long chamber with its injector manifold torus, the long tube-wall
# bell (the cooling tubes drawn along it) with the fuel inlet manifold half-way down; under it
# the turbopump on one shaft (oxidiser pump, fuel pump, turbine), the gas generator over the
# turbine, the turbine exhaust duct run along the bay floor to its own small flared outlet
static func gg_engine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cy: float = 0.36
	# the thrust frame (drawn back) and the two pitch/yaw actuators
	S(ci, PackedVector2Array([_u(r, 0.04, 0.02), _u(r, 0.6, 0.02), _u(r, 0.04, 0.02), _u(r, 0.22, 0.17), _u(r, 0.4, 0.02), _u(r, 0.22, 0.17),
		_u(r, 0.22, 0.02), _u(r, 0.22, 0.17)]), 0.38, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.02), _u(r, 0.6, 0.2), _u(r, 0.6, 0.02), _u(r, 0.76, 0.17)]), 0.55, 1.8)
	O(ci, _u(r, 0.22, 0.19), ms * 0.025, 0.6, 1.3)
	# the chamber, long, with the injector manifold torus at its head
	var ch := PackedVector2Array([_u(r, 0.1, cy - 0.12), _u(r, 0.3, cy - 0.12), _u(r, 0.4, cy - 0.05), _u(r, 0.4, cy + 0.05), _u(r, 0.3, cy + 0.12), _u(r, 0.1, cy + 0.12), _u(r, 0.1, cy - 0.12)])
	P(ci, ch, 0.66, 1.5)
	_ell(ci, _u(r, 0.1, cy), ms * 0.03, ms * 0.1, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.16, cy - 0.12), _u(r, 0.16, cy + 0.12), _u(r, 0.24, cy - 0.12), _u(r, 0.24, cy + 0.12)]), 0.35, 1.0)
	# the long tube-wall bell, its tubes and the fuel inlet manifold
	_bell(ci, r, 0.4, 0.98, cy, 0.05, 0.3, 0)
	var tb := PackedVector2Array()
	for f in [-0.55, 0.0, 0.55]:
		for k in 6:
			var t0: float = k / 6.0
			var t1: float = (k + 1) / 6.0
			tb.append(_u(r, lerpf(0.4, 0.98, t0), cy + f * (0.05 + 0.25 * pow(t0, 0.6))))
			tb.append(_u(r, lerpf(0.4, 0.98, t1), cy + f * (0.05 + 0.25 * pow(t1, 0.6))))
	S(ci, tb, 0.28, 1.0)
	var mx: float = 0.66
	var mh: float = 0.05 + 0.25 * pow((mx - 0.4) / 0.58, 0.6)
	L(ci, _u(r, mx, cy - mh - 0.015), _u(r, mx, cy + mh + 0.015), 0.62, 2.2)
	# the turbopump on its shaft: the two pump volutes, the turbine with its blades
	var sy: float = 0.8
	L(ci, _u(r, 0.04, sy), _u(r, 0.48, sy), 0.5, 1.4)
	for x in [0.1, 0.22]:
		_ell(ci, _u(r, x, sy), ms * 0.045, ms * 0.1, 0.6, 1.3)
	var tw := sub(r, 0.32, sy - 0.07, 0.42, sy + 0.07)
	R(ci, tw, 0.6, 1.3)
	var bl := PackedVector2Array()
	for k in 5:
		var y: float = sy - 0.055 + k * 0.0275
		bl.append(_u(r, 0.34, y))
		bl.append(_u(r, 0.4, y + 0.012))
	S(ci, bl, 0.4)
	# the gas generator over the turbine, its two small feed lines
	var gg := sub(r, 0.33, 0.6, 0.41, 0.69)
	R(ci, gg, 0.58)
	E.Rc(ci, gg.grow(-1.5), Pal.heat(0.4), 1.0)
	# feeds: oxidiser pump up to the injector torus, fuel pump to the bell manifold, the
	# small feeds of the gas generator, the turbine exhaust duct along the floor and out
	S(ci, PackedVector2Array([_u(r, 0.1, sy - 0.1), _u(r, 0.1, cy + 0.12),
		_u(r, 0.22, sy - 0.1), _u(r, 0.22, 0.56), _u(r, 0.22, 0.56), _u(r, mx, 0.56), _u(r, mx, 0.56), _u(r, mx, cy + mh + 0.015),
		_u(r, 0.13, 0.66), _u(r, 0.33, 0.645), _u(r, 0.25, 0.6), _u(r, 0.33, 0.62)]), 0.5, 1.3)
	S(ci, PackedVector2Array([_u(r, 0.42, sy), _u(r, 0.5, sy), _u(r, 0.5, sy), _u(r, 0.54, 0.9), _u(r, 0.54, 0.9), _u(r, 0.86, 0.9),
		_u(r, 0.86, 0.9), _u(r, 0.98, 0.86), _u(r, 0.86, 0.9), _u(r, 0.98, 0.94),
		_u(r, 0.62, 0.9), _u(r, 0.62, 0.96), _u(r, 0.76, 0.9), _u(r, 0.76, 0.96)]), 0.55, 1.6)


# ---------------------------------------------------------------- LC-140: courier engine
# the courier's expander-cycle upper-stage engine: a thrust cone from the bay wall to the
# injector, the small chamber and its long cooling jacket, the pump standing upright over the
# chamber (inducer, pump, turbine on one vertical shaft) driven by the warm gas from the jacket
# and returning it to the injector, the short fixed bell, and the radiation-cooled extension
# skirt stowed round it on two ball-screw rails (their drive motors at the rear end, the rails
# run on to where the skirt goes when it is deployed)
static func courier_engine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cy: float = 0.56
	# the thrust cone from the bay wall
	S(ci, PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 0.08, cy - 0.08), _u(r, 0.0, 0.82), _u(r, 0.08, cy + 0.08),
		_u(r, 0.0, 0.3), _u(r, 0.0, 0.82)]), 0.4, 1.4)
	# the chamber and its long jacket to the throat
	var ch := PackedVector2Array([_u(r, 0.08, cy - 0.09), _u(r, 0.24, cy - 0.09), _u(r, 0.3, cy - 0.04), _u(r, 0.3, cy + 0.04), _u(r, 0.24, cy + 0.09), _u(r, 0.08, cy + 0.09), _u(r, 0.08, cy - 0.09)])
	P(ci, ch, 0.66, 1.5)
	var jk := PackedVector2Array()
	for k in 5:
		var x: float = 0.1 + k * 0.035
		jk.append(_u(r, x, cy - 0.09))
		jk.append(_u(r, x, cy + 0.09))
	S(ci, jk, 0.3)
	# the upright pump: inducer, pump housing, turbine; the expander loop
	var ph := sub(r, 0.12, 0.08, 0.22, 0.2)
	R(ci, ph, 0.6, 1.3)
	R(ci, sub(r, 0.14, 0.2, 0.2, 0.3), 0.55)
	_ell(ci, _u(r, 0.17, 0.05), ms * 0.06, ms * 0.025, 0.6, 1.2)
	L(ci, _u(r, 0.17, 0.03), _u(r, 0.17, 0.3), 0.4)
	S(ci, PackedVector2Array([_u(r, 0.27, cy - 0.07), _u(r, 0.3, 0.12), _u(r, 0.3, 0.12), _u(r, 0.22, 0.12),
		_u(r, 0.12, 0.14), _u(r, 0.05, 0.14), _u(r, 0.05, 0.14), _u(r, 0.05, cy - 0.04), _u(r, 0.05, cy - 0.04), _u(r, 0.08, cy - 0.04),
		_u(r, 0.17, 0.3), _u(r, 0.17, cy - 0.09)]), 0.5, 1.3)
	E.Rc(ci, sub(r, 0.285, 0.18, 0.315, 0.36), Pal.tint(Pal.AIR, 0.5), 1.0)
	# the short fixed bell, its exit flange
	_bell(ci, r, 0.3, 0.58, cy, 0.04, 0.2, 1)
	L(ci, _u(r, 0.58, cy - 0.21), _u(r, 0.58, cy + 0.21), 0.62, 1.8)
	# the stowed skirt round it (drawn back), its ring
	var su := PackedVector2Array([_u(r, 0.36, cy - 0.24), _u(r, 0.62, cy - 0.34)])
	var sd := PackedVector2Array([_u(r, 0.36, cy + 0.24), _u(r, 0.62, cy + 0.34)])
	S(ci, PackedVector2Array([su[0], su[1], sd[0], sd[1], su[0], sd[0], su[1], sd[1],
		_u(r, 0.49, cy - 0.29), _u(r, 0.49, cy + 0.29)]), 0.38, 1.2)
	# the two ball-screw rails and their motors
	var rl := PackedVector2Array()
	for sgn in [-1.0, 1.0]:
		var y: float = cy + sgn * 0.4
		rl.append(_u(r, 0.32, y))
		rl.append(_u(r, 0.98, y))
		for k in 7:
			var x: float = 0.4 + k * 0.08
			rl.append(_u(r, x, y - 0.015))
			rl.append(_u(r, x + 0.03, y + 0.015))
		rl.append(_u(r, 0.62, cy + sgn * 0.34))
		rl.append(_u(r, 0.62, y))
		R(ci, Rect2(_u(r, 0.26, y) - Vector2(0, ms * 0.035), Vector2(r.size.x * 0.06, ms * 0.07)), 0.58)
	S(ci, rl, 0.5, 1.1)


# ---------------------------------------------------------------- M-14: high-load motor
# the mine's high-load drive motor: the finned frame, the fan cowl, the terminal box and its
# cable, the gear reducer bolted on, the output coupling (kept light)
static func hl_motor(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	E.motor(ci, sub(r, 0.04, 0.24, 0.6, 0.88), false, 0.58)
	var gb := sub(r, 0.62, 0.2, 0.9, 0.9)
	R(ci, gb, 0.6, 1.3)
	O(ci, _u(r, 0.76, 0.42), ms * 0.12, 0.45)
	O(ci, _u(r, 0.76, 0.7), ms * 0.07, 0.45)
	S(ci, PackedVector2Array([_u(r, 0.9, 0.7), _u(r, 1.0, 0.7), _u(r, 0.6, 0.56), _u(r, 0.62, 0.56), _u(r, 0.3, 0.18), _u(r, 0.3, 0.0)]), 0.55, 1.8)


# ---------------------------------------------------------------- M-14: vibratory hammer drive
# the vibro drive: two counter-rotating eccentric wheels (their offset masses), the hydraulic
# motor, the rubber suppressor springs above, the clamp jaw below
static func vib_drive(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var bx := sub(r, 0.1, 0.24, 0.9, 0.78)
	R(ci, bx, 0.62, 1.3)
	for k in 2:
		var c := _u(r, 0.32 + k * 0.36, 0.51)
		O(ci, c, ms * 0.22, 0.55)
		D(ci, c + Vector2.from_angle(PI * 0.5 + k * PI) * ms * 0.12, ms * 0.08, 0.5)
		D(ci, c, 1.2, 0.6)
	R(ci, sub(r, 0.42, 0.06, 0.58, 0.24), 0.55)
	var sp := PackedVector2Array()
	for x in [0.18, 0.82]:
		for k in 4:
			sp.append(_u(r, x - 0.04 + (k % 2) * 0.08, 0.04 + k * 0.05))
			sp.append(_u(r, x + 0.04 - (k % 2) * 0.08, 0.09 + k * 0.05))
	S(ci, sp, 0.45)
	_pu(ci, r, [Vector2(0.36, 0.78), Vector2(0.4, 0.98), Vector2(0.6, 0.98), Vector2(0.64, 0.78)], 0.6, 1.4)
	L(ci, _u(r, 0.5, 0.82), _u(r, 0.5, 0.98), 0.45)


# ---------------------------------------------------------------- ARK-01: despin motor / brake (x8, kept light)
# the despin drive: the motor, the brake disc and its caliper, the pinion on the ring gear
# segment, the bed
static func despin_drive(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.3, 0.42, 0.72), 0.6, 1.2)
	var dc := _u(r, 0.58, 0.5)
	O(ci, dc, ms * 0.26, 0.58, 1.2)
	R(ci, Rect2(dc + Vector2(-ms * 0.06, -ms * 0.32), Vector2(ms * 0.12, ms * 0.14)), 0.6)
	D(ci, dc, 1.4, 0.6)
	var gs := PackedVector2Array()
	for k in 6:
		var x: float = 0.66 + k * 0.05
		gs.append(_u(r, x, 0.84))
		gs.append(_u(r, x + 0.025, 0.9))
	S(ci, gs, 0.45)
	S(ci, PackedVector2Array([_u(r, 0.62, 0.9), _u(r, 0.98, 0.9), _u(r, 0.42, 0.5), _u(r, 0.5, 0.5), _u(r, 0.04, 0.96), _u(r, 0.6, 0.96),
		_u(r, 0.12, 0.72), _u(r, 0.12, 0.96), _u(r, 0.34, 0.72), _u(r, 0.34, 0.96), _u(r, 0.16, 0.3), _u(r, 0.16, 0.18)]), 0.5, 1.3)
	var fn := PackedVector2Array()
	for k in 6:
		var x: float = 0.08 + k * 0.055
		fn.append(_u(r, x, 0.34))
		fn.append(_u(r, x, 0.68))
	fn.append_array(PackedVector2Array([dc + Vector2(-ms * 0.06, -ms * 0.18), dc + Vector2(ms * 0.06, -ms * 0.18), dc + Vector2(-ms * 0.05, ms * 0.2), dc + Vector2(ms * 0.05, ms * 0.2)]))
	S(ci, fn, 0.3)
	R(ci, sub(r, 0.42, 0.44, 0.48, 0.56), 0.55)
	# the ventilated disc's slots, the hub, the second caliper below
	var sl := PackedVector2Array()
	for k in 16:
		var a: float = TAU * k / 16.0
		sl.append(dc + Vector2.from_angle(a) * ms * 0.17)
		sl.append(dc + Vector2.from_angle(a) * ms * 0.24)
	S(ci, sl, 0.35)
	O(ci, dc, ms * 0.08, 0.5)
	R(ci, Rect2(dc + Vector2(-ms * 0.06, ms * 0.18), Vector2(ms * 0.12, ms * 0.14)), 0.6)


# a column of n stacked rectangles in a cabinet section (breaker/starter units), batched
static func _stack(ci: CanvasItem, r: Rect2, x0: float, x1: float, y0: float, y1: float, n: int, handle: bool = true) -> void:
	var segs := PackedVector2Array()
	var h: float = (y1 - y0) / n
	for k in n + 1:
		segs.append(_u(r, x0, y0 + k * h))
		segs.append(_u(r, x1, y0 + k * h))
	segs.append(_u(r, x0, y0))
	segs.append(_u(r, x0, y1))
	segs.append(_u(r, x1, y0))
	segs.append(_u(r, x1, y1))
	if handle:
		for k in n:
			var y: float = y0 + (k + 0.5) * h
			segs.append(_u(r, x0 + (x1 - x0) * 0.35, y))
			segs.append(_u(r, x0 + (x1 - x0) * 0.65, y))
	S(ci, segs, 0.45, 1.1)


# ---------------------------------------------------------------- ARK-01: medium-voltage switchgear (x5)
# the vacuum circuit breaker panel: the three vacuum bottles seen through the window, the
# operating mechanism under them, the current transformer rings on the cable side, the
# cable heads below, the busbar chamber on top, the relay box
static func vcb_panel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	S(ci, PackedVector2Array([_u(r, 0.06, 0.12), _u(r, 0.94, 0.12), _u(r, 0.06, 0.3), _u(r, 0.94, 0.3), _u(r, 0.06, 0.66), _u(r, 0.94, 0.66),
		_u(r, 0.12, 0.07), _u(r, 0.88, 0.07)]), 0.5, 1.2)
	E.Rc(ci, sub(r, 0.14, 0.15, 0.5, 0.22), Pal.tint(Pal.AIR, 0.55), 1.0)
	_lamp_row(ci, sub(r, 0.56, 0.16, 0.88, 0.22), 3, Pal.tint(Pal.FLUID, 0.85), 3)
	R(ci, sub(r, 0.14, 0.33, 0.86, 0.62), 0.45)
	var vb := PackedVector2Array()
	for k in 3:
		var x: float = 0.27 + k * 0.23
		vb.append(_u(r, x - 0.05, 0.36))
		vb.append(_u(r, x - 0.05, 0.52))
		vb.append(_u(r, x + 0.05, 0.36))
		vb.append(_u(r, x + 0.05, 0.52))
		vb.append(_u(r, x, 0.31))
		vb.append(_u(r, x, 0.36))
		vb.append(_u(r, x, 0.52))
		vb.append(_u(r, x, 0.6))
	S(ci, vb, 0.55, 1.2)
	L(ci, _u(r, 0.18, 0.58), _u(r, 0.82, 0.58), 0.45, 1.4)
	for k in 3:
		var x: float = 0.3 + k * 0.2
		O(ci, _u(r, x, 0.74), ms * 0.06, 0.45)
	var ch := PackedVector2Array()
	for k in 3:
		var x: float = 0.3 + k * 0.2
		ch.append(_u(r, x, 0.66))
		ch.append(_u(r, x, 0.98))
		ch.append(_u(r, x - 0.03, 0.86))
		ch.append(_u(r, x + 0.03, 0.86))
	S(ci, ch, 0.55, 1.4)
	# the racking slot and position flags, the earthing switch handle, the cable box bolts
	R(ci, sub(r, 0.42, 0.62, 0.58, 0.65), 0.45)
	for k in 2:
		R(ci, sub(r, 0.14 + k * 0.62, 0.62, 0.24 + k * 0.62, 0.65), 0.45)
	L(ci, _u(r, 0.86, 0.7), _u(r, 0.92, 0.62), 0.55, 1.6)
	E.corner_bolts(ci, sub(r, 0.1, 0.68, 0.9, 0.96), 2.5, 0.4)
	_lamp(ci, _u(r, 0.78, 0.44), maxf(1.4, ms * 0.03), Pal.heat(0.8))


# ---------------------------------------------------------------- S-09: robot arm control base
# the arm's control base: three axis servo drives (their lamps), the teach pendant on its hook
# with the coiled lead, the emergency stop, the arm cable out of the top
static func arm_base(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.12, 0.74, 0.96), 0.62, 1.2)
	_stack(ci, r, 0.1, 0.68, 0.2, 0.74, 3, false)
	for k in 3:
		_lamp(ci, _u(r, 0.18, 0.29 + k * 0.18), maxf(1.2, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	var es := _u(r, 0.39, 0.85)
	A(ci, es, ms * 0.07, PI, TAU, 0.5)
	_lamp(ci, es, maxf(1.6, ms * 0.06), Pal.heat(0.9))
	R(ci, sub(r, 0.78, 0.2, 0.98, 0.56), 0.58)
	E.Rc(ci, sub(r, 0.81, 0.24, 0.95, 0.34), Pal.tint(Pal.AIR, 0.6), 1.0)
	var cd := PackedVector2Array()
	for k in 6:
		cd.append(_u(r, 0.88 + (0.04 if k % 2 == 0 else -0.04), 0.56 + k * 0.06))
	P(ci, cd, 0.35)
	L(ci, _u(r, 0.4, 0.12), _u(r, 0.4, 0.0), 0.55, 1.8)


# ---------------------------------------------------------------- MD-160: magnetic bearing controller (x3)
# the flywheel's magnetic bearing controller: the rotor orbit display (its little ellipse),
# the five axis position bars, the rack of power amplifier cards, the touchdown lamp
static func bearing_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.03, 0.94, 0.97), 0.62, 1.3)
	var od := sub(r, 0.12, 0.08, 0.5, 0.38)
	E.Rc(ci, od, Pal.tint(Pal.AIR, 0.55), 1.0)
	var oc := od.get_center()
	S(ci, PackedVector2Array([oc - Vector2(od.size.x * 0.4, 0), oc + Vector2(od.size.x * 0.4, 0), oc - Vector2(0, od.size.y * 0.4), oc + Vector2(0, od.size.y * 0.4)]), 0.25)
	_ell(ci, oc + Vector2(1.5, -1.0), od.size.x * 0.12, od.size.y * 0.08, 0.6)
	var bars := PackedVector2Array()
	for k in 5:
		var x: float = 0.58 + k * 0.07
		bars.append(_u(r, x, 0.36))
		bars.append(_u(r, x, 0.36 - 0.12 - 0.08 * fposmod(k * 0.43, 1.0)))
	S(ci, bars, 0.55, 2.2)
	L(ci, _u(r, 0.56, 0.24), _u(r, 0.9, 0.24), 0.3)
	var cards := PackedVector2Array()
	for k in 10:
		var x: float = 0.12 + (k + 0.5) * 0.76 / 10.0
		cards.append(_u(r, x, 0.46))
		cards.append(_u(r, x, 0.86))
	cards.append(_u(r, 0.12, 0.46))
	cards.append(_u(r, 0.88, 0.46))
	cards.append(_u(r, 0.12, 0.86))
	cards.append(_u(r, 0.88, 0.86))
	S(ci, cards, 0.4, 1.2)
	_lamp_row(ci, sub(r, 0.12, 0.48, 0.88, 0.52), 5, Pal.tint(Pal.FLUID, 0.85), 0)
	_lamp(ci, _u(r, 0.82, 0.92), maxf(1.4, ms * 0.04), Pal.heat(0.85))


# ---------------------------------------------------------------- TB-180: tether brake controller (long box)
# the brake controller box along the brake frame: per channel a proportional valve driver
# and its pressure bar, the tension readout, the encoder terminals, repeated along it
static func brake_ctrl_box(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.0, 0.06, 1.0, 0.94), 0.62, 1.2)
	E.Rc(ci, sub(r, 0.01, 0.16, 0.12, 0.5), Pal.tint(Pal.AIR, 0.55), 1.0)
	var n := clampi(int(r.size.x / 40.0), 2, 10)
	var segs := PackedVector2Array()
	for k in n:
		var x0: float = 0.14 + k * 0.84 / n
		var x1: float = x0 + 0.84 / n - 0.01
		segs.append(_u(r, x0, 0.14))
		segs.append(_u(r, x0, 0.86))
		var bw: float = (x1 - x0) * 0.25
		segs.append(_u(r, x0 + bw, 0.76))
		segs.append(_u(r, x0 + bw, 0.76 - 0.5 * (0.4 + 0.5 * fposmod(k * 0.37, 1.0))))
		segs.append(_u(r, x0 + bw * 2.4, 0.3))
		segs.append(_u(r, x1 - bw * 0.6, 0.3))
		segs.append(_u(r, x0 + bw * 2.4, 0.5))
		segs.append(_u(r, x1 - bw * 0.6, 0.5))
	S(ci, segs, 0.45, 1.3)
	var ts := PackedVector2Array()
	var nt := clampi(int(r.size.x / 8.0), 4, 40)
	for k in nt:
		var x: float = 0.14 + (k + 0.5) * 0.84 / nt
		ts.append(_u(r, x, 0.84))
		ts.append(_u(r, x, 0.92))
	S(ci, ts, 0.35, 1.2)


# ---------------------------------------------------------------- H-22: traction coil supply
# the traction coil's heavy DC supply: the transformer, the thyristor bridge on its heat
# sinks, the big smoothing reactor, the DC bars up to the two coils, the current meter
static func coil_supply(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.04, 0.96, 0.96), 0.62, 1.3)
	var tx := sub(r, 0.1, 0.6, 0.46, 0.9)
	R(ci, tx, 0.55)
	hatch(ci, sub(r, 0.16, 0.64, 0.4, 0.86), 2.4, false, 0.3, 12)
	var bridge := PackedVector2Array()
	for k in 3:
		var x: float = 0.14 + k * 0.12
		bridge.append(_u(r, x, 0.3))
		bridge.append(_u(r, x, 0.5))
		bridge.append(_u(r, x - 0.03, 0.4))
		bridge.append(_u(r, x + 0.03, 0.4))
	S(ci, bridge, 0.55, 1.4)
	hatch(ci, sub(r, 0.1, 0.28, 0.46, 0.52), 3.0, true, 0.2, 20)
	var rc := _u(r, 0.72, 0.6)
	O(ci, rc, ms * 0.2, 0.6, 1.4)
	O(ci, rc, ms * 0.12, 0.4)
	var bars := PackedVector2Array([_u(r, 0.62, 0.0), _u(r, 0.62, 0.36), _u(r, 0.82, 0.0), _u(r, 0.82, 0.36), _u(r, 0.46, 0.4), _u(r, 0.62, 0.36),
		_u(r, 0.46, 0.75), _u(r, 0.52, 0.75)])
	S(ci, bars, 0.6, 2.2)
	E.gauge(ci, _u(r, 0.28, 0.14), maxf(3.0, ms * 0.08), 0.55)
	_lamp(ci, _u(r, 0.48, 0.14), maxf(1.6, ms * 0.04), Pal.tint(Pal.VOLT, 0.85))


# ---------------------------------------------------------------- PT-34: A-net distribution (bus tie, shore, charger)
static func dist_a(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	var mb := PackedVector2Array([_u(r, 0.12, 0.08), _u(r, 0.88, 0.08)])
	for x in [0.24, 0.5, 0.76]:
		mb.append(_u(r, x, 0.08))
		mb.append(_u(r, x, 0.16))
	S(ci, mb, 0.55, 1.4)
	for k in 3:
		var c := _u(r, 0.24 + k * 0.26, 0.2)
		R(ci, Rect2(c - Vector2(ms * 0.06, ms * 0.04), Vector2(ms * 0.12, ms * 0.08)), 0.55)
		_lamp(ci, c, maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85) if k != 1 else Pal.ink(0.35))
	var sh := sub(r, 0.12, 0.3, 0.42, 0.44)
	R(ci, sh, 0.55)
	O(ci, sh.get_center(), ms * 0.05, 0.5)
	O(ci, sh.get_center(), ms * 0.02, 0.5)
	var bc := sub(r, 0.5, 0.3, 0.88, 0.5)
	R(ci, bc, 0.55)
	hatch(ci, Rect2(bc.position + Vector2(2, 2), Vector2(bc.size.x * 0.4, bc.size.y - 4)), 2.0, true, 0.3, 10)
	E.Rc(ci, Rect2(bc.position + Vector2(bc.size.x * 0.55, bc.size.y * 0.2), Vector2(bc.size.x * 0.35, bc.size.y * 0.3)), Pal.tint(Pal.AIR, 0.55), 1.0)
	_stack(ci, r, 0.12, 0.88, 0.56, 0.92, 6)


# ---------------------------------------------------------------- PT-34: B-net distribution (generator incomer, synchroscope)
static func dist_b(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	var sc := _u(r, 0.32, 0.18)
	var sr: float = ms * 0.12
	O(ci, sc, sr, 0.6, 1.3)
	S(ci, PackedVector2Array([sc, sc + Vector2.from_angle(-1.3) * sr * 0.9, sc + Vector2(0, -sr), sc + Vector2(0, -sr * 0.75)]), 0.6, 1.3)
	for k in 2:
		_lamp(ci, sc + Vector2((k * 2 - 1) * sr * 1.5, -sr * 0.4), maxf(1.6, ms * 0.04), Pal.heat(0.8) if k == 0 else Pal.tint(Pal.FLUID, 0.8))
	E.gauge(ci, _u(r, 0.72, 0.18), sr * 0.8, 0.5)
	var acb := sub(r, 0.14, 0.34, 0.86, 0.58)
	R(ci, acb, 0.58, 1.2)
	R(ci, sub(r, 0.36, 0.38, 0.64, 0.5), 0.5)
	S(ci, PackedVector2Array([_u(r, 0.2, 0.44), _u(r, 0.32, 0.44), _u(r, 0.68, 0.44), _u(r, 0.8, 0.44), _u(r, 0.44, 0.53), _u(r, 0.56, 0.53)]), 0.55, 1.6)
	var ls := PackedVector2Array()
	for k in 6:
		var x: float = 0.18 + k * 0.12
		ls.append(_u(r, x, 0.64))
		ls.append(_u(r, x, 0.9))
	S(ci, ls, 0.4, 1.1)
	_lamp_row(ci, sub(r, 0.12, 0.62, 0.88, 0.66), 6, Pal.tint(Pal.FLUID, 0.85), 4)


# ---------------------------------------------------------------- DR-150: variable frequency drive
# a drilling motor's VFD: the cooling fan on top, the IGBT module on its finned heat sink, the
# DC link capacitor bank (cans), the line reactor, the keypad, the braking resistor vents
static func vfd_cabinet(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	E.fan(ci, _u(r, 0.5, 0.1), minf(r.size.x * 0.18, r.size.y * 0.06), 5, 0.42)
	var hs := sub(r, 0.14, 0.2, 0.5, 0.46)
	R(ci, hs, 0.5)
	hatch(ci, hs.grow(-1.5), 2.0, true, 0.3, 30)
	R(ci, sub(r, 0.56, 0.24, 0.86, 0.36), 0.55)
	for k in 4:
		var c := _u(r, 0.2 + k * 0.2, 0.56)
		O(ci, c, ms * 0.07, 0.5)
		D(ci, c, 0.8, 0.5)
	var lr := sub(r, 0.14, 0.66, 0.52, 0.86)
	R(ci, lr, 0.5)
	var cz := PackedVector2Array()
	for k in 7:
		cz.append(lr.position + Vector2(lr.size.x * (0.1 + k * 0.13), lr.size.y * (0.2 if k % 2 == 0 else 0.8)))
	P(ci, cz, 0.45)
	E.Rc(ci, sub(r, 0.6, 0.68, 0.86, 0.74), Pal.tint(Pal.AIR, 0.6), 1.0)
	_lamp_row(ci, sub(r, 0.6, 0.78, 0.86, 0.82), 3, Pal.tint(Pal.FLUID, 0.85), 0)
	E.louvres(ci, sub(r, 0.14, 0.89, 0.86, 0.96), 0.25)


# ---------------------------------------------------------------- E-07: junction box
# the bay's junction box, lid off: the terminal rail with its terminals, the earth bar, the
# three glands with their cables (battery, capacitor, the unit)
static func junction_box(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.08, 0.12, 0.92, 0.88), 0.62, 1.2)
	E.corner_bolts(ci, sub(r, 0.08, 0.12, 0.92, 0.88), 2.5, 0.45)
	var tr := PackedVector2Array([_u(r, 0.2, 0.36), _u(r, 0.8, 0.36), _u(r, 0.2, 0.44), _u(r, 0.8, 0.44)])
	for k in 5:
		var x: float = 0.24 + k * 0.13
		tr.append(_u(r, x, 0.3))
		tr.append(_u(r, x, 0.5))
	S(ci, tr, 0.5, 1.2)
	L(ci, _u(r, 0.2, 0.66), _u(r, 0.8, 0.66), 0.55, 2.0)
	for k in 3:
		var x: float = 0.25 + k * 0.25
		R(ci, sub(r, x - 0.05, 0.88, x + 0.05, 0.94), 0.55)
		S(ci, PackedVector2Array([_u(r, x, 0.94), _u(r, x, 1.0), _u(r, x, 0.5), _u(r, x, 0.88)]), 0.4)


# ---------------------------------------------------------------- MF-126: arc furnace control
# the furnace control cabinet: the furnace mimic (shell, three electrodes, the arc), the
# transformer tap position dial, the three electrode position bars, the power meter, the
# hydraulic regulation valves block
static func furnace_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.02, 0.96, 0.98), 0.62, 1.3)
	_pu(ci, r, [Vector2(0.14, 0.12), Vector2(0.18, 0.3), Vector2(0.52, 0.3), Vector2(0.56, 0.12)], 0.55, 1.2)
	var el := PackedVector2Array()
	for k in 3:
		var x: float = 0.24 + k * 0.11
		el.append(_u(r, x, 0.04))
		el.append(_u(r, x, 0.2 + 0.02 * k))
	S(ci, el, 0.6, 2.0)
	E.Rc(ci, sub(r, 0.22, 0.2, 0.48, 0.26), Pal.heat(0.75), 1.0)
	var tc := _u(r, 0.78, 0.2)
	var tr: float = ms * 0.14
	A(ci, tc, tr, PI * 0.8, PI * 2.2, 0.55, 1.2)
	var tk := PackedVector2Array()
	for k in 9:
		var a: float = PI * 0.8 + k * PI * 1.4 / 8.0
		tk.append(tc + Vector2.from_angle(a) * tr * 0.82)
		tk.append(tc + Vector2.from_angle(a) * tr)
	tk.append(tc)
	tk.append(tc + Vector2.from_angle(PI * 1.7) * tr * 0.8)
	S(ci, tk, 0.45)
	var bars := PackedVector2Array()
	for k in 3:
		var x: float = 0.16 + k * 0.1
		bars.append(_u(r, x, 0.62))
		bars.append(_u(r, x, 0.62 - 0.18 - 0.06 * k))
	S(ci, bars, 0.55, 3.0)
	R(ci, sub(r, 0.12, 0.38, 0.42, 0.64), 0.4)
	E.gauge(ci, _u(r, 0.66, 0.5), maxf(3.0, ms * 0.1), 0.55)
	var hv := sub(r, 0.12, 0.72, 0.88, 0.92)
	R(ci, hv, 0.55)
	for k in 3:
		var x: float = 0.24 + k * 0.26
		_bowtie(ci, _u(r, x, 0.82), maxf(2.5, ms * 0.04))
		R(ci, sub(r, x - 0.04, 0.73, x + 0.04, 0.78), 0.45)


# ---------------------------------------------------------------- FX-70: magnet power supply
# the coil supply: the thyristor stacks, the water-cooled bus with its hoses (flow), the
# DCCT current sensor ring, the ramp controller showing the current ramp, the interlock key
static func magnet_psu(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	var rp := sub(r, 0.14, 0.06, 0.86, 0.2)
	E.Rc(ci, rp, Pal.tint(Pal.AIR, 0.55), 1.0)
	P(ci, PackedVector2Array([rp.position + Vector2(2, rp.size.y - 2), rp.position + Vector2(rp.size.x * 0.35, 3), rp.position + Vector2(rp.size.x * 0.7, 3), rp.end - Vector2(2, rp.size.y * 0.4)]), 0.6)
	_stack(ci, r, 0.14, 0.54, 0.26, 0.66, 5, false)
	hatch(ci, sub(r, 0.15, 0.27, 0.53, 0.65), 3.0, true, 0.2, 20)
	S(ci, PackedVector2Array([_u(r, 0.66, 0.24), _u(r, 0.66, 0.98), _u(r, 0.8, 0.24), _u(r, 0.8, 0.98), _u(r, 0.54, 0.4), _u(r, 0.66, 0.4)]), 0.6, 2.4)
	E.Rc(ci, sub(r, 0.62, 0.3, 0.84, 0.32), Pal.tint(Pal.FLUID, 0.6), 1.0)
	O(ci, _u(r, 0.73, 0.78), ms * 0.12, 0.55, 1.3)
	var kc := _u(r, 0.32, 0.82)
	O(ci, kc, ms * 0.06, 0.55)
	L(ci, kc - Vector2(0, ms * 0.04), kc + Vector2(0, ms * 0.04), 0.6, 1.2)


# ---------------------------------------------------------------- FX-70: quench protection
# the quench protection cabinet: the voltage-tap bridge comparator cards with their trip
# lamps, the big DC dump breaker and its spring mechanism, the link to the dump resistor
static func quench_prot(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	var cards := PackedVector2Array()
	for k in 6:
		var x: float = 0.14 + (k + 0.5) * 0.72 / 6.0
		cards.append(_u(r, x, 0.06))
		cards.append(_u(r, x, 0.34))
	S(ci, cards, 0.4, 1.4)
	_lamp_row(ci, sub(r, 0.14, 0.36, 0.86, 0.4), 6, Pal.tint(Pal.FLUID, 0.85), 5)
	var bk := sub(r, 0.16, 0.46, 0.84, 0.8)
	R(ci, bk, 0.6, 1.3)
	S(ci, PackedVector2Array([_u(r, 0.3, 0.5), _u(r, 0.3, 0.76), _u(r, 0.7, 0.5), _u(r, 0.7, 0.76), _u(r, 0.3, 0.63), _u(r, 0.7, 0.58)]), 0.6, 2.0)
	var sp := PackedVector2Array()
	for k in 6:
		sp.append(_u(r, 0.44 + (k % 2) * 0.12, 0.5 + k * 0.045))
	P(ci, sp, 0.45)
	S(ci, PackedVector2Array([_u(r, 0.3, 0.8), _u(r, 0.3, 0.98), _u(r, 0.7, 0.8), _u(r, 0.7, 0.98)]), 0.55, 2.2)
	_lamp(ci, _u(r, 0.5, 0.88), maxf(1.6, ms * 0.06), Pal.heat(0.85))


# ---------------------------------------------------------------- ES-112 / SP-ISOLATE: lock solenoid
# a lock solenoid actuator: the coil (its winding), the plunger and the lock bolt it throws,
# the return spring, the bolt position switches, the driver box
static func lock_solenoid(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cl := sub(r, 0.2, 0.08, 0.8, 0.46)
	R(ci, cl, 0.62, 1.3)
	hatch(ci, cl.grow(-2.0), 2.4, false, 0.3, 20)
	R(ci, sub(r, 0.42, 0.46, 0.58, 0.74), 0.58)
	R(ci, sub(r, 0.34, 0.74, 0.66, 0.86), 0.62, 1.2)
	var sp := PackedVector2Array()
	for k in 6:
		sp.append(_u(r, 0.42 + (k % 2) * 0.16, 0.48 + k * 0.045))
	P(ci, sp, 0.4)
	for x in [0.26, 0.74]:
		R(ci, sub(r, x - 0.06, 0.78, x + 0.06, 0.86), 0.5)
		_lamp(ci, _u(r, x, 0.82), maxf(1.2, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	R(ci, sub(r, 0.24, 0.88, 0.76, 0.98), 0.5)
	L(ci, _u(r, 0.5, 0.08), _u(r, 0.5, 0.0), 0.55, 1.6)


# ---------------------------------------------------------------- the low-voltage switchboard (CV-138, RO-128)
# a low-voltage board: the air circuit breaker incomer (its big frame, the charge handle,
# ON/OFF), the feeder sections of moulded-case breakers in columns; more columns the wider,
# more rows the taller
static func lv_board(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.02, 0.01, 0.98, 0.99), 0.62, 1.3)
	var acb := sub(r, 0.08, 0.04, 0.44, 0.24)
	R(ci, acb, 0.6, 1.2)
	R(ci, Rect2(acb.position + acb.size * Vector2(0.3, 0.2), acb.size * Vector2(0.4, 0.35)), 0.5)
	S(ci, PackedVector2Array([acb.position + acb.size * Vector2(0.4, 0.75), acb.position + acb.size * Vector2(0.6, 0.75)]), 0.6, 2.0)
	E.gauge(ci, _u(r, 0.58, 0.14), minf(r.size.x * 0.08, r.size.y * 0.06), 0.5)
	E.gauge(ci, _u(r, 0.82, 0.14), minf(r.size.x * 0.08, r.size.y * 0.06), 0.5)
	var cols := clampi(int(r.size.x / 34.0), 2, 6)
	var rows := clampi(int(r.size.y * 0.68 / 16.0), 3, 18)
	var cw: float = 0.88 / cols
	for c in cols:
		_stack(ci, r, 0.06 + c * cw, 0.06 + (c + 1) * cw - 0.02, 0.3, 0.96, rows)
	_lamp_row(ci, sub(r, 0.08, 0.26, 0.92, 0.29), cols * 2, Pal.tint(Pal.FLUID, 0.85), 5)


# ---------------------------------------------------------------- PS-12: main distribution
# the passenger ship's main board: the single-line mimic along the top (bus, a lamp per
# feeder), the incomer breaker with its energy meter, the feeder groups below in rows
static func main_dist(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.02, 0.96, 0.98), 0.62, 1.3)
	var mm := PackedVector2Array([_u(r, 0.1, 0.14), _u(r, 0.9, 0.14), _u(r, 0.5, 0.06), _u(r, 0.5, 0.14)])
	for k in 7:
		var x: float = 0.14 + k * 0.12
		mm.append(_u(r, x, 0.14))
		mm.append(_u(r, x, 0.22))
	S(ci, mm, 0.5, 1.3)
	for k in 7:
		_lamp(ci, _u(r, 0.14 + k * 0.12, 0.24), maxf(1.2, ms * 0.025), Pal.tint(Pal.FLUID, 0.85) if k % 4 != 2 else Pal.heat(0.8))
	var ic := sub(r, 0.1, 0.3, 0.5, 0.5)
	R(ci, ic, 0.6, 1.2)
	S(ci, PackedVector2Array([ic.position + ic.size * Vector2(0.3, 0.5), ic.position + ic.size * Vector2(0.7, 0.5)]), 0.6, 2.0)
	E.Rc(ci, sub(r, 0.58, 0.32, 0.9, 0.42), Pal.tint(Pal.AIR, 0.55), 1.0)
	S(ci, PackedVector2Array([_u(r, 0.6, 0.47), _u(r, 0.88, 0.47)]), 0.35)
	for k in 2:
		_stack(ci, r, 0.1 + k * 0.42, 0.48 + k * 0.42, 0.56, 0.94, 5)


# ---------------------------------------------------------------- OB-90 / SP-PRECISE: primary mirror control
# the mirror's actuator controller: the actuator map (a hexagonal field of dots, a few
# flagged), the wavefront input connector, the thermal control loop readout, card rack below
static func mirror_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	var hc := _u(r, 0.5, 0.26)
	var hr: float = minf(r.size.x * 0.36, r.size.y * 0.2)
	var hx := PackedVector2Array()
	for k in 7:
		hx.append(hc + Vector2.from_angle(TAU * k / 6.0 + PI / 6.0) * hr)
	P(ci, hx, 0.5)
	var st: float = hr * 0.28
	var n := 0
	for row in range(-3, 4):
		for c in range(-4, 5):
			var p := hc + Vector2((c + (0.5 if row % 2 != 0 else 0.0)) * st, row * st * 0.87)
			if p.distance_to(hc) < hr * 0.82:
				if n % 9 == 4:
					_lamp(ci, p, 1.6, Pal.heat(0.8))
				else:
					D(ci, p, 0.8, 0.5)
				n += 1
	O(ci, _u(r, 0.2, 0.56), ms * 0.07, 0.55)
	E.Rc(ci, sub(r, 0.36, 0.52, 0.86, 0.6), Pal.tint(Pal.AIR, 0.55), 1.0)
	var cards := PackedVector2Array()
	for k in 8:
		var x: float = 0.12 + (k + 0.5) * 0.76 / 8.0
		cards.append(_u(r, x, 0.66))
		cards.append(_u(r, x, 0.92))
	cards.append_array(PackedVector2Array([_u(r, 0.12, 0.66), _u(r, 0.88, 0.66), _u(r, 0.12, 0.92), _u(r, 0.88, 0.92)]))
	S(ci, cards, 0.4, 1.2)


# ---------------------------------------------------------------- DC-84: rack PDU
# a rack power strip: the mounting ears with their screws, the current display and the two
# bank breakers on top, the outlets in banks of four (each with its pin slots and earth pin,
# a bank bracket and per-outlet lamp), the earth stud, the input cord gland at the bottom
static func rack_pdu(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.22, 0.01, 0.78, 0.99), 0.62, 1.3)
	var ears := PackedVector2Array()
	for y in [0.02, 0.92]:
		for sx in [[0.04, 0.22], [0.78, 0.96]]:
			var e := sub(r, sx[0], y, sx[1], y + 0.06)
			ears.append_array(PackedVector2Array([e.position, Vector2(e.end.x, e.position.y), e.position, Vector2(e.position.x, e.end.y),
				Vector2(e.position.x, e.end.y), e.end, Vector2(e.end.x, e.position.y), e.end]))
	S(ci, ears, 0.5, 1.1)
	for y in [0.05, 0.95]:
		for x in [0.12, 0.88]:
			D(ci, _u(r, x, y), 1.0, 0.6)
	E.Rc(ci, sub(r, 0.3, 0.04, 0.7, 0.08), Pal.tint(Pal.AIR, 0.6), 1.0)
	_toggle(ci, _u(r, 0.38, 0.13), maxf(1.6, ms * 0.08))
	_toggle(ci, _u(r, 0.62, 0.13), maxf(1.6, ms * 0.08))
	L(ci, _u(r, 0.24, 0.17), _u(r, 0.76, 0.17), 0.45)
	var n := clampi(int(r.size.y * 0.7 / 8.0), 8, 24)
	n -= n % 4
	var segs := PackedVector2Array()
	var pins := PackedVector2Array()
	for k in n:
		var y: float = 0.19 + (k + 0.5) * 0.7 / n
		var h: float = 0.7 / n * 0.34
		segs.append_array(PackedVector2Array([_u(r, 0.36, y - h), _u(r, 0.6, y - h), _u(r, 0.36, y + h), _u(r, 0.6, y + h),
			_u(r, 0.36, y - h), _u(r, 0.36, y + h), _u(r, 0.6, y - h), _u(r, 0.6, y + h)]))
		pins.append_array(PackedVector2Array([_u(r, 0.42, y - h * 0.5), _u(r, 0.42, y + h * 0.5), _u(r, 0.54, y - h * 0.5), _u(r, 0.54, y + h * 0.5),
			_u(r, 0.47, y), _u(r, 0.49, y)]))
		if k % 4 == 0:
			var y1: float = 0.19 + (k + 4) * 0.7 / n
			segs.append_array(PackedVector2Array([_u(r, 0.29, y - h), _u(r, 0.29, y1 - 0.7 / n + h), _u(r, 0.29, y - h), _u(r, 0.32, y - h)]))
		_lamp(ci, _u(r, 0.68, y), 1.4, Pal.tint(Pal.FLUID, 0.85) if k % 4 != 3 else Pal.ink(0.35))
	S(ci, segs, 0.45)
	S(ci, pins, 0.55, 1.0)
	O(ci, _u(r, 0.32, 0.9), ms * 0.035, 0.55)
	R(ci, sub(r, 0.42, 0.89, 0.58, 0.95), 0.58, 1.2)
	L(ci, _u(r, 0.5, 0.95), _u(r, 0.5, 1.0), 0.6, 2.0)


# ---------------------------------------------------------------- the distribution panelboard (ARK-01 x8 and more)
# a panelboard, door open: the main breaker on top, two columns of branch breakers off the
# busbar comb between them, the cable trunking down each side (lean: ARK-01 carries eight)
static func panelboard(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.02, 0.94, 0.98), 0.62, 1.3)
	R(ci, sub(r, 0.32, 0.05, 0.68, 0.16), 0.58, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.45, 0.105), _u(r, 0.55, 0.105)]), 0.6, 2.0)
	var rows := clampi(int(r.size.y * 0.72 / 12.0), 4, 14)
	var segs := PackedVector2Array([_u(r, 0.5, 0.18), _u(r, 0.5, 0.92), _u(r, 0.14, 0.04), _u(r, 0.14, 0.96), _u(r, 0.86, 0.04), _u(r, 0.86, 0.96)])
	for k in rows:
		var y: float = 0.2 + (k + 0.5) * 0.72 / rows
		segs.append(_u(r, 0.22, y))
		segs.append(_u(r, 0.46, y))
		segs.append(_u(r, 0.54, y))
		segs.append(_u(r, 0.78, y))
		segs.append(_u(r, 0.3, y - 0.012))
		segs.append(_u(r, 0.3, y + 0.012))
		segs.append(_u(r, 0.7, y - 0.012))
		segs.append(_u(r, 0.7, y + 0.012))
	S(ci, segs, 0.45, 1.3)
	_lamp(ci, _u(r, 0.5, 0.95), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	# each breaker's toggle and the trunking ties
	var tg := PackedVector2Array()
	for k in rows:
		var y: float = 0.2 + (k + 0.5) * 0.72 / rows
		for x in [0.38, 0.62]:
			tg.append(_u(r, x - 0.02, y - 0.01))
			tg.append(_u(r, x + 0.02, y + 0.01))
		if k % 2 == 0:
			for x in [0.1, 0.9]:
				tg.append(_u(r, x - 0.03, y))
				tg.append(_u(r, x + 0.03, y))
	S(ci, tg, 0.55, 1.6)


# ---------------------------------------------------------------- the process control cabinet (CL-104, MT-140; FL-116, IC-120)
# a PLC cabinet: the HMI on the door edge, the PLC rack (CPU, I/O cards, their lamps), the
# DIN rails of relays and terminals, the slotted wiring ducts between them
static func plc_cabinet(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.02, 0.96, 0.98), 0.62, 1.3)
	var hmi := sub(r, 0.08, 0.06, 0.32, 0.3)
	E.Rc(ci, hmi, Pal.tint(Pal.AIR, 0.55), 1.0)
	E.screen_face(ci, hmi.grow(-1.0), 2, 0.3)
	var pr := sub(r, 0.38, 0.06, 0.92, 0.3)
	R(ci, pr, 0.55)
	var cards := PackedVector2Array()
	var n := clampi(int(pr.size.x / 6.0), 4, 16)
	for k in n:
		var x: float = pr.position.x + (k + 0.5) * pr.size.x / n
		cards.append(Vector2(x, pr.position.y + 2.0))
		cards.append(Vector2(x, pr.end.y - 2.0))
	S(ci, cards, 0.35, 1.3)
	_lamp_row(ci, Rect2(pr.position + Vector2(0, 2), Vector2(pr.size.x, 3)), mini(n, 8), Pal.tint(Pal.FLUID, 0.85), 3)
	var duct := PackedVector2Array()
	for y in [0.36, 0.62, 0.88]:
		duct.append(_u(r, 0.08, y))
		duct.append(_u(r, 0.92, y))
	for y in [0.48, 0.74]:
		duct.append(_u(r, 0.08, y))
		duct.append(_u(r, 0.92, y))
		var nt := clampi(int(r.size.x * 0.8 / 5.0), 6, 30)
		for k in nt:
			var x: float = 0.1 + (k + 0.5) * 0.8 / nt
			duct.append(_u(r, x, y - 0.035))
			duct.append(_u(r, x, y + 0.035))
	S(ci, duct, 0.35, 1.1)


# ---------------------------------------------------------------- VT-80: pump motor control (tall)
# the pump MCC: the incomer on top (main breaker and its handle, ammeter, three phase lamps),
# the starter drawers (each with its handle, start/stop buttons, the overload reset and its run
# lamp), the vertical busbars in the wireway on the right with a dropper into every drawer, the
# door hinges, the cable glands under it
static func pump_mcc(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.06, 0.01, 0.94, 0.99), 0.62, 1.3)
	var ic := sub(r, 0.12, 0.03, 0.72, 0.13)
	R(ci, ic, 0.58, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.18, 0.08), _u(r, 0.36, 0.08), _u(r, 0.36, 0.06), _u(r, 0.36, 0.1)]), 0.6, 2.0)
	E.gauge(ci, _u(r, 0.5, 0.08), maxf(2.5, ms * 0.08), 0.5)
	for k in 3:
		_lamp(ci, _u(r, 0.6 + k * 0.04, 0.11), maxf(1.2, ms * 0.03), Pal.heat(0.8) if k == 0 else Pal.tint(Pal.FLUID, 0.85))
	var n := clampi(int(r.size.y * 0.8 / 22.0), 3, 8)
	var y0: float = 0.15
	var y1: float = 0.92
	_stack(ci, r, 0.12, 0.72, y0, y1, n)
	var bus := PackedVector2Array()
	for x in [0.8, 0.84, 0.88]:
		bus.append(_u(r, x, 0.03))
		bus.append(_u(r, x, 0.92))
	var dh: float = (y1 - y0) / n
	for k in n:
		var y: float = y0 + (k + 0.5) * dh
		bus.append(_u(r, 0.72, y))
		bus.append(_u(r, 0.8, y))
		D(ci, _u(r, 0.8, y), 1.0, 0.6)
		O(ci, _u(r, 0.2, y - dh * 0.2), maxf(1.2, ms * 0.03), 0.55)
		O(ci, _u(r, 0.2, y + dh * 0.2), maxf(1.2, ms * 0.03), 0.55)
		bus.append(_u(r, 0.56, y - dh * 0.25))
		bus.append(_u(r, 0.6, y - dh * 0.25))
		_lamp(ci, _u(r, 0.64, y), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85) if k != 1 else Pal.ink(0.35))
	S(ci, bus, 0.55, 1.4)
	var hg := PackedVector2Array()
	for y in [0.06, 0.4, 0.7, 0.94]:
		hg.append(_u(r, 0.04, y))
		hg.append(_u(r, 0.06, y))
	S(ci, hg, 0.55, 2.0)
	for x in [0.24, 0.44, 0.84]:
		R(ci, Rect2(_u(r, x, 0.95) - Vector2(ms * 0.05, 0), Vector2(ms * 0.1, r.size.y * 0.03)), 0.55)
		L(ci, _u(r, x, 0.98), _u(r, x, 1.0), 0.55, 1.6)


# ---------------------------------------------------------------- the small consumer unit (BELT, POD, S-09)
# a little distribution box, cover off: the rotary main isolator, the residual-current breaker
# with its test button, the miniature breakers clipped on a DIN rail, the neutral bar and the
# earth bar with their screws, the two cable glands under it with their cables, the power lamp
# (lines batched, no circles: belt/pod/s09/tug carry it on small budgets)
static func small_db(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.1, 0.04, 0.9, 0.9), 0.62, 1.2)
	# the rotary isolator (square body, its handle across), the RCD and its test button
	var sg := PackedVector2Array()
	var ib := sub(r, 0.2, 0.08, 0.5, 0.22)
	var rc := sub(r, 0.56, 0.08, 0.82, 0.22)
	for q in [ib, rc]:
		sg.append_array(PackedVector2Array([q.position, Vector2(q.end.x, q.position.y), q.position, Vector2(q.position.x, q.end.y),
			Vector2(q.position.x, q.end.y), q.end, Vector2(q.end.x, q.position.y), q.end]))
	sg.append_array(PackedVector2Array([_u(r, 0.64, 0.12), _u(r, 0.74, 0.12), _u(r, 0.64, 0.12), _u(r, 0.64, 0.15),
		_u(r, 0.74, 0.12), _u(r, 0.74, 0.15)]))
	# the miniature breakers clipped on the DIN rail, each with its toggle
	var n := clampi(int(r.size.x * 0.64 / 5.0), 3, 8)
	sg.append_array(PackedVector2Array([_u(r, 0.16, 0.32), _u(r, 0.84, 0.32), _u(r, 0.16, 0.44), _u(r, 0.84, 0.44)]))
	for k in n:
		var x0: float = 0.18 + k * 0.64 / n
		var x1: float = x0 + 0.64 / n * 0.85
		sg.append_array(PackedVector2Array([_u(r, x0, 0.28), _u(r, x0, 0.48), _u(r, x1, 0.28), _u(r, x1, 0.28),
			_u(r, x1, 0.28), _u(r, x1, 0.48), _u(r, (x0 + x1) * 0.5, 0.35), _u(r, (x0 + x1) * 0.5, 0.41)]))
	# screws of the neutral and earth bars
	for k in 3:
		var x: float = 0.28 + k * 0.22
		sg.append_array(PackedVector2Array([_u(r, x, 0.55), _u(r, x, 0.61), _u(r, x, 0.67), _u(r, x, 0.73)]))
	S(ci, sg, 0.5, 1.0)
	L(ci, _u(r, 0.26, 0.15), _u(r, 0.44, 0.15), 0.62, 2.2)
	S(ci, PackedVector2Array([_u(r, 0.18, 0.58), _u(r, 0.82, 0.58), _u(r, 0.18, 0.7), _u(r, 0.82, 0.7)]), 0.6, 2.2)
	E.Rc(ci, sub(r, 0.18, 0.69, 0.3, 0.71), Pal.tint(Pal.FLUID, 0.6), 1.0)
	_lamp(ci, _u(r, 0.7, 0.8), maxf(1.2, ms * 0.06), Pal.tint(Pal.FLUID, 0.85))
	# the two cable glands under it, their cables
	var gl := PackedVector2Array()
	for x in [0.3, 0.6]:
		gl.append_array(PackedVector2Array([_u(r, x - 0.07, 0.9), _u(r, x - 0.07, 0.94), _u(r, x + 0.07, 0.9), _u(r, x + 0.07, 0.94),
			_u(r, x - 0.07, 0.94), _u(r, x + 0.07, 0.94)]))
	S(ci, gl, 0.55, 1.0)
	S(ci, PackedVector2Array([_u(r, 0.3, 0.94), _u(r, 0.3, 1.0), _u(r, 0.6, 0.94), _u(r, 0.6, 1.0)]), 0.55, 1.8)


# ---------------------------------------------------------------- the ship's switchboard (34 on many ships)
# the main switchboard: the generator section (V, A, Hz meters, synchronising lamps, the
# generator breaker), the battery section, the feeder breakers in columns; it widens and
# grows with the ship
static func ship_swb(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.03, 0.01, 0.97, 0.99), 0.62, 1.3)
	var gw: float = 0.94 if r.size.x < 1.8 * M else 0.45
	var gm := PackedVector2Array([_u(r, 0.06, 0.24), _u(r, 0.06 + gw - 0.03, 0.24)])
	S(ci, gm, 0.45)
	var gr: float = minf(r.size.x * gw * 0.13, r.size.y * 0.06)
	for k in 3:
		E.gauge(ci, _u(r, 0.06 + gw * (0.2 + k * 0.3), 0.1), gr, 0.5)
	for k in 3:
		_lamp(ci, _u(r, 0.06 + gw * (0.3 + k * 0.2), 0.2), maxf(1.2, ms * 0.03), Pal.heat(0.8) if k == 1 else Pal.tint(Pal.FLUID, 0.8))
	var gb := sub(r, 0.08, 0.27, 0.06 + gw - 0.05, 0.4)
	R(ci, gb, 0.58, 1.2)
	S(ci, PackedVector2Array([gb.position + gb.size * Vector2(0.35, 0.5), gb.position + gb.size * Vector2(0.65, 0.5)]), 0.6, 2.0)
	if gw < 0.9:
		var bs := sub(r, 0.53, 0.04, 0.94, 0.4)
		R(ci, bs, 0.5)
		E.Rc(ci, Rect2(bs.position + bs.size * Vector2(0.1, 0.12), bs.size * Vector2(0.8, 0.2)), Pal.tint(Pal.AIR, 0.55), 1.0)
		S(ci, PackedVector2Array([bs.position + bs.size * Vector2(0.1, 0.55), bs.position + bs.size * Vector2(0.9, 0.55), bs.position + bs.size * Vector2(0.1, 0.75), bs.position + bs.size * Vector2(0.9, 0.75)]), 0.4)
	var cols := clampi(int(r.size.x / 30.0), 2, 8)
	var rows := clampi(int(r.size.y * 0.56 / 14.0), 3, 14)
	var cw: float = 0.9 / cols
	for c in cols:
		_stack(ci, r, 0.06 + c * cw, 0.06 + (c + 1) * cw - 0.015, 0.44, 0.97, rows)


# ---------------------------------------------------------------- MT-140: 400 V train bus
# the module train's bus distribution: the inter-car coupler sockets on both sides (round,
# pinned), the bus bars across, the car section contactors, the line insulation monitor
static func train_bus(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.08, 0.02, 0.92, 0.98), 0.62, 1.3)
	for x in [0.04, 0.96]:
		var c := _u(r, x, 0.5)
		O(ci, c, ms * 0.1, 0.62, 1.3)
		for k in 4:
			D(ci, c + Vector2.from_angle(TAU * k / 4.0 + 0.4) * ms * 0.055, 0.9, 0.6)
	var bars := PackedVector2Array()
	for k in 4:
		var y: float = 0.38 + k * 0.08
		bars.append(_u(r, 0.12, y))
		bars.append(_u(r, 0.88, y))
	S(ci, bars, 0.55 if true else 0.4, 2.0)
	for k in 3:
		var x: float = 0.2 + k * 0.24
		var ct := sub(r, x, 0.08, x + 0.16, 0.28)
		R(ci, ct, 0.55)
		S(ci, PackedVector2Array([ct.position + ct.size * Vector2(0.2, 0.3), ct.position + ct.size * Vector2(0.8, 0.3), ct.position + ct.size * Vector2(0.5, 1.0), _u(r, x + 0.08, 0.38)]), 0.45)
		_lamp(ci, ct.position + ct.size * Vector2(0.5, 0.7), maxf(1.4, ms * 0.035), Pal.tint(Pal.FLUID, 0.85))
	E.Rc(ci, sub(r, 0.2, 0.74, 0.6, 0.84), Pal.tint(Pal.AIR, 0.55), 1.0)
	E.gauge(ci, _u(r, 0.74, 0.8), maxf(3.0, ms * 0.08), 0.5)


# ---------------------------------------------------------------- TS-1: bus box
# the training ship's little bus box, lid hinged open: the copper bar on two stand-off
# insulators, a bolted lug at each end, four fuse carriers (holder and fuse body; the blown one
# shows its indicator), the earth bar along the bottom, the four cables out (generator,
# battery, capacitor, lamps)
static func ts_busbox(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.08, 0.06, 0.92, 0.86), 0.62, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.08, 0.06), _u(r, 0.02, 0.0), _u(r, 0.92, 0.06), _u(r, 0.98, 0.0), _u(r, 0.02, 0.0), _u(r, 0.98, 0.0)]), 0.38)
	L(ci, _u(r, 0.14, 0.2), _u(r, 0.86, 0.2), 0.62, 2.6)
	var ins := PackedVector2Array()
	for x in [0.3, 0.7]:
		for k in 2:
			var y: float = 0.235 + k * 0.035
			ins.append(_u(r, x - 0.05, y))
			ins.append(_u(r, x + 0.05, y))
	for x in [0.14, 0.86]:
		var lg := Rect2(_u(r, x, 0.2) - Vector2(ms * 0.05, ms * 0.05), Vector2(ms * 0.1, ms * 0.1))
		ins.append_array(PackedVector2Array([lg.position, Vector2(lg.end.x, lg.position.y), lg.position, Vector2(lg.position.x, lg.end.y),
			Vector2(lg.position.x, lg.end.y), lg.end, Vector2(lg.end.x, lg.position.y), lg.end]))
	S(ci, ins, 0.5, 1.0)
	var fz := PackedVector2Array()
	for k in 4:
		var x: float = 0.22 + k * 0.19
		var fb := sub(r, x - 0.055, 0.38, x + 0.055, 0.62)
		fz.append_array(PackedVector2Array([_u(r, x, 0.2), _u(r, x, 0.34), _u(r, x - 0.07, 0.34), _u(r, x + 0.07, 0.34),
			_u(r, x - 0.07, 0.66), _u(r, x + 0.07, 0.66), _u(r, x, 0.66), _u(r, x, 0.86),
			fb.position, Vector2(fb.end.x, fb.position.y), fb.position, Vector2(fb.position.x, fb.end.y),
			Vector2(fb.position.x, fb.end.y), fb.end, Vector2(fb.end.x, fb.position.y), fb.end]))
		if k == 2:
			_lamp(ci, _u(r, x, 0.5), 1.6, Pal.heat(0.8))
		fz.append(_u(r, x, 0.86))
		fz.append(_u(r, x, 1.0))
	S(ci, fz, 0.5, 1.2)
	L(ci, _u(r, 0.14, 0.76), _u(r, 0.86, 0.76), 0.55, 1.8)


# ---------------------------------------------------------------- FR-26: electric valve box
# the cryo line's valve box: the valve block with four solenoid valves (coils), the pressure
# switch, the pipes in and out, the terminal strip of the coils
static func valve_box(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.04, 0.04, 0.96, 0.96), 0.62, 1.3)
	var bl := sub(r, 0.12, 0.5, 0.88, 0.66)
	R(ci, bl, 0.6, 1.2)
	for k in 4:
		var x: float = 0.2 + k * 0.2
		var co := sub(r, x - 0.06, 0.26, x + 0.06, 0.5)
		R(ci, co, 0.55)
		hatch(ci, co.grow(-1.5), 2.0, false, 0.3, 8)
		S(ci, PackedVector2Array([_u(r, x, 0.26), _u(r, x, 0.16), _u(r, x, 0.66), _u(r, x, 0.96)]), 0.4, 1.2)
	E.gauge(ci, _u(r, 0.5, 0.8), maxf(2.5, ms * 0.08), 0.5)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.58), _u(r, 0.12, 0.58), _u(r, 0.88, 0.58), _u(r, 1.0, 0.58), _u(r, 0.12, 0.16), _u(r, 0.88, 0.16)]), 0.55, 1.6)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.58) - Vector2(0, 0.6), Vector2(r.size.x * 0.12, 1.2)), Pal.tint(Pal.AIR, 0.55), 1.0)


# ---------------------------------------------------------------- ES-112: vault door controller
# the vault door controller: the door mimic (round door, its radial bolts drawn in), the
# three time-lock movements, the keypad, the bolt motor drive, the tamper lamp
static func vault_ctrl(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.03, 0.03, 0.97, 0.97), 0.62, 1.3)
	var dc := _u(r, 0.26, 0.42)
	var dr: float = ms * 0.28
	O(ci, dc, dr, 0.6, 1.3)
	O(ci, dc, dr * 0.3, 0.45)
	var bl := PackedVector2Array()
	for k in 8:
		var a: float = TAU * k / 8.0
		bl.append(dc + Vector2.from_angle(a) * dr * 0.62)
		bl.append(dc + Vector2.from_angle(a) * dr * 0.92)
	S(ci, bl, 0.55, 2.0)
	for k in 3:
		E.gauge(ci, _u(r, 0.58 + k * 0.12, 0.2), maxf(3.0, ms * 0.07), 0.5)
	var kp := PackedVector2Array()
	for row in 3:
		for c in 3:
			kp.append(_u(r, 0.62 + c * 0.06, 0.42 + row * 0.07))
	for p in kp:
		D(ci, p, 1.0, 0.55)
	R(ci, sub(r, 0.56, 0.68, 0.92, 0.88), 0.55)
	S(ci, PackedVector2Array([_u(r, 0.6, 0.78), _u(r, 0.88, 0.78), dc + Vector2(dr, 0), _u(r, 0.56, 0.78)]), 0.45)
	_lamp(ci, _u(r, 0.88, 0.46), maxf(1.6, ms * 0.04), Pal.heat(0.85))


# ---------------------------------------------------------------- PT-34: weapons distribution
# the weapons power board: the master arm key under its guard and the arm lamp, a row of
# guarded arming switches, the capacitor charge contactors with their charge bars, the
# heavy feeds out to the capacitors and the mount
static func weapons_dist(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.05, 0.02, 0.95, 0.98), 0.62, 1.3)
	var mk := _u(r, 0.22, 0.14)
	O(ci, mk, ms * 0.06, 0.55)
	L(ci, mk - Vector2(0, ms * 0.04), mk + Vector2(0, ms * 0.04), 0.6, 1.3)
	P(ci, PackedVector2Array([mk + Vector2(-ms * 0.1, ms * 0.08), mk + Vector2(-ms * 0.1, -ms * 0.09), mk + Vector2(ms * 0.1, -ms * 0.09), mk + Vector2(ms * 0.1, ms * 0.08)]), 0.45)
	_lamp(ci, _u(r, 0.4, 0.14), maxf(1.8, ms * 0.05), Pal.heat(0.9))
	for k in 4:
		_toggle(ci, _u(r, 0.56 + k * 0.1, 0.16), maxf(2.0, ms * 0.04), k % 2 == 0, true)
	for k in 2:
		var x: float = 0.12 + k * 0.42
		var ct := sub(r, x, 0.32, x + 0.34, 0.62)
		R(ci, ct, 0.58)
		S(ci, PackedVector2Array([ct.position + ct.size * Vector2(0.2, 0.3), ct.position + ct.size * Vector2(0.8, 0.3), ct.position + ct.size * Vector2(0.2, 0.7), ct.position + ct.size * Vector2(0.8, 0.7)]), 0.5, 1.6)
		var bar := sub(r, x + 0.06, 0.68, x + 0.28, 0.74)
		R(ci, bar, 0.4)
		hatch(ci, Rect2(bar.position + Vector2(1, 1), Vector2(bar.size.x * (0.4 + 0.4 * k), bar.size.y - 2)), 1.6, true, 0.45, 20)
	S(ci, PackedVector2Array([_u(r, 0.29, 0.62), _u(r, 0.29, 0.98), _u(r, 0.71, 0.62), _u(r, 0.71, 0.98), _u(r, 0.5, 0.8), _u(r, 0.5, 0.98)]), 0.6, 2.4)


# ================================================================ E242–E267 (2026-11-12): seventh batch
# nozzles, attitude thrusters, spheres and the odd ones. The nozzle pieces sit to the right of
# the sixth batch's engine cores, which end in a throat flange at their right edge's middle
# (half-height about 0.15 of the nozzle's height on every ship that pairs them), so every
# nozzle here starts with its own throat flange at its left edge's middle and opens to +x.

static func _nzh(h0: float, h1: float, t: float, k: float = 0.55) -> float:
	return h0 + (h1 - h0) * pow(t, k)


# a contour pair (upper and lower) of a bell from x0 to x1 about cy, n steps, at fraction f of
# the half-height (1.0 = the wall itself)
static func _nz_wall(ci: CanvasItem, r: Rect2, x0: float, x1: float, cy: float, h0: float, h1: float, k: float, f: float, n: int, al: float, wd: float) -> void:
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	for i in n + 1:
		var t: float = float(i) / n
		var hh: float = _nzh(h0, h1, t, k) * f
		up.append(_u(r, lerpf(x0, x1, t), cy - hh))
		dn.append(_u(r, lerpf(x0, x1, t), cy + hh))
	P(ci, up, al, wd)
	P(ci, dn, al, wd)


# ---------------------------------------------------------------- GR-7: tail plug nozzle
# the little tug's truncated plug (aerospike) nozzle: the short outer cowl lip round the annular
# throat with its own cooling tubes, the plug itself tapering inside to its flat base (its
# cooling channels drawn along it, its section seams across, the heat-tinted tip band, two
# thermocouple taps), the two struts that hold the plug, the base-bleed holes in its flat end,
# the mounting flange with its bolt dashes
static func plug_nozzle(ci: CanvasItem, r: Rect2) -> void:
	var cy: float = 0.5
	L(ci, _u(r, 0.012, cy - 0.27), _u(r, 0.012, cy + 0.27), 0.66, 2.2)
	# the cowl lip, both sides
	S(ci, PackedVector2Array([_u(r, 0.02, cy - 0.25), _u(r, 0.2, cy - 0.31), _u(r, 0.02, cy + 0.25), _u(r, 0.2, cy + 0.31),
		_u(r, 0.02, cy - 0.21), _u(r, 0.2, cy - 0.27), _u(r, 0.02, cy + 0.21), _u(r, 0.2, cy + 0.27),
		_u(r, 0.2, cy - 0.31), _u(r, 0.2, cy - 0.27), _u(r, 0.2, cy + 0.31), _u(r, 0.2, cy + 0.27)]), 0.62, 1.4)
	# the plug: a curved spike from the throat to its truncated base
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	var tx := PackedVector2Array()
	for i in 7:
		var t: float = i / 6.0
		var hh: float = lerpf(0.17, 0.06, pow(t, 0.7))
		var x: float = lerpf(0.06, 0.86, t)
		up.append(_u(r, x, cy - hh))
		dn.append(_u(r, x, cy + hh))
		if i % 2 == 0 and i < 6:
			var t2: float = (i + 2) / 6.0
			var h2: float = lerpf(0.17, 0.06, pow(t2, 0.7))
			for f in [-0.7, -0.35, 0.0, 0.35, 0.7]:
				tx.append(_u(r, x, cy + f * hh))
				tx.append(_u(r, lerpf(0.06, 0.86, t2), cy + f * h2))
	P(ci, up, 0.66, 1.6)
	P(ci, dn, 0.66, 1.6)
	# section seams across the plug, the cowl's tubes, the bleed holes, the flange's bolt dashes
	for t in [0.3, 0.6]:
		var hh: float = lerpf(0.17, 0.06, pow(t, 0.7))
		tx.append(_u(r, lerpf(0.06, 0.86, t), cy - hh))
		tx.append(_u(r, lerpf(0.06, 0.86, t), cy + hh))
	for f in [0.23, 0.29]:
		for sgn in [-1.0, 1.0]:
			tx.append(_u(r, 0.03, cy + sgn * (f - 0.02)))
			tx.append(_u(r, 0.19, cy + sgn * (f + 0.02 * (f - 0.2) / 0.1)))
	S(ci, tx, 0.24)
	L(ci, _u(r, 0.86, cy - 0.06), _u(r, 0.86, cy + 0.06), 0.62, 1.8)
	var bd := PackedVector2Array([_u(r, 0.86, cy - 0.03), _u(r, 0.83, cy - 0.03), _u(r, 0.86, cy + 0.03), _u(r, 0.83, cy + 0.03)])
	for k in 5:
		var y: float = cy - 0.24 + k * 0.12
		bd.append(_u(r, 0.0, y))
		bd.append(_u(r, 0.025, y))
	# thermocouple taps on the plug
	for t in [0.45, 0.75]:
		var hh: float = lerpf(0.17, 0.06, pow(t, 0.7))
		bd.append(_u(r, lerpf(0.06, 0.86, t), cy - hh))
		bd.append(_u(r, lerpf(0.06, 0.86, t) + 0.02, cy - hh - 0.05))
	S(ci, bd, 0.5, 1.2)
	E.Rc(ci, Rect2(_u(r, 0.76, cy - 0.072), Vector2(r.size.x * 0.06, r.size.y * 0.004 + 0.8)), Pal.heat(0.5), 1.0)
	# the plug's root in the injector ring, the two struts to the cowl
	S(ci, PackedVector2Array([_u(r, 0.02, cy - 0.17), _u(r, 0.06, cy - 0.17), _u(r, 0.02, cy + 0.17), _u(r, 0.06, cy + 0.17),
		_u(r, 0.18, cy - 0.28), _u(r, 0.26, cy - 0.13), _u(r, 0.18, cy + 0.28), _u(r, 0.26, cy + 0.13)]), 0.5, 1.6)
	# the exhaust free boundary (back, faint) beyond the cowl
	S(ci, PackedVector2Array([_u(r, 0.2, cy - 0.31), _u(r, 0.98, cy - 0.44), _u(r, 0.2, cy + 0.31), _u(r, 0.98, cy + 0.44)]), 0.18)


# ---------------------------------------------------------------- LC-140 / DR-150 / HG-170: main nozzle
# a short conical ablative nozzle bolted to the hull: the bulkhead flange and its bolt dashes,
# the thick wall (outer shell bright, the charring liner's inner face behind it, the liner
# hatched between), the graphite throat insert block, the wall's section seams across the
# cone, the filament-wound overwrap bands, the heat-tinted char band and two thermocouple taps
# near the lip, the lip
static func ablative_nozzle(ci: CanvasItem, r: Rect2) -> void:
	var cy: float = 0.5
	var bp := sub(r, 0.0, 0.04, 0.05, 0.96)
	R(ci, bp, 0.55, 1.2)
	var ou := [_u(r, 0.05, cy - 0.24), _u(r, 0.97, cy - 0.46)]
	var od := [_u(r, 0.05, cy + 0.24), _u(r, 0.97, cy + 0.46)]
	var iu := [_u(r, 0.05, cy - 0.15), _u(r, 0.97, cy - 0.4)]
	var id := [_u(r, 0.05, cy + 0.15), _u(r, 0.97, cy + 0.4)]
	S(ci, PackedVector2Array([ou[0], ou[1], od[0], od[1]]), 0.66, 1.6)
	S(ci, PackedVector2Array([iu[0], iu[1], id[0], id[1]]), 0.42, 1.1)
	var hs := PackedVector2Array()
	for k in 9:
		var t: float = (k + 0.5) / 9.0
		for pr in [[ou, iu], [od, id]]:
			hs.append(pr[0][0].lerp(pr[0][1], t))
			hs.append(pr[1][0].lerp(pr[1][1], minf(1.0, t + 0.05)))
	# section seams across the cone (the liner is laid up in rings), faint
	for t in [0.22, 0.44, 0.66, 0.86]:
		hs.append(iu[0].lerp(iu[1], t))
		hs.append(id[0].lerp(id[1], t))
	S(ci, hs, 0.24)
	for sgn in [-1.0, 1.0]:
		var ti := Rect2(_u(r, 0.06, cy + sgn * 0.2) - Vector2(0, r.size.y * 0.035), Vector2(r.size.x * 0.12, r.size.y * 0.07))
		R(ci, ti, 0.55)
		S(ci, PackedVector2Array([ti.position, ti.end, Vector2(ti.position.x, ti.end.y), Vector2(ti.end.x, ti.position.y)]), 0.35)
	var bd := PackedVector2Array()
	for t in [0.32, 0.62]:
		var x: float = lerpf(0.05, 0.97, t)
		var hh: float = lerpf(0.24, 0.46, t)
		bd.append(_u(r, x - 0.02, cy - hh - 0.01))
		bd.append(_u(r, x + 0.02, cy - hh - 0.02))
		bd.append(_u(r, x - 0.02, cy + hh + 0.01))
		bd.append(_u(r, x + 0.02, cy + hh + 0.02))
	S(ci, bd, 0.55, 2.0)
	# bolt dashes on the bulkhead flange, the thermocouple taps and their leads
	var ds := PackedVector2Array()
	for k in 6:
		var y: float = 0.12 + k * 0.152
		ds.append(_u(r, 0.015, y))
		ds.append(_u(r, 0.035, y))
	for t in [0.76, 0.9]:
		var x: float = lerpf(0.05, 0.97, t)
		var hh: float = lerpf(0.24, 0.46, t)
		ds.append(_u(r, x, cy - hh))
		ds.append(_u(r, x, cy - hh - 0.035))
		ds.append(_u(r, x, cy - hh - 0.035))
		ds.append(_u(r, x - 0.08, cy - hh - 0.035))
	S(ci, ds, 0.5, 1.2)
	var cx: float = 0.8
	E.Rc(ci, Rect2(iu[0].lerp(iu[1], cx), Vector2(1.2, (id[0].lerp(id[1], cx) - iu[0].lerp(iu[1], cx)).y)), Pal.heat(0.4), 1.0)
	L(ci, _u(r, 0.97, cy - 0.47), _u(r, 0.97, cy + 0.47), 0.6, 1.8)


# ---------------------------------------------------------------- the common nozzle (39 on 23 ships)
# a tube-wall regeneratively cooled bell: the throat flange to the engine core, the bright outer
# contour, the cooling tubes running along it in groups (closing up at the throat and fanning out
# to the exit), the two hat-band stiffeners (a pair of lines each, their bolts as dashes), the
# coolant inlet manifold round the exit and the return line running back to the throat, the
# actuator lugs
static func regen_nozzle(ci: CanvasItem, r: Rect2) -> void:
	var cy: float = 0.5
	var h0: float = 0.155
	var h1: float = 0.46
	var x0: float = 0.02
	var x1: float = 0.95
	L(ci, _u(r, 0.012, cy - h0 - 0.04), _u(r, 0.012, cy + h0 + 0.04), 0.66, 2.2)
	_nz_wall(ci, r, x0, x1, cy, h0, h1, 0.55, 1.0, 6, 0.66, 1.5)
	var tb := PackedVector2Array()
	for f in [-0.86, -0.74, -0.42, -0.3, 0.3, 0.42, 0.74, 0.86]:
		for i in 4:
			var ta: float = i / 4.0
			var tc: float = (i + 1) / 4.0
			tb.append(_u(r, lerpf(x0, x1, ta), cy + f * _nzh(h0, h1, ta)))
			tb.append(_u(r, lerpf(x0, x1, tc), cy + f * _nzh(h0, h1, tc)))
	S(ci, tb, 0.24)
	var hb := PackedVector2Array()
	var dsh := PackedVector2Array()
	for t in [0.3, 0.62]:
		for dt in [-0.015, 0.015]:
			var x: float = lerpf(x0, x1, t + dt)
			var hh: float = _nzh(h0, h1, t + dt)
			hb.append(_u(r, x, cy - hh - 0.012))
			hb.append(_u(r, x, cy + hh + 0.012))
		var hh2: float = _nzh(h0, h1, t)
		for f in [-0.95, 0.95]:
			dsh.append(_u(r, lerpf(x0, x1, t) - 0.01, cy + f * hh2))
			dsh.append(_u(r, lerpf(x0, x1, t) + 0.01, cy + f * hh2))
	hb.append(_u(r, x1, cy - h1 - 0.03))
	hb.append(_u(r, 0.5, cy - _nzh(h0, h1, 0.5) - 0.04))
	hb.append(_u(r, 0.5, cy - _nzh(h0, h1, 0.5) - 0.04))
	hb.append(_u(r, 0.06, cy - h0 - 0.05))
	S(ci, hb, 0.5, 1.3)
	S(ci, dsh, 0.6, 2.0)
	S(ci, PackedVector2Array([_u(r, x1 + 0.015, cy - h1 - 0.02), _u(r, x1 + 0.015, cy + h1 + 0.02), _u(r, x1, cy - h1 - 0.02), _u(r, x1 + 0.03, cy - h1 - 0.02),
		_u(r, x1, cy + h1 + 0.02), _u(r, x1 + 0.03, cy + h1 + 0.02)]), 0.6, 1.8)
	var ms := minf(r.size.x, r.size.y)
	var lg := PackedVector2Array()
	for sgn in [-1.0, 1.0]:
		var c := _u(r, lerpf(x0, x1, 0.45), cy + sgn * (_nzh(h0, h1, 0.45) + 0.02))
		lg.append_array(PackedVector2Array([c + Vector2(-ms * 0.04, 0), c + Vector2(0, sgn * ms * 0.05), c + Vector2(0, sgn * ms * 0.05), c + Vector2(ms * 0.04, 0)]))
	S(ci, lg, 0.5)


# ---------------------------------------------------------------- ARK-01 / EV-55 / NR-95 / ST-40: main nozzle
# the big two-part nozzle: the regeneratively cooled upper bell (its cooling tubes in bundles
# along it), the bolted joint (a flange pair, its bolt row as dashes), the turbine-exhaust
# manifold over the joint dump-cooling the extension (its duct back towards the engine), the
# thin radiation-cooled extension (its panel seams along it, three stiffener rings across, two
# thermocouple taps, the heat-tinted band near the lip), the lip, the gimbal actuator lugs
static func thrust_nozzle(ci: CanvasItem, r: Rect2) -> void:
	var cy: float = 0.5
	var h0: float = 0.14
	var h1: float = 0.48
	var tj: float = 0.36
	var xj: float = lerpf(0.02, 0.98, tj)
	var ms := minf(r.size.x, r.size.y)
	L(ci, _u(r, 0.012, cy - h0 - 0.04), _u(r, 0.012, cy + h0 + 0.04), 0.66, 2.4)
	var hj: float = _nzh(h0, h1, tj)
	var up := PackedVector2Array()
	var dn := PackedVector2Array()
	var eu := PackedVector2Array()
	var ed := PackedVector2Array()
	var tb := PackedVector2Array()
	for i in 5:
		var t: float = tj * i / 4.0
		var x: float = lerpf(0.02, 0.98, t)
		up.append(_u(r, x, cy - _nzh(h0, h1, t)))
		dn.append(_u(r, x, cy + _nzh(h0, h1, t)))
		if i % 2 == 0 and i < 4:
			var t2: float = tj * (i + 2) / 4.0
			for f in [-0.8, -0.7, -0.35, -0.25, 0.25, 0.35, 0.7, 0.8]:
				tb.append(_u(r, x, cy + f * _nzh(h0, h1, t)))
				tb.append(_u(r, lerpf(0.02, 0.98, t2), cy + f * _nzh(h0, h1, t2)))
	for i in 6:
		var t: float = lerpf(tj, 1.0, i / 5.0)
		var x: float = lerpf(0.02, 0.98, t)
		eu.append(_u(r, x, cy - _nzh(h0, h1, t)))
		ed.append(_u(r, x, cy + _nzh(h0, h1, t)))
	P(ci, up, 0.68, 1.7)
	P(ci, dn, 0.68, 1.7)
	P(ci, eu, 0.6, 1.3)
	P(ci, ed, 0.6, 1.3)
	# the extension's panel seams (straight along it) and its stiffener rings across
	for f in [-0.55, 0.0, 0.55]:
		tb.append(_u(r, xj + 0.02, cy + f * hj))
		tb.append(_u(r, 0.97, cy + f * h1))
	var st := PackedVector2Array()
	for k in 3:
		var t: float = lerpf(tj, 1.0, (k + 1) / 4.0)
		var x: float = lerpf(0.02, 0.98, t)
		var hh: float = _nzh(h0, h1, t)
		tb.append(_u(r, x, cy - hh))
		tb.append(_u(r, x, cy + hh))
		st.append(_u(r, x, cy - hh - 0.012))
		st.append(_u(r, x, cy - hh + 0.025))
		st.append(_u(r, x, cy + hh + 0.012))
		st.append(_u(r, x, cy + hh - 0.025))
	S(ci, tb, 0.24)
	# the joint: flange pair and its bolt dashes
	st.append_array(PackedVector2Array([_u(r, xj - 0.008, cy - hj - 0.03), _u(r, xj - 0.008, cy + hj + 0.03), _u(r, xj + 0.008, cy - hj - 0.03), _u(r, xj + 0.008, cy + hj + 0.03)]))
	S(ci, st, 0.62, 1.8)
	var ds := PackedVector2Array()
	for k in 8:
		var y: float = cy - hj * 0.92 + k * hj * 1.84 / 7.0
		ds.append(_u(r, xj - 0.02, y))
		ds.append(_u(r, xj + 0.02, y))
	# the exhaust manifold bars over the joint, its duct, the thermocouple taps
	for sgn in [-1.0, 1.0]:
		ds.append(_u(r, xj - 0.03, cy + sgn * (hj + 0.06)))
		ds.append(_u(r, xj + 0.06, cy + sgn * (hj + 0.06)))
	ds.append_array(PackedVector2Array([_u(r, xj - 0.03, cy - hj - 0.06), _u(r, 0.22, cy - 0.47), _u(r, 0.22, cy - 0.47), _u(r, 0.02, cy - 0.47)]))
	for t in [0.55, 0.8]:
		var x: float = lerpf(0.02, 0.98, t)
		var hh: float = _nzh(h0, h1, t)
		ds.append(_u(r, x, cy + hh))
		ds.append(_u(r, x + 0.015, cy + hh - 0.05))
	ds.append_array(PackedVector2Array([_u(r, xj - 0.06, cy - hj), _u(r, xj - 0.06, cy - hj - 0.05), _u(r, xj - 0.06, cy + hj), _u(r, xj - 0.06, cy + hj + 0.05)]))
	S(ci, ds, 0.52, 1.4)
	L(ci, _u(r, 0.985, cy - h1), _u(r, 0.985, cy + h1), 0.55, 1.4)
	var xh: float = 0.9
	var hhh: float = _nzh(h0, h1, (xh - 0.02) / 0.96)
	E.Rc(ci, Rect2(_u(r, xh, cy - hhh), Vector2(maxf(1.0, r.size.x * 0.006), r.size.y * hhh * 2.0)), Pal.heat(0.35), 1.0)
	E.Rc(ci, Rect2(_u(r, 0.975, cy - h1), Vector2(maxf(1.0, r.size.x * 0.006), r.size.y * h1 * 2.0)), Pal.heat(0.55), 1.0)


# ---------------------------------------------------------------- VT-80: tail vent stack
# the vent stack, standing: the base flange and its drain, the stack tube with an expansion
# bellows, the perforated silencer section, the flame arrestor element, the weather cowl on
# top with its louvres, the two guy brackets to the hull
static func vent_stack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	R(ci, sub(r, 0.08, 0.95, 0.92, 0.99), 0.6, 1.3)
	S(ci, PackedVector2Array([_u(r, 0.3, 0.12), _u(r, 0.3, 0.95), _u(r, 0.7, 0.12), _u(r, 0.7, 0.95)]), 0.62, 1.4)
	var sg := PackedVector2Array()
	# bellows
	for k in 4:
		var y: float = 0.78 + k * 0.025
		sg.append(_u(r, 0.24, y))
		sg.append(_u(r, 0.76, y))
	# silencer section, perforations (short ticks in rows)
	for k in 7:
		var y: float = 0.4 + k * 0.045
		for x in [0.38, 0.5, 0.62]:
			sg.append(_u(r, x - 0.03, y))
			sg.append(_u(r, x + 0.03, y))
	sg.append_array(PackedVector2Array([_u(r, 0.22, 0.38), _u(r, 0.78, 0.38), _u(r, 0.22, 0.72), _u(r, 0.78, 0.72),
		_u(r, 0.22, 0.38), _u(r, 0.22, 0.72), _u(r, 0.78, 0.38), _u(r, 0.78, 0.72)]))
	S(ci, sg, 0.42)
	# the flame arrestor element (crossed grid) and the weather cowl with its louvres
	var fa := sub(r, 0.3, 0.2, 0.7, 0.28)
	R(ci, fa, 0.55)
	hatch(ci, fa.grow(-1.0), 2.4, true, 0.3, 8)
	var cw := PackedVector2Array([_u(r, 0.12, 0.12), _u(r, 0.88, 0.12), _u(r, 0.12, 0.12), _u(r, 0.3, 0.02), _u(r, 0.88, 0.12), _u(r, 0.7, 0.02), _u(r, 0.3, 0.02), _u(r, 0.7, 0.02)])
	for k in 3:
		var y: float = 0.135 + k * 0.018
		cw.append(_u(r, 0.18, y))
		cw.append(_u(r, 0.82, y + 0.01))
	S(ci, cw, 0.58, 1.2)
	# drain at the base, guy brackets
	S(ci, PackedVector2Array([_u(r, 0.7, 0.9), _u(r, 0.86, 0.9), _u(r, 0.86, 0.9), _u(r, 0.86, 0.95),
		_u(r, 0.3, 0.5), _u(r, 0.02, 0.62), _u(r, 0.7, 0.5), _u(r, 0.98, 0.62)]), 0.45, 1.2)
	D(ci, _u(r, 0.02, 0.62), maxf(1.0, ms * 0.04), 0.55)
	D(ci, _u(r, 0.98, 0.62), maxf(1.0, ms * 0.04), 0.55)


# ---------------------------------------------------------------- H-22 / M-14 / S-09: attitude nozzle (0.9 x 0.6 m)
# a cold-gas attitude pair: the plenum block, the two solenoid valves and
# the two opposed conical nozzles out of them, the nitrogen feed in from below with its filter
static func cold_gas_pair(ci: CanvasItem, r: Rect2) -> void:
	var pl := sub(r, 0.4, 0.3, 0.6, 0.62)
	R(ci, pl, 0.62, 1.3)
	S(ci, PackedVector2Array([_u(r, 0.26, 0.34), _u(r, 0.4, 0.34), _u(r, 0.26, 0.58), _u(r, 0.4, 0.58), _u(r, 0.26, 0.34), _u(r, 0.26, 0.58),
		_u(r, 0.6, 0.34), _u(r, 0.74, 0.34), _u(r, 0.6, 0.58), _u(r, 0.74, 0.58), _u(r, 0.74, 0.34), _u(r, 0.74, 0.58)]), 0.5, 1.0)
	# the conical nozzles, out both sides
	S(ci, PackedVector2Array([_u(r, 0.26, 0.42), _u(r, 0.04, 0.3), _u(r, 0.26, 0.5), _u(r, 0.04, 0.62), _u(r, 0.04, 0.3), _u(r, 0.04, 0.62),
		_u(r, 0.74, 0.42), _u(r, 0.96, 0.3), _u(r, 0.74, 0.5), _u(r, 0.96, 0.62), _u(r, 0.96, 0.3), _u(r, 0.96, 0.62)]), 0.64, 1.3)
	# the feed from below, its filter
	S(ci, PackedVector2Array([_u(r, 0.5, 0.62), _u(r, 0.5, 1.0), _u(r, 0.44, 0.74), _u(r, 0.56, 0.74), _u(r, 0.44, 0.84), _u(r, 0.56, 0.84),
		_u(r, 0.44, 0.74), _u(r, 0.44, 0.84), _u(r, 0.56, 0.74), _u(r, 0.56, 0.84)]), 0.55, 1.2)


# ---------------------------------------------------------------- ARK-01 / EV-55 / ST-40 / VT-80 / IH-55: RCS pod (3.6 x 1.0 m)
# a long bipropellant RCS pod: the two propellant
# manifold rails along it, four thrusters (two axial out the ends, two radial up and down from
# the middle) each with its small chamber, bell and twin valve block, the heater strip
static func rcs_pod(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var body := sub(r, 0.16, 0.24, 0.84, 0.76)
	R(ci, body, 0.6, 1.3)
	var sg := PackedVector2Array([_u(r, 0.18, 0.4), _u(r, 0.82, 0.4), _u(r, 0.18, 0.6), _u(r, 0.82, 0.6)])
	S(ci, sg, 0.45, 1.4)
	E.Rc(ci, sub(r, 0.3, 0.27, 0.7, 0.3), Pal.heat(0.45), 1.0)
	# the axial thrusters out the ends: valve block, chamber, bell
	for sgn in [-1.0, 1.0]:
		var xv: float = 0.5 + sgn * 0.3
		S(ci, PackedVector2Array([_u(r, xv, 0.5) + Vector2(-ms * 0.12, -ms * 0.14), _u(r, xv, 0.5) + Vector2(-ms * 0.12, ms * 0.14),
			_u(r, xv, 0.5) + Vector2(ms * 0.12, -ms * 0.14), _u(r, xv, 0.5) + Vector2(ms * 0.12, ms * 0.14)]), 0.55)
		var a: float = 0.5 + sgn * 0.34
		var b: float = 0.5 + sgn * 0.4
		var c: float = 0.5 + sgn * 0.495
		_pu(ci, r, [Vector2(a, 0.42), Vector2(b, 0.42), Vector2(b + sgn * 0.01, 0.46), Vector2(c, 0.22)], 0.64, 1.3)
		_pu(ci, r, [Vector2(a, 0.58), Vector2(b, 0.58), Vector2(b + sgn * 0.01, 0.54), Vector2(c, 0.78)], 0.64, 1.3)
		L(ci, _u(r, c, 0.22), _u(r, c, 0.78), 0.55, 1.4)
	# the radial pair from the middle, up and down
	for sgn in [-1.0, 1.0]:
		var y0: float = 0.5 + sgn * 0.26
		var y1: float = 0.5 + sgn * 0.48
		S(ci, PackedVector2Array([_u(r, 0.48, y0), _u(r, 0.45, y1), _u(r, 0.52, y0), _u(r, 0.55, y1), _u(r, 0.45, y1), _u(r, 0.55, y1)]), 0.6, 1.2)


# ---------------------------------------------------------------- POD / S-09 / TB-180 / MY-48: forward RCS (0.9 x 0.5 m)
# a monopropellant four-thruster cluster on a canted bracket: the bracket, four small thrusters
# canted out in an X, each with its feed from the bracket, the common feed
static func mono_cluster(ci: CanvasItem, r: Rect2) -> void:
	var c := _u(r, 0.5, 0.56)
	var br := sub(r, 0.36, 0.44, 0.64, 0.68)
	R(ci, br, 0.62, 1.3)
	var sg := PackedVector2Array()
	for k in 4:
		var d := Vector2(-1 if k % 2 == 0 else 1, -1 if k < 2 else 1)
		var dv := Vector2(d.x * r.size.x * 0.3, d.y * r.size.y * 0.36)
		var a := c + dv * 0.42
		var b := c + dv * 0.86
		var t := dv.normalized().orthogonal()
		var ws: float = minf(r.size.x, r.size.y) * 0.07
		sg.append_array(PackedVector2Array([a + t * ws * 0.6, b + t * ws * 1.4, a - t * ws * 0.6, b - t * ws * 1.4, b + t * ws * 1.4, b - t * ws * 1.4,
			c + dv * 0.24, a]))
	S(ci, sg, 0.6, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.68), _u(r, 0.5, 1.0)]), 0.5, 1.2)


# ---------------------------------------------------------------- OB-90: reaction wheel
# a reaction wheel on its mounting plate: the sealed housing with its flange bolts, a quarter
# cut away to show the flywheel's heavy rim, web and hub bearing, the motor's stator teeth round
# the hub, the speed sensor, the connector and its cable
static func ob_reaction_wheel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var c := _u(r, 0.5, 0.46)
	var rad: float = ms * 0.38
	S(ci, PackedVector2Array([_u(r, 0.06, 0.92), _u(r, 0.94, 0.92), _u(r, 0.06, 0.98), _u(r, 0.94, 0.98), _u(r, 0.06, 0.92), _u(r, 0.06, 0.98),
		_u(r, 0.94, 0.92), _u(r, 0.94, 0.98), _u(r, 0.3, 0.84), _u(r, 0.3, 0.92), _u(r, 0.7, 0.84), _u(r, 0.7, 0.92)]), 0.55, 1.2)
	A(ci, c, rad, PI * 0.5, TAU, 0.62, 1.5)
	for k in 6:
		D(ci, c + Vector2.from_angle(PI * 0.6 + k * PI * 0.27) * rad * 0.92, 0.9, 0.55)
	# the cut-away quarter: rim (thick), web, hub
	A(ci, c, rad * 0.78, 0.0, PI * 0.5, 0.62, 3.0)
	A(ci, c, rad * 0.62, 0.0, PI * 0.5, 0.4)
	S(ci, PackedVector2Array([c, c + Vector2(rad, 0), c, c + Vector2(0, rad), c + Vector2(rad * 0.25, 0), c + Vector2(rad * 0.62, 0),
		c + Vector2(0, rad * 0.25), c + Vector2(0, rad * 0.62)]), 0.45)
	O(ci, c, rad * 0.22, 0.6, 1.3)
	D(ci, c, 1.2, 0.6)
	var tt := PackedVector2Array()
	for k in 8:
		var a: float = TAU * k / 8.0
		tt.append(c + Vector2.from_angle(a) * rad * 0.24)
		tt.append(c + Vector2.from_angle(a) * rad * 0.32)
	S(ci, tt, 0.35)
	R(ci, Rect2(c + Vector2(-rad * 1.0, -rad * 0.95), Vector2(rad * 0.3, rad * 0.24)), 0.5)
	R(ci, Rect2(c + Vector2(rad * 0.7, -rad * 1.05), Vector2(rad * 0.36, rad * 0.3)), 0.55)
	L(ci, c + Vector2(rad * 1.06, -rad * 0.9), _u(r, 1.0, 0.1), 0.5, 1.4)


# ---------------------------------------------------------------- FX-70: liquid-helium dewar
# a helium dewar: the outer vacuum vessel and the inner helium vessel inside it (the layers of
# superinsulation between, ticked in), the G10 support straps, the neck tube up to the head
# with its relief valve, the liquid's level
static func he_dewar(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var c := _u(r, 0.5, 0.55)
	var ro: float = ms * 0.42
	var ri: float = ms * 0.3
	O(ci, c, ro, 0.62, 1.5)
	O(ci, c, ri, 0.55, 1.2)
	var sg := PackedVector2Array()
	for a in [PI * 1.2, PI * 1.4, PI * 1.6, PI * 1.8]:
		sg.append(c + Vector2.from_angle(a) * (ri + (ro - ri) * 0.3))
		sg.append(c + Vector2.from_angle(a + 0.12) * (ri + (ro - ri) * 0.3))
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		sg.append(c + Vector2.from_angle(a) * ri)
		sg.append(c + Vector2.from_angle(a + 0.25) * ro)
	# the neck, the head
	sg.append_array(PackedVector2Array([c + Vector2(-ms * 0.035, -ri), c + Vector2(-ms * 0.035, -ro - ms * 0.06), c + Vector2(ms * 0.035, -ri), c + Vector2(ms * 0.035, -ro - ms * 0.06)]))
	S(ci, sg, 0.5, 1.2)
	var hd := Rect2(c + Vector2(-ms * 0.12, -ro - ms * 0.13), Vector2(ms * 0.24, ms * 0.07))
	R(ci, hd, 0.6, 1.3)
	D(ci, hd.position + Vector2(-ms * 0.03, hd.size.y * 0.5), maxf(1.2, ms * 0.03), 0.6)
	# the liquid level, its hatch below
	var ly: float = c.y + ri * 0.35
	var hw: float = sqrt(maxf(0.0, ri * ri - (ri * 0.35) * (ri * 0.35)))
	L(ci, Vector2(c.x - hw, ly), Vector2(c.x + hw, ly), 0.6, 1.2)
	var lq := PackedVector2Array()
	for k in 2:
		var y: float = ly + (k + 1) * ri * 0.2
		var w: float = sqrt(maxf(0.0, ri * ri - (y - c.y) * (y - c.y))) * 0.9
		lq.append(Vector2(c.x - w, y))
		lq.append(Vector2(c.x + w, y))
	S(ci, lq, 0.35)
	E.Rc(ci, Rect2(Vector2(c.x - hw * 0.6, ly - 0.6), Vector2(hw * 1.2, 1.2)), Pal.tint(Pal.AIR, 0.6), 1.0)


# ---------------------------------------------------------------- MY-48: zero-g spa sphere
# the yacht's zero-g spa: the clear sphere (outer shell, its frame ribs drawn back), the floating
# body of water inside it (a wobbling blob with its surface ripples), the bathers' handholds
# round the rim, the entry hatch with its seal, the inlet jets, the recirculation pump and
# filter under it, the air-curtain fan
static func zero_g_spa(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var c := _u(r, 0.5, 0.47)
	var rad: float = ms * 0.4
	O(ci, c, rad, 0.62, 1.6)
	# the water blob
	var bl := PackedVector2Array()
	for k in 25:
		var a: float = TAU * k / 24.0
		var rr: float = rad * (0.56 + 0.06 * sin(a * 3.0 + 0.7) + 0.035 * sin(a * 5.0))
		bl.append(c + Vector2(cos(a) * rr * 1.06, sin(a) * rr * 0.92) + Vector2(rad * 0.04, rad * 0.06))
	P(ci, bl, 0.55, 1.3)
	A(ci, c + Vector2(rad * 0.04, rad * 0.06), rad * 0.42, PI * 1.1, PI * 1.5, 0.35)
	E.Rc(ci, Rect2(c + Vector2(-rad * 0.3, rad * 0.1), Vector2(rad * 0.6, 1.2)), Pal.tint(Pal.FLUID, 0.55), 1.0)
	# handholds round the rim, the inlet jets
	var sg := PackedVector2Array()
	for k in 8:
		var a: float = TAU * k / 8.0 + 0.2
		var p0 := c + Vector2.from_angle(a) * rad
		sg.append(p0)
		sg.append(c + Vector2.from_angle(a + 0.12) * rad * 1.07)
		sg.append(c + Vector2.from_angle(a + 0.12) * rad * 1.07)
		sg.append(c + Vector2.from_angle(a + 0.24) * rad)
		var j := a + PI / 8.0
		sg.append(c + Vector2.from_angle(j) * rad * 0.95)
		sg.append(c + Vector2.from_angle(j) * rad * 0.86)
	S(ci, sg, 0.5, 1.2)
	# the entry hatch with its seal (upper right)
	var hc := c + Vector2.from_angle(-PI * 0.25) * rad
	O(ci, hc, rad * 0.18, 0.62, 1.4)
	# the pump and filter under it, their lines, the fan on the left
	var pb := Rect2(c + Vector2(-rad * 0.5, rad * 1.06), Vector2(rad * 0.4, rad * 0.16))
	var fb := Rect2(c + Vector2(rad * 0.15, rad * 1.04), Vector2(rad * 0.22, rad * 0.2))
	R(ci, pb, 0.55)
	R(ci, fb, 0.55)
	hatch(ci, fb.grow(-1.0), 2.4, false, 0.3, 8)
	S(ci, PackedVector2Array([pb.position + Vector2(pb.size.x * 0.5, 0), c + Vector2(-rad * 0.3, rad * 0.92), fb.position + Vector2(fb.size.x * 0.5, 0), c + Vector2(rad * 0.26, rad * 0.96),
		pb.end - Vector2(0, pb.size.y * 0.5), fb.position + Vector2(0, fb.size.y * 0.5)]), 0.45, 1.2)
	var fc := c + Vector2(-rad * 1.12, -rad * 0.6)
	S(ci, PackedVector2Array([fc + Vector2(-rad * 0.1, 0), fc + Vector2(rad * 0.1, 0), fc + Vector2(0, -rad * 0.1), fc + Vector2(0, rad * 0.1)]), 0.4)


# ---------------------------------------------------------------- MF-126: steam drum
# the boiler's steam drum lying on its saddles: the shell and its two dished heads, the water
# level inside (the water hatched below it), the cyclone separators along the top half, the
# risers coming in from below and the two downcomers going out, the steam outlet nozzle and the
# two safety valves on top, the gauge glass on the end head, the manway on the other
static func steam_drum(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var y0: float = 0.28
	var y1: float = 0.72
	var hr: float = (y1 - y0) * 0.5 * r.size.y
	var cy: float = (y0 + y1) * 0.5
	S(ci, PackedVector2Array([_u(r, 0.16, y0), _u(r, 0.84, y0), _u(r, 0.16, y1), _u(r, 0.84, y1)]), 0.64, 1.6)
	A(ci, _u(r, 0.16, cy), hr, PI * 0.5, PI * 1.5, 0.64, 1.6)
	A(ci, _u(r, 0.84, cy), hr, -PI * 0.5, PI * 0.5, 0.64, 1.6)
	# water level and the water below it
	var wl: float = 0.53
	L(ci, _u(r, 0.1, wl), _u(r, 0.9, wl), 0.55, 1.2)
	var wq := PackedVector2Array()
	for k in 4:
		var y: float = wl + (k + 1) * 0.035
		wq.append(_u(r, 0.12 + k * 0.01, y))
		wq.append(_u(r, 0.88 - k * 0.01, y))
	S(ci, wq, 0.28)
	E.Rc(ci, Rect2(_u(r, 0.3, wl) - Vector2(0, 0.6), Vector2(r.size.x * 0.4, 1.2)), Pal.tint(Pal.FLUID, 0.6), 1.0)
	# cyclone separators (small cans with their chevron driers)
	var sg := PackedVector2Array()
	for k in 4:
		var x: float = 0.3 + k * 0.13
		sg.append_array(PackedVector2Array([_u(r, x - 0.03, 0.34), _u(r, x - 0.03, 0.48), _u(r, x + 0.03, 0.34), _u(r, x + 0.03, 0.48),
			_u(r, x - 0.03, 0.34), _u(r, x, 0.31), _u(r, x + 0.03, 0.34), _u(r, x, 0.31)]))
	S(ci, sg, 0.4)
	# risers in from below, downcomers out, steam outlet and safety valves on top
	var pp := PackedVector2Array()
	for x in [0.3, 0.42, 0.58, 0.7]:
		pp.append(_u(r, x, y1))
		pp.append(_u(r, x - 0.04, 1.0))
	for x in [0.2, 0.8]:
		pp.append(_u(r, x, y1 - 0.01))
		pp.append(_u(r, x, 1.0))
		pp.append(_u(r, x + 0.02, y1 + 0.02))
		pp.append(_u(r, x + 0.02, 1.0))
	pp.append_array(PackedVector2Array([_u(r, 0.5, y0), _u(r, 0.5, 0.0), _u(r, 0.54, y0), _u(r, 0.54, 0.0)]))
	S(ci, pp, 0.55, 1.4)
	for x in [0.3, 0.72]:
		var vb := sub(r, x - 0.03, 0.12, x + 0.03, y0)
		R(ci, vb, 0.55)
		L(ci, _u(r, x, 0.12), _u(r, x, 0.04), 0.5, 1.4)
		L(ci, _u(r, x - 0.035, 0.08), _u(r, x + 0.035, 0.08), 0.5, 1.6)
	# the gauge glass on the left head, the manway on the right
	var gg := sub(r, 0.02, 0.4, 0.05, 0.64)
	R(ci, gg, 0.55)
	S(ci, PackedVector2Array([_u(r, 0.05, 0.44), _u(r, 0.1, 0.44), _u(r, 0.05, 0.6), _u(r, 0.1, 0.6)]), 0.45)
	E.Rc(ci, Rect2(_u(r, 0.022, wl), Vector2(r.size.x * 0.026, r.size.y * 0.1)), Pal.tint(Pal.FLUID, 0.7), 1.0)
	_ell(ci, _u(r, 0.9, cy), ms * 0.025, hr * 0.5, 0.58, 1.4)
	# saddles
	S(ci, PackedVector2Array([_u(r, 0.22, y1), _u(r, 0.18, 0.84), _u(r, 0.32, y1), _u(r, 0.36, 0.84), _u(r, 0.16, 0.84), _u(r, 0.38, 0.84),
		_u(r, 0.68, y1), _u(r, 0.64, 0.84), _u(r, 0.78, y1), _u(r, 0.82, 0.84), _u(r, 0.62, 0.84), _u(r, 0.84, 0.84)]), 0.4, 1.2)


# ---------------------------------------------------------------- HB-86 / S-09: overhead spray bar
# the maintenance spray line along the ceiling: the canister and its pump at the left end with
# the feed valve, the header pipe, a fan nozzle every metre spraying down, a hanger every three
static func spray_line(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var cw: float = minf(w * 0.08, h * 2.2)
	var cn := Rect2(2.0, h * 0.1, cw, h * 0.8)
	R(ci, cn, 0.6, 1.3)
	L(ci, cn.position + Vector2(cw * 0.3, 0), cn.position + Vector2(cw * 0.3, cn.size.y), 0.4)
	E.Rc(ci, Rect2(cn.position + Vector2(cw * 0.55, cn.size.y * 0.5), Vector2(cw * 0.35, cn.size.y * 0.4)), Pal.tint(Pal.FLUID, 0.55), 1.0)
	var vx: float = cn.end.x + h * 0.6
	O(ci, Vector2(vx, h * 0.35), h * 0.22, 0.55)
	L(ci, Vector2(vx, h * 0.13), Vector2(vx + h * 0.4, h * 0.02), 0.5, 1.2)
	var sg := PackedVector2Array([Vector2(cn.end.x, h * 0.35), Vector2(w - 2.0, h * 0.35), Vector2(cn.end.x, h * 0.5), Vector2(w - 2.0, h * 0.5)])
	S(ci, sg, 0.62, 1.3)
	var nz := PackedVector2Array()
	var step: float = M
	var x: float = vx + h
	var k := 0
	while x < w - 4.0:
		nz.append(Vector2(x, h * 0.5))
		nz.append(Vector2(x, h * 0.62))
		nz.append(Vector2(x, h * 0.62))
		nz.append(Vector2(x - h * 0.3, h * 0.95))
		nz.append(Vector2(x, h * 0.62))
		nz.append(Vector2(x + h * 0.3, h * 0.95))
		if k % 3 == 1:
			nz.append(Vector2(x + step * 0.5, h * 0.35))
			nz.append(Vector2(x + step * 0.5, 0.0))
			nz.append(Vector2(x + step * 0.5 - h * 0.2, 0.0))
			nz.append(Vector2(x + step * 0.5 + h * 0.2, 0.0))
		x += step
		k += 1
	S(ci, nz, 0.45, 1.0)


# ---------------------------------------------------------------- TB-180: tether damper
# the tether's damper: the guide sheave the tether comes round, the hydraulic dashpot (cylinder,
# piston and its rod), the coil spring in parallel with it, the accumulator and its oil line,
# the clevis at the anchor end
static func tether_dashpot(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sc := _u(r, 0.12, 0.5)
	O(ci, sc, ms * 0.32, 0.6, 1.4)
	O(ci, sc, ms * 0.1, 0.5)
	S(ci, PackedVector2Array([sc + Vector2(-ms * 0.3, -ms * 0.12), Vector2(r.position.x, sc.y - ms * 0.45), sc + Vector2(0, -ms * 0.32), _u(r, 0.3, 0.18)]), 0.62, 1.8)
	var cy := sub(r, 0.42, 0.3, 0.8, 0.7)
	R(ci, cy, 0.62, 1.4)
	S(ci, PackedVector2Array([_u(r, 0.56, 0.32), _u(r, 0.56, 0.68), _u(r, 0.58, 0.32), _u(r, 0.58, 0.68),
		_u(r, 0.25, 0.5), _u(r, 0.56, 0.5), _u(r, 0.8, 0.5), _u(r, 0.9, 0.5)]), 0.58, 1.6)
	var sp := PackedVector2Array()
	for k in 9:
		sp.append(_u(r, 0.26 + k * 0.018, 0.22 if k % 2 == 0 else 0.34))
	P(ci, sp, 0.45, 1.0)
	O(ci, _u(r, 0.93, 0.5), ms * 0.08, 0.6, 1.3)
	var ac := sub(r, 0.62, 0.02, 0.78, 0.2)
	R(ci, ac, 0.5)
	S(ci, PackedVector2Array([_u(r, 0.7, 0.2), _u(r, 0.7, 0.3), _u(r, 0.44, 0.3), _u(r, 0.44, 0.7)]), 0.45, 1.1)
	E.Rc(ci, sub(r, 0.6, 0.42, 0.78, 0.58), Pal.tint(Pal.FLUID, 0.4), 1.0)


# ---------------------------------------------------------------- MD-160: clamp actuator
# the clamp's hydraulic actuator: the cylinder on its trunnion, the rod to the toggle linkage,
# the clamp jaw and its pad, the pilot-operated check valve block on the cylinder with its two
# hoses, the rod position sensor
static func clamp_actuator(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cl := sub(r, 0.06, 0.34, 0.46, 0.62)
	R(ci, cl, 0.62, 1.4)
	O(ci, _u(r, 0.12, 0.48), ms * 0.05, 0.55)
	var jp := _u(r, 0.7, 0.48)
	var jt := _u(r, 0.86, 0.14)
	S(ci, PackedVector2Array([_u(r, 0.46, 0.48), jp, jp, jt, jp, _u(r, 0.76, 0.9), _u(r, 0.68, 0.9), _u(r, 0.9, 0.9)]), 0.62, 1.8)
	D(ci, jp, 1.4, 0.6)
	S(ci, PackedVector2Array([jt + Vector2(-ms * 0.12, 0), jt + Vector2(ms * 0.12, 0), jt + Vector2(-ms * 0.12, 0), jt + Vector2(-ms * 0.12, ms * 0.06),
		jt + Vector2(ms * 0.12, 0), jt + Vector2(ms * 0.12, ms * 0.06)]), 0.6, 1.3)
	var vb := sub(r, 0.14, 0.18, 0.34, 0.34)
	R(ci, vb, 0.55)
	S(ci, PackedVector2Array([_u(r, 0.18, 0.18), _u(r, 0.12, 0.02), _u(r, 0.3, 0.18), _u(r, 0.36, 0.02), _u(r, 0.18, 0.34), _u(r, 0.18, 0.4)]), 0.45, 1.2)
	R(ci, sub(r, 0.2, 0.64, 0.42, 0.7), 0.45)
	L(ci, _u(r, 0.42, 0.67), _u(r, 0.6, 0.55), 0.35)


# ---------------------------------------------------------------- OB-90: mirror actuator (x18)
# a mirror segment's actuator, small and lean: the stepper motor, the harmonic gear head, the
# fine screw up to the flexure and the pad that holds the mirror
static func mirror_actuator(ci: CanvasItem, r: Rect2) -> void:
	S(ci, PackedVector2Array([_u(r, 0.1, 0.5), _u(r, 0.42, 0.5), _u(r, 0.1, 0.95), _u(r, 0.42, 0.95), _u(r, 0.1, 0.5), _u(r, 0.1, 0.95),
		_u(r, 0.42, 0.5), _u(r, 0.42, 0.95), _u(r, 0.42, 0.6), _u(r, 0.62, 0.6), _u(r, 0.42, 0.85), _u(r, 0.62, 0.85), _u(r, 0.62, 0.6), _u(r, 0.62, 0.85),
		_u(r, 0.52, 0.6), _u(r, 0.52, 0.3), _u(r, 0.44, 0.3), _u(r, 0.6, 0.3), _u(r, 0.44, 0.3), _u(r, 0.48, 0.2), _u(r, 0.6, 0.3), _u(r, 0.56, 0.2),
		_u(r, 0.3, 0.06), _u(r, 0.9, 0.06), _u(r, 0.48, 0.2), _u(r, 0.48, 0.06), _u(r, 0.56, 0.2), _u(r, 0.56, 0.06)]), 0.58, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.2, 0.5), _u(r, 0.2, 0.95), _u(r, 0.3, 0.5), _u(r, 0.3, 0.95), _u(r, 0.62, 0.72), _u(r, 0.95, 0.72)]), 0.35)


# ---------------------------------------------------------------- HG-170: intake compressor (stage one)
# the axial intake compressor, standing: the bellmouth with its inlet guide vanes on top, the
# casing narrowing down, the rotor drum and its alternating rotor and stator rows, the variable
# stator vane ring and its actuator arm, the bleed valve, the outlet scroll at the foot and the
# drive coupling
static func intake_axial(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	# the bellmouth
	S(ci, PackedVector2Array([_u(r, 0.04, 0.02), _u(r, 0.14, 0.12), _u(r, 0.96, 0.02), _u(r, 0.86, 0.12), _u(r, 0.04, 0.02), _u(r, 0.96, 0.02)]), 0.6, 1.4)
	var ig := PackedVector2Array()
	for k in 6:
		var x: float = 0.2 + k * 0.12
		ig.append(_u(r, x, 0.04))
		ig.append(_u(r, x + 0.03, 0.11))
	S(ci, ig, 0.4)
	# the casing, narrowing
	S(ci, PackedVector2Array([_u(r, 0.14, 0.12), _u(r, 0.26, 0.76), _u(r, 0.86, 0.12), _u(r, 0.74, 0.76)]), 0.64, 1.6)
	# the rotor drum and the blade rows (rotor bright, stator back)
	S(ci, PackedVector2Array([_u(r, 0.42, 0.14), _u(r, 0.4, 0.76), _u(r, 0.58, 0.14), _u(r, 0.6, 0.76), _u(r, 0.42, 0.14), _u(r, 0.58, 0.14)]), 0.55, 1.2)
	var ro := PackedVector2Array()
	var stv := PackedVector2Array()
	for k in 8:
		var y: float = 0.17 + k * 0.075
		var wi: float = lerpf(0.27, 0.15, (y - 0.12) / 0.64)
		var sk: float = 0.015 if k % 2 == 0 else -0.015
		var q := PackedVector2Array([_u(r, 0.5 - 0.08 - (y - 0.14) * 0.03, y), _u(r, 0.5 - 0.08 - wi + 0.08, y + sk),
			_u(r, 0.5 + 0.08 + (y - 0.14) * 0.03, y), _u(r, 0.5 + 0.08 + wi - 0.08, y - sk)])
		if k % 2 == 0:
			ro.append_array(q)
		else:
			stv.append_array(q)
	S(ci, ro, 0.55, 1.2)
	S(ci, stv, 0.3)
	# the VSV ring and its actuator arm on the right, the bleed valve on the left
	S(ci, PackedVector2Array([_u(r, 0.82, 0.28), _u(r, 0.94, 0.28), _u(r, 0.94, 0.28), _u(r, 0.94, 0.56), _u(r, 0.78, 0.44), _u(r, 0.94, 0.44)]), 0.5, 1.2)
	R(ci, sub(r, 0.9, 0.5, 0.98, 0.64), 0.55)
	R(ci, sub(r, 0.06, 0.4, 0.16, 0.52), 0.55)
	L(ci, _u(r, 0.16, 0.46), _u(r, 0.2, 0.46), 0.45, 1.2)
	# the outlet scroll at the foot, the coupling
	A(ci, _u(r, 0.5, 0.84), ms * 0.28, PI * 0.95, PI * 2.05, 0.62, 1.5)
	S(ci, PackedVector2Array([_u(r, 0.22, 0.84), _u(r, 0.0, 0.84), _u(r, 0.22, 0.92), _u(r, 0.0, 0.92), _u(r, 0.22, 0.84), _u(r, 0.22, 0.92),
		_u(r, 0.46, 0.92), _u(r, 0.46, 1.0), _u(r, 0.54, 0.92), _u(r, 0.54, 1.0), _u(r, 0.42, 0.96), _u(r, 0.58, 0.96)]), 0.55, 1.4)


# ---------------------------------------------------------------- DR-150: blowout preventer stack
# the BOP stack, standing on the wellhead: the annular preventer on top (its dome and the
# packing element), two double ram bodies with their bonnets and ram operator cylinders out both
# sides, the drilling spool between them with the choke and kill lines and their two valves
# each, the hydraulic connector at the foot, the control pod hoses up the side
static func bop_stack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	# the annular: dome, body, packing element
	var an := sub(r, 0.24, 0.08, 0.76, 0.24)
	R(ci, an, 0.62, 1.4)
	A(ci, _u(r, 0.5, 0.08), r.size.x * 0.26, PI, TAU, 0.62, 1.4)
	A(ci, _u(r, 0.5, 0.17), r.size.x * 0.14, PI, TAU, 0.45, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.44, 0.0), _u(r, 0.44, 0.04), _u(r, 0.56, 0.0), _u(r, 0.56, 0.04)]), 0.5, 1.2)
	# two double ram bodies, each with bonnets and operator cylinders out both sides
	var sg := PackedVector2Array()
	for y in [0.3, 0.62]:
		var rb := sub(r, 0.3, y, 0.7, y + 0.2)
		R(ci, rb, 0.62, 1.4)
		for k in 2:
			var yy: float = y + 0.05 + k * 0.1
			sg.append_array(PackedVector2Array([_u(r, 0.3, yy), _u(r, 0.7, yy)]))
			for sgn in [-1.0, 1.0]:
				var x0: float = 0.5 + sgn * 0.2
				var x1: float = 0.5 + sgn * 0.33
				var x2: float = 0.5 + sgn * 0.47
				sg.append_array(PackedVector2Array([_u(r, x0, yy - 0.035), _u(r, x1, yy - 0.035), _u(r, x0, yy + 0.035), _u(r, x1, yy + 0.035),
					_u(r, x1, yy - 0.035), _u(r, x1, yy + 0.035), _u(r, x1, yy - 0.02), _u(r, x2, yy - 0.02), _u(r, x1, yy + 0.02), _u(r, x2, yy + 0.02),
					_u(r, x2, yy - 0.02), _u(r, x2, yy + 0.02)]))
	S(ci, sg, 0.5, 1.1)
	# the bore through the stack, behind
	S(ci, PackedVector2Array([_u(r, 0.46, 0.24), _u(r, 0.46, 0.92), _u(r, 0.54, 0.24), _u(r, 0.54, 0.92)]), 0.22)
	# the spool between, choke (right) and kill (left) lines with two valves each
	R(ci, sub(r, 0.36, 0.5, 0.64, 0.62), 0.58, 1.2)
	var ln := PackedVector2Array([_u(r, 0.36, 0.56), _u(r, 0.0, 0.56), _u(r, 0.64, 0.56), _u(r, 1.0, 0.56)])
	S(ci, ln, 0.55, 1.6)
	for x in [0.12, 0.24, 0.76, 0.88]:
		var c := _u(r, x, 0.56)
		P(ci, PackedVector2Array([c + Vector2(-ms * 0.04, -ms * 0.035), c + Vector2(ms * 0.04, ms * 0.035), c + Vector2(ms * 0.04, -ms * 0.035), c + Vector2(-ms * 0.04, ms * 0.035), c + Vector2(-ms * 0.04, -ms * 0.035)]), 0.55)
		L(ci, c, c + Vector2(0, -ms * 0.08), 0.45, 1.2)
	# the connector at the foot (its locking dogs), the wellhead stub
	var cn := sub(r, 0.28, 0.84, 0.72, 0.94)
	R(ci, cn, 0.62, 1.4)
	E.bolts(ci, _u(r, 0.32, 0.89), _u(r, 0.68, 0.89), 5, 0.5, 0.9)
	S(ci, PackedVector2Array([_u(r, 0.4, 0.94), _u(r, 0.4, 1.0), _u(r, 0.6, 0.94), _u(r, 0.6, 1.0)]), 0.55, 1.4)
	# the control pod hoses up the side
	S(ci, PackedVector2Array([_u(r, 0.96, 0.02), _u(r, 0.96, 0.46), _u(r, 0.98, 0.02), _u(r, 0.98, 0.46),
		_u(r, 0.96, 0.18), _u(r, 0.76, 0.18), _u(r, 0.96, 0.4), _u(r, 0.83, 0.4)]), 0.35, 1.0)


# ================================================================ E268–E295 (2026-11-12): eighth batch
# the fourteen kinds that all shared the one capacitor box, each drawn as what it is (capacitor
# cans, pulse networks, chargers, pyrotechnics, an igniter, a survey probe), then the chillers,
# cold boxes, condenser, coolers, fans and two drilling pieces. Circles kept to the few places
# that need them (an O costs up to forty segments).

# a rectangle's four sides as segments, appended to a batch
static func _rs(sg: PackedVector2Array, q: Rect2) -> void:
	sg.append_array(PackedVector2Array([q.position, Vector2(q.end.x, q.position.y), q.position, Vector2(q.position.x, q.end.y),
		Vector2(q.position.x, q.end.y), q.end, Vector2(q.end.x, q.position.y), q.end]))


# a capacitor can seen from the side: the can, its rolled seam under the top, the two screw
# terminals on top, the pressure vent cross on the lid line; appended to a batch
static func _can(sg: PackedVector2Array, q: Rect2) -> void:
	_rs(sg, q)
	var s: float = q.size.y * 0.1
	sg.append_array(PackedVector2Array([q.position + Vector2(0, s), Vector2(q.end.x, q.position.y + s),
		q.position + Vector2(q.size.x * 0.3, 0), q.position + Vector2(q.size.x * 0.3, -s * 0.6),
		q.position + Vector2(q.size.x * 0.7, 0), q.position + Vector2(q.size.x * 0.7, -s * 0.6)]))


# ---------------------------------------------------------------- ARK-01: braking capacitor (supercapacitor rack)
# the regenerative-brake supercapacitor rack: two columns of cylindrical cells strapped in a
# frame, the cell balancing boards down the middle, the series busbar links, the bleed resistor
# block at the foot, the cooling fan on top, the main terminals
static func supercap_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.12, 0.94, 0.86))
	var n := clampi(int(r.size.y * 0.7 / 9.0), 3, 8)
	for k in n:
		var y0: float = 0.15 + k * 0.68 / n
		var y1: float = y0 + 0.68 / n * 0.86
		for xs in [[0.1, 0.4], [0.6, 0.9]]:
			_rs(sg, sub(r, xs[0], y0, xs[1], y1))
			sg.append(_u(r, xs[0] + 0.03, y0))
			sg.append(_u(r, xs[0] + 0.03, y1))
		sg.append(_u(r, 0.4, (y0 + y1) * 0.5))
		sg.append(_u(r, 0.6, (y0 + y1) * 0.5))
	S(ci, sg, 0.5, 1.1)
	R(ci, sub(r, 0.45, 0.15, 0.55, 0.83), 0.55)
	_lamp(ci, _u(r, 0.5, 0.2), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	var bl := sub(r, 0.2, 0.88, 0.8, 0.97)
	R(ci, bl, 0.55)
	hatch(ci, bl.grow(-1.0), 2.4, false, 0.35, 10)
	S(ci, PackedVector2Array([_u(r, 0.3, 0.02), _u(r, 0.7, 0.02), _u(r, 0.3, 0.1), _u(r, 0.7, 0.1), _u(r, 0.3, 0.02), _u(r, 0.3, 0.1), _u(r, 0.7, 0.02), _u(r, 0.7, 0.1),
		_u(r, 0.36, 0.06), _u(r, 0.64, 0.06), _u(r, 0.5, 0.03), _u(r, 0.5, 0.09), _u(r, 0.1, 0.12), _u(r, 0.1, 0.04), _u(r, 0.9, 0.12), _u(r, 0.9, 0.04)]), 0.55, 1.2)
	E.Rc(ci, sub(r, 0.08, 0.035, 0.12, 0.06), Pal.heat(0.8), 1.0)


# ---------------------------------------------------------------- GR-7 / H-22: storage capacitor (one big can)
# one big electrolytic can on its mounting clamp: the can and its rolled seam, the two screw
# terminals with their cable lugs, the vent plug, the clamp band and its two feet
static func storage_can(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_can(sg, sub(r, 0.18, 0.14, 0.82, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.5), _u(r, 0.88, 0.5), _u(r, 0.12, 0.58), _u(r, 0.88, 0.58),
		_u(r, 0.12, 0.5), _u(r, 0.12, 0.96), _u(r, 0.88, 0.5), _u(r, 0.88, 0.96), _u(r, 0.04, 0.96), _u(r, 0.96, 0.96),
		_u(r, 0.37, 0.08), _u(r, 0.2, 0.0), _u(r, 0.63, 0.08), _u(r, 0.8, 0.0)]))
	S(ci, sg, 0.6, 1.2)
	L(ci, _u(r, 0.18, 0.24), _u(r, 0.82, 0.24), 0.4)


# ---------------------------------------------------------------- MD-160 / ARK-01: capacitor bank (6 x 1.8 m)
# a long film-capacitor bank: the rows of cans on their frame, each can's fuse above it, the
# laminated busbar pair across the tops, the discharge resistor and the earthing switch at the
# right end with its handle, the incoming cable box at the left
static func film_bank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.12, 0.88, 0.86, 0.96))
	var n := clampi(int(r.size.x * 0.68 / 16.0), 4, 18)
	for k in n:
		var x0: float = 0.13 + k * 0.72 / n
		var x1: float = x0 + 0.72 / n * 0.74
		_can(sg, sub(r, x0, 0.42, x1, 0.88))
		var xm: float = (x0 + x1) * 0.5
		sg.append_array(PackedVector2Array([_u(r, xm, 0.36), _u(r, xm, 0.24), _u(r, xm - 0.008, 0.3), _u(r, xm + 0.008, 0.3)]))
	S(ci, sg, 0.5, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.12, 0.2), _u(r, 0.86, 0.2), _u(r, 0.12, 0.24), _u(r, 0.86, 0.24)]), 0.62, 2.0)
	var cb := sub(r, 0.01, 0.16, 0.11, 0.6)
	R(ci, cb, 0.58, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.06, 0.6), _u(r, 0.06, 1.0), _u(r, 0.04, 0.6), _u(r, 0.04, 1.0)]), 0.5, 1.4)
	var dr := sub(r, 0.88, 0.16, 0.98, 0.5)
	R(ci, dr, 0.58)
	hatch(ci, dr.grow(-1.0), 2.4, true, 0.3, 10)
	var es := _u(r, 0.93, 0.7)
	S(ci, PackedVector2Array([es, es + Vector2(-ms * 0.08, -ms * 0.14), _u(r, 0.88, 0.62), _u(r, 0.98, 0.62), _u(r, 0.93, 0.7), _u(r, 0.93, 0.96)]), 0.6, 1.6)
	E.Rc(ci, Rect2(es + Vector2(-ms * 0.1, -ms * 0.17), Vector2(ms * 0.05, ms * 0.05)), Pal.heat(0.8), 1.0)


# ---------------------------------------------------------------- CH-110 / IH-55: pulse capacitor (oil-filled case)
# a large oil-filled pulse capacitor: the welded rectangular case with its stiffening ribs,
# the two tall porcelain bushings on the lid (their sheds), the lifting lugs, the case earth
# stud, the oil fill plug, the bulge indicator on the side
static func pulse_cap(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.12, 0.34, 0.88, 0.96))
	for x in [0.32, 0.5, 0.68]:
		sg.append(_u(r, x, 0.36))
		sg.append(_u(r, x, 0.94))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.38), _u(r, 0.88, 0.38)]))
	for x in [0.3, 0.7]:
		sg.append(_u(r, x, 0.34))
		sg.append(_u(r, x, 0.04))
		for k in 5:
			var y: float = 0.1 + k * 0.045
			sg.append(_u(r, x - 0.07, y))
			sg.append(_u(r, x + 0.07, y))
		sg.append(_u(r, x - 0.04, 0.04))
		sg.append(_u(r, x + 0.04, 0.04))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.34), _u(r, 0.06, 0.28), _u(r, 0.88, 0.34), _u(r, 0.94, 0.28)]))
	S(ci, sg, 0.55, 1.2)
	D(ci, _u(r, 0.18, 0.9), maxf(1.2, ms * 0.025), 0.6)
	D(ci, _u(r, 0.5, 0.36), maxf(1.2, ms * 0.02), 0.6)
	E.Rc(ci, sub(r, 0.84, 0.55, 0.88, 0.75), Pal.tint(Pal.AIR, 0.6), 1.0)


# ---------------------------------------------------------------- PT-34: CIWS capacitor (pulse-forming network)
# the CIWS's pulse-forming network: a ladder of capacitor modules and air-core inductors (the
# coils drawn as loops), the thyristor stack that fires it, the output to the gun
static func pfn_ladder(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.84), _u(r, 0.88, 0.84)]))
	for k in 3:
		var x: float = 0.22 + k * 0.26
		_rs(sg, sub(r, x - 0.07, 0.48, x + 0.07, 0.76))
		sg.append_array(PackedVector2Array([_u(r, x, 0.48), _u(r, x, 0.2), _u(r, x, 0.76), _u(r, x, 0.84)]))
	S(ci, sg, 0.5, 1.1)
	var cl := PackedVector2Array()
	for k in 3:
		var x0: float = 0.22 + k * 0.26
		for j in 5:
			var t: float = j / 4.0
			cl.append(_u(r, x0 + 0.03 + t * 0.2, 0.2 + (0.0 if j % 2 == 0 else -0.08)))
			if j < 4:
				cl.append(_u(r, x0 + 0.03 + (j + 1) / 4.0 * 0.2, 0.2 + (0.0 if (j + 1) % 2 == 0 else -0.08)))
	S(ci, cl, 0.6, 1.2)
	var th := sub(r, 0.8, 0.36, 0.92, 0.66)
	R(ci, th, 0.6, 1.2)
	L(ci, _u(r, 0.92, 0.5), _u(r, 1.0, 0.5), 0.45, 1.3)


# ---------------------------------------------------------------- ES-112 / MF-126 / SV-122 / TW-64: charge controller
# a capacitor charging supply, door open: the HV transformer (core and windings), the rectifier
# stack, the charging resistor (its grid), the HV contactor and dump relay box, the voltmeter
# window and two lamps on the door strip
static func charge_supply(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.96))
	_rs(sg, sub(r, 0.08, 0.36, 0.36, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.18, 0.4), _u(r, 0.18, 0.86), _u(r, 0.26, 0.4), _u(r, 0.26, 0.86)]))
	for k in 4:
		var y: float = 0.47 + k * 0.1
		sg.append(_u(r, 0.18, y))
		sg.append(_u(r, 0.26, y))
	_rs(sg, sub(r, 0.42, 0.36, 0.56, 0.9))
	for k in 3:
		var y: float = 0.46 + k * 0.14
		sg.append_array(PackedVector2Array([_u(r, 0.45, y), _u(r, 0.53, y), _u(r, 0.49, y), _u(r, 0.49, y + 0.06)]))
	_rs(sg, sub(r, 0.62, 0.4, 0.92, 0.5))
	for k in 3:
		var x: float = 0.66 + k * 0.09
		sg.append(_u(r, x, 0.4))
		sg.append(_u(r, x + 0.03, 0.5))
	_rs(sg, sub(r, 0.62, 0.58, 0.92, 0.88))
	_rs(sg, sub(r, 0.12, 0.1, 0.3, 0.24))
	sg.append_array(PackedVector2Array([_u(r, 0.21, 0.22), _u(r, 0.26, 0.13), _u(r, 0.36, 0.5), _u(r, 0.42, 0.5), _u(r, 0.56, 0.45), _u(r, 0.62, 0.45)]))
	S(ci, sg, 0.5, 1.1)
	for k in 2:
		_lamp(ci, _u(r, 0.5 + k * 0.1, 0.18), maxf(1.4, ms * 0.035), Pal.tint(Pal.FLUID, 0.85) if k == 0 else Pal.heat(0.8))


# ---------------------------------------------------------------- PS-12: firing capacitor (0.3 m, x4)
# a capacitor discharge unit, tiny: the potted box, the can inside it, the two firing leads
static func cdu_box(ci: CanvasItem, r: Rect2) -> void:
	S(ci, PackedVector2Array([_u(r, 0.1, 0.2), _u(r, 0.9, 0.2), _u(r, 0.1, 0.8), _u(r, 0.9, 0.8), _u(r, 0.1, 0.2), _u(r, 0.1, 0.8), _u(r, 0.9, 0.2), _u(r, 0.9, 0.8),
		_u(r, 0.3, 0.32), _u(r, 0.3, 0.68), _u(r, 0.55, 0.32), _u(r, 0.55, 0.68), _u(r, 0.9, 0.4), _u(r, 1.0, 0.3), _u(r, 0.9, 0.6), _u(r, 1.0, 0.7)]), 0.58, 1.0)


# ---------------------------------------------------------------- PS-12: pyrotechnic (explosive bolt, 0.3 m, x4)
# an explosive bolt, tiny: the hex head, the shank with its weakened groove, the pressure
# cartridge on its end and the initiator's two wires
static func pyro_bolt(ci: CanvasItem, r: Rect2) -> void:
	S(ci, PackedVector2Array([_u(r, 0.04, 0.3), _u(r, 0.04, 0.7), _u(r, 0.18, 0.3), _u(r, 0.18, 0.7), _u(r, 0.04, 0.3), _u(r, 0.18, 0.3), _u(r, 0.04, 0.7), _u(r, 0.18, 0.7),
		_u(r, 0.18, 0.42), _u(r, 0.6, 0.42), _u(r, 0.18, 0.58), _u(r, 0.6, 0.58), _u(r, 0.38, 0.42), _u(r, 0.4, 0.5), _u(r, 0.38, 0.58), _u(r, 0.4, 0.5),
		_u(r, 0.6, 0.34), _u(r, 0.82, 0.34), _u(r, 0.6, 0.66), _u(r, 0.82, 0.66), _u(r, 0.82, 0.34), _u(r, 0.82, 0.66),
		_u(r, 0.82, 0.45), _u(r, 1.0, 0.36), _u(r, 0.82, 0.55), _u(r, 1.0, 0.64)]), 0.6, 1.0)
	E.Rc(ci, sub(r, 0.62, 0.38, 0.8, 0.62), Pal.heat(0.55), 1.0)


# ---------------------------------------------------------------- S-09: arm capacitor pack (0.8 m)
# the arm's capacitor pack: four supercapacitor cells two by two in a clamp frame, the
# balancing board across their tops, the output connector
static func arm_cap_pack(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.2, 0.92, 0.94))
	for c in [Vector2(0.3, 0.4), Vector2(0.7, 0.4), Vector2(0.3, 0.74), Vector2(0.7, 0.74)]:
		var q := sub(r, c.x - 0.14, c.y - 0.13, c.x + 0.14, c.y + 0.13)
		_rs(sg, q)
		sg.append(q.position + Vector2(q.size.x * 0.25, 0))
		sg.append(q.position + Vector2(q.size.x * 0.25, q.size.y))
	_rs(sg, sub(r, 0.14, 0.06, 0.86, 0.16))
	sg.append_array(PackedVector2Array([_u(r, 0.86, 0.11), _u(r, 1.0, 0.11)]))
	S(ci, sg, 0.55, 1.1)
	_lamp(ci, _u(r, 0.22, 0.11), 1.6, Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- ST-40: igniter (capacitor-discharge exciter)
# an ignition exciter and its plug: the exciter box with its finned top, the HT lead in its
# braided sleeve curving out, the igniter plug at its end (body, the electrode tip)
static func ignition_exciter(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.3, 0.56, 0.9))
	for k in 4:
		var x: float = 0.12 + k * 0.12
		sg.append(_u(r, x, 0.3))
		sg.append(_u(r, x, 0.2))
	sg.append_array(PackedVector2Array([_u(r, 0.56, 0.5), _u(r, 0.72, 0.5), _u(r, 0.72, 0.5), _u(r, 0.8, 0.36),
		_u(r, 0.74, 0.08), _u(r, 0.86, 0.08), _u(r, 0.74, 0.36), _u(r, 0.86, 0.36), _u(r, 0.74, 0.08), _u(r, 0.74, 0.36), _u(r, 0.86, 0.08), _u(r, 0.86, 0.36),
		_u(r, 0.8, 0.08), _u(r, 0.8, 0.0)]))
	S(ci, sg, 0.58, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.6, 0.47), _u(r, 0.6, 0.53), _u(r, 0.66, 0.47), _u(r, 0.66, 0.53)]), 0.35)
	E.Rc(ci, sub(r, 0.78, 0.0, 0.82, 0.04), Pal.heat(0.8), 1.0)


# ---------------------------------------------------------------- SV-122: survey probe (x3)
# a penetrator survey probe in its launch rail: the ogive nose and the hardened tip, the body
# with its sensor windows, the tail fins, the tether spool and its line, the rail it sits in
static func survey_probe(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.02), _u(r, 0.34, 0.2), _u(r, 0.5, 0.02), _u(r, 0.66, 0.2),
		_u(r, 0.34, 0.2), _u(r, 0.34, 0.74), _u(r, 0.66, 0.2), _u(r, 0.66, 0.74), _u(r, 0.34, 0.2), _u(r, 0.66, 0.2),
		_u(r, 0.34, 0.74), _u(r, 0.66, 0.74), _u(r, 0.34, 0.62), _u(r, 0.16, 0.86), _u(r, 0.66, 0.62), _u(r, 0.84, 0.86),
		_u(r, 0.16, 0.86), _u(r, 0.34, 0.86), _u(r, 0.84, 0.86), _u(r, 0.66, 0.86), _u(r, 0.5, 0.74), _u(r, 0.5, 0.92)]))
	for y in [0.32, 0.44]:
		_rs(sg, sub(r, 0.42, y, 0.58, y + 0.06))
	S(ci, sg, 0.6, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.38, 0.88), _u(r, 0.62, 0.88), _u(r, 0.38, 0.96), _u(r, 0.62, 0.96), _u(r, 0.5, 0.96), _u(r, 0.5, 1.0),
		_u(r, 0.1, 0.0), _u(r, 0.1, 1.0), _u(r, 0.9, 0.0), _u(r, 0.9, 1.0)]), 0.38, 1.0)
	E.Rc(ci, sub(r, 0.44, 0.33, 0.56, 0.37), Pal.tint(Pal.AIR, 0.7), 1.0)
	E.Rc(ci, sub(r, 0.47, 0.02, 0.53, 0.06), Pal.heat(0.6), 1.0)


# ---------------------------------------------------------------- E07B / TS-1: capacitor module (small board)
# a small capacitor module: the board, three cans standing on it in a row, the terminal strip
static func cap_board(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.1, 0.94, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.2), _u(r, 0.88, 0.2), _u(r, 0.2, 0.72), _u(r, 0.8, 0.72), _u(r, 0.2, 0.84), _u(r, 0.8, 0.84)]))
	for x in [0.12, 0.36, 0.64, 0.88]:
		sg.append(_u(r, x, 0.2))
		sg.append(_u(r, x, 0.62))
	S(ci, sg, 0.55, 1.0)


# ---------------------------------------------------------------- PT-34: weapon capacitor bank (rack)
# the weapons' pulse capacitor rack: drawers of three cylindrical capacitor cans each (sides, the
# rolled top, the terminal post, the strap from the posts to the bus), the heavy double HV bus up
# the back, the triggered spark gap on top (housing, the two rod electrodes and their balls), the
# heavy output cable out of the foot, the charge lamp
static func weapon_cap_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.86, 0.98))
	var n := clampi(int(r.size.y * 0.7 / 20.0), 2, 6)
	var cn := PackedVector2Array()
	for k in n + 1:
		var y: float = 0.28 + k * 0.62 / n
		sg.append(_u(r, 0.06, y))
		sg.append(_u(r, 0.74, y))
	for k in n:
		var y0: float = 0.28 + k * 0.62 / n
		var y1: float = y0 + 0.62 / n
		var yt: float = y0 + 0.62 / n * 0.3
		var yb: float = y1 - 0.62 / n * 0.08
		# three cylindrical cans standing in the drawer: sides, the rolled top, the terminal post
		for x in [0.12, 0.32, 0.52]:
			cn.append_array(PackedVector2Array([_u(r, x, yt), _u(r, x, yb), _u(r, x + 0.16, yt), _u(r, x + 0.16, yb),
				_u(r, x + 0.01, yt - 0.012), _u(r, x + 0.15, yt - 0.012), _u(r, x + 0.08, yt - 0.012), _u(r, x + 0.08, y0 + 0.62 / n * 0.1)]))
		# the drawer's strap from the posts to the bus
		sg.append(_u(r, 0.2, y0 + 0.62 / n * 0.1))
		sg.append(_u(r, 0.8, y0 + 0.62 / n * 0.1))
	S(ci, cn, 0.55, 1.1)
	S(ci, sg, 0.5, 1.1)
	# the heavy HV bus up the back (a pair of bars)
	S(ci, PackedVector2Array([_u(r, 0.79, 0.2), _u(r, 0.79, 0.94), _u(r, 0.83, 0.2), _u(r, 0.83, 0.94)]), 0.62, 2.4)
	# the triggered spark gap at the top: its housing, the two rod electrodes and their balls
	var gh := sub(r, 0.12, 0.05, 0.74, 0.24)
	R(ci, gh, 0.6, 1.4)
	S(ci, PackedVector2Array([_u(r, 0.16, 0.145), _u(r, 0.38, 0.145), _u(r, 0.5, 0.145), _u(r, 0.7, 0.145), _u(r, 0.7, 0.145), _u(r, 0.79, 0.2)]), 0.62, 2.2)
	D(ci, _u(r, 0.4, 0.145), maxf(1.6, ms * 0.05), 0.7)
	D(ci, _u(r, 0.48, 0.145), maxf(1.6, ms * 0.05), 0.7)
	E.Rc(ci, Rect2(_u(r, 0.425, 0.13), Vector2(r.size.x * 0.03, r.size.y * 0.03)), Pal.heat(0.75), 1.0)
	# the heavy output cable out of the foot, its gland
	S(ci, PackedVector2Array([_u(r, 0.81, 0.94), _u(r, 0.81, 1.0), _u(r, 0.76, 0.94), _u(r, 0.86, 0.94)]), 0.62, 3.0)
	_lamp(ci, _u(r, 0.68, 0.26), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- MD-160: power board (the capacitor-art one)
# the drill's DC power board: the DC-link capacitor row along its top, the three IGBT bridge
# legs with their heat-sink fins, the precharge contactor box and its resistor grid, the DC
# busbars, the outgoing feeders and the run lamp (MD-160's p_power_board carries the capacitor art; the
# panelboards elsewhere keep theirs)
static func dc_power_board(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.04, 0.98, 0.96))
	_rs(sg, sub(r, 0.06, 0.12, 0.68, 0.4))
	for k in 5:
		var x: float = 0.06 + (k + 1) * 0.62 / 6.0
		sg.append(_u(r, x, 0.12))
		sg.append(_u(r, x, 0.4))
	sg.append_array(PackedVector2Array([_u(r, 0.05, 0.46), _u(r, 0.95, 0.46), _u(r, 0.05, 0.5), _u(r, 0.95, 0.5)]))
	for k in 3:
		var x0: float = 0.1 + k * 0.18
		_rs(sg, sub(r, x0, 0.56, x0 + 0.12, 0.88))
		sg.append(_u(r, x0 + 0.06, 0.56))
		sg.append(_u(r, x0 + 0.06, 0.88))
		for j in 3:
			var y: float = 0.64 + j * 0.08
			sg.append(_u(r, x0 + 0.01, y))
			sg.append(_u(r, x0 + 0.05, y))
	_rs(sg, sub(r, 0.74, 0.12, 0.94, 0.38))
	for j in 3:
		var x: float = 0.78 + j * 0.055
		sg.append(_u(r, x, 0.16))
		sg.append(_u(r, x + 0.03, 0.34))
	for k in 3:
		var x: float = 0.71 + k * 0.08
		sg.append(_u(r, x, 0.56))
		sg.append(_u(r, x, 0.96))
	S(ci, sg, 0.5, 1.1)
	_lamp(ci, _u(r, 0.79, 0.72), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- CL-104 / FR-26 / HB-86 / SV-122: chiller (scroll)
# a packaged scroll chiller: two scroll compressors standing on the base (their domes), the
# brazed-plate evaporator (chevron plates) and the condenser beside it, the receiver lying
# under, the expansion valve with its bulb, the suction and discharge lines, the chilled-water
# nozzles, the control box with its display
static func scroll_chiller(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.9, 0.98, 0.97))
	for x in [0.1, 0.27]:
		_rs(sg, sub(r, x, 0.42, x + 0.12, 0.9))
		sg.append(_u(r, x, 0.52))
		sg.append(_u(r, x + 0.12, 0.52))
	for x in [0.46, 0.62]:
		var q := sub(r, x, 0.1, x + 0.12, 0.66)
		_rs(sg, q)
		for k in 6:
			var y: float = 0.15 + k * 0.08
			sg.append(_u(r, x + 0.01, y))
			sg.append(_u(r, x + 0.06, y + 0.03))
			sg.append(_u(r, x + 0.06, y + 0.03))
			sg.append(_u(r, x + 0.11, y))
	_rs(sg, sub(r, 0.44, 0.72, 0.76, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.16, 0.42), _u(r, 0.16, 0.3), _u(r, 0.16, 0.3), _u(r, 0.46, 0.3),
		_u(r, 0.33, 0.42), _u(r, 0.33, 0.24), _u(r, 0.33, 0.24), _u(r, 0.62, 0.24),
		_u(r, 0.74, 0.5), _u(r, 0.74, 0.72), _u(r, 0.58, 0.66), _u(r, 0.58, 0.72),
		_u(r, 0.46, 0.16), _u(r, 0.38, 0.16), _u(r, 0.46, 0.58), _u(r, 0.38, 0.58)]))
	S(ci, sg, 0.52, 1.2)
	for x in [0.16, 0.33]:
		A(ci, _u(r, x, 0.42), r.size.x * 0.06, PI, TAU, 0.55, 1.2)
	var cb := sub(r, 0.82, 0.08, 0.97, 0.86)
	R(ci, cb, 0.6, 1.2)
	E.Rc(ci, sub(r, 0.84, 0.14, 0.95, 0.26), Pal.tint(Pal.AIR, 0.55), 1.0)
	_lamp(ci, _u(r, 0.87, 0.34), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_lamp(ci, _u(r, 0.92, 0.34), maxf(1.4, ms * 0.04), Pal.ink(0.35))
	var ev := _u(r, 0.58, 0.69)
	P(ci, PackedVector2Array([ev + Vector2(-3, -2), ev + Vector2(3, 2), ev + Vector2(3, -2), ev + Vector2(-3, 2), ev + Vector2(-3, -2)]), 0.55)
	E.Rc(ci, Rect2(_u(r, 0.36, 0.155), Vector2(r.size.x * 0.03, 1.2)), Pal.tint(Pal.FLUID, 0.6), 1.0)


# ---------------------------------------------------------------- MF-126: heat pump set (4.6 x 5 m)
# a water-to-water heat pump set, big: the centrifugal compressor (its volute) on its motor,
# the flooded evaporator and the condenser shells stacked behind (tube sheets, water boxes),
# the economiser flash tank, the two circulation pumps at the foot with their motors, the
# pipework between, the starter cabinet
static func heat_pump_set(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	for y in [0.42, 0.62]:
		_rs(sg, sub(r, 0.08, y, 0.74, y + 0.16))
		sg.append_array(PackedVector2Array([_u(r, 0.12, y), _u(r, 0.12, y + 0.16), _u(r, 0.7, y), _u(r, 0.7, y + 0.16)]))
		_rs(sg, sub(r, 0.02, y + 0.02, 0.08, y + 0.14))
		_rs(sg, sub(r, 0.74, y + 0.02, 0.8, y + 0.14))
	S(ci, sg, 0.55, 1.3)
	var tb := PackedVector2Array()
	for y in [0.46, 0.5, 0.54, 0.66, 0.7, 0.74]:
		tb.append(_u(r, 0.12, y))
		tb.append(_u(r, 0.7, y))
	S(ci, tb.slice(0, 4), 0.2)
	# compressor: volute and motor on top
	var vc := _u(r, 0.3, 0.24)
	A(ci, vc, ms * 0.12, -PI * 0.2, PI * 1.6, 0.62, 1.5)
	D(ci, vc, maxf(1.4, ms * 0.03), 0.55)
	var mt := sub(r, 0.44, 0.16, 0.68, 0.32)
	R(ci, mt, 0.6, 1.3)
	hatch(ci, mt.grow(-1.5), 3.0, false, 0.3, 10)
	var pp := PackedVector2Array([vc + Vector2(ms * 0.12, -ms * 0.04), _u(r, 0.44, 0.2), _u(r, 0.3, 0.36), _u(r, 0.3, 0.42),
		_u(r, 0.18, 0.12), _u(r, 0.18, 0.42), _u(r, 0.18, 0.12), _u(r, 0.26, 0.12), _u(r, 0.6, 0.58), _u(r, 0.6, 0.62)])
	# flash tank, pumps, starter
	_rs(pp, sub(r, 0.08, 0.04, 0.16, 0.36))
	for x in [0.16, 0.48]:
		var pc := _u(r, x, 0.89)
		pp.append_array(PackedVector2Array([pc + Vector2(-ms * 0.06, ms * 0.06), pc + Vector2(ms * 0.06, ms * 0.06), pc, _u(r, x, 0.78)]))
		_rs(pp, Rect2(pc + Vector2(ms * 0.07, -ms * 0.04), Vector2(ms * 0.14, ms * 0.08)))
	pp.append_array(PackedVector2Array([_u(r, 0.04, 0.96), _u(r, 0.96, 0.96)]))
	_rs(pp, sub(r, 0.82, 0.04, 0.97, 0.94))
	S(ci, pp, 0.52, 1.3)
	for x in [0.16, 0.48]:
		O(ci, _u(r, x, 0.89), ms * 0.05, 0.55, 1.2)
	E.Rc(ci, sub(r, 0.84, 0.1, 0.95, 0.18), Pal.tint(Pal.AIR, 0.55), 1.0)
	for k in 3:
		_lamp(ci, _u(r, 0.86 + k * 0.04, 0.24), maxf(1.4, ms * 0.02), Pal.tint(Pal.FLUID, 0.85) if k != 2 else Pal.heat(0.8))


# ---------------------------------------------------------------- DR-150: choke manifold
# the drilling choke manifold: the inlet cross, the two choke lines (the hydraulic choke with
# its actuator, the manual choke with its handwheel), a gate valve each side of every choke
# (their wheels), the pressure gauge on the cross, the outlet to the buffer tank
static func choke_skid(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.0, 0.5), _u(r, 0.22, 0.5), _u(r, 0.22, 0.24), _u(r, 0.22, 0.76),
		_u(r, 0.22, 0.24), _u(r, 0.9, 0.24), _u(r, 0.22, 0.76), _u(r, 0.9, 0.76), _u(r, 0.9, 0.24), _u(r, 0.9, 0.76), _u(r, 0.9, 0.5), _u(r, 1.0, 0.5)])
	_rs(sg, sub(r, 0.17, 0.42, 0.27, 0.58))
	for y in [0.24, 0.76]:
		for x in [0.36, 0.8]:
			var c := _u(r, x, y)
			sg.append_array(PackedVector2Array([c + Vector2(-ms * 0.05, -ms * 0.04), c + Vector2(ms * 0.05, ms * 0.04), c + Vector2(-ms * 0.05, ms * 0.04), c + Vector2(ms * 0.05, -ms * 0.04),
				c + Vector2(-ms * 0.05, -ms * 0.04), c + Vector2(-ms * 0.05, ms * 0.04), c + Vector2(ms * 0.05, -ms * 0.04), c + Vector2(ms * 0.05, ms * 0.04),
				c, c + Vector2(0, -ms * 0.09), c + Vector2(-ms * 0.04, -ms * 0.09), c + Vector2(ms * 0.04, -ms * 0.09)]))
		_rs(sg, Rect2(_u(r, 0.58, y) - Vector2(ms * 0.08, ms * 0.06), Vector2(ms * 0.16, ms * 0.12)))
	_rs(sg, Rect2(_u(r, 0.58, 0.24) - Vector2(ms * 0.05, ms * 0.2), Vector2(ms * 0.1, ms * 0.14)))
	sg.append_array(PackedVector2Array([_u(r, 0.58, 0.76), _u(r, 0.58, 0.95), _u(r, 0.5, 0.95), _u(r, 0.66, 0.95)]))
	S(ci, sg, 0.58, 1.3)
	E.gauge(ci, _u(r, 0.22, 0.08), maxf(2.5, ms * 0.07), 0.55)
	E.Rc(ci, Rect2(_u(r, 0.58, 0.24) - Vector2(ms * 0.04, ms * 0.17), Vector2(ms * 0.08, ms * 0.03)), Pal.heat(0.7), 1.0)


# ---------------------------------------------------------------- HG-170: cryocooler (two-stage cold head)
# a two-stage Gifford-McMahon cryocooler: the motor and valve housing on top, the first-stage
# cylinder down to its copper flange and the slimmer second stage to the cold tip, the radiation
# shield round the second stage (drawn back), the vacuum can, the two helium flex lines out to the
# compressor with their self-sealing couplings
static func gm_cold_head(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.28, 0.04, 0.72, 0.22))
	_rs(sg, sub(r, 0.2, 0.22, 0.8, 0.27))
	_rs(sg, sub(r, 0.38, 0.27, 0.62, 0.55))
	_rs(sg, sub(r, 0.3, 0.55, 0.7, 0.59))
	_rs(sg, sub(r, 0.45, 0.59, 0.55, 0.86))
	_rs(sg, sub(r, 0.4, 0.86, 0.6, 0.9))
	S(ci, sg, 0.6, 1.3)
	var bk := PackedVector2Array()
	_rs(bk, sub(r, 0.32, 0.6, 0.68, 0.94))
	_rs(bk, sub(r, 0.14, 0.27, 0.86, 0.98))
	S(ci, bk, 0.32, 1.0)
	var fl := PackedVector2Array()
	for k in 4:
		var y: float = 0.08 + k * 0.035
		fl.append(_u(r, 0.32, y))
		fl.append(_u(r, 0.68, y))
	S(ci, fl, 0.35)
	for yy in [0.08, 0.16]:
		P(ci, PackedVector2Array([_u(r, 0.72, yy), _u(r, 0.86, yy), _u(r, 0.92, yy + 0.06), _u(r, 0.98, yy + 0.06)]), 0.55, 1.6)
		R(ci, Rect2(_u(r, 0.84, yy) - Vector2(ms * 0.03, ms * 0.03), Vector2(ms * 0.06, ms * 0.06)), 0.55)
	E.Rc(ci, sub(r, 0.3, 0.552, 0.7, 0.568), Pal.heat(0.55), 1.0)
	E.Rc(ci, sub(r, 0.4, 0.862, 0.6, 0.878), Pal.tint(Pal.AIR, 0.8), 1.0)


# ---------------------------------------------------------------- FR-26: reliquefaction cold box
# the boil-off reliquefaction cold box: the box with its perlite fill (scattered dots), the
# brazed-aluminium plate-fin exchanger block (its fin passes), the turbo-expander with its
# brake, the phase separator, the Joule-Thomson valve, the return line, the box's relief
static func reliq_coldbox(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.96))
	var hx := sub(r, 0.12, 0.1, 0.42, 0.8)
	_rs(sg, hx)
	for k in 7:
		var x: float = 0.15 + k * 0.04
		sg.append(_u(r, x, 0.12))
		sg.append(_u(r, x, 0.78))
	_rs(sg, sub(r, 0.62, 0.56, 0.84, 0.88))
	sg.append_array(PackedVector2Array([_u(r, 0.42, 0.2), _u(r, 0.58, 0.2), _u(r, 0.42, 0.7), _u(r, 0.62, 0.7),
		_u(r, 0.73, 0.56), _u(r, 0.73, 0.4), _u(r, 0.42, 0.45), _u(r, 0.6, 0.45), _u(r, 0.84, 0.82), _u(r, 0.96, 0.82),
		_u(r, 0.27, 0.8), _u(r, 0.27, 0.96), _u(r, 0.9, 0.04), _u(r, 0.9, 0.0)]))
	S(ci, sg, 0.55, 1.2)
	var tc := _u(r, 0.66, 0.22)
	O(ci, tc, ms * 0.08, 0.6, 1.3)
	R(ci, Rect2(tc + Vector2(ms * 0.08, -ms * 0.04), Vector2(ms * 0.14, ms * 0.08)), 0.55)
	var jt := _u(r, 0.6, 0.45)
	P(ci, PackedVector2Array([jt + Vector2(-3, -2), jt + Vector2(3, 2), jt + Vector2(3, -2), jt + Vector2(-3, 2), jt + Vector2(-3, -2)]), 0.55)
	var dots := PackedVector2Array()
	for k in 14:
		var p := _u(r, 0.48 + fmod(k * 0.37, 1.0) * 0.44, 0.08 + fmod(k * 0.61, 1.0) * 0.08 + (0.8 if k % 3 == 0 else 0.0))
		dots.append(p)
		dots.append(p + Vector2(1.2, 0))
	S(ci, dots, 0.35, 1.2)
	E.Rc(ci, sub(r, 0.64, 0.76, 0.82, 0.78), Pal.tint(Pal.AIR, 0.7), 1.0)


# ---------------------------------------------------------------- ARK-01: condenser (steam surface condenser)
# the turbine's surface condenser: the shell, the exhaust neck up to the turbine with its
# expansion joint, the tube bundle between the two tube sheets (support plates across), the
# water boxes at each end with their inlet and outlet, the hotwell under it and the condensate
# outlet, the air-removal line off the top of the bundle
static func surface_condenser(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.14, 0.3, 0.86, 0.78))
	sg.append_array(PackedVector2Array([_u(r, 0.18, 0.3), _u(r, 0.18, 0.78), _u(r, 0.82, 0.3), _u(r, 0.82, 0.78)]))
	_rs(sg, sub(r, 0.04, 0.34, 0.14, 0.74))
	_rs(sg, sub(r, 0.86, 0.34, 0.96, 0.74))
	sg.append_array(PackedVector2Array([_u(r, 0.36, 0.3), _u(r, 0.3, 0.04), _u(r, 0.64, 0.3), _u(r, 0.7, 0.04), _u(r, 0.3, 0.04), _u(r, 0.7, 0.04)]))
	for k in 3:
		var y: float = 0.12 + k * 0.025
		sg.append(_u(r, 0.32 - k * 0.003, y))
		sg.append(_u(r, 0.68 + k * 0.003, y))
	_rs(sg, sub(r, 0.38, 0.78, 0.62, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.9), _u(r, 0.5, 1.0), _u(r, 0.0, 0.42), _u(r, 0.04, 0.42), _u(r, 0.0, 0.66), _u(r, 0.04, 0.66),
		_u(r, 0.96, 0.42), _u(r, 1.0, 0.42), _u(r, 0.96, 0.66), _u(r, 1.0, 0.66), _u(r, 0.5, 0.36), _u(r, 0.5, 0.3), _u(r, 0.5, 0.3), _u(r, 0.86, 0.22), _u(r, 0.86, 0.22), _u(r, 1.0, 0.22)]))
	for x in [0.34, 0.5, 0.66]:
		sg.append(_u(r, x, 0.34))
		sg.append(_u(r, x, 0.74))
	S(ci, sg, 0.55, 1.3)
	var tb := PackedVector2Array()
	for k in 6:
		var y: float = 0.38 + k * 0.06
		tb.append(_u(r, 0.18, y))
		tb.append(_u(r, 0.82, y))
	S(ci, tb, 0.25)
	var wl := PackedVector2Array()
	for k in 2:
		var y: float = 0.82 + k * 0.03
		wl.append(_u(r, 0.4, y))
		wl.append(_u(r, 0.6, y))
	S(ci, wl, 0.3)
	E.Rc(ci, sub(r, 0.4, 0.8, 0.6, 0.81), Pal.tint(Pal.FLUID, 0.6), 1.0)


# ---------------------------------------------------------------- DR-150: vacuum degasser
# the mud vacuum degasser: the vertical vessel, the inclined spreading plates the mud runs down
# in thin sheets, the vacuum pump on its bracket and its gas discharge line, the mud inlet
# with its float valve, the jet (eductor) discharge at the foot, the vacuum gauge
static func vacuum_degasser(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.12, 0.12, 0.62, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.12), _u(r, 0.37, 0.04), _u(r, 0.62, 0.12), _u(r, 0.37, 0.04),
		_u(r, 0.12, 0.86), _u(r, 0.3, 0.94), _u(r, 0.62, 0.86), _u(r, 0.44, 0.94), _u(r, 0.3, 0.94), _u(r, 0.44, 0.94)]))
	for k in 5:
		var y: float = 0.2 + k * 0.12
		if k % 2 == 0:
			sg.append(_u(r, 0.12, y))
			sg.append(_u(r, 0.52, y + 0.06))
		else:
			sg.append(_u(r, 0.62, y))
			sg.append(_u(r, 0.22, y + 0.06))
	_rs(sg, sub(r, 0.66, 0.16, 0.96, 0.32))
	sg.append_array(PackedVector2Array([_u(r, 0.62, 0.2), _u(r, 0.66, 0.2), _u(r, 0.8, 0.16), _u(r, 0.8, 0.0),
		_u(r, 0.0, 0.3), _u(r, 0.12, 0.3), _u(r, 0.37, 0.94), _u(r, 0.37, 1.0), _u(r, 0.37, 0.97), _u(r, 0.9, 0.97), _u(r, 0.66, 0.97), _u(r, 0.72, 0.92), _u(r, 0.72, 0.92), _u(r, 0.78, 0.97)]))
	S(ci, sg, 0.56, 1.2)
	var fl := PackedVector2Array()
	for k in 4:
		var y: float = 0.2 + k * 0.03
		fl.append(_u(r, 0.68, y))
		fl.append(_u(r, 0.94, y))
	S(ci, fl, 0.3)
	E.gauge(ci, _u(r, 0.8, 0.5), maxf(2.5, ms * 0.12), 0.5)
	D(ci, _u(r, 0.18, 0.3), maxf(1.2, ms * 0.04), 0.6)


# ---------------------------------------------------------------- DC-84: dry cooler (x3)
# a V-bank dry cooler: the two finned coils in a V (their fins drawn across), the inlet and
# outlet headers at the top of each coil with their nozzles, the two fans on the deck above
# (rings and blades seen from the side), the legs and the drain
static func vbank_cooler(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	sg.append_array(PackedVector2Array([_u(r, 0.08, 0.26), _u(r, 0.46, 0.82), _u(r, 0.18, 0.26), _u(r, 0.5, 0.74),
		_u(r, 0.92, 0.26), _u(r, 0.54, 0.82), _u(r, 0.82, 0.26), _u(r, 0.5, 0.74), _u(r, 0.46, 0.82), _u(r, 0.54, 0.82),
		_u(r, 0.04, 0.2), _u(r, 0.96, 0.2), _u(r, 0.04, 0.26), _u(r, 0.96, 0.26),
		_u(r, 0.06, 0.26), _u(r, 0.06, 0.98), _u(r, 0.94, 0.26), _u(r, 0.94, 0.98), _u(r, 0.06, 0.9), _u(r, 0.94, 0.9)]))
	S(ci, sg, 0.58, 1.3)
	var fn := PackedVector2Array()
	for k in 6:
		var t: float = (k + 0.5) / 6.0
		var a := _u(r, 0.08, 0.26).lerp(_u(r, 0.46, 0.82), t)
		var b := _u(r, 0.18, 0.26).lerp(_u(r, 0.5, 0.74), t)
		fn.append(a)
		fn.append(b)
		fn.append(Vector2(r.position.x + r.size.x, 0) + Vector2(r.position.x - a.x, a.y))
		fn.append(Vector2(r.position.x + r.size.x, 0) + Vector2(r.position.x - b.x, b.y))
	S(ci, fn, 0.3)
	var fb := PackedVector2Array()
	for x in [0.28, 0.72]:
		fb.append_array(PackedVector2Array([_u(r, x - 0.18, 0.2), _u(r, x - 0.18, 0.1), _u(r, x + 0.18, 0.2), _u(r, x + 0.18, 0.1),
			_u(r, x - 0.18, 0.1), _u(r, x + 0.18, 0.1), _u(r, x - 0.14, 0.15), _u(r, x + 0.14, 0.15), _u(r, x, 0.1), _u(r, x, 0.2)]))
	fb.append_array(PackedVector2Array([_u(r, 0.1, 0.24), _u(r, 0.02, 0.24), _u(r, 0.9, 0.24), _u(r, 0.98, 0.24), _u(r, 0.5, 0.82), _u(r, 0.5, 0.9)]))
	S(ci, fb, 0.5, 1.2)
	E.Rc(ci, sub(r, 0.02, 0.235, 0.06, 0.25), Pal.tint(Pal.FLUID, 0.7), 1.0)


# ---------------------------------------------------------------- ARK-01: duct fan (x12, lean)
# an inline axial duct fan seen from the side: the duct between its inlet and outlet flanges, the
# impeller (the hub's nose cone, its swept blades out to the casing), the motor behind it on its
# strut (cooling fins), the guide vanes after it, the terminal box on the casing, the two
# anti-vibration mounts, the airflow arrow at the inlet
static func inline_fan(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.1, 0.2), _u(r, 0.9, 0.2), _u(r, 0.1, 0.8), _u(r, 0.9, 0.8),
		_u(r, 0.04, 0.08), _u(r, 0.04, 0.92), _u(r, 0.96, 0.08), _u(r, 0.96, 0.92), _u(r, 0.04, 0.2), _u(r, 0.1, 0.2), _u(r, 0.04, 0.8), _u(r, 0.1, 0.8),
		_u(r, 0.96, 0.2), _u(r, 0.9, 0.2), _u(r, 0.96, 0.8), _u(r, 0.9, 0.8),
		_u(r, 0.52, 0.38), _u(r, 0.8, 0.38), _u(r, 0.52, 0.62), _u(r, 0.8, 0.62), _u(r, 0.8, 0.38), _u(r, 0.8, 0.62),
		_u(r, 0.36, 0.42), _u(r, 0.26, 0.5), _u(r, 0.36, 0.58), _u(r, 0.26, 0.5), _u(r, 0.36, 0.38), _u(r, 0.36, 0.62), _u(r, 0.36, 0.38), _u(r, 0.52, 0.38), _u(r, 0.36, 0.62), _u(r, 0.52, 0.62),
		_u(r, 0.66, 0.38), _u(r, 0.66, 0.2), _u(r, 0.66, 0.62), _u(r, 0.66, 0.8),
		_u(r, 0.56, 0.2), _u(r, 0.56, 0.06), _u(r, 0.72, 0.2), _u(r, 0.72, 0.06), _u(r, 0.56, 0.06), _u(r, 0.72, 0.06),
		_u(r, 0.22, 0.8), _u(r, 0.22, 0.97), _u(r, 0.78, 0.8), _u(r, 0.78, 0.97), _u(r, 0.16, 0.97), _u(r, 0.84, 0.97)])
	S(ci, sg, 0.6, 1.3)
	# the blade row on the hub (blades swept, seen edge-on as slanted strokes), the motor fins,
	# the guide vanes behind, the airflow arrow through the inlet
	var bl := PackedVector2Array()
	for k in 4:
		var x: float = 0.36 + k * 0.03
		bl.append(_u(r, x, 0.4))
		bl.append(_u(r, x + 0.05, 0.22))
		bl.append(_u(r, x, 0.6))
		bl.append(_u(r, x + 0.05, 0.78))
	S(ci, bl, 0.55, 1.4)
	var fv := PackedVector2Array()
	for k in 3:
		var x: float = 0.58 + k * 0.08
		fv.append(_u(r, x, 0.4))
		fv.append(_u(r, x, 0.6))
	for sgn in [-1.0, 1.0]:
		fv.append(_u(r, 0.82, 0.5 + sgn * 0.14))
		fv.append(_u(r, 0.88, 0.5 + sgn * 0.26))
	fv.append_array(PackedVector2Array([_u(r, 0.12, 0.5), _u(r, 0.22, 0.5), _u(r, 0.22, 0.5), _u(r, 0.18, 0.46), _u(r, 0.22, 0.5), _u(r, 0.18, 0.54)]))
	S(ci, fv, 0.38, 1.0)


# ---------------------------------------------------------------- RO-128: vehicle deck exhaust fan
# the vehicle deck's centrifugal exhaust fan: the scroll housing and its inlet cone, the wheel
# inside (blades round it), the belt drive over to the motor on its slide base (the belt guard
# drawn as a line), the outlet with its backdraft damper blades, the flexible connector
static func deck_exhaust_fan(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var c := _u(r, 0.3, 0.56)
	var rad: float = ms * 0.36
	var sc := PackedVector2Array()
	for k in 15:
		var a: float = -PI * 0.5 + k / 14.0 * PI * 1.6
		sc.append(c + Vector2.from_angle(a) * rad * (0.8 + 0.25 * k / 14.0))
	P(ci, sc, 0.62, 1.5)
	var sg := PackedVector2Array([sc[0], sc[0] + Vector2(rad * 1.0, 0), sc[14], Vector2(sc[0].x + rad * 1.0, sc[14].y), sc[0] + Vector2(rad * 1.0, 0), Vector2(sc[0].x + rad * 1.0, sc[14].y)])
	for k in 10:
		var a: float = TAU * k / 10.0
		sg.append(c + Vector2.from_angle(a) * rad * 0.3)
		sg.append(c + Vector2.from_angle(a + 0.4) * rad * 0.6)
	S(ci, sg, 0.5, 1.1)
	D(ci, c, maxf(1.4, rad * 0.12), 0.55)
	var ot := Rect2(Vector2(sc[0].x + rad * 0.2, r.position.y + r.size.y * 0.02), Vector2(rad * 0.8, sc[0].y - r.position.y - r.size.y * 0.02))
	var ob := PackedVector2Array()
	_rs(ob, ot)
	for k in 3:
		var y: float = ot.position.y + ot.size.y * (0.25 + k * 0.25)
		ob.append(Vector2(ot.position.x, y))
		ob.append(Vector2(ot.end.x, y - ot.size.y * 0.1))
	var mt := sub(r, 0.72, 0.5, 0.96, 0.82)
	_rs(ob, mt)
	ob.append_array(PackedVector2Array([_u(r, 0.68, 0.88), _u(r, 0.98, 0.88), c + Vector2(0, -rad * 0.1), _u(r, 0.84, 0.6), c + Vector2(0, rad * 0.1), _u(r, 0.84, 0.72),
		_u(r, 0.02, 0.4), _u(r, 0.06, 0.4), _u(r, 0.02, 0.72), _u(r, 0.06, 0.72), _u(r, 0.06, 0.4), _u(r, 0.06, 0.72)]))
	S(ci, ob, 0.52, 1.2)
	hatch(ci, mt.grow(-1.5), 3.0, false, 0.3, 8)


# ================================================================ E311–E345 (2026-11-12): ninth batch, part one
# the gas bottles and tanks: each by what it really is — single bottles (chained, strapped, on a
# trolley, a jumbo tube), bottle banks (bundle frames, manifolds and regulators), upright and lying
# vessels, cryogenic tanks (the vacuum jacket, the vaporiser), accumulators (piston, bladder),
# the expansion tank's diaphragm, the lube box's breather and level glass, the composite tanks'
# windings; the gas told by a theme-colour band (O2 AIR, N2/He/Xe VOLT, fuel HEAT, liquid FLUID)

# an elliptical arc as segments, appended to a batch
static func _arcs(sg: PackedVector2Array, c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> void:
	var pv := c + Vector2(cos(a0) * rx, sin(a0) * ry)
	for k in range(1, n + 1):
		var a: float = lerpf(a0, a1, float(k) / n)
		var q := c + Vector2(cos(a) * rx, sin(a) * ry)
		sg.append(pv)
		sg.append(q)
		pv = q


# an upright pressure vessel: the shell and its two dished heads (hd: the heads' depth, px)
static func _vves(sg: PackedVector2Array, q: Rect2, hd: float, n: int = 4) -> void:
	hd = minf(hd, q.size.y * 0.5)
	var cx := q.get_center().x
	var y0 := q.position.y + hd
	var y1 := q.end.y - hd
	sg.append_array(PackedVector2Array([Vector2(q.position.x, y0), Vector2(q.position.x, y1), Vector2(q.end.x, y0), Vector2(q.end.x, y1)]))
	_arcs(sg, Vector2(cx, y0), q.size.x * 0.5, hd, PI, TAU, n)
	_arcs(sg, Vector2(cx, y1), q.size.x * 0.5, hd, 0.0, PI, n)


# the same lying down (its heads at the two ends)
static func _hves(sg: PackedVector2Array, q: Rect2, hd: float, n: int = 5) -> void:
	hd = minf(hd, q.size.x * 0.5)
	var cy := q.get_center().y
	var x0 := q.position.x + hd
	var x1 := q.end.x - hd
	sg.append_array(PackedVector2Array([Vector2(x0, q.position.y), Vector2(x1, q.position.y), Vector2(x0, q.end.y), Vector2(x1, q.end.y)]))
	_arcs(sg, Vector2(x0, cy), hd, q.size.y * 0.5, PI * 0.5, PI * 1.5, n)
	_arcs(sg, Vector2(x1, cy), hd, q.size.y * 0.5, -PI * 0.5, PI * 0.5, n)


# an upright gas cylinder (q from the neck's top to the foot): the body on its slightly rounded
# foot, the domed shoulder, the neck and its collar
static func _vbot(sg: PackedVector2Array, q: Rect2) -> void:
	var w := q.size.x
	var nh := minf(w * 0.28, q.size.y * 0.08)
	var dh := minf(w * 0.4, q.size.y * 0.2)
	var x0 := q.position.x
	var x1 := q.end.x
	var cx := q.get_center().x
	var yt := q.position.y
	var ys := yt + nh + dh
	var yb := q.end.y
	var c := minf(w * 0.08, 3.0)
	sg.append_array(PackedVector2Array([Vector2(x0, ys), Vector2(x0, yb - c), Vector2(x1, ys), Vector2(x1, yb - c),
		Vector2(x0, yb - c), Vector2(x0 + c, yb), Vector2(x0 + c, yb), Vector2(x1 - c, yb), Vector2(x1 - c, yb), Vector2(x1, yb - c),
		Vector2(cx - w * 0.14, yt), Vector2(cx - w * 0.14, yt + nh + dh * 0.06), Vector2(cx + w * 0.14, yt), Vector2(cx + w * 0.14, yt + nh + dh * 0.06),
		Vector2(cx - w * 0.18, yt), Vector2(cx + w * 0.18, yt)]))
	_arcs(sg, Vector2(cx, ys), w * 0.5, dh, PI, TAU, 4)


# the gas's colour band across a body
static func _gband(ci: CanvasItem, r: Rect2, x0: float, x1: float, y: float, col: Color) -> void:
	E.Rc(ci, Rect2(_u(r, x0, y), Vector2(r.size.x * (x1 - x0), maxf(1.2, r.size.y * 0.012))), col, 1.0)


# the largest rect of aspect asp (w/h) inside r, standing on r's floor, centred
static func _fitr(r: Rect2, asp: float) -> Rect2:
	var w := minf(r.size.x, r.size.y * asp)
	var h := w / asp
	return Rect2(Vector2(r.get_center().x - w * 0.5, r.end.y - h), Vector2(w, h))


# ---------------------------------------------------------------- TW-64 / H-22 / MF-126 / RO-128: piston accumulator
# a piston accumulator: the barrel between its two bolted end caps (their studs), the piston and its
# two seal lands part way down, the gas charging valve and its cap on top, the oil port at the foot
# and its line out, the two clamp bands to the wall
static func piston_accumulator(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.22, 0.1, 0.78, 0.9))
	_rs(sg, sub(r, 0.16, 0.05, 0.84, 0.1))
	_rs(sg, sub(r, 0.16, 0.9, 0.84, 0.95))
	sg.append_array(PackedVector2Array([_u(r, 0.22, 0.42), _u(r, 0.78, 0.42), _u(r, 0.22, 0.47), _u(r, 0.78, 0.47),
		_u(r, 0.5, 0.05), _u(r, 0.5, 0.03), _u(r, 0.46, 0.95), _u(r, 0.46, 0.985), _u(r, 0.54, 0.95), _u(r, 0.54, 0.985), _u(r, 0.4, 0.985), _u(r, 0.6, 0.985)]))
	_rs(sg, sub(r, 0.42, 0.0, 0.58, 0.03))
	for y in [0.26, 0.7]:
		_rs(sg, sub(r, 0.18, y, 0.82, y + 0.03))
		sg.append_array(PackedVector2Array([_u(r, 0.06, y + 0.015), _u(r, 0.18, y + 0.015), _u(r, 0.06, y - 0.02), _u(r, 0.06, y + 0.05)]))
	_fillc(ci, PackedVector2Array([_u(r, 0.22, 0.42), _u(r, 0.78, 0.42), _u(r, 0.78, 0.47), _u(r, 0.22, 0.47)]), Pal.ink(0.32))
	_fillc(ci, PackedVector2Array([_u(r, 0.23, 0.11), _u(r, 0.77, 0.11), _u(r, 0.77, 0.415), _u(r, 0.23, 0.415)]), Color(Pal.VOLT.r, Pal.VOLT.g, Pal.VOLT.b, 0.1))
	S(ci, sg, 0.56, 1.2)
	L(ci, _u(r, 0.6, 0.97), _u(r, 0.98, 0.97), 0.5, 1.6)


# ---------------------------------------------------------------- DR-150: BOP bladder accumulator
# a bladder accumulator bottle in its rack: the forged shell (round at both ends), the bladder inside
# hanging from the gas valve, the valve's guard on top, the poppet valve's port at the foot and the
# line to the BOP, the rack's upright and its two straps
static func bladder_accumulator(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.22, 0.06, 0.82, 0.9), w * 0.3)
	S(ci, sg, 0.58, 1.2)
	var bl := PackedVector2Array()
	_vves(bl, sub(r, 0.32, 0.1, 0.72, 0.66), w * 0.2, 4)
	S(ci, bl, 0.34, 1.0)
	var fr := PackedVector2Array([_u(r, 0.08, 0.0), _u(r, 0.08, 1.0), _u(r, 0.52, 0.06), _u(r, 0.52, 0.02), _u(r, 0.42, 0.02), _u(r, 0.62, 0.02),
		_u(r, 0.42, 0.0), _u(r, 0.42, 0.02), _u(r, 0.62, 0.0), _u(r, 0.62, 0.02), _u(r, 0.52, 0.9), _u(r, 0.52, 0.95)])
	for y in [0.3, 0.7]:
		_rs(fr, sub(r, 0.08, y, 0.9, y + 0.035))
	_rs(fr, sub(r, 0.44, 0.95, 0.6, 0.985))
	S(ci, fr, 0.5, 1.1)
	L(ci, _u(r, 0.6, 0.97), _u(r, 1.0, 0.97), 0.5, 1.6)
	_gband(ci, r, 0.44, 0.6, 0.03, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- CV-138: lift accumulator bank (6 x 16.6 m)
# the lift's accumulator bank in its frame: two big piston accumulators, the nitrogen back-up bottles
# (two columns of two), the gas header over them all, the cross braces of the lower bay, the oil
# manifold block there with its two gauges and the lines out, the ready lamp
static func lift_accu_bank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.02, 0.98, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.64), _u(r, 0.98, 0.64), _u(r, 0.5, 0.02), _u(r, 0.5, 0.64),
		_u(r, 0.02, 0.98), _u(r, 0.3, 0.74), _u(r, 0.98, 0.98), _u(r, 0.7, 0.74)]))
	for x0 in [0.07, 0.28]:
		_rs(sg, sub(r, x0 + 0.02, 0.08, x0 + 0.16, 0.58))
		_rs(sg, sub(r, x0, 0.06, x0 + 0.18, 0.08))
		_rs(sg, sub(r, x0, 0.58, x0 + 0.18, 0.6))
		sg.append_array(PackedVector2Array([_u(r, x0 + 0.02, 0.3), _u(r, x0 + 0.16, 0.3), _u(r, x0 + 0.02, 0.312), _u(r, x0 + 0.16, 0.312)]))
	for cx in [0.55, 0.77]:
		_vbot(sg, sub(r, cx, 0.07, cx + 0.16, 0.33))
		_vbot(sg, sub(r, cx, 0.36, cx + 0.16, 0.62))
	S(ci, sg, 0.55, 1.3)
	var hd := PackedVector2Array([_u(r, 0.16, 0.045), _u(r, 0.85, 0.045), _u(r, 0.16, 0.045), _u(r, 0.16, 0.06), _u(r, 0.37, 0.045), _u(r, 0.37, 0.06),
		_u(r, 0.63, 0.045), _u(r, 0.63, 0.07), _u(r, 0.85, 0.045), _u(r, 0.85, 0.07), _u(r, 0.63, 0.33), _u(r, 0.63, 0.36), _u(r, 0.85, 0.33), _u(r, 0.85, 0.36),
		_u(r, 0.16, 0.6), _u(r, 0.16, 0.8), _u(r, 0.16, 0.8), _u(r, 0.3, 0.8), _u(r, 0.37, 0.6), _u(r, 0.37, 0.74),
		_u(r, 0.7, 0.8), _u(r, 0.98, 0.8), _u(r, 0.5, 0.86), _u(r, 0.5, 0.98)])
	_rs(hd, sub(r, 0.3, 0.74, 0.7, 0.86))
	S(ci, hd, 0.5, 2.0)
	for x in [0.42, 0.58]:
		D(ci, _u(r, x, 0.8), maxf(2.0, ms * 0.035), 0.6)
	_gband(ci, r, 0.55, 0.93, 0.15, Pal.tint(Pal.VOLT, 0.7))
	_gband(ci, r, 0.31, 0.69, 0.83, Pal.tint(Pal.FLUID, 0.7))
	_lamp(ci, _u(r, 0.9, 0.7), maxf(2.0, ms * 0.03), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- MF-126: argon bundles (two stacked)
# two argon cylinder bundles stacked: each one's frame (posts, rails, the two lifting eyes), the front
# row of three cylinders, the bundle manifold over their valves and its outlet valve
static func argon_bundle(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	var mf := PackedVector2Array()
	for b in 2:
		var y0: float = 0.02 + b * 0.5
		_rs(sg, sub(r, 0.04, y0 + 0.06, 0.96, y0 + 0.47))
		sg.append_array(PackedVector2Array([_u(r, 0.04, y0 + 0.3), _u(r, 0.96, y0 + 0.3),
			_u(r, 0.2, y0 + 0.06), _u(r, 0.24, y0 + 0.01), _u(r, 0.24, y0 + 0.01), _u(r, 0.28, y0 + 0.06),
			_u(r, 0.72, y0 + 0.06), _u(r, 0.76, y0 + 0.01), _u(r, 0.76, y0 + 0.01), _u(r, 0.8, y0 + 0.06)]))
		for k in 3:
			var x0: float = 0.1 + k * 0.28
			_vbot(sg, sub(r, x0, y0 + 0.14, x0 + 0.22, y0 + 0.46))
			mf.append(_u(r, x0 + 0.11, y0 + 0.11))
			mf.append(_u(r, x0 + 0.11, y0 + 0.14))
		mf.append_array(PackedVector2Array([_u(r, 0.21, y0 + 0.11), _u(r, 0.92, y0 + 0.11), _u(r, 0.92, y0 + 0.11), _u(r, 0.92, y0 + 0.2),
			_u(r, 0.88, y0 + 0.16), _u(r, 0.96, y0 + 0.16)]))
	S(ci, sg, 0.55, 1.2)
	S(ci, mf, 0.5, 1.5)
	for b in 2:
		_gband(ci, r, 0.05, 0.95, 0.02 + b * 0.5 + 0.08, Pal.tint(Pal.VOLT, 0.7))


# ---------------------------------------------------------------- ARK-01: nitrogen bottle trolley
# a nitrogen cylinder on its two-wheel trolley: the cylinder, the trolley's back frame up to the
# handle loop, the toe plate, the wheel and its axle, the chain round the cylinder, the regulator and
# its gauge on the valve
static func n2_cart(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vbot(sg, sub(r, 0.2, 0.1, 0.62, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.7, 0.9), _u(r, 0.7, 0.08), _u(r, 0.7, 0.08), _u(r, 0.86, 0.02), _u(r, 0.86, 0.02), _u(r, 0.96, 0.08),
		_u(r, 0.12, 0.88), _u(r, 0.76, 0.88), _u(r, 0.12, 0.88), _u(r, 0.12, 0.84),
		_u(r, 0.62, 0.3), _u(r, 0.7, 0.3), _u(r, 0.62, 0.64), _u(r, 0.7, 0.64)]))
	S(ci, sg, 0.56, 1.2)
	var ch := PackedVector2Array([_u(r, 0.41, 0.1), _u(r, 0.41, 0.05), _u(r, 0.41, 0.06), _u(r, 0.54, 0.06)])
	for k in 5:
		var x: float = 0.2 + k * 0.1
		ch.append(_u(r, x, 0.36))
		ch.append(_u(r, x + 0.06, 0.36))
	S(ci, ch, 0.45, 1.3)
	D(ci, _u(r, 0.57, 0.06), maxf(1.4, ms * 0.08), 0.6)
	O(ci, _u(r, 0.7, 0.9), ms * 0.14, 0.6, 1.3)
	D(ci, _u(r, 0.7, 0.9), maxf(1.0, ms * 0.04), 0.6)
	_gband(ci, r, 0.21, 0.61, 0.22, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- ARK-01: nitrogen receiver on legs
# an upright nitrogen receiver on its three legs: the shell and its two girth seams, the inlet and
# outlet nozzles with their flanges, the drain at the foot, the relief valve and its vent tee on the
# top head, the pressure gauge on its siphon
static func n2_vessel(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.18, 0.1, 0.82, 0.82), w * 0.16)
	sg.append_array(PackedVector2Array([_u(r, 0.18, 0.36), _u(r, 0.82, 0.36), _u(r, 0.18, 0.6), _u(r, 0.82, 0.6),
		_u(r, 0.22, 0.76), _u(r, 0.12, 0.98), _u(r, 0.78, 0.76), _u(r, 0.88, 0.98), _u(r, 0.5, 0.82), _u(r, 0.5, 0.98),
		_u(r, 0.06, 0.98), _u(r, 0.18, 0.98), _u(r, 0.82, 0.98), _u(r, 0.94, 0.98),
		_u(r, 0.18, 0.28), _u(r, 0.02, 0.28), _u(r, 0.06, 0.24), _u(r, 0.06, 0.32),
		_u(r, 0.82, 0.68), _u(r, 0.98, 0.68), _u(r, 0.94, 0.64), _u(r, 0.94, 0.72),
		_u(r, 0.38, 0.1), _u(r, 0.38, 0.02), _u(r, 0.3, 0.02), _u(r, 0.46, 0.02), _u(r, 0.62, 0.11), _u(r, 0.62, 0.08)]))
	_rs(sg, sub(r, 0.34, 0.05, 0.42, 0.08))
	S(ci, sg, 0.56, 1.2)
	O(ci, _u(r, 0.62, 0.05), ms * 0.06, 0.55)
	_gband(ci, r, 0.18, 0.82, 0.2, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- ARK-01: oxygen storage vessel
# the ship's oxygen vessel hung in its ring girder: the shell and its deep heads, the girder round its
# middle and the two trunnion arms out to the wall plates, the burst-disc holder on the top head and
# its vent's gooseneck, the valve station under it (the regulator box and its two gauges, the line out)
static func o2_vessel(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.2, 0.08, 0.8, 0.72), w * 0.24)
	_rs(sg, sub(r, 0.16, 0.38, 0.84, 0.43))
	sg.append_array(PackedVector2Array([_u(r, 0.16, 0.405), _u(r, 0.04, 0.405), _u(r, 0.84, 0.405), _u(r, 0.96, 0.405),
		_u(r, 0.04, 0.34), _u(r, 0.04, 0.47), _u(r, 0.96, 0.34), _u(r, 0.96, 0.47),
		_u(r, 0.5, 0.72), _u(r, 0.5, 0.8), _u(r, 0.7, 0.87), _u(r, 1.0, 0.87), _u(r, 0.5, 0.94), _u(r, 0.5, 1.0),
		_u(r, 0.5, 0.08), _u(r, 0.5, 0.0), _u(r, 0.44, 0.035), _u(r, 0.56, 0.035), _u(r, 0.5, 0.005), _u(r, 0.68, 0.005), _u(r, 0.68, 0.005), _u(r, 0.68, 0.04)]))
	_rs(sg, sub(r, 0.3, 0.8, 0.7, 0.94))
	S(ci, sg, 0.56, 1.2)
	for x in [0.4, 0.6]:
		D(ci, _u(r, x, 0.87), maxf(1.4, ms * 0.05), 0.6)
	_gband(ci, r, 0.2, 0.8, 0.2, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- AX-40: helium buffer (composite overwrapped)
# a composite-overwrapped helium buffer: the liner's shape, the helical windings crossing over its
# cylinder, the metal bosses at both poles, the two relief valves on the top boss, the backing rail
# and its two clamp bands
static func copv_buffer(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	var q := sub(r, 0.24, 0.07, 0.84, 0.93)
	var hd: float = q.size.x * 0.4
	_vves(sg, q, hd)
	_rs(sg, sub(r, 0.47, 0.03, 0.61, 0.07))
	_rs(sg, sub(r, 0.47, 0.93, 0.61, 0.97))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.03), _u(r, 0.42, 0.0), _u(r, 0.58, 0.03), _u(r, 0.66, 0.0), _u(r, 0.54, 0.97), _u(r, 0.54, 1.0),
		_u(r, 0.08, 0.02), _u(r, 0.08, 0.98)]))
	for y in [0.3, 0.7]:
		_rs(sg, sub(r, 0.08, y, 0.88, y + 0.03))
	S(ci, sg, 0.56, 1.2)
	var y0: float = q.position.y + hd
	var y1: float = q.end.y - hd
	var dy: float = q.size.x * 0.6
	var hw := PackedVector2Array()
	var n := clampi(int((y1 - y0 - dy) / 9.0), 2, 6)
	for k in n + 1:
		var y: float = lerpf(y0, y1 - dy, float(k) / n)
		hw.append_array(PackedVector2Array([Vector2(q.position.x, y), Vector2(q.end.x, y + dy), Vector2(q.end.x, y), Vector2(q.position.x, y + dy)]))
	S(ci, hw, 0.28, 1.0)
	_gband(ci, r, 0.47, 0.61, 0.95, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- AX-40: xenon propellant tank
# the ion drive's xenon tank: the titanium tank, the heater blanket round it (its edges, the lacing,
# the heater traces), the outlet down to the pressure-management train: two solenoid valves in
# series, the plenum, the filter, the feed out
static func xenon_tank(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.14, 0.02, 0.86, 0.72), w * 0.3)
	_rs(sg, sub(r, 0.12, 0.26, 0.88, 0.5))
	for k in 4:
		var x: float = 0.16 + k * 0.18
		sg.append(_u(r, x, 0.26))
		sg.append(_u(r, x + 0.09, 0.5))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.72), _u(r, 0.5, 0.76), _u(r, 0.5, 0.76), _u(r, 0.22, 0.76), _u(r, 0.22, 0.76), _u(r, 0.22, 0.8),
		_u(r, 0.3, 0.84), _u(r, 0.36, 0.84), _u(r, 0.52, 0.84), _u(r, 0.58, 0.84), _u(r, 0.84, 0.84), _u(r, 0.88, 0.84), _u(r, 0.92, 0.88), _u(r, 0.92, 1.0)]))
	_rs(sg, sub(r, 0.14, 0.8, 0.3, 0.88))
	_rs(sg, sub(r, 0.36, 0.8, 0.52, 0.88))
	_hves(sg, sub(r, 0.58, 0.79, 0.84, 0.89), w * 0.05, 3)
	S(ci, sg, 0.55, 1.1)
	for y in [0.34, 0.42]:
		_gband(ci, r, 0.14, 0.86, y, Pal.heat(0.55))
	_gband(ci, r, 0.2, 0.8, 0.12, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- FL-116: breathing-air bank and fill station
# the breathing-air store and fill station: four storage cylinders in their rack (its foot, strap and
# top rail), each valve piped up to the fill panel (its two gauges and fill valves), the fill whip
# hung in its loop, the fill cabinet at the side (its door, window and a set's cylinder inside)
static func ba_fill_bank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	for k in 4:
		var x0: float = 0.04 + k * 0.155
		_vbot(sg, sub(r, x0, 0.44, x0 + 0.13, 0.97))
		sg.append(_u(r, x0 + 0.065, 0.44))
		sg.append(_u(r, x0 + 0.065, 0.4))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.98), _u(r, 0.66, 0.98), _u(r, 0.02, 0.64), _u(r, 0.66, 0.64), _u(r, 0.02, 0.4), _u(r, 0.66, 0.4),
		_u(r, 0.35, 0.32), _u(r, 0.35, 0.4), _u(r, 0.14, 0.25), _u(r, 0.26, 0.25), _u(r, 0.44, 0.25), _u(r, 0.56, 0.25),
		_u(r, 0.92, 0.7), _u(r, 0.92, 0.78)]))
	_rs(sg, sub(r, 0.04, 0.04, 0.66, 0.32))
	_rs(sg, sub(r, 0.72, 0.36, 0.98, 0.98))
	S(ci, sg, 0.55, 1.2)
	for x in [0.2, 0.5]:
		D(ci, _u(r, x, 0.13), maxf(1.6, ms * 0.06), 0.6)
	A(ci, _u(r, 0.66, 0.2), ms * 0.1, -PI * 0.5, PI * 0.5, 0.45, 1.5)
	_gband(ci, r, 0.03, 0.65, 0.52, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- BL-88: oxygen store and dryer
# the electrolyser's oxygen store: the tank, the desiccant dryer column beside it (its two end caps,
# the bed inside), the line in from the electrolyser over its top, the dried gas down and into the
# tank's foot through the check valve, the outlet valve on top
static func o2_dryer_store(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.06, 0.1, 0.58, 0.96), w * 0.18)
	_rs(sg, sub(r, 0.7, 0.24, 0.9, 0.84))
	sg.append_array(PackedVector2Array([_u(r, 0.67, 0.24), _u(r, 0.93, 0.24), _u(r, 0.67, 0.84), _u(r, 0.93, 0.84),
		_u(r, 1.0, 0.14), _u(r, 0.8, 0.14), _u(r, 0.8, 0.14), _u(r, 0.8, 0.24), _u(r, 0.8, 0.84), _u(r, 0.8, 0.92), _u(r, 0.8, 0.92), _u(r, 0.58, 0.92),
		_u(r, 0.64, 0.89), _u(r, 0.72, 0.95), _u(r, 0.32, 0.1), _u(r, 0.32, 0.02), _u(r, 0.22, 0.02), _u(r, 0.42, 0.02), _u(r, 0.32, 0.05), _u(r, 0.6, 0.05)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.7, 0.4), _u(r, 0.9, 0.4), _u(r, 0.7, 0.68), _u(r, 0.9, 0.68)]), 0.3, 1.0)
	_gband(ci, r, 0.07, 0.57, 0.24, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- M-14: tank-mounted air compressor
# a tank-mounted air compressor: the receiver, the deck plate on it, the compressor's crankcase and
# its finned cylinder, the motor (its fins), the belt guard between them, the discharge pipe round
# and into the receiver, the safety valve, the pressure gauge and the pressure switch (its lamp), the
# drain at the foot, the two feet
static func air_compressor_tank(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.14, 0.42, 0.86, 0.94), w * 0.16)
	_rs(sg, sub(r, 0.06, 0.36, 0.94, 0.4))
	_rs(sg, sub(r, 0.1, 0.24, 0.44, 0.36))
	_rs(sg, sub(r, 0.16, 0.06, 0.38, 0.24))
	for k in 5:
		var y: float = 0.08 + k * 0.035
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.42, y))
	_rs(sg, sub(r, 0.56, 0.18, 0.9, 0.36))
	for k in 3:
		var x: float = 0.62 + k * 0.09
		sg.append(_u(r, x, 0.18))
		sg.append(_u(r, x, 0.36))
	sg.append_array(PackedVector2Array([_u(r, 0.44, 0.26), _u(r, 0.56, 0.22), _u(r, 0.44, 0.34), _u(r, 0.56, 0.32),
		_u(r, 0.27, 0.06), _u(r, 0.27, 0.02), _u(r, 0.27, 0.02), _u(r, 0.04, 0.02), _u(r, 0.04, 0.02), _u(r, 0.04, 0.5), _u(r, 0.04, 0.5), _u(r, 0.14, 0.5),
		_u(r, 0.86, 0.56), _u(r, 0.96, 0.56), _u(r, 0.96, 0.52), _u(r, 0.96, 0.6),
		_u(r, 0.5, 0.94), _u(r, 0.5, 0.99), _u(r, 0.44, 0.99), _u(r, 0.56, 0.99),
		_u(r, 0.2, 0.9), _u(r, 0.16, 1.0), _u(r, 0.8, 0.9), _u(r, 0.84, 1.0)]))
	_rs(sg, sub(r, 0.6, 0.72, 0.8, 0.8))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.36, 0.62), ms * 0.08, 0.55)
	_lamp(ci, _u(r, 0.7, 0.76), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.15, 0.85, 0.5, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- CH-110 / MF-126: coolant tank
# the coolant tank: lying on two saddles where there's room (else standing on its legs), the manway,
# the vent's gooseneck, the level glass on its two cocks, the suction line out, the coolant's level
static func coolant_tank(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	if r.size.x > r.size.y * 1.3:
		var q := sub(r, 0.04, 0.12, 0.84, 0.78)
		_hves(sg, q, q.size.y * 0.3)
		for x in [0.22, 0.6]:
			sg.append_array(PackedVector2Array([_u(r, x, 0.76), _u(r, x - 0.04, 0.96), _u(r, x + 0.08, 0.76), _u(r, x + 0.12, 0.96), _u(r, x - 0.06, 0.96), _u(r, x + 0.14, 0.96)]))
		_rs(sg, sub(r, 0.3, 0.05, 0.42, 0.12))
		sg.append_array(PackedVector2Array([_u(r, 0.28, 0.05), _u(r, 0.44, 0.05),
			_u(r, 0.6, 0.12), _u(r, 0.6, 0.02), _u(r, 0.6, 0.02), _u(r, 0.68, 0.02), _u(r, 0.68, 0.02), _u(r, 0.68, 0.06),
			_u(r, 0.82, 0.3), _u(r, 0.9, 0.3), _u(r, 0.82, 0.66), _u(r, 0.9, 0.66), _u(r, 0.88, 0.24), _u(r, 0.88, 0.72), _u(r, 0.92, 0.24), _u(r, 0.92, 0.72),
			_u(r, 0.48, 0.78), _u(r, 0.48, 0.9), _u(r, 0.48, 0.9), _u(r, 0.98, 0.9), _u(r, 0.72, 0.86), _u(r, 0.72, 0.94)]))
		S(ci, sg, 0.56, 1.3)
		_gband(ci, r, 0.88, 0.92, 0.4, Pal.tint(Pal.FLUID, 0.9))
	else:
		var q := sub(r, 0.1, 0.06, 0.72, 0.86)
		_vves(sg, q, q.size.x * 0.16)
		sg.append_array(PackedVector2Array([_u(r, 0.16, 0.82), _u(r, 0.12, 0.98), _u(r, 0.66, 0.82), _u(r, 0.7, 0.98), _u(r, 0.06, 0.98), _u(r, 0.76, 0.98),
			_u(r, 0.5, 0.06), _u(r, 0.5, 0.01), _u(r, 0.5, 0.01), _u(r, 0.6, 0.01), _u(r, 0.6, 0.01), _u(r, 0.6, 0.04),
			_u(r, 0.72, 0.3), _u(r, 0.8, 0.3), _u(r, 0.72, 0.74), _u(r, 0.8, 0.74), _u(r, 0.78, 0.24), _u(r, 0.78, 0.8), _u(r, 0.82, 0.24), _u(r, 0.82, 0.8),
			_u(r, 0.4, 0.86), _u(r, 0.4, 0.92), _u(r, 0.4, 0.92), _u(r, 0.98, 0.92), _u(r, 0.88, 0.88), _u(r, 0.88, 0.96)]))
		_rs(sg, sub(r, 0.04, 0.36, 0.1, 0.52))
		S(ci, sg, 0.56, 1.3)
		_gband(ci, r, 0.78, 0.82, 0.42, Pal.tint(Pal.FLUID, 0.9))


# ---------------------------------------------------------------- DR-150: rig air receiver
# the rig's air receiver: the shell on its three legs (their pads), the manway on the side (its cover
# and the bolt ring's frame), the inlet nozzle high and the outlet low, the safety valve and its lever
# on top, the pressure gauge, the auto-drain trap at the foot and its discharge
static func air_receiver(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.16, 0.06, 0.84, 0.84), w * 0.2)
	sg.append_array(PackedVector2Array([_u(r, 0.22, 0.8), _u(r, 0.12, 0.98), _u(r, 0.78, 0.8), _u(r, 0.88, 0.98), _u(r, 0.5, 0.84), _u(r, 0.5, 0.9),
		_u(r, 0.06, 0.98), _u(r, 0.18, 0.98), _u(r, 0.82, 0.98), _u(r, 0.94, 0.98),
		_u(r, 0.84, 0.24), _u(r, 1.0, 0.24), _u(r, 0.96, 0.2), _u(r, 0.96, 0.28), _u(r, 0.16, 0.68), _u(r, 0.0, 0.68), _u(r, 0.04, 0.64), _u(r, 0.04, 0.72),
		_u(r, 0.4, 0.07), _u(r, 0.4, 0.02), _u(r, 0.4, 0.03), _u(r, 0.26, 0.0),
		_u(r, 0.56, 0.93), _u(r, 0.7, 0.93), _u(r, 0.7, 0.93), _u(r, 0.7, 1.0)]))
	_rs(sg, sub(r, 0.36, 0.38, 0.64, 0.52))
	_rs(sg, sub(r, 0.4, 0.41, 0.6, 0.49))
	_rs(sg, sub(r, 0.44, 0.9, 0.56, 0.96))
	S(ci, sg, 0.55, 1.2)
	O(ci, _u(r, 0.62, 0.05), ms * 0.08, 0.55)
	_gband(ci, r, 0.16, 0.84, 0.18, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- DR-150: nitrogen bottle (chained, capped)
# the rig's nitrogen cylinder in its protective cage (two posts, the top and middle hoops, the foot
# rail), the valve and its wheel, the high-pressure pigtail out over the cage and down to its hose
# connector nut, the securing chain across
static func bottle_chained(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_vbot(sg, sub(r, 0.26, 0.14, 0.72, 0.94))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.06), _u(r, 0.12, 0.98), _u(r, 0.84, 0.06), _u(r, 0.84, 0.98),
		_u(r, 0.12, 0.06), _u(r, 0.84, 0.06), _u(r, 0.12, 0.52), _u(r, 0.84, 0.52), _u(r, 0.06, 0.98), _u(r, 0.9, 0.98),
		_u(r, 0.49, 0.14), _u(r, 0.49, 0.09), _u(r, 0.38, 0.09), _u(r, 0.6, 0.09),
		_u(r, 0.56, 0.12), _u(r, 0.94, 0.12), _u(r, 0.94, 0.12), _u(r, 0.94, 0.42)]))
	_rs(sg, sub(r, 0.9, 0.42, 0.98, 0.47))
	S(ci, sg, 0.56, 1.2)
	var ch := PackedVector2Array()
	for k in 4:
		var x: float = 0.12 + k * 0.18
		ch.append(_u(r, x, 0.34))
		ch.append(_u(r, x + 0.1, 0.34))
	S(ci, ch, 0.5, 1.6)
	_gband(ci, r, 0.27, 0.71, 0.27, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- EV-55 / MF-126: diaphragm expansion tank
# a diaphragm expansion tank: the shell, the diaphragm across it sagging under the water side, the air
# valve and its cap on top, the water connection down from the foot (its isolating valve and the line
# out along the floor), the wall bracket
static func expansion_tank(ci: CanvasItem, r: Rect2) -> void:
	var q := _fitr(r, 0.56)
	var w := q.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(q, 0.12, 0.06, 0.88, 0.8), w * 0.3)
	_arcs(sg, _u(q, 0.5, 0.3), w * 0.38, w * 0.08, 0.0, PI, 6)
	sg.append_array(PackedVector2Array([_u(q, 0.5, 0.06), _u(q, 0.5, 0.015), _u(q, 0.42, 0.015), _u(q, 0.58, 0.015),
		_u(q, 0.5, 0.8), _u(q, 0.5, 0.95), _u(q, 0.5, 0.95), Vector2(r.end.x, q.position.y + q.size.y * 0.95), _u(q, 0.42, 0.88), _u(q, 0.58, 0.88),
		_u(q, 0.12, 0.28), Vector2(r.position.x, q.position.y + q.size.y * 0.28), _u(q, 0.12, 0.32), Vector2(r.position.x, q.position.y + q.size.y * 0.32)]))
	S(ci, sg, 0.56, 1.2)


# ---------------------------------------------------------------- FX-70 / HG-170: helium buffer on its skirt
# the cryoplant's helium buffer: the welded tank and its two girth seams, the skirt it stands on (its
# access hole), the valve tree on top (a header and three valves with their handles) with the
# return line out to the side, the pressure transmitter on the shell
static func he_buffer_skirt(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.16, 0.14, 0.84, 0.84), w * 0.16)
	sg.append_array(PackedVector2Array([_u(r, 0.16, 0.4), _u(r, 0.84, 0.4), _u(r, 0.16, 0.62), _u(r, 0.84, 0.62),
		_u(r, 0.2, 0.84), _u(r, 0.12, 0.98), _u(r, 0.8, 0.84), _u(r, 0.88, 0.98), _u(r, 0.08, 0.98), _u(r, 0.92, 0.98),
		_u(r, 0.5, 0.14), _u(r, 0.5, 0.08), _u(r, 0.2, 0.08), _u(r, 1.0, 0.08)]))
	_rs(sg, sub(r, 0.42, 0.88, 0.58, 0.94))
	_rs(sg, sub(r, 0.84, 0.48, 0.96, 0.56))
	for x in [0.28, 0.5, 0.72]:
		sg.append_array(PackedVector2Array([_u(r, x, 0.08), _u(r, x, 0.02), _u(r, x - 0.08, 0.02), _u(r, x + 0.08, 0.02)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.17, 0.83, 0.3, Pal.tint(Pal.VOLT, 0.7))


# ---------------------------------------------------------------- GR-7 / BELT / TUG: small air cylinders
# a small boat's general-purpose air receiver: the little tank with its dished heads on two saddle
# brackets off the bulkhead (the wall plate) and its two floor legs, the drain cock at the foot, the
# relief valve and the inlet line on the top head
static func slim_bottle(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.2, 0.1, 0.8, 0.84), w * 0.16)
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 0.2, 0.3), _u(r, 0.0, 0.64), _u(r, 0.2, 0.64), _u(r, 0.0, 0.24), _u(r, 0.0, 0.7),
		_u(r, 0.28, 0.82), _u(r, 0.2, 1.0), _u(r, 0.72, 0.82), _u(r, 0.8, 1.0),
		_u(r, 0.5, 0.84), _u(r, 0.5, 0.92), _u(r, 0.42, 0.92), _u(r, 0.58, 0.92),
		_u(r, 0.38, 0.11), _u(r, 0.38, 0.03), _u(r, 0.3, 0.03), _u(r, 0.46, 0.03),
		_u(r, 0.62, 0.11), _u(r, 0.62, 0.04), _u(r, 0.62, 0.04), _u(r, 1.0, 0.04)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.21, 0.79, 0.24, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- FR-26: hydrogen tank (type IV)
# the racer's hydrogen tank: the composite tank's capsule and its hoop windings, the bosses at both
# poles, the in-tank solenoid valve's box on the top boss and its cable, the thermal relief device and
# its vent line up and out, the two rubber-lined straps out to the floor rails
static func h2_type4(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	var q := sub(r, 0.16, 0.08, 0.84, 0.92)
	var hd: float = q.size.x * 0.42
	_vves(sg, q, hd)
	_rs(sg, sub(r, 0.42, 0.04, 0.58, 0.08))
	_rs(sg, sub(r, 0.42, 0.92, 0.58, 0.96))
	_rs(sg, sub(r, 0.56, 0.0, 0.76, 0.05))
	sg.append_array(PackedVector2Array([_u(r, 0.76, 0.025), _u(r, 1.0, 0.025), _u(r, 0.44, 0.04), _u(r, 0.34, 0.005), _u(r, 0.34, 0.005), _u(r, 0.04, 0.005)]))
	for y in [0.32, 0.7]:
		_rs(sg, sub(r, 0.12, y, 0.88, y + 0.025))
		sg.append_array(PackedVector2Array([_u(r, 0.12, y + 0.012), _u(r, 0.02, y + 0.012), _u(r, 0.88, y + 0.012), _u(r, 0.98, y + 0.012)]))
	S(ci, sg, 0.56, 1.2)
	var hw := PackedVector2Array()
	var y0: float = q.position.y + hd
	var y1: float = q.end.y - hd
	var n := clampi(int((y1 - y0) / 8.0), 4, 12)
	for k in range(1, n):
		var y: float = lerpf(y0, y1, float(k) / n)
		hw.append(Vector2(q.position.x, y))
		hw.append(Vector2(q.end.x, y))
	S(ci, hw, 0.22, 1.0)
	E.Rc(ci, Rect2(_u(r, 0.32, 0.0), Vector2(w * 0.08, w * 0.06)), Pal.heat(0.8), 1.0)
	_gband(ci, r, 0.17, 0.83, 0.2, Pal.heat(0.7))


# ---------------------------------------------------------------- MY-48: halon bottles (discharged)
# the yacht's halon bank, already discharged: the bottles in their rack (its strap), each one's
# discharge head and its flex hose up to the manifold, the solenoid actuator on the first head, the
# manifold and the pipe out; each head's gauge with its needle down at empty, the empty tag hung
# from the first neck, struck through
static func halon_bank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var n := clampi(int(r.size.x / maxf(r.size.y * 0.42, 10.0)), 2, 5)
	var bw: float = 0.84 / n
	var sg := PackedVector2Array()
	var gn := PackedVector2Array()
	for k in n:
		var x0: float = 0.06 + k * bw
		var xm: float = x0 + bw * 0.5
		_vbot(sg, sub(r, x0 + bw * 0.12, 0.34, x0 + bw * 0.88, 0.98))
		_rs(sg, sub(r, xm - bw * 0.16, 0.26, xm + bw * 0.16, 0.34))
		sg.append(_u(r, xm, 0.26))
		sg.append(_u(r, xm, 0.14))
		var c := _u(r, xm + bw * 0.3, 0.3)
		gn.append(c)
		gn.append(c + Vector2(-1.0, 1.0) * ms * 0.035)
		O(ci, c, ms * 0.05, 0.5)
	sg.append_array(PackedVector2Array([_u(r, 0.06 + bw * 0.5, 0.14), _u(r, 0.98, 0.14), _u(r, 0.98, 0.14), _u(r, 0.98, 0.0),
		_u(r, 0.02, 0.62), _u(r, 0.96, 0.62)]))
	_rs(sg, sub(r, 0.06 + bw * 0.06, 0.16, 0.06 + bw * 0.3, 0.26))
	S(ci, sg, 0.55, 1.1)
	var tg := sub(r, 0.06 + bw * 0.56, 0.42, 0.06 + bw * 0.56 + 0.1, 0.58)
	gn.append_array(PackedVector2Array([_u(r, 0.06 + bw * 0.5, 0.36), tg.position, tg.position, Vector2(tg.end.x, tg.position.y)]))
	S(ci, gn, 0.62, 1.1)
	E.Rc(ci, tg, Pal.heat(0.8), 1.0)
	L(ci, Vector2(tg.position.x, tg.end.y), Vector2(tg.end.x, tg.position.y), 0.65, 1.2)


# ---------------------------------------------------------------- MT-140: lube oil tank
# the lube oil tank: the box and its stiffening ribs, the skid under it, the breather (a mushroom cap)
# and the filler and its cap on the roof, the return line in over the top, the immersion heater's
# flange low on the side and its cable, the drain valve at the foot, the level glass on its two cocks
static func lube_box_tank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.1, 0.78, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.08, 0.36), _u(r, 0.78, 0.36), _u(r, 0.08, 0.64), _u(r, 0.78, 0.64),
		_u(r, 0.04, 0.9), _u(r, 0.82, 0.9), _u(r, 0.04, 0.94), _u(r, 0.82, 0.94), _u(r, 0.04, 0.9), _u(r, 0.04, 0.94), _u(r, 0.82, 0.9), _u(r, 0.82, 0.94),
		_u(r, 0.26, 0.1), _u(r, 0.26, 0.05), _u(r, 0.5, 0.1), _u(r, 0.5, 0.065), _u(r, 0.44, 0.065), _u(r, 0.56, 0.065), _u(r, 0.45, 0.045), _u(r, 0.55, 0.045),
		_u(r, 0.0, 0.03), _u(r, 0.68, 0.03), _u(r, 0.68, 0.03), _u(r, 0.68, 0.1),
		_u(r, 0.4, 0.94), _u(r, 0.4, 0.99), _u(r, 0.34, 0.99), _u(r, 0.48, 0.99),
		_u(r, 0.78, 0.26), _u(r, 0.86, 0.26), _u(r, 0.78, 0.82), _u(r, 0.86, 0.82), _u(r, 0.12, 0.78), _u(r, 0.0, 0.78)]))
	_rs(sg, sub(r, 0.86, 0.22, 0.92, 0.86))
	_rs(sg, sub(r, 0.12, 0.72, 0.28, 0.84))
	S(ci, sg, 0.55, 1.2)
	A(ci, _u(r, 0.26, 0.05), ms * 0.12, PI, TAU, 0.55, 1.2)
	_gband(ci, r, 0.865, 0.915, 0.5, Pal.tint(Pal.FLUID, 0.9))


# ---------------------------------------------------------------- MED-47: medical gas bottles
# the clinic's medical gases: four bottles, each with its colour ring (a gas each), each pigtail up to
# the manifold panel (its two regulators with their gauges, the changeover lever, the alarm lamp),
# the outlet up and out, the restraint chain across the bottles
static func medgas_bank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var cols := [Pal.tint(Pal.AIR, 0.85), Pal.tint(Pal.FLUID, 0.85), Pal.heat(0.75), Pal.tint(Pal.VOLT, 0.85)]
	var sg := PackedVector2Array()
	for k in 4:
		var x0: float = 0.04 + k * 0.235
		_vbot(sg, sub(r, x0, 0.4, x0 + 0.2, 0.97))
		sg.append(_u(r, x0 + 0.1, 0.4))
		sg.append(_u(r, x0 + 0.1, 0.3))
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.3))
	_rs(sg, sub(r, 0.12, 0.1, 0.3, 0.24))
	_rs(sg, sub(r, 0.7, 0.1, 0.88, 0.24))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.62), _u(r, 0.98, 0.62), _u(r, 0.46, 0.12), _u(r, 0.58, 0.22), _u(r, 0.5, 0.04), _u(r, 0.5, 0.0)]))
	S(ci, sg, 0.55, 1.1)
	for x in [0.21, 0.79]:
		D(ci, _u(r, x, 0.15), maxf(1.4, ms * 0.04), 0.6)
	for k in 4:
		var x0: float = 0.04 + k * 0.235
		_gband(ci, r, x0 + 0.005, x0 + 0.195, 0.53, cols[k])
	_lamp(ci, _u(r, 0.5, 0.26), maxf(1.4, ms * 0.04), Pal.heat(0.8))


# ---------------------------------------------------------------- SV-122: nitrogen purge tube
# a tall nitrogen purge tube: the long cylinder clamped to its back rail by three bands, its valve,
# the purge line over to the side through the regulator, the flowmeter (its float) and down and out
static func n2_purge_tube(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vbot(sg, sub(r, 0.18, 0.05, 0.7, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.02), _u(r, 0.06, 0.98),
		_u(r, 0.5, 0.035), _u(r, 0.88, 0.035), _u(r, 0.88, 0.035), _u(r, 0.88, 0.4), _u(r, 0.88, 0.5), _u(r, 0.88, 0.98),
		_u(r, 0.36, 0.005), _u(r, 0.52, 0.005)]))
	for y in [0.28, 0.54, 0.8]:
		_rs(sg, sub(r, 0.06, y, 0.74, y + 0.016))
	_rs(sg, sub(r, 0.38, 0.015, 0.5, 0.05))
	_rs(sg, sub(r, 0.8, 0.08, 0.96, 0.13))
	_rs(sg, sub(r, 0.84, 0.4, 0.92, 0.5))
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.88, 0.43), maxf(1.2, ms * 0.04), 0.65)
	_gband(ci, r, 0.19, 0.69, 0.12, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- FL-116: nitrogen pressurising header
# the nitrogen pressurising header: three tall cylinders (two strap rails across), each one's pigtail
# up to the header and its isolating valve, the header across to the regulator station (its two
# gauges), the relief valve's stub, the pressurising main down the side and out
static func n2_header_bank(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	for k in 3:
		var x0: float = 0.06 + k * 0.22
		var xm: float = x0 + 0.09
		_vbot(sg, sub(r, x0, 0.2, x0 + 0.18, 0.98))
		sg.append_array(PackedVector2Array([_u(r, xm, 0.2), _u(r, xm, 0.1), _u(r, xm - 0.05, 0.15), _u(r, xm + 0.05, 0.15)]))
	sg.append_array(PackedVector2Array([_u(r, 0.15, 0.1), _u(r, 0.72, 0.1), _u(r, 0.86, 0.16), _u(r, 0.86, 1.0),
		_u(r, 0.02, 0.5), _u(r, 0.72, 0.5), _u(r, 0.02, 0.8), _u(r, 0.72, 0.8),
		_u(r, 0.86, 0.06), _u(r, 0.86, 0.0), _u(r, 0.82, 0.0), _u(r, 0.9, 0.0)]))
	_rs(sg, sub(r, 0.72, 0.06, 0.98, 0.16))
	S(ci, sg, 0.55, 1.2)
	for x in [0.78, 0.92]:
		D(ci, _u(r, x, 0.11), maxf(1.4, ms * 0.05), 0.6)
	_gband(ci, r, 0.06, 0.68, 0.29, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- FR-26: oxygen bottle (steel)
# the racer's oxygen bottle: the seamless steel cylinder, the guard ring round its valve on its two
# posts, the valve's wheel, the outlet over to the side through the check valve to the gauge and
# down the side; the foot ring, the back rail and its two straps
static func o2_steel_bottle(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vbot(sg, sub(r, 0.16, 0.1, 0.72, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.26, 0.02), _u(r, 0.62, 0.02), _u(r, 0.26, 0.02), _u(r, 0.26, 0.11), _u(r, 0.62, 0.02), _u(r, 0.62, 0.11),
		_u(r, 0.36, 0.05), _u(r, 0.52, 0.05), _u(r, 0.44, 0.05), _u(r, 0.44, 0.1),
		_u(r, 0.5, 0.08), _u(r, 0.86, 0.08), _u(r, 0.86, 0.08), _u(r, 0.86, 1.0),
		_u(r, 0.1, 0.94), _u(r, 0.78, 0.94), _u(r, 0.04, 0.02), _u(r, 0.04, 0.98)]))
	_rs(sg, sub(r, 0.82, 0.14, 0.9, 0.2))
	for y in [0.34, 0.72]:
		_rs(sg, sub(r, 0.04, y, 0.76, y + 0.02))
	S(ci, sg, 0.55, 1.2)
	D(ci, _u(r, 0.86, 0.3), maxf(1.6, ms * 0.08), 0.6)
	_gband(ci, r, 0.17, 0.71, 0.24, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- CH-110 / SV-122 / TB-180 / VT-80: oxygen bottles on changeover
# oxygen bottles in their cage on an automatic changeover: the cage (posts, foot, the chain across),
# the bottles (as many as fit), each pigtail up to the manifold, the changeover valve and its lever
# in the middle, the outlet up and out
static func o2_bottle_pair(ci: CanvasItem, r: Rect2) -> void:
	var n := clampi(roundi(r.size.x / (r.size.y * 0.42)), 1, 3)
	var bw: float = 0.8 / n
	var sg := PackedVector2Array([_u(r, 0.04, 0.22), _u(r, 0.04, 0.98), _u(r, 0.96, 0.22), _u(r, 0.96, 0.98), _u(r, 0.04, 0.98), _u(r, 0.96, 0.98),
		_u(r, 0.04, 0.5), _u(r, 0.96, 0.5)])
	var mf := PackedVector2Array([_u(r, 0.1 + bw * 0.5, 0.1), _u(r, 0.9 - bw * 0.5, 0.1), _u(r, 0.5, 0.04), _u(r, 0.5, 0.0), _u(r, 0.56, 0.04), _u(r, 0.66, 0.0)])
	for k in n:
		var x0: float = 0.1 + k * bw
		var xm: float = x0 + bw * 0.5
		_vbot(sg, sub(r, x0 + bw * 0.1, 0.24, x0 + bw * 0.9, 0.97))
		mf.append_array(PackedVector2Array([_u(r, xm, 0.24), _u(r, xm + bw * 0.12, 0.17), _u(r, xm + bw * 0.12, 0.17), _u(r, xm, 0.1)]))
	_rs(mf, sub(r, 0.42, 0.04, 0.58, 0.16))
	S(ci, sg, 0.55, 1.2)
	S(ci, mf, 0.5, 1.3)
	for k in n:
		var x0: float = 0.1 + k * bw
		_gband(ci, r, x0 + bw * 0.12, x0 + bw * 0.88, 0.36, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- HB-86 / MY-48: liquid oxygen tank and vaporiser
# the liquid-oxygen tank: the vacuum jacket and the inner vessel inside it, the legs, the vent stack
# and the two relief valves on the top head, the ladder up its side (where it is tall); the ambient
# vaporiser beside it (its finned column, the frost on it), the liquid line over from the tank's foot,
# the gas out of the vaporiser's top
static func o2_cryo_tank(ci: CanvasItem, r: Rect2) -> void:
	var tall := r.size.y > r.size.x * 1.8
	var q := sub(r, 0.06, 0.05, 0.6, 0.9)
	var w := q.size.x
	var sg := PackedVector2Array()
	_vves(sg, q, w * 0.22)
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.86), _u(r, 0.08, 0.98), _u(r, 0.54, 0.86), _u(r, 0.58, 0.98),
		_u(r, 0.33, 0.05), _u(r, 0.33, 0.0), _u(r, 0.22, 0.07), _u(r, 0.22, 0.035), _u(r, 0.44, 0.07), _u(r, 0.44, 0.035),
		_u(r, 0.33, 0.9), _u(r, 0.33, 0.97), _u(r, 0.33, 0.97), _u(r, 0.84, 0.97), _u(r, 0.84, 0.97), _u(r, 0.84, 0.94),
		_u(r, 0.84, 0.2), _u(r, 0.84, 0.12), _u(r, 0.84, 0.12), _u(r, 1.0, 0.12)]))
	_rs(sg, sub(r, 0.72, 0.2, 0.96, 0.94))
	for k in 3:
		var x: float = 0.78 + k * 0.06
		sg.append(_u(r, x, 0.2))
		sg.append(_u(r, x, 0.94))
	if tall:
		var nr := clampi(int(r.size.y * 0.8 / 12.0), 4, 24)
		sg.append_array(PackedVector2Array([_u(r, 0.62, 0.14), _u(r, 0.62, 0.98), _u(r, 0.68, 0.14), _u(r, 0.68, 0.98)]))
		for k in nr:
			var y: float = 0.16 + k * 0.8 / nr
			sg.append(_u(r, 0.62, y))
			sg.append(_u(r, 0.68, y))
	S(ci, sg, 0.55, 1.2)
	var iv := PackedVector2Array()
	_vves(iv, q.grow(-w * 0.07), w * 0.18, 4)
	S(ci, iv, 0.24, 1.0)
	_gband(ci, r, 0.07, 0.59, 0.18, Pal.tint(Pal.AIR, 0.8))
	for y in [0.8, 0.88]:
		_gband(ci, r, 0.73, 0.95, y, Pal.tint(Pal.AIR, 0.6))


# ---------------------------------------------------------------- MED-47 / PT-34 / JD-38: oxygen bottle with flowmeter
# a bedside oxygen bottle: the bottle, the flowmeter on its valve (its tube and float), the humidifier
# jar hung under it (the water in it), the mask hose's loop down the side, the wall strap
static func o2_flow_bottle(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vbot(sg, sub(r, 0.1, 0.12, 0.62, 0.98))
	_rs(sg, sub(r, 0.62, 0.02, 0.76, 0.2))
	_rs(sg, sub(r, 0.66, 0.24, 0.92, 0.42))
	sg.append_array(PackedVector2Array([_u(r, 0.36, 0.12), _u(r, 0.36, 0.08), _u(r, 0.36, 0.08), _u(r, 0.62, 0.08), _u(r, 0.69, 0.2), _u(r, 0.69, 0.24),
		_u(r, 0.8, 0.42), _u(r, 0.9, 0.6), _u(r, 0.9, 0.6), _u(r, 0.72, 0.76), _u(r, 0.72, 0.76), _u(r, 0.92, 0.9),
		_u(r, 0.02, 0.52), _u(r, 0.66, 0.52)]))
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.69, 0.12), maxf(1.0, ms * 0.06), 0.65)
	_gband(ci, r, 0.68, 0.9, 0.36, Pal.tint(Pal.FLUID, 0.8))
	_gband(ci, r, 0.11, 0.61, 0.26, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- CH-110 / TB-180: pressurant bottles (lying pair)
# the propellant pressurant pair, lying one over the other: each titanium bottle (its centre weld,
# the closed boss at one end, the outlet boss at the other), the two clamp straps over both down to
# their feet, the two outlets into the regulator block (its gauge), the feed out of its foot
static func pressurant_pair(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	for y0 in [0.06, 0.5]:
		var q := sub(r, 0.08, y0, 0.78, y0 + 0.38)
		_hves(sg, q, q.size.y * 0.5)
		_rs(sg, sub(r, 0.04, y0 + 0.15, 0.08, y0 + 0.23))
		sg.append_array(PackedVector2Array([_u(r, 0.43, y0), _u(r, 0.43, y0 + 0.38), _u(r, 0.78, y0 + 0.19), _u(r, 0.84, y0 + 0.19)]))
	for x in [0.22, 0.62]:
		_rs(sg, sub(r, x, 0.03, x + 0.035, 0.94))
		sg.append(_u(r, x - 0.03, 0.97))
		sg.append(_u(r, x + 0.065, 0.97))
	sg.append_array(PackedVector2Array([_u(r, 0.84, 0.25), _u(r, 0.84, 0.69), _u(r, 0.84, 0.47), _u(r, 0.86, 0.47), _u(r, 0.91, 0.64), _u(r, 0.91, 1.0)]))
	_rs(sg, sub(r, 0.86, 0.3, 0.96, 0.64))
	S(ci, sg, 0.55, 1.2)
	D(ci, _u(r, 0.91, 0.4), maxf(1.4, ms * 0.07), 0.6)
	_gband(ci, r, 0.3, 0.38, 0.25, Pal.tint(Pal.VOLT, 0.75))
	_gband(ci, r, 0.3, 0.38, 0.69, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- QC-30: helium buffer and gas-handling panel
# the dilution fridge's helium buffer hung on the wall: the slim tank on its rail (two clamp bands),
# the line from its top over to the gas-handling panel (the valve grid and the lines between), the
# liquid-nitrogen cold trap hung under the panel (its dewar and its two lines)
static func qc_he_buffer(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.04, 0.02), _u(r, 0.04, 0.98)])
	_vves(sg, sub(r, 0.1, 0.04, 0.5, 0.96), w * 0.2)
	for y in [0.24, 0.76]:
		sg.append(_u(r, 0.04, y))
		sg.append(_u(r, 0.54, y))
	_rs(sg, sub(r, 0.58, 0.12, 0.96, 0.56))
	sg.append_array(PackedVector2Array([_u(r, 0.3, 0.04), _u(r, 0.3, 0.01), _u(r, 0.3, 0.01), _u(r, 0.77, 0.01), _u(r, 0.77, 0.01), _u(r, 0.77, 0.12),
		_u(r, 0.66, 0.24), _u(r, 0.88, 0.24), _u(r, 0.66, 0.36), _u(r, 0.88, 0.36), _u(r, 0.66, 0.24), _u(r, 0.66, 0.48), _u(r, 0.88, 0.24), _u(r, 0.88, 0.48),
		_u(r, 0.77, 0.36), _u(r, 0.77, 0.48), _u(r, 0.66, 0.48), _u(r, 0.88, 0.48),
		_u(r, 0.72, 0.56), _u(r, 0.72, 0.66), _u(r, 0.82, 0.56), _u(r, 0.82, 0.66)]))
	_vves(sg, sub(r, 0.64, 0.66, 0.9, 0.94), w * 0.08, 3)
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.77, 0.36), maxf(1.2, ms * 0.06), 0.65)
	_gband(ci, r, 0.11, 0.49, 0.16, Pal.tint(Pal.VOLT, 0.7))


# ---------------------------------------------------------------- QC-30: 3He/4He mixture tank (caged, sealed)
# the 3He/4He mixture's dump tank, the most valuable gas aboard: the tank in its protective cage
# (frame, bars, rings), the sealed bellows valve on top (its folds, its wheel), the padlock on the
# wheel and the seal lamp
static func mix_tank_cage(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.24, 0.18, 0.76, 0.92), w * 0.2)
	sg.append_array(PackedVector2Array([_u(r, 0.42, 0.18), _u(r, 0.42, 0.06), _u(r, 0.58, 0.18), _u(r, 0.58, 0.06),
		_u(r, 0.5, 0.06), _u(r, 0.5, 0.03), _u(r, 0.38, 0.03), _u(r, 0.62, 0.03)]))
	for k in 4:
		var y: float = 0.08 + k * 0.025
		sg.append(_u(r, 0.4, y))
		sg.append(_u(r, 0.6, y))
	_rs(sg, sub(r, 0.62, 0.035, 0.72, 0.075))
	S(ci, sg, 0.58, 1.2)
	A(ci, _u(r, 0.67, 0.035), r.size.x * 0.04, PI, TAU, 0.58, 1.0)
	var cg := PackedVector2Array()
	_rs(cg, sub(r, 0.1, 0.12, 0.9, 0.98))
	cg.append_array(PackedVector2Array([_u(r, 0.3, 0.12), _u(r, 0.3, 0.98), _u(r, 0.5, 0.12), _u(r, 0.5, 0.98), _u(r, 0.7, 0.12), _u(r, 0.7, 0.98), _u(r, 0.1, 0.55), _u(r, 0.9, 0.55)]))
	S(ci, cg, 0.32, 1.1)
	_lamp(ci, _u(r, 0.8, 0.06), maxf(1.4, ms * 0.05), Pal.tint(Pal.VOLT, 0.9))
	_gband(ci, r, 0.25, 0.75, 0.3, Pal.tint(Pal.VOLT, 0.7))


# ---------------------------------------------------------------- CL-104: refrigerant liquid receiver
# the plant's liquid receiver: the tall vessel on its two wall brackets, the inlet down into its top
# head, the twin relief valves on their changeover tee, the two sight glasses either side of the
# liquid line, the king valve at the foot (its wheel) and the liquid line out, the fusible plug
static func ref_receiver(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.16, 0.06, 0.74, 0.9), w * 0.2)
	sg.append_array(PackedVector2Array([_u(r, 0.74, 0.25), _u(r, 1.0, 0.25), _u(r, 0.74, 0.75), _u(r, 1.0, 0.75), _u(r, 0.96, 0.21), _u(r, 0.96, 0.29), _u(r, 0.96, 0.71), _u(r, 0.96, 0.79),
		_u(r, 1.0, 0.04), _u(r, 0.6, 0.04), _u(r, 0.6, 0.04), _u(r, 0.6, 0.08),
		_u(r, 0.45, 0.9), _u(r, 0.45, 0.96), _u(r, 0.36, 0.96), _u(r, 0.54, 0.96), _u(r, 0.45, 0.96), _u(r, 0.45, 0.99), _u(r, 0.45, 0.99), _u(r, 1.0, 0.99),
		_u(r, 0.32, 0.07), _u(r, 0.32, 0.03), _u(r, 0.22, 0.03), _u(r, 0.42, 0.03), _u(r, 0.22, 0.03), _u(r, 0.22, 0.0), _u(r, 0.42, 0.03), _u(r, 0.42, 0.0)]))
	_rs(sg, sub(r, 0.66, 0.965, 0.82, 1.0))
	S(ci, sg, 0.55, 1.2)
	for y in [0.52, 0.72]:
		O(ci, _u(r, 0.45, y), ms * 0.09, 0.6, 1.2)
	D(ci, _u(r, 0.62, 0.86), 1.4, 0.6)


# ---------------------------------------------------------------- ST-40: nitrous oxide tank
# the stunt craft's nitrous tank: the tank in its two straps, the vent valve on top and its line out
# over the side, the dip tube down inside to the fill level, the liquid's level, the fill coupling on
# the side, the run valve at the foot with its pneumatic actuator, the feed out
static func n2o_tank(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.16, 0.06, 0.8, 0.82), w * 0.22)
	for y in [0.28, 0.62]:
		_rs(sg, sub(r, 0.14, y, 0.82, y + 0.025))
	sg.append_array(PackedVector2Array([_u(r, 0.48, 0.06), _u(r, 0.48, 0.02), _u(r, 0.48, 0.02), _u(r, 0.96, 0.02), _u(r, 0.96, 0.02), _u(r, 0.96, 0.08),
		_u(r, 0.8, 0.46), _u(r, 0.9, 0.46), _u(r, 0.9, 0.42), _u(r, 0.9, 0.5), _u(r, 0.9, 0.43), _u(r, 0.97, 0.46), _u(r, 0.9, 0.49), _u(r, 0.97, 0.46),
		_u(r, 0.48, 0.82), _u(r, 0.48, 0.86), _u(r, 0.48, 0.94), _u(r, 0.48, 1.0), _u(r, 0.56, 0.9), _u(r, 0.6, 0.9)]))
	_rs(sg, sub(r, 0.4, 0.86, 0.56, 0.94))
	_rs(sg, sub(r, 0.6, 0.85, 0.86, 0.95))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.46, 0.08), _u(r, 0.46, 0.34), _u(r, 0.5, 0.08), _u(r, 0.5, 0.34)]), 0.3, 1.0)
	_gband(ci, r, 0.17, 0.79, 0.16, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- TS-1: practice reagent bottle
# a practice reagent bottle on its drip tray: the bottle, its shoulder and neck, the screw cap, the
# blank label, the liquid in it, the tray with its lips
static func reagent_bottle(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.2, 0.46), _u(r, 0.2, 0.9), _u(r, 0.8, 0.46), _u(r, 0.8, 0.9), _u(r, 0.2, 0.9), _u(r, 0.8, 0.9),
		_u(r, 0.2, 0.46), _u(r, 0.4, 0.32), _u(r, 0.8, 0.46), _u(r, 0.6, 0.32), _u(r, 0.4, 0.32), _u(r, 0.4, 0.22), _u(r, 0.6, 0.32), _u(r, 0.6, 0.22),
		_u(r, 0.04, 0.96), _u(r, 0.96, 0.96), _u(r, 0.04, 0.96), _u(r, 0.04, 0.88), _u(r, 0.96, 0.96), _u(r, 0.96, 0.88)])
	_rs(sg, sub(r, 0.34, 0.08, 0.66, 0.22))
	S(ci, sg, 0.6, 1.0)
	R(ci, sub(r, 0.28, 0.62, 0.72, 0.8), 0.3)
	_gband(ci, r, 0.22, 0.78, 0.54, Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- ARK-01 / TW-64: welding gas bottle
# a welding gas bottle in use: the bottle, the regulator on its valve (its body and two gauges), the
# flashback arrestor and the hose down to its coil, the cap hung on the wall chain's end
static func weld_bottle(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vbot(sg, sub(r, 0.08, 0.16, 0.56, 0.98))
	_rs(sg, sub(r, 0.26, 0.08, 0.5, 0.14))
	_rs(sg, sub(r, 0.66, 0.6, 0.9, 0.68))
	sg.append_array(PackedVector2Array([_u(r, 0.32, 0.16), _u(r, 0.32, 0.14), _u(r, 0.5, 0.11), _u(r, 0.62, 0.11), _u(r, 0.62, 0.11), _u(r, 0.62, 0.28),
		_u(r, 0.62, 0.28), _u(r, 0.8, 0.8), _u(r, 0.56, 0.42), _u(r, 0.72, 0.6), _u(r, 0.68, 0.6), _u(r, 0.72, 0.56), _u(r, 0.72, 0.56), _u(r, 0.84, 0.56), _u(r, 0.84, 0.56), _u(r, 0.88, 0.6)]))
	S(ci, sg, 0.55, 1.1)
	var ch := PackedVector2Array()
	for k in 3:
		var x: float = 0.0 + k * 0.2
		ch.append(_u(r, x, 0.42))
		ch.append(_u(r, x + 0.07, 0.42))
	S(ci, ch, 0.48, 1.5)
	for x in [0.3, 0.46]:
		D(ci, _u(r, x, 0.055), maxf(1.4, ms * 0.08), 0.6)
	O(ci, _u(r, 0.8, 0.86), ms * 0.16, 0.45, 1.4)
	_gband(ci, r, 0.09, 0.55, 0.3, Pal.heat(0.75))


# ================================================================ E161–E370 (2026-11-12): ninth batch, part two
# the ARK's switchboards and turbine, the core switch, the filters, the hydraulic power units, the
# manifolds and valve groups, the pipes (each by what it carries: its bore, flanges, supports,
# lagging, jacket or tracing)

# ---------------------------------------------------------------- ARK-01: main turbine-generator
# the ARK's turbine-generator: the high-pressure casing (its cone, the horizontal joint) and the main
# stop valve with its actuator over it, the crossover pipe to the low-pressure casing and its exhaust
# hood down to the condenser, the bearing pedestals, the coupling, the generator (its stator ribs, the
# air cooler on top, the exciter at the end), the soleplate
static func ark_turbine(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.38), _u(r, 0.04, 0.62), _u(r, 0.04, 0.38), _u(r, 0.22, 0.3), _u(r, 0.04, 0.62), _u(r, 0.22, 0.7),
		_u(r, 0.22, 0.3), _u(r, 0.22, 0.7), _u(r, 0.04, 0.5), _u(r, 0.22, 0.5),
		_u(r, 0.26, 0.7), _u(r, 0.3, 0.9), _u(r, 0.5, 0.7), _u(r, 0.46, 0.9), _u(r, 0.3, 0.9), _u(r, 0.46, 0.9),
		_u(r, 0.1, 0.2), _u(r, 0.1, 0.34), _u(r, 0.2, 0.84), _u(r, 0.2, 0.9), _u(r, 0.54, 0.84), _u(r, 0.54, 0.9),
		_u(r, 0.02, 0.9), _u(r, 0.98, 0.9), _u(r, 0.02, 0.94), _u(r, 0.98, 0.94)])
	_rs(sg, sub(r, 0.26, 0.22, 0.5, 0.7))
	_rs(sg, sub(r, 0.06, 0.08, 0.14, 0.2))
	_rs(sg, sub(r, 0.07, 0.0, 0.13, 0.08))
	_rs(sg, sub(r, 0.52, 0.44, 0.58, 0.56))
	_rs(sg, sub(r, 0.6, 0.28, 0.94, 0.78))
	_rs(sg, sub(r, 0.66, 0.12, 0.88, 0.28))
	_rs(sg, sub(r, 0.94, 0.42, 0.98, 0.58))
	for x in [0.67, 0.74, 0.81, 0.88]:
		sg.append(_u(r, x, 0.28))
		sg.append(_u(r, x, 0.78))
	sg.append_array(PackedVector2Array([_u(r, 0.66, 0.18), _u(r, 0.88, 0.18), _u(r, 0.66, 0.23), _u(r, 0.88, 0.23)]))
	S(ci, sg, 0.55, 1.3)
	S(ci, PackedVector2Array([_u(r, 0.13, 0.32), _u(r, 0.13, 0.12), _u(r, 0.13, 0.12), _u(r, 0.38, 0.12), _u(r, 0.38, 0.12), _u(r, 0.38, 0.22)]), 0.55, 2.6)
	L(ci, _u(r, 0.0, 0.5), _u(r, 0.98, 0.5), 0.3)
	_gband(ci, r, 0.05, 0.21, 0.42, Pal.heat(0.7))


# ---------------------------------------------------------------- ARK-01: main power distribution centre
# the ship's main switchboard: three sections under the busbar chamber, the mimic bus across them,
# a draw-out air circuit breaker in each (its racking frame, the window, the charging handle), the
# moulded-case feeder breakers under them, the meters of the middle section, the cable gland plate
static func ark_main_board(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.02, 0.98, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.34, 0.02), _u(r, 0.34, 0.98), _u(r, 0.66, 0.02), _u(r, 0.66, 0.98),
		_u(r, 0.02, 0.14), _u(r, 0.98, 0.14), _u(r, 0.02, 0.92), _u(r, 0.98, 0.92)]))
	for x0 in [0.02, 0.34, 0.66]:
		_rs(sg, sub(r, x0 + 0.04, 0.36, x0 + 0.28, 0.6))
		_rs(sg, sub(r, x0 + 0.09, 0.4, x0 + 0.23, 0.48))
		sg.append_array(PackedVector2Array([_u(r, x0 + 0.16, 0.52), _u(r, x0 + 0.16, 0.58), _u(r, x0 + 0.06, 0.66), _u(r, x0 + 0.26, 0.66)]))
		for k in 3:
			var y: float = 0.7 + k * 0.07
			sg.append(_u(r, x0 + 0.06, y))
			sg.append(_u(r, x0 + 0.26, y))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.04, 0.08), _u(r, 0.96, 0.08)]), 0.55, 2.4)
	for x in [0.44, 0.56]:
		D(ci, _u(r, x, 0.22), maxf(1.6, ms * 0.04), 0.6)
	_gband(ci, r, 0.04, 0.96, 0.3, Pal.tint(Pal.VOLT, 0.75))
	_lamp(ci, _u(r, 0.5, 0.86), maxf(1.6, ms * 0.03), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- ARK-01: hub distribution (slip ring)
# the hub's distribution: two moulded-case breakers (their toggles) over the slip-ring unit that
# carries power across into the spinning ring — the ring drum, its shaft, the brush arms on both
# sides — and the cable glands at the foot
static func ark_hub_dist(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.02, 0.96, 0.98))
	_rs(sg, sub(r, 0.12, 0.08, 0.44, 0.3))
	_rs(sg, sub(r, 0.56, 0.08, 0.88, 0.3))
	_rs(sg, sub(r, 0.3, 0.42, 0.7, 0.78))
	sg.append_array(PackedVector2Array([_u(r, 0.28, 0.16), _u(r, 0.28, 0.22), _u(r, 0.72, 0.16), _u(r, 0.72, 0.22),
		_u(r, 0.5, 0.36), _u(r, 0.5, 0.84), _u(r, 0.3, 0.92), _u(r, 0.3, 0.98), _u(r, 0.5, 0.92), _u(r, 0.5, 0.98), _u(r, 0.7, 0.92), _u(r, 0.7, 0.98)]))
	for k in 4:
		var y: float = 0.48 + k * 0.08
		sg.append_array(PackedVector2Array([_u(r, 0.3, y), _u(r, 0.7, y), _u(r, 0.16, y - 0.02), _u(r, 0.3, y), _u(r, 0.84, y - 0.02), _u(r, 0.7, y)]))
	S(ci, sg, 0.55, 1.2)
	_gband(ci, r, 0.31, 0.69, 0.44, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- ARK-01: segment local distribution (x12)
# a section's local panelboard: the door, the two columns of miniature breakers inside (their rows),
# the main isolator's rotary handle, the cable gland plate and the three cables out of the foot
static func ark_local_dist(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.04, 0.94, 0.9))
	for x0 in [0.14, 0.56]:
		_rs(sg, sub(r, x0, 0.22, x0 + 0.3, 0.8))
		for k in 4:
			var y: float = 0.33 + k * 0.11
			sg.append(_u(r, x0, y))
			sg.append(_u(r, x0 + 0.3, y))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.12), _u(r, 0.62, 0.08), _u(r, 0.3, 0.9), _u(r, 0.3, 1.0), _u(r, 0.5, 0.9), _u(r, 0.5, 1.0), _u(r, 0.7, 0.9), _u(r, 0.7, 1.0)]))
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.5, 0.12), maxf(1.6, ms * 0.06), 0.55)


# ---------------------------------------------------------------- ARK-01: ring main unit (x4)
# the ring's main unit: two load-break switch panels side by side, each with its mimic (the bus,
# the switch blade), the operating hole for the handle and the earthing switch's, the cable
# compartment under it with its three cable heads; the gas pressure gauge over the middle
static func ark_ring_dist(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.02, 0.96, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.02), _u(r, 0.5, 0.98)]))
	for x0 in [0.04, 0.5]:
		var xm: float = x0 + 0.23
		sg.append_array(PackedVector2Array([_u(r, xm, 0.22), _u(r, xm, 0.3), _u(r, xm, 0.3), _u(r, xm + 0.1, 0.38), _u(r, xm, 0.42), _u(r, xm, 0.5)]))
		_rs(sg, sub(r, x0 + 0.06, 0.62, x0 + 0.4, 0.94))
		for k in 3:
			var x: float = x0 + 0.12 + k * 0.11
			sg.append_array(PackedVector2Array([_u(r, x, 0.94), _u(r, x, 0.72), _u(r, x - 0.03, 0.72), _u(r, x + 0.03, 0.72)]))
	S(ci, sg, 0.55, 1.1)
	for x in [0.17, 0.35, 0.63, 0.81]:
		D(ci, _u(r, x, 0.56), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.06, 0.94, 0.22, Pal.tint(Pal.VOLT, 0.75))
	_lamp(ci, _u(r, 0.5, 0.08), maxf(1.6, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- DC-84: core network switch
# the data centre's core switch chassis: the fan tray on top (its grille), the two supervisor
# cards, the stack of line cards and their port rows, the power supplies at the foot, the fibre
# bundles out of the side, the status lamps
static func core_switch(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.86, 0.98))
	_rs(sg, sub(r, 0.1, 0.04, 0.82, 0.12))
	for x in [0.28, 0.46, 0.64]:
		sg.append(_u(r, x, 0.04))
		sg.append(_u(r, x, 0.12))
	for y in [0.14, 0.2]:
		_rs(sg, sub(r, 0.1, y, 0.82, y + 0.05))
	var n := clampi(int(r.size.y * 0.54 / 9.0), 4, 10)
	var pt := PackedVector2Array()
	for k in n + 1:
		var y: float = 0.27 + k * 0.54 / n
		sg.append(_u(r, 0.1, y))
		sg.append(_u(r, 0.82, y))
		if k < n:
			var yp: float = y + 0.27 / n
			for j in 4:
				var x: float = 0.16 + j * 0.15
				pt.append(_u(r, x, yp))
				pt.append(_u(r, x + 0.1, yp))
	for k in 3:
		var x0: float = 0.1 + k * 0.24
		_rs(sg, sub(r, x0, 0.84, x0 + 0.22, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.86, 0.36), _u(r, 1.0, 0.44), _u(r, 0.86, 0.5), _u(r, 1.0, 0.58), _u(r, 0.86, 0.64), _u(r, 1.0, 0.72)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, pt, 0.42, 1.6)
	_lamp(ci, _u(r, 0.14, 0.165), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_lamp(ci, _u(r, 0.14, 0.225), maxf(1.4, ms * 0.04), Pal.tint(Pal.AIR, 0.85))


# ---------------------------------------------------------------- ARK-01 and many: cartridge filter
# a cartridge filter housing: the housing on its legs, the quick-opening lid and its clamp band and
# swing bolts, the lifting lug on top, the inlet flange high on one side and the outlet low on the
# other (their flange pairs), the pleated cartridge seen inside, the differential-pressure gauge on its
# two impulse lines, the drain valve at the foot
static func cartridge_filter(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.2, 0.2, 0.8, 0.86), w * 0.08, 4)
	_rs(sg, sub(r, 0.16, 0.12, 0.84, 0.2))
	sg.append_array(PackedVector2Array([_u(r, 0.16, 0.16), _u(r, 0.84, 0.16), _u(r, 0.42, 0.12), _u(r, 0.5, 0.05), _u(r, 0.5, 0.05), _u(r, 0.58, 0.12),
		_u(r, 0.12, 0.13), _u(r, 0.12, 0.19), _u(r, 0.88, 0.13), _u(r, 0.88, 0.19),
		_u(r, 0.0, 0.3), _u(r, 0.2, 0.3), _u(r, 0.03, 0.25), _u(r, 0.03, 0.35), _u(r, 0.06, 0.25), _u(r, 0.06, 0.35),
		_u(r, 0.8, 0.76), _u(r, 1.0, 0.76), _u(r, 0.97, 0.71), _u(r, 0.97, 0.81), _u(r, 0.94, 0.71), _u(r, 0.94, 0.81),
		_u(r, 0.8, 0.32), _u(r, 0.9, 0.32), _u(r, 0.9, 0.32), _u(r, 0.9, 0.42), _u(r, 0.8, 0.7), _u(r, 0.86, 0.7), _u(r, 0.86, 0.7), _u(r, 0.86, 0.5),
		_u(r, 0.5, 0.86), _u(r, 0.5, 0.92), _u(r, 0.42, 0.9), _u(r, 0.58, 0.96), _u(r, 0.42, 0.96), _u(r, 0.58, 0.9), _u(r, 0.42, 0.9), _u(r, 0.42, 0.96), _u(r, 0.58, 0.9), _u(r, 0.58, 0.96),
		_u(r, 0.26, 0.82), _u(r, 0.22, 1.0), _u(r, 0.74, 0.82), _u(r, 0.78, 1.0)]))
	S(ci, sg, 0.55, 1.1)
	var cg := PackedVector2Array()
	_rs(cg, sub(r, 0.32, 0.26, 0.68, 0.8))
	for k in 8:
		var y0: float = 0.28 + k * 0.065
		cg.append(_u(r, 0.36 if k % 2 == 0 else 0.64, y0))
		cg.append(_u(r, 0.64 if k % 2 == 0 else 0.36, y0 + 0.065))
	S(ci, cg, 0.3, 1.0)
	var gc := _u(r, 0.88, 0.46)
	O(ci, gc, w * 0.08, 0.6)
	L(ci, gc, gc + Vector2(w * 0.05, -w * 0.03), 0.6)


# ---------------------------------------------------------------- BL-88: hollow-fibre oxygenator
# the water loop's oxygenator: the clear column between its two flanges, the hollow-fibre bundle in
# it, the base, the gas in at the foot and out of the top, the water in low and out high, the
# bubbles of gas through it
static func fibre_oxygenator(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.24, 0.1, 0.76, 0.86))
	_rs(sg, sub(r, 0.14, 0.86, 0.86, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.18, 0.1), _u(r, 0.82, 0.1), _u(r, 0.18, 0.86), _u(r, 0.82, 0.86),
		_u(r, 0.0, 0.8), _u(r, 0.24, 0.8), _u(r, 0.5, 0.1), _u(r, 0.5, 0.0), _u(r, 0.76, 0.72), _u(r, 1.0, 0.72), _u(r, 0.24, 0.2), _u(r, 0.0, 0.2)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.36, 0.16), _u(r, 0.36, 0.8), _u(r, 0.5, 0.16), _u(r, 0.5, 0.8), _u(r, 0.64, 0.16), _u(r, 0.64, 0.8)]), 0.26, 1.0)
	for p in [Vector2(0.43, 0.62), Vector2(0.57, 0.46), Vector2(0.43, 0.3)]:
		_lamp(ci, _u(r, p.x, p.y), maxf(1.2, ms * 0.06), Pal.tint(Pal.AIR, 0.8))
	_gband(ci, r, 0.25, 0.75, 0.5, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- ARK-01: decontamination station
# the decontamination booth: its posts and roof, the shower rose on its supply pipe and the spray
# under it, the grated floor over the drain sump, the hose reel on the side and its hose, the foot
# valve
static func decon_booth(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.08, 0.04), _u(r, 0.08, 0.9), _u(r, 0.72, 0.04), _u(r, 0.72, 0.9), _u(r, 0.04, 0.04), _u(r, 0.76, 0.04),
		_u(r, 0.04, 0.9), _u(r, 0.76, 0.9), _u(r, 0.04, 0.94), _u(r, 0.76, 0.94), _u(r, 0.4, 0.04), _u(r, 0.4, 0.12),
		_u(r, 0.72, 0.4), _u(r, 0.8, 0.4), _u(r, 0.86, 0.4), _u(r, 0.92, 0.72), _u(r, 0.6, 0.9), _u(r, 0.66, 0.84)])
	_rs(sg, sub(r, 0.28, 0.12, 0.52, 0.15))
	_rs(sg, sub(r, 0.32, 0.94, 0.48, 0.99))
	for k in 5:
		var x: float = 0.16 + k * 0.12
		sg.append(_u(r, x, 0.9))
		sg.append(_u(r, x, 0.94))
	S(ci, sg, 0.55, 1.1)
	var sp := PackedVector2Array()
	for k in 5:
		var x: float = 0.3 + k * 0.05
		sp.append(_u(r, x, 0.16))
		sp.append(_u(r, 0.4 + (x - 0.4) * 2.4, 0.6))
	S(ci, sp, 0.24, 1.0)
	O(ci, _u(r, 0.86, 0.4), ms * 0.1, 0.55)
	_gband(ci, r, 0.38, 0.42, 0.08, Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- M-14 / MF-126: baghouse dust collector
# a pulse-jet baghouse: the casing over its hopper, the filter bags hanging in it, the compressed-air
# tank on top and the blow pipe with its diaphragm valves over the bags, the hopper down to the rotary
# valve, the dusty inlet duct on the side, the clean outlet up to the fan, the legs
static func baghouse(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.12, 0.18, 0.8, 0.62))
	_rs(sg, sub(r, 0.38, 0.86, 0.54, 0.96))
	_rs(sg, sub(r, 0.0, 0.34, 0.12, 0.5))
	_hves(sg, sub(r, 0.16, 0.02, 0.6, 0.1), r.size.y * 0.04, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.62), _u(r, 0.38, 0.86), _u(r, 0.8, 0.62), _u(r, 0.54, 0.86),
		_u(r, 0.16, 0.14), _u(r, 0.78, 0.14), _u(r, 0.3, 0.1), _u(r, 0.3, 0.14), _u(r, 0.46, 0.1), _u(r, 0.46, 0.14),
		_u(r, 0.8, 0.26), _u(r, 0.94, 0.26), _u(r, 0.94, 0.26), _u(r, 0.94, 0.0),
		_u(r, 0.16, 0.62), _u(r, 0.16, 1.0), _u(r, 0.76, 0.62), _u(r, 0.76, 1.0)]))
	S(ci, sg, 0.55, 1.2)
	var bg := PackedVector2Array()
	for k in 6:
		var x: float = 0.2 + k * 0.105
		bg.append(_u(r, x, 0.22))
		bg.append(_u(r, x, 0.56))
	S(ci, bg, 0.3, 1.0)


# ---------------------------------------------------------------- FX-70 / HG-170: helium purifier
# the helium purifier: the liquid-nitrogen dewar (its neck and lid), the charcoal adsorber hung in it,
# the impure gas in and the clean gas out over the lid, the regeneration heater's lead, the small
# valve panel at its side (two valves)
static func he_purifier(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.06, 0.28, 0.66, 0.96), w * 0.14)
	_rs(sg, sub(r, 0.22, 0.14, 0.5, 0.18))
	_rs(sg, sub(r, 0.72, 0.3, 0.96, 0.62))
	sg.append_array(PackedVector2Array([_u(r, 0.26, 0.28), _u(r, 0.26, 0.18), _u(r, 0.46, 0.28), _u(r, 0.46, 0.18),
		_u(r, 0.3, 0.14), _u(r, 0.3, 0.04), _u(r, 0.3, 0.04), _u(r, 0.0, 0.04), _u(r, 0.42, 0.14), _u(r, 0.42, 0.08), _u(r, 0.42, 0.08), _u(r, 0.84, 0.08), _u(r, 0.84, 0.08), _u(r, 0.84, 0.3),
		_u(r, 0.76, 0.4), _u(r, 0.92, 0.4), _u(r, 0.76, 0.52), _u(r, 0.92, 0.52), _u(r, 0.48, 0.16), _u(r, 0.6, 0.0)]))
	S(ci, sg, 0.55, 1.1)
	var ad := PackedVector2Array()
	_rs(ad, sub(r, 0.24, 0.36, 0.48, 0.84))
	S(ci, ad, 0.28, 1.0)
	_gband(ci, r, 0.07, 0.65, 0.88, Pal.tint(Pal.AIR, 0.75))
	_gband(ci, r, 0.73, 0.95, 0.34, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- HG-170: filter bank (three lying canisters)
# a bank of three filter canisters lying one over another on their rack, each between the supply
# header and the outlet header with its isolating valve, the rack's foot
static func filter_bank3(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.02, 0.98), _u(r, 0.98, 0.98)])
	for k in 3:
		var y0: float = 0.06 + k * 0.31
		var yc: float = y0 + 0.1
		_hves(sg, sub(r, 0.22, y0, 0.78, y0 + 0.2), r.size.x * 0.06, 3)
		sg.append_array(PackedVector2Array([_u(r, 0.08, yc), _u(r, 0.22, yc), _u(r, 0.78, yc), _u(r, 0.92, yc),
			_u(r, 0.15, yc - 0.04), _u(r, 0.15, yc + 0.04), _u(r, 0.66, y0), _u(r, 0.66, y0 + 0.2)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.08, 0.02), _u(r, 0.08, 0.96), _u(r, 0.92, 0.02), _u(r, 0.92, 0.96)]), 0.55, 2.0)


# ---------------------------------------------------------------- MED-47 / CH-110: isolation-room filter
# the isolation room's bag-in/bag-out HEPA housing: the box, the tapered inlet and outlet transitions
# to their duct collars, the sealed access door and its four clamp handles, the pleated HEPA cartridge
# behind it, the change bag sealed on under the door, the magnehelic gauge, the two test ports, the
# air in
static func bibo_filter(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.14, 0.1, 0.86, 0.9))
	_rs(sg, sub(r, 0.28, 0.14, 0.72, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 0.14, 0.18), _u(r, 0.0, 0.7), _u(r, 0.14, 0.82), _u(r, 0.02, 0.3), _u(r, 0.02, 0.7),
		_u(r, 1.0, 0.3), _u(r, 0.86, 0.18), _u(r, 1.0, 0.7), _u(r, 0.86, 0.82), _u(r, 0.98, 0.3), _u(r, 0.98, 0.7),
		_u(r, 0.24, 0.24), _u(r, 0.28, 0.24), _u(r, 0.24, 0.76), _u(r, 0.28, 0.76), _u(r, 0.72, 0.24), _u(r, 0.76, 0.24), _u(r, 0.72, 0.76), _u(r, 0.76, 0.76),
		_u(r, 0.2, 0.9), _u(r, 0.2, 1.0), _u(r, 0.8, 0.9), _u(r, 0.8, 1.0)]))
	S(ci, sg, 0.55, 1.1)
	var pl := PackedVector2Array()
	for k in 6:
		var x0: float = 0.32 + k * 0.06
		pl.append_array(PackedVector2Array([_u(r, x0, 0.2), _u(r, x0 + 0.03, 0.8), _u(r, x0 + 0.03, 0.8), _u(r, x0 + 0.06, 0.2)]))
	S(ci, pl, 0.3, 1.0)
	_pu(ci, r, [Vector2(0.36, 0.9), Vector2(0.38, 0.98), Vector2(0.62, 0.98), Vector2(0.64, 0.9)], 0.38, 1.0)
	D(ci, _u(r, 0.8, 0.2), maxf(1.4, ms * 0.06), 0.6)
	_gband(ci, r, 0.0, 0.12, 0.5, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- OB-90: fan-filter unit
# a fan-filter unit: the fan housing on top (the impeller's ring and hub), the pleated HEPA panel
# under it, the prefilter under that, the clean air out of the face
static func fan_filter_unit(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.04, 0.92, 0.32))
	_rs(sg, sub(r, 0.08, 0.36, 0.92, 0.72))
	_rs(sg, sub(r, 0.08, 0.76, 0.92, 0.84))
	for x in [0.3, 0.5, 0.7]:
		sg.append(_u(r, x, 0.76))
		sg.append(_u(r, x, 0.84))
	for x in [0.3, 0.7]:
		sg.append_array(PackedVector2Array([_u(r, x, 0.86), _u(r, x, 0.98), _u(r, x - 0.05, 0.93), _u(r, x, 0.98), _u(r, x + 0.05, 0.93), _u(r, x, 0.98)]))
	S(ci, sg, 0.55, 1.1)
	var pl := PackedVector2Array()
	for k in 7:
		var x0: float = 0.1 + k * 0.114
		pl.append_array(PackedVector2Array([_u(r, x0, 0.38), _u(r, x0 + 0.057, 0.7), _u(r, x0 + 0.057, 0.7), _u(r, x0 + 0.114, 0.38)]))
	S(ci, pl, 0.4, 1.0)
	O(ci, _u(r, 0.5, 0.18), w * 0.16, 0.5)
	D(ci, _u(r, 0.5, 0.18), maxf(1.4, w * 0.04), 0.6)
	_gband(ci, r, 0.09, 0.91, 0.8, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- FL-116 / VT-80: duplex basket strainer
# a duplex basket strainer: the two bodies side by side (their lids on T-bolts, the baskets inside),
# the changeover plug valve between them and its lever, the inlet in under it and the outlet out over
# it, the drains, the base
static func duplex_strainer(ci: CanvasItem, r: Rect2) -> void:
	var q := _fitr(r, 1.05)
	var sg := PackedVector2Array()
	var bk := PackedVector2Array()
	for x0 in [0.06, 0.58]:
		_vves(sg, sub(q, x0, 0.22, x0 + 0.36, 0.84), q.size.x * 0.06, 3)
		sg.append_array(PackedVector2Array([_u(q, x0 - 0.02, 0.22), _u(q, x0 + 0.38, 0.22), _u(q, x0 + 0.06, 0.22), _u(q, x0 + 0.06, 0.16), _u(q, x0 + 0.3, 0.22), _u(q, x0 + 0.3, 0.16),
			_u(q, x0 + 0.18, 0.84), _u(q, x0 + 0.18, 0.9)]))
		_rs(bk, sub(q, x0 + 0.07, 0.32, x0 + 0.29, 0.7))
	_rs(sg, sub(q, 0.44, 0.44, 0.56, 0.6))
	sg.append_array(PackedVector2Array([_u(q, 0.42, 0.52), _u(q, 0.44, 0.52), _u(q, 0.56, 0.52), _u(q, 0.58, 0.52), _u(q, 0.5, 0.44), _u(q, 0.62, 0.34),
		_u(q, 0.5, 0.6), _u(q, 0.5, 0.94), _u(q, 0.5, 0.94), Vector2(r.position.x, q.position.y + q.size.y * 0.94),
		_u(q, 0.5, 0.44), _u(q, 0.5, 0.06), _u(q, 0.5, 0.06), Vector2(r.end.x, q.position.y + q.size.y * 0.06),
		_u(q, 0.02, 0.98), _u(q, 0.98, 0.98)]))
	S(ci, sg, 0.55, 1.2)
	S(ci, bk, 0.28, 1.0)


# ---------------------------------------------------------------- CH-110 / HB-86 / MF-126: water treatment skid
# the water treatment skid: the sand filter (its media bed), the softener column and its brine tank,
# the UV steriliser tube, the dosing pump and its chemical drum, the controller and its lamp, the
# pipework over them, the skid frame
static func water_treat_skid(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.04, 0.14, 0.26, 0.86), r.size.x * 0.03)
	_vves(sg, sub(r, 0.32, 0.2, 0.46, 0.86), r.size.x * 0.02)
	_rs(sg, sub(r, 0.5, 0.5, 0.66, 0.86))
	_hves(sg, sub(r, 0.7, 0.18, 0.96, 0.3), r.size.y * 0.03, 3)
	_rs(sg, sub(r, 0.72, 0.64, 0.82, 0.76))
	_rs(sg, sub(r, 0.84, 0.56, 0.96, 0.86))
	_rs(sg, sub(r, 0.7, 0.38, 0.86, 0.54))
	sg.append_array(PackedVector2Array([_u(r, 0.15, 0.06), _u(r, 0.83, 0.06), _u(r, 0.15, 0.06), _u(r, 0.15, 0.14), _u(r, 0.39, 0.06), _u(r, 0.39, 0.2),
		_u(r, 0.83, 0.06), _u(r, 0.83, 0.18), _u(r, 0.82, 0.7), _u(r, 0.84, 0.7), _u(r, 0.5, 0.62), _u(r, 0.66, 0.62),
		_u(r, 0.02, 0.9), _u(r, 0.98, 0.9), _u(r, 0.02, 0.96), _u(r, 0.98, 0.96)]))
	S(ci, sg, 0.55, 1.2)
	L(ci, _u(r, 0.04, 0.58), _u(r, 0.26, 0.58), 0.3)
	_gband(ci, r, 0.05, 0.25, 0.4, Pal.tint(Pal.FLUID, 0.7))
	_gband(ci, r, 0.72, 0.94, 0.24, Pal.tint(Pal.VOLT, 0.75))
	_lamp(ci, _u(r, 0.78, 0.46), maxf(1.6, ms * 0.03), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- DR-150: mud-gas separator (poor-boy degasser)
# the poor-boy degasser: the tall vessel on its legs, the baffle plates zigzagging down inside it,
# the inlet from the choke manifold on its side, the gas vent line up from the top, the inspection
# hatch, the mud leg's U-seal at the foot and the return over to the shakers, the mud's level
static func poorboy_degasser(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.24, 0.12, 0.64, 0.84), w * 0.1)
	_rs(sg, sub(r, 0.5, 0.54, 0.6, 0.64))
	for k in 4:
		var y: float = 0.28 + k * 0.1
		if k % 2 == 0:
			sg.append(_u(r, 0.24, y))
			sg.append(_u(r, 0.52, y + 0.03))
		else:
			sg.append(_u(r, 0.64, y))
			sg.append(_u(r, 0.36, y + 0.03))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.34), _u(r, 0.24, 0.34), _u(r, 0.06, 0.3), _u(r, 0.06, 0.38),
		_u(r, 0.28, 0.8), _u(r, 0.22, 0.98), _u(r, 0.6, 0.8), _u(r, 0.66, 0.98),
		_u(r, 0.44, 0.84), _u(r, 0.44, 0.94), _u(r, 0.44, 0.94), _u(r, 0.8, 0.94), _u(r, 0.8, 0.94), _u(r, 0.8, 0.7), _u(r, 0.8, 0.7), _u(r, 1.0, 0.7)]))
	S(ci, sg, 0.55, 1.2)
	L(ci, _u(r, 0.44, 0.12), _u(r, 0.44, 0.0), 0.55, 2.0)
	_gband(ci, r, 0.25, 0.63, 0.74, Pal.tint(Pal.FLUID, 0.7))
	_gband(ci, r, 0.4, 0.48, 0.02, Pal.heat(0.75))


# ---------------------------------------------------------------- RO-128: door hydraulic power unit
# the vehicle door's hydraulic power unit: the reservoir (its level glass, the breather on its lid),
# the motor-pump on the lid (the motor's fins, the bell housing, the pump, its suction), the stack
# of directional valves for the door rams (their solenoid stubs) with the hoses up out of it, the
# two piston accumulators beside it
static func door_hpu(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.56, 0.62, 0.96))
	_rs(sg, sub(r, 0.08, 0.66, 0.11, 0.88))
	_rs(sg, sub(r, 0.08, 0.3, 0.3, 0.54))
	_rs(sg, sub(r, 0.3, 0.36, 0.36, 0.5))
	_rs(sg, sub(r, 0.36, 0.38, 0.46, 0.48))
	_rs(sg, sub(r, 0.48, 0.18, 0.62, 0.54))
	sg.append_array(PackedVector2Array([_u(r, 0.08, 0.38), _u(r, 0.3, 0.38), _u(r, 0.08, 0.46), _u(r, 0.3, 0.46), _u(r, 0.41, 0.48), _u(r, 0.41, 0.56),
		_u(r, 0.5, 0.56), _u(r, 0.5, 0.5), _u(r, 0.52, 0.18), _u(r, 0.52, 0.02), _u(r, 0.58, 0.18), _u(r, 0.58, 0.02), _u(r, 0.68, 0.82), _u(r, 0.62, 0.82)]))
	for k in 3:
		var y: float = 0.24 + k * 0.1
		sg.append_array(PackedVector2Array([_u(r, 0.48, y + 0.06), _u(r, 0.62, y + 0.06), _u(r, 0.44, y), _u(r, 0.48, y), _u(r, 0.62, y), _u(r, 0.66, y)]))
	_vves(sg, sub(r, 0.7, 0.1, 0.82, 0.86), w * 0.04, 3)
	_vves(sg, sub(r, 0.86, 0.1, 0.98, 0.86), w * 0.04, 3)
	S(ci, sg, 0.55, 1.2)
	A(ci, _u(r, 0.5, 0.5), w * 0.03, PI, TAU, 0.55, 1.1)
	_gband(ci, r, 0.083, 0.107, 0.76, Pal.tint(Pal.FLUID, 0.9))
	_gband(ci, r, 0.71, 0.97, 0.16, Pal.tint(Pal.VOLT, 0.7))


# ---------------------------------------------------------------- CH-110 / RO-128 / TW-64 / H-22 / M-14: hydraulic power unit
# the main hydraulic power unit: the big reservoir (its baffle, level glass), the duty and standby
# motor-pump sets on its lid, the pressure line over to the manifold block (its relief valve and
# gauge) and the outlet lines, the plate cooler on the reservoir's face; where there is height to
# spare, two accumulators stand over it
static func main_hpu(ci: CanvasItem, r: Rect2) -> void:
	var q := _fitr(r, 1.5)
	var ms := minf(q.size.x, q.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(q, 0.02, 0.5, 0.98, 0.96))
	_rs(sg, sub(q, 0.9, 0.6, 0.93, 0.86))
	_rs(sg, sub(q, 0.74, 0.24, 0.92, 0.4))
	_rs(sg, sub(q, 0.56, 0.6, 0.84, 0.8))
	for x0 in [0.06, 0.38]:
		_rs(sg, sub(q, x0, 0.26, x0 + 0.18, 0.48))
		_rs(sg, sub(q, x0 + 0.2, 0.32, x0 + 0.28, 0.44))
		sg.append_array(PackedVector2Array([_u(q, x0, 0.34), _u(q, x0 + 0.18, 0.34), _u(q, x0, 0.41), _u(q, x0 + 0.18, 0.41),
			_u(q, x0 + 0.18, 0.37), _u(q, x0 + 0.2, 0.37), _u(q, x0 + 0.24, 0.44), _u(q, x0 + 0.24, 0.5),
			_u(q, x0 + 0.24, 0.32), _u(q, x0 + 0.24, 0.18)]))
	sg.append_array(PackedVector2Array([_u(q, 0.3, 0.18), _u(q, 0.83, 0.18), _u(q, 0.83, 0.18), _u(q, 0.83, 0.24),
		_u(q, 0.8, 0.24), _u(q, 0.8, 0.12), _u(q, 0.92, 0.29), Vector2(r.end.x, q.position.y + q.size.y * 0.29), _u(q, 0.92, 0.35), Vector2(r.end.x, q.position.y + q.size.y * 0.35),
		_u(q, 0.5, 0.56), _u(q, 0.5, 0.92)]))
	for k in 4:
		var x: float = 0.6 + k * 0.06
		sg.append(_u(q, x, 0.6))
		sg.append(_u(q, x, 0.8))
	if r.size.y > q.size.y * 1.3:
		var top := Rect2(r.position, Vector2(r.size.x, q.position.y - r.position.y))
		_vves(sg, sub(top, 0.2, 0.06, 0.36, 0.94), r.size.x * 0.03, 3)
		_vves(sg, sub(top, 0.62, 0.06, 0.78, 0.94), r.size.x * 0.03, 3)
	S(ci, sg, 0.55, 1.2)
	D(ci, _u(q, 0.86, 0.32), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, q, 0.903, 0.927, 0.72, Pal.tint(Pal.FLUID, 0.9))


# ---------------------------------------------------------------- TW-64: motor-pump set
# a hydraulic motor-pump set on its base frame: the electric motor (its fins, the fan cowl, the
# terminal box), the bell housing to the axial piston pump and its pressure compensator (the
# adjusting screw), the suction hose down and the pressure hose up and out, the anti-vibration
# mounts, the drip tray under it all
static func motor_pump_set(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.74, 0.98, 0.84))
	_rs(sg, sub(r, 0.04, 0.3, 0.44, 0.72))
	_rs(sg, sub(r, 0.0, 0.36, 0.04, 0.66))
	_rs(sg, sub(r, 0.18, 0.2, 0.3, 0.3))
	_rs(sg, sub(r, 0.56, 0.4, 0.8, 0.62))
	_rs(sg, sub(r, 0.64, 0.3, 0.74, 0.4))
	sg.append_array(PackedVector2Array([_u(r, 0.44, 0.36), _u(r, 0.56, 0.42), _u(r, 0.44, 0.66), _u(r, 0.56, 0.6),
		_u(r, 0.69, 0.3), _u(r, 0.69, 0.24), _u(r, 0.8, 0.56), _u(r, 0.9, 0.56), _u(r, 0.9, 0.56), _u(r, 0.94, 0.74),
		_u(r, 0.0, 0.92), _u(r, 1.0, 0.92), _u(r, 0.0, 0.92), _u(r, 0.0, 0.88), _u(r, 1.0, 0.92), _u(r, 1.0, 0.88)]))
	for y in [0.4, 0.48, 0.56, 0.64]:
		sg.append(_u(r, 0.06, y))
		sg.append(_u(r, 0.42, y))
	for x in [0.1, 0.4, 0.6, 0.9]:
		sg.append(_u(r, x, 0.84))
		sg.append(_u(r, x, 0.9))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.76, 0.4), _u(r, 0.86, 0.18), _u(r, 0.86, 0.18), _u(r, 1.0, 0.18)]), 0.55, 1.8)
	_gband(ci, r, 0.88, 0.98, 0.15, Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- ARK-01 / SP-FLUID / VT-80: cross-connection manifold
# the cross-connection manifold: the two mains (port and starboard) along its top and foot and the
# three cross-connections between them, each with its gate valve (body, stem, handwheel) and its
# spectacle blind, the gauges on the mains; as a long run (VT-80) the main with its cross tees
static func cross_manifold(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	if r.size.x > r.size.y * 8.0:
		sg.append_array(PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 1.0, 0.3), _u(r, 0.0, 0.7), _u(r, 1.0, 0.7)]))
		var n := clampi(int(r.size.x / 160.0), 2, 16)
		for k in n:
			var x: float = (k + 0.5) / n
			var dx: float = 6.0 / r.size.x
			sg.append_array(PackedVector2Array([_u(r, x - dx, 0.0), _u(r, x - dx, 0.3), _u(r, x + dx, 0.0), _u(r, x + dx, 0.3),
				_u(r, x - dx * 2.0, 0.12), _u(r, x + dx * 2.0, 0.12), _u(r, x + dx * 4.0, 0.7), _u(r, x + dx * 4.0, 1.0)]))
		S(ci, sg, 0.55, 1.2)
		_gband(ci, r, 0.0, 0.02, 0.45, Pal.tint(Pal.FLUID, 0.75))
		return
	for y in [0.12, 0.2, 0.8, 0.88]:
		sg.append(_u(r, 0.02, y))
		sg.append(_u(r, 0.98, y))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.08), _u(r, 0.02, 0.24), _u(r, 0.98, 0.08), _u(r, 0.98, 0.24), _u(r, 0.02, 0.76), _u(r, 0.02, 0.92), _u(r, 0.98, 0.76), _u(r, 0.98, 0.92)]))
	for x in [0.22, 0.5, 0.78]:
		sg.append_array(PackedVector2Array([_u(r, x - 0.02, 0.2), _u(r, x - 0.02, 0.8), _u(r, x + 0.02, 0.2), _u(r, x + 0.02, 0.8),
			_u(r, x + 0.05, 0.48), _u(r, x + 0.1, 0.48), _u(r, x + 0.1, 0.42), _u(r, x + 0.1, 0.54)]))
		_rs(sg, sub(r, x - 0.05, 0.4, x + 0.05, 0.56))
		sg.append(_u(r, x - 0.04, 0.655))
		sg.append(_u(r, x + 0.04, 0.655))
	S(ci, sg, 0.55, 1.2)
	for p in [Vector2(0.36, 0.16), Vector2(0.64, 0.84)]:
		D(ci, _u(r, p.x, p.y), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.04, 0.16, 0.16, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- ARK-01 (x14) / VT-80: main valve group
# the main valve pair on its riser: the riser up through, its two gate valves (bodies, the flange
# pairs, the bonnets and handwheels), the bypass round them with its globe valve
static func main_valve_pair(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.5, 0.12), _u(r, 0.18, 0.12), _u(r, 0.18, 0.12), _u(r, 0.18, 0.46), _u(r, 0.18, 0.56), _u(r, 0.18, 0.88), _u(r, 0.18, 0.88), _u(r, 0.5, 0.88)])
	_rs(sg, sub(r, 0.12, 0.46, 0.24, 0.56))
	for y0 in [0.22, 0.62]:
		_rs(sg, sub(r, 0.38, y0, 0.62, y0 + 0.16))
		sg.append_array(PackedVector2Array([_u(r, 0.62, y0 + 0.08), _u(r, 0.8, y0 + 0.08), _u(r, 0.8, y0 + 0.02), _u(r, 0.8, y0 + 0.14)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.0), _u(r, 0.5, 0.22), _u(r, 0.5, 0.38), _u(r, 0.5, 0.62), _u(r, 0.5, 0.78), _u(r, 0.5, 1.0)]), 0.55, 2.2)


# ---------------------------------------------------------------- FL-116 / MF-126: precision distribution manifold
# the precision distribution manifold: the supply header along its foot, the block manifold over
# it, the row of outlets — each a needle valve and its handle under a rotameter (tube, float) — with
# their lines up and out, the filter-regulator at the inlet and its gauge
static func precision_manifold(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.12, 0.72, 0.92, 0.84))
	_rs(sg, sub(r, 0.02, 0.6, 0.1, 0.84))
	var n := clampi(int(r.size.x * 0.8 / 40.0), 3, 10)
	var fl := PackedVector2Array()
	for k in n:
		var x: float = 0.16 + (k + 0.5) * 0.72 / n
		var dx: float = 0.18 / n
		sg.append_array(PackedVector2Array([_u(r, x, 0.72), _u(r, x, 0.54), _u(r, x - dx, 0.62), _u(r, x + dx, 0.62),
			_u(r, x - dx * 0.6, 0.24), _u(r, x - dx * 0.6, 0.54), _u(r, x + dx * 0.6, 0.24), _u(r, x + dx * 0.6, 0.54), _u(r, x, 0.24), _u(r, x, 0.04)]))
		var yf: float = 0.3 + 0.18 * float((k * 5) % 3) / 2.0
		fl.append(_u(r, x - dx * 0.6, yf))
		fl.append(_u(r, x + dx * 0.6, yf))
	S(ci, sg, 0.55, 1.1)
	S(ci, fl, 0.7, 2.0)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.9), _u(r, 0.98, 0.9)]), 0.55, 2.2)
	D(ci, _u(r, 0.06, 0.54), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.12, 0.92, 0.94, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- CH-110 / H-22: tow-arm valve block
# the tow arm's hydraulic valve block: the mounting plate, the steel block, the three directional
# valves stacked on it (each body between its two solenoid coils, its manual override lever), the
# A/B work ports out of the side, the pressure gauge
static func tow_valve_block(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.78, 0.98, 0.96))
	_rs(sg, sub(r, 0.06, 0.52, 0.9, 0.78))
	for k in 3:
		var x0: float = 0.08 + k * 0.28
		_rs(sg, sub(r, x0 + 0.06, 0.28, x0 + 0.2, 0.52))
		_rs(sg, sub(r, x0, 0.32, x0 + 0.06, 0.48))
		_rs(sg, sub(r, x0 + 0.2, 0.32, x0 + 0.26, 0.48))
		sg.append(_u(r, x0 + 0.13, 0.28))
		sg.append(_u(r, x0 + 0.18, 0.12))
	sg.append_array(PackedVector2Array([_u(r, 0.9, 0.58), _u(r, 1.0, 0.58), _u(r, 0.9, 0.7), _u(r, 1.0, 0.7)]))
	S(ci, sg, 0.55, 1.2)
	D(ci, _u(r, 0.14, 0.65), maxf(1.6, ms * 0.06), 0.6)
	_gband(ci, r, 0.07, 0.89, 0.6, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- BL-88: irrigation spray line
# the irrigation line hung under the deckhead: the pipe, its two hangers, the drop nozzles along it
# and their spray fans
static func sprinkler_line(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.26), _u(r, 1.0, 0.26), _u(r, 0.0, 0.4), _u(r, 1.0, 0.4), _u(r, 0.22, 0.0), _u(r, 0.22, 0.26), _u(r, 0.78, 0.0), _u(r, 0.78, 0.26)])
	var sp := PackedVector2Array()
	for x in [0.1, 0.36, 0.62, 0.88]:
		sg.append(_u(r, x, 0.4))
		sg.append(_u(r, x, 0.58))
		sp.append_array(PackedVector2Array([_u(r, x, 0.6), _u(r, x - 0.05, 0.98), _u(r, x, 0.6), _u(r, x + 0.05, 0.98)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, sp, 0.26, 1.0)


# ---------------------------------------------------------------- BL-88: water main
# the water main: the large pipe through, its flanged joint, the gate valve in it (body and wedge),
# the two saddle supports, the water's colour
static func water_main(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.12), _u(r, 1.0, 0.12), _u(r, 0.0, 0.78), _u(r, 1.0, 0.78),
		_u(r, 0.3, 0.02), _u(r, 0.3, 0.88), _u(r, 0.33, 0.02), _u(r, 0.33, 0.88),
		_u(r, 0.62, 0.12), _u(r, 0.74, 0.78), _u(r, 0.62, 0.78), _u(r, 0.74, 0.12), _u(r, 0.62, 0.02), _u(r, 0.62, 0.88), _u(r, 0.74, 0.02), _u(r, 0.74, 0.88),
		_u(r, 0.12, 0.78), _u(r, 0.1, 1.0), _u(r, 0.86, 0.78), _u(r, 0.88, 1.0)])
	S(ci, sg, 0.55, 1.2)
	_gband(ci, r, 0.04, 0.26, 0.44, Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- DC-84 (x12): rack coolant manifold
# the rack row's coolant manifold: the supply and return tubes one over the other, their end caps,
# the quick-disconnect tap-offs down to each rack (supply and return side by side), supply cold and
# return warm
static func rack_coolant_manifold(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.02, 0.06), _u(r, 0.02, 0.62), _u(r, 0.98, 0.06), _u(r, 0.98, 0.62)])
	for k in 3:
		var x: float = 0.2 + k * 0.28
		sg.append_array(PackedVector2Array([_u(r, x, 0.18), _u(r, x, 0.98), _u(r, x + 0.06, 0.5), _u(r, x + 0.06, 0.98), _u(r, x - 0.02, 0.82), _u(r, x + 0.08, 0.82)]))
	S(ci, sg, 0.5, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.02, 0.18), _u(r, 0.98, 0.18), _u(r, 0.02, 0.5), _u(r, 0.98, 0.5)]), 0.55, 2.4)
	_gband(ci, r, 0.04, 0.14, 0.02, Pal.tint(Pal.AIR, 0.85))
	_gband(ci, r, 0.04, 0.14, 0.34, Pal.heat(0.8))


# ---------------------------------------------------------------- DR-150 (x6): high-pressure mud line
# the high-pressure mud line: the heavy-walled pipe, its two hammer unions (the wing nut and its
# lugs), the swivel elbow at the end
static func mud_line(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	for x in [0.28, 0.6]:
		_rs(sg, sub(r, x, 0.06, x + 0.06, 0.94))
		sg.append_array(PackedVector2Array([_u(r, x, 0.06), _u(r, x - 0.03, 0.0), _u(r, x + 0.06, 0.94), _u(r, x + 0.09, 1.0)]))
	_rs(sg, sub(r, 0.86, 0.1, 0.98, 0.9))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.24), _u(r, 0.86, 0.24), _u(r, 0.0, 0.76), _u(r, 0.86, 0.76)]), 0.55, 1.8)
	_gband(ci, r, 0.02, 0.24, 0.5, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- FX-70 / HG-170 (x6): helium tubes
# the helium transfer tubes: the supply and return tubes side by side in their tray, the tube clips
# along them, the bend up at the end, the gas's colour
static func he_tube_pair(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.9), _u(r, 1.0, 0.9), _u(r, 0.0, 0.72), _u(r, 0.0, 0.9), _u(r, 1.0, 0.72), _u(r, 1.0, 0.9),
		_u(r, 0.0, 0.3), _u(r, 0.9, 0.3), _u(r, 0.0, 0.56), _u(r, 0.86, 0.56), _u(r, 0.9, 0.3), _u(r, 0.96, 0.04), _u(r, 0.86, 0.56), _u(r, 0.92, 0.04)])
	for x in [0.22, 0.5, 0.78]:
		sg.append(_u(r, x, 0.2))
		sg.append(_u(r, x, 0.66))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.04, 0.16, 0.08, Pal.tint(Pal.VOLT, 0.8))


# ---------------------------------------------------------------- LC-140: braided flexible line
# the small craft's braided flexible line: the hose sagging between its two end fittings (their hex
# nuts), the braid's lay along it, the P-clip that holds it
static func braided_hose(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.0, 0.26, 0.1, 0.66))
	_rs(sg, sub(r, 0.9, 0.26, 1.0, 0.66))
	_rs(sg, sub(r, 0.46, 0.5, 0.54, 0.98))
	S(ci, sg, 0.55, 1.1)
	_pu(ci, r, [Vector2(0.1, 0.32), Vector2(0.3, 0.5), Vector2(0.5, 0.56), Vector2(0.7, 0.5), Vector2(0.9, 0.32)], 0.55, 1.1)
	_pu(ci, r, [Vector2(0.1, 0.6), Vector2(0.3, 0.8), Vector2(0.5, 0.86), Vector2(0.7, 0.8), Vector2(0.9, 0.6)], 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.2, 0.44), _u(r, 0.24, 0.66), _u(r, 0.36, 0.52), _u(r, 0.4, 0.8), _u(r, 0.62, 0.53), _u(r, 0.66, 0.79), _u(r, 0.78, 0.46), _u(r, 0.82, 0.68)]), 0.26, 1.0)


# ---------------------------------------------------------------- DR-150 / HG-170 / LC-140: double-walled fuel main
# the double-walled fuel main: the outer jacket and the fuel line inside it, the flanged joint and
# its bonding jumper, the leak-detection port off the jacket, the fuel's colour
static func fuel_main_dw(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.1), _u(r, 1.0, 0.1), _u(r, 0.0, 0.9), _u(r, 1.0, 0.9),
		_u(r, 0.4, 0.0), _u(r, 0.4, 1.0), _u(r, 0.43, 0.0), _u(r, 0.43, 1.0), _u(r, 0.37, 0.96), _u(r, 0.46, 0.96),
		_u(r, 0.74, 0.1), _u(r, 0.74, 0.0), _u(r, 0.71, 0.0), _u(r, 0.77, 0.0)])
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.36), _u(r, 1.0, 0.36), _u(r, 0.0, 0.64), _u(r, 1.0, 0.64)]), 0.3, 1.0)
	_gband(ci, r, 0.06, 0.32, 0.5, Pal.heat(0.75))


# ---------------------------------------------------------------- VT-80: pressurising header (the long run)
# the pressurising header's long run: the pipe, the branch tees up to the deck at intervals (each with
# its isolating valve), the supports under it, the gas's colour on every other length
static func n2_header_pipe(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.32), _u(r, 1.0, 0.32), _u(r, 0.0, 0.64), _u(r, 1.0, 0.64)])
	var n := clampi(int(r.size.x / 150.0), 1, 14)
	var dx: float = 4.0 / r.size.x
	for k in n:
		var x: float = (k + 0.5) / n
		sg.append_array(PackedVector2Array([_u(r, x, 0.32), _u(r, x, 0.0), _u(r, x - dx, 0.08), _u(r, x + dx, 0.22), _u(r, x + dx, 0.08), _u(r, x - dx, 0.22),
			_u(r, x + 0.25 / n, 0.64), _u(r, x + 0.25 / n, 1.0)]))
	S(ci, sg, 0.55, 1.1)
	for k in range(0, n, 2):
		var x: float = (k + 0.5) / n
		_gband(ci, r, x + 0.05 / n, x + 0.2 / n, 0.44, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- OB-90: vacuum-jacketed cryo line
# the vacuum-jacketed cryogenic line: the outer jacket (its ends) and the inner line on its spacers,
# the bayonet collars at both ends, the vacuum pump-out port, the cold's colour
static func vj_cryo_line(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.06, 0.1), _u(r, 0.94, 0.1), _u(r, 0.06, 0.9), _u(r, 0.94, 0.9), _u(r, 0.06, 0.1), _u(r, 0.06, 0.9), _u(r, 0.94, 0.1), _u(r, 0.94, 0.9),
		_u(r, 0.5, 0.1), _u(r, 0.5, 0.0), _u(r, 0.46, 0.0), _u(r, 0.54, 0.0)])
	_rs(sg, sub(r, 0.02, 0.24, 0.06, 0.76))
	_rs(sg, sub(r, 0.94, 0.24, 0.98, 0.76))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.42), _u(r, 1.0, 0.42), _u(r, 0.0, 0.58), _u(r, 1.0, 0.58), _u(r, 0.3, 0.1), _u(r, 0.3, 0.42), _u(r, 0.7, 0.58), _u(r, 0.7, 0.9)]), 0.3, 1.0)
	_gband(ci, r, 0.62, 0.9, 0.5, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- VT-80: riser
# a vertical riser: the pipe, its two flanged joints, the expansion bellows (its convolutions), the
# two guide brackets out to the wall, the drain at the foot, the fluid's colour
static func riser_pipe(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.3, 0.0), _u(r, 0.3, 0.45), _u(r, 0.7, 0.0), _u(r, 0.7, 0.45), _u(r, 0.3, 0.55), _u(r, 0.3, 1.0), _u(r, 0.7, 0.55), _u(r, 0.7, 1.0),
		_u(r, 0.7, 0.15), _u(r, 1.0, 0.15), _u(r, 0.7, 0.66), _u(r, 1.0, 0.66), _u(r, 0.3, 0.95), _u(r, 0.0, 0.95)])
	for y in [0.25, 0.26, 0.75, 0.76]:
		sg.append(_u(r, 0.14, y))
		sg.append(_u(r, 0.86, y))
	for y in [0.46, 0.49, 0.52, 0.55]:
		sg.append(_u(r, 0.2, y))
		sg.append(_u(r, 0.8, y))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.32, 0.68, 0.36, Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- SP-CRYO: pipe-rack post
# a pipe-rack post: the I-section column (its two flanges and the web), the base plate and its two
# anchor bolts, the two cantilever arms and the U-bolts' bars over the pipes they carry
static func rack_post(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.2, 0.0), _u(r, 0.2, 0.96), _u(r, 0.8, 0.0), _u(r, 0.8, 0.96), _u(r, -0.2, 0.97), _u(r, 1.2, 0.97),
		_u(r, 0.0, 0.2), _u(r, 1.0, 0.2), _u(r, 0.0, 0.55), _u(r, 1.0, 0.55)])
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.2, 0.17), _u(r, 0.8, 0.17), _u(r, 0.2, 0.52), _u(r, 0.8, 0.52)]), 0.5, 1.0)
	_gband(ci, r, 0.25, 0.75, 0.4, Pal.tint(Pal.AIR, 0.75))


# ================================================================ E380–E425 (2026-11-13): tenth batch, part one
# the pumps (each by its real machine: multistage, vertical inline, wet-rotor circulator, split case,
# self-priming, vacuum-primed, diaphragm, peristaltic, gear, long-shaft tank pump, submersible,
# cryogenic submerged, screw and piston compressors, grease pump, booster set, portable damage-control
# pump ...) and the radiators (deployable wings, petals, mirror-tile plates, cold plates, a Stirling
# cooler, a heater pad ...)

# a TEFC motor seen from the side: its body, the fan cowl at one end, the cooling fins, the terminal box
static func _mot(sg: PackedVector2Array, q: Rect2, cowl_right: bool = true) -> void:
	_rs(sg, q)
	var cx: float = q.end.x - q.size.x * 0.16 if cowl_right else q.position.x + q.size.x * 0.16
	sg.append(Vector2(cx, q.position.y))
	sg.append(Vector2(cx, q.end.y))
	var x0: float = q.position.x + q.size.x * 0.06 if cowl_right else cx
	var x1: float = cx if cowl_right else q.end.x - q.size.x * 0.06
	for k in 3:
		var y: float = q.position.y + q.size.y * (0.28 + k * 0.22)
		sg.append(Vector2(x0, y))
		sg.append(Vector2(x1, y))
	_rs(sg, Rect2(Vector2(q.position.x + q.size.x * 0.36, q.position.y - q.size.y * 0.2), Vector2(q.size.x * 0.2, q.size.y * 0.2)))


# a motor standing upright: its body, the fan cowl on top, two fin lines, the terminal box on its side
static func _vmot(sg: PackedVector2Array, q: Rect2) -> void:
	_rs(sg, q)
	var cy: float = q.position.y + q.size.y * 0.16
	sg.append_array(PackedVector2Array([Vector2(q.position.x, cy), Vector2(q.end.x, cy),
		Vector2(q.position.x + q.size.x * 0.33, cy), Vector2(q.position.x + q.size.x * 0.33, q.end.y - q.size.y * 0.06),
		Vector2(q.position.x + q.size.x * 0.67, cy), Vector2(q.position.x + q.size.x * 0.67, q.end.y - q.size.y * 0.06)]))
	_rs(sg, Rect2(Vector2(q.end.x, q.position.y + q.size.y * 0.4), Vector2(q.size.x * 0.22, q.size.y * 0.2)))


# a centrifugal pump's volute: the spiral casing (its growing radius), its discharge nozzle up, the
# impeller's swept vanes inside
static func _vol(sg: PackedVector2Array, c: Vector2, rad: float) -> void:
	var pv := c + Vector2(rad * 0.72, 0)
	for k in range(1, 9):
		var a: float = TAU * k / 9.0
		var q := c + Vector2(cos(a), sin(a)) * rad * (0.72 + 0.28 * k / 8.0)
		sg.append(pv)
		sg.append(q)
		pv = q
	sg.append_array(PackedVector2Array([pv, c + Vector2(rad * 0.8, -rad * 1.5), c + Vector2(0.0, -rad * 0.75), c + Vector2(0.0, -rad * 1.5),
		c + Vector2(-rad * 0.15, -rad * 1.5), c + Vector2(rad * 0.95, -rad * 1.5)]))
	# the impeller inside: its swept vanes off the hub
	for k in 6:
		var a: float = TAU * k / 6.0
		sg.append(c + Vector2.from_angle(a) * rad * 0.16)
		sg.append(c + Vector2.from_angle(a + 0.7) * rad * 0.56)


# ---------------------------------------------------------------- ARK-01: boiler feed pump (multistage)
# a multistage ring-section feed pump on its baseplate: the suction casing, the stage rings and the
# tie rods along them, the discharge casing, both nozzles up with flanges, the bearing housings, the
# coupling guard, the motor; the hot water's colour on the discharge
static func feed_pump_ms(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.84, 0.98, 0.92))
	_rs(sg, sub(r, 0.06, 0.28, 0.14, 0.8))
	_rs(sg, sub(r, 0.42, 0.28, 0.5, 0.8))
	_rs(sg, sub(r, 0.52, 0.44, 0.6, 0.64))
	_mot(sg, sub(r, 0.6, 0.34, 0.96, 0.8))
	for x in [0.2, 0.27, 0.34]:
		sg.append(_u(r, x, 0.36))
		sg.append(_u(r, x, 0.72))
	sg.append_array(PackedVector2Array([_u(r, 0.14, 0.36), _u(r, 0.42, 0.36), _u(r, 0.14, 0.72), _u(r, 0.42, 0.72),
		_u(r, 0.1, 0.28), _u(r, 0.1, 0.12), _u(r, 0.06, 0.12), _u(r, 0.14, 0.12), _u(r, 0.46, 0.28), _u(r, 0.46, 0.12), _u(r, 0.42, 0.12), _u(r, 0.5, 0.12),
		_u(r, 0.02, 0.5), _u(r, 0.06, 0.5), _u(r, 0.1, 0.8), _u(r, 0.1, 0.84), _u(r, 0.46, 0.8), _u(r, 0.46, 0.84)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.43, 0.49, 0.2, Pal.heat(0.75))


# ---------------------------------------------------------------- ARK-01: lube oil skid
# the turbine's lube oil console: the reservoir and its level glass, the two vertical motor-pumps on its
# lid (duty and standby), the pressure line over to the duplex filter (its two bowls and changeover
# lever) and on into the plate cooler (its plates), the oil's colour
static func lube_skid(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.5, 0.62, 0.94))
	_rs(sg, sub(r, 0.05, 0.6, 0.08, 0.86))
	for x in [0.12, 0.36]:
		_vmot(sg, sub(r, x, 0.12, x + 0.12, 0.38))
		_rs(sg, sub(r, x + 0.02, 0.38, x + 0.1, 0.5))
	_vves(sg, sub(r, 0.66, 0.3, 0.74, 0.62), r.size.x * 0.02, 3)
	_vves(sg, sub(r, 0.78, 0.3, 0.86, 0.62), r.size.x * 0.02, 3)
	_rs(sg, sub(r, 0.9, 0.2, 0.98, 0.76))
	for k in 4:
		var y: float = 0.3 + k * 0.11
		sg.append(_u(r, 0.9, y))
		sg.append(_u(r, 0.98, y))
	sg.append_array(PackedVector2Array([_u(r, 0.18, 0.06), _u(r, 0.18, 0.12), _u(r, 0.42, 0.06), _u(r, 0.42, 0.12), _u(r, 0.18, 0.06), _u(r, 0.76, 0.06), _u(r, 0.76, 0.06), _u(r, 0.76, 0.3),
		_u(r, 0.74, 0.46), _u(r, 0.78, 0.46), _u(r, 0.76, 0.3), _u(r, 0.82, 0.22), _u(r, 0.86, 0.46), _u(r, 0.9, 0.46), _u(r, 0.94, 0.76), _u(r, 0.94, 0.86), _u(r, 0.94, 0.86), _u(r, 0.62, 0.86)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.052, 0.078, 0.7, Pal.tint(Pal.FLUID, 0.9))


# ---------------------------------------------------------------- ARK-01 (x29): main line pump (vertical inline)
# a vertical inline pump in its line: the pipe through at the foot (its flanges and their bolts), the
# inline casing and the impeller's sweep in it, the lantern (its window), the upright motor on top (its
# cowl, fins, terminal box, lifting eye), the gauges on the suction and discharge, the drain
static func inline_vpump(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.76), _u(r, 0.36, 0.76), _u(r, 0.64, 0.76), _u(r, 1.0, 0.76), _u(r, 0.0, 0.88), _u(r, 0.36, 0.88), _u(r, 0.64, 0.88), _u(r, 1.0, 0.88),
		_u(r, 0.33, 0.72), _u(r, 0.33, 0.92), _u(r, 0.67, 0.72), _u(r, 0.67, 0.92), _u(r, 0.44, 0.52), _u(r, 0.44, 0.64), _u(r, 0.56, 0.52), _u(r, 0.56, 0.64)])
	_rs(sg, sub(r, 0.36, 0.64, 0.64, 0.96))
	_vmot(sg, sub(r, 0.34, 0.06, 0.62, 0.52))
	_arcs(sg, _u(r, 0.5, 0.86), r.size.x * 0.1, r.size.y * 0.05, PI, TAU, 4)
	sg.append_array(PackedVector2Array([_u(r, 0.33, 0.68), _u(r, 0.33, 0.66), _u(r, 0.67, 0.68), _u(r, 0.67, 0.66), _u(r, 0.33, 0.94), _u(r, 0.33, 0.96), _u(r, 0.67, 0.94), _u(r, 0.67, 0.96),
		_u(r, 0.22, 0.76), _u(r, 0.22, 0.62), _u(r, 0.78, 0.76), _u(r, 0.78, 0.62), _u(r, 0.5, 0.96), _u(r, 0.5, 1.0), _u(r, 0.44, 0.06), _u(r, 0.48, 0.02), _u(r, 0.48, 0.02), _u(r, 0.52, 0.06)]))
	S(ci, sg, 0.55, 1.1)
	for x in [0.22, 0.78]:
		D(ci, _u(r, x, 0.58), maxf(1.4, r.size.y * 0.04), 0.6)
	_gband(ci, r, 0.02, 0.3, 0.82, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- ARK-01 (x6): wet-rotor circulator
# a wet-rotor circulator between its two isolating valves: the pipe and its unions, the small inline
# body, the round motor head (its rim), the control box and its lamp
static func circulator(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.0, 0.74), _u(r, 0.32, 0.74), _u(r, 0.68, 0.74), _u(r, 1.0, 0.74), _u(r, 0.0, 0.84), _u(r, 0.32, 0.84), _u(r, 0.68, 0.84), _u(r, 1.0, 0.84),
		_u(r, 0.08, 0.7), _u(r, 0.2, 0.88), _u(r, 0.08, 0.88), _u(r, 0.2, 0.7), _u(r, 0.8, 0.7), _u(r, 0.92, 0.88), _u(r, 0.8, 0.88), _u(r, 0.92, 0.7)])
	_rs(sg, sub(r, 0.32, 0.64, 0.68, 0.92))
	_rs(sg, sub(r, 0.66, 0.2, 0.9, 0.42))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.48, 0.38), ms * 0.24, 0.55, 1.2)
	O(ci, _u(r, 0.48, 0.38), ms * 0.15, 0.4)
	var vn := PackedVector2Array([_u(r, 0.42, 0.79), _u(r, 0.58, 0.79), _u(r, 0.58, 0.79), _u(r, 0.54, 0.75), _u(r, 0.58, 0.79), _u(r, 0.54, 0.83), _u(r, 0.9, 0.34), _u(r, 1.0, 0.2)])
	for k in 5:
		var a: float = TAU * k / 5.0
		vn.append(_u(r, 0.48, 0.38) + Vector2.from_angle(a) * ms * 0.03)
		vn.append(_u(r, 0.48, 0.38) + Vector2.from_angle(a + 0.8) * ms * 0.13)
	S(ci, vn, 0.45, 1.0)
	_lamp(ci, _u(r, 0.78, 0.31), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- IH-55: air-bag blower and valve manifold
# the lifting bags' inflation set: the side-channel blower (its round housing) on its motor, the air
# header and its four valves, each hose down to a bag coupling, the relief valve and the gauge
static func bag_blower(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.86, 0.5, 0.94))
	_mot(sg, sub(r, 0.24, 0.5, 0.48, 0.84), true)
	sg.append_array(PackedVector2Array([_u(r, 0.13, 0.4), _u(r, 0.13, 0.12), _u(r, 0.13, 0.12), _u(r, 0.96, 0.12)]))
	for k in 4:
		var x: float = 0.4 + k * 0.16
		sg.append_array(PackedVector2Array([_u(r, x, 0.12), _u(r, x, 0.34), _u(r, x - 0.04, 0.22), _u(r, x + 0.04, 0.22)]))
	_rs(sg, sub(r, 0.9, 0.04, 0.98, 0.12))
	S(ci, sg, 0.55, 1.2)
	var hs := PackedVector2Array()
	for k in 4:
		var x: float = 0.4 + k * 0.16
		hs.append_array(PackedVector2Array([_u(r, x, 0.34), _u(r, x + 0.04, 0.62), _u(r, x + 0.04, 0.62), _u(r, x, 0.92)]))
	S(ci, hs, 0.4, 1.6)
	O(ci, _u(r, 0.13, 0.62), ms * 0.2, 0.55, 1.2)
	D(ci, _u(r, 0.13, 0.62), maxf(1.4, ms * 0.04), 0.6)
	D(ci, _u(r, 0.28, 0.12), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.16, 0.36, 0.08, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- RO-128: ballast pump with vacuum priming
# the ballast pump set: the horizontal centrifugal pump and its motor on the base, the suction in at the
# end, the discharge up, and the vacuum priming system on its back: the separator tank over the
# casing, the small vacuum pump and its motor, the air line from the tank
static func ballast_primed(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.86, 0.98, 0.94))
	_vol(sg, _u(r, 0.18, 0.6), r.size.y * 0.2)
	_rs(sg, sub(r, 0.26, 0.54, 0.4, 0.68))
	_rs(sg, sub(r, 0.4, 0.56, 0.46, 0.66))
	_mot(sg, sub(r, 0.46, 0.44, 0.84, 0.84))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.6), _u(r, 0.1, 0.6), _u(r, 0.18, 0.8), _u(r, 0.18, 0.86), _u(r, 0.33, 0.68), _u(r, 0.33, 0.86)]))
	_vves(sg, sub(r, 0.24, 0.06, 0.36, 0.3), r.size.x * 0.01, 3)
	_rs(sg, sub(r, 0.86, 0.5, 0.97, 0.84))
	sg.append_array(PackedVector2Array([_u(r, 0.21, 0.3), _u(r, 0.21, 0.42), _u(r, 0.36, 0.14), _u(r, 0.9, 0.14), _u(r, 0.9, 0.14), _u(r, 0.9, 0.5)]))
	S(ci, sg, 0.55, 1.2)
	D(ci, _u(r, 0.18, 0.6), maxf(1.4, r.size.y * 0.03), 0.6)
	_gband(ci, r, 0.25, 0.35, 0.22, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- M-14: belt drive motor
# the conveyor's belt drive: the motor on its slide rails (the adjusting bolt), the drive pulley on its
# shaft, the V-belts up to the driven pulley, the belt guard round them
static func belt_drive(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.04, 0.9), _u(r, 0.96, 0.9), _u(r, 0.04, 0.94), _u(r, 0.96, 0.94), _u(r, 0.96, 0.86), _u(r, 0.96, 0.94), _u(r, 0.88, 0.88), _u(r, 1.0, 0.88),
		_u(r, 0.16, 0.66), _u(r, 0.6, 0.06), _u(r, 0.3, 0.74), _u(r, 0.74, 0.12)])
	_mot(sg, sub(r, 0.36, 0.56, 0.92, 0.88), false)
	sg.append_array(PackedVector2Array([_u(r, 0.08, 0.5), _u(r, 0.52, 0.0), _u(r, 0.38, 0.88), _u(r, 0.84, 0.18), _u(r, 0.08, 0.5), _u(r, 0.08, 0.88)]))
	S(ci, sg, 0.55, 1.2)
	O(ci, _u(r, 0.23, 0.72), ms * 0.1, 0.6, 1.2)
	O(ci, _u(r, 0.67, 0.1), ms * 0.08, 0.6, 1.2)
	D(ci, _u(r, 0.23, 0.72), maxf(1.4, ms * 0.03), 0.6)


# ---------------------------------------------------------------- BL-88: air-operated diaphragm pump
# the water-ball loop's double-diaphragm pump: the two diaphragm chambers either side, the air valve
# block between them, the discharge manifold over and the suction manifold under (their ball-check
# housings), the air line in through its filter-regulator
static func diaphragm_pump(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_arcs(sg, _u(r, 0.36, 0.5), r.size.x * 0.2, r.size.y * 0.24, PI * 0.5, PI * 1.5, 6)
	_arcs(sg, _u(r, 0.64, 0.5), r.size.x * 0.2, r.size.y * 0.24, -PI * 0.5, PI * 0.5, 6)
	_rs(sg, sub(r, 0.36, 0.3, 0.64, 0.7))
	_rs(sg, sub(r, 0.42, 0.42, 0.58, 0.58))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.16), _u(r, 0.88, 0.16), _u(r, 0.12, 0.24), _u(r, 0.88, 0.24), _u(r, 0.12, 0.76), _u(r, 0.88, 0.76), _u(r, 0.12, 0.84), _u(r, 0.88, 0.84),
		_u(r, 0.16, 0.24), _u(r, 0.16, 0.3), _u(r, 0.84, 0.24), _u(r, 0.84, 0.3), _u(r, 0.16, 0.7), _u(r, 0.16, 0.76), _u(r, 0.84, 0.7), _u(r, 0.84, 0.76),
		_u(r, 0.5, 0.16), _u(r, 0.5, 0.0), _u(r, 0.5, 0.84), _u(r, 0.5, 1.0), _u(r, 0.5, 0.42), _u(r, 0.5, 0.34), _u(r, 0.58, 0.5), _u(r, 0.96, 0.5)]))
	_rs(sg, sub(r, 0.86, 0.4, 0.96, 0.5))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.87, 0.95, 0.56, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- BL-88: irrigation unit
# the drip irrigation head: the small pump and its motor on their foot, the disc filter (its ribs) on
# the discharge, the venturi fertiliser injector after it with its suction line down into the
# fertiliser tank, the line out
static func irrigation_head(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.5, 0.94))
	_vol(sg, _u(r, 0.14, 0.66), r.size.y * 0.12)
	_mot(sg, sub(r, 0.24, 0.6, 0.48, 0.86))
	_vves(sg, sub(r, 0.54, 0.24, 0.7, 0.62), r.size.x * 0.03, 3)
	for k in 3:
		var y: float = 0.34 + k * 0.08
		sg.append(_u(r, 0.54, y))
		sg.append(_u(r, 0.7, y))
	_rs(sg, sub(r, 0.76, 0.6, 0.96, 0.94))
	sg.append_array(PackedVector2Array([_u(r, 0.14, 0.48), _u(r, 0.14, 0.18), _u(r, 0.14, 0.18), _u(r, 0.62, 0.18), _u(r, 0.62, 0.18), _u(r, 0.62, 0.24),
		_u(r, 0.62, 0.62), _u(r, 0.62, 0.7), _u(r, 0.62, 0.7), _u(r, 0.74, 0.7), _u(r, 0.74, 0.66), _u(r, 0.8, 0.5), _u(r, 0.74, 0.74), _u(r, 0.8, 0.5),
		_u(r, 0.74, 0.66), _u(r, 0.74, 0.74), _u(r, 0.8, 0.5), _u(r, 1.0, 0.5), _u(r, 0.77, 0.6), _u(r, 0.77, 0.56)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.77, 0.95, 0.76, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- ARK-01: brake oil cooling pack (pump art)
# the brake's oil cooling pack: the oil pump and its motor on the foot, the finned oil cooler over them
# and its fan (ring, hub), the hoses between, the oil's warmth
static func brake_oil_pack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.98, 0.95))
	_rs(sg, sub(r, 0.06, 0.62, 0.26, 0.86))
	_mot(sg, sub(r, 0.26, 0.64, 0.6, 0.86))
	_rs(sg, sub(r, 0.06, 0.06, 0.94, 0.46))
	for k in 5:
		var x: float = 0.12 + k * 0.08
		sg.append(_u(r, x, 0.06))
		sg.append(_u(r, x, 0.46))
	sg.append_array(PackedVector2Array([_u(r, 0.16, 0.62), _u(r, 0.16, 0.46), _u(r, 0.22, 0.46), _u(r, 0.22, 0.62), _u(r, 0.94, 0.3), _u(r, 1.0, 0.3)]))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.74, 0.26), ms * 0.16, 0.55, 1.2)
	D(ci, _u(r, 0.74, 0.26), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.07, 0.5, 0.1, Pal.heat(0.7))


# ---------------------------------------------------------------- MD-160 / TB-180: brake oil cooler (radiator art)
# the brake's oil-to-air cooler: the tube-and-fin core between its two headers, the fan shrouds along
# it (rings and hubs), the hot oil in and the cooled oil out
static func brake_oil_cooler(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.12, 0.94, 0.88))
	_rs(sg, sub(r, 0.02, 0.08, 0.06, 0.92))
	_rs(sg, sub(r, 0.94, 0.08, 0.98, 0.92))
	var nf := clampi(int(r.size.x * 0.88 / 9.0), 6, 30)
	var fn := PackedVector2Array()
	for k in nf:
		var x: float = 0.08 + k * 0.84 / nf
		fn.append(_u(r, x, 0.14))
		fn.append(_u(r, x, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.2), _u(r, 0.02, 0.2), _u(r, 0.98, 0.8), _u(r, 1.0, 0.8)]))
	S(ci, sg, 0.55, 1.2)
	S(ci, fn, 0.26, 1.0)
	var n := clampi(int(r.size.x / (r.size.y * 1.2)), 1, 5)
	for k in n:
		var c := _u(r, 0.06 + (k + 0.5) * 0.88 / n, 0.5)
		O(ci, c, r.size.y * 0.3, 0.55, 1.2)
		D(ci, c, maxf(1.4, r.size.y * 0.06), 0.6)
	_gband(ci, r, 0.0, 0.05, 0.15, Pal.heat(0.8))


# ---------------------------------------------------------------- CH-110 / FL-116: screw compressor package
# a rotary screw compressor in its acoustic enclosure: the enclosure's louvres, the motor, the airend
# (its two rotors), the oil separator vessel, the aftercooler and its fan, the control panel's screen
static func screw_compressor(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.04, 0.98, 0.96))
	for k in 4:
		var y: float = 0.1 + k * 0.05
		sg.append(_u(r, 0.06, y))
		sg.append(_u(r, 0.24, y))
	_mot(sg, sub(r, 0.06, 0.56, 0.34, 0.9), false)
	_rs(sg, sub(r, 0.34, 0.6, 0.5, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.36, 0.69), _u(r, 0.48, 0.69), _u(r, 0.36, 0.77), _u(r, 0.48, 0.77), _u(r, 0.42, 0.6), _u(r, 0.42, 0.4), _u(r, 0.42, 0.4), _u(r, 0.56, 0.4)]))
	_vves(sg, sub(r, 0.56, 0.3, 0.7, 0.9), r.size.x * 0.03, 3)
	_rs(sg, sub(r, 0.74, 0.3, 0.94, 0.62))
	_rs(sg, sub(r, 0.74, 0.7, 0.94, 0.9))
	_rs(sg, sub(r, 0.34, 0.1, 0.5, 0.26))
	sg.append_array(PackedVector2Array([_u(r, 0.7, 0.4), _u(r, 0.74, 0.4)]))
	S(ci, sg, 0.55, 1.2)
	O(ci, _u(r, 0.84, 0.46), ms * 0.12, 0.5)
	E.Rc(ci, sub(r, 0.36, 0.13, 0.48, 0.2), Pal.tint(Pal.FLUID, 0.7), 1.0)
	_gband(ci, r, 0.57, 0.69, 0.5, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- 14 ships: close-coupled coolant pump
# a close-coupled monobloc coolant pump: the volute bolted straight to the motor's flange (no base, no
# coupling), the motor on its foot bracket, the suction in at the end, the discharge up, the drain plug
static func monobloc_pump(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_vol(sg, _u(r, 0.22, 0.58), minf(r.size.x * 0.15, r.size.y * 0.24))
	_mot(sg, sub(r, 0.36, 0.42, 0.94, 0.8))
	sg.append_array(PackedVector2Array([_u(r, 0.32, 0.38), _u(r, 0.32, 0.8), _u(r, 0.36, 0.38), _u(r, 0.36, 0.8),
		_u(r, 0.0, 0.58), _u(r, 0.08, 0.58), _u(r, 0.5, 0.8), _u(r, 0.46, 0.94), _u(r, 0.8, 0.8), _u(r, 0.84, 0.94), _u(r, 0.42, 0.94), _u(r, 0.9, 0.94)]))
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.22, 0.58), maxf(1.2, r.size.y * 0.04), 0.6)
	_gband(ci, r, 0.0, 0.07, 0.62, Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- DC-84: twin-head main cooling pump
# the data centre's main cooling water pump: one twin casing in the line with two upright motors on it
# (duty and standby), the flap valve between the two heads, the variable-speed drive on the wall
static func twin_head_pump(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.0, 0.8), _u(r, 0.12, 0.8), _u(r, 0.76, 0.8), _u(r, 0.86, 0.8), _u(r, 0.0, 0.9), _u(r, 0.12, 0.9), _u(r, 0.76, 0.9), _u(r, 0.86, 0.9),
		_u(r, 0.44, 0.66), _u(r, 0.44, 0.94), _u(r, 0.44, 0.8), _u(r, 0.5, 0.72)])
	_rs(sg, sub(r, 0.12, 0.66, 0.76, 0.96))
	_vmot(sg, sub(r, 0.14, 0.14, 0.36, 0.62))
	_vmot(sg, sub(r, 0.48, 0.14, 0.7, 0.62))
	S(ci, sg, 0.55, 1.1)
	var vd := PackedVector2Array()
	_rs(vd, sub(r, 0.88, 0.2, 1.0, 0.6))
	S(ci, vd, 0.55, 1.1)
	_lamp(ci, _u(r, 0.94, 0.28), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.0, 0.1, 0.84, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- PT-34: portable damage-control pump
# a portable damage-control pump in its tubular frame: the frame and its carry handles, the little
# engine (its cooling fins, the fuel tank on top), the pump on its side, the suction hose coiled with
# its strainer, the discharge outlet
static func portable_dc_pump(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.04, 0.2), _u(r, 0.04, 0.94), _u(r, 0.7, 0.2), _u(r, 0.7, 0.94), _u(r, 0.04, 0.94), _u(r, 0.7, 0.94),
		_u(r, 0.04, 0.2), _u(r, 0.1, 0.1), _u(r, 0.1, 0.1), _u(r, 0.64, 0.1), _u(r, 0.64, 0.1), _u(r, 0.7, 0.2)])
	_rs(sg, sub(r, 0.12, 0.44, 0.44, 0.88))
	_rs(sg, sub(r, 0.14, 0.24, 0.42, 0.42))
	for k in 3:
		var y: float = 0.54 + k * 0.1
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.44, y))
	_vol(sg, _u(r, 0.56, 0.66), ms * 0.12)
	sg.append_array(PackedVector2Array([_u(r, 0.68, 0.66), _u(r, 0.76, 0.66), _u(r, 0.94, 0.86), _u(r, 0.98, 0.98)]))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.86, 0.56), ms * 0.14, 0.45, 1.6)
	_gband(ci, r, 0.15, 0.41, 0.33, Pal.heat(0.7))


# ---------------------------------------------------------------- DR-150: two-stage piston air compressor
# the rig's air-cooled piston compressor: the two finned cylinders in a V on the crankcase, the
# intercooler tube between their heads, the flywheel with its fan spokes, the belt guard over to the
# motor, the base
static func piston_compressor(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.98, 0.95))
	_rs(sg, sub(r, 0.12, 0.56, 0.42, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.14, 0.56), _u(r, 0.04, 0.2), _u(r, 0.24, 0.56), _u(r, 0.16, 0.18), _u(r, 0.04, 0.2), _u(r, 0.16, 0.18),
		_u(r, 0.3, 0.56), _u(r, 0.36, 0.18), _u(r, 0.4, 0.56), _u(r, 0.48, 0.2), _u(r, 0.36, 0.18), _u(r, 0.48, 0.2),
		_u(r, 0.1, 0.17), _u(r, 0.1, 0.08), _u(r, 0.1, 0.08), _u(r, 0.42, 0.08), _u(r, 0.42, 0.08), _u(r, 0.42, 0.17),
		_u(r, 0.5, 0.56), _u(r, 0.6, 0.48), _u(r, 0.5, 0.86), _u(r, 0.6, 0.86), _u(r, 0.6, 0.48), _u(r, 0.6, 0.86)]))
	for k in 3:
		var t: float = 0.32 + k * 0.08
		sg.append_array(PackedVector2Array([_u(r, 0.06 + 0.06 * t, t), _u(r, 0.2 + 0.06 * t, t), _u(r, 0.34 - 0.04 * t, t), _u(r, 0.46 - 0.05 * t, t)]))
	_mot(sg, sub(r, 0.62, 0.56, 0.96, 0.86))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.5, 0.7), ms * 0.14, 0.55, 1.2)
	D(ci, _u(r, 0.5, 0.7), maxf(1.4, ms * 0.03), 0.6)


# ---------------------------------------------------------------- DR-150: rig hydraulic unit (compact)
# the rig's compact hydraulic unit: the reservoir, the upright motor on its bell housing on the lid,
# the manifold with its three control valves and their levers, the small accumulator, the gauge
static func compact_hpu(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.56, 0.96, 0.94))
	_vmot(sg, sub(r, 0.08, 0.06, 0.3, 0.42))
	_rs(sg, sub(r, 0.12, 0.42, 0.26, 0.56))
	_rs(sg, sub(r, 0.46, 0.34, 0.88, 0.5))
	for k in 3:
		var x: float = 0.52 + k * 0.13
		sg.append(_u(r, x, 0.34))
		sg.append(_u(r, x + 0.04, 0.16))
	_vves(sg, sub(r, 0.9, 0.12, 0.98, 0.5), r.size.x * 0.02, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.26, 0.48), _u(r, 0.46, 0.48), _u(r, 0.88, 0.42), _u(r, 0.9, 0.42)]))
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.4, 0.4), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.06, 0.94, 0.66, Pal.tint(Pal.FLUID, 0.6))


# ---------------------------------------------------------------- RO-128: deluge valve set
# the vehicle deck's deluge valve set: the riser up through it, the OS&Y gate valve at the foot (its
# rising stem, its wheel), the deluge valve (body, the diaphragm cover), its trim to the left (the
# solenoid, the two gauges), the water-motor alarm gong at the side, the header across the top
static func deluge_set(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.5, 1.0), _u(r, 0.5, 0.84), _u(r, 0.5, 0.64), _u(r, 0.5, 0.58), _u(r, 0.5, 0.32), _u(r, 0.5, 0.08),
		_u(r, 0.04, 0.08), _u(r, 0.96, 0.08), _u(r, 0.04, 0.04), _u(r, 0.04, 0.12), _u(r, 0.96, 0.04), _u(r, 0.96, 0.12),
		_u(r, 0.58, 0.77), _u(r, 0.8, 0.77), _u(r, 0.8, 0.71), _u(r, 0.8, 0.83),
		_u(r, 0.38, 0.44), _u(r, 0.2, 0.44), _u(r, 0.2, 0.44), _u(r, 0.2, 0.72), _u(r, 0.2, 0.72), _u(r, 0.42, 0.72),
		_u(r, 0.62, 0.4), _u(r, 0.76, 0.4), _u(r, 0.76, 0.4), _u(r, 0.76, 0.26)])
	_rs(sg, sub(r, 0.42, 0.7, 0.58, 0.84))
	_rs(sg, sub(r, 0.38, 0.32, 0.62, 0.58))
	_rs(sg, sub(r, 0.34, 0.4, 0.38, 0.5))
	_rs(sg, sub(r, 0.12, 0.5, 0.28, 0.6))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.0), _u(r, 0.5, 1.0)]), 0.45, 2.4)
	for y in [0.4, 0.66]:
		D(ci, _u(r, 0.2, y), maxf(1.4, ms * 0.04), 0.6)
	O(ci, _u(r, 0.76, 0.2), ms * 0.08, 0.55, 1.2)
	_gband(ci, r, 0.06, 0.94, 0.08, Pal.heat(0.75))


# ---------------------------------------------------------------- HG-170: cryogenic submerged transfer pump
# the cryogenic transfer pump: the vacuum-jacketed sump can (outer and inner walls) with the submerged
# motor-pump inside it, the top plate and its bolts, the suction and discharge lines (jacketed) out of
# the top, the frost
static func cryo_sump_pump(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.2, 0.16, 0.8, 0.98), w * 0.1, 3)
	_rs(sg, sub(r, 0.14, 0.12, 0.86, 0.18))
	sg.append_array(PackedVector2Array([_u(r, 0.3, 0.12), _u(r, 0.3, 0.0), _u(r, 0.38, 0.12), _u(r, 0.38, 0.0), _u(r, 0.62, 0.12), _u(r, 0.62, 0.04), _u(r, 0.62, 0.04), _u(r, 1.0, 0.04),
		_u(r, 0.7, 0.12), _u(r, 0.7, 0.1), _u(r, 0.7, 0.1), _u(r, 1.0, 0.1)]))
	S(ci, sg, 0.55, 1.1)
	var iv := PackedVector2Array()
	_vves(iv, sub(r, 0.27, 0.2, 0.73, 0.94), w * 0.08, 3)
	_rs(iv, sub(r, 0.4, 0.3, 0.6, 0.64))
	_rs(iv, sub(r, 0.36, 0.64, 0.64, 0.76))
	S(ci, iv, 0.3, 1.0)
	_gband(ci, r, 0.21, 0.79, 0.86, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- DR-150 / HG-170 / LC-140: fuel pump
# the fuel transfer pump: the flameproof motor (its heavy ribbed body, the thick end bells), the gear
# pump on it, the fuel filter and water separator beside it (its head, its clear bowl with the water
# settled at the bottom and the drain)
static func fuel_pump_xp(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.62, 0.95))
	_rs(sg, sub(r, 0.06, 0.5, 0.42, 0.86))
	_rs(sg, sub(r, 0.02, 0.48, 0.08, 0.88))
	_rs(sg, sub(r, 0.4, 0.48, 0.46, 0.88))
	for k in 4:
		var y: float = 0.56 + k * 0.08
		sg.append(_u(r, 0.08, y))
		sg.append(_u(r, 0.4, y))
	_rs(sg, sub(r, 0.46, 0.56, 0.6, 0.8))
	_rs(sg, sub(r, 0.66, 0.2, 0.96, 0.32))
	_rs(sg, sub(r, 0.7, 0.32, 0.92, 0.82))
	sg.append_array(PackedVector2Array([_u(r, 0.53, 0.56), _u(r, 0.53, 0.26), _u(r, 0.53, 0.26), _u(r, 0.66, 0.26), _u(r, 0.81, 0.82), _u(r, 0.81, 0.9), _u(r, 0.96, 0.26), _u(r, 1.0, 0.26)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.71, 0.91, 0.76, Pal.tint(Pal.FLUID, 0.8))
	_gband(ci, r, 0.71, 0.91, 0.5, Pal.heat(0.7))


# ---------------------------------------------------------------- CH-110 / M-14 / MF-126: gear-drum grease pump
# the open gear drive's spray lubrication: the grease drum (its ribs) with the follower plate inside,
# the air-driven pump's tube down into it and the air motor on top, the hose over to the progressive
# distributor block (its outlets), the spray lines to the nozzles at the gear rim
static func grease_station(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.4, 0.34, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.04, 0.56), _u(r, 0.34, 0.56), _u(r, 0.04, 0.8), _u(r, 0.34, 0.8),
		_u(r, 0.19, 0.4), _u(r, 0.19, 0.24), _u(r, 0.19, 0.12), _u(r, 0.6, 0.12), _u(r, 0.6, 0.12), _u(r, 0.6, 0.36)]))
	_rs(sg, sub(r, 0.12, 0.12, 0.26, 0.24))
	_rs(sg, sub(r, 0.54, 0.36, 0.66, 0.7))
	for k in 4:
		var y: float = 0.4 + k * 0.08
		sg.append_array(PackedVector2Array([_u(r, 0.66, y), _u(r, 0.86, 0.3 + k * 0.14)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.06, 0.62), _u(r, 0.32, 0.62)]), 0.3, 1.0)
	A(ci, _u(r, 1.12, 0.52), r.size.y * 0.42, PI * 0.6, PI * 1.4, 0.45, 1.4)
	_gband(ci, r, 0.05, 0.33, 0.7, Pal.heat(0.6))


# ---------------------------------------------------------------- ARK-01 / VT-80: big split-case pump
# a big double-suction split-case pump: the casing's lower and upper halves and the split flange
# between them, the suction and discharge branches out of its sides at the foot, the two bearing
# housings, the coupling guard, the motor, the baseplate
static func split_case_pump(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.98, 0.95))
	_arcs(sg, _u(r, 0.26, 0.56), r.size.x * 0.16, r.size.y * 0.3, PI, TAU, 6)
	sg.append_array(PackedVector2Array([_u(r, 0.1, 0.56), _u(r, 0.1, 0.84), _u(r, 0.42, 0.56), _u(r, 0.42, 0.84), _u(r, 0.1, 0.84), _u(r, 0.42, 0.84),
		_u(r, 0.06, 0.56), _u(r, 0.46, 0.56), _u(r, 0.06, 0.59), _u(r, 0.46, 0.59),
		_u(r, 0.0, 0.72), _u(r, 0.1, 0.72), _u(r, 0.0, 0.82), _u(r, 0.1, 0.82), _u(r, 0.26, 0.84), _u(r, 0.26, 0.88)]))
	_rs(sg, sub(r, 0.46, 0.5, 0.52, 0.66))
	_rs(sg, sub(r, 0.52, 0.52, 0.6, 0.64))
	_mot(sg, sub(r, 0.6, 0.38, 0.96, 0.86))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.26, 0.26), _u(r, 0.26, 0.04), _u(r, 0.2, 0.04), _u(r, 0.32, 0.04)]), 0.55, 2.0)
	_gband(ci, r, 0.0, 0.09, 0.77, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- MF-126: conveyor drive (motor and reducer)
# the conveyor's drive: the motor, the coupling guard, the helical-bevel reducer (its ribbed case, the
# breather), the output shaft and its sprocket, the chain off it, the base
static func conveyor_drive(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.98, 0.95))
	_mot(sg, sub(r, 0.04, 0.46, 0.4, 0.86), false)
	_rs(sg, sub(r, 0.4, 0.56, 0.48, 0.74))
	_rs(sg, sub(r, 0.48, 0.3, 0.8, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.56, 0.3), _u(r, 0.56, 0.86), _u(r, 0.72, 0.3), _u(r, 0.72, 0.86), _u(r, 0.62, 0.3), _u(r, 0.62, 0.22), _u(r, 0.59, 0.22), _u(r, 0.65, 0.22),
		_u(r, 0.8, 0.5), _u(r, 0.88, 0.5), _u(r, 0.9, 0.3), _u(r, 1.0, 0.04), _u(r, 0.96, 0.62), _u(r, 1.0, 0.56)]))
	S(ci, sg, 0.55, 1.2)
	O(ci, _u(r, 0.9, 0.5), ms * 0.18, 0.55, 1.4)
	D(ci, _u(r, 0.9, 0.5), maxf(1.4, ms * 0.04), 0.6)


# ---------------------------------------------------------------- ARK-01 / HB-86: peristaltic nutrient dosers
# the nutrient dosing station: a row of peristaltic heads (each a rotor and its three rollers squeezing
# the tube's loop), the drive box behind them, the stock bottles under them with their pick-up tubes,
# the dosing lines out
static func peristaltic_doser(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var n := clampi(int(r.size.x / (r.size.y * 0.7)), 1, 4)
	var bw: float = 0.92 / n
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.06, 0.96, 0.5))
	for k in n:
		var xm: float = 0.04 + (k + 0.5) * bw
		_rs(sg, sub(r, xm - bw * 0.3, 0.62, xm + bw * 0.3, 0.96))
		sg.append_array(PackedVector2Array([_u(r, xm - bw * 0.1, 0.5), _u(r, xm - bw * 0.1, 0.9), _u(r, xm + bw * 0.1, 0.5), _u(r, xm + bw * 0.1, 0.06), _u(r, xm + bw * 0.1, 0.06), _u(r, xm + bw * 0.2, 0.0)]))
	S(ci, sg, 0.55, 1.1)
	for k in n:
		var c := _u(r, 0.04 + (k + 0.5) * bw, 0.28)
		var rad: float = minf(r.size.x * bw * 0.36, r.size.y * 0.18)
		O(ci, c, rad, 0.55, 1.2)
		for j in 3:
			D(ci, c + Vector2.from_angle(TAU * j / 3.0 + 0.4) * rad * 0.6, maxf(1.2, rad * 0.16), 0.6)
		_gband(ci, r, 0.04 + (k + 0.2) * bw, 0.04 + (k + 0.8) * bw, 0.76, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- FL-116: API process pump
# the process pump: the heavy baseplate with its drain rim, the centreline-mounted volute (its feet at
# the shaft's height), the bearing frame and its oil bottle, the seal and its seal pot over it with the
# two lines down, the coupling guard, the motor
static func api_process_pump(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.86, 0.98, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.86), _u(r, 0.02, 0.82), _u(r, 0.98, 0.86), _u(r, 0.98, 0.82),
		_u(r, 0.06, 0.62), _u(r, 0.06, 0.86), _u(r, 0.3, 0.62), _u(r, 0.3, 0.86)]))
	_vol(sg, _u(r, 0.18, 0.62), r.size.y * 0.16)
	_rs(sg, sub(r, 0.3, 0.54, 0.5, 0.7))
	_rs(sg, sub(r, 0.38, 0.7, 0.44, 0.8))
	_rs(sg, sub(r, 0.5, 0.56, 0.58, 0.68))
	_mot(sg, sub(r, 0.58, 0.44, 0.96, 0.84))
	_vves(sg, sub(r, 0.3, 0.12, 0.4, 0.34), r.size.x * 0.02, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.32, 0.34), _u(r, 0.32, 0.56), _u(r, 0.38, 0.34), _u(r, 0.38, 0.54)]))
	S(ci, sg, 0.55, 1.2)
	D(ci, _u(r, 0.18, 0.62), maxf(1.4, ms * 0.03), 0.6)
	_gband(ci, r, 0.385, 0.435, 0.74, Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.31, 0.39, 0.2, Pal.heat(0.7))


# ---------------------------------------------------------------- 7 ships: small end-suction cooling pump
# the classic small end-suction cooling pump on its base: the volute and its suction, the bearing
# bracket, the coupling guard, the motor, the flexible connector on the discharge and the gauge over it
static func end_suction_pump(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.86, 0.98, 0.94))
	_vol(sg, _u(r, 0.2, 0.62), minf(r.size.x * 0.13, r.size.y * 0.2))
	_rs(sg, sub(r, 0.32, 0.56, 0.46, 0.7))
	_rs(sg, sub(r, 0.46, 0.58, 0.52, 0.68))
	_mot(sg, sub(r, 0.52, 0.48, 0.96, 0.84))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.62), _u(r, 0.1, 0.62), _u(r, 0.2, 0.82), _u(r, 0.2, 0.86), _u(r, 0.38, 0.7), _u(r, 0.38, 0.86),
		_u(r, 0.2, 0.32), _u(r, 0.2, 0.14), _u(r, 0.16, 0.3), _u(r, 0.24, 0.26), _u(r, 0.16, 0.24), _u(r, 0.24, 0.2)]))
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.3, 0.16), maxf(1.4, ms * 0.05), 0.6)


# ---------------------------------------------------------------- MF-126 / VT-80: self-priming return pump
# the self-priming return pump: the big priming chamber over the impeller casing, its filling plug,
# the suction in high, the non-return flap on the suction, the discharge up from the chamber, the
# bearing bracket and motor on the base
static func self_priming_pump(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.98, 0.95))
	_rs(sg, sub(r, 0.08, 0.2, 0.36, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.08, 0.56), _u(r, 0.36, 0.56), _u(r, 0.0, 0.3), _u(r, 0.08, 0.3), _u(r, 0.08, 0.26), _u(r, 0.14, 0.36),
		_u(r, 0.26, 0.2), _u(r, 0.26, 0.04), _u(r, 0.2, 0.04), _u(r, 0.32, 0.04), _u(r, 0.16, 0.2), _u(r, 0.16, 0.14), _u(r, 0.13, 0.14), _u(r, 0.19, 0.14)]))
	_rs(sg, sub(r, 0.36, 0.6, 0.5, 0.76))
	_rs(sg, sub(r, 0.5, 0.62, 0.56, 0.74))
	_mot(sg, sub(r, 0.56, 0.5, 0.96, 0.86))
	S(ci, sg, 0.55, 1.2)
	var im := PackedVector2Array()
	_arcs(im, _u(r, 0.22, 0.72), r.size.x * 0.1, r.size.y * 0.12, 0.0, TAU, 6)
	S(ci, im, 0.35, 1.0)
	_gband(ci, r, 0.09, 0.35, 0.4, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- MY-48: spa pump
# the yacht spa's pump: the hair-and-lint strainer pot (its clear lid with the basket under it, the
# lid's lock ring), the close-coupled pump and motor, the inline heater tube on the discharge, the
# jet manifold it feeds
static func spa_pump_set(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.86, 0.6, 0.94))
	_rs(sg, sub(r, 0.04, 0.34, 0.2, 0.86))
	_rs(sg, sub(r, 0.02, 0.28, 0.22, 0.34))
	_rs(sg, sub(r, 0.2, 0.46, 0.28, 0.8))
	_mot(sg, sub(r, 0.28, 0.5, 0.58, 0.84))
	_rs(sg, sub(r, 0.66, 0.2, 0.96, 0.34))
	sg.append_array(PackedVector2Array([_u(r, 0.24, 0.46), _u(r, 0.24, 0.27), _u(r, 0.24, 0.27), _u(r, 0.66, 0.27), _u(r, 0.81, 0.34), _u(r, 0.81, 0.62),
		_u(r, 0.7, 0.62), _u(r, 0.96, 0.62), _u(r, 0.72, 0.62), _u(r, 0.72, 0.72), _u(r, 0.81, 0.62), _u(r, 0.81, 0.72), _u(r, 0.9, 0.62), _u(r, 0.9, 0.72)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.07, 0.4), _u(r, 0.07, 0.72), _u(r, 0.17, 0.4), _u(r, 0.17, 0.72), _u(r, 0.07, 0.72), _u(r, 0.17, 0.72)]), 0.3, 1.0)
	_gband(ci, r, 0.67, 0.95, 0.27, Pal.heat(0.75))
	_gband(ci, r, 0.05, 0.19, 0.5, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- MF-126: self-cleaning strainer (pump art)
# the automatic self-cleaning strainer: the upright body and its screen, the geared motor on top that
# turns the cleaning brush's shaft, the inlet and outlet flanges, the backwash valve and its actuator
# at the foot, the differential-pressure switch, the base
static func auto_strainer(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.92, 0.94, 0.98))
	_vves(sg, sub(r, 0.32, 0.26, 0.68, 0.84), r.size.x * 0.04, 3)
	_vmot(sg, sub(r, 0.42, 0.02, 0.58, 0.24))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.42), _u(r, 0.32, 0.42), _u(r, 0.68, 0.66), _u(r, 1.0, 0.66), _u(r, 0.04, 0.36), _u(r, 0.04, 0.48), _u(r, 0.96, 0.6), _u(r, 0.96, 0.72),
		_u(r, 0.5, 0.84), _u(r, 0.5, 0.92), _u(r, 0.5, 0.88), _u(r, 0.2, 0.88)]))
	_rs(sg, sub(r, 0.12, 0.76, 0.24, 0.9))
	_rs(sg, sub(r, 0.76, 0.3, 0.88, 0.4))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.4, 0.32), _u(r, 0.4, 0.78), _u(r, 0.6, 0.32), _u(r, 0.6, 0.78), _u(r, 0.5, 0.24), _u(r, 0.5, 0.8)]), 0.3, 1.0)
	_lamp(ci, _u(r, 0.82, 0.35), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- VT-80 / FL-116: submersible sump pump
# a submersible sump pump in its pit: the pit's walls and floor, the twin guide rails, the pump down
# in it (the motor can and its domed top, its cooling bands, the volute base, the inlet strainer's
# slots), the power cable up out of the pit, the guide claw on the rails, the discharge bend and the
# riser up out of the pit with its non-return valve and union, the float switch's ball on its cable,
# the water in the pit
static func sump_submersible(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.04, 0.0), _u(r, 0.04, 0.96), _u(r, 0.04, 0.96), _u(r, 0.96, 0.96), _u(r, 0.96, 0.96), _u(r, 0.96, 0.0),
		_u(r, 0.1, 0.0), _u(r, 0.1, 0.94), _u(r, 0.14, 0.0), _u(r, 0.14, 0.94),
		_u(r, 0.5, 0.36), _u(r, 0.5, 0.28), _u(r, 0.5, 0.28), _u(r, 0.38, 0.0),
		_u(r, 0.62, 0.6), _u(r, 0.7, 0.6), _u(r, 0.7, 0.6), _u(r, 0.7, 0.02), _u(r, 0.7, 0.02), _u(r, 1.0, 0.02),
		_u(r, 0.82, 0.0), _u(r, 0.86, 0.5), _u(r, 0.26, 0.86), _u(r, 0.26, 0.94), _u(r, 0.34, 0.86), _u(r, 0.34, 0.94), _u(r, 0.42, 0.86), _u(r, 0.42, 0.94), _u(r, 0.5, 0.86), _u(r, 0.5, 0.94)])
	_rs(sg, sub(r, 0.38, 0.4, 0.62, 0.72))
	_arcs(sg, _u(r, 0.5, 0.4), r.size.x * 0.12, r.size.y * 0.06, PI, TAU, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.38, 0.5), _u(r, 0.62, 0.5), _u(r, 0.38, 0.6), _u(r, 0.62, 0.6)]))
	_rs(sg, sub(r, 0.22, 0.72, 0.66, 0.86))
	_rs(sg, sub(r, 0.66, 0.16, 0.74, 0.24))
	_rs(sg, sub(r, 0.66, 0.32, 0.74, 0.36))
	_rs(sg, sub(r, 0.14, 0.62, 0.38, 0.66))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.87, 0.58), ms * 0.08, 0.55)
	_gband(ci, r, 0.15, 0.95, 0.5, Pal.tint(Pal.FLUID, 0.65))


# ---------------------------------------------------------------- PS-12 / CV-138: duty and standby service pumps
# the service pump set: two upright inline pumps side by side between the common suction header at the
# foot and the discharge header over them, each with its isolating valves and its non-return valve
static func duty_standby_pumps(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.9), _u(r, 1.0, 0.9), _u(r, 0.0, 0.08), _u(r, 1.0, 0.08)])
	for x0 in [0.12, 0.56]:
		var xm: float = x0 + 0.14
		_vmot(sg, sub(r, x0 + 0.04, 0.3, x0 + 0.22, 0.62))
		_rs(sg, sub(r, x0, 0.62, x0 + 0.28, 0.78))
		sg.append_array(PackedVector2Array([_u(r, x0 + 0.02, 0.78), _u(r, x0 + 0.02, 0.9), _u(r, x0 + 0.26, 0.7), _u(r, x0 + 0.34, 0.7), _u(r, x0 + 0.34, 0.7), _u(r, x0 + 0.34, 0.08),
			_u(r, x0 + 0.3, 0.2), _u(r, x0 + 0.38, 0.28), _u(r, x0 + 0.3, 0.28), _u(r, x0 + 0.38, 0.2),
			_u(r, x0 - 0.02, 0.84), _u(r, x0 + 0.06, 0.84), _u(r, x0 + 0.3, 0.14), _u(r, x0 + 0.38, 0.14)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.02, 0.1, 0.9, Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- MT-140: long-shaft tank pump
# the vertical long-shaft tank pump: the tank's top plate, the upright motor on its discharge head, the
# discharge branch off the head, the column pipe down into the tank (its line shaft and the bearing
# brackets) to the bowl and its suction strainer, the tank's level
static func tank_lineshaft(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.42), _u(r, 1.0, 0.42), _u(r, 0.0, 0.46), _u(r, 1.0, 0.46), _u(r, 0.6, 0.36), _u(r, 1.0, 0.36)])
	_vmot(sg, sub(r, 0.36, 0.0, 0.6, 0.24))
	_rs(sg, sub(r, 0.34, 0.24, 0.62, 0.42))
	_rs(sg, sub(r, 0.4, 0.82, 0.56, 0.94))
	S(ci, sg, 0.55, 1.2)
	var cl := PackedVector2Array([_u(r, 0.44, 0.46), _u(r, 0.44, 0.82), _u(r, 0.52, 0.46), _u(r, 0.52, 0.82), _u(r, 0.38, 0.6), _u(r, 0.58, 0.6), _u(r, 0.38, 0.72), _u(r, 0.58, 0.72),
		_u(r, 0.42, 0.94), _u(r, 0.42, 0.99), _u(r, 0.54, 0.94), _u(r, 0.54, 0.99)])
	S(ci, cl, 0.38, 1.0)
	_gband(ci, r, 0.0, 1.0, 0.66, Pal.tint(Pal.FLUID, 0.55))


# ---------------------------------------------------------------- 6 ships: gear transfer pump
# the transfer pump, a rotary gear pump: the pump body cut open to show its two meshing gears, the
# relief valve on top, the reduction gearbox between it and the motor, the suction and discharge
# ports out of its sides, the base
static func gear_transfer(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.88, 0.98, 0.95))
	_rs(sg, sub(r, 0.08, 0.4, 0.36, 0.86))
	_rs(sg, sub(r, 0.16, 0.26, 0.28, 0.4))
	_rs(sg, sub(r, 0.38, 0.5, 0.56, 0.86))
	_mot(sg, sub(r, 0.58, 0.5, 0.96, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.7), _u(r, 0.08, 0.7), _u(r, 0.36, 0.7), _u(r, 0.38, 0.7), _u(r, 0.22, 0.26), _u(r, 0.22, 0.18),
		_u(r, 0.56, 0.64), _u(r, 0.58, 0.64), _u(r, 0.47, 0.5), _u(r, 0.47, 0.44)]))
	S(ci, sg, 0.55, 1.2)
	O(ci, _u(r, 0.22, 0.55), ms * 0.13, 0.5)
	O(ci, _u(r, 0.22, 0.75), ms * 0.13, 0.5)
	_gband(ci, r, 0.0, 0.07, 0.66, Pal.heat(0.7))


# ---------------------------------------------------------------- TS-1: practice coolant pump
# the trainer's little magnetic-drive pump: the clear head (its impeller showing), the short motor on its
# bracket (its fins and feet), the suction hose and the delivery hose curling away, their clamps
static func mini_mag_pump(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.06, 0.9), _u(r, 0.94, 0.9), _u(r, 0.0, 0.56), _u(r, 0.14, 0.56), _u(r, 0.3, 0.3), _u(r, 0.3, 0.18),
		_u(r, 0.3, 0.18), _u(r, 0.5, 0.06), _u(r, 0.04, 0.5), _u(r, 0.04, 0.62), _u(r, 0.26, 0.24), _u(r, 0.34, 0.24),
		_u(r, 0.5, 0.52), _u(r, 0.84, 0.52), _u(r, 0.5, 0.68), _u(r, 0.84, 0.68), _u(r, 0.56, 0.82), _u(r, 0.56, 0.9), _u(r, 0.8, 0.82), _u(r, 0.8, 0.9)])
	_rs(sg, sub(r, 0.44, 0.38, 0.9, 0.82))
	S(ci, sg, 0.55, 1.0)
	O(ci, _u(r, 0.3, 0.6), ms * 0.22, 0.55)
	D(ci, _u(r, 0.3, 0.6), maxf(1.0, ms * 0.06), 0.6)


# ---------------------------------------------------------------- NR-95: actuated vent valve (pump art)
# the reactor's vent valve: the valve body in its line between the flanges, the yoke up to the diaphragm
# actuator (its domed casing), the positioner on the yoke, the vent stack off the outlet and the
# silencer on it
static func actuated_vent(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.78), _u(r, 0.3, 0.78), _u(r, 0.0, 0.92), _u(r, 0.3, 0.92), _u(r, 0.26, 0.72), _u(r, 0.26, 0.98),
		_u(r, 0.36, 0.66), _u(r, 0.36, 0.36), _u(r, 0.5, 0.66), _u(r, 0.5, 0.36), _u(r, 0.22, 0.36), _u(r, 0.64, 0.36),
		_u(r, 0.56, 0.85), _u(r, 0.76, 0.85), _u(r, 0.76, 0.85), _u(r, 0.76, 0.06)])
	_rs(sg, sub(r, 0.3, 0.66, 0.56, 0.98))
	_rs(sg, sub(r, 0.5, 0.44, 0.6, 0.56))
	_rs(sg, sub(r, 0.7, 0.06, 0.82, 0.42))
	_arcs(sg, _u(r, 0.43, 0.36), r.size.x * 0.21, r.size.y * 0.24, PI, TAU, 6)
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.72, 0.14), _u(r, 0.8, 0.14), _u(r, 0.72, 0.22), _u(r, 0.8, 0.22), _u(r, 0.72, 0.3), _u(r, 0.8, 0.3)]), 0.3, 1.0)
	_gband(ci, r, 0.71, 0.81, 0.04, Pal.heat(0.75))


# ---------------------------------------------------------------- ARK-01 / IC-120: water booster set
# the water main's booster set: two vertical multistage pumps (their stacked stages, the motors on top)
# between the common suction and discharge headers, the membrane pressure vessel on the discharge,
# the control box and its lamp
static func booster_set(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.0, 0.92), _u(r, 0.72, 0.92), _u(r, 0.0, 0.12), _u(r, 0.86, 0.12), _u(r, 0.86, 0.12), _u(r, 0.86, 0.5)])
	for x0 in [0.1, 0.38]:
		_rs(sg, sub(r, x0, 0.5, x0 + 0.16, 0.92))
		for k in 3:
			var y: float = 0.6 + k * 0.09
			sg.append(_u(r, x0, y))
			sg.append(_u(r, x0 + 0.16, y))
		_vmot(sg, sub(r, x0 + 0.02, 0.2, x0 + 0.14, 0.5))
		sg.append(_u(r, x0 + 0.14, 0.52))
		sg.append(_u(r, x0 + 0.24, 0.12))
	_vves(sg, sub(r, 0.76, 0.5, 0.96, 0.96), r.size.x * 0.04, 3)
	S(ci, sg, 0.55, 1.1)
	R(ci, sub(r, 0.66, 0.24, 0.8, 0.4), 0.55)
	_lamp(ci, _u(r, 0.73, 0.3), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.77, 0.95, 0.72, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- FR-26: racing heat-rejection fin
# the racer's heat-rejection fin: the swept fin's outline (the root wide, the tip narrow), the heat
# pipes fanning out from the root block, the root clamp and its bolts, the leading edge's strip
static func racing_fin(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.1, 0.04), _u(r, 0.96, 0.4), _u(r, 0.96, 0.4), _u(r, 0.96, 0.6), _u(r, 0.96, 0.6), _u(r, 0.1, 0.96),
		_u(r, 0.1, 0.06), _u(r, 0.94, 0.42)])
	_rs(sg, sub(r, 0.02, 0.0, 0.1, 1.0))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.2), _u(r, 0.06, 0.24), _u(r, 0.06, 0.76), _u(r, 0.06, 0.8)]))
	S(ci, sg, 0.55, 1.2)
	var hp := PackedVector2Array()
	for k in 7:
		var y: float = 0.14 + k * 0.12
		hp.append(_u(r, 0.1, y))
		hp.append(_u(r, 0.9, 0.44 + k * 0.02))
	S(ci, hp, 0.32, 1.0)
	_gband(ci, r, 0.03, 0.09, 0.5, Pal.heat(0.75))


# ---------------------------------------------------------------- IC-120 (x9): ice-melt heating pad
# an ice-melt heating pad: the pad's outline, the heating element snaking through it, the thermostat
# box at one corner and its power lead
static func ice_heat_pad(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.06, 0.96, 0.94))
	_rs(sg, sub(r, 0.76, 0.12, 0.92, 0.26))
	sg.append_array(PackedVector2Array([_u(r, 0.92, 0.19), _u(r, 1.0, 0.19)]))
	S(ci, sg, 0.55, 1.1)
	var n := clampi(int(r.size.y * 0.7 / 7.0), 3, 7)
	var pts: Array = []
	for k in n:
		var y: float = 0.24 + k * 0.62 / maxf(n - 1, 1)
		var x0: float = 0.12 if k % 2 == 0 else 0.86
		var x1: float = 0.86 if k % 2 == 0 else 0.12
		pts.append(Vector2(x0, y))
		pts.append(Vector2(x1, y))
	_pu(ci, r, pts, 0.5, 1.4)
	_gband(ci, r, 0.12, 0.86, 0.15, Pal.heat(0.75))


# ---------------------------------------------------------------- 10 ships: space radiator panel
# a body-mounted radiator panel: its outline, the supply header along the top and the return header
# along the foot, the flow tubes between them, the stiffener across, the hinge brackets at the edge,
# the inlet and outlet stubs
static func radiator_panel(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.04, 0.5), _u(r, 0.96, 0.5), _u(r, 0.0, 0.2), _u(r, 0.04, 0.2), _u(r, 0.0, 0.8), _u(r, 0.04, 0.8),
		_u(r, 0.96, 0.1), _u(r, 1.0, 0.1), _u(r, 0.96, 0.9), _u(r, 1.0, 0.9)]))
	S(ci, sg, 0.55, 1.2)
	var nt := clampi(int(r.size.x * 0.9 / 10.0), 4, 24)
	var tb := PackedVector2Array()
	for k in nt:
		var x: float = 0.06 + (k + 0.5) * 0.88 / nt
		tb.append(_u(r, x, 0.1))
		tb.append(_u(r, x, 0.9))
	S(ci, tb, 0.28, 1.0)
	S(ci, PackedVector2Array([_u(r, 0.04, 0.09), _u(r, 0.96, 0.09), _u(r, 0.04, 0.91), _u(r, 0.96, 0.91)]), 0.55, 2.2)
	_gband(ci, r, 0.05, 0.3, 0.07, Pal.heat(0.7))
	_gband(ci, r, 0.05, 0.3, 0.92, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- ARK-01 (x24) and others: deployable radiator wing
# a deployable radiator wing: the dense fin rows across every panel (read from afar as its grain),
# the heavy supply header along the top and the return header along the foot with their root
# connections, each panel's frame with its cross bracing and mid rail, the hinge lines and their
# knuckle blocks, the deploy arm's truss at the root, the coolant in (warm) and out (cold)
static func radiator_wing(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.0, 0.02, 1.0, 0.98))
	var np := clampi(int(r.size.x / maxf(r.size.y * 0.6, 40.0)), 2, 5)
	var fn := PackedVector2Array()
	var nf := clampi(int(r.size.x / 7.0), 16, 120)
	for k in nf:
		var x: float = (k + 0.5) / nf
		if absf(x * np - roundf(x * np)) * r.size.x / np < 4.0:
			continue
		fn.append(_u(r, x, 0.11))
		fn.append(_u(r, x, 0.89))
	for k in np:
		var x0: float = float(k) / np
		var x1: float = float(k + 1) / np
		_rs(sg, sub(r, x0 + 0.012, 0.1, x1 - 0.012, 0.9))
		sg.append_array(PackedVector2Array([_u(r, x0 + 0.012, 0.1), _u(r, x1 - 0.012, 0.9), _u(r, x0 + 0.012, 0.9), _u(r, x1 - 0.012, 0.1),
			_u(r, x0 + 0.012, 0.5), _u(r, x1 - 0.012, 0.5)]))
		if k > 0:
			sg.append_array(PackedVector2Array([_u(r, x0, 0.02), _u(r, x0, 0.98)]))
			for y in [0.06, 0.94]:
				_rs(sg, sub(r, x0 - 0.01, y - 0.02, x0 + 0.01, y + 0.02))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.1), _u(r, -0.03, 0.3), _u(r, -0.03, 0.3), _u(r, 0.0, 0.5), _u(r, 0.0, 0.5), _u(r, -0.03, 0.7), _u(r, -0.03, 0.7), _u(r, 0.0, 0.9)]))
	S(ci, fn, 0.22, 1.0)
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.06), _u(r, 1.0, 0.06), _u(r, 0.0, 0.94), _u(r, 1.0, 0.94)]), 0.6, 3.0)
	S(ci, PackedVector2Array([_u(r, 0.0, 0.06), _u(r, -0.02, 0.06), _u(r, 0.0, 0.94), _u(r, -0.02, 0.94)]), 0.6, 3.0)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.035), Vector2(r.size.x * 0.06, r.size.y * 0.05)), Pal.heat(0.8), 1.4)
	E.Rc(ci, Rect2(_u(r, 0.0, 0.915), Vector2(r.size.x * 0.06, r.size.y * 0.05)), Pal.tint(Pal.AIR, 0.8), 1.4)


# ---------------------------------------------------------------- NR-95: petal radiator
# a petal radiator: the tapered petal (wide at its root, narrow at the tip), the coolant spine down its
# middle, the heat-pipe ribs off the spine both ways in a herringbone, the root hinge
static func petal_radiator(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.0), _u(r, 0.98, 0.3), _u(r, 0.98, 0.3), _u(r, 0.98, 0.7), _u(r, 0.98, 0.7), _u(r, 0.04, 1.0)])
	_rs(sg, sub(r, 0.0, 0.0, 0.04, 1.0))
	S(ci, sg, 0.55, 1.2)
	var n := clampi(int(r.size.x * 0.9 / 16.0), 4, 18)
	var rb := PackedVector2Array()
	for k in n:
		var x: float = 0.08 + k * 0.86 / n
		var hw: float = 0.5 - (x - 0.04) / 0.94 * 0.2
		rb.append_array(PackedVector2Array([_u(r, x, 0.5), _u(r, x + 0.04, 0.5 - hw * 0.85), _u(r, x, 0.5), _u(r, x + 0.04, 0.5 + hw * 0.85)]))
	S(ci, rb, 0.3, 1.0)
	S(ci, PackedVector2Array([_u(r, 0.04, 0.5), _u(r, 0.98, 0.5)]), 0.55, 2.2)
	_gband(ci, r, 0.06, 0.4, 0.5, Pal.heat(0.6))


# ---------------------------------------------------------------- S-09: mirror-tile radiator plate
# a small radiator plate faced with mirror tiles: the plate and the grid of tiles, the fine fins
# under them (the plate's grain), the supply header across the top and the return across the foot
# with their ports (warm in, cold out), the two mounting brackets
static func osr_plate(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.1, 0.94, 0.9))
	for k in range(1, 4):
		var x: float = 0.06 + k * 0.22
		sg.append(_u(r, x, 0.1))
		sg.append(_u(r, x, 0.9))
	for k in range(1, 4):
		var y: float = 0.1 + k * 0.2
		sg.append(_u(r, 0.06, y))
		sg.append(_u(r, 0.94, y))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.2), _u(r, 0.06, 0.2), _u(r, 0.0, 0.8), _u(r, 0.06, 0.8),
		_u(r, 0.94, 0.04), _u(r, 1.0, 0.04), _u(r, 0.94, 0.96), _u(r, 1.0, 0.96)]))
	S(ci, sg, 0.5, 1.1)
	var fn := PackedVector2Array()
	var nf := clampi(int(r.size.x * 0.88 / 4.0), 10, 40)
	for k in nf:
		var x: float = 0.07 + (k + 0.5) * 0.86 / nf
		fn.append(_u(r, x, 0.11))
		fn.append(_u(r, x, 0.89))
	S(ci, fn, 0.2, 1.0)
	S(ci, PackedVector2Array([_u(r, 0.04, 0.05), _u(r, 0.96, 0.05), _u(r, 0.04, 0.95), _u(r, 0.96, 0.95)]), 0.6, 2.6)
	_gband(ci, r, 0.9, 1.0, 0.03, Pal.heat(0.8))
	_gband(ci, r, 0.9, 1.0, 0.95, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- SV-122: sensor cryocooler
# the sensor's Stirling cryocooler: the dewar and the sensor window at its top, the cold finger down to
# the cooler's expander, the twin-piston compressor lying at the foot (its two heads), its finned heat
# rejection collar, the transfer line between them
static func stirling_cooler(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.22, 0.02, 0.78, 0.4), w * 0.12, 3)
	_rs(sg, sub(r, 0.38, 0.04, 0.62, 0.08))
	sg.append_array(PackedVector2Array([_u(r, 0.46, 0.4), _u(r, 0.46, 0.6), _u(r, 0.54, 0.4), _u(r, 0.54, 0.6)]))
	_rs(sg, sub(r, 0.36, 0.6, 0.64, 0.72))
	_hves(sg, sub(r, 0.04, 0.8, 0.96, 0.94), r.size.y * 0.02, 3)
	for k in 4:
		var x: float = 0.38 + k * 0.08
		sg.append(_u(r, x, 0.78))
		sg.append(_u(r, x, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.72), _u(r, 0.5, 0.8)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.23, 0.77, 0.3, Pal.tint(Pal.AIR, 0.75))
	_gband(ci, r, 0.37, 0.63, 0.75, Pal.heat(0.6))


# ---------------------------------------------------------------- ST-40: battery cold plate
# the battery's cold plate: the plate, the coolant channel snaking through it, the inlet and outlet
# ports at one end, the row of cells standing on it
static func battery_cold_plate(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.5, 0.98, 0.96))
	var n := clampi(int(r.size.x * 0.9 / 10.0), 4, 12)
	for k in n:
		var x0: float = 0.04 + k * 0.92 / n
		_rs(sg, sub(r, x0, 0.0, x0 + 0.92 / n * 0.8, 0.5))
	sg.append_array(PackedVector2Array([_u(r, 0.98, 0.6), _u(r, 1.0, 0.6), _u(r, 0.98, 0.86), _u(r, 1.0, 0.86)]))
	S(ci, sg, 0.5, 1.0)
	var pts: Array = [Vector2(0.98, 0.6)]
	for k in 4:
		var x: float = 0.86 - k * 0.24
		pts.append(Vector2(x, 0.6 if k % 2 == 0 else 0.86))
		pts.append(Vector2(x, 0.86 if k % 2 == 0 else 0.6))
	_pu(ci, r, pts, 0.32, 1.0)
	_gband(ci, r, 0.04, 0.4, 0.72, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- SV-122: thermal control unit
# the instrument bay's thermal control unit, a stack in its frame: the circulating pump at the foot, the
# bellows accumulator, the plate heat exchanger (its plates), the trim heater, the mixing valve, the
# loop lines out of the side
static func thermal_stack(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.0), _u(r, 0.04, 1.0), _u(r, 0.96, 0.0), _u(r, 0.96, 1.0)])
	_rs(sg, sub(r, 0.2, 0.82, 0.8, 0.96))
	_rs(sg, sub(r, 0.3, 0.6, 0.7, 0.78))
	for k in 3:
		var y: float = 0.64 + k * 0.045
		sg.append(_u(r, 0.3, y))
		sg.append(_u(r, 0.7, y))
	_rs(sg, sub(r, 0.16, 0.3, 0.84, 0.56))
	for k in 5:
		var x: float = 0.26 + k * 0.12
		sg.append(_u(r, x, 0.3))
		sg.append(_u(r, x, 0.56))
	_rs(sg, sub(r, 0.24, 0.16, 0.76, 0.26))
	_rs(sg, sub(r, 0.4, 0.02, 0.6, 0.12))
	sg.append_array(PackedVector2Array([_u(r, 0.84, 0.36), _u(r, 1.0, 0.36), _u(r, 0.84, 0.5), _u(r, 1.0, 0.5), _u(r, 0.5, 0.78), _u(r, 0.5, 0.82), _u(r, 0.5, 0.56), _u(r, 0.5, 0.6),
		_u(r, 0.5, 0.26), _u(r, 0.5, 0.3), _u(r, 0.5, 0.12), _u(r, 0.5, 0.16)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.25, 0.75, 0.21, Pal.heat(0.75))
	_gband(ci, r, 0.17, 0.83, 0.43, Pal.tint(Pal.FLUID, 0.6))


# ---------------------------------------------------------------- PT-34: weapon coolant unit
# the guns' coolant unit, all in a row: the coolant tank (its level), the circulating pump and motor,
# the plate heat exchanger to the ship's loop (its plates), the fan cooler at the end (its ring)
static func weapon_cooler(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.9, 0.98, 0.96))
	_rs(sg, sub(r, 0.04, 0.2, 0.24, 0.9))
	_vol(sg, _u(r, 0.32, 0.66), r.size.y * 0.16)
	_mot(sg, sub(r, 0.38, 0.52, 0.56, 0.88))
	_rs(sg, sub(r, 0.6, 0.24, 0.72, 0.9))
	for k in 4:
		var x: float = 0.62 + k * 0.025
		sg.append(_u(r, x, 0.24))
		sg.append(_u(r, x, 0.9))
	_rs(sg, sub(r, 0.76, 0.1, 0.98, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.24, 0.66), _u(r, 0.26, 0.66), _u(r, 0.32, 0.42), _u(r, 0.32, 0.16), _u(r, 0.32, 0.16), _u(r, 0.66, 0.16), _u(r, 0.66, 0.16), _u(r, 0.66, 0.24),
		_u(r, 0.72, 0.5), _u(r, 0.76, 0.5)]))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.87, 0.5), ms * 0.3, 0.55, 1.2)
	D(ci, _u(r, 0.87, 0.5), maxf(1.4, ms * 0.06), 0.6)
	_gband(ci, r, 0.05, 0.23, 0.6, Pal.tint(Pal.FLUID, 0.7))


# ================================================================ E442–E537 (2026-11-13): tenth batch, part two
# the water tanks and treatment (each by what it holds and how it is kept), the environmental and
# life-support units (air handlers, air revitalisation, scrubbers, precision coolers, fume hoods ...),
# the cold stores (freezers, fridges, a chiller) and the oxygen cabinets

# a centrifugal fan wheel in its scroll: the scroll's spiral, the wheel's blades, the hub
static func _fanw(sg: PackedVector2Array, c: Vector2, rad: float) -> void:
	var pv := c + Vector2(rad * 0.8, 0)
	for k in range(1, 8):
		var a: float = TAU * k / 8.0
		var q := c + Vector2(cos(a), sin(a)) * rad * (0.8 + 0.2 * k / 7.0)
		sg.append(pv)
		sg.append(q)
		pv = q
	sg.append(pv)
	sg.append(pv + Vector2(0, -rad * 0.5))
	for k in 6:
		var a: float = TAU * k / 6.0
		sg.append(c + Vector2.from_angle(a) * rad * 0.25)
		sg.append(c + Vector2.from_angle(a + 0.5) * rad * 0.62)


# a finned coil: its frame, the fin lines across it, the two header stubs at its side
static func _coilq(sg: PackedVector2Array, q: Rect2, n: int, vert: bool = true) -> void:
	_rs(sg, q)
	for k in n:
		var t: float = (k + 0.5) / n
		if vert:
			sg.append(Vector2(lerpf(q.position.x, q.end.x, t), q.position.y))
			sg.append(Vector2(lerpf(q.position.x, q.end.x, t), q.end.y))
		else:
			sg.append(Vector2(q.position.x, lerpf(q.position.y, q.end.y, t)))
			sg.append(Vector2(q.end.x, lerpf(q.position.y, q.end.y, t)))


# a pleated filter: its frame and the pleats' zigzag
static func _pleat(sg: PackedVector2Array, q: Rect2, n: int, vert: bool = true) -> void:
	_rs(sg, q)
	for k in n:
		var t0: float = float(k) / n
		var t1: float = (k + 0.5) / n
		var t2: float = float(k + 1) / n
		if vert:
			sg.append_array(PackedVector2Array([Vector2(q.position.x, lerpf(q.position.y, q.end.y, t0)), Vector2(q.end.x, lerpf(q.position.y, q.end.y, t1)),
				Vector2(q.end.x, lerpf(q.position.y, q.end.y, t1)), Vector2(q.position.x, lerpf(q.position.y, q.end.y, t2))]))
		else:
			sg.append_array(PackedVector2Array([Vector2(lerpf(q.position.x, q.end.x, t0), q.position.y), Vector2(lerpf(q.position.x, q.end.x, t1), q.end.y),
				Vector2(lerpf(q.position.x, q.end.x, t1), q.end.y), Vector2(lerpf(q.position.x, q.end.x, t2), q.position.y)]))


# ---------------------------------------------------------------- ARK-01 (x7): drinking water dispenser
# a drinking water dispenser: the inverted bottle on top (its shoulder and neck into the cooler), the
# cabinet, the hot and cold taps (their colours), the drip tray and its grille, the cup holder
static func water_dispenser(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.12, 0.34, 0.88, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.14, 0.02), _u(r, 0.86, 0.02), _u(r, 0.14, 0.02), _u(r, 0.14, 0.24), _u(r, 0.86, 0.02), _u(r, 0.86, 0.24),
		_u(r, 0.14, 0.24), _u(r, 0.4, 0.3), _u(r, 0.86, 0.24), _u(r, 0.6, 0.3), _u(r, 0.4, 0.3), _u(r, 0.4, 0.34), _u(r, 0.6, 0.3), _u(r, 0.6, 0.34),
		_u(r, 0.3, 0.44), _u(r, 0.3, 0.5), _u(r, 0.7, 0.44), _u(r, 0.7, 0.5), _u(r, 0.18, 0.62), _u(r, 0.82, 0.62),
		_u(r, 0.26, 0.6), _u(r, 0.26, 0.62), _u(r, 0.42, 0.6), _u(r, 0.42, 0.62), _u(r, 0.58, 0.6), _u(r, 0.58, 0.62), _u(r, 0.74, 0.6), _u(r, 0.74, 0.62),
		_u(r, 0.88, 0.4), _u(r, 0.98, 0.4), _u(r, 0.98, 0.4), _u(r, 0.98, 0.56)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.76, 0.07), _u(r, 0.86, 0.07), _u(r, 0.79, 0.13), _u(r, 0.86, 0.13), _u(r, 0.76, 0.19), _u(r, 0.86, 0.19)]), 0.5, 1.0)
	_lamp(ci, _u(r, 0.3, 0.42), maxf(1.4, r.size.x * 0.08), Pal.heat(0.85))
	_lamp(ci, _u(r, 0.7, 0.42), maxf(1.4, r.size.x * 0.08), Pal.tint(Pal.AIR, 0.85))


# ---------------------------------------------------------------- ARK-01: emergency core cooling water tank
# the reactor's emergency core cooling water: a pair of upright cylinders side by side (each with its
# two stiffening rings and its legs), the crossover over their tops with the nitrogen blanket's valve,
# the header joining their feet down to the check valve and the motorised valve (its actuator), the
# level transmitter's tube, the borated water in both
static func eccs_tank(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	for x0 in [0.06, 0.46]:
		_vves(sg, sub(r, x0, 0.14, x0 + 0.34, 0.84), w * 0.08, 4)
		for y in [0.4, 0.62]:
			_rs(sg, sub(r, x0 - 0.01, y - 0.01, x0 + 0.35, y + 0.01))
		sg.append_array(PackedVector2Array([_u(r, x0 + 0.05, 0.82), _u(r, x0 + 0.03, 0.98), _u(r, x0 + 0.29, 0.82), _u(r, x0 + 0.31, 0.98)]))
	sg.append_array(PackedVector2Array([_u(r, 0.23, 0.14), _u(r, 0.23, 0.06), _u(r, 0.23, 0.06), _u(r, 0.63, 0.06), _u(r, 0.63, 0.06), _u(r, 0.63, 0.14),
		_u(r, 0.43, 0.06), _u(r, 0.43, 0.0), _u(r, 0.39, 0.0), _u(r, 0.47, 0.0),
		_u(r, 0.23, 0.84), _u(r, 0.23, 0.9), _u(r, 0.23, 0.9), _u(r, 0.63, 0.9), _u(r, 0.63, 0.9), _u(r, 0.63, 0.84),
		_u(r, 0.43, 0.9), _u(r, 0.43, 0.94), _u(r, 0.43, 0.94), _u(r, 0.47, 0.94), _u(r, 0.55, 0.94), _u(r, 0.62, 0.94), _u(r, 0.7, 0.94), _u(r, 1.0, 0.94),
		_u(r, 0.47, 0.91), _u(r, 0.55, 0.97), _u(r, 0.02, 0.98), _u(r, 0.84, 0.98),
		_u(r, 0.8, 0.22), _u(r, 0.9, 0.22), _u(r, 0.8, 0.76), _u(r, 0.9, 0.76), _u(r, 0.88, 0.2), _u(r, 0.88, 0.78), _u(r, 0.92, 0.2), _u(r, 0.92, 0.78)]))
	_rs(sg, sub(r, 0.47, 0.91, 0.55, 0.97))
	_rs(sg, sub(r, 0.62, 0.91, 0.7, 0.97))
	_rs(sg, sub(r, 0.63, 0.85, 0.69, 0.91))
	_liquid_body(ci, sub(r, 0.47, 0.2, 0.79, 0.78), 0.82, Pal.VOLT.lerp(Pal.AIR, 0.45))
	S(ci, sg, 0.55, 1.3)
	_gband(ci, r, 0.885, 0.915, 0.32, Pal.tint(Pal.AIR, 0.9))
	_lamp(ci, _u(r, 0.43, 0.0), maxf(1.4, w * 0.03), Pal.tint(Pal.VOLT, 0.85))


# ---------------------------------------------------------------- ARK-01 / EV-55: sectional potable water tank
# the potable water tank, a bolted sectional panel tank: its panel grid (the flanged joints), the roof
# manhole and the ladder up the side, the vent mushroom, the overflow down the side, the level glass,
# the outlet at the foot, the water's level
static func sectional_tank(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.1, 0.86, 0.94))
	for k in range(1, 4):
		var x: float = 0.06 + k * 0.2
		sg.append(_u(r, x, 0.1))
		sg.append(_u(r, x, 0.94))
	for k in range(1, 3):
		var y: float = 0.1 + k * 0.28
		sg.append(_u(r, 0.06, y))
		sg.append(_u(r, 0.86, y))
	_rs(sg, sub(r, 0.32, 0.04, 0.5, 0.1))
	sg.append_array(PackedVector2Array([_u(r, 0.66, 0.1), _u(r, 0.66, 0.04), _u(r, 0.62, 0.04), _u(r, 0.7, 0.04),
		_u(r, 0.88, 0.12), _u(r, 0.88, 0.96), _u(r, 0.96, 0.12), _u(r, 0.96, 0.96), _u(r, 0.02, 0.14), _u(r, 0.02, 0.98),
		_u(r, 0.02, 0.14), _u(r, 0.06, 0.14), _u(r, 0.46, 0.94), _u(r, 0.46, 1.0)]))
	for k in 6:
		var y: float = 0.2 + k * 0.13
		sg.append(_u(r, 0.88, y))
		sg.append(_u(r, 0.96, y))
	S(ci, sg, 0.55, 1.2)


# ---------------------------------------------------------------- RO-128: ballast tank
# the ballast tanks seen in section: the run between the hull plates split into compartments by double
# bulkheads (each with its manhole), the frames between them, each compartment's air vent up to its
# gooseneck and its sounding pipe, and the sea water standing at a different level in each
static func ballast_tank(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.01, 0.06, 0.99, 0.94))
	var n := clampi(int(r.size.x / (r.size.y * 0.9)), 2, 8)
	var fr := PackedVector2Array()
	var hl := PackedVector2Array()
	var cw: float = 0.98 / n
	for k in n:
		var x0: float = 0.01 + k * cw
		if k > 0:
			sg.append_array(PackedVector2Array([_u(r, x0 - 0.004, 0.06), _u(r, x0 - 0.004, 0.94), _u(r, x0 + 0.004, 0.06), _u(r, x0 + 0.004, 0.94)]))
			_arcs(hl, _u(r, x0, 0.62), cw * r.size.x * 0.06, r.size.y * 0.1, 0.0, TAU, 6)
		for j in [0.33, 0.66]:
			fr.append(_u(r, x0 + cw * j, 0.08))
			fr.append(_u(r, x0 + cw * j, 0.92))
		var vx: float = x0 + cw * 0.82
		sg.append_array(PackedVector2Array([_u(r, vx, 0.06), _u(r, vx, -0.04), _u(r, vx, -0.04), _u(r, vx + cw * 0.08, -0.04), _u(r, vx + cw * 0.08, -0.04), _u(r, vx + cw * 0.08, 0.0),
			_u(r, x0 + cw * 0.12, 0.0), _u(r, x0 + cw * 0.12, 0.9)]))
	S(ci, sg, 0.6, 1.3)
	S(ci, fr, 0.3, 1.0)
	S(ci, hl, 0.5, 1.1)


# ---------------------------------------------------------------- MED-47: biological waste tank
# the clinic's biological waste tank: the drum and its heating jacket (the bands of its trace), the
# clamped lid (its locking lever), the vent through its sterilising filter cartridge, the drain valve
# at the foot
static func bio_waste_tank(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	var sg := PackedVector2Array()
	_vves(sg, sub(r, 0.14, 0.18, 0.78, 0.9), w * 0.06, 3)
	_rs(sg, sub(r, 0.1, 0.14, 0.82, 0.2))
	_rs(sg, sub(r, 0.82, 0.02, 0.94, 0.32))
	sg.append_array(PackedVector2Array([_u(r, 0.6, 0.14), _u(r, 0.74, 0.06), _u(r, 0.82, 0.17), _u(r, 0.88, 0.17), _u(r, 0.88, 0.17), _u(r, 0.88, 0.32),
		_u(r, 0.46, 0.9), _u(r, 0.46, 0.98), _u(r, 0.4, 0.94), _u(r, 0.52, 0.98), _u(r, 0.4, 0.98), _u(r, 0.52, 0.94),
		_u(r, 0.2, 0.86), _u(r, 0.16, 1.0), _u(r, 0.72, 0.86), _u(r, 0.76, 1.0)]))
	S(ci, sg, 0.55, 1.2)
	for y in [0.36, 0.5, 0.64]:
		_gband(ci, r, 0.15, 0.77, y, Pal.heat(0.32))
	_lamp(ci, _u(r, 0.88, 0.08), maxf(1.4, w * 0.04), Pal.tint(Pal.VOLT, 0.85))


# ---------------------------------------------------------------- BL-88: fish holding tank
# the fish holding tank: the glass tank in its frame and lid, the water and a few fish in it, the air
# stone's bubbles, the hang-on filter box on the side and its return spout
static func fish_tank(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.16, 0.8, 0.94))
	_rs(sg, sub(r, 0.04, 0.1, 0.82, 0.16))
	_rs(sg, sub(r, 0.82, 0.18, 0.98, 0.5))
	sg.append_array(PackedVector2Array([_u(r, 0.04, 0.94), _u(r, 0.82, 0.94), _u(r, 0.04, 0.98), _u(r, 0.82, 0.98), _u(r, 0.86, 0.5), _u(r, 0.86, 0.7),
		_u(r, 0.82, 0.24), _u(r, 0.74, 0.3), _u(r, 0.6, 0.9), _u(r, 0.6, 0.2)]))
	for p in [Vector2(0.24, 0.48), Vector2(0.44, 0.66), Vector2(0.3, 0.78)]:
		sg.append_array(PackedVector2Array([_u(r, p.x, p.y), _u(r, p.x + 0.08, p.y - 0.02), _u(r, p.x, p.y), _u(r, p.x + 0.08, p.y + 0.02),
			_u(r, p.x + 0.08, p.y - 0.02), _u(r, p.x + 0.12, p.y), _u(r, p.x + 0.08, p.y + 0.02), _u(r, p.x + 0.12, p.y)]))
	S(ci, sg, 0.55, 1.1)
	for y in [0.4, 0.56, 0.72]:
		_lamp(ci, _u(r, 0.6 + (y - 0.56) * 0.1, y), maxf(1.2, r.size.x * 0.025), Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- BL-88: nutrient solution tank
# the nutrient tank: the cone-bottomed tank on its legs, the mixer's motor on the lid and its shaft and
# impeller down inside, the outlet out of the cone, the solution's level
static func nutrient_mixer_tank(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.12, 0.2), _u(r, 0.12, 0.66), _u(r, 0.88, 0.2), _u(r, 0.88, 0.66), _u(r, 0.12, 0.66), _u(r, 0.46, 0.84), _u(r, 0.88, 0.66), _u(r, 0.54, 0.84),
		_u(r, 0.46, 0.84), _u(r, 0.54, 0.84), _u(r, 0.5, 0.84), _u(r, 0.5, 0.94), _u(r, 0.42, 0.94), _u(r, 0.58, 0.94),
		_u(r, 0.16, 0.66), _u(r, 0.1, 1.0), _u(r, 0.84, 0.66), _u(r, 0.9, 1.0), _u(r, 0.08, 0.2), _u(r, 0.92, 0.2)])
	_rs(sg, sub(r, 0.38, 0.02, 0.62, 0.2))
	sg.append_array(PackedVector2Array([_u(r, 0.38, 0.06), _u(r, 0.62, 0.06)]))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.2), _u(r, 0.5, 0.6), _u(r, 0.36, 0.56), _u(r, 0.64, 0.64), _u(r, 0.36, 0.64), _u(r, 0.64, 0.56)]), 0.38, 1.0)


# ---------------------------------------------------------------- BL-88: constructed wetland pond
# the constructed wetland: the shallow basin (its sloped sides), the gravel bed in it, the reeds
# growing up through the water, the inlet pipe in at one end and the weir out at the other
static func wetland_pond(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 0.1, 0.94), _u(r, 0.1, 0.94), _u(r, 0.9, 0.94), _u(r, 0.9, 0.94), _u(r, 1.0, 0.3),
		_u(r, 0.06, 0.74), _u(r, 0.94, 0.74), _u(r, 0.0, 0.18), _u(r, 0.14, 0.18), _u(r, 0.14, 0.18), _u(r, 0.14, 0.4), _u(r, 0.9, 0.42), _u(r, 0.98, 0.42)])
	var rd := PackedVector2Array()
	for k in 9:
		var x: float = 0.2 + k * 0.08
		var top: float = 0.06 + float((k * 7) % 4) * 0.05
		rd.append(_u(r, x, 0.74))
		rd.append(_u(r, x + 0.02, top))
		if k % 2 == 0:
			rd.append(_u(r, x + 0.01, 0.4))
			rd.append(_u(r, x + 0.05, 0.3))
	S(ci, sg, 0.55, 1.1)
	S(ci, rd, 0.45, 1.0)


# ---------------------------------------------------------------- BL-88 / DR-150: water recovery unit
# the water recovery rack: the multifiltration bed column, the two reverse-osmosis membrane housings
# lying across, the UV tube, the feed pump at the foot, the product line out, the frame
static func water_recovery(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.0), _u(r, 0.04, 1.0), _u(r, 0.96, 0.0), _u(r, 0.96, 1.0)])
	_vves(sg, sub(r, 0.1, 0.06, 0.34, 0.66), r.size.x * 0.04, 3)
	for y in [0.2, 0.32, 0.44]:
		sg.append(_u(r, 0.1, y))
		sg.append(_u(r, 0.34, y))
	for y0 in [0.1, 0.3]:
		_hves(sg, sub(r, 0.42, y0, 0.92, y0 + 0.12), r.size.y * 0.02, 3)
	_rs(sg, sub(r, 0.44, 0.52, 0.9, 0.58))
	_rs(sg, sub(r, 0.12, 0.76, 0.3, 0.94))
	_rs(sg, sub(r, 0.3, 0.8, 0.5, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.22, 0.66), _u(r, 0.22, 0.76), _u(r, 0.5, 0.85), _u(r, 0.66, 0.85), _u(r, 0.66, 0.85), _u(r, 0.66, 0.58),
		_u(r, 0.92, 0.16), _u(r, 0.94, 0.16), _u(r, 0.94, 0.16), _u(r, 0.94, 0.36), _u(r, 0.92, 0.36), _u(r, 0.94, 0.36), _u(r, 0.34, 0.16), _u(r, 0.42, 0.16)]))
	for y0 in [0.1, 0.3]:
		_liquid_body(ci, sub(r, 0.44, y0 + 0.01, 0.9, y0 + 0.11), 0.75 if y0 < 0.2 else 0.5, Pal.FLUID if y0 < 0.2 else Pal.AIR)
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.45, 0.89, 0.55, Pal.tint(Pal.VOLT, 0.8))
	_gband(ci, r, 0.43, 0.91, 0.36, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- DR-150: mud tank with agitator
# the active mud tank: the open-topped tank and its walkway rail on top, the agitator's gear motor on
# the walkway and its shaft down to the paddles, the mud gun's nozzle, the suction at the foot, the
# mud's level
static func mud_agitator_tank(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.24), _u(r, 0.04, 0.96), _u(r, 0.04, 0.96), _u(r, 0.96, 0.96), _u(r, 0.96, 0.96), _u(r, 0.96, 0.24),
		_u(r, 0.0, 0.24), _u(r, 1.0, 0.24), _u(r, 0.0, 0.08), _u(r, 1.0, 0.08), _u(r, 0.0, 0.08), _u(r, 0.0, 0.24), _u(r, 0.5, 0.08), _u(r, 0.5, 0.24), _u(r, 1.0, 0.08), _u(r, 1.0, 0.24),
		_u(r, 0.86, 0.24), _u(r, 0.74, 0.5), _u(r, 0.96, 0.88), _u(r, 1.0, 0.88)])
	_rs(sg, sub(r, 0.28, 0.1, 0.44, 0.24))
	_rs(sg, sub(r, 0.3, 0.02, 0.42, 0.1))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.36, 0.24), _u(r, 0.36, 0.84), _u(r, 0.24, 0.8), _u(r, 0.48, 0.88), _u(r, 0.24, 0.88), _u(r, 0.48, 0.8)]), 0.4, 1.2)
	for x in [0.18, 0.46, 0.74]:
		D(ci, _u(r, x, 0.42), maxf(1.2, r.size.y * 0.012), 0.5)


# ---------------------------------------------------------------- CH-110 / TW-64: hydraulic oil reservoir
# the hydraulic reservoir lying low: the tank and its baffle, the bolted clean-out cover, the return
# filter and the filler-breather on its lid, the suction strainer inside, the level and temperature
# gauge, the drain, the feet
static func hyd_reservoir(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.24, 0.96, 0.9))
	_rs(sg, sub(r, 0.56, 0.08, 0.68, 0.24))
	_rs(sg, sub(r, 0.76, 0.16, 0.84, 0.24))
	_rs(sg, sub(r, 0.86, 0.36, 0.92, 0.8))
	sg.append_array(PackedVector2Array([_u(r, 0.62, 0.08), _u(r, 0.62, 0.0), _u(r, 0.04, 0.27), _u(r, 0.96, 0.27),
		_u(r, 0.1, 0.9), _u(r, 0.1, 0.98), _u(r, 0.9, 0.9), _u(r, 0.9, 0.98), _u(r, 0.3, 0.9), _u(r, 0.3, 0.96)]))
	S(ci, sg, 0.6, 1.4)
	var ins := PackedVector2Array([_u(r, 0.5, 0.3), _u(r, 0.5, 0.9), _u(r, 0.68, 0.24), _u(r, 0.68, 0.62)])
	_rs(ins, sub(r, 0.6, 0.62, 0.76, 0.86))
	_rs(ins, sub(r, 0.12, 0.36, 0.38, 0.78))
	S(ci, ins, 0.26, 1.0)
	A(ci, _u(r, 0.8, 0.16), r.size.y * 0.06, PI, TAU, 0.55, 1.1)
	_gband(ci, r, 0.865, 0.915, 0.56, Pal.tint(Pal.FLUID, 0.9))


# ---------------------------------------------------------------- PS-12 / MT-140: sanitary module
# the sanitary module: its cubicle frame and door, the vacuum toilet (bowl and seat) on its flush
# valve, the wash basin and its tap on the partition, the mirror over it, the vacuum tank and its pipes
# under the floor, the floor drain
static func sanitary_module(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.74))
	sg.append_array(PackedVector2Array([_u(r, 0.52, 0.04), _u(r, 0.52, 0.74), _u(r, 0.62, 0.46), _u(r, 0.9, 0.46), _u(r, 0.86, 0.46), _u(r, 0.86, 0.38), _u(r, 0.86, 0.38), _u(r, 0.8, 0.38),
		_u(r, 0.12, 0.5), _u(r, 0.38, 0.5), _u(r, 0.12, 0.5), _u(r, 0.16, 0.66), _u(r, 0.38, 0.5), _u(r, 0.34, 0.66), _u(r, 0.16, 0.66), _u(r, 0.34, 0.66),
		_u(r, 0.26, 0.66), _u(r, 0.26, 0.82), _u(r, 0.26, 0.82), _u(r, 0.5, 0.82), _u(r, 0.76, 0.46), _u(r, 0.76, 0.82), _u(r, 0.76, 0.82), _u(r, 0.6, 0.82),
		_u(r, 0.04, 0.74), _u(r, 0.04, 0.98), _u(r, 0.96, 0.74), _u(r, 0.96, 0.98), _u(r, 0.04, 0.98), _u(r, 0.96, 0.98)]))
	_rs(sg, sub(r, 0.14, 0.36, 0.36, 0.5))
	_rs(sg, sub(r, 0.64, 0.12, 0.88, 0.3))
	_hves(sg, sub(r, 0.5, 0.78, 0.9, 0.94), r.size.y * 0.03, 3)
	_rs(sg, sub(r, 0.06, 0.06, 0.12, 0.72))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.64, 0.88, 0.48, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- TS-1: small coolant reservoir
# the trainer's little coolant reservoir, drawn plain to read at its size: the bottle and its wall's
# thickness, the filler cap on its flange, the glass sight tube outside the wall on its two connections
# (the coolant standing in it, its two marks), the hose in on its flange, the drain valve at the foot,
# the light catching the coolant along the wall
static func coolant_bottle(ci: CanvasItem, r: Rect2) -> void:
	var col := Pal.FLUID.lerp(Pal.AIR, 0.5)
	_fillc(ci, PackedVector2Array([_u(r, 0.135, 0.48), _u(r, 0.17, 0.48), _u(r, 0.17, 0.9), _u(r, 0.135, 0.9)]), Color(col.r, col.g, col.b, 0.55))
	var sg := PackedVector2Array([_u(r, 0.0, 0.46), _u(r, 0.1, 0.46), _u(r, 0.03, 0.4), _u(r, 0.03, 0.52), _u(r, 0.3, 0.94), _u(r, 0.3, 0.97),
		_u(r, 0.78, 0.36), _u(r, 0.84, 0.36), _u(r, 0.78, 0.86), _u(r, 0.84, 0.86), _u(r, 0.26, 0.22), _u(r, 0.62, 0.22),
		_u(r, 0.94, 0.5), _u(r, 0.98, 0.5), _u(r, 0.94, 0.7), _u(r, 0.98, 0.7)])
	_rs(sg, sub(r, 0.1, 0.22, 0.78, 0.94))
	_rs(sg, sub(r, 0.32, 0.06, 0.56, 0.2))
	_rs(sg, sub(r, 0.84, 0.3, 0.96, 0.92))
	_rs(sg, sub(r, 0.24, 0.97, 0.36, 1.0))
	_fillc(ci, PackedVector2Array([_u(r, 0.86, 0.5), _u(r, 0.94, 0.5), _u(r, 0.94, 0.9), _u(r, 0.86, 0.9)]), Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.9))
	S(ci, sg, 0.6, 1.3)
	var iw := PackedVector2Array()
	_rs(iw, sub(r, 0.13, 0.25, 0.75, 0.91))
	S(ci, iw, 0.32, 1.0)


# ---------------------------------------------------------------- 11 ships: fresh water tank
# a fresh water tank: lying on two saddles where it is long (else standing on its skirt), the manway,
# the vent with its insect screen, the level glass on its two cocks, the outlet and drain, the water
static func fresh_water_tank(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	if r.size.x > r.size.y * 1.3:
		var q := sub(r, 0.04, 0.12, 0.84, 0.8)
		_hves(sg, q, q.size.y * 0.32, 4)
		for x in [0.2, 0.62]:
			sg.append_array(PackedVector2Array([_u(r, x, 0.78), _u(r, x - 0.03, 0.96), _u(r, x + 0.08, 0.78), _u(r, x + 0.11, 0.96), _u(r, x - 0.05, 0.96), _u(r, x + 0.13, 0.96)]))
		_rs(sg, sub(r, 0.36, 0.06, 0.48, 0.12))
		sg.append_array(PackedVector2Array([_u(r, 0.62, 0.12), _u(r, 0.62, 0.02), _u(r, 0.58, 0.02), _u(r, 0.66, 0.02),
			_u(r, 0.82, 0.3), _u(r, 0.9, 0.3), _u(r, 0.82, 0.66), _u(r, 0.9, 0.66), _u(r, 0.88, 0.24), _u(r, 0.88, 0.72), _u(r, 0.92, 0.24), _u(r, 0.92, 0.72),
			_u(r, 0.44, 0.8), _u(r, 0.44, 0.92), _u(r, 0.44, 0.92), _u(r, 1.0, 0.92)]))
		S(ci, sg, 0.55, 1.2)
		_gband(ci, r, 0.88, 0.92, 0.36, Pal.tint(Pal.FLUID, 0.9))
	else:
		var q := sub(r, 0.12, 0.08, 0.74, 0.84)
		_vves(sg, q, q.size.x * 0.18, 4)
		sg.append_array(PackedVector2Array([_u(r, 0.2, 0.8), _u(r, 0.16, 0.98), _u(r, 0.66, 0.8), _u(r, 0.7, 0.98), _u(r, 0.12, 0.98), _u(r, 0.74, 0.98),
			_u(r, 0.43, 0.08), _u(r, 0.43, 0.02), _u(r, 0.37, 0.02), _u(r, 0.49, 0.02),
			_u(r, 0.74, 0.24), _u(r, 0.84, 0.24), _u(r, 0.74, 0.72), _u(r, 0.84, 0.72), _u(r, 0.82, 0.18), _u(r, 0.82, 0.78), _u(r, 0.86, 0.18), _u(r, 0.86, 0.78),
			_u(r, 0.43, 0.84), _u(r, 0.43, 0.92), _u(r, 0.43, 0.92), _u(r, 1.0, 0.92)]))
		_rs(sg, sub(r, 0.02, 0.36, 0.12, 0.52))
		S(ci, sg, 0.55, 1.2)
		_gband(ci, r, 0.82, 0.86, 0.32, Pal.tint(Pal.FLUID, 0.9))


# ---------------------------------------------------------------- ARK-01 (x11): reverse-osmosis water plant
# the ARK's water plant, a reverse-osmosis rack: the two cartridge prefilters, the high-pressure pump
# and its motor at the foot, the three membrane pressure tubes racked across (their end caps), the UV
# steriliser, the permeate line out and the brine line down, the frame
static func ro_rack(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.02, 0.0), _u(r, 0.02, 1.0), _u(r, 0.98, 0.0), _u(r, 0.98, 1.0), _u(r, 0.02, 0.98), _u(r, 0.98, 0.98)])
	for x0 in [0.06, 0.2]:
		_vves(sg, sub(r, x0, 0.08, x0 + 0.1, 0.5), r.size.x * 0.02, 3)
	for k in 3:
		var y0: float = 0.08 + k * 0.14
		_rs(sg, sub(r, 0.36, y0, 0.94, y0 + 0.08))
		sg.append_array(PackedVector2Array([_u(r, 0.38, y0), _u(r, 0.38, y0 + 0.08), _u(r, 0.92, y0), _u(r, 0.92, y0 + 0.08)]))
	_rs(sg, sub(r, 0.06, 0.68, 0.24, 0.94))
	_mot(sg, sub(r, 0.24, 0.72, 0.6, 0.94))
	_hves(sg, sub(r, 0.64, 0.56, 0.94, 0.64), r.size.y * 0.02, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.15, 0.5), _u(r, 0.15, 0.68), _u(r, 0.25, 0.08), _u(r, 0.25, 0.04), _u(r, 0.25, 0.04), _u(r, 0.11, 0.04),
		_u(r, 0.33, 0.12), _u(r, 0.33, 0.4), _u(r, 0.33, 0.12), _u(r, 0.36, 0.12), _u(r, 0.33, 0.26), _u(r, 0.36, 0.26), _u(r, 0.33, 0.4), _u(r, 0.36, 0.4),
		_u(r, 0.94, 0.6), _u(r, 0.98, 0.6), _u(r, 0.94, 0.12), _u(r, 0.96, 0.12), _u(r, 0.96, 0.12), _u(r, 0.96, 0.56)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.65, 0.93, 0.6, Pal.tint(Pal.VOLT, 0.8))
	_gband(ci, r, 0.37, 0.93, 0.12, Pal.tint(Pal.FLUID, 0.65))


# ---------------------------------------------------------------- 16 ships: air handling unit
# an air handling unit, its sections along the airflow: the mixing box (the damper blades), the pleated
# filter bank, the cooling coil (its fins) and its drain pan, the centrifugal fan (the wheel in its
# scroll), the discharge plenum; the section doors' handles, the airflow arrow
static func ahu_sections(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	var vert := r.size.y > r.size.x * 1.2
	var q := Rect2(r.position, Vector2(r.size.y, r.size.x)) if vert else r
	var X := func(u: float, v: float) -> Vector2:
		return r.position + (Vector2(v * r.size.x, u * r.size.y) if vert else Vector2(u * r.size.x, v * r.size.y))
	sg.append_array(PackedVector2Array([X.call(0.0, 0.06), X.call(1.0, 0.06), X.call(0.0, 0.94), X.call(1.0, 0.94), X.call(0.0, 0.06), X.call(0.0, 0.94), X.call(1.0, 0.06), X.call(1.0, 0.94)]))
	for u in [0.18, 0.36, 0.56, 0.84]:
		sg.append(X.call(u, 0.06))
		sg.append(X.call(u, 0.94))
	for k in 4:
		var v: float = 0.18 + k * 0.2
		sg.append(X.call(0.03, v))
		sg.append(X.call(0.15, v + 0.08))
	for k in 6:
		var v0: float = 0.1 + k * 0.13
		sg.append_array(PackedVector2Array([X.call(0.2, v0), X.call(0.34, v0 + 0.065), X.call(0.34, v0 + 0.065), X.call(0.2, v0 + 0.13)]))
	for k in 5:
		var u: float = 0.39 + k * 0.035
		sg.append(X.call(u, 0.12))
		sg.append(X.call(u, 0.82))
	sg.append_array(PackedVector2Array([X.call(0.38, 0.86), X.call(0.55, 0.86), X.call(0.9, 0.5), X.call(0.98, 0.5), X.call(0.98, 0.5), X.call(0.95, 0.44), X.call(0.98, 0.5), X.call(0.95, 0.56)]))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	var c: Vector2 = X.call(0.7, 0.5)
	_fanw(fw, c, minf(q.size.x * 0.11, q.size.y * 0.3))
	S(ci, fw, 0.5, 1.1)
	var d0: Vector2 = X.call(0.09, 0.92)
	_lamp(ci, d0, maxf(1.4, minf(r.size.x, r.size.y) * 0.03), Pal.tint(Pal.AIR, 0.85))


# ---------------------------------------------------------------- ARK-01 / HB-86: oxygen generation plant
# the oxygen generation plant: the electrolyser's cell stack between its end plates (the tie rods,
# the plates), the water feed tank, the hydrogen separator and the oxygen separator over it, the
# oxygen line out to the air, the hydrogen vent, the power rectifier box
static func o2_generator_plant(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.46, 0.58, 0.86))
	_rs(sg, sub(r, 0.02, 0.42, 0.06, 0.9))
	_rs(sg, sub(r, 0.58, 0.42, 0.62, 0.9))
	for k in range(1, 8):
		var x: float = 0.06 + k * 0.065
		sg.append(_u(r, x, 0.46))
		sg.append(_u(r, x, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.48), _u(r, 0.62, 0.48), _u(r, 0.02, 0.84), _u(r, 0.62, 0.84)]))
	_vves(sg, sub(r, 0.08, 0.06, 0.24, 0.38), r.size.x * 0.03, 3)
	_vves(sg, sub(r, 0.32, 0.06, 0.48, 0.38), r.size.x * 0.03, 3)
	_rs(sg, sub(r, 0.7, 0.5, 0.96, 0.9))
	_rs(sg, sub(r, 0.7, 0.1, 0.96, 0.38))
	sg.append_array(PackedVector2Array([_u(r, 0.16, 0.38), _u(r, 0.16, 0.46), _u(r, 0.4, 0.38), _u(r, 0.4, 0.46), _u(r, 0.16, 0.06), _u(r, 0.16, 0.0),
		_u(r, 0.4, 0.06), _u(r, 0.4, 0.02), _u(r, 0.4, 0.02), _u(r, 1.0, 0.02), _u(r, 0.62, 0.66), _u(r, 0.7, 0.66), _u(r, 0.62, 0.24), _u(r, 0.7, 0.24),
		_u(r, 0.04, 0.9), _u(r, 0.04, 0.98), _u(r, 0.6, 0.9), _u(r, 0.6, 0.98)]))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.33, 0.47, 0.22, Pal.tint(Pal.AIR, 0.8))
	_gband(ci, r, 0.09, 0.23, 0.22, Pal.heat(0.7))
	_gband(ci, r, 0.71, 0.95, 0.24, Pal.tint(Pal.FLUID, 0.7))
	_lamp(ci, _u(r, 0.83, 0.6), maxf(1.4, minf(r.size.x, r.size.y) * 0.03), Pal.tint(Pal.VOLT, 0.85))


# ---------------------------------------------------------------- MED-47: regenerative CO2 removal (twin bed)
# the clinic's air regeneration: the two molecular-sieve beds standing side by side (one adsorbing, one
# baking out), the four-way switching valves over them and their actuators, the blower, the regen
# heater, the precooler, the ducts in and out
static func twin_bed_regen(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	for x0 in [0.06, 0.28]:
		_vves(sg, sub(r, x0, 0.22, x0 + 0.16, 0.9), r.size.x * 0.03, 3)
		for y in [0.4, 0.58, 0.76]:
			sg.append(_u(r, x0, y))
			sg.append(_u(r, x0 + 0.16, y))
	_rs(sg, sub(r, 0.12, 0.06, 0.38, 0.16))
	sg.append_array(PackedVector2Array([_u(r, 0.14, 0.16), _u(r, 0.14, 0.22), _u(r, 0.36, 0.16), _u(r, 0.36, 0.22), _u(r, 0.25, 0.06), _u(r, 0.25, 0.0),
		_u(r, 0.38, 0.11), _u(r, 0.52, 0.11), _u(r, 0.14, 0.9), _u(r, 0.14, 0.96), _u(r, 0.36, 0.9), _u(r, 0.36, 0.96), _u(r, 0.14, 0.96), _u(r, 0.6, 0.96)]))
	_rs(sg, sub(r, 0.52, 0.04, 0.66, 0.18))
	_coilq(sg, sub(r, 0.72, 0.1, 0.96, 0.4), 6)
	_rs(sg, sub(r, 0.6, 0.6, 0.96, 0.96))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.78, 0.78), minf(r.size.x, r.size.y) * 0.13)
	S(ci, fw, 0.5, 1.1)
	_gband(ci, r, 0.53, 0.65, 0.11, Pal.heat(0.8))
	_gband(ci, r, 0.73, 0.95, 0.26, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- ARK-01: ring air machine (axial fan)
# the ring's air machine: the duct through it, the axial fan in its casing (the blades, the motor
# hub, the guide vanes), the splitter silencer's baffles after it, the heater coil before it, the
# flexible connections at both ends
static func axial_air_machine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.0, 0.2), _u(r, 1.0, 0.2), _u(r, 0.0, 0.8), _u(r, 1.0, 0.8)])
	for x in [0.06, 0.1, 0.9, 0.94]:
		sg.append(_u(r, x, 0.16))
		sg.append(_u(r, x, 0.84))
	_coilq(sg, sub(r, 0.12, 0.24, 0.24, 0.76), 4)
	for y in [0.32, 0.5, 0.68]:
		_rs(sg, sub(r, 0.66, y - 0.04, 0.88, y + 0.04))
	_rs(sg, sub(r, 0.3, 0.12, 0.6, 0.88))
	S(ci, sg, 0.55, 1.2)
	var c := _u(r, 0.45, 0.5)
	O(ci, c, ms * 0.3, 0.55, 1.2)
	var bl := PackedVector2Array()
	for k in 7:
		var a: float = TAU * k / 7.0
		bl.append(c + Vector2.from_angle(a) * ms * 0.08)
		bl.append(c + Vector2.from_angle(a + 0.4) * ms * 0.28)
	S(ci, bl, 0.45, 1.1)
	D(ci, c, maxf(1.6, ms * 0.07), 0.6)
	_gband(ci, r, 0.13, 0.23, 0.5, Pal.heat(0.7))


# ---------------------------------------------------------------- ARK-01: in-row rack cooler
# the in-row rack cooler: the tall cabinet, the three EC fans stacked on its face (rings and hubs),
# the chilled-water coil behind them, the condensate pump at the foot, the controller's display, the
# perforated top grille
static func inrow_cooler(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	_coilq(sg, sub(r, 0.1, 0.12, 0.9, 0.84), 8)
	_rs(sg, sub(r, 0.12, 0.86, 0.36, 0.96))
	_rs(sg, sub(r, 0.6, 0.86, 0.88, 0.95))
	for k in 5:
		var x: float = 0.14 + k * 0.17
		sg.append(_u(r, x, 0.04))
		sg.append(_u(r, x + 0.08, 0.1))
	S(ci, sg, 0.5, 1.1)
	for k in 3:
		var c := _u(r, 0.5, 0.24 + k * 0.25)
		O(ci, c, ms * 0.3, 0.6, 1.3)
		D(ci, c, maxf(1.4, ms * 0.06), 0.65)
	E.Rc(ci, sub(r, 0.62, 0.88, 0.86, 0.93), Pal.tint(Pal.FLUID, 0.75), 1.0)
	_gband(ci, r, 0.11, 0.89, 0.13, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- BL-88: CO2 scrubber
# the CO2 scrubber: the stack of absorbent canisters in their rack (each canister's clamp bands), the
# fan over them, the inlet louvres under them, the CO2 sensor and its lamp, the outlet up
static func co2_canister_scrubber(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	for k in 3:
		var y0: float = 0.28 + k * 0.2
		_rs(sg, sub(r, 0.16, y0, 0.84, y0 + 0.16))
		sg.append_array(PackedVector2Array([_u(r, 0.3, y0), _u(r, 0.3, y0 + 0.16), _u(r, 0.7, y0), _u(r, 0.7, y0 + 0.16)]))
	for k in 4:
		var x: float = 0.16 + k * 0.18
		sg.append(_u(r, x, 0.9))
		sg.append(_u(r, x + 0.1, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.02), _u(r, 0.5, 0.0)]))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.42, 0.14), ms * 0.16)
	S(ci, fw, 0.5, 1.1)
	R(ci, sub(r, 0.7, 0.08, 0.88, 0.2), 0.55)
	_lamp(ci, _u(r, 0.79, 0.14), maxf(1.4, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	for k in 3:
		_gband(ci, r, 0.17, 0.83, 0.36 + k * 0.2, Pal.tint(Pal.VOLT, 0.55))


# ---------------------------------------------------------------- BL-88: refrigerant dehumidifier
# the dehumidifier: the evaporator coil the damp air crosses first, the condenser coil after it, the
# compressor (its dome) and the fan, the condensate dripping into the tank with its float at the foot
static func dehumidifier_unit(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	_coilq(sg, sub(r, 0.12, 0.08, 0.88, 0.22), 7)
	_coilq(sg, sub(r, 0.12, 0.26, 0.88, 0.4), 7)
	_rs(sg, sub(r, 0.12, 0.78, 0.88, 0.94))
	_vves(sg, sub(r, 0.16, 0.5, 0.4, 0.74), r.size.x * 0.06, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.2, 0.84), _u(r, 0.8, 0.84), _u(r, 0.66, 0.84), _u(r, 0.66, 0.92), _u(r, 0.5, 0.4), _u(r, 0.5, 0.78)]))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.68, 0.6), ms * 0.16)
	S(ci, fw, 0.5, 1.1)
	D(ci, _u(r, 0.66, 0.85), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.13, 0.87, 0.15, Pal.tint(Pal.AIR, 0.7))
	_gband(ci, r, 0.13, 0.87, 0.33, Pal.heat(0.65))
	_gband(ci, r, 0.13, 0.87, 0.88, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- BL-88: life support rack
# the habitat's life support rack, four bays: the oxygen bottle and its regulator, the scrubber
# cartridge, the circulation fan, the monitor panel (its gauges and alarm lamp)
static func life_support_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.02, 0.96, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.04, 0.5), _u(r, 0.96, 0.5), _u(r, 0.5, 0.02), _u(r, 0.5, 0.98)]))
	_vbot(sg, sub(r, 0.14, 0.06, 0.4, 0.46))
	_rs(sg, sub(r, 0.58, 0.08, 0.88, 0.44))
	for y in [0.16, 0.26, 0.36]:
		sg.append(_u(r, 0.58, y))
		sg.append(_u(r, 0.88, y))
	_rs(sg, sub(r, 0.58, 0.58, 0.9, 0.9))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.27, 0.74), ms * 0.16)
	S(ci, fw, 0.5, 1.1)
	for x in [0.66, 0.82]:
		O(ci, _u(r, x, 0.68), ms * 0.06, 0.55)
	_lamp(ci, _u(r, 0.74, 0.82), maxf(1.4, ms * 0.04), Pal.heat(0.85))
	_gband(ci, r, 0.15, 0.39, 0.2, Pal.tint(Pal.AIR, 0.8))
	_gband(ci, r, 0.59, 0.87, 0.3, Pal.tint(Pal.VOLT, 0.6))


# ---------------------------------------------------------------- DC-84 (x4): downflow precision cooler (CRAH)
# the computer room air handler: the return-air filters across the top (their pleats), the A-frame
# chilled-water coil under them and its drip tray, the EC fans at the foot pushing down into the raised
# floor, the controller's display on the door
static func crah_downflow(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	_pleat(sg, sub(r, 0.1, 0.04, 0.9, 0.16), 6, false)
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.2), _u(r, 0.5, 0.56), _u(r, 0.88, 0.2), _u(r, 0.5, 0.56), _u(r, 0.18, 0.2), _u(r, 0.5, 0.5), _u(r, 0.82, 0.2), _u(r, 0.5, 0.5),
		_u(r, 0.32, 0.6), _u(r, 0.68, 0.6), _u(r, 0.32, 0.6), _u(r, 0.32, 0.56), _u(r, 0.68, 0.6), _u(r, 0.68, 0.56)]))
	for k in 4:
		var t: float = 0.3 + k * 0.15
		sg.append(_u(r, 0.12 + 0.38 * t, 0.2 + 0.36 * t))
		sg.append(_u(r, 0.18 + 0.32 * t, 0.2 + 0.3 * t))
		sg.append(_u(r, 0.88 - 0.38 * t, 0.2 + 0.36 * t))
		sg.append(_u(r, 0.82 - 0.32 * t, 0.2 + 0.3 * t))
	_rs(sg, sub(r, 0.64, 0.64, 0.88, 0.72))
	S(ci, sg, 0.55, 1.1)
	for x in [0.3, 0.7]:
		O(ci, _u(r, x, 0.86), ms * 0.18, 0.55, 1.2)
		D(ci, _u(r, x, 0.86), maxf(1.4, ms * 0.04), 0.6)
	E.Rc(ci, sub(r, 0.66, 0.655, 0.86, 0.705), Pal.tint(Pal.FLUID, 0.75), 1.0)
	_gband(ci, r, 0.3, 0.7, 0.4, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- FL-116: decontamination line (env art)
# the decontamination line: two booths in a row (the airlock and the shower), their sealed doors and
# window ports, the spray rings in the shower and the air knife in the airlock, the grated floors over
# the sump, the effluent line out
static func decon_line(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.04), _u(r, 0.5, 0.86), _u(r, 0.04, 0.86), _u(r, 0.96, 0.86), _u(r, 0.04, 0.9), _u(r, 0.96, 0.9),
		_u(r, 0.1, 0.14), _u(r, 0.44, 0.14), _u(r, 0.56, 0.14), _u(r, 0.9, 0.14), _u(r, 0.56, 0.5), _u(r, 0.9, 0.5),
		_u(r, 0.46, 0.94), _u(r, 1.0, 0.94), _u(r, 0.46, 0.9), _u(r, 0.46, 0.94)]))
	for k in 6:
		var x: float = 0.1 + k * 0.06
		sg.append(_u(r, x, 0.86))
		sg.append(_u(r, x, 0.9))
		sg.append(_u(r, x + 0.46, 0.86))
		sg.append(_u(r, x + 0.46, 0.9))
	_rs(sg, sub(r, 0.0, 0.3, 0.04, 0.8))
	_rs(sg, sub(r, 0.48, 0.3, 0.52, 0.8))
	_rs(sg, sub(r, 0.96, 0.3, 1.0, 0.8))
	S(ci, sg, 0.55, 1.2)
	var sp := PackedVector2Array()
	for k in 5:
		var x: float = 0.6 + k * 0.07
		sp.append_array(PackedVector2Array([_u(r, x, 0.14), _u(r, x - 0.02, 0.4), _u(r, x, 0.5), _u(r, x + 0.02, 0.76)]))
		sp.append(_u(r, 0.12 + k * 0.07, 0.16))
		sp.append(_u(r, 0.14 + k * 0.07, 0.3))
	S(ci, sp, 0.26, 1.0)
	_gband(ci, r, 0.56, 0.9, 0.12, Pal.tint(Pal.FLUID, 0.8))
	_gband(ci, r, 0.1, 0.44, 0.12, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- DR-150 / HG-170: fume hood
# the lab's fume hood: the hood and its exhaust collar up to the duct, the sliding sash (its glass and
# handle) over the work surface, the baffle slots at the back, the airflow monitor's lamp, the base
# cabinet's two doors
static func fume_hood(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.08, 0.96, 0.6))
	_rs(sg, sub(r, 0.36, 0.0, 0.64, 0.08))
	_rs(sg, sub(r, 0.1, 0.18, 0.9, 0.42))
	sg.append_array(PackedVector2Array([_u(r, 0.04, 0.6), _u(r, 0.04, 0.98), _u(r, 0.96, 0.6), _u(r, 0.96, 0.98), _u(r, 0.04, 0.98), _u(r, 0.96, 0.98),
		_u(r, 0.5, 0.64), _u(r, 0.5, 0.98), _u(r, 0.4, 0.78), _u(r, 0.4, 0.84), _u(r, 0.6, 0.78), _u(r, 0.6, 0.84),
		_u(r, 0.36, 0.42), _u(r, 0.64, 0.42), _u(r, 0.04, 0.62), _u(r, 0.96, 0.62)]))
	for k in 3:
		var y: float = 0.48 + k * 0.035
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.88, y))
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.14, 0.2), _u(r, 0.3, 0.4), _u(r, 0.22, 0.2), _u(r, 0.38, 0.4)]), 0.25, 1.0)
	_lamp(ci, _u(r, 0.86, 0.12), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- 6 ships: air-cycle environmental control pack
# the environmental control pack: the air cycle machine (its compressor and turbine wheels on one
# shaft, the fan), the primary and secondary heat exchangers, the water separator, the bleed air in
# through its valve, the conditioned air out
static func ecs_pack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.04, 0.98, 0.96))
	_coilq(sg, sub(r, 0.06, 0.1, 0.3, 0.46), 6)
	_coilq(sg, sub(r, 0.06, 0.54, 0.3, 0.9), 6)
	_vves(sg, sub(r, 0.78, 0.5, 0.92, 0.9), r.size.x * 0.02, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.4, 0.5), _u(r, 0.7, 0.5), _u(r, 0.3, 0.28), _u(r, 0.4, 0.36), _u(r, 0.3, 0.72), _u(r, 0.4, 0.64),
		_u(r, 0.7, 0.56), _u(r, 0.78, 0.7), _u(r, 0.85, 0.5), _u(r, 0.85, 0.3), _u(r, 0.85, 0.3), _u(r, 1.0, 0.3),
		_u(r, 0.0, 0.18), _u(r, 0.06, 0.18), _u(r, 0.02, 0.14), _u(r, 0.04, 0.22)]))
	S(ci, sg, 0.55, 1.1)
	var w := PackedVector2Array()
	for x in [0.45, 0.55, 0.65]:
		var c := _u(r, x, 0.5)
		var rad: float = ms * (0.12 if x != 0.55 else 0.16)
		_arcs(w, c, rad * 0.5, rad, 0.0, TAU, 6)
		w.append(c + Vector2(0, -rad * 0.8))
		w.append(c + Vector2(0, rad * 0.8))
	S(ci, w, 0.5, 1.1)
	_gband(ci, r, 0.07, 0.29, 0.14, Pal.heat(0.75))
	_gband(ci, r, 0.86, 0.99, 0.26, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- HB-86: main environmental plant (8 x 9 m)
# the habitat's main environmental plant room: the big air handler along the top (its damper, filter
# bank, coil, two fans), the steam humidifier under it with its steam lance, the oxygen injection rack
# (a bank of bottles, its header and dosing valve), the dehumidifier, the control panel, the ducts
static func ecs_plantroom(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.04, 0.98, 0.4))
	for x in [0.12, 0.26, 0.42, 0.72]:
		sg.append(_u(r, x, 0.04))
		sg.append(_u(r, x, 0.4))
	for k in 4:
		var y: float = 0.1 + k * 0.08
		sg.append(_u(r, 0.04, y))
		sg.append(_u(r, 0.1, y + 0.04))
	_pleat(sg, sub(r, 0.14, 0.08, 0.24, 0.36), 6, true)
	_coilq(sg, sub(r, 0.28, 0.08, 0.4, 0.36), 6)
	_rs(sg, sub(r, 0.04, 0.48, 0.3, 0.8))
	sg.append_array(PackedVector2Array([_u(r, 0.17, 0.48), _u(r, 0.17, 0.4), _u(r, 0.1, 0.44), _u(r, 0.24, 0.44)]))
	for k in 5:
		var x0: float = 0.36 + k * 0.06
		_vbot(sg, sub(r, x0, 0.56, x0 + 0.045, 0.94))
		sg.append(_u(r, x0 + 0.022, 0.56))
		sg.append(_u(r, x0 + 0.022, 0.5))
	sg.append_array(PackedVector2Array([_u(r, 0.38, 0.5), _u(r, 0.62, 0.5), _u(r, 0.62, 0.5), _u(r, 0.62, 0.4)]))
	_rs(sg, sub(r, 0.7, 0.5, 0.86, 0.94))
	_coilq(sg, sub(r, 0.72, 0.54, 0.84, 0.66), 4)
	_rs(sg, sub(r, 0.88, 0.5, 0.97, 0.76))
	sg.append_array(PackedVector2Array([_u(r, 0.98, 0.18), _u(r, 1.0, 0.18), _u(r, 0.98, 0.28), _u(r, 1.0, 0.28), _u(r, 0.02, 0.98), _u(r, 0.98, 0.98)]))
	S(ci, sg, 0.55, 1.2)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.52, 0.22), ms * 0.12)
	_fanw(fw, _u(r, 0.85, 0.22), ms * 0.12)
	S(ci, fw, 0.5, 1.1)
	for k in 5:
		_gband(ci, r, 0.36 + k * 0.06, 0.405 + k * 0.06, 0.66, Pal.tint(Pal.AIR, 0.8))
	_gband(ci, r, 0.05, 0.29, 0.62, Pal.heat(0.6))
	_lamp(ci, _u(r, 0.925, 0.58), maxf(2.0, ms * 0.02), Pal.tint(Pal.FLUID, 0.85))


# ---------------------------------------------------------------- 6 small ships: compact environmental unit
# a small craft's compact environmental unit: the box, the fan grille (its ring and spokes), the small
# coil beside it, the filter slot, the control knob, the duct stubs in and out
static func compact_ecu(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.08, 0.94, 0.92))
	_coilq(sg, sub(r, 0.6, 0.18, 0.86, 0.58), 4)
	_rs(sg, sub(r, 0.12, 0.8, 0.56, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 0.06, 0.3), _u(r, 0.0, 0.5), _u(r, 0.06, 0.5), _u(r, 0.94, 0.7), _u(r, 1.0, 0.7), _u(r, 0.94, 0.86), _u(r, 1.0, 0.86)]))
	var c := _u(r, 0.32, 0.44)
	for k in 6:
		var a: float = TAU * k / 6.0
		sg.append(c + Vector2.from_angle(a) * ms * 0.04)
		sg.append(c + Vector2.from_angle(a) * ms * 0.24)
	S(ci, sg, 0.55, 1.0)
	O(ci, c, ms * 0.26, 0.55)
	D(ci, _u(r, 0.73, 0.75), maxf(1.4, ms * 0.05), 0.6)
	_gband(ci, r, 0.61, 0.85, 0.66, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- 19 pieces: environmental control unit
# the environmental control unit on the wall: the louvred intake, the filter and the fan section over
# the sensor bay (the oxygen, CO2 and humidity probes), the control panel and its display, the outlet
static func env_controller(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.48), _u(r, 0.94, 0.48), _u(r, 0.06, 0.72), _u(r, 0.94, 0.72)]))
	for k in 4:
		var y: float = 0.05 + k * 0.035
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.88, y + 0.02))
	_pleat(sg, sub(r, 0.12, 0.2, 0.36, 0.44), 4, true)
	for k in 3:
		var x0: float = 0.14 + k * 0.26
		_rs(sg, sub(r, x0, 0.54, x0 + 0.16, 0.66))
		sg.append(_u(r, x0 + 0.08, 0.66))
		sg.append(_u(r, x0 + 0.08, 0.7))
	_rs(sg, sub(r, 0.14, 0.78, 0.6, 0.92))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.64, 0.32), ms * 0.14)
	S(ci, fw, 0.5, 1.1)
	E.Rc(ci, sub(r, 0.16, 0.8, 0.58, 0.9), Pal.tint(Pal.FLUID, 0.7), 1.0)
	for k in 3:
		_lamp(ci, _u(r, 0.68 + k * 0.08, 0.85), maxf(1.4, ms * 0.04), [Pal.tint(Pal.AIR, 0.85), Pal.tint(Pal.VOLT, 0.85), Pal.tint(Pal.FLUID, 0.85)][k])


# ---------------------------------------------------------------- CL-104: emergency anti-freeze heater (env art)
# the hold's emergency anti-freeze heater: the casing, the bank of finned heating elements (their
# glow), the fan blowing through them, the thermostat and its sensing bulb, the outlet louvres
static func freeze_heater(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.06, 0.96, 0.94))
	for k in 5:
		var x: float = 0.12 + k * 0.08
		sg.append_array(PackedVector2Array([_u(r, x, 0.14), _u(r, x, 0.86), _u(r, x - 0.02, 0.3), _u(r, x + 0.02, 0.3), _u(r, x - 0.02, 0.5), _u(r, x + 0.02, 0.5), _u(r, x - 0.02, 0.7), _u(r, x + 0.02, 0.7)]))
	for k in 4:
		var y: float = 0.2 + k * 0.18
		sg.append(_u(r, 0.86, y))
		sg.append(_u(r, 0.94, y + 0.08))
	_rs(sg, sub(r, 0.56, 0.7, 0.72, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.64, 0.86), _u(r, 0.64, 0.94), _u(r, 0.64, 0.94), _u(r, 0.36, 1.0)]))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.68, 0.38), ms * 0.22)
	S(ci, fw, 0.5, 1.1)
	for k in 5:
		_gband(ci, r, 0.105 + k * 0.08, 0.135 + k * 0.08, 0.6, Pal.heat(0.8))


# ---------------------------------------------------------------- CH-110 / CV-138 / PS-12: packaged air conditioning loop
# the packaged air conditioning loop: the condenser coil and its fan (ring, blades) on one side, the
# scroll compressor (its dome) and the receiver, the expansion valve, the evaporator coil and its
# blower on the other, the refrigerant lines between (hot and cold)
static func hvac_package(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.04, 0.98, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.04), _u(r, 0.5, 0.96)]))
	_coilq(sg, sub(r, 0.06, 0.1, 0.2, 0.9), 5, false)
	_vves(sg, sub(r, 0.3, 0.56, 0.42, 0.9), r.size.x * 0.02, 3)
	_rs(sg, sub(r, 0.44, 0.7, 0.48, 0.9))
	_coilq(sg, sub(r, 0.8, 0.1, 0.94, 0.9), 5, false)
	sg.append_array(PackedVector2Array([_u(r, 0.36, 0.56), _u(r, 0.36, 0.2), _u(r, 0.36, 0.2), _u(r, 0.2, 0.2), _u(r, 0.2, 0.8), _u(r, 0.46, 0.8),
		_u(r, 0.46, 0.7), _u(r, 0.46, 0.14), _u(r, 0.46, 0.14), _u(r, 0.8, 0.14), _u(r, 0.8, 0.86), _u(r, 0.42, 0.86), _u(r, 0.6, 0.12), _u(r, 0.6, 0.16)]))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.32, 0.36), ms * 0.18, 0.55, 1.2)
	D(ci, _u(r, 0.32, 0.36), maxf(1.4, ms * 0.04), 0.6)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.66, 0.5), ms * 0.2)
	S(ci, fw, 0.5, 1.1)
	_gband(ci, r, 0.21, 0.35, 0.2, Pal.heat(0.75))
	_gband(ci, r, 0.62, 0.79, 0.86, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- ARK-01 and 4 ships: life support master unit
# the life support master unit, a rack of four modules: the oxygen generator (its cell stack), the
# CO2 removal bed, the trace contaminant control (the catalytic oxidiser and its heater), the
# humidity control (its condensing coil and the water out), the master panel's lamps across the top
static func life_support_master(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.02, 0.98, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.14), _u(r, 0.98, 0.14), _u(r, 0.02, 0.56), _u(r, 0.98, 0.56), _u(r, 0.5, 0.14), _u(r, 0.5, 0.98)]))
	_rs(sg, sub(r, 0.08, 0.2, 0.44, 0.5))
	for k in range(1, 6):
		var x: float = 0.08 + k * 0.06
		sg.append(_u(r, x, 0.2))
		sg.append(_u(r, x, 0.5))
	_vves(sg, sub(r, 0.6, 0.2, 0.88, 0.5), r.size.x * 0.04, 3)
	for y in [0.3, 0.4]:
		sg.append(_u(r, 0.6, y))
		sg.append(_u(r, 0.88, y))
	_rs(sg, sub(r, 0.12, 0.62, 0.38, 0.92))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.72), _u(r, 0.38, 0.72), _u(r, 0.12, 0.82), _u(r, 0.38, 0.82)]))
	_coilq(sg, sub(r, 0.58, 0.62, 0.9, 0.82), 6)
	sg.append_array(PackedVector2Array([_u(r, 0.74, 0.82), _u(r, 0.74, 0.94), _u(r, 0.7, 0.94), _u(r, 0.78, 0.94)]))
	S(ci, sg, 0.55, 1.1)
	for k in 6:
		_lamp(ci, _u(r, 0.12 + k * 0.15, 0.08), maxf(1.4, ms * 0.03), Pal.tint(Pal.FLUID, 0.85) if k != 3 else Pal.heat(0.85))
	_gband(ci, r, 0.13, 0.37, 0.77, Pal.heat(0.75))
	_gband(ci, r, 0.61, 0.87, 0.26, Pal.tint(Pal.VOLT, 0.6))
	_gband(ci, r, 0.09, 0.43, 0.24, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- OB-90: clean air supply unit
# the observatory's clean air supply: the louvred intake at the foot, the prefilter, the centrifugal
# blower in the middle, the ULPA filter plenum on top and the clean duct up out of it, the pressure
# gauge across the filter
static func clean_air_supply(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.06, 0.92, 0.98))
	_rs(sg, sub(r, 0.3, 0.0, 0.7, 0.06))
	_pleat(sg, sub(r, 0.12, 0.08, 0.88, 0.26), 7, false)
	_pleat(sg, sub(r, 0.12, 0.74, 0.88, 0.8), 7, false)
	for k in 3:
		var y: float = 0.84 + k * 0.045
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.88, y + 0.02))
	S(ci, sg, 0.55, 1.1)
	var fw := PackedVector2Array()
	_fanw(fw, _u(r, 0.48, 0.5), ms * 0.26)
	S(ci, fw, 0.5, 1.1)
	O(ci, _u(r, 0.84, 0.32), ms * 0.06, 0.55)
	_gband(ci, r, 0.13, 0.87, 0.04, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- MED-47 (x12): pod air circulator
# a care pod's air circulator: the slim casing, the tangential fan's long rotor (its blades), the
# filter strip in front of it, the angled outlet louvres, the intake grille
static func pod_circulator(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.06, 0.98, 0.94))
	_rs(sg, sub(r, 0.24, 0.3, 0.74, 0.7))
	for k in 6:
		var x: float = 0.27 + k * 0.08
		sg.append(_u(r, x, 0.3))
		sg.append(_u(r, x + 0.04, 0.7))
	for k in 3:
		var x: float = 0.8 + k * 0.05
		sg.append(_u(r, x, 0.14))
		sg.append(_u(r, x + 0.03, 0.86))
	for k in 3:
		var y: float = 0.24 + k * 0.24
		sg.append(_u(r, 0.04, y))
		sg.append(_u(r, 0.16, y))
	sg.append_array(PackedVector2Array([_u(r, 0.19, 0.12), _u(r, 0.19, 0.88)]))
	S(ci, sg, 0.55, 1.0)
	_gband(ci, r, 0.25, 0.73, 0.5, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- ARK-01: cold room condensing unit (freezer art)
# the cold room's condensing unit: the scroll compressor (its dome) and the liquid receiver lying
# under the condenser coil and its fan (ring, blades), the suction and liquid lines out to the cold
# room (cold and warm), the controller's lamp
static func condensing_unit(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.04, 0.98, 0.96))
	_coilq(sg, sub(r, 0.5, 0.08, 0.94, 0.92), 7)
	_vves(sg, sub(r, 0.08, 0.38, 0.26, 0.9), r.size.x * 0.03, 3)
	_hves(sg, sub(r, 0.28, 0.72, 0.46, 0.88), r.size.y * 0.03, 3)
	sg.append_array(PackedVector2Array([_u(r, 0.17, 0.38), _u(r, 0.17, 0.2), _u(r, 0.17, 0.2), _u(r, 0.5, 0.2), _u(r, 0.46, 0.8), _u(r, 0.5, 0.8),
		_u(r, 0.0, 0.24), _u(r, 0.06, 0.24), _u(r, 0.0, 0.34), _u(r, 0.06, 0.34)]))
	_rs(sg, sub(r, 0.3, 0.42, 0.44, 0.6))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.72, 0.5), ms * 0.36, 0.55, 1.2)
	var bl := PackedVector2Array()
	for k in 5:
		var a: float = TAU * k / 5.0
		bl.append(_u(r, 0.72, 0.5) + Vector2.from_angle(a) * ms * 0.05)
		bl.append(_u(r, 0.72, 0.5) + Vector2.from_angle(a + 0.6) * ms * 0.32)
	S(ci, bl, 0.45, 1.1)
	_lamp(ci, _u(r, 0.37, 0.51), maxf(1.4, ms * 0.05), Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.0, 0.06, 0.24, Pal.tint(Pal.AIR, 0.85))
	_gband(ci, r, 0.0, 0.06, 0.34, Pal.heat(0.8))


# ---------------------------------------------------------------- ARK-01: upright freezer (freezer art)
# the galley's upright freezer: the cabinet, its door (the gasket line, the long handle, the hinges),
# the control panel strip on top with its display, the kick plate's grille, the frost's colour
static func upright_freezer(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	_rs(sg, sub(r, 0.1, 0.12, 0.9, 0.86))
	_rs(sg, sub(r, 0.14, 0.15, 0.86, 0.83))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.12), _u(r, 0.94, 0.12), _u(r, 0.78, 0.3), _u(r, 0.78, 0.66), _u(r, 0.06, 0.2), _u(r, 0.1, 0.2), _u(r, 0.06, 0.76), _u(r, 0.1, 0.76)]))
	for k in 5:
		var x: float = 0.18 + k * 0.14
		sg.append(_u(r, x, 0.9))
		sg.append(_u(r, x + 0.06, 0.95))
	S(ci, sg, 0.55, 1.1)
	E.Rc(ci, sub(r, 0.56, 0.04, 0.86, 0.09), Pal.tint(Pal.AIR, 0.8), 1.0)
	_gband(ci, r, 0.15, 0.85, 0.17, Pal.tint(Pal.AIR, 0.6))


# ---------------------------------------------------------------- EV-55: two-door fridge (fridge art)
# a two-door fridge: the freezer door over the fridge door (their handles, the gasket lines), the
# hinges, the ventilation grille at the foot
static func two_door_fridge(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.02, 0.92, 0.98))
	_rs(sg, sub(r, 0.12, 0.05, 0.88, 0.33))
	_rs(sg, sub(r, 0.12, 0.36, 0.88, 0.88))
	sg.append_array(PackedVector2Array([_u(r, 0.8, 0.12), _u(r, 0.8, 0.26), _u(r, 0.8, 0.42), _u(r, 0.8, 0.62), _u(r, 0.08, 0.08), _u(r, 0.12, 0.08), _u(r, 0.08, 0.84), _u(r, 0.12, 0.84)]))
	for k in 4:
		var x: float = 0.2 + k * 0.16
		sg.append(_u(r, x, 0.91))
		sg.append(_u(r, x + 0.1, 0.91))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.13, 0.87, 0.07, Pal.tint(Pal.AIR, 0.6))


# ---------------------------------------------------------------- BL-88 / HG-170: glass-door lab fridge
# a glass-door laboratory fridge: the cabinet, the glazed door (its frame), the shelves and the sample
# bottles on them seen through the glass, the lock, the temperature display, the grille at the foot
static func lab_fridge(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	_rs(sg, sub(r, 0.12, 0.12, 0.88, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.1), _u(r, 0.94, 0.1), _u(r, 0.06, 0.9), _u(r, 0.94, 0.9), _u(r, 0.82, 0.44), _u(r, 0.82, 0.56)]))
	for k in 3:
		var y: float = 0.32 + k * 0.18
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.88, y))
		for j in 3:
			var x: float = 0.2 + j * 0.2 + (k % 2) * 0.08
			sg.append_array(PackedVector2Array([_u(r, x, y), _u(r, x, y - 0.1), _u(r, x + 0.06, y), _u(r, x + 0.06, y - 0.1), _u(r, x, y - 0.1), _u(r, x + 0.06, y - 0.1)]))
	S(ci, sg, 0.5, 1.0)
	E.Rc(ci, sub(r, 0.6, 0.03, 0.86, 0.08), Pal.tint(Pal.FLUID, 0.8), 1.0)
	_gband(ci, r, 0.13, 0.87, 0.94, Pal.tint(Pal.AIR, 0.6))


# ---------------------------------------------------------------- MED-47 (x3): ultra-low freezer
# the clinic's ultra-low freezer: the heavy cabinet and its thick door with the lever latch, the inner
# doors' outline behind it, the control panel and its display, the compressor compartment's grille at
# the foot, the CO2 backup bottle strapped to its side
static func ult_freezer(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.02, 0.78, 0.98))
	_rs(sg, sub(r, 0.08, 0.14, 0.74, 0.78))
	_rs(sg, sub(r, 0.08, 0.04, 0.74, 0.12))
	sg.append_array(PackedVector2Array([_u(r, 0.08, 0.35), _u(r, 0.74, 0.35), _u(r, 0.08, 0.56), _u(r, 0.74, 0.56), _u(r, 0.68, 0.4), _u(r, 0.68, 0.6), _u(r, 0.68, 0.5), _u(r, 0.6, 0.5),
		_u(r, 0.04, 0.82), _u(r, 0.78, 0.82)]))
	for k in 6:
		var x: float = 0.1 + k * 0.1
		sg.append(_u(r, x, 0.86))
		sg.append(_u(r, x, 0.95))
	_vbot(sg, sub(r, 0.82, 0.3, 0.94, 0.94))
	sg.append_array(PackedVector2Array([_u(r, 0.78, 0.5), _u(r, 0.96, 0.5), _u(r, 0.78, 0.8), _u(r, 0.96, 0.8), _u(r, 0.88, 0.3), _u(r, 0.88, 0.2), _u(r, 0.88, 0.2), _u(r, 0.78, 0.2)]))
	S(ci, sg, 0.55, 1.1)
	E.Rc(ci, sub(r, 0.12, 0.06, 0.4, 0.1), Pal.tint(Pal.AIR, 0.85), 1.0)
	_lamp(ci, _u(r, 0.66, 0.08), maxf(1.4, ms * 0.03), Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.83, 0.93, 0.42, Pal.tint(Pal.VOLT, 0.75))


# ---------------------------------------------------------------- QC-30: water chiller
# the quantum lab's water chiller: the cabinet, the condenser fan on its top (ring, blades), the
# compressor (its dome) and the brazed plate exchanger inside, the circulating pump, the supply and
# return stubs (cold and warm)
static func lab_chiller(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.04, 0.94, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.4), _u(r, 0.94, 0.4), _u(r, 0.94, 0.6), _u(r, 1.0, 0.6), _u(r, 0.94, 0.72), _u(r, 1.0, 0.72)]))
	_vves(sg, sub(r, 0.12, 0.48, 0.36, 0.9), r.size.x * 0.05, 3)
	_rs(sg, sub(r, 0.44, 0.48, 0.62, 0.9))
	for k in 4:
		var x: float = 0.46 + k * 0.04
		sg.append(_u(r, x, 0.5))
		sg.append(_u(r, x, 0.88))
	_rs(sg, sub(r, 0.7, 0.66, 0.9, 0.9))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.5, 0.22), ms * 0.28, 0.55, 1.2)
	var bl := PackedVector2Array()
	for k in 5:
		var a: float = TAU * k / 5.0
		bl.append(_u(r, 0.5, 0.22) + Vector2.from_angle(a) * ms * 0.04)
		bl.append(_u(r, 0.5, 0.22) + Vector2.from_angle(a + 0.6) * ms * 0.25)
	S(ci, bl, 0.45, 1.1)
	_gband(ci, r, 0.94, 1.0, 0.57, Pal.tint(Pal.AIR, 0.85))
	_gband(ci, r, 0.94, 1.0, 0.69, Pal.heat(0.8))


# ---------------------------------------------------------------- SV-122: sample storage freezer
# the survey ship's sample store: the tall cabinet, the glazed door, the grid of sample drawer racks
# behind it, the temperature chart recorder (its round chart and pen), the alarm lamp
static func sample_store(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.02, 0.96, 0.98))
	_rs(sg, sub(r, 0.08, 0.22, 0.92, 0.94))
	for k in range(1, 4):
		var x: float = 0.08 + k * 0.21
		sg.append(_u(r, x, 0.22))
		sg.append(_u(r, x, 0.94))
	for k in range(1, 8):
		var y: float = 0.22 + k * 0.09
		sg.append(_u(r, 0.08, y))
		sg.append(_u(r, 0.92, y))
	S(ci, sg, 0.45, 1.0)
	O(ci, _u(r, 0.3, 0.12), ms * 0.14, 0.55, 1.1)
	L(ci, _u(r, 0.3, 0.12), _u(r, 0.38, 0.08), 0.6)
	_lamp(ci, _u(r, 0.76, 0.12), maxf(1.6, ms * 0.04), Pal.heat(0.85))
	_gband(ci, r, 0.09, 0.91, 0.24, Pal.tint(Pal.AIR, 0.6))


# ---------------------------------------------------------------- CL-104 (x6): vaccine carrier
# a vaccine cold box (or two side by side where wide): the insulated box, its lid and the two latches,
# the carry handles, the data logger's display on its face, the cold's colour on the lid seal
static func vaccine_carrier(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var n := 2 if r.size.x > r.size.y * 1.8 else 1
	var bw: float = 1.0 / n
	var sg := PackedVector2Array()
	for k in n:
		var x0: float = k * bw
		_rs(sg, sub(r, x0 + bw * 0.06, 0.3, x0 + bw * 0.94, 0.96))
		_rs(sg, sub(r, x0 + bw * 0.04, 0.18, x0 + bw * 0.96, 0.3))
		sg.append_array(PackedVector2Array([_u(r, x0 + bw * 0.3, 0.18), _u(r, x0 + bw * 0.34, 0.06), _u(r, x0 + bw * 0.34, 0.06), _u(r, x0 + bw * 0.66, 0.06), _u(r, x0 + bw * 0.66, 0.06), _u(r, x0 + bw * 0.7, 0.18),
			_u(r, x0 + bw * 0.14, 0.26), _u(r, x0 + bw * 0.14, 0.4), _u(r, x0 + bw * 0.86, 0.26), _u(r, x0 + bw * 0.86, 0.4),
			_u(r, x0 + bw * 0.06, 0.88), _u(r, x0 + bw * 0.94, 0.88)]))
		_rs(sg, sub(r, x0 + bw * 0.3, 0.5, x0 + bw * 0.7, 0.68))
	S(ci, sg, 0.55, 1.1)
	for k in n:
		E.Rc(ci, sub(r, k * bw + bw * 0.34, 0.54, k * bw + bw * 0.66, 0.64), Pal.tint(Pal.FLUID, 0.75), 1.0)
		_gband(ci, r, k * bw + bw * 0.06, k * bw + bw * 0.94, 0.3, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- ARK-01 (x25): oxygen outlet station
# an ARK oxygen station on the wall: the cabinet, its glazed door's frame and handle, the oxygen outlet
# panel inside (the flowmeter's tube and float, the outlet socket, the ready lamp on its label strip),
# the supply hose coiled on its hook, the two masks hung beside it on their elastic straps
static func o2_outlet_station(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.04, 0.94, 0.96))
	_rs(sg, sub(r, 0.14, 0.1, 0.42, 0.5))
	_rs(sg, sub(r, 0.24, 0.14, 0.32, 0.4))
	sg.append_array(PackedVector2Array([_u(r, 0.28, 0.4), _u(r, 0.28, 0.5), _u(r, 0.28, 0.5), _u(r, 0.5, 0.62), _u(r, 0.5, 0.62), _u(r, 0.5, 0.88),
		_u(r, 0.62, 0.16), _u(r, 0.62, 0.34), _u(r, 0.8, 0.16), _u(r, 0.8, 0.34), _u(r, 0.56, 0.34), _u(r, 0.68, 0.34), _u(r, 0.74, 0.34), _u(r, 0.86, 0.34),
		_u(r, 0.56, 0.34), _u(r, 0.6, 0.44), _u(r, 0.68, 0.34), _u(r, 0.64, 0.44), _u(r, 0.6, 0.44), _u(r, 0.64, 0.44),
		_u(r, 0.74, 0.34), _u(r, 0.78, 0.44), _u(r, 0.86, 0.34), _u(r, 0.82, 0.44), _u(r, 0.78, 0.44), _u(r, 0.82, 0.44)]))
	_rs(sg, sub(r, 0.1, 0.07, 0.9, 0.93))
	sg.append_array(PackedVector2Array([_u(r, 0.86, 0.46), _u(r, 0.86, 0.58), _u(r, 0.6, 0.44), _u(r, 0.6, 0.5), _u(r, 0.6, 0.5), _u(r, 0.66, 0.54),
		_u(r, 0.82, 0.44), _u(r, 0.82, 0.5), _u(r, 0.82, 0.5), _u(r, 0.76, 0.54), _u(r, 0.14, 0.56), _u(r, 0.42, 0.56), _u(r, 0.14, 0.62), _u(r, 0.42, 0.62)]))
	S(ci, sg, 0.55, 1.0)
	O(ci, _u(r, 0.5, 0.76), ms * 0.14, 0.5, 1.4)
	O(ci, _u(r, 0.5, 0.78), ms * 0.1, 0.45, 1.4)
	D(ci, _u(r, 0.28, 0.24), maxf(1.0, ms * 0.04), 0.65)
	_lamp(ci, _u(r, 0.36, 0.59), maxf(1.2, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.15, 0.41, 0.46, Pal.tint(Pal.AIR, 0.85))


# ---------------------------------------------------------------- 17 pieces: emergency oxygen cabinet
# an emergency oxygen cabinet: the box and its break-glass front, the portable oxygen bottle standing
# inside with its regulator and gauge, the mask on its tube hung beside it, the pull handle
static func emergency_o2_box(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.04, 0.94, 0.96))
	_rs(sg, sub(r, 0.1, 0.08, 0.9, 0.84))
	_vbot(sg, sub(r, 0.16, 0.2, 0.42, 0.82))
	_rs(sg, sub(r, 0.24, 0.14, 0.4, 0.2))
	sg.append_array(PackedVector2Array([_u(r, 0.4, 0.17), _u(r, 0.6, 0.24), _u(r, 0.6, 0.24), _u(r, 0.66, 0.5), _u(r, 0.6, 0.5), _u(r, 0.76, 0.5),
		_u(r, 0.6, 0.5), _u(r, 0.64, 0.6), _u(r, 0.76, 0.5), _u(r, 0.72, 0.6), _u(r, 0.64, 0.6), _u(r, 0.72, 0.6),
		_u(r, 0.36, 0.88), _u(r, 0.64, 0.88), _u(r, 0.12, 0.1), _u(r, 0.3, 0.3)]))
	S(ci, sg, 0.55, 1.0)
	D(ci, _u(r, 0.36, 0.17), maxf(1.0, ms * 0.04), 0.65)
	_gband(ci, r, 0.17, 0.41, 0.36, Pal.tint(Pal.AIR, 0.85))
	_gband(ci, r, 0.36, 0.64, 0.9, Pal.heat(0.85))


# ================================================================ E435–E581 (2026-11-13): tenth batch, part three
# the lockers (each by what it keeps), the seats (by who sits there), the berths and beds, the shelves
# and racks (by what they hold), the planting (by how it grows), the medical machines, the galleys,
# and the rest (a separator, the shakers, a standpipe, a turboexpander, a composter, an escape pod)

# ---------------------------------------------------------------- FL-116 / IC-120: three-phase separator
# the three-phase separator: the vessel (lying, or standing where tall), the inlet diverter, the weir
# plate and the oil bucket inside, the gas out of the top through its mist pad, the oil and water
# outlets and their level bridles, the relief valve, the saddles; oil over water
static func three_phase_sep(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	if r.size.x >= r.size.y:
		var q := sub(r, 0.03, 0.14, 0.97, 0.82)
		_hves(sg, q, q.size.y * 0.4, 4)
		sg.append_array(PackedVector2Array([_u(r, 0.14, 0.24), _u(r, 0.14, 0.6), _u(r, 0.66, 0.42), _u(r, 0.66, 0.82), _u(r, 0.74, 0.5), _u(r, 0.74, 0.82),
			_u(r, 0.66, 0.42), _u(r, 0.74, 0.42), _u(r, 0.86, 0.14), _u(r, 0.86, 0.02), _u(r, 0.82, 0.24), _u(r, 0.9, 0.24),
			_u(r, 0.5, 0.82), _u(r, 0.5, 0.96), _u(r, 0.7, 0.82), _u(r, 0.7, 0.96), _u(r, 0.06, 0.4), _u(r, 0.0, 0.4),
			_u(r, 0.3, 0.14), _u(r, 0.3, 0.04), _u(r, 0.26, 0.04), _u(r, 0.34, 0.04),
			_u(r, 0.2, 0.8), _u(r, 0.16, 0.98), _u(r, 0.26, 0.8), _u(r, 0.3, 0.98), _u(r, 0.8, 0.8), _u(r, 0.76, 0.98), _u(r, 0.86, 0.8), _u(r, 0.9, 0.98)]))
		_rs(sg, sub(r, 0.8, 0.18, 0.92, 0.3))
		S(ci, sg, 0.55, 1.2)
		_gband(ci, r, 0.05, 0.66, 0.5, Pal.heat(0.6))
		_gband(ci, r, 0.05, 0.66, 0.66, Pal.tint(Pal.FLUID, 0.7))
	else:
		var q := sub(r, 0.16, 0.06, 0.84, 0.86)
		_vves(sg, q, q.size.x * 0.3, 4)
		_rs(sg, sub(r, 0.24, 0.16, 0.76, 0.24))
		sg.append_array(PackedVector2Array([_u(r, 0.16, 0.42), _u(r, 0.0, 0.42), _u(r, 0.5, 0.06), _u(r, 0.5, 0.0), _u(r, 0.84, 0.6), _u(r, 1.0, 0.6),
			_u(r, 0.5, 0.86), _u(r, 0.5, 0.98), _u(r, 0.24, 0.84), _u(r, 0.18, 1.0), _u(r, 0.76, 0.84), _u(r, 0.82, 1.0)]))
		S(ci, sg, 0.55, 1.2)
		_gband(ci, r, 0.17, 0.83, 0.56, Pal.heat(0.6))
		_gband(ci, r, 0.17, 0.83, 0.72, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- DR-150: shale shaker
# the shale shaker: the possum belly feeding the mud in at the back, the inclined basket and its screen
# panels, the two vibrator motors on top of the basket, the coil springs it rides on, the underflow
# sump below it, the cuttings chute off the front
static func shale_shaker(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.16, 0.18, 0.44))
	sg.append_array(PackedVector2Array([_u(r, 0.18, 0.46), _u(r, 0.86, 0.3), _u(r, 0.18, 0.58), _u(r, 0.86, 0.42), _u(r, 0.18, 0.46), _u(r, 0.18, 0.58), _u(r, 0.86, 0.3), _u(r, 0.86, 0.42),
		_u(r, 0.86, 0.36), _u(r, 0.98, 0.56), _u(r, 0.86, 0.42), _u(r, 0.96, 0.6),
		_u(r, 0.14, 0.74), _u(r, 0.86, 0.74), _u(r, 0.14, 0.74), _u(r, 0.22, 0.96), _u(r, 0.86, 0.74), _u(r, 0.78, 0.96), _u(r, 0.22, 0.96), _u(r, 0.78, 0.96)]))
	for k in range(1, 4):
		var t: float = k / 4.0
		sg.append(_u(r, lerpf(0.18, 0.86, t), lerpf(0.46, 0.3, t)))
		sg.append(_u(r, lerpf(0.18, 0.86, t), lerpf(0.58, 0.42, t)))
	for x in [0.26, 0.78]:
		var y: float = lerpf(0.58, 0.42, (x - 0.18) / 0.68)
		sg.append_array(PackedVector2Array([_u(r, x - 0.03, y), _u(r, x + 0.03, y + 0.04), _u(r, x + 0.03, y + 0.04), _u(r, x - 0.03, y + 0.08),
			_u(r, x - 0.03, y + 0.08), _u(r, x + 0.03, y + 0.12), _u(r, x, y + 0.12), _u(r, x, 0.74)]))
	S(ci, sg, 0.55, 1.2)
	var sc := PackedVector2Array()
	for k in 10:
		var t: float = (k + 0.5) / 10.0
		sc.append(_u(r, lerpf(0.18, 0.86, t), lerpf(0.47, 0.31, t)))
		sc.append(_u(r, lerpf(0.18, 0.86, t), lerpf(0.57, 0.41, t)))
	S(ci, sc, 0.22, 1.0)
	for x in [0.4, 0.62]:
		var y: float = lerpf(0.46, 0.3, (x - 0.18) / 0.68)
		O(ci, _u(r, x, y - 0.1), ms * 0.09, 0.55, 1.2)
	_gband(ci, r, 0.03, 0.17, 0.36, Pal.heat(0.55))
	_gband(ci, r, 0.2, 0.8, 0.86, Pal.heat(0.5))


# ---------------------------------------------------------------- M-14: crusher and trommel screen
# the crushing and screening plant: the feed hopper, the jaw crusher under it (the fixed jaw, the
# swing jaw, the flywheel), the inclined trommel drum it feeds (its riding rings, the perforations, the
# girth gear and its drive), the fines chute under the drum, the oversize out of its end
static func crusher_trommel(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.02, 0.04), _u(r, 0.12, 0.3), _u(r, 0.38, 0.04), _u(r, 0.28, 0.3),
		_u(r, 0.12, 0.3), _u(r, 0.16, 0.56), _u(r, 0.28, 0.3), _u(r, 0.2, 0.56), _u(r, 0.06, 0.3), _u(r, 0.06, 0.6), _u(r, 0.34, 0.3), _u(r, 0.34, 0.6),
		_u(r, 0.36, 0.5), _u(r, 0.96, 0.66), _u(r, 0.36, 0.72), _u(r, 0.96, 0.88), _u(r, 0.36, 0.5), _u(r, 0.36, 0.72), _u(r, 0.96, 0.66), _u(r, 0.96, 0.88),
		_u(r, 0.5, 0.78), _u(r, 0.46, 0.98), _u(r, 0.86, 0.88), _u(r, 0.82, 0.98), _u(r, 0.46, 0.98), _u(r, 0.82, 0.98), _u(r, 0.96, 0.78), _u(r, 1.0, 0.92)])
	for x in [0.48, 0.84]:
		var y0: float = lerpf(0.5, 0.66, (x - 0.36) / 0.6)
		sg.append_array(PackedVector2Array([_u(r, x, y0 - 0.02), _u(r, x, y0 + 0.24), _u(r, x + 0.02, y0 - 0.02), _u(r, x + 0.02, y0 + 0.24)]))
	S(ci, sg, 0.55, 1.2)
	var pf := PackedVector2Array()
	for k in 8:
		var t: float = 0.3 + k * 0.08
		for j in 3:
			var y: float = lerpf(0.5, 0.66, t) + 0.05 + j * 0.06
			pf.append(_u(r, 0.36 + t * 0.6, y))
			pf.append(_u(r, 0.38 + t * 0.6, y))
	S(ci, pf, 0.35, 1.2)
	O(ci, _u(r, 0.06, 0.74), ms * 0.12, 0.55, 1.2)


# ---------------------------------------------------------------- DR-150 / SP-FLUID: standpipe manifold
# the derrick's standpipe: the riser up the leg (its clamps to the leg), the gooseneck at the top and
# the kelly hose's union off it, the standpipe manifold at the foot with its two gate valves (their
# wheels), the pressure gauge, the bleed-off line
static func standpipe_riser(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.86, 0.0), _u(r, 0.86, 1.0)])
	for y in [0.3, 0.55]:
		sg.append_array(PackedVector2Array([_u(r, 0.38, y), _u(r, 0.86, y), _u(r, 0.38, y + 0.03), _u(r, 0.86, y + 0.03)]))
	sg.append_array(PackedVector2Array([_u(r, 0.6, 0.12), _u(r, 0.6, 0.18), _u(r, 0.68, 0.12), _u(r, 0.68, 0.18),
		_u(r, 0.32, 0.86), _u(r, 0.1, 0.86), _u(r, 0.18, 0.78), _u(r, 0.18, 0.94), _u(r, 0.08, 0.78), _u(r, 0.08, 0.94),
		_u(r, 0.32, 0.72), _u(r, 0.12, 0.72), _u(r, 0.12, 0.72), _u(r, 0.12, 0.6), _u(r, 0.32, 0.96), _u(r, 0.32, 1.0)]))
	_rs(sg, sub(r, 0.24, 0.8, 0.4, 0.92))
	S(ci, sg, 0.55, 1.2)
	S(ci, PackedVector2Array([_u(r, 0.32, 0.98), _u(r, 0.32, 0.12)]), 0.6, 2.4)
	A(ci, _u(r, 0.46, 0.12), r.size.x * 0.14, PI, TAU, 0.6, 2.4)
	S(ci, PackedVector2Array([_u(r, 0.6, 0.12), _u(r, 0.64, 0.4), _u(r, 0.64, 0.4), _u(r, 0.56, 0.7)]), 0.45, 2.0)
	O(ci, _u(r, 0.12, 0.56), ms * 0.08, 0.55)
	_gband(ci, r, 0.27, 0.37, 0.46, Pal.heat(0.6))


# ---------------------------------------------------------------- HG-170: turboexpander
# the helium turboexpander: the expander's casing (the hot gas in, the cold gas out), the brake
# compressor's casing on the same shaft, the bearing housing between them, the oil console under them
# (its tank, pump, filter), the trip valve on the inlet, the frost on the cold end
static func turbo_expander(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.4, 0.3, 0.6, 0.52))
	_rs(sg, sub(r, 0.06, 0.66, 0.94, 0.96))
	_rs(sg, sub(r, 0.12, 0.72, 0.34, 0.9))
	_rs(sg, sub(r, 0.62, 0.72, 0.72, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.41), _u(r, 0.94, 0.41), _u(r, 0.22, 0.14), _u(r, 0.22, 0.02), _u(r, 0.78, 0.14), _u(r, 0.78, 0.02),
		_u(r, 0.22, 0.68), _u(r, 0.22, 0.6), _u(r, 0.5, 0.52), _u(r, 0.5, 0.66), _u(r, 0.12, 0.08), _u(r, 0.22, 0.08), _u(r, 0.86, 0.66), _u(r, 0.86, 0.5)]))
	_rs(sg, sub(r, 0.16, 0.04, 0.28, 0.12))
	S(ci, sg, 0.55, 1.2)
	var wh := PackedVector2Array()
	_arcs(wh, _u(r, 0.22, 0.41), r.size.x * 0.17, r.size.y * 0.27, 0.0, TAU, 9)
	_arcs(wh, _u(r, 0.78, 0.41), r.size.x * 0.17, r.size.y * 0.27, 0.0, TAU, 9)
	for c in [Vector2(0.22, 0.41), Vector2(0.78, 0.41)]:
		for k in 6:
			var a: float = TAU * k / 6.0
			wh.append(_u(r, c.x, c.y) + Vector2.from_angle(a) * ms * 0.05)
			wh.append(_u(r, c.x, c.y) + Vector2.from_angle(a + 0.6) * ms * 0.2)
	S(ci, wh, 0.5, 1.1)
	_gband(ci, r, 0.06, 0.38, 0.7, Pal.tint(Pal.AIR, 0.75))
	_gband(ci, r, 0.13, 0.33, 0.8, Pal.tint(Pal.FLUID, 0.6))


# ---------------------------------------------------------------- ARK-01 (x6): colonist's berth pod
# a colonist's sleeping berth: the pod's curved canopy over the mattress, the pillow, the privacy
# curtain on its rail, the reading lamp, the storage drawer under it
static func berth_pod(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.02, 0.6), _u(r, 0.98, 0.6), _u(r, 0.02, 0.74), _u(r, 0.98, 0.74), _u(r, 0.02, 0.96), _u(r, 0.98, 0.96),
		_u(r, 0.02, 0.6), _u(r, 0.02, 0.96), _u(r, 0.98, 0.6), _u(r, 0.98, 0.96), _u(r, 0.46, 0.84), _u(r, 0.56, 0.84),
		_u(r, 0.06, 0.6), _u(r, 0.06, 0.48), _u(r, 0.06, 0.48), _u(r, 0.2, 0.48), _u(r, 0.2, 0.48), _u(r, 0.2, 0.6)])
	_arcs(sg, _u(r, 0.5, 0.6), r.size.x * 0.48, r.size.y * 0.56, PI, TAU, 8)
	S(ci, sg, 0.55, 1.1)
	var cu := PackedVector2Array([_u(r, 0.62, 0.12), _u(r, 0.62, 0.6)])
	for k in 3:
		var x: float = 0.66 + k * 0.08
		cu.append(_u(r, x, 0.1 + k * 0.01))
		cu.append(_u(r, x, 0.6))
	S(ci, cu, 0.3, 1.0)
	_lamp(ci, _u(r, 0.3, 0.2), maxf(1.4, r.size.y * 0.08), Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- ARK-01 / EV-55: operating table
# the operating table: the column on its base, the tabletop's sections (head, back, seat, legs) and
# their joints, the arm board out to the side, the surgical light on its boom over it
static func operating_table(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.08, 0.5), _u(r, 0.22, 0.5), _u(r, 0.22, 0.5), _u(r, 0.46, 0.46), _u(r, 0.46, 0.46), _u(r, 0.7, 0.46), _u(r, 0.7, 0.46), _u(r, 0.94, 0.52),
		_u(r, 0.08, 0.56), _u(r, 0.22, 0.56), _u(r, 0.22, 0.56), _u(r, 0.46, 0.52), _u(r, 0.46, 0.52), _u(r, 0.7, 0.52), _u(r, 0.7, 0.52), _u(r, 0.94, 0.58),
		_u(r, 0.5, 0.52), _u(r, 0.5, 0.86), _u(r, 0.56, 0.52), _u(r, 0.56, 0.86), _u(r, 0.32, 0.86), _u(r, 0.74, 0.86), _u(r, 0.32, 0.94), _u(r, 0.74, 0.94),
		_u(r, 0.32, 0.86), _u(r, 0.32, 0.94), _u(r, 0.74, 0.86), _u(r, 0.74, 0.94), _u(r, 0.36, 0.5), _u(r, 0.3, 0.68),
		_u(r, 0.9, 0.0), _u(r, 0.9, 0.12), _u(r, 0.9, 0.12), _u(r, 0.62, 0.18)])
	S(ci, sg, 0.55, 1.2)
	for x in [0.22, 0.46, 0.7]:
		D(ci, _u(r, x, 0.53), maxf(1.2, ms * 0.04), 0.6)
	A(ci, _u(r, 0.56, 0.26), ms * 0.16, PI, TAU, 0.55, 1.2)
	_gband(ci, r, 0.46, 0.66, 0.27, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- MED-47 / MY-48 / PT-34: ICU bed and monitor
# the intensive-care bed: the bed frame on its castors, the mattress with the head raised, the side
# rail, the IV pole and its bag, the patient monitor on its arm (its screen and trace)
static func icu_bed(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.06, 0.66), _u(r, 0.96, 0.66), _u(r, 0.06, 0.74), _u(r, 0.96, 0.74), _u(r, 0.36, 0.6), _u(r, 0.96, 0.6),
		_u(r, 0.36, 0.6), _u(r, 0.14, 0.36), _u(r, 0.14, 0.36), _u(r, 0.1, 0.42), _u(r, 0.1, 0.42), _u(r, 0.3, 0.66),
		_u(r, 0.42, 0.52), _u(r, 0.82, 0.52), _u(r, 0.42, 0.52), _u(r, 0.42, 0.6), _u(r, 0.82, 0.52), _u(r, 0.82, 0.6),
		_u(r, 0.16, 0.74), _u(r, 0.16, 0.92), _u(r, 0.86, 0.74), _u(r, 0.86, 0.92), _u(r, 0.5, 0.74), _u(r, 0.5, 0.84), _u(r, 0.16, 0.84), _u(r, 0.86, 0.84),
		_u(r, 0.04, 0.02), _u(r, 0.04, 0.66), _u(r, 0.0, 0.04), _u(r, 0.08, 0.04), _u(r, 0.98, 0.24), _u(r, 0.98, 0.66), _u(r, 0.98, 0.3), _u(r, 0.9, 0.3)])
	_rs(sg, sub(r, 0.02, 0.06, 0.08, 0.22))
	_rs(sg, sub(r, 0.76, 0.08, 0.96, 0.3))
	S(ci, sg, 0.55, 1.1)
	for x in [0.16, 0.86]:
		D(ci, _u(r, x, 0.94), maxf(1.2, ms * 0.05), 0.6)
	_pu(ci, r, [Vector2(0.78, 0.2), Vector2(0.82, 0.2), Vector2(0.84, 0.12), Vector2(0.86, 0.26), Vector2(0.88, 0.2), Vector2(0.94, 0.2)], 0.7, 1.0)
	_gband(ci, r, 0.025, 0.075, 0.16, Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- many ships: crew berth
# a crew berth (or the berths stacked and side by side where the space holds more): each berth's
# frame and mattress, the pillow, the lee rail, the reading lamp, the curtain's rail
static func crew_berth(ci: CanvasItem, r: Rect2) -> void:
	var rows := clampi(roundi(r.size.y / 34.0), 1, 2)
	var cols := clampi(roundi(r.size.x / 106.0), 1, 2)
	var sg := PackedVector2Array()
	var lm := PackedVector2Array()
	for i in cols:
		for j in rows:
			var q := Rect2(r.position + Vector2(r.size.x * i / cols, r.size.y * j / rows), Vector2(r.size.x / cols, r.size.y / rows))
			_rs(sg, sub(q, 0.02, 0.2, 0.98, 0.94))
			sg.append_array(PackedVector2Array([_u(q, 0.02, 0.5), _u(q, 0.98, 0.5), _u(q, 0.04, 0.5), _u(q, 0.04, 0.3), _u(q, 0.04, 0.3), _u(q, 0.16, 0.3), _u(q, 0.16, 0.3), _u(q, 0.16, 0.5),
				_u(q, 0.3, 0.2), _u(q, 0.3, 0.1), _u(q, 0.3, 0.1), _u(q, 0.94, 0.1), _u(q, 0.94, 0.1), _u(q, 0.94, 0.2)]))
			lm.append(_u(q, 0.1, 0.14))
	S(ci, sg, 0.55, 1.1)
	for c in lm:
		_lamp(ci, c, maxf(1.2, r.size.y / rows * 0.1), Pal.tint(Pal.FLUID, 0.8))


# ---------------------------------------------------------------- ARK-01 and 13 ships: two-tier crew bunk
# a two-tier crew bunk: the end posts, the two berths (mattresses, pillows), the ladder up the end, the
# curtains half drawn on the upper, the drawers under the lower
static func double_bunk(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.0), _u(r, 0.04, 1.0), _u(r, 0.96, 0.0), _u(r, 0.96, 1.0), _u(r, 0.04, 0.4), _u(r, 0.96, 0.4), _u(r, 0.04, 0.78), _u(r, 0.96, 0.78),
		_u(r, 0.04, 0.32), _u(r, 0.96, 0.32), _u(r, 0.04, 0.7), _u(r, 0.96, 0.7), _u(r, 0.06, 0.32), _u(r, 0.06, 0.24), _u(r, 0.06, 0.24), _u(r, 0.18, 0.24), _u(r, 0.18, 0.24), _u(r, 0.18, 0.32),
		_u(r, 0.06, 0.7), _u(r, 0.06, 0.62), _u(r, 0.06, 0.62), _u(r, 0.18, 0.62), _u(r, 0.18, 0.62), _u(r, 0.18, 0.7),
		_u(r, 0.04, 0.02), _u(r, 0.96, 0.02), _u(r, 0.5, 0.78), _u(r, 0.5, 1.0), _u(r, 0.24, 0.89), _u(r, 0.3, 0.89), _u(r, 0.7, 0.89), _u(r, 0.76, 0.89)])
	for k in 3:
		var y: float = 0.5 + k * 0.1
		sg.append(_u(r, 0.86, y))
		sg.append(_u(r, 0.96, y))
	sg.append_array(PackedVector2Array([_u(r, 0.86, 0.4), _u(r, 0.86, 0.78)]))
	S(ci, sg, 0.55, 1.1)
	var cu := PackedVector2Array()
	for k in 4:
		var x: float = 0.5 + k * 0.08
		cu.append(_u(r, x, 0.04))
		cu.append(_u(r, x + 0.02, 0.32))
	S(ci, cu, 0.3, 1.0)


# ---------------------------------------------------------------- PS-12 (x12): rest capsules
# a pair of rest capsules, one over the other: each capsule's rounded shell, its entrance shade half
# down, the screen and the vent inside, the step up to the upper
static func rest_capsules(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	for y0 in [0.04, 0.52]:
		var q := sub(r, 0.02, y0, 0.98, y0 + 0.44)
		_hves(sg, q, q.size.y * 0.4, 4)
		sg.append_array(PackedVector2Array([_u(r, 0.86, y0 + 0.06), _u(r, 0.86, y0 + 0.38), _u(r, 0.7, y0 + 0.06), _u(r, 0.7, y0 + 0.22)]))
		_rs(sg, sub(r, 0.2, y0 + 0.08, 0.34, y0 + 0.18))
		for k in 3:
			var x: float = 0.4 + k * 0.04
			sg.append(_u(r, x, y0 + 0.08))
			sg.append(_u(r, x, y0 + 0.14))
	sg.append_array(PackedVector2Array([_u(r, 0.74, 0.96), _u(r, 0.98, 0.96)]))
	S(ci, sg, 0.55, 1.1)
	for y0 in [0.04, 0.52]:
		E.Rc(ci, sub(r, 0.21, y0 + 0.09, 0.33, y0 + 0.17), Pal.tint(Pal.VOLT, 0.7), 1.0)


# ---------------------------------------------------------------- BL-88: drum composter
# the in-vessel composter: the drum on its stand rollers (its hoops, the loading hatch), the gear
# motor turning it, the aeration pipe along its axis, the leachate tray under it
static func drum_composter(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.14, 0.86, 0.66))
	for x in [0.2, 0.74]:
		sg.append(_u(r, x, 0.12))
		sg.append(_u(r, x, 0.68))
	_rs(sg, sub(r, 0.38, 0.2, 0.56, 0.3))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.4), _u(r, 1.0, 0.4), _u(r, 0.14, 0.66), _u(r, 0.1, 0.9), _u(r, 0.8, 0.66), _u(r, 0.84, 0.9),
		_u(r, 0.04, 0.9), _u(r, 0.96, 0.9), _u(r, 0.12, 0.82), _u(r, 0.82, 0.82), _u(r, 0.12, 0.82), _u(r, 0.12, 0.86), _u(r, 0.82, 0.82), _u(r, 0.82, 0.86)]))
	_rs(sg, sub(r, 0.86, 0.3, 0.98, 0.5))
	S(ci, sg, 0.55, 1.2)
	for x in [0.2, 0.74]:
		O(ci, _u(r, x, 0.7), ms * 0.04, 0.55)
	_gband(ci, r, 0.09, 0.85, 0.56, Pal.heat(0.5))
	_gband(ci, r, 0.13, 0.81, 0.84, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- PS-12 (x4): escape capsule
# a passenger escape capsule in its cradle: the rounded hull, its hatch and the hatch wheel, the
# portholes, the seat rows inside, the docking collar and its release clamps, the retro motor
static func escape_capsule(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_hves(sg, sub(r, 0.08, 0.08, 0.92, 0.92), r.size.y * 0.4, 5)
	_rs(sg, sub(r, 0.36, 0.2, 0.56, 0.8))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.3), _u(r, 0.08, 0.3), _u(r, 0.0, 0.7), _u(r, 0.08, 0.7), _u(r, 0.02, 0.3), _u(r, 0.02, 0.7),
		_u(r, 0.92, 0.4), _u(r, 1.0, 0.34), _u(r, 0.92, 0.6), _u(r, 1.0, 0.66), _u(r, 1.0, 0.34), _u(r, 1.0, 0.66)]))
	S(ci, sg, 0.55, 1.2)
	var st := PackedVector2Array()
	for k in 3:
		var x: float = 0.62 + k * 0.08
		st.append_array(PackedVector2Array([_u(r, x, 0.3), _u(r, x, 0.7), _u(r, x, 0.7), _u(r, x + 0.04, 0.7)]))
	S(ci, st, 0.3, 1.0)
	O(ci, _u(r, 0.46, 0.5), ms * 0.1, 0.55, 1.2)
	for x in [0.2, 0.28]:
		O(ci, _u(r, x, 0.42), ms * 0.07, 0.5)
	_gband(ci, r, 0.1, 0.9, 0.12, Pal.heat(0.75))


# ---------------------------------------------------------------- 9 ships: galley counter
# a small ship's galley counter: the worktop and its splashback, the sink (its basin and tap), the
# two-ring induction hob, the cupboards under it (their doors and handles), the extract hood over the hob
static func galley_counter(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.5, 0.98, 0.98))
	_rs(sg, sub(r, 0.08, 0.5, 0.36, 0.62))
	_rs(sg, sub(r, 0.56, 0.02, 0.94, 0.16))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.56), _u(r, 0.98, 0.56), _u(r, 0.22, 0.5), _u(r, 0.22, 0.4), _u(r, 0.22, 0.4), _u(r, 0.3, 0.4),
		_u(r, 0.34, 0.66), _u(r, 0.34, 0.98), _u(r, 0.66, 0.66), _u(r, 0.66, 0.98), _u(r, 0.28, 0.76), _u(r, 0.28, 0.86), _u(r, 0.4, 0.76), _u(r, 0.4, 0.86),
		_u(r, 0.72, 0.76), _u(r, 0.72, 0.86), _u(r, 0.66, 0.16), _u(r, 0.84, 0.16), _u(r, 0.66, 0.16), _u(r, 0.66, 0.24), _u(r, 0.84, 0.16), _u(r, 0.84, 0.24)]))
	S(ci, sg, 0.55, 1.1)
	for x in [0.62, 0.86]:
		O(ci, _u(r, x, 0.48), ms * 0.08, 0.5)
	_gband(ci, r, 0.09, 0.35, 0.53, Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- CH-110 / MT-140 / PS-12: crew mess serving line
# the crew mess's serving line: the counter with its hot wells (each pan under its lid), the sneeze
# guard's glass over them, the tray slide along the front, the drinks dispenser at the end, the stack
# of plates
static func mess_serving_line(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.46, 0.98, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.0, 0.62), _u(r, 0.98, 0.62), _u(r, 0.0, 0.66), _u(r, 0.98, 0.66),
		_u(r, 0.06, 0.2), _u(r, 0.66, 0.2), _u(r, 0.06, 0.2), _u(r, 0.04, 0.46), _u(r, 0.66, 0.2), _u(r, 0.68, 0.46)]))
	for k in 4:
		var x0: float = 0.06 + k * 0.15
		_rs(sg, sub(r, x0, 0.4, x0 + 0.13, 0.46))
		sg.append(_u(r, x0 + 0.05, 0.4))
		sg.append(_u(r, x0 + 0.08, 0.36))
	_rs(sg, sub(r, 0.72, 0.06, 0.86, 0.46))
	_rs(sg, sub(r, 0.75, 0.12, 0.83, 0.24))
	for k in 4:
		var y: float = 0.42 - k * 0.03
		sg.append(_u(r, 0.88, y))
		sg.append(_u(r, 0.98, y))
	for k in 5:
		var x: float = 0.12 + k * 0.18
		sg.append(_u(r, x, 0.74))
		sg.append(_u(r, x, 0.92))
	S(ci, sg, 0.55, 1.1)
	for k in 4:
		_gband(ci, r, 0.07 + k * 0.15, 0.18 + k * 0.15, 0.44, Pal.heat(0.6))
	E.Rc(ci, sub(r, 0.76, 0.13, 0.82, 0.23), Pal.tint(Pal.FLUID, 0.7), 1.0)


# ---------------------------------------------------------------- 7 ships: ship's galley
# the ship's galley: the range (four burners, the oven door under them, its handle), the combi oven
# stacked beside it, the extraction hood over the range and its grease filters, the prep sink, the
# reach-in fridge, the fiddle rail along the front
static func ship_galley(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.46, 0.34, 0.98))
	_rs(sg, sub(r, 0.05, 0.58, 0.31, 0.9))
	_rs(sg, sub(r, 0.02, 0.04, 0.34, 0.2))
	for k in 3:
		var x: float = 0.06 + k * 0.1
		sg.append(_u(r, x, 0.2))
		sg.append(_u(r, x + 0.08, 0.06))
	_rs(sg, sub(r, 0.38, 0.12, 0.6, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.38, 0.4), _u(r, 0.6, 0.4), _u(r, 0.38, 0.7), _u(r, 0.6, 0.7), _u(r, 0.56, 0.2), _u(r, 0.56, 0.34),
		_u(r, 0.08, 0.6), _u(r, 0.28, 0.6), _u(r, 0.02, 0.42), _u(r, 0.34, 0.42)]))
	_rs(sg, sub(r, 0.64, 0.5, 0.8, 0.98))
	_rs(sg, sub(r, 0.67, 0.5, 0.77, 0.58))
	sg.append_array(PackedVector2Array([_u(r, 0.72, 0.5), _u(r, 0.72, 0.4), _u(r, 0.72, 0.4), _u(r, 0.68, 0.4)]))
	_rs(sg, sub(r, 0.82, 0.18, 0.98, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.85, 0.3), _u(r, 0.85, 0.5), _u(r, 0.82, 0.62), _u(r, 0.98, 0.62)]))
	S(ci, sg, 0.55, 1.1)
	for x in [0.1, 0.26]:
		O(ci, _u(r, x, 0.48), ms * 0.04, 0.5)
	E.Rc(ci, sub(r, 0.41, 0.15, 0.53, 0.2), Pal.tint(Pal.FLUID, 0.7), 1.0)
	_gband(ci, r, 0.06, 0.3, 0.46, Pal.heat(0.7))
	_gband(ci, r, 0.83, 0.97, 0.22, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- ARK-01 (x21): emergency equipment locker
# an emergency equipment locker: the cabinet and its glazed door (the frame, the latch), the
# extinguisher standing in it, the axe on its clips, the rescue line coiled on its peg, the first-aid
# box on the shelf, the alarm colour along its top
static func emergency_kit_locker(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	_rs(sg, sub(r, 0.12, 0.1, 0.88, 0.92))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.3), _u(r, 0.88, 0.3), _u(r, 0.82, 0.5), _u(r, 0.82, 0.6),
		_u(r, 0.62, 0.36), _u(r, 0.62, 0.86), _u(r, 0.56, 0.4), _u(r, 0.72, 0.36), _u(r, 0.72, 0.36), _u(r, 0.72, 0.46)]))
	_vbot(sg, sub(r, 0.2, 0.4, 0.44, 0.88))
	_rs(sg, sub(r, 0.2, 0.16, 0.48, 0.28))
	S(ci, sg, 0.55, 1.0)
	O(ci, _u(r, 0.68, 0.2), ms * 0.14, 0.45, 1.3)
	_gband(ci, r, 0.07, 0.93, 0.05, Pal.heat(0.85))
	_gband(ci, r, 0.21, 0.43, 0.55, Pal.heat(0.75))


# ---------------------------------------------------------------- ARK-01 (x42): crew locker (two tier)
# a two-tier crew locker: the cabinet, the upper and lower doors, each door's vent slots, its hasp and
# padlock, the blank name plate, the coat hook on the side
static func tier_locker(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.02, 0.92, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.08, 0.5), _u(r, 0.92, 0.5), _u(r, 0.92, 0.2), _u(r, 1.0, 0.16)]))
	for y0 in [0.02, 0.5]:
		for k in 3:
			var y: float = y0 + 0.06 + k * 0.035
			sg.append(_u(r, 0.3, y))
			sg.append(_u(r, 0.7, y))
		_rs(sg, sub(r, 0.3, y0 + 0.24, 0.6, y0 + 0.3))
		sg.append(_u(r, 0.8, y0 + 0.22))
		sg.append(_u(r, 0.8, y0 + 0.34))
	S(ci, sg, 0.55, 1.0)


# ---------------------------------------------------------------- PS-12: baggage hold
# the passenger baggage hold: the hold's outline, the cargo net across it (its mesh), the suitcases and
# holdalls stacked inside (their handles), the tie-down rails on the floor and wall
static func baggage_hold(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.02, 0.98, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.94), _u(r, 0.98, 0.94), _u(r, 0.06, 0.02), _u(r, 0.06, 0.98)]))
	var bags := [[0.1, 0.62, 0.4, 0.94], [0.42, 0.7, 0.66, 0.94], [0.68, 0.56, 0.94, 0.94], [0.12, 0.34, 0.34, 0.62], [0.36, 0.44, 0.62, 0.7], [0.66, 0.3, 0.9, 0.56], [0.2, 0.12, 0.46, 0.34]]
	for b in bags:
		_rs(sg, sub(r, b[0], b[1], b[2], b[3]))
		var xm: float = (b[0] + b[2]) * 0.5
		sg.append_array(PackedVector2Array([_u(r, xm - 0.04, b[1]), _u(r, xm - 0.04, b[1] - 0.03), _u(r, xm - 0.04, b[1] - 0.03), _u(r, xm + 0.04, b[1] - 0.03), _u(r, xm + 0.04, b[1] - 0.03), _u(r, xm + 0.04, b[1])]))
	S(ci, sg, 0.55, 1.1)
	var nt := PackedVector2Array()
	for k in 6:
		var t: float = k / 5.0
		nt.append(_u(r, 0.06 + t * 0.92, 0.04))
		nt.append(_u(r, 0.06 + maxf(t - 0.4, 0.0) * 0.92, 0.04 + minf(t, 0.4) * 2.3))
		nt.append(_u(r, 0.06 + t * 0.92, 0.04))
		nt.append(_u(r, 0.06 + minf(t + 0.4, 1.0) * 0.92, 0.04 + minf(1.0 - t, 0.4) * 2.3))
	S(ci, nt, 0.24, 1.0)


# ---------------------------------------------------------------- PS-12 (x3): overhead bins
# a row of passenger overhead bins: the bins' doors (each its latch), the hinge line along the top, the
# handrail along the foot, the reading lights and call buttons under them
static func overhead_bins(ci: CanvasItem, r: Rect2) -> void:
	var n := clampi(int(r.size.x / 48.0), 2, 16)
	var sg := PackedVector2Array([_u(r, 0.0, 0.08), _u(r, 1.0, 0.08), _u(r, 0.0, 0.7), _u(r, 1.0, 0.7), _u(r, 0.0, 0.86), _u(r, 1.0, 0.86)])
	for k in n + 1:
		var x: float = float(k) / n
		sg.append(_u(r, x, 0.08))
		sg.append(_u(r, x, 0.7))
	for k in n:
		var xm: float = (k + 0.5) / n
		sg.append(_u(r, xm - 0.1 / n, 0.56))
		sg.append(_u(r, xm + 0.1 / n, 0.56))
	S(ci, sg, 0.55, 1.1)
	for k in n:
		_lamp(ci, _u(r, (k + 0.3) / n, 0.78), maxf(1.2, r.size.y * 0.08), Pal.tint(Pal.FLUID, 0.75))


# ---------------------------------------------------------------- M-14: explosives magazine
# the blasting charges' magazine: the steel box on its timber skids, the double lid and its hinges,
# the hasp and its padlock, the vent louvres, the earthing strap, the hazard diamond on its face
static func explosives_magazine(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.18, 0.94, 0.86))
	_rs(sg, sub(r, 0.02, 0.1, 0.98, 0.18))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.1), _u(r, 0.5, 0.18), _u(r, 0.06, 0.86), _u(r, 0.06, 0.96), _u(r, 0.94, 0.86), _u(r, 0.94, 0.96),
		_u(r, 0.02, 0.96), _u(r, 0.98, 0.96), _u(r, 0.94, 0.78), _u(r, 1.0, 0.98),
		_u(r, 0.5, 0.3), _u(r, 0.62, 0.48), _u(r, 0.62, 0.48), _u(r, 0.5, 0.66), _u(r, 0.5, 0.66), _u(r, 0.38, 0.48), _u(r, 0.38, 0.48), _u(r, 0.5, 0.3)]))
	for k in 3:
		var y: float = 0.66 + k * 0.05
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.3, y))
	_rs(sg, sub(r, 0.46, 0.18, 0.54, 0.26))
	S(ci, sg, 0.55, 1.1)
	A(ci, _u(r, 0.5, 0.18), r.size.x * 0.03, PI, TAU, 0.6, 1.0)
	_gband(ci, r, 0.44, 0.56, 0.48, Pal.heat(0.85))


# ---------------------------------------------------------------- PT-34: damage-control locker
# the damage-control locker standing open: the cabinet and its door swung back, the shoring timbers
# stood inside, the box of wedges and plugs, the sledgehammer and the patch on their clips
static func dc_gear_locker(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.2, 0.02, 0.96, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.2, 0.02), _u(r, 0.02, 0.1), _u(r, 0.02, 0.1), _u(r, 0.02, 0.9), _u(r, 0.02, 0.9), _u(r, 0.2, 0.98)]))
	for k in 3:
		var x: float = 0.28 + k * 0.08
		sg.append(_u(r, x, 0.08))
		sg.append(_u(r, x + 0.04, 0.94))
		sg.append(_u(r, x + 0.04, 0.08))
		sg.append(_u(r, x + 0.08, 0.94))
	_rs(sg, sub(r, 0.6, 0.72, 0.92, 0.94))
	for k in 3:
		var x: float = 0.64 + k * 0.09
		sg.append_array(PackedVector2Array([_u(r, x, 0.92), _u(r, x + 0.03, 0.8), _u(r, x + 0.03, 0.8), _u(r, x + 0.06, 0.92)]))
	sg.append_array(PackedVector2Array([_u(r, 0.66, 0.1), _u(r, 0.66, 0.6), _u(r, 0.6, 0.1), _u(r, 0.72, 0.1), _u(r, 0.6, 0.1), _u(r, 0.6, 0.16), _u(r, 0.72, 0.1), _u(r, 0.72, 0.16)]))
	_rs(sg, sub(r, 0.78, 0.1, 0.92, 0.5))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.79, 0.91, 0.3, Pal.heat(0.7))


# ---------------------------------------------------------------- MED-47 (x2): corridor emergency cabinet
# the corridor's emergency cabinet: the box and its glass door, the fire hose reel inside (the drum, the
# hose's coils), the branch pipe, the small extinguisher beside it
static func hose_reel_cabinet(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.04, 0.96, 0.96))
	_rs(sg, sub(r, 0.08, 0.1, 0.92, 0.9))
	sg.append_array(PackedVector2Array([_u(r, 0.36, 0.5), _u(r, 0.5, 0.8), _u(r, 0.5, 0.8), _u(r, 0.6, 0.8)]))
	_vbot(sg, sub(r, 0.72, 0.24, 0.86, 0.86))
	S(ci, sg, 0.55, 1.0)
	O(ci, _u(r, 0.36, 0.5), ms * 0.32, 0.55, 1.2)
	O(ci, _u(r, 0.36, 0.5), ms * 0.22, 0.4, 1.2)
	D(ci, _u(r, 0.36, 0.5), maxf(1.2, ms * 0.06), 0.6)
	_gband(ci, r, 0.73, 0.85, 0.5, Pal.heat(0.8))
	_gband(ci, r, 0.05, 0.95, 0.06, Pal.heat(0.8))


# ---------------------------------------------------------------- ES-112 (x3): guard's weapons locker
# the guards' weapons locker: the barred door over the rifle rack (the rifles stood in their slots,
# stocks down), the ammunition drawer under it, the combination dial
static func weapons_locker(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	_rs(sg, sub(r, 0.12, 0.78, 0.88, 0.92))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.74), _u(r, 0.94, 0.74), _u(r, 0.12, 0.66), _u(r, 0.88, 0.66), _u(r, 0.44, 0.84), _u(r, 0.56, 0.84)]))
	for k in 4:
		var x: float = 0.18 + k * 0.18
		sg.append_array(PackedVector2Array([_u(r, x, 0.1), _u(r, x, 0.64), _u(r, x, 0.64), _u(r, x - 0.03, 0.72), _u(r, x - 0.03, 0.72), _u(r, x + 0.05, 0.72), _u(r, x + 0.05, 0.72), _u(r, x + 0.02, 0.6),
			_u(r, x, 0.34), _u(r, x + 0.04, 0.34)]))
	S(ci, sg, 0.55, 1.1)
	var br := PackedVector2Array()
	for k in 5:
		var x: float = 0.1 + k * 0.2
		br.append(_u(r, x, 0.04))
		br.append(_u(r, x, 0.72))
	S(ci, br, 0.3, 1.2)
	O(ci, _u(r, 0.8, 0.4), ms * 0.08, 0.6, 1.2)


# ---------------------------------------------------------------- RO-128: lashing gear store
# the vehicle deck's lashing store: the tall rack, the lashing chains hung in coils on its hooks, the
# ratchet tensioners on the rail, the straps, the wheel chocks stacked at the foot
static func lashing_store(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.01, 0.96, 0.99))
	for y in [0.06, 0.38, 0.62]:
		sg.append(_u(r, 0.04, y))
		sg.append(_u(r, 0.96, y))
	for k in 3:
		var x: float = 0.18 + k * 0.32
		sg.append_array(PackedVector2Array([_u(r, x - 0.06, 0.4), _u(r, x - 0.06, 0.56), _u(r, x + 0.06, 0.4), _u(r, x + 0.06, 0.56), _u(r, x - 0.06, 0.48), _u(r, x - 0.1, 0.48),
			_u(r, x, 0.62), _u(r, x, 0.76)]))
	for k in 3:
		var y0: float = 0.82 + k * 0.055
		sg.append_array(PackedVector2Array([_u(r, 0.1, y0 + 0.05), _u(r, 0.5, y0 + 0.05), _u(r, 0.1, y0 + 0.05), _u(r, 0.2, y0), _u(r, 0.2, y0), _u(r, 0.5, y0 + 0.05)]))
	S(ci, sg, 0.55, 1.1)
	for k in 3:
		var c := _u(r, 0.2 + k * 0.3, 0.2)
		O(ci, c, ms * 0.13, 0.5, 1.6)
		O(ci, c + Vector2(0, ms * 0.04), ms * 0.09, 0.45, 1.6)
	_gband(ci, r, 0.55, 0.9, 0.9, Pal.heat(0.6))


# ---------------------------------------------------------------- many ships: tool locker
# a tool locker (one bay, or several where it is wide): the cabinet, the pegboard door with the tools'
# outlines on it (a spanner, a hammer, a screwdriver), the drawers under it and their pulls
static func tool_locker(ci: CanvasItem, r: Rect2) -> void:
	var n := clampi(roundi(r.size.x / maxf(r.size.y * 0.45, 14.0)), 1, 4)
	var bw: float = 1.0 / n
	var sg := PackedVector2Array()
	for k in n:
		var x0: float = k * bw
		_rs(sg, sub(r, x0 + bw * 0.06, 0.02, x0 + bw * 0.94, 0.98))
		sg.append_array(PackedVector2Array([_u(r, x0 + bw * 0.06, 0.62), _u(r, x0 + bw * 0.94, 0.62), _u(r, x0 + bw * 0.06, 0.74), _u(r, x0 + bw * 0.94, 0.74), _u(r, x0 + bw * 0.06, 0.86), _u(r, x0 + bw * 0.94, 0.86),
			_u(r, x0 + bw * 0.4, 0.68), _u(r, x0 + bw * 0.6, 0.68), _u(r, x0 + bw * 0.4, 0.8), _u(r, x0 + bw * 0.6, 0.8), _u(r, x0 + bw * 0.4, 0.92), _u(r, x0 + bw * 0.6, 0.92),
			_u(r, x0 + bw * 0.24, 0.12), _u(r, x0 + bw * 0.3, 0.5), _u(r, x0 + bw * 0.2, 0.12), _u(r, x0 + bw * 0.28, 0.08),
			_u(r, x0 + bw * 0.5, 0.14), _u(r, x0 + bw * 0.5, 0.5), _u(r, x0 + bw * 0.42, 0.14), _u(r, x0 + bw * 0.58, 0.14),
			_u(r, x0 + bw * 0.74, 0.12), _u(r, x0 + bw * 0.74, 0.3), _u(r, x0 + bw * 0.74, 0.3), _u(r, x0 + bw * 0.74, 0.5)]))
	S(ci, sg, 0.55, 1.0)
	for k in n:
		_gband(ci, r, k * bw + bw * 0.71, k * bw + bw * 0.77, 0.24, Pal.heat(0.7))


# ---------------------------------------------------------------- MED-47 / PT-34: drug cabinet (locker art)
# the clinic's drug cabinet: the glazed upper doors and the shelves of bottles behind them, the locked
# controlled-drug drawers under them (each its lock), the cross on its face
static func drug_cabinet(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.02, 0.94, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.06, 0.6), _u(r, 0.94, 0.6), _u(r, 0.5, 0.02), _u(r, 0.5, 0.6)]))
	for k in 3:
		var y: float = 0.2 + k * 0.14
		sg.append(_u(r, 0.1, y))
		sg.append(_u(r, 0.9, y))
		for j in 3:
			var x: float = 0.14 + j * 0.26
			sg.append_array(PackedVector2Array([_u(r, x, y), _u(r, x, y - 0.08), _u(r, x + 0.08, y), _u(r, x + 0.08, y - 0.08), _u(r, x, y - 0.08), _u(r, x + 0.08, y - 0.08)]))
	for k in 3:
		var y: float = 0.72 + k * 0.09
		sg.append(_u(r, 0.06, y))
		sg.append(_u(r, 0.94, y))
		sg.append(_u(r, 0.46, y - 0.04))
		sg.append(_u(r, 0.54, y - 0.04))
	S(ci, sg, 0.55, 1.0)
	var c := _u(r, 0.5, 0.66)
	E.Rc(ci, Rect2(c - Vector2(r.size.x * 0.1, r.size.y * 0.01), Vector2(r.size.x * 0.2, r.size.y * 0.02)), Pal.tint(Pal.FLUID, 0.85), 1.2)
	E.Rc(ci, Rect2(c - Vector2(r.size.y * 0.01, r.size.x * 0.1), Vector2(r.size.y * 0.02, r.size.x * 0.2)), Pal.tint(Pal.FLUID, 0.85), 1.2)


# ---------------------------------------------------------------- CV-138 (x2): rotor blade spares rack
# the rotor spares rack: the tall frame, the spare rotor blades stood in their cradles (each blade's
# tapered profile and its root fitting), the spare hub on the bottom shelf, the parts bins
static func rotor_blade_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.01, 0.98, 0.99))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.76), _u(r, 0.98, 0.76), _u(r, 0.02, 0.1), _u(r, 0.98, 0.1)]))
	for k in 4:
		var x: float = 0.1 + k * 0.17
		sg.append_array(PackedVector2Array([_u(r, x, 0.06), _u(r, x + 0.03, 0.06), _u(r, x, 0.06), _u(r, x - 0.01, 0.7), _u(r, x + 0.03, 0.06), _u(r, x + 0.08, 0.7),
			_u(r, x - 0.01, 0.7), _u(r, x + 0.08, 0.7), _u(r, x - 0.01, 0.7), _u(r, x, 0.74), _u(r, x + 0.08, 0.7), _u(r, x + 0.07, 0.74)]))
	for k in 3:
		var x0: float = 0.72 + k * 0.08
		_rs(sg, sub(r, x0, 0.8, x0 + 0.07, 0.9))
	S(ci, sg, 0.55, 1.1)
	O(ci, _u(r, 0.3, 0.88), ms * 0.14, 0.55, 1.4)
	D(ci, _u(r, 0.3, 0.88), maxf(1.4, ms * 0.04), 0.6)
	_gband(ci, r, 0.1, 0.7, 0.4, Pal.heat(0.55))


# ---------------------------------------------------------------- FL-116: spill response station
# the spill response station: the wheeled spill bin (its lid, the wheels), the absorbent boom coiled on
# its hook, the pads in their pocket, the shovel and the broom on the wall, the drain cover mat
static func spill_station(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.42, 0.5, 0.92))
	_rs(sg, sub(r, 0.02, 0.36, 0.52, 0.42))
	_rs(sg, sub(r, 0.56, 0.6, 0.76, 0.86))
	sg.append_array(PackedVector2Array([_u(r, 0.84, 0.04), _u(r, 0.84, 0.86), _u(r, 0.8, 0.86), _u(r, 0.88, 0.86), _u(r, 0.8, 0.86), _u(r, 0.8, 0.98), _u(r, 0.88, 0.86), _u(r, 0.88, 0.98),
		_u(r, 0.94, 0.04), _u(r, 0.94, 0.8), _u(r, 0.9, 0.8), _u(r, 0.98, 0.8), _u(r, 0.9, 0.8), _u(r, 0.92, 0.96), _u(r, 0.94, 0.8), _u(r, 0.94, 0.96), _u(r, 0.98, 0.8), _u(r, 0.96, 0.96),
		_u(r, 0.56, 0.98), _u(r, 0.78, 0.98)]))
	for k in 3:
		var y: float = 0.66 + k * 0.06
		sg.append(_u(r, 0.58, y))
		sg.append(_u(r, 0.74, y))
	S(ci, sg, 0.55, 1.1)
	for x in [0.12, 0.42]:
		O(ci, _u(r, x, 0.94), ms * 0.05, 0.55)
	O(ci, _u(r, 0.3, 0.18), ms * 0.14, 0.5, 2.0)
	O(ci, _u(r, 0.3, 0.2), ms * 0.1, 0.45, 2.0)
	_gband(ci, r, 0.03, 0.51, 0.39, Pal.heat(0.8))
	_gband(ci, r, 0.05, 0.49, 0.6, Pal.heat(0.6))


# ---------------------------------------------------------------- MED-47 (x3): anaesthesia machine
# the anaesthesia machine: the cart on its castors, the two vaporisers on the back bar, the flowmeter
# tubes and their floats, the bellows ventilator (its folds), the CO2 absorber canister, the gas
# cylinders at the back, the monitor screen on top
static func anaesthesia_machine(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.08, 0.3, 0.92, 0.82))
	_rs(sg, sub(r, 0.3, 0.02, 0.7, 0.24))
	_rs(sg, sub(r, 0.12, 0.36, 0.22, 0.56))
	_rs(sg, sub(r, 0.24, 0.36, 0.34, 0.56))
	_rs(sg, sub(r, 0.4, 0.36, 0.56, 0.62))
	_rs(sg, sub(r, 0.62, 0.36, 0.76, 0.6))
	sg.append_array(PackedVector2Array([_u(r, 0.44, 0.36), _u(r, 0.44, 0.62), _u(r, 0.48, 0.36), _u(r, 0.48, 0.62), _u(r, 0.52, 0.36), _u(r, 0.52, 0.62),
		_u(r, 0.5, 0.24), _u(r, 0.5, 0.3), _u(r, 0.12, 0.82), _u(r, 0.12, 0.92), _u(r, 0.88, 0.82), _u(r, 0.88, 0.92), _u(r, 0.12, 0.92), _u(r, 0.88, 0.92)]))
	for k in 4:
		var y: float = 0.4 + k * 0.05
		sg.append(_u(r, 0.62, y))
		sg.append(_u(r, 0.76, y))
	_rs(sg, sub(r, 0.8, 0.36, 0.9, 0.66))
	S(ci, sg, 0.55, 1.0)
	for x in [0.44, 0.48, 0.52]:
		D(ci, _u(r, x, 0.5 - (x - 0.48) * 2.0), maxf(1.0, ms * 0.03), 0.7)
	for x in [0.12, 0.88]:
		D(ci, _u(r, x, 0.95), maxf(1.0, ms * 0.04), 0.6)
	_pu(ci, r, [Vector2(0.34, 0.14), Vector2(0.42, 0.14), Vector2(0.46, 0.06), Vector2(0.5, 0.2), Vector2(0.54, 0.14), Vector2(0.66, 0.14)], 0.7, 1.0)
	_gband(ci, r, 0.13, 0.21, 0.42, Pal.tint(Pal.VOLT, 0.8))
	_gband(ci, r, 0.25, 0.33, 0.42, Pal.tint(Pal.FLUID, 0.8))
	_gband(ci, r, 0.81, 0.89, 0.5, Pal.tint(Pal.AIR, 0.8))


# ---------------------------------------------------------------- ARK-01: bedside patient monitor
# the bedside patient monitor: the screen and its bezel, the ECG and pleth traces running across it,
# the numbers' boxes beside them, the mounting arm, the patient leads hanging from its side
static func bedside_monitor(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.04, 0.94, 0.74))
	_rs(sg, sub(r, 0.12, 0.1, 0.88, 0.66))
	_rs(sg, sub(r, 0.66, 0.14, 0.84, 0.3))
	_rs(sg, sub(r, 0.66, 0.36, 0.84, 0.52))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.74), _u(r, 0.5, 0.98), _u(r, 0.36, 0.98), _u(r, 0.64, 0.98), _u(r, 0.94, 0.3), _u(r, 1.0, 0.6), _u(r, 0.94, 0.4), _u(r, 0.98, 0.7)]))
	S(ci, sg, 0.55, 1.0)
	_pu(ci, r, [Vector2(0.14, 0.26), Vector2(0.26, 0.26), Vector2(0.3, 0.14), Vector2(0.34, 0.36), Vector2(0.38, 0.26), Vector2(0.62, 0.26)], 0.7, 1.0)
	_pu(ci, r, [Vector2(0.14, 0.5), Vector2(0.24, 0.42), Vector2(0.34, 0.54), Vector2(0.44, 0.42), Vector2(0.54, 0.54), Vector2(0.62, 0.46)], 0.6, 1.0)
	_gband(ci, r, 0.68, 0.82, 0.22, Pal.tint(Pal.FLUID, 0.85))
	_gband(ci, r, 0.68, 0.82, 0.44, Pal.tint(Pal.AIR, 0.85))


# ---------------------------------------------------------------- MED-47 (x3): defibrillator
# the defibrillator: its case and handle, the screen with its trace, the two paddles in their holders
# on its sides and their coiled leads, the charge and shock buttons
static func defibrillator(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.18, 0.2, 0.82, 0.94))
	_rs(sg, sub(r, 0.26, 0.3, 0.6, 0.6))
	_rs(sg, sub(r, 0.02, 0.36, 0.16, 0.6))
	_rs(sg, sub(r, 0.84, 0.36, 0.98, 0.6))
	sg.append_array(PackedVector2Array([_u(r, 0.36, 0.2), _u(r, 0.4, 0.06), _u(r, 0.4, 0.06), _u(r, 0.6, 0.06), _u(r, 0.6, 0.06), _u(r, 0.64, 0.2),
		_u(r, 0.09, 0.6), _u(r, 0.12, 0.8), _u(r, 0.12, 0.8), _u(r, 0.18, 0.84), _u(r, 0.91, 0.6), _u(r, 0.88, 0.8), _u(r, 0.88, 0.8), _u(r, 0.82, 0.84)]))
	S(ci, sg, 0.55, 1.0)
	_pu(ci, r, [Vector2(0.28, 0.46), Vector2(0.36, 0.46), Vector2(0.4, 0.34), Vector2(0.44, 0.56), Vector2(0.48, 0.46), Vector2(0.58, 0.46)], 0.7, 1.0)
	_lamp(ci, _u(r, 0.7, 0.4), maxf(1.4, ms * 0.08), Pal.tint(Pal.AIR, 0.85))
	_lamp(ci, _u(r, 0.7, 0.62), maxf(1.6, ms * 0.1), Pal.heat(0.9))


# ---------------------------------------------------------------- NR-95 / ARK-01: dose rate probe
# the dose rate meter: the telescopic probe pole (its sections) out to the detector head, the cable
# back to the readout, the readout box and its meter (the scale's arc, the needle), the range switch
static func dose_probe_meter(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.36, 0.44, 0.92))
	_rs(sg, sub(r, 0.82, 0.08, 0.98, 0.34))
	sg.append_array(PackedVector2Array([_u(r, 0.44, 0.6), _u(r, 0.6, 0.48), _u(r, 0.6, 0.48), _u(r, 0.72, 0.36), _u(r, 0.72, 0.36), _u(r, 0.82, 0.28),
		_u(r, 0.6, 0.44), _u(r, 0.6, 0.52), _u(r, 0.72, 0.32), _u(r, 0.72, 0.4), _u(r, 0.86, 0.34), _u(r, 0.6, 0.98), _u(r, 0.6, 0.98), _u(r, 0.3, 0.92),
		_u(r, 0.24, 0.62), _u(r, 0.3, 0.48)]))
	S(ci, sg, 0.55, 1.1)
	A(ci, _u(r, 0.24, 0.66), ms * 0.22, PI * 1.15, PI * 1.85, 0.55, 1.0)
	O(ci, _u(r, 0.36, 0.82), ms * 0.05, 0.55)
	_gband(ci, r, 0.83, 0.97, 0.12, Pal.tint(Pal.VOLT, 0.8))
	_lamp(ci, _u(r, 0.12, 0.82), maxf(1.4, ms * 0.05), Pal.heat(0.85))


# ---------------------------------------------------------------- MED-47: ICU ventilator (MT-140's vent fan keeps its pump art)
# the ICU ventilator: the unit on its stand and castors, the touch screen and its pressure trace, the
# breathing circuit's two limbs looping out to the patient's Y-piece, the humidifier chamber on its
# heater, the flow sensor
static func icu_ventilator(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.06, 0.04, 0.5, 0.56))
	_rs(sg, sub(r, 0.1, 0.08, 0.46, 0.36))
	_rs(sg, sub(r, 0.36, 0.6, 0.5, 0.78))
	sg.append_array(PackedVector2Array([_u(r, 0.28, 0.56), _u(r, 0.28, 0.86), _u(r, 0.08, 0.86), _u(r, 0.48, 0.86), _u(r, 0.36, 0.66), _u(r, 0.5, 0.66)]))
	S(ci, sg, 0.55, 1.0)
	S(ci, PackedVector2Array([_u(r, 0.5, 0.42), _u(r, 0.76, 0.3), _u(r, 0.76, 0.3), _u(r, 0.94, 0.5), _u(r, 0.5, 0.5), _u(r, 0.74, 0.62), _u(r, 0.74, 0.62), _u(r, 0.94, 0.5),
		_u(r, 0.94, 0.5), _u(r, 1.0, 0.5)]), 0.45, 1.6)
	_pu(ci, r, [Vector2(0.12, 0.26), Vector2(0.18, 0.26), Vector2(0.22, 0.14), Vector2(0.3, 0.14), Vector2(0.34, 0.26), Vector2(0.44, 0.26)], 0.7, 1.0)
	for x in [0.08, 0.48]:
		D(ci, _u(r, x, 0.92), maxf(1.0, ms * 0.05), 0.6)
	_gband(ci, r, 0.37, 0.49, 0.72, Pal.tint(Pal.FLUID, 0.8))
	_gband(ci, r, 0.37, 0.49, 0.76, Pal.heat(0.7))


# ---------------------------------------------------------------- ARK-01 (x48): ebb-and-flow grow tray
# an ebb-and-flow grow tray on its stand: the tray, the seedlings in their rows, the LED bar on its
# hangers over them, the flood and drain fittings, the stand's legs
static func grow_tray(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.02, 0.6), _u(r, 0.98, 0.6), _u(r, 0.02, 0.72), _u(r, 0.98, 0.72), _u(r, 0.02, 0.6), _u(r, 0.02, 0.72), _u(r, 0.98, 0.6), _u(r, 0.98, 0.72),
		_u(r, 0.06, 0.72), _u(r, 0.06, 1.0), _u(r, 0.94, 0.72), _u(r, 0.94, 1.0), _u(r, 0.2, 0.06), _u(r, 0.2, 0.14), _u(r, 0.8, 0.06), _u(r, 0.8, 0.14),
		_u(r, 0.5, 0.72), _u(r, 0.5, 0.86)])
	var n := clampi(int(r.size.x / 14.0), 4, 12)
	for k in n:
		var x: float = 0.06 + (k + 0.5) * 0.88 / n
		sg.append_array(PackedVector2Array([_u(r, x, 0.6), _u(r, x, 0.4), _u(r, x, 0.46), _u(r, x - 0.025, 0.36), _u(r, x, 0.46), _u(r, x + 0.025, 0.36)]))
	S(ci, sg, 0.5, 1.0)
	E.Rc(ci, sub(r, 0.1, 0.14, 0.9, 0.2), Pal.tint(Pal.VOLT, 0.8), 1.0)
	_gband(ci, r, 0.03, 0.97, 0.66, Pal.tint(Pal.FLUID, 0.6))


# ---------------------------------------------------------------- BL-88 (x4): NFT hydroponic rack
# the nutrient-film rack: three sloped gutters stepped down its frame, the plants in their net pots
# along each, the LED strip over each tier, the reservoir and its pump at the foot, the return pipe
static func nft_rack(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.0), _u(r, 0.04, 1.0), _u(r, 0.96, 0.0), _u(r, 0.96, 1.0)])
	_rs(sg, sub(r, 0.08, 0.82, 0.6, 0.98))
	_rs(sg, sub(r, 0.62, 0.86, 0.74, 0.96))
	sg.append_array(PackedVector2Array([_u(r, 0.68, 0.86), _u(r, 0.68, 0.02), _u(r, 0.68, 0.02), _u(r, 0.12, 0.02)]))
	var pt := PackedVector2Array()
	for k in 3:
		var y: float = 0.22 + k * 0.24
		sg.append_array(PackedVector2Array([_u(r, 0.08, y), _u(r, 0.92, y + 0.04), _u(r, 0.08, y + 0.05), _u(r, 0.92, y + 0.09)]))
		for j in 6:
			var x: float = 0.14 + j * 0.13
			var yy: float = y + (x - 0.08) / 0.84 * 0.04
			pt.append_array(PackedVector2Array([_u(r, x, yy), _u(r, x - 0.03, yy - 0.08), _u(r, x, yy), _u(r, x + 0.03, yy - 0.08), _u(r, x, yy), _u(r, x, yy - 0.1)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, pt, 0.45, 1.0)
	for k in 3:
		E.Rc(ci, sub(r, 0.1, 0.06 + k * 0.24, 0.9, 0.08 + k * 0.24), Pal.tint(Pal.VOLT, 0.75), 1.0)
	_gband(ci, r, 0.09, 0.59, 0.88, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- BL-88 (x5): raised planter bed
# a raised planter bed: its timber sides (the boards), the soil line, the leafy plants growing in it
# (their stems and leaves), the drip line along it and its emitters
static func raised_planter(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.5, 0.98, 0.98))
	for y in [0.66, 0.82]:
		sg.append(_u(r, 0.02, y))
		sg.append(_u(r, 0.98, y))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.56), _u(r, 0.98, 0.56)]))
	var pl := PackedVector2Array()
	for k in 6:
		var x: float = 0.1 + k * 0.16
		pl.append_array(PackedVector2Array([_u(r, x, 0.56), _u(r, x, 0.16), _u(r, x, 0.3), _u(r, x - 0.06, 0.2), _u(r, x, 0.4), _u(r, x + 0.06, 0.28),
			_u(r, x - 0.06, 0.2), _u(r, x - 0.02, 0.32), _u(r, x + 0.06, 0.28), _u(r, x + 0.02, 0.4)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, pl, 0.45, 1.0)
	_gband(ci, r, 0.03, 0.97, 0.53, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- BL-88 (x3): vertical aeroponic tower
# the vertical aeroponic towers: the column(s) with their plant ports staggered up them and the plants in
# them, the LED strips standing either side, the base reservoir and its misting pump
static func aero_tower(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.38, 0.04, 0.62, 0.86))
	_rs(sg, sub(r, 0.16, 0.86, 0.84, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.5, 0.86), _u(r, 0.5, 0.04)]))
	var pl := PackedVector2Array()
	var n := clampi(int(r.size.y * 0.8 / 16.0), 5, 16)
	for k in n:
		var y: float = 0.08 + k * 0.76 / n
		var left: bool = k % 2 == 0
		var x0: float = 0.38 if left else 0.62
		var dx: float = -0.2 if left else 0.2
		pl.append_array(PackedVector2Array([_u(r, x0, y), _u(r, x0 + dx * 0.5, y - 0.015), _u(r, x0 + dx * 0.5, y - 0.015), _u(r, x0 + dx, y - 0.03), _u(r, x0 + dx * 0.5, y - 0.015), _u(r, x0 + dx * 0.8, y + 0.01)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, pl, 0.45, 1.0)
	for x in [0.06, 0.9]:
		E.Rc(ci, sub(r, x, 0.06, x + 0.04, 0.84), Pal.tint(Pal.VOLT, 0.75), 1.0)
	_gband(ci, r, 0.17, 0.83, 0.92, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- HB-86 (x6): culture racks
# the long culture racks: the tiers of shelving, the culture flasks standing along each (their necks and
# caps), the light tube over each tier, the uprights
static func culture_racks(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	var nu := clampi(int(r.size.x / 60.0), 3, 16)
	for k in nu + 1:
		var x: float = float(k) / nu
		sg.append(_u(r, x, 0.0))
		sg.append(_u(r, x, 1.0))
	var fl := PackedVector2Array()
	var nf := clampi(int(r.size.x / 14.0), 8, 60)
	for t in 3:
		var y: float = 0.32 + t * 0.32
		sg.append(_u(r, 0.0, y))
		sg.append(_u(r, 1.0, y))
		for k in nf:
			var x: float = (k + 0.5) / nf
			var w: float = 0.3 / nf
			fl.append_array(PackedVector2Array([_u(r, x - w, y), _u(r, x - w * 0.3, y - 0.14), _u(r, x + w, y), _u(r, x + w * 0.3, y - 0.14), _u(r, x - w * 0.3, y - 0.14), _u(r, x - w * 0.3, y - 0.2), _u(r, x + w * 0.3, y - 0.14), _u(r, x + w * 0.3, y - 0.2)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, fl, 0.4, 1.0)
	for t in 3:
		_gband(ci, r, 0.01, 0.99, 0.03 + t * 0.32, Pal.tint(Pal.AIR, 0.6))
		_gband(ci, r, 0.01, 0.99, 0.28 + t * 0.32, Pal.tint(Pal.FLUID, 0.55))


# ---------------------------------------------------------------- MY-48: framed artwork
# the saloon's artwork: the frame and its mount, the picture (a horizon, a sun, a few strokes of
# sea), the picture light over it
static func framed_artwork(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.14, 0.96, 0.96))
	_rs(sg, sub(r, 0.12, 0.22, 0.88, 0.88))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.6), _u(r, 0.88, 0.6), _u(r, 0.3, 0.06), _u(r, 0.7, 0.06), _u(r, 0.5, 0.06), _u(r, 0.5, 0.14)]))
	S(ci, sg, 0.55, 1.1)
	_pu(ci, r, [Vector2(0.14, 0.72), Vector2(0.3, 0.68), Vector2(0.46, 0.74), Vector2(0.62, 0.68), Vector2(0.86, 0.72)], 0.4, 1.0)
	_pu(ci, r, [Vector2(0.14, 0.8), Vector2(0.34, 0.76), Vector2(0.54, 0.82), Vector2(0.86, 0.78)], 0.35, 1.0)
	O(ci, _u(r, 0.66, 0.42), ms * 0.1, 0.55)
	_gband(ci, r, 0.58, 0.74, 0.42, Pal.heat(0.8))
	_gband(ci, r, 0.13, 0.87, 0.64, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- BL-88 (x2): fruit tree in its tub
# the fruit tree: the big tub and its rim, the trunk and the branches, the canopy's outline, the fruit
# hanging in it, the stake and its tie
static func fruit_tree(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array([_u(r, 0.22, 0.8), _u(r, 0.28, 0.98), _u(r, 0.78, 0.8), _u(r, 0.72, 0.98), _u(r, 0.28, 0.98), _u(r, 0.72, 0.98), _u(r, 0.2, 0.8), _u(r, 0.8, 0.8),
		_u(r, 0.48, 0.8), _u(r, 0.48, 0.4), _u(r, 0.52, 0.8), _u(r, 0.52, 0.4), _u(r, 0.5, 0.5), _u(r, 0.3, 0.3), _u(r, 0.5, 0.44), _u(r, 0.72, 0.26), _u(r, 0.5, 0.4), _u(r, 0.5, 0.16),
		_u(r, 0.62, 0.8), _u(r, 0.62, 0.36), _u(r, 0.52, 0.56), _u(r, 0.62, 0.56)])
	_arcs(sg, _u(r, 0.5, 0.3), r.size.x * 0.46, r.size.y * 0.28, 0.0, TAU, 12)
	S(ci, sg, 0.55, 1.1)
	for p in [Vector2(0.3, 0.38), Vector2(0.62, 0.2), Vector2(0.76, 0.36), Vector2(0.4, 0.22), Vector2(0.58, 0.42)]:
		D(ci, _u(r, p.x, p.y), maxf(1.4, ms * 0.04), 0.7)
		_lamp(ci, _u(r, p.x, p.y), maxf(1.6, ms * 0.04), Pal.heat(0.85))
	_gband(ci, r, 0.23, 0.77, 0.84, Pal.tint(Pal.FLUID, 0.6))


# ---------------------------------------------------------------- BL-88: soil growing bed
# the soil bed: its edge boards, the soil, the rows of root crops (their leaf rosettes over the soil and
# the roots' swell under it), the drip emitters along the row
static func soil_bed(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.5, 0.98, 0.98))
	sg.append_array(PackedVector2Array([_u(r, 0.02, 0.58), _u(r, 0.98, 0.58)]))
	var pl := PackedVector2Array()
	var n := clampi(int(r.size.x / 14.0), 6, 14)
	for k in n:
		var x: float = 0.04 + (k + 0.5) * 0.92 / n
		var w: float = 0.3 / n
		pl.append_array(PackedVector2Array([_u(r, x, 0.58), _u(r, x - w, 0.3), _u(r, x, 0.58), _u(r, x, 0.24), _u(r, x, 0.58), _u(r, x + w, 0.3),
			_u(r, x - w * 0.6, 0.62), _u(r, x, 0.8), _u(r, x + w * 0.6, 0.62), _u(r, x, 0.8)]))
	S(ci, sg, 0.55, 1.1)
	S(ci, pl, 0.45, 1.0)
	_gband(ci, r, 0.03, 0.97, 0.54, Pal.tint(Pal.FLUID, 0.7))


# ---------------------------------------------------------------- HB-86 (x3): seedling racks
# the long seedling racks: the tiers, the plug trays on each (their cell grid), the clear humidity domes
# over the trays, the mist line along each tier
static func seedling_racks(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	var nu := clampi(int(r.size.x / 60.0), 3, 16)
	for k in nu + 1:
		var x: float = float(k) / nu
		sg.append(_u(r, x, 0.0))
		sg.append(_u(r, x, 1.0))
	var dm := PackedVector2Array()
	for t in 3:
		var y: float = 0.32 + t * 0.32
		sg.append_array(PackedVector2Array([_u(r, 0.0, y), _u(r, 1.0, y), _u(r, 0.0, y - 0.06), _u(r, 1.0, y - 0.06)]))
		var nc := clampi(int(r.size.x / 8.0), 8, 100)
		for k in nc:
			var x: float = float(k) / nc
			sg.append(_u(r, x, y - 0.06))
			sg.append(_u(r, x, y))
		for k in nu:
			_arcs(dm, _u(r, (k + 0.5) / nu, y - 0.06), r.size.x * 0.45 / nu, r.size.y * 0.12, PI, TAU, 6)
	S(ci, sg, 0.5, 1.0)
	S(ci, dm, 0.3, 1.0)
	for t in 3:
		_gband(ci, r, 0.0, 1.0, 0.06 + t * 0.32, Pal.tint(Pal.AIR, 0.6))


# ---------------------------------------------------------------- ARK-01 and many: task chair
# a task chair: the five-star base and its castors, the gas lift, the seat, the backrest and its curve,
# the armrest
static func task_chair(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.1, 0.94), _u(r, 0.9, 0.94), _u(r, 0.5, 0.94), _u(r, 0.5, 0.62), _u(r, 0.46, 0.62), _u(r, 0.46, 0.8),
		_u(r, 0.12, 0.62), _u(r, 0.9, 0.62), _u(r, 0.12, 0.56), _u(r, 0.9, 0.56), _u(r, 0.12, 0.56), _u(r, 0.12, 0.62), _u(r, 0.9, 0.56), _u(r, 0.9, 0.62),
		_u(r, 0.16, 0.56), _u(r, 0.1, 0.06), _u(r, 0.26, 0.56), _u(r, 0.22, 0.08), _u(r, 0.1, 0.06), _u(r, 0.22, 0.08),
		_u(r, 0.3, 0.42), _u(r, 0.7, 0.42), _u(r, 0.6, 0.42), _u(r, 0.6, 0.56)])
	S(ci, sg, 0.55, 1.1)
	for x in [0.12, 0.88]:
		D(ci, _u(r, x, 0.97), maxf(1.0, r.size.x * 0.05), 0.6)


# ---------------------------------------------------------------- 4 small craft: co-pilot seat
# the co-pilot's seat on its rails: the seat pan and back, the headrest, the four-point harness, the
# fold-down chart table on its arm, the seat rails and their lock lever
static func copilot_seat(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.06, 0.96), _u(r, 0.94, 0.96), _u(r, 0.06, 0.92), _u(r, 0.94, 0.92), _u(r, 0.3, 0.92), _u(r, 0.3, 0.7), _u(r, 0.7, 0.92), _u(r, 0.7, 0.7),
		_u(r, 0.12, 0.7), _u(r, 0.86, 0.7), _u(r, 0.12, 0.62), _u(r, 0.86, 0.62), _u(r, 0.86, 0.62), _u(r, 0.86, 0.7),
		_u(r, 0.12, 0.7), _u(r, 0.06, 0.16), _u(r, 0.24, 0.62), _u(r, 0.2, 0.16), _u(r, 0.06, 0.16), _u(r, 0.2, 0.16),
		_u(r, 0.08, 0.04), _u(r, 0.22, 0.04), _u(r, 0.08, 0.04), _u(r, 0.08, 0.14), _u(r, 0.22, 0.04), _u(r, 0.22, 0.14),
		_u(r, 0.86, 0.6), _u(r, 0.98, 0.36), _u(r, 0.98, 0.36), _u(r, 0.7, 0.32), _u(r, 0.6, 0.92), _u(r, 0.64, 0.98)])
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.14, 0.2), _u(r, 0.5, 0.6), _u(r, 0.2, 0.2), _u(r, 0.56, 0.6)]), 0.4, 1.4)
	_gband(ci, r, 0.32, 0.6, 0.6, Pal.tint(Pal.AIR, 0.75))


# ---------------------------------------------------------------- small craft: pilot seat (side stick)
# the small craft's pilot seat: the bucket seat and its high back, the five-point harness, the side
# stick on the armrest, the rudder pedals ahead of it, the seat's mounting frame
static func pilot_bucket(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.2, 0.92), _u(r, 0.7, 0.92), _u(r, 0.3, 0.92), _u(r, 0.3, 0.72), _u(r, 0.6, 0.92), _u(r, 0.6, 0.72),
		_u(r, 0.16, 0.72), _u(r, 0.7, 0.72), _u(r, 0.16, 0.64), _u(r, 0.7, 0.64), _u(r, 0.7, 0.64), _u(r, 0.76, 0.6),
		_u(r, 0.16, 0.72), _u(r, 0.08, 0.06), _u(r, 0.28, 0.64), _u(r, 0.22, 0.12), _u(r, 0.08, 0.06), _u(r, 0.22, 0.12),
		_u(r, 0.64, 0.58), _u(r, 0.68, 0.36), _u(r, 0.62, 0.36), _u(r, 0.72, 0.36), _u(r, 0.62, 0.58), _u(r, 0.76, 0.58),
		_u(r, 0.84, 0.98), _u(r, 0.96, 0.8), _u(r, 0.84, 0.98), _u(r, 0.98, 0.98)])
	S(ci, sg, 0.55, 1.1)
	S(ci, PackedVector2Array([_u(r, 0.14, 0.18), _u(r, 0.5, 0.64), _u(r, 0.22, 0.18), _u(r, 0.56, 0.64), _u(r, 0.5, 0.64), _u(r, 0.4, 0.92)]), 0.4, 1.4)
	_lamp(ci, _u(r, 0.68, 0.34), maxf(1.2, r.size.x * 0.05), Pal.heat(0.85))


# ---------------------------------------------------------------- 18 ships: bridge chair
# the bridge watch chair: the pedestal and its swivel, the footrest ring, the seat and back and
# headrest, the armrest consoles (the joystick on one, the keypad on the other)
static func bridge_chair(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.2, 0.98), _u(r, 0.8, 0.98), _u(r, 0.46, 0.98), _u(r, 0.46, 0.66), _u(r, 0.56, 0.98), _u(r, 0.56, 0.66), _u(r, 0.28, 0.82), _u(r, 0.74, 0.82),
		_u(r, 0.14, 0.66), _u(r, 0.86, 0.66), _u(r, 0.14, 0.58), _u(r, 0.86, 0.58), _u(r, 0.86, 0.58), _u(r, 0.86, 0.66),
		_u(r, 0.14, 0.66), _u(r, 0.1, 0.14), _u(r, 0.26, 0.58), _u(r, 0.22, 0.14), _u(r, 0.1, 0.14), _u(r, 0.22, 0.14),
		_u(r, 0.1, 0.04), _u(r, 0.24, 0.04), _u(r, 0.1, 0.04), _u(r, 0.1, 0.12), _u(r, 0.24, 0.04), _u(r, 0.24, 0.12),
		_u(r, 0.76, 0.32), _u(r, 0.8, 0.22)])
	_rs(sg, sub(r, 0.6, 0.4, 0.94, 0.48))
	S(ci, sg, 0.55, 1.1)
	D(ci, _u(r, 0.8, 0.2), maxf(1.2, r.size.x * 0.05), 0.65)
	E.Rc(ci, sub(r, 0.66, 0.41, 0.74, 0.47), Pal.tint(Pal.FLUID, 0.8), 1.0)
	_gband(ci, r, 0.15, 0.85, 0.62, Pal.tint(Pal.AIR, 0.6))


# ---------------------------------------------------------------- PS-12 (x20): passenger seat
# a passenger seat: the seat leg and its track fitting, the cushion, the reclined back and headrest,
# the tray table folded on the back, the armrest, the life vest pouch under the seat
static func passenger_seat(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.08, 0.98), _u(r, 0.92, 0.98), _u(r, 0.3, 0.98), _u(r, 0.34, 0.7), _u(r, 0.72, 0.98), _u(r, 0.68, 0.7),
		_u(r, 0.18, 0.7), _u(r, 0.84, 0.7), _u(r, 0.18, 0.6), _u(r, 0.84, 0.6), _u(r, 0.84, 0.6), _u(r, 0.84, 0.7),
		_u(r, 0.18, 0.7), _u(r, 0.04, 0.08), _u(r, 0.3, 0.6), _u(r, 0.18, 0.08), _u(r, 0.04, 0.08), _u(r, 0.18, 0.08),
		_u(r, 0.0, 0.3), _u(r, 0.04, 0.24), _u(r, 0.0, 0.3), _u(r, 0.06, 0.5), _u(r, 0.3, 0.46), _u(r, 0.8, 0.46), _u(r, 0.8, 0.46), _u(r, 0.8, 0.56)])
	_rs(sg, sub(r, 0.42, 0.76, 0.6, 0.86))
	S(ci, sg, 0.55, 1.1)
	_gband(ci, r, 0.43, 0.59, 0.81, Pal.heat(0.75))
	_gband(ci, r, 0.06, 0.16, 0.1, Pal.tint(Pal.AIR, 0.7))


# ---------------------------------------------------------------- ARK-01 (x116): wall shelf
# a wall shelf (or a short shelving unit where tall): the shelf boards and their front lips on their
# brackets, and on each a lidded box (its label), a storage tub with its lid, two bottles
static func wall_shelf(ci: CanvasItem, r: Rect2) -> void:
	var n := clampi(int(r.size.y / 28.0), 1, 4)
	var sg := PackedVector2Array([_u(r, 0.02, 0.0), _u(r, 0.98, 0.0)])
	for k in n:
		var y: float = float(k + 1) / n - 0.05
		var h: float = 1.0 / n
		sg.append_array(PackedVector2Array([_u(r, 0.02, y), _u(r, 0.98, y), _u(r, 0.02, y + h * 0.06), _u(r, 0.98, y + h * 0.06),
			_u(r, 0.1, y + h * 0.06), _u(r, 0.06, y + h * 0.18), _u(r, 0.9, y + h * 0.06), _u(r, 0.94, y + h * 0.18)]))
		_rs(sg, sub(r, 0.06, y - h * 0.6, 0.32, y))
		sg.append_array(PackedVector2Array([_u(r, 0.06, y - h * 0.48), _u(r, 0.32, y - h * 0.48), _u(r, 0.15, y - h * 0.3), _u(r, 0.23, y - h * 0.3)]))
		_rs(sg, sub(r, 0.36, y - h * 0.4, 0.6, y))
		sg.append_array(PackedVector2Array([_u(r, 0.34, y - h * 0.4), _u(r, 0.62, y - h * 0.4)]))
		for j in 2:
			var x: float = 0.68 + j * 0.14
			_rs(sg, sub(r, x, y - h * 0.5, x + 0.06, y))
			sg.append(_u(r, x + 0.02, y - h * 0.5))
			sg.append(_u(r, x + 0.02, y - h * 0.58))
	S(ci, sg, 0.5, 1.0)


# ---------------------------------------------------------------- DC-84 (x2): spare drive shelf
# the spare drive shelf: the rack, the anti-static bins on each shelf with the drive caddies standing in
# them (their handles), the earthing strap, the blue of the static-safe bins
static func drive_shelf(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.02, 0.96, 0.98))
	for k in 3:
		var y: float = 0.32 + k * 0.32
		sg.append(_u(r, 0.04, y))
		sg.append(_u(r, 0.96, y))
		for j in 8:
			var x: float = 0.1 + j * 0.1
			sg.append(_u(r, x, y))
			sg.append(_u(r, x, y - 0.18))
		sg.append(_u(r, 0.08, y - 0.2))
		sg.append(_u(r, 0.92, y - 0.2))
	sg.append_array(PackedVector2Array([_u(r, 0.96, 0.5), _u(r, 1.0, 0.6), _u(r, 1.0, 0.6), _u(r, 1.0, 0.98)]))
	S(ci, sg, 0.5, 1.0)
	for k in 3:
		_gband(ci, r, 0.07, 0.93, 0.3 + k * 0.32, Pal.tint(Pal.VOLT, 0.7))


# ---------------------------------------------------------------- DR-150 (x3): core box rack
# the core store: the rack, the core boxes on each shelf (their dividers) with the core lying in its
# lengths, the box lids leaned beside them
static func core_box_rack(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.02, 0.98, 0.98))
	var cr := PackedVector2Array()
	for k in 4:
		var y: float = 0.24 + k * 0.24
		sg.append(_u(r, 0.02, y))
		sg.append(_u(r, 0.98, y))
		_rs(sg, sub(r, 0.06, y - 0.14, 0.86, y))
		for j in range(1, 3):
			sg.append(_u(r, 0.06, y - j * 0.047))
			sg.append(_u(r, 0.86, y - j * 0.047))
		for j in 3:
			var yy: float = y - 0.023 - j * 0.047
			for s in 3:
				var x0: float = 0.08 + s * 0.26
				cr.append(_u(r, x0, yy))
				cr.append(_u(r, x0 + 0.22, yy))
		sg.append(_u(r, 0.9, y))
		sg.append(_u(r, 0.96, y - 0.18))
	S(ci, sg, 0.5, 1.0)
	S(ci, cr, 0.55, 2.0)


# ---------------------------------------------------------------- DR-150: sack pallet
# the mud chemical sacks on their pallet: the pallet's deck boards and blocks, the sacks stacked
# brick-wise (each its rounded pillow), the shrink wrap round the stack
static func sack_pallet(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array([_u(r, 0.04, 0.88), _u(r, 0.96, 0.88), _u(r, 0.04, 0.98), _u(r, 0.96, 0.98)])
	for x in [0.06, 0.46, 0.86]:
		_rs(sg, sub(r, x, 0.88, x + 0.08, 0.98))
	for k in 5:
		var y0: float = 0.88 - (k + 1) * 0.16
		var off: float = 0.0 if k % 2 == 0 else 0.15
		for j in 3:
			var x0: float = 0.06 + off + j * 0.3
			if x0 + 0.28 > 0.95:
				continue
			sg.append_array(PackedVector2Array([_u(r, x0 + 0.02, y0), _u(r, x0 + 0.26, y0), _u(r, x0 + 0.02, y0 + 0.15), _u(r, x0 + 0.26, y0 + 0.15),
				_u(r, x0 + 0.02, y0), _u(r, x0, y0 + 0.075), _u(r, x0, y0 + 0.075), _u(r, x0 + 0.02, y0 + 0.15), _u(r, x0 + 0.26, y0), _u(r, x0 + 0.28, y0 + 0.075), _u(r, x0 + 0.28, y0 + 0.075), _u(r, x0 + 0.26, y0 + 0.15)]))
	S(ci, sg, 0.5, 1.0)
	S(ci, PackedVector2Array([_u(r, 0.03, 0.06), _u(r, 0.03, 0.88), _u(r, 0.97, 0.06), _u(r, 0.97, 0.88), _u(r, 0.03, 0.06), _u(r, 0.97, 0.06)]), 0.25, 1.0)
	_gband(ci, r, 0.08, 0.32, 0.8, Pal.heat(0.55))


# ---------------------------------------------------------------- DR-150 (x2): rig spares rack
# the heavy rig spares rack: its two shelves, the tricone bits on the top shelf (the cones and the pin),
# the subs and crossovers lying on the next, the valve seats and rubbers in the bins at the foot
static func rig_spares_rack(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.02, 0.02, 0.98, 0.98))
	for y in [0.36, 0.66]:
		sg.append(_u(r, 0.02, y))
		sg.append(_u(r, 0.98, y))
	for k in 3:
		var x: float = 0.18 + k * 0.3
		sg.append_array(PackedVector2Array([_u(r, x - 0.04, 0.06), _u(r, x + 0.04, 0.06), _u(r, x - 0.04, 0.06), _u(r, x - 0.04, 0.16), _u(r, x + 0.04, 0.06), _u(r, x + 0.04, 0.16),
			_u(r, x - 0.1, 0.18), _u(r, x + 0.1, 0.18), _u(r, x - 0.1, 0.18), _u(r, x - 0.06, 0.34), _u(r, x + 0.1, 0.18), _u(r, x + 0.06, 0.34), _u(r, x, 0.18), _u(r, x, 0.34)]))
	for k in 3:
		var y: float = 0.44 + k * 0.07
		_rs(sg, sub(r, 0.08, y, 0.6 + k * 0.1, y + 0.05))
	for k in 4:
		var x0: float = 0.06 + k * 0.23
		_rs(sg, sub(r, x0, 0.76, x0 + 0.2, 0.94))
	S(ci, sg, 0.5, 1.0)
	for k in 4:
		O(ci, _u(r, 0.16 + k * 0.23, 0.82), ms * 0.04, 0.5)


# ---------------------------------------------------------------- ARK-01 and 6 ships: bin parts rack
# the parts rack of small bins: the frame and shelves, the louvred bins on them (each its label holder),
# the boxed spares on the top shelf
static func bin_parts_rack(ci: CanvasItem, r: Rect2) -> void:
	var sg := PackedVector2Array()
	_rs(sg, sub(r, 0.04, 0.02, 0.96, 0.98))
	var rows := clampi(int(r.size.y / 26.0), 3, 8)
	var cols := clampi(int(r.size.x / 22.0), 2, 8)
	for j in rows:
		var y: float = 0.02 + float(j + 1) / rows * 0.96
		sg.append(_u(r, 0.04, y))
		sg.append(_u(r, 0.96, y))
		if j == 0:
			_rs(sg, sub(r, 0.1, y - 0.8 / rows, 0.46, y))
			_rs(sg, sub(r, 0.54, y - 0.6 / rows, 0.9, y))
			continue
		for i in cols:
			var x0: float = 0.06 + i * 0.88 / cols
			var x1: float = x0 + 0.88 / cols * 0.86
			var yt: float = y - 0.7 / rows
			sg.append_array(PackedVector2Array([_u(r, x0, y), _u(r, x0, yt + 0.3 / rows), _u(r, x0, yt + 0.3 / rows), _u(r, x1, yt), _u(r, x1, yt), _u(r, x1, y),
				_u(r, x0 + 0.02, y - 0.25 / rows), _u(r, x1 - 0.02, y - 0.25 / rows)]))
	S(ci, sg, 0.5, 1.0)


# ---------------------------------------------------------------- HB-86: UV steriliser chamber
# the UV steriliser: the lying chamber, the bank of UV lamps across it seen through its sight glass, the
# quartz sleeves' end caps, the ballast box and its cable, the inlet and outlet, the intensity sensor
static func uv_chamber(ci: CanvasItem, r: Rect2) -> void:
	var ms := minf(r.size.x, r.size.y)
	var sg := PackedVector2Array()
	_hves(sg, sub(r, 0.04, 0.16, 0.74, 0.84), r.size.y * 0.16, 4)
	_rs(sg, sub(r, 0.2, 0.26, 0.6, 0.74))
	_rs(sg, sub(r, 0.8, 0.1, 0.98, 0.7))
	sg.append_array(PackedVector2Array([_u(r, 0.12, 0.84), _u(r, 0.12, 0.98), _u(r, 0.66, 0.16), _u(r, 0.66, 0.02), _u(r, 0.74, 0.4), _u(r, 0.8, 0.4),
		_u(r, 0.64, 0.84), _u(r, 0.7, 0.96), _u(r, 0.14, 0.84), _u(r, 0.08, 0.96), _u(r, 0.4, 0.16), _u(r, 0.4, 0.08)]))
	for k in 4:
		var y: float = 0.32 + k * 0.12
		sg.append(_u(r, 0.12, y))
		sg.append(_u(r, 0.16, y))
	S(ci, sg, 0.55, 1.1)
	for k in 4:
		E.Rc(ci, sub(r, 0.16, 0.31 + k * 0.12, 0.66, 0.33 + k * 0.12), Pal.tint(Pal.VOLT, 0.85), 1.0)
	_lamp(ci, _u(r, 0.89, 0.2), maxf(1.6, ms * 0.04), Pal.tint(Pal.FLUID, 0.85))
	D(ci, _u(r, 0.4, 0.08), maxf(1.4, ms * 0.03), 0.6)


# ================================================================ 2026-11-13: the liquid tanks' liquid
# (user: "我总感觉现在水箱还没以前好看呢" - the redrawn tanks had become empty frames: their art names no
# longer matched tank_fill_fx.gd's, so the live liquid had stopped, and they painted none of their own)
# Each liquid tank's inside as [rect in the art's pixels, corner round, liquid key or colour, painted
# level]: tank_fill_fx.gd fills it live where the ship's fluid system holds a volume for the piece;
# elsewhere (the catalog, pieces with no volume) the drawing paints its still liquid there itself.
const LIQ_KEYS := ["water_dispenser", "eccs_tank", "sectional_tank", "ballast_tank", "bio_waste_tank", "fish_tank",
	"nutrient_mixer_tank", "wetland_pond", "water_recovery", "mud_agitator_tank", "hyd_reservoir", "coolant_bottle",
	"fresh_water_tank", "coolant_tank", "expansion_tank", "lube_box_tank", "ref_receiver", "n2o_tank", "piston_accumulator"]


static func liquid_rect(art: String, w: float, h: float) -> Array:
	var r := Rect2(0, 0, w, h)
	match art:
		"water_dispenser": return [sub(r, 0.14, 0.02, 0.86, 0.24), 0.1, Pal.AIR.lerp(Color.WHITE, 0.35), 0.88]
		"eccs_tank": return [sub(r, 0.07, 0.2, 0.39, 0.78), 0.2, Pal.VOLT.lerp(Pal.AIR, 0.45), 0.82]
		"sectional_tank": return [sub(r, 0.06, 0.1, 0.86, 0.94), 0.02, Pal.AIR, 0.72]
		"ballast_tank": return [sub(r, 0.01, 0.06, 0.99, 0.94), 0.0, Pal.AIR.lerp(Pal.FLUID, 0.55), 0.62]
		"bio_waste_tank": return [sub(r, 0.14, 0.2, 0.78, 0.88), 0.12, Pal.tint(Pal.FLUID, 1.0), 0.5]
		"fish_tank": return [sub(r, 0.06, 0.16, 0.8, 0.94), 0.0, Pal.FLUID.lerp(Pal.AIR, 0.35), 0.86]
		"nutrient_mixer_tank": return [sub(r, 0.12, 0.2, 0.88, 0.66), 0.0, "nutrient", 0.86]
		"wetland_pond": return [sub(r, 0.08, 0.3, 0.92, 0.74), 0.0, Pal.FLUID, 0.7]
		"water_recovery": return [sub(r, 0.1, 0.1, 0.34, 0.62), 0.2, Pal.FLUID.lerp(Pal.AIR, 0.6), 0.55]
		"mud_agitator_tank": return [sub(r, 0.04, 0.24, 0.96, 0.96), 0.0, Color(0.86, 0.68, 0.5), 0.74]
		"hyd_reservoir": return [sub(r, 0.04, 0.24, 0.96, 0.9), 0.02, Color(0.72, 0.3, 0.22), 0.6]
		"coolant_bottle": return [sub(r, 0.1, 0.22, 0.78, 0.94), 0.06, Pal.FLUID.lerp(Pal.AIR, 0.5), 0.6]
		"fresh_water_tank":
			if w > h * 1.3:
				return [sub(r, 0.1, 0.13, 0.78, 0.79), 0.3, "water", 0.62]
			return [sub(r, 0.13, 0.12, 0.73, 0.8), 0.15, "water", 0.66]
		"coolant_tank":
			if w > h * 1.3:
				return [sub(r, 0.1, 0.13, 0.78, 0.77), 0.3, "glycol", 0.56]
			return [sub(r, 0.11, 0.1, 0.71, 0.82), 0.15, "glycol", 0.52]
		"expansion_tank":
			var q := _fitr(r, 0.56)
			return [sub(q, 0.13, 0.32, 0.87, 0.78), 0.25, "glycol", 1.0]
		"lube_box_tank": return [sub(r, 0.08, 0.1, 0.78, 0.9), 0.0, Color(0.8, 0.6, 0.32), 0.48]
		"ref_receiver": return [sub(r, 0.16, 0.1, 0.74, 0.86), 0.25, Pal.AIR.lerp(Pal.VOLT, 0.5), 0.62]
		"n2o_tank": return [sub(r, 0.16, 0.1, 0.8, 0.78), 0.25, "solvent", 0.6]
		"piston_accumulator": return [sub(r, 0.22, 0.47, 0.78, 0.9), 0.0, Color(0.72, 0.3, 0.22), 1.0]
	return []


# which picture tank_fill_fx.gd should treat a piece as (alt: its art here, raw: its own art): a split arm
# that hands the piece back to its old picture keeps that picture's liquid; a liquid tank here keeps its own
static func liquid_art(alt: String, raw: String) -> String:
	if alt == "lube_box_tank" and raw != "gastank":
		return raw
	if alt == "water_treat_skid" or alt == "ro_rack":
		return ""
	return alt if LIQ_KEYS.has(alt) else ""


# a coloured fill (through the batch while recording, straight to the canvas otherwise)
static func _fillc(ci: CanvasItem, q: PackedVector2Array, col: Color) -> void:
	if E._rec:
		E._tri_fan(q, col)
	else:
		ci.draw_colored_polygon(q, col)


# a liquid tank's shell thickness (its inner wall line) and, unless the live liquid is drawing it, its
# still liquid: the dark body in the liquid's own colour under its rippled, lit surface
static func _liquid(ci: CanvasItem, p, art: String, r: Rect2) -> void:
	var lr := liquid_rect(art, r.size.x, r.size.y)
	if lr.is_empty():
		return
	var q: Rect2 = lr[0]
	q.position += r.position
	if q.size.x * q.size.y > 1200.0:
		R(ci, q.grow(-1.5), 0.3)
	if p != null and p.has_meta("liquid_live"):
		return
	if art == "ballast_tank":
		var n := clampi(int(r.size.x / (r.size.y * 0.9)), 2, 8)
		var cw: float = q.size.x / n
		for k in n:
			_liquid_body(ci, Rect2(q.position + Vector2(k * cw + 2.0, 0.0), Vector2(cw - 4.0, q.size.y)), [0.72, 0.38, 0.86, 0.55, 0.3, 0.64, 0.8, 0.45][k], _liq_col(lr[2]), 5)
		return
	_liquid_body(ci, q, float(lr[3]), _liq_col(lr[2]))


# the hue a still liquid is painted in: the liquid's own colour where it has one, the theme's where it is
# clear (water and refrigerant lean cyan, nitrous violet, nutrient green)
static func _liq_col(k) -> Color:
	if k is Color:
		return k
	match str(k):
		"water": return Pal.AIR
		"refrigerant": return Pal.AIR.lerp(Color.WHITE, 0.3)
		"solvent": return Pal.VOLT
		"nutrient": return Pal.FLUID
	return LC.of(str(k))


# a still liquid in a rect: the dark body in its hue, the lit band just under the surface, the ripple
static func _liquid_body(ci: CanvasItem, q: Rect2, lv: float, col: Color, max_n: int = 10) -> void:
	var x0: float = q.position.x + 1.5
	var x1: float = q.end.x - 1.5
	var yb: float = q.end.y - 1.5
	var y: float = lerpf(yb, q.position.y + 1.5, lv)
	if yb - y < 1.0:
		return
	var n := clampi(int((x1 - x0) / 14.0), 3, max_n)
	var amp: float = minf(1.4, (yb - y) * 0.1)
	var top := PackedVector2Array()
	for k in n + 1:
		top.append(Vector2(lerpf(x0, x1, float(k) / n), y + (amp if k % 2 == 0 else -amp)))
	var bd := PackedVector2Array([Vector2((x0 + x1) * 0.5, (y + yb) * 0.5)])
	bd.append_array(top)
	bd.append_array(PackedVector2Array([Vector2(x1, yb), Vector2(x0, yb), top[0]]))
	_fillc(ci, bd, Color(col.r * 0.42, col.g * 0.42, col.b * 0.42, 0.92))
	var hb: float = minf(4.0, (yb - y) * 0.18)
	if hb > 1.0 and x1 - x0 > 40.0:
		_fillc(ci, PackedVector2Array([Vector2(x0, y + amp), Vector2(x1, y + amp), Vector2(x1, y + amp + hb), Vector2(x0, y + amp + hb)]), Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, 0.5))
	P(ci, top, 0.66, 1.2)
