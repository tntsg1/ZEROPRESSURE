extends "res://tests/perf_probe.gd"
# temporary (60 FPS work): where a frame goes on ARK-01, close and pulled right out


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.zh = true
	if "look=0" in OS.get_cmdline_user_args():
		Look.on = false
	Game.contract = {}
	Game.start_ship = "ark01"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(150)
	for phase in ["follow", "far"]:
		if phase == "far":
			g.zoom_override = 0.08
			g.cam_override = Vector2(300.0 * Geom.M, 0)
			await _frames(90)
		World.prof = {}
		World.acc_n = {}
		World.acc_sum = {}
		var ts: Array = []
		var l0 := Time.get_ticks_usec()
		var vp := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		var rc := 0.0
		var rg := 0.0
		var ph := 0.0
		var per: Array = []      # [frame ms, {key: µs this frame}, render cpu, physics]
		var last := {}
		for i in 240:
			await process_frame
			var n2 := Time.get_ticks_usec()
			ts.append((n2 - l0) / 1000.0)
			l0 = n2
			var d := {}
			for k in World.acc_sum:
				var v: int = World.acc_sum[k] - int(last.get(k, 0))
				if v > 0: d[k] = v
			last = World.acc_sum.duplicate()
			per.append([ts[-1], d, RenderingServer.viewport_get_measured_render_time_cpu(vp), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
			rc += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			rg += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		# the slowest tenth against the middle: what grew
		var by := per.duplicate()
		by.sort_custom(func(x, y): return x[0] > y[0])
		var slow: Array = by.slice(0, 24)
		var mid: Array = by.slice(96, 144)
		var avg := func(arr: Array, k: String) -> float:
			var s := 0.0
			for e in arr: s += float(e[1].get(k, 0))
			return s / arr.size() / 1000.0
		var avgi := func(arr: Array, i: int) -> float:
			var s := 0.0
			for e in arr: s += float(e[i])
			return s / arr.size()
		print("  slow tenth: frame %.2f vs middle %.2f | render cpu %.2f vs %.2f | physics %.2f vs %.2f" % [avgi.call(slow, 0), avgi.call(mid, 0), avgi.call(slow, 2), avgi.call(mid, 2), avgi.call(slow, 3), avgi.call(mid, 3)])
		var grow: Array = []
		for k in World.acc_sum:
			grow.append([k, avg.call(slow, k) - avg.call(mid, k), avg.call(slow, k)])
		grow.sort_custom(func(x, y): return x[1] > y[1])
		for e in grow.slice(0, 8):
			print("    +%.3f ms  %s (%.3f in slow frames)" % [e[1], e[0], e[2]])
		ts.sort()
		var a := 0.0
		for x in ts: a += x
		print("ARK %-7s median %.2f mean %.2f p95 %.2f | physics %.2f | render cpu %.2f gpu %.2f | draws %d objects %d" % [phase, ts[ts.size() / 2], a / ts.size(), ts[int(ts.size() * 0.95)], ph / 240.0, rc / 240.0, rg / 240.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		var pk: Array = World.prof.keys()
		pk.sort_custom(func(x, y): return World.prof[x] > World.prof[y])
		for k in pk.slice(0, 10):
			print("  P %-22s %.3f ms/frame" % [k, World.prof[k] / 240.0 / 1000.0])
		var ks: Array = World.acc_sum.keys()
		ks.sort_custom(func(x, y): return World.acc_sum[x] > World.acc_sum[y])
		for k in ks.slice(0, 40):
			print("  %-26s %.3f ms/frame" % [k, World.acc_sum[k] / 240.0 / 1000.0])
	quit()
