extends RefCounted
# Each ship's signature machines (2026-10-20 rework, player: "parts you can name, drawn
# the way the real thing is built"): a drilling ship's top drive and triplex mud pumps,
# a cryoplant's turboexpanders, a telescope's wavefront sensor... Picked by the piece's
# kind (name_key), so every ship carrying one shows it; recorded once and replayed
# like the shared art (art_equip.gd, whose primitives these use).

const E = preload("res://scripts/art_equip.gd")
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
	"p_pharmacy": "pharmacy",
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
	# DR-150 Derrick
	"p_dr_top_drive": "top_drive", "p_dr_drawworks": "drawworks", "p_dr_crown_block": "crown_block",
	"p_dr_travel_block": "travel_block", "p_dr_rotary": "rotary_table", "p_dr_stand": "drillpipe",
	"p_dr_bha": "bha", "p_dr_mud_pump": "mud_pump", "p_dr_shaker": "shaker", "p_dr_desander": "hydrocyclone",
	"p_dr_degasser": "degasser", "p_dr_centrifuge": "decanter", "p_dr_mud_gas_sep": "gas_buster",
	"p_dr_agitator": "agitator", "p_dr_roughneck": "roughneck", "p_dr_pipe_rack": "pipe_rack",
	"p_dr_casing": "pipe_bundle", "p_dr_bop": "bop", "p_dr_lathe": "lathe", "p_dr_mill": "mill",
	"p_dr_standpipe": "standpipe", "p_dr_choke": "choke_manifold", "p_dr_bop_accumulator": "koomey",
	# HG-170 Gas Sea (and FX-70's helium compressors)
	"p_hg_intake_comp": "axial_comp",
	"p_fx_he_compressor": "screw_comp",
	"p_hg_sample_comp": "screw_comp",
	"p_hg_cryocooler": "cold_box_h2",
	"p_hg_ortho_para": "ortho_para",
	"p_hg_precooler": "precooler",
	"p_hg_separator": "psa",
	"p_hg_chromatograph": "gc",
	"p_hg_mass_spec": "mass_spec",
	"p_hg_turboexpander": "turboexpander",
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
	"p_ob_wheel": "reaction_wheel",
	"p_star_tracker": "star_tracker",
	# DC-84 Deep Mind
	"p_dc_rack": "immersion_rack",
	"p_dc_cdu": "cdu",
	"p_dc_dry_cooler": "dry_cooler",
	"p_dc_array": "storage_array",
	"p_dc_core_switch": "switch_chassis",
	"p_dc_drive": "drive_carrier",
	# ARK-01 Voyager: the power core, the rings
	"p_reactor_core": "pwr_core",
	"p_ark_secondary_reactor": "pwr_core",
	"p_core_pump": "rcp",
	"p_ark_pressurizer": "pressurizer",
	"p_ark_crd": "crdm",
	"p_ark_turbine": "steam_turbine",
	"p_ark_condenser": "condenser",
	"p_ark_despin": "despin_brake",
	"p_ark_slip_ring": "slip_ring",
	"p_ark_rotary_seal": "rotary_seal",
	"p_ark_spoke_lift": "spoke_lift",
	"p_lift_car": "spoke_lift",
	"p_ark_vehicle": "work_vehicle",
	"p_ark_food_module": "food_module",
	"p_cross_manifold": "manifold",
	# ST-40, EV-55, BL-88, LC-140
	"p_st_turbopump": "turbopump",
	"p_ev_coronagraph": "coronagraph",
	"p_ev_particle": "particle_det",
	"p_ev_magnetometer": "magnetometer",
	"p_bl_electrolyser": "bl_electrolyser",
	"p_bl_compost": "composter",
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
	"p_hyd_pump": "hpu",
	"p_spray": "spray_bar",
	"p_microscope": "microscope",
	"p_co2": "co2_scrubber",
	"p_uv_steriliser": "uv_steriliser",
	"p_humidity": "humidifier",
	"p_ref_plant": "ref_plant",
	"p_evaporator": "evaporator",
	"p_forklift": "forklift",
	"p_safe_box": "safe_deposit",
	"p_armory": "gun_rack",
	"p_biometric": "biometric",
	"p_separator": "separator_3ph",
	"p_level_radar": "level_radar",
	"p_flow_meter": "coriolis",
	"p_manifold": "manifold",
	"p_optics": "ir_camera",
	"p_inertial_unit": "imu",
	"p_align_bench": "iso_table",
	"p_furnace_core": "arc_furnace",
	"p_ingot_rack": "ingot_rack",
	"p_sorter": "eddy_sorter",
	"p_mag_sep": "mag_separator",
	"p_scrubber": "scrubber",
	"p_spectro": "spectrograph",
	"p_heat_pump": "chiller",
	"p_car": "car",
	"p_deck_tractor": "deck_tractor",
	"p_apu": "apu",
	"p_escape_pod": "escape_pod",
	# the odd-shaped ships
	"p_crane_trolley": "hold_crane",
	"p_ntr_core": "ntr_core",
	"p_control_drum": "control_drum",
	"p_rad_shield": "shadow_shield",
	"p_flywheel": "flywheel_rotor",
	"p_launch_cradle": "launch_cradle",
	"p_tether_damper": "tether_damper",
	"p_hyd_clamp": "hyd_clamp",
	"p_piano": "piano",
	"p_wine_wall": "wine_rack",
	"p_bar": "bar",
	# the early ships
	"p_reactor": "pwr_core",
	"p_crusher": "crusher",
	"p_screener": "shaker",
	"p_reliq": "cold_box_h2",
	"p_n2gen": "psa",
	"p_o2_gen": "psa",
	"p_bog": "screw_comp",
	"p_valve_block": "manifold",
}

const DRAWN := ["top_drive", "drawworks", "crown_block", "travel_block", "rotary_table", "drillpipe", "bha", "mud_pump",
	"shaker", "hydrocyclone", "degasser", "decanter", "gas_buster", "agitator", "roughneck", "pipe_rack", "pipe_bundle",
	"bop", "lathe", "mill", "standpipe", "choke_manifold", "koomey", "axial_comp", "screw_comp", "cold_box_h2", "ortho_para", "precooler", "psa", "gc", "mass_spec", "turboexpander", "dr_stage", "qpu", "pulse_tube", "ghs", "iso_table", "instrument_rack", "turbo_pump", "scroll_pump", "hexapod", "aft_optics", "fsm", "ir_camera", "spectrograph", "fgs", "wfs", "recoater", "reaction_wheel", "star_tracker", "immersion_rack", "cdu", "dry_cooler", "storage_array", "switch_chassis", "drive_carrier", "pwr_core", "rcp", "pressurizer", "crdm", "steam_turbine", "condenser", "despin_brake", "slip_ring", "rotary_seal", "spoke_lift", "work_vehicle", "food_module", "turbopump", "coronagraph", "particle_det", "magnetometer", "electrolyser", "composter", "beehive", "forklift", "hold_crane", "xray_scanner", "mail_sorter", "tow_winch", "spray_bar", "microscope", "co2_scrubber", "uv_steriliser", "humidifier", "ref_plant", "evaporator", "safe_deposit", "gun_rack", "biometric", "separator_3ph", "level_radar", "coriolis", "imu", "arc_furnace", "ingot_rack", "eddy_sorter", "mag_separator", "scrubber", "car", "deck_tractor", "apu", "escape_pod", "ntr_core", "control_drum", "shadow_shield", "flywheel_rotor", "launch_cradle", "tether_damper", "hyd_clamp", "piano", "wine_rack", "bar", "crusher",
	"rf_amp", "aux_rocket", "gamma_probe", "pellet_feeder", "steam_cyl", "fog_pump", "comms_desk", "fw_appliance", "rig_welder", "e07_unit", "shunt_reg", "gas_puff", "ion_grid", "rb_clock", "daq_rail",
	"ark_aux_pack", "battery_cart", "emerg_light", "ring_battery", "shuttle_pack", "vrla_rack", "main_battery", "drone_pack", "courier_stack", "lock_ups", "pod_ups", "race_pack", "standby_bank", "ups_unit",
	"brake_ctrl", "dosing_skid", "material_rack", "food_bench", "tx_cabinet", "turbine_ctrl", "bench_drill", "tool_cart", "pack_rack", "dispatch_log", "bms_cab", "cal_bench", "survey_log", "crd_cab", "crypto_rack", "hv_switchgear", "gas_detector",
	"herbarium", "garden_locker", "chem_store", "core_store", "drill_tools", "well_logs", "ev_calib", "dcdc", "cryo_cdb", "cryo_spares", "shot_archive", "spare_leads", "sample_cyl", "ob_cal", "plate_archive", "spare_cells", "server_spares",
	"batch_log", "shadow_board", "cargo_log", "custody_reg", "evidence_lockers", "flow_ctrl", "mail_locker", "manifest_term", "pharmacy", "sample_trays", "seed_vault", "smelt_log", "cockpit_case", "supply_stack", "svc_bench", "dining_table", "tow_log",
	"bl_electrolyser", "fuel_cell_pm", "stirling_gen", "turbine_genset", "drups", "co2_burner", "diesel_genset", "rtg_module", "main_alternator", "ts_power"]


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
			if i == 2:
				R(ci, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), 0.45)
			else:
				O(ci, c, rad, 0.45)
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
		O(ci, _u(r, 0.62 + k * 0.1, 0.36), maxf(1.6, ms * 0.04), 0.5)
		O(ci, _u(r, 0.62 + k * 0.1, 0.48), maxf(1.6, ms * 0.04), 0.5)
	E.breaker(ci, sub(r, 0.1, 0.62, 0.46, 0.86), true, 0.5)
	for k in 2:
		var tp := _u(r, 0.62 + k * 0.18, 0.74)
		R(ci, Rect2(tp - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), 0.55)
		D(ci, tp, 1.0, 0.6)
	L(ci, _u(r, 0.71, 0.74), _u(r, 0.71, 0.92), 0.5, 1.6)
