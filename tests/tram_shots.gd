extends "res://tests/guide_check.gd"
# 97 号: the shuttle and its rails, before and after — the same four views at 1920×1080 (the hub and
# the berth's stop, a district stop close up, the train in the hub's curves, the berth's gate), and
# the frame time over the hub with the train running (perf=1: vsync off, no fixed fps).
#   tools/run_test.sh tests/tram_shots.gd --fixed-fps 60 -- tag=after
#   tools/run_test.sh tests/tram_shots.gd -- perf=1


func _initialize() -> void:
	Career.path = "user://zp_test_tram_shots_career.json"
	SaveGame.path = "user://zp_test_tram_shots_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _shot(name: String, at: Vector2, zoom: float) -> void:
	_put(at, zoom)
	await _frames(12)
	Cap.save(root, "res://tests/out/tram97_%s_%s.png" % [name, _arg("tag", "after")])


# the camera straight there (it follows on a spring otherwise, and takes a second to arrive)
func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


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
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1, "tug": 1}
	Career.data.tram_found = ["ring", "power", "tug", "process", "trade", "cargo"]
	Career.data.seen = {"port_walk_started": true}
	Career.save()
	await _spawn()
	await _frames(20)
	var tr = g.tram
	if _arg("old", "0") == "1":
		# the shuttle as it was before 97 号 (tests/_tram_old.gd), in place of the new one
		var old := Node2D.new()
		old.set_script(load("res://tests/_tram_old.gd"))
		old.set("game", g)
		g.remove_child(tr)
		tr.queue_free()
		g.add_child(old)
		g.tram = old
		tr = old
		await _frames(5)
	var c := Backdrop.port_centre_px()
	var M := Geom.M
	if perf:
		# the hub framed, the train running round it and back, over and over
		g.drone.global_position = Tram.station_at("process")
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(4)
		g.cam_override = c + Vector2(0, 12) * M
		g.zoom_override = 0.42
		await _frames(30)
		var route := ["cargo", "process", "trade", "power"]
		var k := 0
		for pass_i in 3:
			var acc := []
			var last := Time.get_ticks_usec()
			for i in 600:
				if tr.phase == "":
					var here: String = tr.at if tr.at != "" else "process"
					g.drone.global_position = Tram.station_at(here)
					var to: String = route[k % route.size()]
					tr.call_to(here, to if to != here else "ring")
					k += 1
				await process_frame
				var now := Time.get_ticks_usec()
				acc.append((now - last) / 1000.0)
				last = now
			acc.sort()
			var avg := 0.0
			for x in acc:
				avg += x
			print("  hub + train run %d (%s): avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f ms" % [pass_i, _arg("tag", "after"), avg / acc.size(), acc[300], acc[570], acc[594], acc[599]])
		var m2: Dictionary = await measure(240)
		# the same frames with each layer of the shuttle hidden in turn
		if tr.get("_track") is Array:
			var nv := 0
			for mesh in tr._track:
				nv += (mesh as ArrayMesh).surface_get_array_len(0)
			print("  track %d meshes, %d verts" % [tr._track.size(), nv])
		for layer in ["rails", "points", "self"]:
			var n = tr if layer == "self" else tr.get(layer)
			if n == null:
				continue
			n.visible = false
			if layer == "self":
				tr.set_process(false)
			await _frames(20)
			var mh: Dictionary = await measure(240)
			print("  without %s: shuttle draw %.0f µs step %.0f µs | frame avg %.2f p95 %.2f p99 %.2f | render cpu %.2f gpu %.2f draws %d" % [layer, tr.draw_us, tr.step_us, mh.avg, mh.p95, mh.p99, mh.render_cpu, mh.render_gpu, mh.draws])
			n.visible = true
			tr.set_process(true)
			await _frames(20)
		print("  shuttle: draw %.0f µs a frame, physics %.0f µs a step" % [tr.get("draw_us") if tr.get("draw_us") != null else -1.0, tr.get("step_us") if tr.get("step_us") != null else -1.0])
		print("hub + train (%s): frame avg %.2f p95 %.2f p99 %.2f max %.2f | process %.2f physics %.2f render cpu %.2f gpu %.2f draws %d" % [_arg("tag", "after"), m2.avg, m2.p95, m2.p99, m2.max, m2.process, m2.physics, m2.render_cpu, m2.render_gpu, m2.draws])
		g.queue_free()
		quit(0)
		return
	# 1: the hub and the corridor down to the berth's gate
	await _shot("hub", c + Vector2(0, 30) * M, 0.3)
	# 2: the hub's stop close up, the train standing in it
	await _shot("ring_stop", Tram.station_at("ring"), 1.0)
	# 3: the berth's gate, where the new stop stands
	var gate: Rect2 = g.dock.port_gate()
	await _shot("gate", Vector2(gate.get_center().x, Dock.RAIL_Y - 6.0) * M, 0.8)
	# 4: the train running through the hub's curves, followed
	g.drone.global_position = Tram.station_at("process")
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(4)
	tr.call_to("process", "cargo")
	var n := 0
	while tr.phase != "" and n < 60 * 40:
		await _frames(1)
		n += 1
		if tr.phase == "ride" and tr.position_px.distance_to(c) < (Tram.LOOP_R + 1.0) * M and tr.speed > 0.3 * Tram.SPEED:
			break
	for i in 4:
		_put(tr.position_px, 1.1)
		await _frames(1)
	Cap.save(root, "res://tests/out/tram97_curve_%s.png" % _arg("tag", "after"))
	while tr.phase != "" and n < 60 * 40:
		await _frames(1)
		n += 1
	# 5: a district's stop, the train standing in it with its doors
	await _shot("district_stop", Tram.station_at("cargo"), 1.0)
	if _arg("tag", "after") == "after":
		# 6: the hub's stop to the berth's: the reversal past the switch, the points thrown
		g.drone.global_position = Tram.station_at("cargo")
		tr.call_to("cargo", "ring")
		n = 0
		while tr.phase != "" and n < 60 * 40:
			await _frames(1)
			n += 1
		g.drone.global_position = Tram.station_at("ring")
		tr.call_to("ring", "salvage")
		n = 0
		var shot := false
		while tr.phase != "" and n < 60 * 40:
			await _frames(1)
			n += 1
			if not shot and tr._hold > 0.0 and tr._hold < 0.35:
				shot = true
				for i in 3:
					_put(tr.position_px + Vector2(0, 2) * M, 1.3)
					await _frames(1)
				Cap.save(root, "res://tests/out/tram97_reverse_after.png")
			# 7: in at the berth's stop, its doors open, the drone stepping off
			if tr.phase == "alight" and tr.dwell > 0.55:
				for i in 3:
					_put(Tram.station_at("salvage") + Vector2(0, -1) * M, 1.3)
					await _frames(1)
				Cap.save(root, "res://tests/out/tram97_berth_stop_after.png")
				break
	print("shots done (%s)" % _arg("tag", "after"))
	g.queue_free()
	quit(0)


func measure(n: int) -> Dictionary:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var dts: Array = []
	var gpu := 0.0
	var cpu := 0.0
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var s := dts.duplicate()
	s.sort()
	var avg := 0.0
	for x in s:
		avg += x
	avg /= s.size()
	return {"avg": avg, "p95": s[int(s.size() * 0.95)], "p99": s[mini(s.size() - 1, int(s.size() * 0.99))], "max": s[s.size() - 1], "low1": s[s.size() - 1],
		"process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"render_cpu": cpu / n, "render_gpu": gpu / n,
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
