extends "res://tests/guide_check.gd"
# Frame time with the star map open (find page): idle, mid-sweep, signals found, pointer on a
# station. vsync off, wall clock over 120 frames. Own test saves only.
#   tools/run_test.sh tests/starmap_perf.gd


func _initialize() -> void:
	Career.path = "user://zp_test_starmap_perf_career.json"
	SaveGame.path = "user://zp_test_starmap_perf_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wall(n: int = 120) -> Array:
	await _frames(20)
	var ts: Array = []
	var t0 := Time.get_ticks_usec()
	for i in n:
		var a := Time.get_ticks_usec()
		await process_frame
		ts.append((Time.get_ticks_usec() - a) / 1000.0)
	ts.sort()
	return [(Time.get_ticks_usec() - t0) / 1000.0 / n, ts[int(n * 0.95)], ts[n - 1]]


func _p(name: String, r: Array) -> void:
	print("STARMAP PERF %-16s avg %6.2f ms  p95 %6.2f  max %6.2f" % [name, r[0], r[1], r[2]])


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	# the opening: the worst frame of the first 30 (shaders are compiled on first use)
	var worst := 0.0
	g.open_star_map("find")
	for i in 30:
		var a := Time.get_ticks_usec()
		await process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - a) / 1000.0)
	print("STARMAP PERF open, worst frame   %6.2f ms" % worst)
	var sm = g.console_ui
	_p("idle", await _wall())
	var near: int = Scan.order()[0]
	sm.sel_sector = near
	Scan.sweep(near)
	Scan.advance(Scan.SWEEP_S * 0.3)
	sm._sig_key = ""
	_p("sweeping", await _wall())
	Scan.advance(Scan.SWEEP_S)
	for sg in Scan.signals(near):
		Scan.analyze(str(sg.id))
		Scan.advance(Scan.ANALYZE_S + 0.5)
	sm._sig_key = ""
	_p("found", await _wall())
	var other: int = Scan.order()[1]
	sm.mouse = sm._to(Orbits.pos(Orbits.station(other), Shipping.day()))
	_p("hover", await _wall())
	quit()
