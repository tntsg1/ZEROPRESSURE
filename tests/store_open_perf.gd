extends "res://tests/guide_check.gd"
# 打开仓库那一帧和静止的帧时间（新旧对比用）。2026-11-05 公司仓库页精修（scripts/company_store.gd）：整页静止、悬停（浮起、聚光、小卡）、右键菜单、Ctrl 框选
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
	await _frames(30)
	ui.prof_us = 0
	ui.prof_frames = 0
	ui.prof_grid = 0
	ui.prof_over = 0
	var idle: Array = await _ms(120)
	var d_idle: float = (ui.prof_us + ui.prof_grid + ui.prof_over) / 1000.0 / maxi(1, ui.prof_frames)
	BenchFx.shot_mouse = ui._grid_rect().get_center()
	await _frames(30)
	ui.prof_us = 0
	ui.prof_frames = 0
	ui.prof_grid = 0
	ui.prof_over = 0
	var hov: Array = await _ms(120)
	var d_hov: float = (ui.prof_us + ui.prof_grid + ui.prof_over) / 1000.0 / maxi(1, ui.prof_frames)
	print("STORE DRAW parts (pointer on the grid): page %.3f · grid %.3f · over %.3f ms" % [ui.prof_us / 1000.0 / maxi(1, ui.prof_frames), ui.prof_grid / 1000.0 / maxi(1, ui.prof_frames), ui.prof_over / 1000.0 / maxi(1, ui.prof_frames)])
	print("STORE DRAW the page's own drawing: idle %.3f ms · pointer on the grid %.3f ms a frame" % [d_idle, d_hov])
	print("STORE OPEN PERF open worst %.2f ms · idle %.2f / %.2f · pointer on the grid %.2f / %.2f" % [worst, idle[0], idle[1], hov[0], hov[1]])
	quit(0)
