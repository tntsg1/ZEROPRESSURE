extends SceneTree
# 108 号 帧率 (user 2026-10-30: "精细化是精细化了，但是帧率还是太低了"; 60 FPS is the release bar):
# the frame time at each place the player stands — the berth, the ring, every district's console,
# the shuttle stops — averaged and P95 over 120 frames, vsync off, at 1920x1080. Then, at the worst
# place, every drawing layer of the game hidden in turn (and its process stopped): what each costs.
#   tools/run_test.sh tests/fps108_survey.gd -- [layers]
const PortStructure = preload("res://scripts/port_structure.gd")
var g: Node


func _initialize() -> void:
	Career.path = "user://zp_test_fps108_career.json"
	SaveGame.path = "user://zp_test_fps108_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _measure(n := 120) -> Array:
	await _frames(30)
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		ts.append((now - last) / 1000.0)
		last = now
	ts.sort()
	var avg := 0.0
	for x in ts:
		avg += x
	return [avg / ts.size(), ts[int(ts.size() * 0.95)], ts[-1]]


func _at(p: Vector2) -> void:
	g.drone.global_position = p
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(45)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.market = true
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.walk_v = 2
	Career.data.port = {"power": 1, "salvage": 1, "process": 1, "tug": 1, "trade": 1, "cargo": 1, "ring": 1}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(60)
	g.tutorial = null
	var places := [["berth", Dock.centre() * Geom.M], ["ring", Backdrop.port_centre_px()], ["ring_stop", Tram.station_at("ring")]]
	for z in ["power", "tug", "cargo", "trade", "process"]:
		places.append([z, PortStructure.console_spot(z)])
		places.append([z + "_stop", Tram.station_at(z)])
	var worst := ""
	var worst_ms := 0.0
	var worst_at := Vector2.ZERO
	for pl in places if not ("layers" in OS.get_cmdline_user_args() or "prof" in OS.get_cmdline_user_args()) else []:
		await _at(pl[1])
		var m: Array = await _measure()
		print("PLACE %-12s avg %6.2f ms  p95 %6.2f ms  max %6.2f ms" % [pl[0], m[0], m[1], m[2]])
		if float(m[0]) > worst_ms:
			worst_ms = float(m[0])
			worst = str(pl[0])
			worst_at = pl[1]
	print("WORST %s %.2f ms" % [worst, worst_ms])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("at="):
			for pl in places:
				if str(pl[0]) == a.substr(3):
					worst = str(pl[0])
					worst_at = pl[1]
	if "prof" in OS.get_cmdline_user_args():
		await _at(worst_at)
		await _frames(30)
		Prof.reset()
		var t0 := Time.get_ticks_usec()
		for i in 120:
			await process_frame
			Prof.roll()
		var wall := (Time.get_ticks_usec() - t0) / 1000.0 / 120.0
		var keys: Array = Prof.sum.keys()
		keys.sort_custom(func(a, b): return Prof.sum[a] > Prof.sum[b])
		print("PROF at %s: frame %.2f ms" % [worst, wall])
		for k in keys.slice(0, 22):
			print("  %-34s avg %6.3f ms  peak %6.3f ms" % [k, Prof.sum[k] / 1000.0 / 120.0, Prof.peak[k] / 1000.0])
	if "layers" in OS.get_cmdline_user_args():
		await _at(worst_at)
		var base: Array = await _measure()
		print("LAYERS at %s, all on: %.2f ms" % [worst, base[0]])
		print("  monitors: process %.2f ms · physics %.2f ms · draw calls %d · canvas items %d · objects %d · nodes %d" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		for c in g.get_children():
			if not c is CanvasItem or not c.visible:
				continue
			c.visible = false
			var was_p: bool = c.is_processing()
			c.set_process(false)
			var m2: Array = await _measure(90)
			var sp: String = c.get_script().resource_path.get_file() if c.get_script() != null else c.get_class()
			print("  hide %-28s %6.2f ms  (saves %5.2f)  process %.2f ms" % [sp, m2[0], base[0] - m2[0], Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
			c.visible = true
			c.set_process(was_p)
	print("FPS108 SURVEY DONE")
	quit()
