extends "res://tests/perf_probe.gd"
# 100 号: the power district, inside and out — shots at the usual zooms and the frame it costs
# (1920x1080, vsync off, no cap). Own test saves only.
#   tools/run_test.sh tests/power_station_probe.gd -- tag=before [perf=1] [stage=1]
const Cap = preload("res://tests/cap.gd")
const PW = preload("res://scripts/power_works.gd")


# a test load on the bus (a furnace's worth in the processing district)
class TestLoad extends Node:
	var mw := 0.0
	var group := "process"
	func grid_loads() -> Array:
		return [{"id": "test_load", "name": "TEST", "group": group, "rated": mw, "demand": mw, "mw_now": -1.0, "state": "run"}] if mw > 0.0 else []


func _initialize() -> void:
	Career.path = "user://zp_test_power100_career.json"
	SaveGame.path = "user://zp_test_power100_save.json"
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
	Engine.max_fps = 0
	var tag := _arg("tag", "now")
	var perf := _arg("perf", "1") == "1"
	var stage := int(_arg("stage", "1"))
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": stage, "tug": 1, "cargo": 1}
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
	var box: Rect2 = PortStructure.box("power")
	var m := PortStructure.M()
	g.drone.global_position = box.position + Vector2(30, 16) * m
	g.drone.linear_velocity = Vector2.ZERO
	var whole := 1920.0 / (box.size.x * 1.08)
	await _look(box.get_center(), whole, 90)
	Cap.save(root, "res://tests/out/power100_%s_s%d_inside.png" % [tag, stage])
	if perf:
		print(line("动力区 站内全景", await measure(300)))
	await _look(box.position + Vector2(15, 12) * m, whole * 2.0)
	Cap.save(root, "res://tests/out/power100_%s_s%d_reactors.png" % [tag, stage])
	await _look(box.position + Vector2(46, 16) * m, whole * 2.0)
	Cap.save(root, "res://tests/out/power100_%s_s%d_turbine.png" % [tag, stage])
	if _arg("work", "1") == "1" and stage >= 1:
		var tl := TestLoad.new()
		root.add_child(tl)
		Grid.add_load_source(tl)
		await _look(box.get_center(), whole, 10)
		tl.mw = 20.0
		for i in 3:
			await create_timer(2.5).timeout
			Cap.save(root, "res://tests/out/power100_%s_s%d_load%02d.png" % [tag, stage, i])
		if perf:
			print(line("动力区 带载", await measure(300)))
			print("动力区自身 CPU：状态机 %.0f µs/帧，动态部分绘制 %.0f µs/帧" % [g.port_structure.interiors.power_tick_us, g.port_structure.interiors.power_draw_us])
		PW.start_fault("feed")
		await create_timer(2.0).timeout
		await _look(box.position + Vector2(15, 20) * m, whole * 2.0, 10)
		Cap.save(root, "res://tests/out/power100_%s_s%d_fault.png" % [tag, stage])
		await _look(box.position + Vector2(46, 20) * m, whole * 2.0, 10)
		Cap.save(root, "res://tests/out/power100_%s_s%d_switch.png" % [tag, stage])
		# more than the plant gives: the shore line, its umbilical out
		Grid.set_ctl("line", "auto_shore")
		tl.mw = 36.0
		await create_timer(9.0).timeout
		await _look(box.get_center(), whole, 10)
		Cap.save(root, "res://tests/out/power100_%s_s%d_shore.png" % [tag, stage])
		g.port_structure.interiors.card.probe = box.position + Vector2(5.0, 10.0) * m
		await create_timer(0.8).timeout
		Cap.save(root, "res://tests/out/power100_%s_s%d_card.png" % [tag, stage])
		g.port_structure.interiors.card.probe = Vector2.INF
	g.drone.global_position = box.position + Vector2(30, -20) * m
	await _frames(10)
	await _look(box.get_center(), 1920.0 / (box.size.x * 2.6), 60)
	Cap.save(root, "res://tests/out/power100_%s_s%d_outside.png" % [tag, stage])
	if perf:
		print(line("动力区 外观", await measure(300)))
	quit()
