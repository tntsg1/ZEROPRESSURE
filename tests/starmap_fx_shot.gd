extends "res://tests/guide_check.gd"
# 2026-11-04 星图视觉重做：默认态、悬停星站、扫描中、信号分析中、找到船、航运页，1920x1080。
# 只用测试存档。tools/run_test.sh tests/starmap_fx_shot.gd


func _initialize() -> void:
	Career.path = "user://zp_test_starmap_fx_career.json"
	SaveGame.path = "user://zp_test_starmap_fx_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true, "tow_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	g.open_star_map("find")
	await _frames(60)
	var sm = g.console_ui
	var day := Shipping.day()
	# default: the pointer resting over empty space in the belt (the plot lights round it)
	sm.mouse = sm._to(Vector2(-1.2, -1.6))
	await _frames(30)
	Cap.save(root, "res://tests/out/starmap_fx_default.png")
	# hover a station
	var other: int = Scan.order()[1]
	sm.mouse = sm._to(Orbits.pos(Orbits.station(other), Shipping.day()))
	await _wait_s(0.2)
	Cap.save(root, "res://tests/out/starmap_fx_hover_morph.png")
	await _wait_s(0.9)
	Cap.save(root, "res://tests/out/starmap_fx_hover.png")
	check(str(sm.hover.get("key", "")) == "st%d" % other, "the pointer on a station locks on it")
	# the sweep
	sm.mouse = Vector2(-99999, -99999)
	var near: int = Scan.order()[0]
	sm.sel_sector = near
	Scan.sweep(near)
	Scan.advance(Scan.SWEEP_S * 0.45)
	sm._sig_key = ""
	sm._fill()
	await _frames(40)
	Cap.save(root, "res://tests/out/starmap_fx_sweep.png")
	# analysing a signal
	Scan.advance(Scan.SWEEP_S)
	var sigs: Array = Scan.signals(near)
	sm.sel_sig = str(sigs[0].id)
	Scan.analyze(str(sigs[0].id))
	Scan.advance(Scan.ANALYZE_S * 0.55)
	sm._sig_key = ""
	sm._fill()
	await _wait_s(0.5)
	Cap.save(root, "res://tests/out/starmap_fx_analyse.png")
	# the analysis lands: the diamond morphs, the name rises
	Scan.advance(Scan.ANALYZE_S)
	await _wait_s(0.22)
	Cap.save(root, "res://tests/out/starmap_fx_morph.png")
	await _wait_s(0.35)
	Cap.save(root, "res://tests/out/starmap_fx_rise.png")
	# all analysed: hulks found
	for sg in Scan.signals(near):
		if not sg.get("known", false):
			Scan.analyze(str(sg.id))
			Scan.advance(Scan.ANALYZE_S + 0.5)
	sm._sig_key = ""
	sm._fill()
	await _wait_s(2.6)
	Cap.save(root, "res://tests/out/starmap_fx_found.png")
	# the radar's labels: no two boxes overlap (checked over a second of frames, the blips drifting)
	var clash := ""
	for f in 60:
		await process_frame
		var boxes: Array = sm.inset_labels
		for x in boxes.size():
			for y in range(x + 1, boxes.size()):
				if (boxes[x] as Rect2).intersects(boxes[y]):
					clash = "%s / %s" % [boxes[x], boxes[y]]
	check(clash == "" and sm.inset_labels.size() >= 2, "no two radar labels overlap (%d labels%s)" % [sm.inset_labels.size(), "" if clash == "" else ", clash " + clash])
	# the pointer over the column (#154): the rows round it lit, their edges glowing
	var row: Button = null
	for b in sm.find_box.find_children("*", "Button", true, false):
		if not b.is_queued_for_deletion() and "派拖船去拖" in b.text:
			row = b
			break
	if row != null:
		sm.shot_mouse = row.global_position + Vector2(row.size.x * 0.7, row.size.y + 4.0)
		await _frames(10)
		Cap.save(root, "res://tests/out/starmap_fx_panel_hover.png")
		sm.shot_mouse = Vector2.INF
	# send the tug: its route draws itself on
	var send: Button = null
	for b in sm.find_box.find_children("*", "Button", true, false):
		if not b.disabled and not b.is_queued_for_deletion() and "派拖船去拖" in b.text:
			send = b
			break
	check(send != null, "a tug button to press")
	if send != null:
		send.pressed.emit()
		await _wait_s(1.1)
		Cap.save(root, "res://tests/out/starmap_fx_tow.png")
		await _wait_s(1.6)
		Cap.save(root, "res://tests/out/starmap_fx_towing.png")
	# the shipping page
	sm.set_mode("ships")
	await _frames(40)
	Cap.save(root, "res://tests/out/starmap_fx_ships.png")
	print("STARMAP FX SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
