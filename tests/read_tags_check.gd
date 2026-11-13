extends SceneTree
# 公测反馈 #15 (2026-11-13): reading tags put away one by one (the × under the pointer), all at once
# (clear_reads, Y), the part still measured, a new measure shows it again; the × click never reaches
# the tools; the tags keep off the bolts and clips.
#   tools/run_test.sh tests/read_tags_check.gd --fixed-fps 60                (checks)
#   tools/run_test.sh tests/read_tags_check.gd --fixed-fps 60 -- shots       (the before/after picture)
# Test saves only; the pointer is the bot's aim, the clicks the bot's buttons.
const Cap = preload("res://tests/cap.gd")
const Hud = preload("res://scripts/hud.gd")

var g
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_readtags_career.json"
	SaveGame.path = "user://zp_test_readtags_save.json"
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


func _world(sp: Vector2) -> Vector2:
	return g.get_viewport().get_canvas_transform().affine_inverse() * sp


func _click(key: String) -> void:
	g.bot[key] = true
	await _frames(2)
	g.bot[key] = false
	await _frames(3)


func _visible(p) -> bool:
	if p.gone or p.body != null:
		return false
	var l: Array = g.world.pieces_at(_c(p))
	return not l.is_empty() and l[0] == p and not g.world.hidden(_c(p))


func _measure(p, at := Vector2.INF) -> String:
	var aim: Vector2 = at if at.is_finite() else _c(p)
	g.tools.tool = 1
	g.drone.global_position = aim + Vector2(-3.0 * Geom.M, -2.0 * Geom.M)
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	g.bot.aim = aim
	await _frames(10)
	var before: Array = g.sys.readings.keys()
	await _click("lmb")
	await _frames(30)
	for k in g.sys.readings:
		if not k in before:
			return str(k)
	# measured before: the same key, a new reading
	for k in g.sys.readings:
		if g.sys.readings[k].get("piece") == p:
			return str(k)
	return ""


func _key(code: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "m14"
	var shots := OS.get_cmdline_user_args().has("shots")
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "mmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	for r in g.world.rooms:
		g.world.rooms[r].revealed = true
	g.world.redraw_all(true)
	await _frames(4)
	var hud = g.hud
	ok(Keys.codes("clear_reads") == [KEY_Y] and "clear_reads" in Keys.ORDER, "clear_reads is a key of its own (Y), in the key settings")
	var clash := []
	for a in Keys.ORDER:
		if a != "clear_reads" and KEY_Y in Keys.codes(a):
			clash.append(a)
	ok(clash.is_empty(), "Y is no other action's key %s" % [clash])
	# ---- a part with bolts on it: the tag measured right by a bolt
	var part = null
	var jat := Vector2.INF
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not _visible(p) or g.world.joints_of(p).size() < 2:
			continue
		part = p
		var j = g.world.joints_of(p)[0]
		jat = g.world.joint_world(j)
		break
	ok(part != null, "found a part held by bolts: %s" % part)
	if part == null:
		quit(1)
		return
	# measured a little inside, next to the bolt
	var inside: Vector2 = jat + (_c(part) - jat).normalized() * 0.6 * Geom.M
	var key := await _measure(part, inside)
	ok(key != "" and g.sys.readings.has(key), "the meter left a reading: %s" % key)
	g.tools.tool = 4
	g.bot.aim = _c(part) + Vector2(0, 40.0 * Geom.M)
	await _frames(20)
	if shots:
		g.bot.aim = g.world.joint_world(g.world.joints_of(part)[0])
		await _frames(6)
		Hud.tag_fix = false
		await _frames(4)
		Cap.save(root, "res://proofs/fb15_read_tags_before.png")
		Hud.tag_fix = true
		await _frames(4)
		Cap.save(root, "res://proofs/fb15_read_tags_after.png")
		print("SHOT joint at ", g.hud.to_screen(g.bot.aim), " tag ", g.hud.tag_rect_of.get(key))
	# ---- off the bolts: no tag on a bolt or clip on screen
	var keep: Array = hud._tag_keep()
	var on_bolt := []
	for k in hud.tag_rect_of:
		var tr: Rect2 = hud.tag_rect_of[k]
		for z in keep:
			if Rect2(tr.position, tr.size + Vector2(Hud.TAG_X, 0)).intersects(z):
				on_bolt.append(k)
				break
	ok(on_bolt.is_empty(), "no tag sits on a bolt or clip (%d tags, %d bolts on screen) %s" % [hud.tag_rect_of.size(), keep.size(), on_bolt])
	ok(hud.tag_rect_of.has(key), "the tag is drawn")
	# ---- the ×: only under the pointer
	ok(not hud.tag_x.has_area(), "no × while the pointer is elsewhere")
	var tr: Rect2 = hud.tag_rect_of.get(key, Rect2())
	g.bot.aim = _world(tr.get_center())
	await _frames(4)
	ok(hud.tag_x.has_area() and hud.tag_x_key == key, "pointer on the tag: its × shows")
	if shots:
		g.bot.aim = _world(hud.tag_x.get_center())
		await _frames(4)
		Cap.save(root, "res://proofs/fb15_read_tags_x.png")
	# ---- the × clicked with the laser in hand: the tag goes, nothing is cut
	g.tools.tool = 2
	await _frames(3)
	g.bot.aim = _world(hud.tag_x.get_center())
	await _frames(3)
	var n_read: int = g.sys.readings.size()
	g.bot.lmb = true
	var cut := false
	for i in 20:
		await process_frame
		cut = cut or g.tools.cutting or g.tools.lmb
	g.bot.lmb = false
	await _frames(4)
	ok(g.sys.readings[key].get("tag_off", false), "the × put the tag away")
	ok(not cut, "the × click never reached the laser")
	ok(g.sys.readings.has(key) and g.sys.readings.size() == n_read, "the reading itself stays (the part counts as measured)")
	ok(not hud.tag_rect_of.has(key), "the tag is no longer drawn")
	# ---- measured again: the tag back
	var key2 := await _measure(part, inside)
	ok(key2 == key and not g.sys.readings[key].get("tag_off", false) and hud.tag_rect_of.has(key), "a new measure shows it again")
	# ---- all at once: Y
	var other = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p != part and _visible(p) and _c(p).distance_to(_c(part)) < 8.0 * Geom.M and _c(p).distance_to(_c(part)) > 1.5 * Geom.M:
			other = p
			break
	if other != null:
		await _measure(other)
	g.tools.tool = 4
	g.bot.aim = _c(part) + Vector2(0, 40.0 * Geom.M)
	await _frames(6)
	var shown: int = hud.tags_shown()
	ok(shown >= 2, "two readings shown (%d)" % shown)
	var keys_before: Array = g.sys.readings.keys()
	await _key(KEY_Y)
	await _frames(3)
	ok(hud.tags_shown() == 0 and hud.tag_rect_of.is_empty(), "Y put every tag away")
	ok(g.sys.readings.keys() == keys_before, "every reading still there (%d)" % keys_before.size())
	ok(hud.hint_text.contains("仍算测过"), "the hint says so: " + hud.hint_text)
	ok(not hud.hint_text.contains("机器人"), "no 机器人 in it")
	# the function band's key: lit with tags, shut without
	var f = hud.keys_band._fn_list().filter(func(q): return q.a == "clear_reads")
	ok(f.size() == 1 and not bool(f[0].ok), "the band's key is shut with no tags shown")
	await _measure(part, inside)
	f = hud.keys_band._fn_list().filter(func(q): return q.a == "clear_reads")
	ok(f.size() == 1 and bool(f[0].ok), "and lit with one")
	print("read_tags_check: %d fails" % fails)
	quit(fails)
