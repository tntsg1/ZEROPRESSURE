extends "res://tests/guide_check.gd"
# 2026-11-11 用户选定 A+B (scripts/ui_kit/key_fx.gd): a key on the terminal's home, the exchange, the
# stores and the settings, hovered and pressed by mouse events pushed into this test's own viewport (the
# real mouse is never moved): checks that the key rises, sinks and springs back, that the keys around it
# stay still, and shoots close-ups (rest / hover / pressed). Own test saves only.
#   tools/run_test.sh tests/charcoal_keyfx_shot.gd --fixed-fps 60
const KeyFx = preload("res://scripts/ui_kit/key_fx.gd")
var shots := []      # [screen, state, Image crop]
var at := Vector2(-50, -50)


func _initialize() -> void:
	Career.path = "user://zp_test_charcoal_keyfx_career.json"
	SaveGame.path = "user://zp_test_charcoal_keyfx_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = p - at
	ev.position = p
	ev.global_position = p
	at = p
	root.push_input(ev)


func _btn(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = on
	ev.position = at
	ev.global_position = at
	root.push_input(ev)


# a drawn key of this canvas item: [its state, its rect on the screen]
func _drawn_key(ci: CanvasItem, min_w := 150.0) -> Array:
	var m = KeyFx._inst
	if m == null or ci == null or not is_instance_valid(ci):
		return []
	var rec: Dictionary = m._cis.get(ci.get_instance_id(), {})
	for kid in rec.get("keys", {}):
		var st: Dictionary = rec.keys[kid]
		var r: Rect2 = st.r
		if r.size.x >= min_w and r.size.y >= 36.0:
			var xf := ci.get_global_transform_with_canvas()
			return [st, Rect2(xf * r.position, xf.basis_xform(r.size))]
	return []


func _crop(r: Rect2) -> Image:
	var img: Image = Cap.to_srgb8(root.get_texture().get_image())
	var c := r.grow_individual(40, 30, 40, 30)
	c = c.intersection(Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height())))
	return img.get_region(Rect2i(c))


func _st(f: Callable) -> Dictionary:
	var v = f.call()
	return v if v is Dictionary else {}


func _probe(name: String, st_of: Callable, screen_r: Rect2) -> void:
	_move(screen_r.position + Vector2(-60, -60))
	await _frames(30)
	shots.append([name, "常态", _crop(screen_r)])
	var p := screen_r.get_center() + Vector2(screen_r.size.x * 0.22, 2)
	_move(p)
	await _frames(24)
	var st: Dictionary = _st(st_of)
	check(float(st.get("hov", 0.0)) > 0.9, "%s: under the pointer it rises (%.2f)" % [name, float(st.get("hov", 0.0))])
	shots.append([name, "悬停", _crop(screen_r)])
	_btn(true)
	await _frames(10)
	st = _st(st_of)
	check(float(st.get("prs", 0.0)) > 0.85, "%s: held, it sinks (%.2f)" % [name, float(st.get("prs", 0.0))])
	shots.append([name, "按下", _crop(screen_r)])
	_btn(false)
	_move(screen_r.position + Vector2(-60, -60))
	await _frames(40)
	st = _st(st_of)
	check(absf(float(st.get("hov", 1.0))) < 0.05 and absf(float(st.get("prs", 1.0))) < 0.05, "%s: let go and left, it springs back (%.2f / %.2f)" % [name, float(st.get("hov", 1.0)), float(st.get("prs", 1.0))])


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_tour": true, "port_walk": true, "first_tow": true, "store_guide_done": true, "store_counter": true}
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.money = 214573.0
	Career.data.history = [{"id": "TUG-001"}]
	Career.save()
	await _spawn()
	await _frames(30)
	if g.codex_hud != null:
		g.codex_hud.visible = false
	# 1. the terminal's home: an app key (drawn by the page)
	g.open_console("terminal")
	await _frames(10)
	var term = g.console_ui
	term._skip_boot()
	await _frames(60)
	_move(Vector2(5, 5))
	await _frames(5)
	var k: Array = _drawn_key(term)
	check(not k.is_empty(), "the terminal's home keys are charcoal keys (KeyFx tracks them)")
	if not k.is_empty():
		await _probe("终端首页", func(): var a := _drawn_key(term); return a[0] if not a.is_empty() else {}, k[1])
	# the frame time with the pointer resting on a key and with it moving across the page
	var ms := []
	for off in [true, false]:
		KeyFx.off_in_tests = off
		await _frames(10)
		var t0 := Time.get_ticks_usec()
		for i in 120:
			_move(Vector2(300 + (i % 60) * 20, 520 + (i / 60) * 120))
			await _frames(1)
		ms.append((Time.get_ticks_usec() - t0) / 120000.0)
	KeyFx.off_in_tests = false
	print("KEYFX terminal, pointer sweeping the keys: without %.2f ms, with %.2f ms a frame" % [ms[0], ms[1]])
	term.close()
	await _frames(10)
	# 2. the exchange: its tab key (drawn)
	g.open_hall("")
	await _frames(60)
	var hp = g.console_ui
	k = _drawn_key(hp, 200.0)
	check(not k.is_empty(), "the exchange's keys are charcoal keys")
	if not k.is_empty():
		await _probe("交易行", func(): var a := _drawn_key(hp, 200.0); return a[0] if not a.is_empty() else {}, k[1])
	if g.console_ui != null:
		g.console_ui.close()
	await _frames(10)
	# 3. the stores: a filter key (drawn)
	g.open_store()
	await _frames(60)
	var sp = g.console_ui
	k = _drawn_key(sp, 200.0)
	check(not k.is_empty(), "the stores' keys are charcoal keys")
	if not k.is_empty():
		await _probe("仓库", func(): var a := _drawn_key(sp, 200.0); return a[0] if not a.is_empty() else {}, k[1])
	if g.console_ui != null:
		if g.console_ui.has_method("close"):
			g.console_ui.close()
		else:
			g.console_ui._close()
	await _frames(10)
	# 4. the settings: its back key (drawn)
	g.settings_panel.open()
	await _frames(50)
	var sc: CanvasItem = g.settings_panel.c
	k = _drawn_key(sc, 300.0)
	check(not k.is_empty(), "the settings' back key is a charcoal key")
	if not k.is_empty():
		await _probe("设置", func(): var a := _drawn_key(sc, 300.0); return a[0] if not a.is_empty() else {}, k[1])
	# reduce motion: no rise and no light under the pointer, only the press sinking
	var was := Txt.reduce_motion
	Txt.reduce_motion = true
	_move(Vector2(5, 5))
	await _frames(20)
	k = _drawn_key(sc, 300.0)
	if not k.is_empty():
		_move(k[1].get_center())
		await _frames(20)
		var st: Dictionary = _drawn_key(sc, 300.0)[0]
		check(float(st.hov) == 0.0, "reduce motion: no rise under the pointer (%.2f)" % float(st.hov))
		_btn(true)
		await _frames(4)
		st = _drawn_key(sc, 300.0)[0]
		check(float(st.prs) == 1.0, "reduce motion: the press still sinks, at once (%.2f)" % float(st.prs))
		_btn(false)
		_move(Vector2(5, 5))
		await _frames(10)
	Txt.reduce_motion = was
	g.settings_panel.close()
	await _frames(10)
	# 5. a real Button (style_button): the furnace desk's close key
	Career.data.port["process"] = 1
	Career.data.port["power"] = 1
	Career.save()
	# the sheet: rows the screens, columns rest / hover / pressed
	var cw := 0
	var ch := 0
	for s in shots:
		cw = maxi(cw, (s[2] as Image).get_width())
		ch = maxi(ch, (s[2] as Image).get_height())
	var rows := shots.size() / 3
	var sheet := Image.create(cw * 3 + 20, (ch + 10) * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.03, 0.03, 0.035))
	for i in shots.size():
		var im: Image = shots[i][2]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % 3) * (cw + 10), (i / 3) * (ch + 10)))
	sheet.save_png("res://tests/out/keyfx_closeups_raw.png")
	print("KEYFX rows: ", ", ".join(shots.filter(func(s): return s[1] == "常态").map(func(s): return s[0])))
	print("CHARCOAL KEYFX %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(0)
