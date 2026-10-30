extends SceneTree
# Where a frame goes now (2026-10-24): the empty berth with the port lit, the port panorama,
# and a contract ship in view. Wall time per frame, script process/physics time, draw calls.
# tools/run_test.sh tests/perf_now.gd
var g: Node
func _initialize() -> void:
	Career.path = "user://zp_test_perfnow_career.json"
	SaveGame.path = "user://zp_test_perfnow_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()
func _frames(n: int) -> void:
	for i in n: await process_frame
func _measure(label: String, n: int = 120) -> void:
	await _frames(30)
	var t0 := Time.get_ticks_usec()
	var proc := 0.0
	var phys := 0.0
	var worst := 0.0
	var last := t0
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("PERF %-28s frame %6.2f ms (worst %6.2f) · process %6.2f · physics %6.2f · draws %d · objects %d · nodes %d" % [label, wall, worst, proc / n, phys / n, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.port = {"power": 1, "salvage": 1, "process": 1, "tug": 1, "trade": 2, "cargo": 1, "ring": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(10)
	await _measure("berth, drone view")
	g.zoom_target = 0.2
	g.zoom_now = 0.2
	await _measure("berth, zoomed out")
	g.port_view = true
	await _frames(120)
	await _measure("port panorama")
	g.port_view = false
	g.queue_free()
	await _frames(5)
	for ship in ["gr7", "fx70"]:
		Career.data.active = {}
		Game.start_ship = ship
		Game.contract = {}
		g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		await _frames(20)
		await _measure("contract %s, drone view" % ship)
		g.zoom_target = 0.25
		g.zoom_now = 0.25
		await _measure("contract %s, whole ship" % ship)
		g.queue_free()
		await _frames(5)
	quit()
