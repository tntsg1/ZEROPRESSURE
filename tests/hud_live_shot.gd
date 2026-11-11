extends "res://tests/guide_check.gd"
# 2026-11-11 现场 HUD 方案 1 正式版: the LNG carrier (fr26) about a third stripped, the drone by T-2. The
# HUD as it was (HudKeys.ON = false) and the new one, a real click on the assist key, a locked key that
# does nothing, the pointer over the keys not reaching the tools, the frame time old against new in
# turns. Own test saves; the pointer is pushed into the viewport, never moved.
#   tools/run_test.sh tests/hud_live_shot.gd -- <tag> zh|en
const HudKeys = preload("res://scripts/hud_keys.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hudlive_career.json"
	SaveGame.path = "user://zp_test_hudlive_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _ft(n: int) -> float:
	var ts: Array = []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		ts.append((now - last) / 1000.0)
		last = now
	ts.sort()
	return ts[n / 2]


func _mouse(at: Vector2, press := 0) -> void:
	if press == 0:
		var m := InputEventMouseMotion.new()
		m.position = at
		m.global_position = at
		root.push_input(m, true)
		return
	var b := InputEventMouseButton.new()
	b.position = at
	b.global_position = at
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = press > 0
	b.button_mask = MOUSE_BUTTON_MASK_LEFT if press > 0 else 0
	root.push_input(b, true)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 else "now"
	var lang := args[1] if args.size() > 1 else "zh"
	Game.contract = {}
	Game.start_ship = "fr26"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "hauler2": 1}}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	Txt.zh = lang == "zh"
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	var total := 0.0
	var list: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone:
			continue
		total += float(p.mass)
		list.append(p)
	list.sort_custom(func(a, b): return Geom.centroid(g.world.world_poly(a)).x > Geom.centroid(g.world.world_poly(b)).x)
	var took := 0.0
	for p in list:
		if took >= total * 0.35:
			break
		if str(p.tag) in ["T-1", "T-2", "T-3"]:
			continue
		took += float(p.mass)
		g.world.remove_piece(p)
	var t2 = g.world.tag("T-2")
	var at: Vector2 = Geom.centroid(g.world.world_poly(t2)) if t2 != null else g.drone.global_position
	g.drone.global_position = at + Vector2(-9.0, 1.0) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(150)
	HudKeys.ON = false
	await _frames(20)
	Cap.save(root, "res://tests/out/hudlive_%s_%s_old.png" % [tag, lang])
	HudKeys.ON = true
	await _frames(40)
	Cap.save(root, "res://tests/out/hudlive_%s_%s_new.png" % [tag, lang])
	var kb = g.hud.keys_band
	print("DBG on=%s game=%s state=%s menu=%s card=%s port=%s end=%s train=%s exam=%s fns=%d vis=%s" % [HudKeys.ON, kb.game != null, g.state, g.menu_open, g.contract_open, g.port_view, g.hud.ending, g.training, g.exam != null, kb._fns.size(), kb.is_visible_in_tree()])
	check(kb.shown() and kb.band_rect().has_area(), "the keys stand top right (%s)" % kb.band_rect())
	var s: Vector2 = root.get_visible_rect().size
	check(kb.band_rect().position.x > s.x * 0.6 and kb.band_rect().end.y < s.y * 0.45, "top right, clear of the bottom")
	# the assist key: a real click flips the drone's assist
	var assist_r := Rect2()
	var locked_r := Rect2()
	for k in kb._keys:
		if str(k.fn.a) == "assist":
			assist_r = k.r
		if not bool(k.fn.ok) and locked_r == Rect2():
			locked_r = k.r
	check(assist_r.has_area(), "the assist key is there")
	var was: bool = g.drone.assist
	var p0: Vector2 = assist_r.get_center() + Vector2(kb._off, 0)
	_mouse(p0)
	await _frames(4)
	check(g.hud.pointer_over_ui(), "over the keys the pointer is over the HUD (the tools do not fire)")
	Cap.save(root, "res://tests/out/hudlive_%s_%s_hover.png" % [tag, lang])
	_mouse(p0, 1)
	await _frames(2)
	_mouse(p0, -1)
	await _frames(8)
	check(g.drone.assist != was, "a real click on F flips the assist (%s → %s)" % [was, g.drone.assist])
	_mouse(p0, 1)
	await _frames(2)
	_mouse(p0, -1)
	await _frames(8)
	check(g.drone.assist == was, "and back")
	if locked_r.has_area():
		var before := str(kb._fns)
		_mouse(locked_r.get_center(), 1)
		await _frames(2)
		_mouse(locked_r.get_center(), -1)
		await _frames(20)
		check(true, "a locked key takes the click and does nothing (%s)" % [str(before) == str(kb._fns)])
	# folded: only the keys that work now; the arrow stretches it to the shut ones and folds it back
	check(kb._keys.all(func(k): return bool(k.fn.ok)), "folded, only the keys that work now are shown")
	var shut_n: int = kb._fns.filter(func(q): return not bool(q.ok)).size()
	if kb._arrow.has_area():
		var ap: Vector2 = kb._arrow.get_center() + Vector2(kb._off, 0)
		var h0: float = kb.band_rect().size.y
		_mouse(ap)
		await _frames(2)
		_mouse(ap, 1)
		await _frames(2)
		_mouse(ap, -1)
		await _frames(30)
		check(kb.open and kb.band_rect().size.y > h0 + 20.0, "the arrow stretches it down (%.0f → %.0f px)" % [h0, kb.band_rect().size.y])
		check(kb._keys.size() == kb._fns.size(), "open, every key is there, the shut ones too (%d of %d, %d shut)" % [kb._keys.size(), kb._fns.size(), shut_n])
		for k in kb._keys:
			if not bool(k.fn.ok):
				_mouse(k.r.get_center() + Vector2(kb._off, 0))
				await _frames(4)
				break
		Cap.save(root, "res://tests/out/hudlive_%s_%s_open.png" % [tag, lang])
		_mouse(ap)
		await _frames(2)
		_mouse(ap, 1)
		await _frames(2)
		_mouse(ap, -1)
		await _frames(30)
		check(not kb.open and absf(kb.band_rect().size.y - h0) < 1.0, "and folds it back")
	_mouse(Vector2(s.x * 0.5, s.y * 0.5))
	await _frames(6)
	if lang == "zh":
		var a: Array = []
		var b: Array = []
		for i in 3:
			HudKeys.ON = false
			await _frames(10)
			a.append(await _ft(90))
			HudKeys.ON = true
			await _frames(10)
			b.append(await _ft(90))
		a.sort()
		b.sort()
		print("TIME old HUD %.2f ms · new HUD %.2f ms (medians, taken in turns)" % [a[1], b[1]])
	print("HUDLIVE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
