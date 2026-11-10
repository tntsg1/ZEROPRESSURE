extends SceneTree
# Mechanisms that change state seen changing (design/机制动画缺口_20261110.md): key frames of
# MD-160's flywheels spinning down under the brake, EV-55's hull glowing as it cools, IH-55's
# bags letting down, FR-26's relief valve venting.
# tools/run_test.sh tests/mech_fx_shot.gd --fixed-fps 60 -- <md160|ev55|ih55|fr26> [base]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_mechfx_career.json"
	SaveGame.path = "user://zp_test_mechfx_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _game(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 20:
		await process_frame
	for n in g.world.rooms:
		g.world.reveal(n, g.world.rooms[n].bbox.get_center())
	var w := 0
	while str(g.state) == "survey" and w < 60 * 25:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(-40.0, -60.0) * Geom.M
	return g


func _look(g, at: Vector2, zoom: float, wait: int, name: String) -> void:
	g.zoom_override = zoom
	g.cam_override = at * Geom.M
	for i in wait:
		await process_frame
	Cap.save(root, "res://tests/out/%s.png" % name)


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ship: String = args[0] if args.size() > 0 else "md160"
	var base := "base" in args
	var g = await _game(ship)
	match ship:
		"md160":
			await _look(g, Vector2(40.0, 0.0), 0.9, 40, "fx_md160_%s_spin" % ("base" if base else "a"))
			if base:
				quit()
				return
			g.do_wrench(_ctrl(g, "BR-1"))
			await _look(g, Vector2(40.0, -2.0), 0.9, 90, "fx_md160_b_brake_dry")
			g.do_wrench(_ctrl(g, "CV-1"))
			g.flywheel.rpm["FW-1"] = 900.0
			await _look(g, Vector2(40.0, -2.0), 0.9, 90, "fx_md160_c_cooled_slow")
		"ev55":
			await _look(g, Vector2(12.0, 0.0), 0.75, 40, "fx_ev55_%s_hot" % ("base" if base else "a"))
			if base:
				quit()
				return
			for z in g.thermal.temp:
				g.thermal.temp[z] = float(g.thermal.temp[z]) * 0.5
			await _look(g, Vector2(12.0, 0.0), 0.75, 30, "fx_ev55_b_cooling")
			for z in g.thermal.temp:
				g.thermal.temp[z] = 40.0
			await _look(g, Vector2(12.0, 0.0), 0.75, 30, "fx_ev55_c_cool")
		"ih55":
			await _look(g, Vector2(40.0, 0.0), 0.45, 40, "fx_ih55_%s" % ("base" if base else "a_full"))
			if base:
				quit()
				return
			var bag: String = g.softshell.cfg.bags.keys()[0]
			var v: String = g.softshell.cfg.bags[bag].vessel
			g.sys.vols[v].n = 0.0
			var w := 0
			while not g.softshell.folded.has(bag) and w < 120:
				await process_frame
				w += 1
			await _look(g, Vector2(40.0, 0.0), 0.45, 40, "fx_ih55_b_folding")
			await _look(g, Vector2(40.0, 0.0), 0.45, 90, "fx_ih55_c_flat")
		"mf126":
			await _look(g, Vector2(60.0, 0.0), 1.0, 40, "fx_mf126_a_hot")
			g.furnace.T = 420.0
			await _look(g, Vector2(60.0, 0.0), 1.0, 20, "fx_mf126_b_cooler")
			g.furnace.cracked = true
			await _look(g, Vector2(60.0, 0.0), 1.0, 20, "fx_mf126_c_cracked")
		"pt34":
			var i := 0
			for id in g.world.order:
				var p = g.world.pieces[id]
				if not p.gone and str(p.hazard) == "explosive" and p.room == "MAG":
					p.temp = [60.0, 90.0, 112.0, 40.0][i % 4]
					i += 1
			g.munitions.set_physics_process(false)
			await _look(g, Vector2(31.0, 5.3), 2.0, 30, "fx_pt34_a_cooking")
			g.munitions.set_physics_process(true)
			g.munitions.flood("FLV")
			await _look(g, Vector2(31.0, 5.3), 2.0, 70, "fx_pt34_b_flooding")
			await _look(g, Vector2(31.0, 5.3), 2.0, 200, "fx_pt34_c_flooded")
		"fl116":
			g.world.ctrls["V-2"].state = false
			g.world.ctrls["V-3"].state = false
			g.do_hose(_ctrl(g, "MP-2"))
			await _look(g, Vector2(80.0, 6.0), 0.8, 60, "fx_fl116_a_drawing")
			g.world.ctrls["V-2"].state = true
			await _look(g, Vector2(88.7, 9.3), 1.6, 60, "fx_fl116_b_mixing")
			var man = g.world.tag("MANIFOLD")
			g.media.on_manifold(man)
			await _look(g, Vector2(88.7, 9.3), 1.2, 40, "fx_fl116_c_spill")
		"dc84":
			await _look(g, Vector2(15.0, 4.9), 2.2, 40, "fx_dc84_a_full")
			g.do_hose(_ctrl(g, "PTA-1"))
			g.sys.fvol["tkA1"].amount = 0.2
			await _look(g, Vector2(15.0, 4.9), 2.2, 40, "fx_dc84_b_draining")
			g.sys.fvol["tkA1"].amount = 0.04
			await _look(g, Vector2(15.0, 4.9), 2.2, 40, "fx_dc84_c_nearly_dry")
		"ch110":
			await _look(g, Vector2(40.0, -9.0), 2.4, 40, "fx_ch110_a_held")
			g.sys.switch["HC-U1"] = false
			await _look(g, Vector2(40.0, -9.0), 2.4, 12, "fx_ch110_b_sprung")
			g.sys.switch["HC-U2"] = false
			g.sys.switch["HC-U3"] = false
			for t in ["BM2-2"]:
				g.sandwich._check(g.world.tag(t))
			await _look(g, Vector2(48.0, 0.0), 0.6, 14, "fx_ch110_c_twist_snap")
		"dr150":
			for k in 4:
				g.sys.switch["SLIP-%d" % (k + 1)] = true
			await _look(g, Vector2(50.0, -16.0), 1.0, 60, "fx_dr150_a_torque_mud")
			g.sys.switch["TQB"] = true
			g.drillstring.torque = 0.45
			g.do_hose(_ctrl(g, "PMUD"))
			await _look(g, Vector2(50.0, -16.0), 1.0, 60, "fx_dr150_b_bleeding")
			g.drillstring._drop(["J-6", "J-7", "J-8"], "J-5", "drill_drop_below")
			g.drillstring.whipped = true
			await _look(g, Vector2(50.0, -10.0), 0.8, 14, "fx_dr150_c_whip_drop")
		"cl104":
			await _look(g, Vector2(35.8, -1.4), 0.85, 40, "fx_cl104_a_frozen")
			g.coldchain.temp["K1"] = -11.0
			await _look(g, Vector2(35.8, -1.4), 0.85, 20, "fx_cl104_b_warming")
			g.coldchain.temp["K1"] = -4.0
			await _look(g, Vector2(35.8, -1.4), 0.85, 60, "fx_cl104_c_thawed")
		"vt80":
			g.sys.fvol["t1"].amount = 3.6
			g.sys.fvol["t3"].amount = 0.8
			await _look(g, Vector2(46.0, 5.8), 0.8, 40, "fx_vt80_a_levels")
			g.sys.switch["XV-1"] = true
			g.sys.switch["XV-3"] = true
			await _look(g, Vector2(46.0, 5.8), 0.8, 200, "fx_vt80_b_evening")
			g.tanknet.buckled["T-3"] = true
			g.tanknet._dry_t = 2.5
			await _look(g, Vector2(66.0, 5.8), 0.8, 30, "fx_vt80_c_buckled_dry")
		"qc30":
			await _look(g, Vector2(15.5, -3.0), 3.0, 40, "fx_qc30_a_cold")
			g.dilution.set_physics_process(false)
			for st in ["STG-50K", "STG-4K", "STG-STILL"]:
				g.dilution.temp[st] = 200.0
			g.dilution.temp["STG-CP"] = 20.0
			g.dilution.temp["STG-MXC"] = 2.0
			g.sys.switch["HEAT"] = true
			await _look(g, Vector2(15.5, -3.0), 3.0, 30, "fx_qc30_b_warming")
			g.sys.switch["HEAT"] = false
			g.dilution.boiled = true
			g.dilution.cracked = "qpu_shock"
			await _look(g, Vector2(15.5, -3.0), 3.0, 20, "fx_qc30_c_boil_crack")
		"st40":
			var hc = g.world.tag("HC1-0")
			g.tools.front = g.world.frame(hc) * Geom.centroid(hc.poly)
			g.composite.on_cut(hc)
			await _look(g, Vector2(24.0, 0.0), 0.9, 20, "fx_st40_a_fumes")
			g.composite.smoke["E"] = 2.5
			g.composite.smoke["P"] = 2.0
			await _look(g, Vector2(24.0, 0.0), 0.9, 60, "fx_st40_b_haze")
			g.composite.fogged["CAN-1"] = true
			g.composite.fogged["CAN-2"] = true
			await _look(g, Vector2(17.0, 0.0), 1.6, 30, "fx_st40_c_fogged")
		"med47":
			var at: Vector2 = g.world.rooms["U3"].bbox.get_center() if g.world.rooms.has("U3") else Vector2.ZERO
			await _look(g, at / Geom.M, 0.7, 40, "fx_med47_a_isolation")
			g.sys.bio_add("U2" if g.world.rooms.has("U2") else "U4", 1.6)
			await _look(g, at / Geom.M, 0.7, 60, "fx_med47_b_spread")
			await _look(g, at / Geom.M, 0.5, 30, "fx_med47_c_wide")
		"hb86":
			var at: Vector2 = g.world.rooms["U3"].bbox.get_center()
			await _look(g, at / Geom.M + Vector2(-8.0, 0.0), 0.8, 40, "fx_hb86_a_rich")
			g.tools.front = at
			g.atmos._last["U3"] = g.sys.time
			await _look(g, at / Geom.M + Vector2(-8.0, 0.0), 0.8, 24, "fx_hb86_b_flash")
			g.drone.global_position = at + Vector2(0, -40.0) * Geom.M
			await _look(g, at / Geom.M + Vector2(-8.0, 0.0), 0.8, 170, "fx_hb86_c_scorched")
		"tb180":
			await _look(g, Vector2(60.0, 0.0), 0.5, 40, "fx_tb180_a_turning")
			await _look(g, Vector2(60.0, 0.0), 0.5, 90, "fx_tb180_a2_turned")
			g.sys.switch["BRK"] = true
			g.tether.heat = 4.5
			await _look(g, Vector2(90.0, 0.6), 1.6, 30, "fx_tb180_b_braking_dry")
			g.sys.switch["RCS-B"] = true
			g.tether.slipped = true
			await _look(g, Vector2(168.0, 0.0), 0.9, 30, "fx_tb180_c_rcs")
		"ark01":
			var c1 = g.world.tag("CT-11")
			var at: Vector2 = Geom.centroid(c1.poly) / Geom.M
			g.spine.cut["CT-11"] = true
			g.spine._weigh()
			g.spine.set_physics_process(false)
			await _look(g, at, 0.35, 40, "fx_ark01_a_loaded")
			g.spine._tear("L11")
			await _look(g, at + Vector2(30.0, 0.0), 0.22, 14, "fx_ark01_b_tear_lurch")
			await _look(g, at, 0.6, 150, "fx_ark01_c_parted")
		"fr26":
			await _look(g, Vector2(21.3, -2.6), 1.6, 40, "fx_fr26_%s" % ("base" if base else "a"))
			if base:
				quit()
				return
			var e: Dictionary = g.cryo.tanks["T-1"]
			e.T = float(e.T0) + 60.0
			var w := 0
			while not e.get("lifting", false) and w < 900:
				await process_frame
				w += 1
			print("SHOT lifted after %d frames" % w)
			await _look(g, Vector2(21.3, -2.6), 1.6, 12, "fx_fr26_b_lift")
			await _look(g, Vector2(21.3, -2.6), 1.6, 60, "fx_fr26_c_venting")
	quit()
