extends "res://tests/guide_check.gd"
# 2026-11-04 工作台通用动效（scripts/bench_fx.gd）样板：供电控制屏。入场中途、静止、悬停（假指针）、
# 点击扩散、电不够时主操作呼吸、展开推开中途、提示条、退场中途、减少动效。1920x1080，只用测试存档，
# 不动真实鼠标（悬停用 BenchFx.shot_mouse）。
#   tools/run_test.sh tests/bench_power_shot.gd


func _initialize() -> void:
	Career.path = "user://zp_test_bench_power_career.json"
	SaveGame.path = "user://zp_test_bench_power_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


class Fake extends Node:
	var group := "salvage"
	var mw := 3.0
	func grid_loads() -> Array:
		return [{"id": "fake_" + group, "name": "FAKE", "group": group, "rated": mw, "demand": mw, "mw_now": -1.0, "state": "run"}]


func _entry(ui, b: Button):
	var rig = BenchFx.rig_of(ui)
	for e in rig.entries:
		if e.b == b:
			return e
	return null


func _run() -> void:
	var was_reduce := Txt.reduce_motion
	var was_anim := Txt.anim
	Txt.reduce_motion = false
	Txt.anim = "full"
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 20000.0
	Career.save()
	await _spawn()
	await _frames(20)
	# 1. coming in
	g.open_power_screen()
	await _wait_s(0.16)
	Cap.save(root, "res://tests/out/bench_power_enter.png")
	var ui = g.console_ui
	check(ui.margin.modulate.a < 0.99 and ui.margin.offset_left > 1.0, "mid entry: still sliding and fading in (%.2f, %.0f px)" % [ui.margin.modulate.a, ui.margin.offset_left])
	await _wait_s(0.18)
	Cap.save(root, "res://tests/out/bench_power_enter2.png")
	await _wait_s(1.6)
	check(is_equal_approx(ui.margin.modulate.a, 1.0), "settled: fully in")
	check(is_equal_approx(ui.margin.offset_left, 0.0), "settled: slid home")
	Cap.save(root, "res://tests/out/bench_power_idle.png")
	# 2. the pointer on the second "when it runs short" choice (a fake pointer; the real one is not moved)
	var opt: Button = ui.details_key
	BenchFx.shot_mouse = opt.global_position + Vector2(opt.size.x * 0.3, opt.size.y * 0.5)
	await _wait_s(0.45)
	var e = _entry(ui, opt)
	check(e != null and e.q > 0.9, "hover: the row lifts (q %.2f)" % (e.q if e != null else -1.0))
	check(e != null and e.lit(), "hover: the light is on")
	Cap.save(root, "res://tests/out/bench_power_hover.png")
	# 3. pressed: the ring from the click point
	opt.button_down.emit()
	await _wait_s(0.12)
	Cap.save(root, "res://tests/out/bench_power_click.png")
	opt.button_up.emit()
	BenchFx.shot_mouse = Vector2.INF
	await _wait_s(0.6)
	check(e.q < 0.05, "pointer gone: the row settles back (q %.2f)" % e.q)
	# 4. short of power: the first way out breathes
	for gp in [["salvage", 3.0], ["process", 5.0]]:
		var f := Fake.new()
		f.group = gp[0]
		f.mw = gp[1]
		g.add_child(f)
		Grid.add_load_source(f)
	await _wait_s(1.2)
	check(not ui.banner.ok and ui.fixes.get_child_count() >= 1, "short: the ways out are on the band")
	if ui.fixes.get_child_count() > 0:
		var pe = _entry(ui, ui.fixes.get_child(0))
		check(pe != null and pe.primary, "short: the first way out breathes")
	Cap.save(root, "res://tests/out/bench_power_short.png")
	# 5. the details push the page down
	var h0: float = ui.details_fold.size.y
	ui.details_key.pressed.emit()
	await _wait_s(0.16)
	var hm: float = ui.details_fold.size.y
	Cap.save(root, "res://tests/out/bench_power_fold_mid.png")
	await _wait_s(0.6)
	var h1: float = ui.details_fold.size.y
	check(ui.details.visible, "details open")
	check(h0 < 1.0 and hm > h0 + 10.0 and hm < h1 - 10.0, "fold: grows smoothly (%.0f → %.0f → %.0f)" % [h0, hm, h1])
	Cap.save(root, "res://tests/out/bench_power_fold_open.png")
	ui.details_key.pressed.emit()
	await _wait_s(0.6)
	check(not ui.details.visible and ui.details_fold.size.y < 1.0, "details folded away again")
	# 6. a note
	ui._apply("defer", false)
	await _wait_s(0.22)
	Cap.save(root, "res://tests/out/bench_power_toast.png")
	check(ui.msg.text.begins_with("已设定"), "the note says what was set (%s)" % ui.msg.text)
	# 7. going out
	ui.close()
	check(g.console_ui == null, "closing: the game has its hands back at once")
	await _wait_s(0.1)
	Cap.save(root, "res://tests/out/bench_power_leave.png")
	await _wait_s(0.4)
	check(not is_instance_valid(ui), "closed: the picture is gone")
	# 8. reduce motion: everything at once
	Txt.reduce_motion = true
	g.open_power_screen()
	await _frames(2)
	ui = g.console_ui
	check(is_equal_approx(ui.margin.modulate.a, 1.0) and is_equal_approx(ui.margin.offset_left, 0.0), "reduce motion: in at once")
	var bad := 0
	for c in ui.find_children("*", "Control", true, false):
		if c.modulate.a < 0.99 and c.is_visible_in_tree() and c.get_parent() != null and c.get_parent().name != "BenchFx":
			bad += 1
	check(bad == 0, "reduce motion: no row held back (%d)" % bad)
	opt = ui.shore_key
	BenchFx.shot_mouse = opt.global_position + Vector2(40, 20)
	await _frames(10)
	e = _entry(ui, opt)
	check(e != null and e.q == 0.0 and not e.lit(), "reduce motion: no lift, no light")
	ui.details_key.pressed.emit()
	await _frames(2)
	check(ui.details_fold.k == 1.0, "reduce motion: the details open at once")
	Cap.save(root, "res://tests/out/bench_power_reduce.png")
	BenchFx.shot_mouse = Vector2.INF
	ui.close()
	await _frames(2)
	check(not is_instance_valid(ui), "reduce motion: gone at once")
	Txt.reduce_motion = was_reduce
	Txt.anim = was_anim
	print("BENCH POWER %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
