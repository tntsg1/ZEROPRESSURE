extends SceneTree
# 117 号 信息清理：字后暗晕（Hud.halo_on）开与关背靠背比帧时，同一船、同一镜头，轮流六轮。
# Own test saves only.
#   tools/run_test.sh tests/halo_perf.gd -- [ship]
const CoreAsset = preload("res://scripts/core_asset.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_haloperf_career.json"
	SaveGame.path = "user://zp_test_haloperf_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _pct(a: Array, q: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(s.size() * q), 0, s.size() - 1)]


func _run() -> void:
	var sid := "jd38"
	for a in OS.get_cmdline_user_args():
		sid = a
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 10: await process_frame
	g.job = {"id": "halo-perf", "ship": sid}
	for i in 90: await process_frame
	g.tutorial = null
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var by := {true: {"frame": [], "cpu": [], "proc": []}, false: {"frame": [], "cpu": [], "proc": []}}
	for round in 12:
		var on := round % 2 == 0
		Hud.halo_on = on
		for i in 20: await process_frame
		for i in 120:
			var t0 := Time.get_ticks_usec()
			await process_frame
			by[on].frame.append((Time.get_ticks_usec() - t0) / 1000.0)
			by[on].cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
			by[on].proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	Hud.halo_on = true
	for on in [false, true]:
		var d: Dictionary = by[on]
		print("halo %s  frame p50 %.2f p95 %.2f p99 %.2f ms · render cpu p50 %.2f p95 %.2f · process p50 %.2f p95 %.2f" % [
			"on " if on else "off", _pct(d.frame, 0.5), _pct(d.frame, 0.95), _pct(d.frame, 0.99),
			_pct(d.cpu, 0.5), _pct(d.cpu, 0.95), _pct(d.proc, 0.5), _pct(d.proc, 0.95)])
	quit(0)
