extends "res://tests/guide_check.gd"
# 2026-11-04 (user: "左边点卖也卖不了，转移全部、全部卖出也弄不了"): the settlement's second page has
# to take real clicks while the job's ending screen is still up behind it. The HUD's ending
# handler used to swallow every left click (set_input_as_handled in _input), so nothing on the
# page ever reached _gui_input. Clicks here go through the viewport like the player's — never
# the user's mouse (Viewport.push_input, no warp).
#   tools/run_test.sh tests/disposal_click_check.gd --fixed-fps 60


func _initialize() -> void:
	# 128 号: the piece-by-piece page is the legacy path now (StoreBook off)
	StoreBook.ON = false
	Career.path = "user://zp_test_disposal_click_career.json"
	SaveGame.path = "user://zp_test_disposal_click_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _part(uid: String, cls: String, cond: float, value: float) -> Dictionary:
	return {"uid": uid, "cls": cls, "tag": uid.to_upper(), "nk": "p_motor", "cond": cond, "value": value, "ship": "gr7", "job": "DCL-1"}


func _click(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	root.push_input(m)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = p
		ev.global_position = p
		root.push_input(ev)
		await _frames(2)


func _wheel(p: Vector2, b: MouseButton, n: int) -> void:
	for i in n:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		ev.pressed = true
		ev.position = p
		ev.global_position = p
		root.push_input(ev)
		await _frames(1)


func _key(k: Key, ctrl := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.ctrl_pressed = ctrl
	ev.pressed = true
	root.push_input(ev)
	await _frames(2)


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.money = 100000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.active = {"id": "DCL-1", "ship": "gr7", "fee": 0.0, "fee_paid": true, "scope": "full"}
	Career.save()
	var parts: Array = []
	for i in 10:
		parts.append(_part("dcl_%d" % i, ["drive", "power", "heat", "nav"][i % 4], 1.0 if i % 3 else 0.5, 3000.0 + i * 500.0))
	Career.settle({"job_id": "DCL-1", "earned": 30000.0, "grade": 2, "ingot_value": 1500.0, "ingot_t": 98.1, "parts": parts, "parts_value": 50000.0})
	await _spawn()
	# the job's ending screen is up, as after a real settlement
	g.hud.ending = true
	g.hud.end_t = 9.0
	check(g.open_disposal(), "the page opens")
	await _frames(20)
	var p = g.disposal_ui
	var n0: int = p.left_n()
	check(n0 == 11, "eleven things to sort (%d)" % n0)
	# 2026-11-04 (user: "上下滚动"): four rows do not fit; the grid scrolls inside its view
	var view: Rect2 = p._view_rect()
	check(view.end.y <= p._sale_rect().position.y - 8.0, "the cards' view ends above the sale strip (%.0f / %.0f)" % [view.end.y, p._sale_rect().position.y])
	check(p._scroll_max() > 0.0 and not p._btns.has("sell:dcl_9"), "the last row is below the view, its sale button not live (scroll max %.0f)" % p._scroll_max())
	await _wheel(view.get_center(), MOUSE_BUTTON_WHEEL_DOWN, 3)
	await _frames(30)
	check(p.scroll > 0.0 and p._btns.has("sell:dcl_9"), "the wheel scrolls the last row into view (%.0f)" % p.scroll)
	await _click((p._btns["sell:dcl_9"] as Rect2).get_center())
	check(str(p._item("dcl_9").place) == "sold", "and its \"sell\" works there")
	await _key(KEY_Z, true)
	var img0 := root.get_texture().get_image()
	if img0 != null and img0.get_width() > 100:
		img0.save_png("res://tests/out/disposal_scroll.png")
	# the scrollbar's thumb dragged back to the top
	var th: Rect2 = p._bar_thumb()
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = true
	m.position = th.get_center()
	root.push_input(m)
	var mv := InputEventMouseMotion.new()
	mv.position = th.get_center() - Vector2(0, 400)
	root.push_input(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = mv.position
	root.push_input(up)
	await _frames(30)
	check(p.scroll < 0.5 and p.left_n() == 11, "the scrollbar dragged up: back at the top, nothing moved (%.0f, %d)" % [p.scroll, p.left_n()])
	# a card's own sale button
	var sb: Rect2 = p._btns.get("sell:dcl_1", Rect2())
	await _click(sb.get_center())
	check(str(p._item("dcl_1").place) == "sold", "the card's \"sell\" sells it (%s)" % str(p._item("dcl_1").place))
	# a card clicked: put away
	await _frames(20)
	var cr: Rect2 = p._rects.get("dcl_2", Rect2())
	await _click(cr.position + Vector2(cr.size.x * 0.5, 40.0))
	check(str(p._item("dcl_2").place) == "wh", "a card clicked is put away (%s)" % str(p._item("dcl_2").place))
	# move all
	await _click((p._btns["move_all"] as Rect2).get_center())
	check(p.left_n() == 0, "\"move all\" puts everything left away (%d left)" % p.left_n())
	# undo by key, then sell all
	for i in 9:
		await _key(KEY_Z, true)
	check(p.left_n() == 9, "Ctrl+Z puts the nine back (%d)" % p.left_n())
	await _click((p._btns["sell_all"] as Rect2).get_center())
	check(p.left_n() == 0 and p.cash_now() > 1000.0, "\"sell all\" sells the rest (%s now)" % Pal.money(p.cash_now()))
	await _frames(30)
	var sr: Rect2 = p._sale_rect()
	var on_strip := true
	for it in p.items:
		if str(it.place) == "sold" and not sr.encloses(p._rects[it.id]):
			on_strip = false
	check(on_strip, "all the sold things stay on the sale strip")
	var img1 := root.get_texture().get_image()
	if img1 != null and img1.get_width() > 100:
		img1.save_png("res://tests/out/disposal_sold_all.png")
	# nothing on the ending screen behind reacted to the clicks
	check(g.disposal_ui == p, "the page is still open")
	for i in 9:
		await _key(KEY_Z, true)
	await _frames(30)
	var img := root.get_texture().get_image()
	if img != null and img.get_width() > 100:
		img.save_png("res://tests/out/disposal_click.png")
	print("DISPOSAL CLICK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
