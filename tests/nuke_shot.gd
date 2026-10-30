extends SceneTree
# Screenshots of the core's heart and its detonation (scripts/reactor.gd, scripts/nuke.gd): the
# count in the heart, the fireball, a district as the shell reaches it, the whole port, the card.
# Own test saves only.
#   tools/run_test.sh tests/nuke_shot.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_nukeshot_career.json"
	SaveGame.path = "user://zp_test_nukeshot_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _park(g, at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


var frames: Array = []
var by := {}
var gpu: Array = []


func _until(nk, t: float) -> void:
	while nk.t < t:
		var t0 := Time.get_ticks_usec()
		await process_frame
		frames.append((Time.get_ticks_usec() - t0) / 1000.0)
		var vp := root.get_viewport_rid()
		gpu.append([nk.t, RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		var ph := "close" if nk.t < nk.T_CLOSE else ("zones" if nk.t < nk.t_card - nk.T_WIDE else ("wide" if not nk.card else "card"))
		if not by.has(ph):
			by[ph] = []
		by[ph].append(frames[frames.size() - 1])


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = "nr95"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10: await process_frame
	# a career's contract, so the port stands round the berth
	g.job = {"id": "nuke-shot", "ship": "nr95"}
	for i in 60: await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var r = g.reactor
	for i in 4:
		var c = g.world.ctrls["DL-%d" % (i + 1)]
		g.do_wrench({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})
	var core = g.world.tag("CORE")
	var hw: Vector2 = g.world.frame(core) * Geom.centroid(core.poly)
	g.cam_override = hw + Vector2(0, -1.5) * Geom.M
	g.zoom_override = 1.0
	for i in 70: await process_frame
	Cap.save(root, "res://tests/out/nuke_0_heart_zh.png")
	# the beam a metre short of the core: the warning
	var top := hw + Vector2(0, -1.4) * Geom.M
	g.bot.aim = top + Vector2(0, -1.0) * Geom.M
	g.bot.lmb = true
	for i in 40:
		_park(g, top + Vector2(0, -3.2) * Geom.M)
		await process_frame
	Cap.save(root, "res://tests/out/nuke_1_near_zh.png")
	g.bot.aim = top + Vector2(0, 0.8) * Geom.M
	while g.state != "nuke":
		_park(g, top + Vector2(0, -3.2) * Geom.M)
		await process_frame
	g.bot.lmb = false
	var nk = g.nuke
	await _until(nk, 0.35)
	Cap.save(root, "res://tests/out/nuke_2_flash_zh.png")
	await _until(nk, 1.6)
	Cap.save(root, "res://tests/out/nuke_3_fireball_zh.png")
	await _until(nk, float(nk.zones[1].t) + 0.6)
	Cap.save(root, "res://tests/out/nuke_4_zone_zh.png")
	await _until(nk, float(nk.zones[4].t) + 0.3)
	Cap.save(root, "res://tests/out/nuke_5_zone_far_zh.png")
	await _until(nk, nk.t_card - 0.6)
	Cap.save(root, "res://tests/out/nuke_6_wide_zh.png")
	await _until(nk, nk.t_card + nk.T_FADE + 2.0)
	Cap.save(root, "res://tests/out/nuke_7_card_zh.png")
	# frame times through the cinematic (screenshot frames left out)
	var ft: Array = frames.filter(func(x): return x < 300.0)
	ft.sort()
	var avg := 0.0
	for x in ft:
		avg += x
	avg /= maxf(1.0, ft.size())
	print("NUKE FRAMES n %d avg %.1f ms p95 %.1f ms p99 %.1f ms max %.1f ms" % [ft.size(), avg, ft[int(ft.size() * 0.95)], ft[int(ft.size() * 0.99)], ft[ft.size() - 1]])
	for ph in by:
		var a: Array = by[ph].filter(func(x): return x < 300.0)
		a.sort()
		print("  %s n %d p50 %.1f p95 %.1f max %.1f" % [ph, a.size(), a[a.size() / 2], a[int(a.size() * 0.95)], a[a.size() - 1]])
	for lim in [[0.0, 2.6], [2.6, 10.0], [10.0, 13.5]]:
		for col in [1, 2, 3]:
			var xs: Array = gpu.filter(func(d): return d[0] >= lim[0] and d[0] < lim[1]).map(func(d): return d[col])
			xs.sort()
			if not xs.is_empty():
				print("  %s %.1f-%.1f s: p50 %.2f p95 %.2f max %.2f ms" % [["", "render cpu", "gpu", "physics"][col], lim[0], lim[1], xs[xs.size() / 2], xs[int(xs.size() * 0.95)], xs[xs.size() - 1]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	quit()
