extends "res://tests/guide_check.gd"
# 2026-11-04 工作台通用动效：供电控制屏的帧时间。打开那一帧（前 30 帧最差）、静止、悬停按钮、
# 展开推开过程中、展开后静止、关闭那一帧。关垂直同步，墙钟，测试存档。旧版对照：临时换回旧文件跑同一脚本。
#   tools/run_test.sh tests/bench_power_perf.gd


func _initialize() -> void:
	Career.path = "user://zp_test_bench_perf_career.json"
	SaveGame.path = "user://zp_test_bench_perf_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wall(n: int = 120, settle: int = 20) -> Array:
	await _frames(settle)
	var ts: Array = []
	var t0 := Time.get_ticks_usec()
	for i in n:
		var a := Time.get_ticks_usec()
		await process_frame
		ts.append((Time.get_ticks_usec() - a) / 1000.0)
	ts.sort()
	return [(Time.get_ticks_usec() - t0) / 1000.0 / n, ts[int(n * 0.95)], ts[n - 1]]


func _p(name: String, r: Array) -> void:
	print("BENCH PERF %-14s avg %6.2f ms  p95 %6.2f  max %6.2f" % [name, r[0], r[1], r[2]])


func _worst(n: int) -> float:
	var worst := 0.0
	for i in n:
		var a := Time.get_ticks_usec()
		await process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - a) / 1000.0)
	return worst


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Txt.zh = true
	Txt.reduce_motion = false
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.save()
	await _spawn()
	await _frames(30)
	_p("world", await _wall())
	for round in 2:
		var a := Time.get_ticks_usec()
		g.open_power_screen()
		var call_ms := (Time.get_ticks_usec() - a) / 1000.0
		var w := await _worst(30)
		print("BENCH PERF open #%d: build %.2f ms, worst of first 30 frames %.2f ms" % [round + 1, call_ms, w])
		var ui = g.console_ui
		_p("idle", await _wall())
		var b: Button = ui.shore_key
		BenchFx.shot_mouse = b.global_position + Vector2(40, 20)
		_p("hover", await _wall(120, 2))
		BenchFx.shot_mouse = Vector2.INF
		await _frames(30)
		ui.details_key.pressed.emit()
		_p("fold opening", await _wall(24, 0))
		_p("details open", await _wall())
		a = Time.get_ticks_usec()
		ui.close()
		print("BENCH PERF close: call %.2f ms, worst of next 30 frames %.2f ms" % [(Time.get_ticks_usec() - a) / 1000.0, await _worst(30)])
		await _frames(30)
	quit()
