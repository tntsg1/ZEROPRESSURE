extends "res://tests/guide_check.gd"
# 136 号 (user 2026-11-10: "右下角我点这个，想输入价格或者上下调价格都很难调啊"): the counter-offer box in
# a hulk-market listing's window, driven by injected clicks, keys and the wheel (never the real
# mouse). It must take a click and typing (the game's keys not stealing digits or letters), show the
# figure with thousands separators, step by a sensible share of the ask with its − / + keys (held:
# it repeats; Shift: bigger steps), fill the quick stops (−5 % / −10 % / −15 % / the estimate), take
# the wheel itself (the list behind does not scroll), submit on Enter, and Esc must only leave the
# editing (the window stays). The hold key and the inspections are checked too. Own test saves only.
#   tools/run_test.sh tests/haggle_input_check.gd --fixed-fps 60

var ui


func _initialize() -> void:
	Career.path = "user://zp_test_haggle_input_career.json"
	SaveGame.path = "user://zp_test_haggle_input_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(code: int, uni: int = 0, shift := false, ctrl := false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.unicode = uni if down else 0
		e.pressed = down
		e.shift_pressed = shift
		e.ctrl_pressed = ctrl
		Input.parse_input_event(e)
		await process_frame


func _type(s: String) -> void:
	for ch in s:
		var code := ch.unicode_at(0)
		await _key(code if ch >= "0" and ch <= "9" else OS.find_keycode_from_string(ch.to_upper()), code)


func _click(p: Vector2, button := MOUSE_BUTTON_LEFT, hold_frames := 1) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await process_frame
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = button
	e.pressed = true
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(e)
	for i in hold_frames:
		await process_frame
	var u := e.duplicate()
	u.pressed = false
	u.button_mask = 0
	Input.parse_input_event(u)
	await process_frame


func _wheel(p: Vector2, up: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.factor = 1.0
	Input.parse_input_event(e)
	await process_frame
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await process_frame


func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 5000000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"starmap_tour": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(60)
	g.open_ship_market()
	await _frames(40)
	ui = g.console_ui
	# the dearest listing that fits: its window, "more" opened
	var pick := {}
	for l in ShipMarket.data().listings:
		if ShipMarket.fits(l) and (pick.is_empty() or float(l.price) > float(pick.price)):
			pick = l
	var id := str(pick.id)
	var ask := float(pick.price)
	ui.chosen = id
	ui._detail()
	ui.more_box.visible = true
	await _frames(10)
	var box: Control = null
	for c in ui.detail_win.find_children("*", "", true, false):
		if c.has_meta("price_input"):
			box = c
	var spin: SpinBox = null
	if box == null:
		for c in ui.detail_win.find_children("*", "SpinBox", true, false):
			spin = c
	print("ask %s; control: %s" % [Pal.money(ask), "price input" if box != null else ("SpinBox" if spin != null else "none")])
	if box == null:
		# ---- the old SpinBox, as the player found it
		var le := spin.get_line_edit()
		await _click(_centre(le))
		print("  click: focus=%s text=\"%s\" (thousands separators: %s)" % [str(le.has_focus()), le.text, str(le.text.contains(","))])
		await _key(KEY_A, 0, false, true)
		await _key(KEY_DELETE)
		await _type("750000")
		print("  ctrl+A, delete, type 750000: text=\"%s\" value=%s" % [le.text, str(spin.value)])
		await _key(KEY_ENTER)
		print("  Enter: value=%s, offered=%s (Enter does not offer)" % [str(spin.value), str(ShipMarket.listing(id).get("haggled", false))])
		var v0 := spin.value
		var sr := spin.get_global_rect()
		await _click(Vector2(sr.end.x - 6, sr.position.y + 6))
		print("  the up arrow (%.0f px wide): %s → %s (step %s)" % [16.0, str(v0), str(spin.value), str(spin.step)])
		var sv: int = ui._scroll.scroll_vertical
		v0 = spin.value
		await _wheel(_centre(le), true)
		print("  wheel over the box: value %s → %s, list scroll %d → %d" % [str(v0), str(spin.value), sv, ui._scroll.scroll_vertical])
		le.grab_focus()
		await _key(KEY_ESCAPE)
		await _frames(3)
		print("  Esc while editing: window open=%s" % str(ui.detail_win.visible))
		Cap.save(root, "res://tests/out/haggle_before_zh.png")
		quit(0)
		return
	# ---- the new box
	var le2: LineEdit = box.field
	# the window's right side scrolls: the box brought into view as the 更多 key does
	ui._right_scroll.ensure_control_visible(box)
	await _frames(4)
	check(ui.detail_win.get_global_rect().end.y <= 1080.0 and ui.detail_win.get_global_rect().position.y >= 0.0, "the window with 更多 open stays on the screen (%s)" % str(ui.detail_win.get_global_rect()))
	await _click(_centre(le2))
	check(le2.has_focus(), "a click on the figure starts editing")
	check(le2.text.contains(","), "the figure shows thousands separators (%s)" % le2.text)
	await _key(KEY_A, 0, false, true)
	await _key(KEY_DELETE)
	check(le2.text == "" or le2.text == "$", "select all and delete clear it (%s)" % le2.text)
	var drone0: Vector2 = g.drone.global_position
	await _type("7")
	await _type("50000")
	await _frames(2)
	check(box.value == 750000.0 and le2.text.contains("750,000"), "typing 750000 reads 750,000 as it is typed (%s / %s)" % [le2.text, str(box.value)])
	await _type("wasde")
	check(box.value == 750000.0 and g.console_ui == ui and ui.detail_win.visible and g.drone.global_position.distance_to(drone0) < 1.0, "letters and the game's keys do nothing while editing (W A S D E)")
	var step: float = box.step_of(false)
	check(step >= 500.0 and step <= maxf(1000.0, ask * 0.02), "the − / + step is a sensible share of the ask (%s of %s)" % [Pal.money(step), Pal.money(ask)])
	var v: float = box.value
	await _click(_centre(box.plus))
	check(is_equal_approx(box.value, minf(box.max_value, v + step)), "+ adds one step (%s → %s)" % [Pal.money(v), Pal.money(box.value)])
	v = box.value
	await _click(_centre(box.minus))
	check(is_equal_approx(box.value, v - step), "− takes one step off")
	v = box.value
	await _click(_centre(box.minus), MOUSE_BUTTON_LEFT, 50)
	check(box.value <= v - step * 3.0, "held, − repeats (%s → %s in 50 frames)" % [Pal.money(v), Pal.money(box.value)])
	v = box.value
	Input.parse_input_event(_shift(true))
	await process_frame
	await _click(_centre(box.plus))
	Input.parse_input_event(_shift(false))
	await process_frame
	check(is_equal_approx(box.value, minf(box.max_value, v + box.step_of(true))) and box.step_of(true) > step, "Shift makes the step bigger (%s)" % Pal.money(box.step_of(true)))
	var sv2: int = ui._scroll.scroll_vertical
	v = box.value
	await _wheel(_centre(le2), false)
	check(is_equal_approx(box.value, v - step) and ui._scroll.scroll_vertical == sv2, "the wheel over the box steps the price and not the list")
	for st in box.stops:
		await _click(_centre(st))
		check(is_equal_approx(box.value, float(st.get_meta("to"))), "the stop %s fills %s" % [st.text, Pal.money(float(st.get_meta("to")))])
	check(box.hint.text.contains("%"), "the share under the ask is said live (%s)" % box.hint.text)
	box.set_value(ask * 0.5)
	await _frames(2)
	check(box.value < ask * ShipMarket.HAGGLE_MIN and box.hint.text != "", "far under what the seller takes: said, not stopped (%s)" % box.hint.text)
	await _click(_centre(le2))
	le2.grab_focus()
	await _key(KEY_ESCAPE)
	await _frames(3)
	check(not le2.has_focus() and ui.detail_win.visible, "Esc while editing only leaves the box; the window stays")
	box.set_value(snappedf(ask * 0.9, 100.0))
	await _frames(3)
	Cap.save(root, "res://tests/out/haggle_after_zh.png")
	# Enter offers: one fair counter-offer goes to the seller
	await _click(_centre(le2))
	await _key(KEY_A, 0, false, true)
	await _type(str(int(snappedf(ask * 0.97, 100.0))))
	await _key(KEY_ENTER)
	await _frames(10)
	var l2 := ShipMarket.listing(id)
	check(l2.is_empty() or l2.get("haggled", false), "Enter sends the offer (once)")
	ui.close()
	g.queue_free()
	await _frames(4)
	print("HAGGLE INPUT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _shift(down: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_SHIFT
	e.physical_keycode = KEY_SHIFT
	e.pressed = down
	return e
