extends "res://tests/perf_probe.gd"
# 103 号: the consoles — at a console (lit, the hint), from across the district, at the edge of the
# view; every district and the mill pedestal. Own test saves only.
#   tools/run_test.sh tests/console_probe.gd -- tag=after
const Cap = preload("res://tests/cap.gd")
const PW = preload("res://scripts/power_works.gd")


# a test load on the bus (a furnace's worth in the processing district)
class TestLoad extends Node:
	var mw := 0.0
	var group := "process"
	func grid_loads() -> Array:
		return [{"id": "test_load", "name": "TEST", "group": group, "rated": mw, "demand": mw, "mw_now": -1.0, "state": "run"}] if mw > 0.0 else []


func _initialize() -> void:
	Career.path = "user://zp_test_console103_career.json"
	SaveGame.path = "user://zp_test_console103_save.json"
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


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var tag := _arg("tag", "now")
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "tug": 1, "cargo": 1, "ring": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "port_tour": true}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	Txt.zh = true
	var m := PortStructure.M()
	for zone in _arg("zones", "power,trade,cargo,process,tug").split(",", false):
		if zone == "none":
			continue
		var box: Rect2 = PortStructure.box(zone)
		var cs: Vector2 = PortStructure.console_spot(zone)
		var whole := 1920.0 / (box.size.x * 1.08)
		# across the district, then at it (lit), then with the console at the view's edge
		g.drone.global_position = box.position + Vector2(8, 22) * m
		g.drone.linear_velocity = Vector2.ZERO
		await _look(box.get_center(), whole, 40)
		Cap.save(root, "res://tests/out/console103_%s_%s_far.png" % [tag, zone])
		g.drone.global_position = cs + Vector2(1.5, 0.5) * m
		g.drone.linear_velocity = Vector2.ZERO
		await _look(cs + Vector2(0, -1) * m, whole * 3.0, 40)
		Cap.save(root, "res://tests/out/console103_%s_%s_near.png" % [tag, zone])
		await _look(cs + Vector2(-14, -6) * m, whole * 2.0, 30)
		Cap.save(root, "res://tests/out/console103_%s_%s_edge.png" % [tag, zone])
	# the mill pedestal
	if _arg("mill", "1") != "1":
		quit()
		return
	var mp: Vector2 = preload("res://scripts/mill_line.gd").pedestal()
	g.drone.global_position = mp + Vector2(1.5, 0.5) * m
	await _look(mp + Vector2(0, -1) * m, 1920.0 / (PortStructure.box("process").size.x * 1.08) * float(_arg("mz", "3")), 40)
	Cap.save(root, "res://tests/out/console103_%s_mill_near.png" % tag)
	quit()
