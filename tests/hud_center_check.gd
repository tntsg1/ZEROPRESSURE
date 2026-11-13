extends SceneTree
# 2026-11-12 HUD 中央交互 (scripts/hud_center.gd): hover / select / cancel / keep clear / grading.
#   tools/run_test.sh tests/hud_center_check.gd --fixed-fps 60                 (checks)
#   tools/run_test.sh tests/hud_center_check.gd --fixed-fps 60 -- shots 1920   (and the old/new pictures)
# Test saves only; the pointer is the bot's aim, the clicks the bot's buttons (the real mouse is never touched).
const Cap = preload("res://tests/cap.gd")
const HudCenter = preload("res://scripts/hud_center.gd")

var g
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_hudcenter_career.json"
	SaveGame.path = "user://zp_test_hudcenter_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _c(p) -> Vector2:
	return g.world.frame(p) * Geom.centroid(p.poly)


func _find(pred: Callable):
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null:
			continue
		var at := _c(p)
		if g.world.hidden(at):
			continue
		var l: Array = g.world.pieces_at(at)
		if l.is_empty() or l[0] != p:
			continue
		if pred.call(p):
			return p
	return null


var park := Vector2.INF
func _aim(p, off := Vector2.ZERO) -> void:
	var at := _c(p)
	if park.is_finite() and park.distance_to(at) < 7.0 * Geom.M:
		g.drone.global_position = park
	else:
		g.drone.global_position = at + Vector2(-4.0 * Geom.M, -3.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.bot.aim = at + off
	await _frames(12)


func _click(key: String) -> void:
	g.bot[key] = true
	await _frames(2)
	g.bot[key] = false
	await _frames(3)


func _scr(w: Vector2) -> Vector2:
	return g.get_viewport().get_canvas_transform() * w


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "m14"
	var args := OS.get_cmdline_user_args()
	var shots := args.has("shots")
	var tag := args[args.find("shots") + 1] if shots and args.size() > args.find("shots") + 1 else "x"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "mmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	var hc = g.hud_center
	# the hull opened up as if cut away (the rooms' contents in view)
	for r in g.world.rooms:
		g.world.rooms[r].revealed = true
	g.world.redraw_all(true)
	await _frames(4)
	ok(hc != null, "HudCenter is on the game")
	var tank = _find(func(p): return p.hazard == "gas_tank")
	# a plain plate in the same picture as the tank
	var plate = null
	if tank != null:
		var best := INF
		for id in g.world.order:
			var q = g.world.pieces[id]
			if q.gone or q.body != null or q.cls != "metal" or absf(Geom.area(q.poly)) < 900.0 or absf(Geom.area(q.poly)) > 60000.0:
				continue
			var l: Array = g.world.pieces_at(_c(q))
			if l.is_empty() or l[0] != q or g.world.hidden(_c(q)):
				continue
			var dd := _c(q).distance_to(_c(tank))
			if dd < best and dd > 2.5 * Geom.M and dd < 7.0 * Geom.M:
				best = dd
				plate = q
	var other = _find(func(p): return p != tank and hc.danger(p))
	ok(plate != null and tank != null and other != null, "found a plate, a gas tank and a second danger part %s %s %s" % [plate, tank, other])
	if plate == null or tank == null:
		quit(1)
		return
	# ---- hover a plain plate: outline + tag, no card, the grade says plain
	g.tools.tool = 1
	# the drone parked between the two, the view settled on it
	park = (_c(plate) + _c(tank)) * 0.5 + Vector2(0, -2.5 * Geom.M)
	g.drone.global_position = park
	g.drone.reset_physics_interpolation()
	await _frames(150 if shots else 20)
	await _aim(plate)
	ok(g.tools.hover.get("piece") == plate, "hover is on the plate")
	ok(HudCenter.tag_rect.has_area(), "the plate gets a tag")
	ok(not hc.danger(plate), "a plate is not a danger part")
	var st: Array = hc.status(plate, g.tools.hover)
	ok(not st[1], "the plate's tag does not warn: " + str(st[0]))
	if shots:
		await _shot("hud_center_%s_hover_plate" % tag)
	# a click on it: no card (plain parts keep the tag only)
	await _click("mmb")
	ok(hc.sel == null and not hc.card_rect.has_area(), "selecting a plate opens no card")
	# ---- hover the gas tank: a warning tag naming the danger, with its icon and text
	await _aim(tank)
	ok(g.tools.hover.get("piece") == tank, "hover is on the tank")
	st = hc.status(tank, g.tools.hover)
	ok(st[1] and str(st[2]) == "pressure", "the tank's tag warns of pressure: " + str(st[0]))
	ok("pressure" in hc.dangers(tank), "the tank grades as a pressure danger")
	if shots:
		await _shot("hud_center_%s_hover_tank" % tag)
	# ---- select it (middle button): the card, beside it, clear of the pointer and the drone
	await _click("mmb")
	ok(hc.sel == tank, "middle click selects the tank")
	await _frames(12)
	ok(hc.card_rect.has_area(), "the card is up")
	var rows: Array = hc.rows(tank)
	var has_p := rows.any(func(r): return r[0] == "pressure")
	ok(has_p, "the card has a pressure row: " + str(rows.map(func(r): return "%s=%s" % [r[1], r[2]])))
	ok(not hc.card_rect.grow(-1).intersects(Rect2(_scr(g.bot.aim) - Vector2(40, 40), Vector2(80, 80))), "the card keeps clear of the pointer (%s)" % hc.card_side)
	ok(not hc.card_rect.intersects(Rect2(_scr(g.drone.global_position) - Vector2(40, 40), Vector2(80, 80))), "the card keeps clear of the drone")
	if shots:
		await _shot("hud_center_%s_card_tank" % tag)
	# ---- keep clear: the pointer moved to where the card stands, the card goes elsewhere
	var was: Rect2 = hc.card_rect
	var side0: String = hc.card_side
	g.bot.aim = g.get_viewport().get_canvas_transform().affine_inverse() * was.get_center()
	await _frames(8)
	ok(not hc.card_rect.intersects(Rect2(_scr(g.bot.aim) - Vector2(40, 40), Vector2(80, 80))), "pointer on the card's place: it moves (%s -> %s)" % [side0, hc.card_side])
	# with the laser cutting next to it: still up, clear of the beam's spot
	g.tools.tool = 2
	g.bot.aim = _c(tank) + Vector2(-1.5 * Geom.M, 0)
	g.bot.lmb = true
	await _frames(10)
	ok(hc.sel == tank and hc.card_rect.has_area(), "the card stays while cutting")
	ok(not hc.card_rect.intersects(Rect2(_scr(g.tools.front if g.tools.cutting else g.bot.aim) - Vector2(40, 40), Vector2(80, 80))), "the card keeps clear of the beam")
	g.bot.lmb = false
	await _frames(4)
	# ---- cancel: Esc (the site's back), a new target, blank space
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(ev)
	await _frames(3)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(3)
	ok(hc.sel == null and not g.menu_open, "Esc closes the card and not the menu")
	g.tools.tool = 1
	await _aim(tank)
	await _click("mmb")
	ok(hc.sel == tank, "selected again")
	if other != null:
		await _aim(other)
		await _click("mmb")
		ok(hc.sel == other, "another danger part takes the card over")
	g.bot.aim = g.drone.global_position + Vector2(0, -40.0 * Geom.M)
	await _frames(4)
	await _click("mmb")
	ok(hc.sel == null, "middle click on blank space closes it")
	# the left button stays the tools' own: it neither opens nor closes the card
	await _aim(tank)
	await _click("lmb")
	ok(hc.sel == null, "left click with the meter does not select")
	await _click("mmb")
	ok(hc.sel == tank, "middle click on the tank selects it")
	g.tools.tool = 4
	g.bot.aim = g.drone.global_position + Vector2(0, -40.0 * Geom.M)
	await _frames(4)
	await _click("lmb")
	ok(hc.sel == tank, "left click on blank space leaves the card")
	await _click("mmb")
	ok(hc.sel == null, "middle click on blank space closes it")
	# ---- off: the old picture (tag none from here; look.gd draws its target box again)
	HudCenter.on = false
	await _aim(tank)
	ok(not HudCenter.tag_rect.has_area(), "HudCenter.on = false draws nothing")
	HudCenter.on = true
	print("hud_center_check: %d fails" % fails)
	quit(fails)


# the same moment twice: the old picture, then the new
func _shot(name: String) -> void:
	var keep_sel = g.hud_center.sel
	HudCenter.on = false
	await _frames(3)
	Cap.save(root, "res://proofs/%s_old.png" % name)
	HudCenter.on = true
	g.hud_center.sel = keep_sel
	g.hud_center.card_k = 1.0
	await _frames(3)
	Cap.save(root, "res://proofs/%s_new.png" % name)
