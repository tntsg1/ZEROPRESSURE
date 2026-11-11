extends "res://tests/guide_check.gd"
# 2026-11-10 公司仓库：同类成叠 + 长按数量滑块（卖 / 压块 / 拖动拆分），旧存档不丢件、总价值不变。
# Real key and mouse events pushed into the test viewport only; the page's pointer is
# BenchFx.shot_mouse (the user's mouse is never moved). Own test saves only.
#   tools/run_test.sh tests/store_stack_check.gd --fixed-fps 60

const OUT := "res://tests/out/store_stack_%s.png"


func _initialize() -> void:
	Career.path = "user://zp_test_stack_career.json"
	SaveGame.path = "user://zp_test_stack_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key_ev(code: int, down: bool, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	ev.shift_pressed = shift
	root.push_input(ev)


func _tap(code: int, shift := false) -> void:
	_key_ev(code, true, shift)
	await _frames(2)
	_key_ev(code, false, shift)
	await _frames(2)


func _btn(pos: Vector2, down: bool) -> void:
	BenchFx.shot_mouse = pos
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	if down:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev)


func _move(pos: Vector2) -> void:
	BenchFx.shot_mouse = pos
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev)


func _at(ui, id: String) -> Vector2:
	return ui._grid_rect().position + (ui.unit_rect(id) as Rect2).get_center()


func _of(ui, nk: String) -> Array:
	return ui.items.filter(func(it): return str(it.id).begins_with("p:") and str(it.part.get("nk", "")) == nk).map(func(it): return str(it.id))


func _part(uid: String, nk: String, value: float) -> Dictionary:
	return {"uid": uid, "nk": nk, "cls": "power", "cond": 1.0, "value": value, "ship": "tug", "tag": "ST-" + uid, "mass": 0.5}


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.seen = {"port_walk": true, "intro": true, "belt_prelude": true, "first_ship": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1}
	Career.data.money = 10000.0
	Career.data.parts = [
		_part("pump-a", "p_pump", 1500.0), _part("pump-b", "p_pump", 1700.0), _part("pump-c", "p_pump", 1600.0),
		_part("bat-a", "p_battery", 1200.0), _part("bat-b", "p_battery", 1200.0), _part("bat-c", "p_battery", 1250.0), _part("bat-d", "p_battery", 1300.0),
		_part("pod-a", "p_pod", 2500.0), _part("pod-b", "p_pod", 2600.0), _part("pod-c", "p_pod", 2700.0),
		_part("worn-a", "p_pump", 1500.0)]
	Career.data.parts[10].cond = 0.1
	StoreBook._add_raw(Exchange.INGOT, 10.0, "test", "")
	Career.save()
	# ---- an old save read in: nothing lost, the worth unchanged (the stacks change no cells)
	var n0 := StoreBook.units().size()
	var t0 := StoreBook.totals()
	var pos0 := str(StoreBook.layout(StoreBook.units()))
	Career.data = {}
	Career.load_or_new()
	var t1 := StoreBook.totals()
	check(StoreBook.units().size() == n0 and absf(float(t1.market) - float(t0.market)) < 0.5 and absf(float(t1.recycle) - float(t0.recycle)) < 0.5, "the save read in: %d things, worth %s / %s unchanged" % [n0, Pal.money(float(t1.recycle)), Pal.money(float(t1.market))])
	check(str(StoreBook.layout(StoreBook.units())) == pos0 and int(t1.used) == int(t0.used), "no thing moved, the same cells used (%d)" % int(t1.used))
	await _spawn()
	g.open_store()
	await _frames(12)
	var ui = g.console_ui
	ui.tidy()
	await _frames(30)
	ui.scroll = 0.0
	await _frames(4)
	# ---- three of one kind make a stack (the worn one is another kind)
	var pumps := _of(ui, "p_pump").filter(func(id): return id != "p:worn-a")
	check(pumps.size() == 3 and ui.stack_of(pumps[0]).size() == 3, "three pumps of one kind: one stack of 3")
	check(ui.stack_of("p:worn-a").size() < 2, "a worn pump is not in that stack")
	var u := Rect2()
	var area := 0.0
	for id in pumps:
		var r: Rect2 = ui._rest_rect(id)
		area += r.get_area()
		u = r if u.size == Vector2.ZERO else u.merge(r)
	check(absf(u.get_area() - area) < 1.0, "一键整理 lays the stack together (one block)")
	await _frames(6)
	if DisplayServer.get_name() != "headless":
		Cap.save(root, OUT % "stack")
	# ---- a long press on it: the slider, the whole stack
	var pa := _at(ui, pumps[0])
	_btn(pa, true)
	await _frames(12)
	check(not ui._long_done, "a short hold is not a long press yet")
	await _frames(24)
	check(ui._long_done and ui.sel == pumps[0] and ui.quantity == 3 and ui._quantity_available(), "held 0.6 s still: the slider takes the whole stack (%d)" % ui.quantity)
	_btn(pa, false)
	await _frames(6)
	check(ui.drag_id == "" and ui._btns.has("quantity"), "let go: no drag, the slider is up")
	check(ui._qty_line(ui._item(pumps[0])) == "3 件（整叠）", "the count under the name says the stack: %s" % ui._qty_line(ui._item(pumps[0])))
	if DisplayServer.get_name() != "headless":
		Cap.save(root, OUT % "slider")
	# Shift+← : 2; Enter sells the two
	await _tap(KEY_LEFT, true)
	check(ui.quantity == 2 and ui.sel == pumps[0], "Shift+← : two (and the same one stays picked)")
	check(ui._qty_line(ui._item(pumps[0])) == "2 件", "and it follows the slider: %s" % ui._qty_line(ui._item(pumps[0])))
	var money := float(Career.data.money)
	var chosen: Array = ui._quantity_chosen().map(func(x): return str(x.id))
	var want := 0.0
	for x in ui._quantity_chosen():
		want += float(x.recycle)
	await _tap(KEY_ENTER)
	await _frames(10)
	var left := _of(ui, "p_pump").filter(func(id): return id != "p:worn-a")
	check(left.size() == 1 and not chosen.has(left[0]), "two sold, one left (%s)" % str(left))
	check(absf(float(Career.data.money) - money - want) < 1.0, "paid for the two: +%s" % Pal.money(float(Career.data.money) - money))
	# ---- a drag splits: two of four batteries go where they are dropped
	ui.tidy()
	await _frames(30)
	ui.scroll = 0.0
	await _frames(4)
	var bats := _of(ui, "p_battery")
	ui.select(bats[0])
	await _frames(2)
	await _tap(KEY_RIGHT, true)
	check(ui.quantity == 2, "Shift+→ : two batteries")
	var gr: Rect2 = ui._grid_rect()
	var c: float = ui.cell()
	var occ := StoreBook._occ_of(ui.lay, ui.items)
	var it0: Dictionary = ui._item(bats[0])
	var sz := StoreBook._size(it0, int(ui.lay[bats[0]][2]))
	var tgt := Vector2i(-1, -1)
	var rows_in_view := int(gr.size.y / c)
	for y in range(rows_in_view - 1, -1, -1):
		for x in range(StoreBook.COLS - 1, -1, -1):
			if tgt.x < 0 and StoreBook._free(occ, x, y, sz) and StoreBook._free(occ, maxi(0, x - sz.x), y, sz):
				tgt = Vector2i(x, y)
	check(tgt.x >= 0, "a free place in view %s" % str(tgt))
	var start := _at(ui, bats[0])
	var grab: Vector2 = start - gr.position - (ui.unit_rect(bats[0]) as Rect2).position
	var drop: Vector2 = gr.position + Vector2(tgt.x * c, tgt.y * c) + grab
	_btn(start, true)
	await _frames(3)
	_move(start + Vector2(20, 0))
	await _frames(3)
	check(ui.drag_id == bats[0] and ui._drag_group.size() == 2, "dragging takes the two")
	_move(drop)
	await _frames(4)
	_btn(drop, false)
	await _frames(10)
	var near := 0
	for id in _of(ui, "p_battery"):
		var p: Array = ui.lay[id]
		if Vector2(int(p[0]) - tgt.x, int(p[1]) - tgt.y).length() <= 3.0:
			near += 1
	check(near == 2 and _of(ui, "p_battery").size() == 4, "two batteries split off to the drop, two stay (%d there)" % near)
	# ---- P bales part of a stack
	ui.tidy()
	await _frames(20)
	var pods := _of(ui, "p_pod")
	ui.select(pods[0])
	await _frames(2)
	await _tap(KEY_RIGHT, true)
	check(ui.quantity == 2, "two of three pods")
	await _tap(KEY_P)
	await _frames(6)
	check(_of(ui, "p_pod").size() == 1, "a tap of P sends two of the three to the press (%d left)" % _of(ui, "p_pod").size())
	check(ui.message.contains("送去压块 2 件"), "it says so: %s" % ui.message)
	# ---- the raw bundles: a long press takes them all too
	var raw: Array = ui.items.filter(func(x): return str(x.id).begins_with("r:")).map(func(x): return str(x.id))
	var ra := _at(ui, raw[0])
	_btn(ra, true)
	await _frames(40)
	_btn(ra, false)
	await _frames(4)
	check(ui.quantity == raw.size(), "a long press on a raw bundle takes all %d" % raw.size())
	BenchFx.shot_mouse = Vector2.INF
	ui.on_close.call()
	g.queue_free()
	await _frames(4)
	print("STACK %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
