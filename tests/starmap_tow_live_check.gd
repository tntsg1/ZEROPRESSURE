extends "res://tests/guide_check.gd"
# The tow goes on while the star map is open (user 2026-11-05, 截图：“S-001 · 货运吊舱 · 拖运途中 · 约 12 秒到港”：
# “它也没倒计时啊，就是单纯写了 12 秒，之后也没变过。”): the map open for 5 s, the countdown on the row
# and on the way line drops by 4 s or more, the tug moves; on docking the row says so and a line says
# where to go. Own test saves only.
#   tools/run_test.sh tests/starmap_tow_live_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_tow_live_career.json"
	SaveGame.path = "user://zp_test_tow_live_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


func _texts(sm) -> Array:
	var out: Array = []
	for c in sm.find_box.find_children("*", "", true, false):
		if c.is_queued_for_deletion():
			continue
		if c is Button or c is Label:
			out.append(str(c.text))
	return out


# the first number before 秒 in a text with the key in it
func _secs(sm, key: String) -> int:
	var re := RegEx.new()
	re.compile("约 (\\d+) 秒")
	for t in _texts(sm):
		if key in t:
			var m := re.search(t)
			if m != null:
				return int(m.get_string(1))
	return -1


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true, "tow_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	g.open_star_map("find")
	await _frames(20)
	var sm = g.console_ui
	var near: int = Scan.order()[0]
	sm.sel_sector = near
	Scan.sweep(near)
	Scan.advance(Scan.SWEEP_S + 0.5)
	for sg in Scan.signals(near):
		Scan.analyze(str(sg.id))
		Scan.advance(Scan.ANALYZE_S + 0.5)
	sm._sig_key = ""
	sm._fill()
	await _frames(10)
	var send: Button = null
	for b in sm.find_box.find_children("*", "Button", true, false):
		if not b.disabled and not b.is_queued_for_deletion() and "派拖船去拖" in b.text:
			send = b
			break
	check(send != null, "a tug button to press")
	if send == null:
		quit(1)
		return
	var sig := str(send.text).get_slice(" · ", 0)
	send.pressed.emit()
	await _frames(20)
	check(g.console_ui == sm and not ShipMarket.on_the_way().is_empty(), "the tug is on its way, the map still open")
	var aid := str(ShipMarket.on_the_way()[0].id)
	var row0 := _secs(sm, "拖运途中")
	var way0 := _secs(sm, "在路上")
	var next0 := str(sm.next_line())
	var au0: Vector2 = sm._tow_au(aid)
	var left0 := float(ShipMarket.on_the_way()[0].left_s)
	check(not next0.contains("关掉星图它才走"), "the next-step line does not say the tug waits for the map to close (%s)" % next0)
	await _wait_s(5.0)
	var row1 := _secs(sm, "拖运途中")
	var way1 := _secs(sm, "在路上")
	var au1: Vector2 = sm._tow_au(aid)
	var left1 := float(ShipMarket.on_the_way()[0].left_s) if not ShipMarket.on_the_way().is_empty() else 0.0
	check(left0 - left1 >= 4.0, "the tow's clock ran with the map open (%.1f → %.1f s)" % [left0, left1])
	check(row0 > 0 and row0 - row1 >= 4, "the row's countdown dropped by 4 s or more (%d → %d)" % [row0, row1])
	check(way0 > 0 and way0 - way1 >= 4, "the on-the-way line's countdown dropped by 4 s or more (%d → %d)" % [way0, way1])
	check(au0.is_finite() and au1.is_finite() and au0.distance_to(au1) > 0.001, "the tug moved on the map (%.4f AU)" % au0.distance_to(au1))
	Cap.save(root, "res://tests/out/starmap_tow_live.png")
	# on to the dock: the row says it is home and a line says where to go
	var n := 0
	while not ShipMarket.on_the_way().is_empty() and n < 3000:
		n += 1
		await process_frame
	# the page looks again every 0.5 s
	await _wait_s(0.7)
	var all := "\n".join(_texts(sm))
	check(all.contains("%s · " % sig) and all.contains("已到港"), "docked: its row says 已到港")
	check(all.contains("%s 已到港 · 去船坞开工" % sig), "and a line says where to go (%s)" % sig)
	check(sm._docked_flash(sig) > 0.0, "the row flashes")
	Cap.save(root, "res://tests/out/starmap_tow_docked.png")
	print("STARMAP TOW LIVE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
