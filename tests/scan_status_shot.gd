extends "res://tests/guide_check.gd"
# The signal list while a signal is analysed (user 2026-10-28, 截图：“正在分析信号 S-001，等它完成”
# drawn as a third row looked like one more signal): the status is no row — the signal being
# analysed says so on its own row, a status line (no button) under the list counts it down, and
# says what it found for a few seconds when done. Own test saves only.
#   tools/run_test.sh tests/scan_status_shot.gd


func _initialize() -> void:
	Career.path = "user://zp_test_scan_status_career.json"
	SaveGame.path = "user://zp_test_scan_status_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rows(sm) -> Array:
	return sm.find_box.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and str(b.text).begins_with("S-"))


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "starmap_tour": true}
	Career.data.money = 20000.0
	Career.save()
	Scan.ON = true
	await _spawn()
	await _frames(20)
	g.open_star_map("find")
	await _frames(10)
	var sm = g.console_ui
	var near: int = Scan.order()[0]
	sm.sel_sector = near
	Scan.sweep(near)
	sm._sig_key = ""
	sm._fill()
	await _frames(4)
	check(not (sm._tour_parts.sweep is Button) and sm._tour_parts.sweep.has_method("_bar"), "a sweep under way shows as status where its button was")
	Scan.finish()
	var sigs: Array = Scan.signals(near)
	var first := str(sigs[0].id)
	sm.sel_sig = first
	Scan.analyze(first)
	# the user's case: another signal picked while the first is analysed
	if sigs.size() > 1:
		sm.sel_sig = str(sigs[1].id)
	Scan.advance(Scan.ANALYZE_S * 0.47)
	sm._sig_key = ""
	sm._fill()
	await _frames(30)
	var rows := _rows(sm)
	check(rows.size() == sigs.size(), "only the signals are rows (%d rows, %d signals)" % [rows.size(), sigs.size()])
	check(not rows.any(func(b): return "等它完成" in str(b.text)), "no row says 'wait for it'")
	check(rows.any(func(b): return str(b.text).begins_with(first) and "分析中" in str(b.text)), "the signal being analysed says so on its own row")
	var st: Array = sm.find_box.find_children("*", "", true, false).filter(func(c): return c.get_script() != null and c.has_method("_bar"))
	check(st.size() == 1 and "分析信号" in str(st[0].lbl.text), "one status line under the list: %s" % (str(st[0].lbl.text) if not st.is_empty() else "-"))
	Cap.save(root, "res://tests/out/scan_status_busy_zh.png")
	# Done: retain the result while immediately offering the selected next signal.
	Scan.advance(Scan.ANALYZE_S)
	sm._fill()
	await _frames(10)
	st = sm.find_box.find_children("*", "", true, false).filter(func(c): return c.get_script() != null and c.has_method("_bar"))
	check(st.size() == 1 and "分析完成" in str(st[0].lbl.text), "done: the status line says what it found: %s" % (str(st[0].lbl.text) if not st.is_empty() else "-"))
	var immediate: Array = sm.find_box.find_children("*", "Button", true, false).filter(func(b): return "电磁特征" in str(b.text) and not b.disabled)
	check(sigs.size() < 2 or (immediate.size() == 1 and str(immediate[0].text).contains(str(sigs[1].id))), "next signal can be analysed immediately while the result is visible")
	Cap.save(root, "res://tests/out/scan_status_done_zh.png")
	if not immediate.is_empty():
		immediate[0].pressed.emit()
		check(Scan.busy() and str(Scan.data().job.sig) == str(sigs[1].id), "clicking immediately starts the next analysis")
		Scan.data().job = {}
	sm._done_until = 0
	sm._fill()
	await _frames(6)
	var back: Array = sm.find_box.find_children("*", "Button", true, false).filter(func(b): return "电磁特征" in str(b.text) and not b.disabled)
	check(sigs.size() < 2 or back.size() == 1, "the next signal's analyse button remains after the result fades")
	# user 2026-10-28: the analyse button is an action, not one more signal: drawn apart from the rows
	if not back.is_empty():
		# 107 号 Q6 A: a hulk's row is its tug button (an action itself): compare with a plain signal row
		var row: Button = _rows(sm).filter(func(b): return "未知信号" in str(b.text))[0]
		var sa: StyleBox = back[0].get_theme_stylebox("normal")
		var sr: StyleBox = row.get_theme_stylebox("normal")
		check(sa is StyleBoxFlat and sr is StyleBoxFlat and not (sa as StyleBoxFlat).bg_color.is_equal_approx((sr as StyleBoxFlat).bg_color), "the analyse button is filled apart from the signal rows")
	await _frames(20)
	Cap.save(root, "res://tests/out/scan_status_idle_zh.png")
	print("SCAN STATUS SHOT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
