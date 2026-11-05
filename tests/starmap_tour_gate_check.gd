extends "res://tests/guide_check.gd"
# The star map's tour waits for what each step talks about (user 2026-11-05, 截图：扫描到 83%、一个信号都没出来，
# 卡片已经在讲“分析电磁特征”，右下角港区导览卡也在说话): from the sweep on, frame by frame, the analyse
# step's words never show before the signals do, Space never skips past a step not yet there, the lit
# frame is on what the card talks about, and the port walk's card is hidden while the map is open.
# Own test saves only.
#   tools/run_test.sh tests/starmap_tour_gate_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_tour_gate_career.json"
	SaveGame.path = "user://zp_test_tour_gate_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _space(sm) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	sm._input(ev)


func _card_text(sm) -> String:
	var c: Array = sm.tour_card()
	return "" if c.is_empty() else "%s %s" % [c[0], c[1]]


func _walk_card_on() -> bool:
	return g.port_walk != null and is_instance_valid(g.port_walk) and g.port_walk.layer != null and g.port_walk.layer.visible


func _lit_on(sm, c) -> bool:
	if c == null or not is_instance_valid(c):
		return false
	var r: Rect2 = sm._tour_rect(sm._tour_part())
	return r.grow(2.0).encloses(c.get_global_rect())


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	g.start_port_walk(false)
	await _frames(30)
	check(_walk_card_on(), "the port walk is on, its card shown")
	g.open_star_map("find")
	await _frames(12)
	var sm = g.console_ui
	check(sm.tour_on() and sm._tour_i == 0, "the star map's tour starts")
	check(not _walk_card_on(), "the star map open: the port walk's card is hidden (one voice at a time)")
	_space(sm)
	_space(sm)
	await _frames(3)
	check(sm._tour_i == 2, "space twice: the sweep step (%d)" % sm._tour_i)
	for k in 4:
		_space(sm)
	await _frames(3)
	check(sm._tour_i == 2, "space cannot skip past the sweep before it is started (%d: %s)" % [sm._tour_i, _card_text(sm)])
	check(_lit_on(sm, sm._tour_parts.get("sweep")), "the sweep step frames the sweep button")
	# the lit sweep button pressed (what a click on it does), the tour goes on
	var near: int = sm.sel_sector
	sm._tour_parts.sweep.pressed.emit()
	sm._tour_next(true)
	await _frames(2)
	check(Scan.busy() and sm._tour_i == 3, "the sweep started: on to the signals step (%d)" % sm._tour_i)
	# every frame until the sweep is done: no analyse words, Space pressed now and then
	var bad := ""
	var framed_bar := true
	var shot_mid := false
	var n := 0
	while sm._sweeping_here() and n < 2000:
		n += 1
		if n % 7 == 0:
			_space(sm)
		await process_frame
		var txt := _card_text(sm)
		if sm._sweeping_here() or Scan.signals(near).is_empty():
			if "分析" in txt or sm._tour_i > 3:
				bad = "frame %d step %d: %s" % [n, sm._tour_i, txt]
			if not _lit_on(sm, sm._tour_parts.get("sweep")):
				framed_bar = false
		if _walk_card_on():
			bad = "frame %d: the port walk's card is on over the star map" % n
		if not shot_mid and Scan.progress() > 0.8:
			shot_mid = true
			check(txt.contains("正在扫描，扫完会出现几个信号"), "sweeping: the card says it is sweeping (%s)" % txt)
			Cap.save(root, "res://tests/out/starmap_tour_sweeping.png")
	check(n > 30, "the sweep ran over %d frames" % n)
	check(bad == "", "while sweeping, no analyse words and no skipping ahead (%s)" % bad)
	check(framed_bar, "while sweeping, the frame is on the sweep's progress bar")
	await _frames(20)
	check(not Scan.signals(near).is_empty() and sm._tour_i == 3 and _card_text(sm).contains("信号点"), "swept: the signals step shows (%s)" % _card_text(sm))
	Cap.save(root, "res://tests/out/starmap_tour_swept.png")
	_space(sm)
	await _frames(4)
	check(sm._tour_i == 4 and _card_text(sm).contains("分析电磁特征"), "then the analyse step (%s)" % _card_text(sm))
	var rows: Array = sm._tour_parts.get("sigs", [])
	var all_in := rows.size() >= 2
	for c in rows:
		if not _lit_on(sm, c):
			all_in = false
	check(all_in and not _lit_on(sm, sm._tour_parts.get("sweep")), "the analyse step frames the signal rows (%d), not the sweep button" % rows.size())
	Cap.save(root, "res://tests/out/starmap_tour_analyse.png")
	for k in 3:
		_space(sm)
	await _frames(3)
	check(sm._tour_i == 4, "space cannot skip to the tug before a hulk is found (%d)" % sm._tour_i)
	# analyse the hulk's signal: the card waits, then the tug step comes by itself
	var ship_sig := ""
	for s in Scan.signals(near):
		if str(s.get("kind", "")) == "ship" and ship_sig == "":
			ship_sig = str(s.id)
	check(ship_sig != "", "a hulk among the signals")
	sm.sel_sig = ship_sig
	sm._sig_key = ""
	sm._fill()
	Scan.analyze(ship_sig)
	var waited := false
	var n2 := 0
	while Scan.busy() and n2 < 2000:
		n2 += 1
		await process_frame
		if sm._tour_i > 4:
			bad = "analysing: on step %d before the hulk is known" % sm._tour_i
		if _card_text(sm).contains("正在分析"):
			waited = true
	check(bad == "" and waited, "analysing: the card waits and says so (%s)" % bad)
	await _frames(20)
	check(sm._tour_i == 5 and _card_text(sm).contains("派拖船"), "the hulk found: the tug step (%s)" % _card_text(sm))
	check(_lit_on(sm, sm._tour_parts.get("send")), "the tug step frames the tug button")
	sm.close()
	await _frames(20)
	check(_walk_card_on(), "the star map closed: the port walk's card is back")
	print("STARMAP TOUR GATE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
