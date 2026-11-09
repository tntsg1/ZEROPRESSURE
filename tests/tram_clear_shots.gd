extends "res://tests/perf_probe.gd"
# 接驳站穿模修复: every district's shuttle stop, the train standing at it, the drone inside the
# district (its inside drawn) — the same views before and after. Own test saves only.
#   tools/run_test.sh tests/tram_clear_shots.gd -- tag=before [zones=tug,trade]
const Cap = preload("res://tests/cap.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_tramclear_career.json"
	SaveGame.path = "user://zp_test_tramclear_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _look(at: Vector2, zoom: float, settle: int = 40) -> void:
	g.cam_override = at
	g.cam_pos = at
	g.zoom_override = zoom
	g.zoom_now = zoom
	await _frames(settle)


func _park(zone: String) -> void:
	var tr = g.get("tram")
	if tr == null:
		return
	tr.at = zone
	tr.path = []
	tr.position_px = Tram.station_at(zone)
	tr._settle(zone)
	tr._poses()
	tr._poses()


func _run() -> void:
	var tag := _arg("tag", "now")
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.money = 300000.0
	var st := int(_arg("stage", "2"))
	Career.data.port = {"salvage": st, "trade": st, "process": st, "power": st, "tug": st, "cargo": st, "ring": st}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "port_tour": true}
	Career.data.tram_found = ["power", "tug", "process", "trade", "cargo"]
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	var m := PortStructure.M()
	var zones: Array = _arg("zones", "tug,trade,power,process,cargo,salvage").split(",")
	for zone in zones:
		var sp := Tram.station_at(zone)
		_park(zone)
		if zone == "salvage":
			g.drone.global_position = sp + Vector2(0, -6) * m
		else:
			var box: Rect2 = PortStructure.box(zone)
			# the drone inside, away from the stop (the district's inside is drawn while it is in)
			g.drone.global_position = box.get_center() + (box.get_center() - sp).normalized() * 8.0 * m
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(10)
		_park(zone)
		if zone != "salvage":
			var box2: Rect2 = PortStructure.box(zone)
			await _look(box2.get_center(), 1920.0 / (box2.size.x * 1.08), 60)
			Cap.save(root, "res://tests/out/tramclear_%s_%s_whole.png" % [zone, tag])
		# the stop and its train (close), then the whole line into the district (the freight stop's)
		await _look(sp - Tram.station_dir(zone) * 2.0 * m, 1920.0 / (22.0 * m), 40)
		Cap.save(root, "res://tests/out/tramclear_%s_%s_close.png" % [zone, tag])
		await _look(sp - Tram.station_dir(zone) * 10.0 * m, 1920.0 / (36.0 * m), 40)
		Cap.save(root, "res://tests/out/tramclear_%s_%s_lane.png" % [zone, tag])
	quit()
