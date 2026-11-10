extends SceneTree
# 工业剖面样片的帧时间：Pal.solid 关/开交替，每轮 120 帧；场景 idle（近景静止）和 cut（激光切船壳）。
# 另记切换那一帧（整船条带全量重画）的耗时。Own test saves only.
#   tools/run_test.sh tests/cutaway_perf.gd -- [ship=gr7]
func _initialize() -> void:
	Career.path = "user://zp_test_cutperf_career.json"
	SaveGame.path = "user://zp_test_cutperf_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _pct(a: Array, q: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(s.size() * q), 0, s.size() - 1)]


func _park(g, at: Vector2, cam: Vector2, z: float) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_override = cam
	g.zoom_override = z


func _run() -> void:
	var sid := "gr7"
	var rounds := 6
	var frames := 120
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
		elif a.begins_with("rounds="):
			rounds = int(a.substr(7))
		elif a.begins_with("skip="):
			for k in a.substr(5).split(","):
				Cutaway.skip[k] = true
		elif a.begins_with("frames="):
			frames = int(a.substr(7))
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": true}}
	root.add_child(g)
	for i in 10: await process_frame
	g.job = {"id": "cutaway-perf", "ship": sid}
	for i in 90: await process_frame
	g.tutorial = null
	# a hull plate to cut, and where to look from
	var tgt = null
	var big := 0.0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.kind == "hull" and p.body == null and not p.gone:
			var ar := Geom.area(p.poly)
			if ar > big:
				big = ar
				tgt = p
	var at: Vector2 = Geom.centroid(tgt.poly)
	var dp := at + Vector2(-3.0, -3.5) * Geom.M
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var res := {}
	var toggles := {true: [], false: []}
	for scen in ["idle", "cut"]:
		for on in [false, true]:
			res[[scen, on]] = {"frame": [], "cpu": [], "proc": [], "gpu": []}
		g.tools.tool = 2
		g.bot.aim = at
		g.bot.lmb = scen == "cut"
		for round in rounds:
			var on := round % 2 == 1
			Pal.solid = on
			g.world.redraw_all(true)
			var t0 := Time.get_ticks_usec()
			_park(g, dp, at, Game.CAM_ZOOM)
			await process_frame
			toggles[on].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			for i in 20:
				_park(g, dp, at, Game.CAM_ZOOM)
				await process_frame
			var d: Dictionary = res[[scen, on]]
			for i in frames:
				_park(g, dp, at, Game.CAM_ZOOM)
				var t1 := Time.get_ticks_usec()
				await process_frame
				d.frame.append((Time.get_ticks_usec() - t1) / 1000.0)
				d.cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
				d.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
				d.proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	g.bot.lmb = false
	Pal.solid = false
	print("ship %s" % sid)
	for scen in ["idle", "cut"]:
		for on in [false, true]:
			var d: Dictionary = res[[scen, on]]
			print("%s solid %s  frame p50 %.2f p95 %.2f p99 %.2f · process p50 %.2f p95 %.2f · render cpu p50 %.2f p95 %.2f · gpu p50 %.2f p95 %.2f" % [
				scen, "on " if on else "off", _pct(d.frame, 0.5), _pct(d.frame, 0.95), _pct(d.frame, 0.99),
				_pct(d.proc, 0.5), _pct(d.proc, 0.95), _pct(d.cpu, 0.5), _pct(d.cpu, 0.95), _pct(d.gpu, 0.5), _pct(d.gpu, 0.95)])
	var row := "ROW %s" % sid
	for scen in ["idle", "cut"]:
		for on in [false, true]:
			var d: Dictionary = res[[scen, on]]
			row += " %s_%s %.2f %.2f %.2f %.2f %.2f" % [scen, "on" if on else "off", _pct(d.frame, 0.5), _pct(d.frame, 0.99), _pct(d.proc, 0.5), _pct(d.cpu, 0.5), _pct(d.gpu, 0.5)]
	print(row)
	var CL = load("res://scripts/cutaway_light.gd")
	print("stand redraws %d, %.1f ms total" % [CL.stand_draws, CL.stand_us / 1000.0])
	for on in [false, true]:
		print("full-redraw frame (process) solid %s: %s" % ["on " if on else "off", str(toggles[on].map(func(x): return snappedf(x, 0.01)))])
	quit(0)
