extends "res://tests/seg4_sketch.gd"
# 2026-11-07 加工区面板重做: about 20 s — the processing queue opened empty, Enter queues a heat, the cards with
# batches, a card dragged, closed; the processing console opened, Enter starts the separation, 更多 unfolded,
# Esc folds it and closes. Own test saves only.
#   tools/run_test.sh tests/record_seg4_panels.gd --write-movie recordings/zeropressure_seg4_panels.avi --fixed-fps 60

func _initialize() -> void:
	Career.path = "user://zp_test_recpan_career.json"
	SaveGame.path = "user://zp_test_recpan_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev)


func _s(sec: float) -> void:
	await _frames(int(sec * 60.0))


func _run() -> void:
	_career()
	HallMarket.data().orders = []
	await _spawn()
	await _frames(10)
	_put(PortStructure.box("process").position + Vector2(20.0, 18.0) * Geom.M, 0.7)
	await _s(0.6)
	g.open_queue_panel()
	await _s(2.4)
	BenchFx.shot_mouse = g.console_ui._btns["one"].get_center()
	await _s(0.8)
	_key(KEY_ENTER)
	await _s(1.6)
	BenchFx.shot_mouse = Vector2.INF
	ProcessLine.queue_ingots(4.0)
	ProcessLine.queue_ingots(2.0, {"kind": "sell"}, "small")
	await _s(2.0)
	var lots: Array = ProcessQueue.open_entries().map(func(e): return str(e.lot))
	g.console_ui.test_drag(lots[2], 1)
	await _s(1.8)
	_key(KEY_ESCAPE)
	await _s(1.0)
	Career.data.upgrades["gas_line"] = 1
	Career.data.upgrades["lox_tank"] = 1
	GasLine.receive({"o2": 13.0, "n2": 45.0}, "TUG-001")
	GasLine.receive({"o2": 52.0, "n2": 174.0}, "S09-001")
	GasLine.data().o2.ind = 420.0
	GasLine.data().lox.kg = 3600.0
	g.open_district("process")
	await _s(2.4)
	BenchFx.shot_mouse = g.console_ui.next_key.get_global_rect().get_center()
	await _s(0.8)
	_key(KEY_ENTER)
	await _s(1.6)
	BenchFx.shot_mouse = Vector2.INF
	g.console_ui.more_key.pressed.emit()
	await _s(2.4)
	_key(KEY_ESCAPE)
	await _s(1.0)
	_key(KEY_ESCAPE)
	await _s(1.0)
	print("RECORD PANELS DONE")
	g.queue_free()
	await _frames(4)
	quit()
