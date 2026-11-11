extends "res://tests/guide_check.gd"
# 2026-11-10 公司仓库：按住 P 点选压块 + 框选/拖动时拖到网格边缘自动滚动。
# Real key and mouse events pushed into the test viewport only (root.push_input); the pointer the
# page reads is BenchFx.shot_mouse — the user's real mouse is never moved. Own test saves only.
#   tools/run_test.sh tests/store_bale_pick_check.gd --fixed-fps 60

const OUT := "res://tests/out/store_bale_%s.png"


func _initialize() -> void:
	Career.path = "user://zp_test_bale_pick_career.json"
	SaveGame.path = "user://zp_test_bale_pick_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key_ev(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	root.push_input(ev)


func _btn(pos: Vector2, down: bool, ctrl := false, button := MOUSE_BUTTON_LEFT) -> void:
	BenchFx.shot_mouse = pos
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	ev.ctrl_pressed = ctrl
	if button == MOUSE_BUTTON_LEFT and down:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(ev)


func _move(pos: Vector2, ctrl := false) -> void:
	BenchFx.shot_mouse = pos
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.ctrl_pressed = ctrl
	root.push_input(ev)


func _click(pos: Vector2, ctrl := false) -> void:
	_btn(pos, true, ctrl)
	await _frames(2)
	_btn(pos, false, ctrl)
	await _frames(2)


# a unit's centre on the page (in view)
func _at(ui, id: String) -> Vector2:
	var r: Rect2 = ui.unit_rect(id)
	return ui._grid_rect().position + r.get_center()


func _in_view(ui, id: String) -> bool:
	var r: Rect2 = ui.unit_rect(id)
	return r.size != Vector2.ZERO and r.position.y >= 0.0 and r.end.y <= ui._grid_rect().size.y


func _ids_in_store() -> Dictionary:
	var out := {}
	for u in StoreBook.units():
		out[str(u.id)] = true
	return out


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
	var parts: Array = []
	for i in 10:
		parts.append({"uid": "bp-%d" % i, "nk": "p_pick_%d" % i if i < 8 else "p_pump", "cls": "power", "cond": 1.0, "value": 1500.0 + i * 100.0, "ship": "tug", "tag": "BP-%d" % i, "mass": 0.5})
	Career.data.parts = parts
	StoreBook._add_raw(Exchange.INGOT, 60.0, "test", "")
	await _spawn()
	g.open_store()
	await _frames(12)
	var ui = g.console_ui
	check(ui != null and ui.get_script() == preload("res://scripts/company_store.gd"), "the stores are open")
	ui.tidy()
	await _frames(30)
	# the machines lie after the raw bundles: scroll to where they start (an ingot row still in view)
	for it in ui.items:
		if str(it.id).begins_with("p:") and ui.lay.has(str(it.id)):
			ui.scroll = clampf(ui.unit_rect(str(it.id)).position.y + ui.scroll - ui.cell() * 2.0, 0.0, ui._scroll_max())
			break
	await _frames(6)
	print("UNITS %d placed %d · used %d/%d" % [ui.items.size(), ui.lay.size(), StoreBook.used(), StoreBook.cap()])
	var pick: Array = []
	var ingot := ""
	for it in ui.items:
		var id := str(it.id)
		if id.begins_with("p:") and _in_view(ui, id) and pick.size() < 5 and ui.stack_of(id).size() < 2:
			pick.append(id)
		if id.begins_with("r:") and ingot == "" and _in_view(ui, id):
			ingot = id
	check(pick.size() == 5 and ingot != "", "five machines and an ingot bundle in view (%d)" % pick.size())
	if pick.size() < 5 or ingot == "":
		quit(1)
		return
	var lay0: Dictionary = ui.lay.duplicate(true)

	# ---- 按住 P: past 0.25 s the bale mode is up
	_key_ev(KEY_P, true)
	await _frames(6)
	check(not ui._p_mode, "a tap's length is not the mode yet")
	await _frames(14)
	check(ui._p_mode, "P held 0.33 s: the bale mode is up")
	check(ui._matches(ui._item(pick[0])) and not ui._matches(ui._item(ingot)), "what the press takes is lit, the ingots dim")
	# three clicks, three picks; nothing moves
	for k in 3:
		await _click(_at(ui, pick[k]))
	check(ui._bale_marks.size() == 3, "three clicks: three picked (%d)" % ui._bale_marks.size())
	check(ui.drag_id == "" and str(ui.lay) == str(lay0), "a click with P held never drags or moves a thing")
	# the same one again: dropped
	await _click(_at(ui, pick[1]))
	check(ui._bale_marks.size() == 2 and not ui._bale_marks.has(pick[1]), "clicked again: dropped (%d left)" % ui._bale_marks.size())
	# an ingot bundle: refused, with the reason
	await _click(_at(ui, ingot))
	check(not ui._bale_marks.has(ingot) and ui._msg_bad and ui.message.contains("不用压"), "an ingot bundle is refused: %s" % ui.message)
	# a sweep with the button down picks what it crosses
	_btn(_at(ui, pick[3]), true)
	await _frames(3)
	_move(_at(ui, pick[3]).lerp(_at(ui, pick[4]), 0.5))
	await _frames(3)
	_move(_at(ui, pick[4]))
	await _frames(3)
	_btn(_at(ui, pick[4]), false)
	await _frames(3)
	check(ui._bale_marks.has(pick[3]) and ui._bale_marks.has(pick[4]) and ui._bale_marks.size() >= 4, "a sweep picks what it crosses, both ends too (%d picked)" % ui._bale_marks.size())
	await _frames(10)
	if DisplayServer.get_name() != "headless":
		Cap.save(root, OUT % "mode")
	# let go of P: the picks go to the press, out of the grid
	var marked: Array = ui._bale_marks.keys()
	var jobs0: int = ProcessLine.press().get("jobs", []).size() + (0 if ProcessLine.press().get("cur", {}).is_empty() else 1)
	_key_ev(KEY_P, false)
	await _frames(6)
	var have := _ids_in_store()
	var gone := 0
	for id in marked:
		if not have.has(str(id)):
			gone += 1
	var jobs1: int = ProcessLine.press().get("jobs", []).size() + (0 if ProcessLine.press().get("cur", {}).is_empty() else 1)
	check(not ui._p_mode and gone == marked.size() and jobs1 >= jobs0 + marked.size() - 1, "let go of P: every pick goes to the press (%d of %d gone, press %d → %d)" % [gone, marked.size(), jobs0, jobs1])
	check(have.has(pick[1]), "the one dropped stays in store")
	check(ui.message.contains("送去压块 %d 件" % marked.size()), "it says so: %s" % ui.message)

	# ---- Esc while held: every pick dropped, nothing sent
	_key_ev(KEY_P, true)
	await _frames(20)
	await _click(_at(ui, pick[1]))
	check(ui._bale_marks.size() == 1, "picked one more")
	_key_ev(KEY_ESCAPE, true)
	await _frames(2)
	_key_ev(KEY_ESCAPE, false)
	_key_ev(KEY_P, false)
	await _frames(4)
	check(_ids_in_store().has(pick[1]) and ui._bale_marks.is_empty() and not ui._p_mode, "Esc drops the picks: it stays in store")

	# ---- a stack in the bale mode goes whole (two pumps of one kind)
	for u2 in ["pp-a", "pp-b"]:
		Career.data.parts.append({"uid": u2, "nk": "p_pair", "cls": "power", "cond": 1.0, "value": 1400.0, "ship": "tug", "tag": "PP-" + u2, "mass": 0.5})
	ui.build()
	var pumps: Array = ["p:pp-a", "p:pp-b"]
	ui.tidy()
	await _frames(40)
	ui.select(pumps[0])
	await _frames(4)
	_key_ev(KEY_P, true)
	await _frames(20)
	await _click(_at(ui, pumps[0]))
	check(ui._bale_marks.has(pumps[0]) and ui._bale_marks.has(pumps[1]), "a click on a stack picks it whole (%d)" % ui._bale_marks.size())
	_key_ev(KEY_P, false)
	await _frames(6)
	have = _ids_in_store()
	check(not have.has(pumps[0]) and not have.has(pumps[1]), "and both go to the press")
	# ---- Ctrl selection + a tap of P: the selection goes together
	ui.tidy()
	await _frames(30)
	for it in ui.items:
		if str(it.id).begins_with("p:") and ui.lay.has(str(it.id)):
			ui.scroll = clampf(ui.unit_rect(str(it.id)).position.y + ui.scroll - ui.cell() * 2.0, 0.0, ui._scroll_max())
			break
	await _frames(6)
	var two: Array = []
	for it in ui.items:
		var id := str(it.id)
		if id.begins_with("p:") and _in_view(ui, id) and two.size() < 2:
			two.append(id)
	ui.select(ingot)
	await _frames(2)
	ui._multi = {}
	var s_ctrl: float = ui.scroll
	await _click(_at(ui, two[0]), true)
	await _click(_at(ui, two[1]), true)
	check(absf(ui.scroll - s_ctrl) < 0.5, "a Ctrl-click near the edge does not scroll the grid")
	ui._multi.erase(ingot)
	check(ui._multi.has(two[0]) and ui._multi.has(two[1]), "Ctrl+click chose two machines (%d)" % ui._multi.size())
	_key_ev(KEY_P, true)
	await _frames(2)
	_key_ev(KEY_P, false)
	await _frames(4)
	have = _ids_in_store()
	check(not have.has(two[0]) and not have.has(two[1]) and ui._multi.is_empty(), "a tap of P bales the whole Ctrl selection")

	# ---- the Ctrl box dragged past the grid's foot scrolls the grid; what was chosen stays chosen
	ui.tidy()
	await _frames(30)
	ui.scroll = 0.0
	await _frames(4)
	var pre: Array = []
	for it in ui.items:
		var id := str(it.id)
		if id.begins_with("r:") and _in_view(ui, id) and pre.size() < 2 and ui.unit_rect(id).position.y > ui.cell() * 2.0:
			pre.append(id)
	ui._multi = {}
	ui.select(pre[0])
	await _click(_at(ui, pre[1]), true)
	var chosen0: int = ui._multi.size()
	check(chosen0 == 2, "two bundles chosen first (%d)" % chosen0)
	var gr: Rect2 = ui._grid_rect()
	var start := gr.position + Vector2(ui.cell() * 0.1, 6.0)
	_btn(start, true, true)
	await _frames(2)
	_move(gr.position + Vector2(gr.size.x * 0.6, gr.size.y * 0.5), true)
	await _frames(4)
	var s0: float = ui.scroll
	var below := Vector2(gr.position.x + gr.size.x * 0.6, gr.end.y + 40.0)
	_move(below, true)
	await _frames(20)
	var s1: float = ui.scroll
	check(ui._marq_on and s1 > s0 + 100.0, "dragged past the grid's foot: the grid scrolls (%.0f → %.0f)" % [s0, s1])
	check(ui._multi.has(pre[0]) and ui._multi.has(pre[1]), "and what was chosen before is still chosen")
	if DisplayServer.get_name() != "headless":
		Cap.save(root, OUT % "autoscroll")
	# the wheel while dragging: the grid scrolls, the box goes on
	_move(Vector2(below.x, gr.end.y - ui.EDGE_PX - 30.0), true)
	await _frames(30)
	var s2: float = ui.scroll
	_btn(BenchFx.shot_mouse, true, true, MOUSE_BUTTON_WHEEL_DOWN)
	_btn(BenchFx.shot_mouse, false, true, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(20)
	check(ui._marq_on and ui.scroll > s2 + 20.0, "the wheel while dragging scrolls too, the box still on (%.0f → %.0f)" % [s2, ui.scroll])
	var box: Rect2 = ui._box_content()
	check(box.size.y > gr.size.y, "the box reaches past what one screen shows (%.0f px of content)" % box.size.y)
	_btn(BenchFx.shot_mouse, false, true)
	await _frames(4)
	var far := 0
	for id in ui._multi:
		var r: Rect2 = ui.unit_rect(str(id))
		if r.end.y + ui.scroll > gr.size.y + 4.0:
			far += 1
	check(ui._multi.has(pre[0]) and ui._multi.has(pre[1]) and ui._multi.size() > chosen0 + 6 and far > 0, "let go: the box's things join, the first two kept, some not on the first screen (%d chosen, %d below it)" % [ui._multi.size(), far])

	# ---- a thing being dragged to move it scrolls the grid too
	ui._multi = {}
	ui.scroll = 0.0
	await _frames(4)
	var mv := ""
	for it in ui.items:
		if _in_view(ui, str(it.id)):
			mv = str(it.id)
			break
	_btn(_at(ui, mv), true)
	await _frames(2)
	_move(_at(ui, mv) + Vector2(0, 20))
	await _frames(3)
	_move(Vector2(_at(ui, mv).x, gr.end.y + 30.0))
	await _frames(20)
	check(ui.drag_id == mv and ui.scroll > 60.0, "dragging a thing to the foot scrolls the grid (%.0f)" % ui.scroll)
	_key_ev(KEY_ESCAPE, true)
	await _frames(2)
	_key_ev(KEY_ESCAPE, false)
	_btn(BenchFx.shot_mouse, false)
	await _frames(4)
	BenchFx.shot_mouse = Vector2.INF
	ui.on_close.call()
	g.queue_free()
	await _frames(4)
	print("BALE_PICK %d/%d" % [checks - fails, checks])
	quit(1 if fails else 0)
