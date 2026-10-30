extends "res://tests/guide_check.gd"
# 101 号: the processing district before and after — the whole hall and close views of the arc
# furnace melting, the pre-processing line and the rolling mill on a pass, at 1920×1080; and the
# frame time over the hall with everything running (perf=1: vsync off, no fixed fps).
#   tools/run_test.sh tests/process_shots.gd --fixed-fps 60 -- tag=before
#   tools/run_test.sh tests/process_shots.gd -- perf=1 tag=before


func _initialize() -> void:
	Career.path = "user://zp_test_process_shots_career.json"
	SaveGame.path = "user://zp_test_process_shots_save.json"
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


func _shot(name: String, at: Vector2, zoom: float, wait := 12) -> void:
	_put(at, zoom)
	await _frames(wait)
	Cap.save(root, "res://tests/out/proc101_%s_%s.png" % [name, _arg("tag", "after")])


func _run() -> void:
	var perf := _arg("perf", "0") == "1"
	if perf:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": int(_arg("stage", "1")), "power": 1, "cargo": 1, "tug": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.data.exchange.actors.company.stock["steel_billet:1"] = 3.0
	Career.save()
	await _spawn()
	await _frames(10)
	# the furnace melting a tonne under its arcs
	var f = g.plant.smelter
	f.begin_manual()
	f.manual_charge(1.0)
	Career.data.industrial_heat = {"id": "H-98", "state": "processing", "quantity": 1.0, "source_lots": [], "furnace": f.manual_snapshot(),
		"transport": {}, "electric_paid_j": float(f.electrical_j), "energy_cost": 0.0, "created": 0.0}
	g.drone.global_position = g.industrial_heat.site()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(10)
	g.open_heat()
	await _frames(6)
	if g.console_ui != null:
		g.console_ui.main.pressed.emit()
		await _frames(6)
		g.console_ui.close()
	# the mill on a pass of plate
	Mill.start("plate")
	if not Career.data.get("mill", {}).is_empty():
		Career.data.mill.state = "roll"
	await _frames(240)
	var box := PortStructure.box("process")
	var M := Geom.M
	if perf:
		_put(box.get_center(), 0.62)
		await _frames(60)
		for pass_i in 2:
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
			print("  process hall run %d (%s): avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f ms" % [pass_i, _arg("tag", "after"), avg / acc.size(), acc[300], acc[570], acc[594], acc[599]])
		var di = g.port_structure.interiors
		print("  works: furnace + line shapes %.0f µs a redraw (meshes %.0f, furnace %.0f); line %.0f µs a redraw, %d redraws" % [g.plant.shapes_us, g.plant.split_us.x, g.plant.split_us.y, g.plant.split_us.z, g.plant.line_draws])
		print("  processing district: machines step %.0f µs, drawing behind %.0f µs, in front %.0f µs a frame" % [di.proc_tick_us, di.proc_draw_us, di.proc_front_us])
		# the same frames with the new layers hidden (what the hall cost before, roughly)
		var hide := func(on: bool) -> void:
			for n in [di.proc_still, di.proc_back, di.proc_front, di.proc_glow]:
				n.visible = on
				n.set_process(on)
		for pass_i in 2:
			for hidden in [true, false]:
				hide.call(not hidden)
				di.set_process(not hidden)
				await _frames(30)
				var acc2 := []
				var last2 := Time.get_ticks_usec()
				for i in 600:
					await process_frame
					var now2 := Time.get_ticks_usec()
					acc2.append((now2 - last2) / 1000.0)
					last2 = now2
				acc2.sort()
				var avg2 := 0.0
				for x in acc2:
					avg2 += x
				print("  %s: avg %.2f p50 %.2f p95 %.2f p99 %.2f ms" % ["new layers hidden" if hidden else "new layers shown ", avg2 / acc2.size(), acc2[300], acc2[570], acc2[594]])
			di.set_process(true)
		g.queue_free()
		quit(0)
		return
	await _shot("hall", box.get_center(), 0.62)
	await _shot("furnace", Vector2(g.plant.X + 3.0, g.plant.F + 4.0) * M, 1.1)
	await _shot("line", Vector2(g.plant.X - 3.0, g.plant.F + 2.0) * M, 1.1)
	await _shot("mill", preload("res://scripts/mill_line.gd").centre(), 1.2)
	await _shot("door", box.position + Vector2(52.0, 14.0) * M, 1.0)
	if _arg("tag", "after") != "before":
		var Wk = preload("res://scripts/process_works.gd")
		# the crane over the chute, the basket emptying into it
		f.bunker = maxf(float(f.bunker), 0.8)
		for i in 60 * 30:
			await _frames(1)
			if Wk.step == "charge" and Wk.basket_fill > 0.2:
				break
		await _shot("crane", box.position + Vector2(17.0, 9.0) * M, 1.0, 4)
		# the tap: the vessel tilts, the stream into the moulds, the sparks
		f.bunker = 0.0
		f.m_s = 0.0
		f.m_l = 11.0
		f.T = 1660.0
		f.phase = "melt"
		f.sample_count = 1
		f.tc_age = 0.0
		print("  tap: ", f.manual_command("tap"))
		for i in 60 * 30:
			await _frames(1)
			if str(f.phase) == "pour" and float(f.gate) > 0.6:
				break
		await _frames(30)
		await _shot("tap", Vector2(g.plant.X + 3.5, g.plant.F + 6.0) * M, 1.0, 4)
	print("shots done (%s)" % _arg("tag", "after"))
	Career.data.industrial_heat = {}
	g.queue_free()
	await _frames(4)
	quit(0)
