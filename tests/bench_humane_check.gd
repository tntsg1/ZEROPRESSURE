extends "res://tests/guide_check.gd"
# 2026-11-04 工作台人性化（scripts/bench_fx.gd）在供电控制屏上：Esc 分层退、悬停 0.4 秒白话说明、
# 点不了的键写出原因、下次打开回到上次的状态（存进 Career.data 并随存档走）、Enter 按主操作、
# 接入外购电立刻生效并出完成提示、界面缩放 90%–130%。只用测试存档，不动真实鼠标。
#   tools/run_test.sh tests/bench_humane_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_bench_humane_career.json"
	SaveGame.path = "user://zp_test_bench_humane_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


func _esc() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)
	await process_frame


func _note_text(ui) -> String:
	var n = ui.find_child("BfxNote", true, false)
	if n == null or not n.visible:
		return ""
	return str(n.get_child(0).text)


class Fake extends Node:
	var group := "salvage"
	var mw := 3.0
	func grid_loads() -> Array:
		return [{"id": "fake_" + group, "name": "FAKE", "group": group, "rated": mw, "demand": mw, "mw_now": -1.0, "state": "run"}]


func _run() -> void:
	var was := [Txt.reduce_motion, Txt.anim, Txt.ui_scale]
	Txt.reduce_motion = false
	Txt.anim = "full"
	Txt.ui_scale = 1.0
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.save()
	await _spawn()
	await _frames(20)
	g.open_power_screen()
	await _wait_s(1.2)
	var ui = g.console_ui
	# 规则 1: Esc folds the details first, then closes
	ui.details_key.pressed.emit()
	await _wait_s(0.6)
	check(ui.details_fold.open, "details open")
	await _esc()
	await _wait_s(0.5)
	check(g.console_ui == ui and not ui.details_fold.open, "Esc 1: the details fold, the screen stays")
	check(ui.details_key.text.ends_with("▾"), "Esc 1: its key turns back (%s)" % ui.details_key.text)
	# 规则 4: a plain note after 0.4 s; a shut key says why
	BenchFx.shot_mouse = ui.furnace_pause.global_position + Vector2(20, 15)
	await _wait_s(0.2)
	check(_note_text(ui) == "", "no note before 0.4 s")
	await _wait_s(0.4)
	check(_note_text(ui).contains("停下等电"), "note after 0.4 s (%s)" % _note_text(ui))
	Cap.save(root, "res://tests/out/bench_humane_note.png")
	var up_first: Button = ui.order_box.get_child(0).get_child(0).get_child(0)
	check(up_first.disabled, "the first district's up key is shut")
	BenchFx.shot_mouse = up_first.global_position + up_first.size * 0.5
	await _wait_s(0.6)
	check(_note_text(ui) == "已经排在第一", "a shut key says why (%s)" % _note_text(ui))
	Cap.save(root, "res://tests/out/bench_humane_why.png")
	BenchFx.shot_mouse = Vector2.INF
	await _wait_s(0.2)
	# 规则 2: bought power at once, no confirm, a note of what it does and costs
	ui.shore_key.pressed.emit()
	await _wait_s(0.3)
	check(str(Grid.ctl().line) == "auto_shore", "bought power on at once")
	check(not ui.confirm.visible, "no confirm box")
	check(ui.msg.text.contains("已接入外购电") and ui.msg.text.contains("$300"), "the note says what and what it costs (%s)" % ui.msg.text)
	Cap.save(root, "res://tests/out/bench_humane_shore.png")
	ui.shore_key.pressed.emit()
	await _wait_s(0.2)
	check(str(Grid.ctl().line) == "auto", "and off again at once")
	# 规则 6: short of power, Enter presses the breathing way out, which carries its key
	var fakes: Array = []
	for gp in [["salvage", 3.0], ["process", 5.0]]:
		var f := Fake.new()
		f.group = gp[0]
		f.mw = gp[1]
		g.add_child(f)
		Grid.add_load_source(f)
		fakes.append(f)
	await _wait_s(0.8)
	var first: Button = ui.fixes.get_child(0)
	var tag = first.find_child("BfxTag", false, false)
	check(tag != null and tag.visible and tag.text == "Enter", "the way out carries Enter")
	Cap.save(root, "res://tests/out/bench_humane_enter.png")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.keycode = KEY_ENTER
	ev.pressed = true
	root.push_input(ev)
	await _wait_s(0.3)
	check(str(Grid.ctl().line) == "auto_shore", "Enter took the first way out (buy power)")
	Grid.set_ctl("line", "auto")
	for f in fakes:
		Grid.extra_loads.erase(f)
		f.queue_free()
	await _wait_s(0.4)
	# 规则 3: open the details, scroll, close; reopened, it is as it was, and the state is in the save
	ui.details_key.pressed.emit()
	await _wait_s(0.6)
	ui.scroll.scroll_vertical = 300
	await _frames(3)
	var sv: int = ui.scroll.scroll_vertical
	await _esc()   # folds
	ui.details_key.pressed.emit()
	await _wait_s(0.6)
	ui.scroll.scroll_vertical = sv
	await _frames(3)
	ui.close()
	await _wait_s(0.5)
	var st: Dictionary = Career.data.get("bench_ui", {}).get("power_panel", {})
	check(st.get("folds", []) == [true] and int(st.get("scroll", [0])[0]) == sv, "the details' state is kept (%s)" % str(st))
	Career.save()
	var keep: Dictionary = Career.data.duplicate(true)
	Career.data = {}
	Career.load_or_new()
	check(Career.data.get("bench_ui", {}).has("power_panel"), "the state travels with the save")
	if not Career.data.get("bench_ui", {}).has("power_panel"):
		Career.data = keep
	g.open_power_screen()
	await _wait_s(1.0)
	ui = g.console_ui
	check(ui.details_fold.open and ui.details.visible, "reopened: the details open as left")
	check(absi(ui.scroll.scroll_vertical - sv) <= 2, "reopened: scrolled where it was (%d vs %d)" % [ui.scroll.scroll_vertical, sv])
	Cap.save(root, "res://tests/out/bench_humane_restored.png")
	# Esc twice: folds, then closes
	await _esc()
	await _wait_s(0.5)
	check(g.console_ui == ui, "Esc 1 folds (screen still open)")
	await _esc()
	await _wait_s(0.5)
	check(g.console_ui == null, "Esc 2 closes the screen")
	# 规则 5: each interface scale lays the screen out in its own space and draws it to the screen
	for s in [0.9, 1.1, 1.3]:
		Txt.ui_scale = s
		g.open_power_screen()
		await _wait_s(0.9)
		ui = g.console_ui
		var vp: Vector2 = ui.get_viewport_rect().size
		check(ui.scale.is_equal_approx(Vector2(s, s)) and (ui.size * s).distance_to(vp) < 2.0, "scale %d%%: fills the screen" % roundi(s * 100))
		Cap.save(root, "res://tests/out/bench_humane_scale_%d.png" % roundi(s * 100))
		ui.close()
		await _wait_s(0.4)
	Txt.reduce_motion = was[0]
	Txt.anim = was[1]
	Txt.ui_scale = was[2]
	print("BENCH HUMANE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
