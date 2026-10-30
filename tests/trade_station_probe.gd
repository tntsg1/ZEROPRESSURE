extends "res://tests/perf_probe.gd"
# 98 号: the trade district, inside and out — shots at the usual zooms and the frame it costs
# (1920x1080, vsync off, no cap). Own test saves only.
#   tools/run_test.sh tests/trade_station_probe.gd -- tag=before [perf=1]
const Cap = preload("res://tests/cap.gd")
const Ex = preload("res://scripts/industrial_exchange.gd")
const TW = preload("res://scripts/trade_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_trade98_career.json"
	SaveGame.path = "user://zp_test_trade98_save.json"
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
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": int(_arg("stage", "1")), "process": 1, "power": 1, "tug": 1, "cargo": 1}
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
	Ex.command("view")
	TW.record()
	var box: Rect2 = PortStructure.box("trade")
	var m := PortStructure.M()
	g.drone.global_position = box.position + Vector2(10, 16) * m
	g.drone.linear_velocity = Vector2.ZERO
	var whole := 1920.0 / (box.size.x * 1.08)
	await _look(box.get_center(), whole, 90)
	Cap.save(root, "res://tests/out/trade98_%s_inside.png" % tag)
	if perf:
		print(line("贸易港 站内全景", await measure(300)))
	await _look(box.position + Vector2(32, 9) * m, whole * 2.0)
	Cap.save(root, "res://tests/out/trade98_%s_counters.png" % tag)
	await _look(box.position + Vector2(36, 22) * m, whole * 2.0)
	Cap.save(root, "res://tests/out/trade98_%s_board.png" % tag)
	# a visitor, and a buy from a port counter: the dock at work
	if _arg("work", "1") == "1":
		TradePeople.arrive()
		var th = g.trade_hall
		g.drone.global_position = th.counter_spot(0)
		var st: Dictionary = Career.data.exchange
		# billets in the warehouse, sold to a port company: the dock loads its lighter
		st.actors.company.lots["TEST-BIL"] = {"id": "TEST-BIL", "key": "steel_billet:1", "available": 2.0, "total": 2.0, "origin": "manufactured"}
		st.actors.company.stock["steel_billet:1"] = float(st.actors.company.stock.get("steel_billet:1", 0.0)) + 2.0
		print("sell: ", Ex.command("post", {"side": "sell", "item": "steel_billet", "grade": 1, "quantity": 2.0, "price": 1000.0}).ok)
		await _look(box.get_center(), whole, 10)
		for i in int(_arg("shots", "6")):
			await create_timer(4.0).timeout
			Cap.save(root, "res://tests/out/trade98_%s_work%02d.png" % [tag, i])
			if i == 1 and perf:
				print(line("贸易港 作业中", await measure(300)))
				print("贸易港自身 CPU：状态机 %.0f µs/帧，动态部分绘制 %.0f µs/帧" % [g.trade_hall.tick_us, g.trade_hall.draw_us])
		await _look(box.position + Vector2(40, 21) * m, whole * 2.0, 30)
		Cap.save(root, "res://tests/out/trade98_%s_dock.png" % tag)
		# the hover card over the weighbridge (a probe point: the mouse is never moved)
		await _look(box.get_center(), whole, 20)
		g.trade_hall.card.probe = box.position + Vector2(29.0, 23.0) * m
		await create_timer(0.8).timeout
		Cap.save(root, "res://tests/out/trade98_%s_card.png" % tag)
		g.trade_hall.card.probe = Vector2.INF
		# at a counter: the video link
		g.drone.global_position = g.trade_hall.counter_spot(1)
		await _look(box.position + Vector2(36, 9) * m, whole * 2.4, 60)
		Cap.save(root, "res://tests/out/trade98_%s_counter.png" % tag)
	g.drone.global_position = box.position + Vector2(30, -20) * m
	await _frames(10)
	await _look(box.get_center() + Vector2(10, 0) * m, 1920.0 / (box.size.x * 1.7), 60)
	Cap.save(root, "res://tests/out/trade98_%s_outside.png" % tag)
	if perf:
		print(line("贸易港 外观", await measure(300)))
	quit()
