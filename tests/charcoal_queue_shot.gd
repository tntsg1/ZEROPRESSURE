extends "res://tests/seg4_sketch.gd"
# 炭黑 rollout: the processing queue (PRC-3) empty, with batches (a mould change between them, one
# in the furnace) and with 更多 open; Chinese or English; the frames while it opens. Own saves.
#   tools/run_test.sh tests/charcoal_queue_shot.gd --fixed-fps 60 -- tag=before [en]
var tag := "after"
var lang_en := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			tag = a.substr(4)
		elif a == "en":
			lang_en = true
	Career.path = "user://zp_test_cqueue_career.json"
	SaveGame.path = "user://zp_test_cqueue_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _snap(name: String) -> void:
	await _frames(3)
	Cap.save(root, "res://tests/out/queue_%s_%s_%s.png" % [tag, name, "en" if lang_en else "zh"])


func _run() -> void:
	_career()
	HallMarket.data().orders = []
	await _spawn()
	await _frames(10)
	Txt.zh = not lang_en
	g.open_queue_panel()
	var ft: Array = []
	var last := Time.get_ticks_usec()
	for i in 40:
		await process_frame
		var now := Time.get_ticks_usec()
		ft.append((now - last) / 1000.0)
		last = now
	ft.sort()
	print("QUEUE_FRAMES %s mean=%.2f p95=%.2f" % [tag, ft.reduce(func(x, y): return x + y, 0.0) / ft.size(), ft[int(ft.size() * 0.95)]])
	var q = g.console_ui
	await _snap("1_empty")
	ProcessLine.queue_ingots(4.0)
	ProcessLine.queue_ingots(2.0, {"kind": "sell"}, "small")
	ProcessLine.queue_ingots(3.0)
	for i in 60 * 6:
		await _frames(1)
	await _frames(20)
	await _snap("2_list")
	q.more_open = true
	await _frames(30)
	await _snap("3_more")
	# ---- real pointer: drag the third card to the top, click 更多, click the close key
	var fails := 0
	var lots: Array = ProcessQueue.open_entries().map(func(e): return str(e.lot))
	if lots.size() >= 3:
		var r3: Rect2 = q._btns.get("row:" + str(lots[2]), Rect2())
		var r1: Rect2 = q._btns.get("row:" + str(lots[0]), Rect2())
		var grip := r3.position + Vector2(30, r3.size.y * 0.5)
		await _mouse(grip, true)
		for k in 12:
			await _move(grip.lerp(Vector2(grip.x, r1.position.y + 4.0), (k + 1) / 12.0))
		await _mouse(Vector2(grip.x, r1.position.y + 4.0), false)
		await _frames(20)
		var now: Array = ProcessQueue.open_entries().map(func(e): return str(e.lot))
		var moved := now.find(str(lots[2])) < 2
		print("[%s] dragging the third card up with the pointer moves it (%s → %s)" % ["PASS" if moved else "FAIL", str(lots), str(now)])
		fails += 0 if moved else 1
	var was: bool = q.more_open
	await _mouse(Rect2(q._btns.get("more", Rect2())).get_center(), true)
	await _mouse(Rect2(q._btns.get("more", Rect2())).get_center(), false)
	await _frames(10)
	print("[%s] clicking 更多 folds it (%s → %s)" % ["PASS" if q.more_open != was else "FAIL", was, q.more_open])
	fails += 0 if q.more_open != was else 1
	var cr: Rect2 = q._btns.get("close", Rect2())
	await _mouse(cr.get_center(), true)
	await _mouse(cr.get_center(), false)
	await _frames(30)
	var shut: bool = g.console_ui == null or not is_instance_valid(q)
	print("[%s] clicking the close key closes it" % ("PASS" if shut else "FAIL"))
	fails += 0 if shut else 1
	print("QUEUE POINTER %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit()


func _move(p: Vector2) -> void:
	var at := root.get_final_transform() * p
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mv)
	await _frames(1)


func _mouse(p: Vector2, down: bool) -> void:
	await _move(p)
	var at := root.get_final_transform() * p
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	root.push_input(ev)
	await _frames(2)
