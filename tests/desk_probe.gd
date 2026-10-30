extends "res://tests/perf_probe.gd"
# 105 号: the stations' work desks — the furnace desk, the sorting desk, the assay bench, the berth
# terminal and parts rack, the cargo counter and rack mouths — near (lit) and as found. Own saves only.
#   tools/run_test.sh tests/desk_probe.gd -- tag=after
const Cap = preload("res://tests/cap.gd")
const PW = preload("res://scripts/power_works.gd")


# a test load on the bus (a furnace's worth in the processing district)
class TestLoad extends Node:
	var mw := 0.0
	var group := "process"
	func grid_loads() -> Array:
		return [{"id": "test_load", "name": "TEST", "group": group, "rated": mw, "demand": mw, "mw_now": -1.0, "state": "run"}] if mw > 0.0 else []


func _initialize() -> void:
	Career.path = "user://zp_test_desk104_career.json"
	SaveGame.path = "user://zp_test_desk104_save.json"
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
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "tug": 1, "cargo": int(_arg("cargo", "1")), "ring": 1}
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
	var zoom := 1920.0 / (60.0 * m * 1.08) * float(_arg("z", "2.4"))
	var spots := {}
	if g.industrial_heat != null:
		spots["furnace"] = g.industrial_heat.site()
	if g.industrial_sort != null:
		spots["sort"] = g.industrial_sort.site()
	if g.industrial_assay != null:
		spots["assay"] = g.industrial_assay.site()
	if g.consoles != null:
		spots["terminal"] = Consoles.centre(0)
		spots["rack"] = Consoles.rack_centre()
	if g.cargo_floor != null:
		spots["counter"] = g.cargo_floor.at(Vector2(23.2, 23.0))
		spots["mouth"] = g.cargo_floor.mouth("A")
	for k in spots:
		var p: Vector2 = spots[k]
		g.drone.global_position = p + Vector2(1.2, 0.4) * m
		g.drone.linear_velocity = Vector2.ZERO
		await _look(p + Vector2(0, -0.5) * m, zoom, 40)
		Cap.save(root, "res://tests/out/desk104_%s_%s.png" % [tag, k])
	quit()
