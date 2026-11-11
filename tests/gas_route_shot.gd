extends "res://tests/guide_check.gd"
# The gas and cryo pipelines across the port (2026-11-11): the whole port, each run close, the
# first-transfer close-up. Test career only.
#   tools/run_test.sh tests/gas_route_shot.gd --fixed-fps 60 -- tag=before|after [probe=1]


func _initialize() -> void:
	Career.path = "user://zp_test_gas_route_career.json"
	SaveGame.path = "user://zp_test_gas_route_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _shot(name: String, at: Vector2, zoom: float, wait := 20) -> void:
	_put(at, zoom)
	await _frames(wait)
	Cap.save(root, "res://tests/out/gasroute_%s_%s.png" % [name, _arg("tag", "after")])


func _setup() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 2, "power": 1, "cargo": 1, "tug": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	if not Career.data.has("upgrades"):
		Career.data.upgrades = {}
	Career.data.upgrades["gas_line"] = true
	Career.data.upgrades["lox_tank"] = true
	var d := GasLine.data()
	d.made = 3
	d.o2.ind = 1500.0
	d.lox.kg = 5200.0
	Career.save()


func _run() -> void:
	Pal.solid = _arg("solid", "1") == "1"
	_setup()
	await _spawn()
	await _frames(30)
	var M := PortStructure.M()
	var c := PortStructure.centre()
	if _arg("probe", "0") == "1":
		print("PROBE M %.2f px/m, port centre %s, Geom.M %.2f" % [M, c, Geom.M])
		for z in ["power", "tug", "process", "trade", "cargo", "salvage"]:
			var b := PortStructure.box(z)
			print("PROBE %s box m %s door %s" % [z, Rect2((b.position - c) / M, b.size / M), (PortStructure.door(z)[0] - c) / M])
		print("PROBE berth drone at %s m" % ((g.drone.global_position - c) / M))
		print("PROBE bounds %s" % PortArt.bounds())
	var b := PortArt.bounds()
	var vs: Vector2 = root.get_visible_rect().size
	if _arg("perf", "0") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		var seen0: Dictionary = Career.data.get("seen", {})
		seen0["gas_flow_film"] = true
		Career.data.seen = seen0
		var bp := GasLine.receive({"o2": 2100.0, "n2": 7800.0}, "PERF")
		bp.t_total = 9999.0
		bp.t_left = 5000.0
		var gp = g.gas_works.pipes
		var vp := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for view in [["port", c + b.get_center() * M, minf(vs.x / (b.size.x * M), vs.y / (b.size.y * M))], ["rack", c + Vector2(-90.0, 40.0) * M, 10.0 / M]]:
			_put(view[1], view[2])
			var sums := {"none": Vector3.ZERO, "shown": Vector3.ZERO}
			for pass_i in 4:
				for mode in ["none", "shown"]:
					gp.visible = mode == "shown"
					gp.set_process(mode == "shown")
					await _frames(20)
					var acc := Vector3.ZERO
					var last := Time.get_ticks_usec()
					for i in 120:
						await process_frame
						var now := Time.get_ticks_usec()
						acc += Vector3(RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), (now - last) / 1000.0)
						last = now
					sums[mode] += acc / 120.0
			var su := Vector3.ZERO
			for i in 60:
				await process_frame
				su += gp.us
			for mode in ["none", "shown"]:
				var v: Vector3 = sums[mode] / 4.0
				print("  %s view, pipes %s: frame %.2f ms, render CPU %.2f ms, GPU %.2f ms" % [view[0], mode, v.z, v.x, v.y])
			print("  %s view, pipes script: process %.0f µs, draw %.0f µs, glow %.0f µs" % [view[0], su.x / 60.0, su.y / 60.0, su.z / 60.0])
		g.queue_free()
		quit(0)
		return
	await _shot("port", c + b.get_center() * M, minf(vs.x / (b.size.x * M), vs.y / (b.size.y * M)), 40)
	if _arg("tag", "after") != "before":
		var seen: Dictionary = Career.data.get("seen", {})
		seen["gas_flow_film"] = true          # the film on its own below
		Career.data.seen = seen
		var bt := GasLine.receive({"o2": 2100.0, "n2": 7800.0, "ar": 100.0}, "TEST")
		bt.certified = true
		print("TRANSIT state after settlement: %s, separable: %s" % [bt.state, GasLine.sep_block(str(bt.id)) == ""])
		bt.t_left = float(bt.t_total) * 0.55
		await _frames(30)
		await _shot("transit_port", c + PortArt.bounds().get_center() * M, minf(vs.x / (PortArt.bounds().size.x * M), vs.y / (PortArt.bounds().size.y * M)), 10)
		var gp = g.gas_works.pipes
		var at: Vector2 = gp._along(gp.g_path, (1.0 - float(bt.t_left) / float(bt.t_total)) * gp._len_g)
		await _shot("transit_close", c + at * M, 14.0 / M, 10)
		await _shot("receiver", c + Vector2(-34.0, 140.0) * M, 14.0 / M, 10)
		bt.t_left = 3.0
		await _shot("inlet", c + Vector2(-160.0, 14.0) * M, 16.0 / M, 30)
		await _frames(200)
		print("TRANSIT arrived: state %s, separable: %s" % [bt.state, GasLine.sep_block(str(bt.id)) == ""])
		# the tug station's cryo tanks with something in them, then a charge on its way down
		TugYard.set_cryo("lh2", 1100.0)
		TugYard.set_cryo("lox", 3800.0)
		var keep_cap := GasLine.LH2_CAP
		GasLine.data().lh2 = {"kg": GasLine.LH2_CAP}
		var lox_keep := float(GasLine.data().lox.kg)
		GasLine.data().lox.kg = GasLine.TANK_CAP
		await _shot("tug_tanks", c + Vector2(-106.0, -21.0) * M, 26.0 / M, 30)
		GasLine.data().lh2 = {"kg": 300.0}
		GasLine.data().lox.kg = lox_keep
		await _frames(3)
		for cp in GasLine.data().get("cryo_pipe", []):
			cp.t_left = float(cp.t_total) * (0.45 if str(cp.kind) == "lh2" else 0.6)
		await _shot("tug_piping", c + Vector2(-128.0, -15.0) * M, 13.0 / M, 20)
		await _shot("tug_port", c + Vector2(-120.0, -10.0) * M, 6.0 / M, 10)
		# the cryo run while the tug fills at the stand
		var PS = preload("res://scripts/power_supply.gd")
		PS.d().fc_fuel = 0.0
		Career.data.gas.lh2 = {"kg": 1200.0}
		PS.start_cryo()
		PS.d().cryo.phase = "p_fill"
		PS.d().cryo.t = 1.0
		await _shot("cryo_port", c + Vector2(-60.0, 25.0) * M, vs.x / (250.0 * M), 20)
		await _shot("cryo_bridge", c + Vector2(0.0, 66.0) * M, 14.0 / M, 10)
		await _shot("cryo_stand", c + Vector2(-140.0, -18.0) * M, 14.0 / M, 10)
		PS.d().cryo.phase = "home"
		# the film, as it plays the first time
		g.cam_override = null
		g.zoom_override = -1.0
		var b2 := GasLine.receive({"o2": 900.0, "n2": 3000.0}, "TEST2")
		seen.erase("gas_flow_film")
		for k in 400:
			await process_frame
			if gp.film >= 0.0:
				break
		print("FILM started: ", gp.film >= 0.0)
		for mark in [0.8, 3.5, 5.5, 7.5, 9.2, 10.8]:
			while gp.film >= 0.0 and gp.film < mark:
				await process_frame
			Cap.save(root, "res://tests/out/gasroute_film_%04.1f_%s.png" % [mark, _arg("tag", "after")])
		while gp.film >= 0.0:
			await process_frame
		print("FILM ended; camera released: ", g.cam_override == null, " seen: ", Career.data.seen.get("gas_flow_film", false))
		# it does not play again by itself
		var b3 := GasLine.receive({"o2": 900.0, "n2": 3000.0}, "TEST3")
		await _frames(60)
		print("FILM replays by itself: ", gp.film >= 0.0)
		gp.play_film()
		await _frames(30)
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = true
		root.push_input(ev)
		await _frames(5)
		print("FILM skipped by a key: ", gp.film < 0.0, ", camera released: ", g.cam_override == null)
	if _arg("probe", "0") == "1":
		await _shot("probe_low", c + Vector2(-30.0, 80.0) * M, vs.x / (300.0 * M), 30)
		print("PROBE_VIEW low centre -30,80 m_per_px %.4f" % (300.0 / vs.x))
	g.queue_free()
	quit(0)
