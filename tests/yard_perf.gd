extends SceneTree
# 工业剖面 · 船坞与港区: frame time, the old picture and the cutaway one alternated in the same run
# (the machine is never idle; the A/B difference cancels the background). Views: the berth close,
# the berth whole, the processing district, the whole port. Own test saves only.
#   tools/run_test.sh tests/yard_perf.gd -- [rounds=6] [frames=120]
func _initialize() -> void:
	Career.path = "user://zp_test_yardperf_career.json"
	SaveGame.path = "user://zp_test_yardperf_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _pct(a: Array, q: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(s.size() * q), 0, s.size() - 1)]


func _redraw_all(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for c in n.get_children():
		_redraw_all(c)


func _run() -> void:
	var rounds := 6
	var frames := 120
	var sid := "gr7"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
		if a.begins_with("rounds="):
			rounds = int(a.substr(7))
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
	g.job = {"id": "yard-perf", "ship": sid}
	for i in 90: await process_frame
	g.tutorial = null
	var M := Geom.M
	g.drone.global_position = Vector2(-20, -20) * M
	var pb: Rect2 = PortStructure.box("process")
	var views := [["berth_near", 0.9, Vector2(4.0, 4.0) * M], ["berth_whole", 0.3, Dock.centre() * M],
		["process", minf(1920.0 * 0.9 / pb.size.x, 1080.0 * 0.85 / pb.size.y) * 0.3, pb.get_center()],
		["port", 0.03, PortStructure.centre()]]
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for v in views:
		var res := {true: {"frame": [], "cpu": []}, false: {"frame": [], "cpu": []}}
		for r in rounds:
			var on := r % 2 == 1
			if "hull" in OS.get_cmdline_user_args():
				PortArt.hull_style = 1 if on else 0
			else:
				Pal.solid = on
			_redraw_all(g)
			g.world.redraw_all(true)
			for i in 30:
				g.cam_override = v[2]; g.zoom_override = v[1]; g.zoom_now = v[1]; g.cam_pos = v[2]
				await process_frame
			for i in frames:
				g.cam_override = v[2]; g.zoom_override = v[1]; g.zoom_now = v[1]; g.cam_pos = v[2]
				var t1 := Time.get_ticks_usec()
				await process_frame
				res[on].frame.append((Time.get_ticks_usec() - t1) / 1000.0)
				res[on].cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
		var row := "YARD %s %s" % [sid, v[0]]
		for on in [false, true]:
			var d: Dictionary = res[on]
			var mean := 0.0
			for x in d.frame:
				mean += x
			mean /= maxf(d.frame.size(), 1)
			row += "  %s mean %.2f p95 %.2f p99 %.2f rcpu %.2f" % ["new" if on else "old", mean, _pct(d.frame, 0.95), _pct(d.frame, 0.99), _pct(d.cpu, 0.5)]
		print(row)
	Pal.solid = true
	g.queue_free()
	for i in 6: await process_frame
	quit(0)
