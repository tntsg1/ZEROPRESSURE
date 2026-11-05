extends "res://tests/guide_check.gd"
# 2026-11-05 公司仓库页精修（scripts/company_store.gd）：整页静止、悬停（浮起、聚光、小卡）、右键菜单、Ctrl 框选
# 中途、多选汇总、批量卖出飞走；框选 / Ctrl 点选 / 批量卖出后现金和仓库正确；各状态的帧时间。
# 只用测试存档；不动真实鼠标（假指针 BenchFx.shot_mouse），Ctrl 用测试开关（不按真实按键）。
#   tools/run_test.sh tests/store_fx_shot.gd

const OUT := "res://tests/out/store_fx_%s.png"


func _initialize() -> void:
	Career.path = "user://zp_test_store_fx_career.json"
	SaveGame.path = "user://zp_test_store_fx_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame


func _ms(n: int) -> Array:
	var ts: Array = []
	for i in n:
		var a := Time.get_ticks_usec()
		await process_frame
		ts.append((Time.get_ticks_usec() - a) / 1000.0)
	var sum := 0.0
	for v in ts:
		sum += v
	ts.sort()
	return [sum / n, ts[int(n * 0.95)], ts[n - 1]]


func _click(ui, at: Vector2, button := MOUSE_BUTTON_LEFT, pressed := true) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ui._gui_input(ev)


func _centre(ui, id: String) -> Vector2:
	var r: Rect2 = ui.unit_rect(id)
	return ui._grid_rect().position + r.get_center()


func _run() -> void:
	var was := Txt.reduce_motion
	Txt.reduce_motion = false
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true}
	Career.data.money = 10000.0
	Career.save()
	await _spawn()
	await _frames(20)
	# a haul of every tier: common, rare, precious machines, hazardous goods, ingots
	var gds: Array = []
	for i in 6:
		gds.append({"cat": "equip", "tag": "LOW-%d" % i, "nk": "p_pod", "value": 300.0 + i * 40.0, "cond": 1.0, "mass": 0.6})
	for i in 5:
		gds.append({"cat": "equip", "tag": "MID-%d" % i, "nk": "p_pod", "value": 900.0 + i * 200.0, "cond": 1.0, "mass": 1.5})
	for i in 3:
		gds.append({"cat": "equip", "tag": "TOP-%d" % i, "nk": "p_pod", "value": 3200.0 + i * 500.0, "cond": 1.0, "mass": 3.0})
	for i in 2:
		gds.append({"cat": "special", "tag": "HAZ-%d" % i, "nk": "p_pod", "value": 800.0, "cond": 1.0, "mass": 0.5})
	StoreBook.receive("201-TEST", "gr7", 14.0, [], gds)
	StoreBook.admit()
	Career.save()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var worst := 0.0
	g.open_store()
	for i in 30:
		var a := Time.get_ticks_usec()
		await process_frame
		worst = maxf(worst, (Time.get_ticks_usec() - a) / 1000.0)
	var ui = g.console_ui
	check(ui != null and ui.get_script() == preload("res://scripts/company_store.gd"), "the stores open")
	var tiers := {}
	for it in ui.items:
		tiers[ui.tier_of(it)] = true
	check(tiers.size() >= 3, "several value tiers on the page (%s)" % str(tiers.keys()))
	# when it came off: stamped with the game day on the way in; an old save's thing (no stamp) shows "—"
	var one: Dictionary = ui.shown()[0]
	check(one.has("day") and float(one.day) >= 0.0 and ui.origin_of(one).contains("拆下于 第 %d 天" % int(Shipping.day())), "taken-off day: %s" % ui.origin_of(one))
	var old := one.duplicate()
	old.erase("day")
	check(ui.origin_of(old).contains("拆下于 —"), "old save, no stamp: %s" % ui.origin_of(old))
	var idle: Array = await _ms(120)
	await _wait_s(0.6)
	Cap.save(root, OUT % "page")
	await _frames(5)
	# hover: the thing floats up under the light, then its small card
	var eq := ""
	for it in ui.shown():
		if str(it.cat) == "equip" and ui.tier_of(it) == "precious":
			eq = str(it.id)
			break
	BenchFx.shot_mouse = _centre(ui, eq) + Vector2(6, -4)
	await _frames(4)
	check(float(ui._hk.get(eq, 0.0)) > 0.2 and float(ui._hk.get(eq, 0.0)) < 1.0, "hover: it rises, not at once (%.2f)" % float(ui._hk.get(eq, 0.0)))
	await _wait_s(0.45)
	check(ui._tip_id == eq and ui._tip_t >= ui.TIP_S, "hover 0.3 s: its small card")
	var hov: Array = await _ms(120)
	Cap.save(root, OUT % "hover_card")
	# right click: the menu
	_click(ui, BenchFx.shot_mouse, MOUSE_BUTTON_RIGHT)
	await _wait_s(0.25)
	check(not ui._menu.is_empty() and ui._menu.rows.size() >= 2, "right click: a menu (%d rows)" % (ui._menu.rows.size() if not ui._menu.is_empty() else 0))
	Cap.save(root, OUT % "menu")
	ui._menu = {}
	# Ctrl + drag: a box over the top rows
	ui._test_ctrl = true
	var gr: Rect2 = ui._grid_rect()
	var a0 := gr.position + Vector2(6, 6)
	var a1 := gr.position + Vector2(gr.size.x * 0.62, ui.cell() * 1.6)
	BenchFx.shot_mouse = a0
	_click(ui, a0)
	BenchFx.shot_mouse = a1
	await _wait_s(0.15)
	var box: Array = await _ms(60)
	Cap.save(root, OUT % "box")
	_click(ui, a1, MOUSE_BUTTON_LEFT, false)
	await _frames(3)
	var n_box: int = ui._multi.size()
	check(n_box >= 3, "Ctrl box: %d things chosen" % n_box)
	# Ctrl + click: one more out, then back in
	var pick := str(ui._multi.keys()[0])
	BenchFx.shot_mouse = _centre(ui, pick)
	_click(ui, BenchFx.shot_mouse)
	_click(ui, BenchFx.shot_mouse, MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	check(ui._multi.size() == n_box - 1 and not ui._multi.has(pick), "Ctrl+click takes one out")
	_click(ui, BenchFx.shot_mouse)
	_click(ui, BenchFx.shot_mouse, MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	check(ui._multi.size() == n_box and ui._multi.has(pick), "and puts it back")
	ui._test_ctrl = false
	BenchFx.shot_mouse = Vector2(ui.size.x * 0.5, 30)
	await _wait_s(0.6)
	var sum: Dictionary = ui.multi_sum()
	check(int(sum.n) == n_box, "the summary counts them (%d)" % int(sum.n))
	Cap.save(root, OUT % "multi")
	# sell them all
	var m0 := float(Career.data.money)
	var ids: Array = ui._multi.keys()
	var want := float(sum.recycle)
	ui.sell_multi()
	var sell_ms: Array = await _ms(20)
	await _wait_s(0.15)
	Cap.save(root, OUT % "multi_sell")
	await _wait_s(1.2)
	check(absf(float(Career.data.money) - m0 - want) < 1.5, "sold: +%s, cash right (%s)" % [Pal.money(want), Pal.money(float(Career.data.money) - m0)])
	var left := 0
	for id in ids:
		if not ui._item(str(id)).is_empty():
			left += 1
	check(left == 0 and ui._multi.is_empty(), "and gone from the store (%d left)" % left)
	check(ui.message.contains("卖给回收站") and ui.message.contains("件"), "one note: %s" % ui.message)
	# reduced motion: the hover is at once
	Txt.reduce_motion = true
	var any := str(ui.shown()[0].id)
	BenchFx.shot_mouse = _centre(ui, any)
	await _frames(3)
	check(float(ui._hk.get(any, 0.0)) == 1.0, "reduced motion: lifted at once")
	Txt.reduce_motion = was
	BenchFx.shot_mouse = Vector2.INF
	print("STORE FX PERF open worst %.2f ms · idle %.2f / %.2f · hover %.2f / %.2f · box %.2f / %.2f · selling %.2f / %.2f (avg / p95 ms)" % [worst, idle[0], idle[1], hov[0], hov[1], box[0], box[1], sell_ms[0], sell_ms[1]])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	print("STORE FX %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
