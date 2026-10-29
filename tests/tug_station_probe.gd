extends "res://tests/perf_probe.gd"
# 96 号: the tug station, inside and out — shots at the usual zooms and the frame it costs
# (1920x1080, vsync off, no cap: the real interval between frames, P95/P99). Own test saves only.
#   tools/run_test.sh tests/tug_station_probe.gd -- tag=before [stage=1] [perf=1]
const Cap = preload("res://tests/cap.gd")
const TugWorks = preload("res://scripts/tug_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_tug96_career.json"
	SaveGame.path = "user://zp_test_tug96_save.json"
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
	var stage := int(_arg("stage", "1"))
	var perf := _arg("perf", "1") == "1"
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "tug": stage, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk": true, "first_ship": true, "intro": true, "belt_prelude": true, "port_tour": true}
	Career.save()
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(20)
	g.tutorial = null
	if _arg("hide_tram", "0") == "1" and g.get("tram") != null:
		g.tram.visible = false
		g.tram.process_mode = Node.PROCESS_MODE_DISABLED
	var box: Rect2 = PortStructure.box("tug")
	var m := PortStructure.M()
	# inside: the drone by the tank, the whole shop in frame
	g.drone.global_position = box.position + Vector2(30, 14) * m
	g.drone.linear_velocity = Vector2.ZERO
	var whole := 1920.0 / (box.size.x * 1.08)
	await _look(box.get_center(), whole, 60)
	Cap.save(root, "res://tests/out/tug96_%s_inside.png" % tag)
	if perf:
		print(line("拖船站 站内全景", await measure(300)))
	if _arg("ab", "0") == "1":
		# the same view with each part switched off in turn: what each costs
		var it0 = g.port_structure.interiors
		var tr = g.get("tram")
		for round in 2:
			for case in ["all", "no_tram", "no_tug", "neither"]:
				if tr != null:
					tr.visible = case in ["all", "no_tug"]
				it0.visible = case in ["all", "no_tram"]
				it0.set_process(case in ["all", "no_tram"])
				await _frames(20)
				print(line("A/B %s" % case, await measure(240)))
		if tr != null:
			tr.visible = true
		it0.set_process(true)
		quit()
		return
	# close: the cradle and gantry, then the tank and rack
	await _look(box.position + Vector2(14, 15) * m, whole * 2.2)
	Cap.save(root, "res://tests/out/tug96_%s_cradle.png" % tag)
	await _look(box.position + Vector2(40, 14) * m, whole * 2.2)
	Cap.save(root, "res://tests/out/tug96_%s_rack.png" % tag)
	if perf:
		print(line("拖船站 站内近景", await measure(300)))
	# a hulk home, lying in the mouth (a test asset): its pre-processing; and a tug coming home
	var ship := _arg("ship", "gr7")
	if not Career.data.has("ship_market"):
		ShipMarket.data()
	Career.data.ship_market.assets.append({"id": "HULK-96", "ship": ship, "listing": {"offer": {"ship": ship}}, "state": "arrived",
		"seen_in": true, "yard": 0, "run": {}, "tow": 0.0, "price": 0.0, "claimed": false, "mind": {}, "tug": ""})
	TugWorks.homecoming(0)
	await _look(box.get_center(), whole, 10)
	var shots := int(_arg("shots", "10"))
	for i in shots:
		await create_timer(7.0).timeout
		Cap.save(root, "res://tests/out/tug96_%s_work%02d.png" % [tag, i])
		if i == 1 and perf:
			print(line("拖船站 作业中", await measure(300)))
			var itx = g.port_structure.interiors
			print("拖船站自身 CPU：状态机 %.0f µs/帧，动态部分绘制 %.0f µs/帧" % [itx.tug_tick_us, itx.tug_draw_us])
	await _look(box.position + Vector2(14, 16) * m, whole * 2.2, 60)
	Cap.save(root, "res://tests/out/tug96_%s_overhaul_close.png" % tag)
	# the hover card over the tank and over the mouth (a probe point: the mouth is never moved)
	var it2 = g.port_structure.interiors
	if it2 != null and it2.get("card") != null:
		await _look(box.get_center(), whole, 20)
		it2.card.probe = box.position + Vector2(44.6, 19.0) * m
		await _frames(30)
		await create_timer(0.6).timeout
		Cap.save(root, "res://tests/out/tug96_%s_card_tank.png" % tag)
		it2.card.probe = box.position + Vector2(8.0, 20.0) * m
		await create_timer(0.8).timeout
		Cap.save(root, "res://tests/out/tug96_%s_card_mouth.png" % tag)
		it2.card.probe = Vector2.INF
	# outside: the berths and the hall
	g.drone.global_position = box.position + Vector2(-30, 14) * m
	await _frames(10)
	await _look(box.get_center() - Vector2(10, 0) * m, 1920.0 / (box.size.x * 1.7), 60)
	Cap.save(root, "res://tests/out/tug96_%s_outside.png" % tag)
	await _look(box.position + Vector2(-7, 8) * m, whole * 1.8)
	Cap.save(root, "res://tests/out/tug96_%s_berth.png" % tag)
	if perf:
		print(line("拖船站 外观泊位", await measure(300)))
	quit()
