extends "res://tests/guide132_check.gd"
# 132 号: about 40 s — at the trade port the power runs short: the paused card (电力不足—功率 19%, the
# drawing moving), "带我去" to the power district's console; then the new pages one by one: the trade
# port's console (the haggle folded, opened), the exchange's orders, the processing queue, the gas
# console, the furnace desk and the mill as cards. Own test saves only.
#   tools/run_test.sh tests/record_132.gd --write-movie recordings/zeropressure_132.avi --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_rec132_career.json"
	SaveGame.path = "user://zp_test_rec132_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _s(sec: float) -> void:
	await _frames(int(sec * 60.0))


func _tap(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev)


func _run() -> void:
	_career()
	Career.data.port["tug"] = 1
	HallMarket.data().orders = []
	Txt.guide_cards = true
	GC.force_on = true
	GC.reset()
	# only the power card this time: the rest seen already
	var gs := {}
	for id in GC.CARDS:
		if id != "power_short":
			gs[id] = 1
	Career.data.guide_seen = gs
	await _spawn()
	await _frames(10)
	g.drone.global_position = PortStructure.console_spot("trade")
	g.drone.linear_velocity = Vector2.ZERO
	_put(PortStructure.console_spot("trade") + Vector2(-6.0, 3.0) * Geom.M, 0.9)
	_trade_pier()
	await _s(1.5)
	# the power runs short at the trade port
	GC.test_due["power_short"] = {"n": 19, "who": "拆船区排第一，先拿满；加工区功率 8%，贸易港功率 0%。", "groups": [["拆船区", 100], ["加工区", 8], ["贸易港", 0]]}
	GC._gap = 999.0
	await _s(6.0)
	_tap(KEY_ENTER)
	GC.test_due = {}
	await _s(3.2)
	_tap(KEY_ESCAPE)
	await _s(0.8)
	# the trade port's console
	g.open_district("trade")
	await _s(2.6)
	var d = g.console_ui
	if d != null and d.get("trade_box") != null:
		d._haggle_open = true
		d._trade_sig = ""
	await _s(2.6)
	_tap(KEY_ESCAPE)
	await _s(0.6)
	# the exchange's orders
	_orders()
	g.open_hall("orders")
	await _s(4.2)
	_tap(KEY_ESCAPE)
	await _s(0.8)
	# the processing district: the queue, the gas console, the furnace desk, the mill
	ProcessLine.queue_ingots(2.0)
	ProcessLine.queue_ingots(4.0)
	ProcessLine.queue_ingots(2.0, {"kind": "sell"}, "small")
	var Gal = preload("res://scripts/process_gallery.gd")
	g.drone.global_position = Gal.term("furnace")
	_put(PortStructure.box("process").position + Vector2(20.0, 18.0) * Geom.M, 0.7)
	await _s(0.8)
	g.open_queue_panel()
	await _s(3.6)
	_tap(KEY_ESCAPE)
	await _s(0.5)
	Career.data.upgrades["gas_line"] = 1
	Career.data.upgrades["lox_tank"] = 1
	GasLine.receive({"o2": 13.0, "n2": 45.0}, "TUG-001")
	GasLine.data().o2.ind = 420.0
	GasLine.data().lox.kg = 3600.0
	g.open_district("process")
	await _s(3.6)
	_tap(KEY_ESCAPE)
	await _s(0.5)
	g.drone.global_position = g.industrial_heat.site()
	_put(g.industrial_heat.site() + Vector2(4.0, 4.0) * Geom.M, 0.85)
	await _s(0.8)
	g.open_heat()
	await _s(3.4)
	_tap(KEY_ESCAPE)
	await _s(0.5)
	Career.data.exchange.actors.company.stock[Mill.FEED] = 2.0
	g.drone.global_position = preload("res://scripts/mill_line.gd").pedestal()
	_put(preload("res://scripts/mill_line.gd").pedestal() + Vector2(2.0, 4.0) * Geom.M, 0.85)
	await _s(0.8)
	g.open_mill()
	await _s(3.6)
	_tap(KEY_ESCAPE)
	await _s(0.8)
	g.queue_free()
	await _frames(4)
	quit()
