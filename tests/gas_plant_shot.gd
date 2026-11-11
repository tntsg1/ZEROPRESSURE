extends "res://tests/guide_check.gd"
# The gas line's plant in the processing district (2026-11-10, user: "这里气体分离到底在哪里分离的呀？
# ……我得看到动画呀！"): the whole district and the plant close, in each state — idle, separating,
# liquefying, shipping (the cryo tug filling at the stand). Test career only.
#   tools/run_test.sh tests/gas_plant_shot.gd --fixed-fps 60 -- tag=before
#   tools/run_test.sh tests/gas_plant_shot.gd -- perf=1 tag=after


func _initialize() -> void:
	Career.path = "user://zp_test_gas_plant_career.json"
	SaveGame.path = "user://zp_test_gas_plant_save.json"
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
	Cap.save(root, "res://tests/out/gasplant_%s_%s.png" % [name, _arg("tag", "after")])


# the plant's centre and a zoom that frames it (falls back to the old works' origin)
func _plant_view() -> Array:
	# the bay and what stands over its roof (scripts/gas_plant.gd view_rect), the same before and after
	var M := PortStructure.M()
	var r := Rect2(PortStructure.box("process").position + Vector2(-38.4, -9.6) * M, Vector2(42.4, 38.0) * M)
	return [r.get_center(), clampf(minf(1920.0 / (r.size.x * 1.06), 1080.0 / (r.size.y * 1.08)), 0.05, 3.0)]


func _frame_times(label: String) -> void:
	var acc := []
	var last := Time.get_ticks_usec()
	for i in 600:
		await process_frame
		var now := Time.get_ticks_usec()
		acc.append((now - last) / 1000.0)
		last = now
	acc.sort()
	var avg := 0.0
	for x in acc:
		avg += x
	print("  %s (%s): avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f ms" % [label, _arg("tag", "after"), avg / acc.size(), acc[300], acc[570], acc[594], acc[599]])


func _run() -> void:
	var perf := _arg("perf", "0") == "1"
	if perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	Txt.zh = true
	preload("res://scripts/gas_works.gd").NEW_PLANT = _arg("tag", "after") != "before"
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": int(_arg("stage", "2")), "power": 1, "cargo": 1, "tug": 1}
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
	d.o2.ind = 4000.0
	d.lox.kg = 6200.0
	d.lh2 = {"kg": 900.0}
	var b := GasLine.receive({"o2": 2100.0, "n2": 7800.0, "ar": 100.0}, "TEST")
	b.certified = true
	Career.save()
	await _spawn()
	await _frames(30)
	var box := PortStructure.box("process")
	# the hall's inside is only drawn with the drone in it
	g.drone.global_position = box.get_center() + Vector2(0.0, -2.0) * PortStructure.M()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(20)
	var pv := _plant_view()
	var M0 := PortStructure.M()
	var allr := box.merge(Rect2(box.position + Vector2(-38.4, -9.6) * M0, Vector2(42.4, 38.0) * M0))
	var all_at := allr.get_center()
	var all_z := clampf(minf(1920.0 / (allr.size.x * 1.04), 1080.0 / (allr.size.y * 1.1)), 0.05, 3.0)
	if perf:
		var gp = g.gas_works.plant if g.gas_works != null else null
		var show := func(on: bool) -> void:
			if gp != null:
				gp.set_process(on)
				gp.visible = on
		GasLine.separate(str(b.id))
		GasLine.liquefy(1000.0)
		var vp := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for view in [["hall", box.get_center(), 0.62], ["all", all_at, all_z], ["close", pv[0], pv[1]]]:
			_put(view[1], view[2])
			var modes := ["none", "all"]
			var sums := {}
			for md in modes:
				sums[md] = Vector3.ZERO
			for pass_i in 2:
				for mode in modes:
					show.call(mode != "none")
					if mode != "none":
						gp.still_node.visible = mode in ["all", "still"]
						gp.glow.visible = mode in ["all", "glow"]
						gp.debug_skip_main = false
						gp.dbg = {}
						gp.still_node.visible = mode == "all"
						gp.glow.visible = mode == "all"
						if mode != "all":
							for part in ["turn", "liq", "stage", "frost", "gas", "tanks"]:
								gp.dbg[part] = (part == "tanks" and mode in ["frame", "tanks_only"]) or (part == "liq" and mode == "tanks_only")
					await _frames(20)
					var acc := Vector3.ZERO
					var last := Time.get_ticks_usec()
					for i in 120:
						await process_frame
						var now := Time.get_ticks_usec()
						acc += Vector3(RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), (now - last) / 1000.0)
						last = now
					sums[mode] += acc / 120.0
			gp.still_node.visible = true
			gp.glow.visible = true
			gp.debug_skip_main = false
			gp.debug_every = 1
			gp.dbg = {}
			gp.still_node.visible = true
			gp.glow.visible = true
			var accu := Vector3.ZERO
			for i in 60:
				await process_frame
				accu += gp.us
			var parts := []
			for k in gp.prof:
				parts.append("%s %.0f" % [k, float(gp.prof[k])])
			print("  %s view, plant script: process %.0f µs, draw %.0f µs, glow %.0f µs; draw parts: %s" % [view[0], accu.x / 60.0, accu.y / 60.0, accu.z / 60.0, ", ".join(parts)])
			for mode in modes:
				var v: Vector3 = sums[mode] / 2.0
				print("  %s view, plant %s: frame %.2f ms, render CPU %.2f ms, GPU %.2f ms" % [view[0], mode, v.z, v.x, v.y])
		var vc := 0
		for k in gp._meshes:
			var mm: ArrayMesh = gp._meshes[k]
			if mm.get_surface_count() > 0:
				vc += (mm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector2Array).size()
		print("  meshes: %d, vertices %d" % [gp._meshes.size(), vc])
		show.call(true)
		if gp != null:
			var t0 := Time.get_ticks_usec()
			for i in 20:
				gp.queue_redraw()
				gp.glow.queue_redraw()
				await process_frame
			print("  plant: %d meshes cached" % gp._meshes.size())
		g.queue_free()
		quit(0)
		return
	await _shot("idle_all", all_at, all_z)
	await _shot("idle_close", pv[0], pv[1])
	# separating: about a tenth of the way
	GasLine.separate(str(b.id))
	var j: Dictionary = GasLine.data().job
	j.left = float(j.total) * 0.9
	await _shot("sep_close", pv[0], pv[1], 90)
	await _shot("sep_all", all_at, all_z)
	# liquefying (the column done)
	GasLine.data().job = {}
	b.state = "done"
	GasLine.liquefy(1000.0)
	await _shot("liq_close", pv[0], pv[1], 120)
	await _shot("liq_all", all_at, all_z)
	# shipping: the cryo tug filling at the stand
	GasLine.data().liq = {}
	var PS = preload("res://scripts/power_supply.gd")
	PS.d().fc_fuel = 0.0
	PS.start_cryo()
	PS.d().cryo.phase = "p_fill"
	PS.d().cryo.t = 2.0
	await _shot("ship_close", pv[0], pv[1], 60)
	await _shot("ship_all", all_at, all_z, 4)
	g.queue_free()
	quit(0)
