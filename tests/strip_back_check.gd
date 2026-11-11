extends SceneTree
# 工业剖面: what is left behind a dismantled part of the ship. The user (PS-12, lower half taken
# off): "这个背景看起来很突兀，出戏" — a room's back wall and its grid kept showing at full strength
# once the plating round it was gone. Takes the lower half of a ship off (every piece below the
# middle line marked gone), then
#  - asserts: every room with less than half its shell left draws its back wall at most at 10 % (Cutaway.back_k) and
#    no panel grid; a room still whole keeps its wall; the back wall's tone stays under the
#    foreground equipment's
#  - shoots: the old picture, and the cutaway picture, of the half-stripped ship
# Own test saves only.   tools/run_test.sh tests/strip_back_check.gd --fixed-fps 60 -- [ship=ps12] [tag=after]
const Cap = preload("res://tests/cap.gd")

var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_stripback_career.json"
	SaveGame.path = "user://zp_test_stripback_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _hold(g, at: Vector2, z: float, n: int) -> void:
	for i in n:
		g.cam_override = at
		g.zoom_override = z
		g.zoom_now = z
		g.cam_pos = at
		g.drone.global_position = at + Vector2(-30, -16) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO
		await process_frame


func _run() -> void:
	var sid := "ps12"
	var tag := "after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ship="):
			sid = a.substr(5)
		elif a.begins_with("tag="):
			tag = a.substr(4)
	if tag == "before":
		Cutaway.skip["backfix"] = true
	Txt.zh = true
	Backdrop.t_fixed = 3.0
	Career.data = Career.fresh()
	Career.data.port = {"power": 2, "salvage": 1, "process": 2, "tug": 1, "trade": 1, "cargo": 1, "ring": 0}
	Career.save()
	Game.contract = {}
	Game.start_ship = sid
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.job = {"id": "strip-back", "ship": sid}
	await _frames(50)
	g.tutorial = null
	var w = g.world
	# every room opened (as a dismantled ship's are)
	for n in w.rooms:
		w.rooms[n].revealed = true
		w.rooms[n].reveal_t = 1.0
	var bb := Rect2()
	var first := true
	for id in w.order:
		var b := Geom.bbox(w.pieces[id].poly)
		bb = b if first else bb.merge(b)
		first = false
	var mid := bb.get_center().y
	# the lower half taken off
	var n_gone := 0
	for id in w.order:
		var p = w.pieces[id]
		if Geom.bbox(p.poly).get_center().y > mid + 0.3 * Geom.M:
			p.gone = true
			n_gone += 1
	w.redraw_all(true)
	w.dirty_back = true
	await _frames(4)
	print("%s: %d pieces taken off below y=%.1f m" % [sid, n_gone, mid / Geom.M])
	# the assertions (the rule, on this ship's rooms)
	var shells: Dictionary = w._room_shells()
	var stripped := 0
	var whole := 0
	for n in w.rooms:
		var r = w.rooms[n]
		if not r.has("shell0") or r.shell0 <= 0.0:
			continue
		var f: float = shells[n] / r.shell0
		var k := Cutaway.back_k(f)
		print("    room %s: shell %.0f%% left, wall k %.2f, grid %s" % [n, f * 100.0, k, Cutaway.back_grid(f)])
		if f < 0.5:
			stripped += 1
			_check(k <= 0.1, "room %s (shell %.0f%% left): its back wall gone (k %.2f <= 0.1)" % [n, f * 100.0, k])
			_check(not Cutaway.back_grid(f), "room %s: no panel grid" % n)
		elif f > 0.95:
			whole += 1
			_check(k > 0.9, "room %s (whole): its wall stays (k %.2f)" % [n, k])
	_check(stripped > 0, "%d rooms stripped, %d whole" % [stripped, whole])
	var wall := Pal.ROOM_LIT
	var lum := func(c: Color) -> float: return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	_check(lum.call(wall) * 1.25 < lum.call(Cutaway.MATS["machine"][0]), "the back wall's lit tone stays under the equipment's (%.3f < %.3f)" % [lum.call(wall) * 1.25, lum.call(Cutaway.MATS["machine"][0])])
	# the pictures: whole ship view and a close one on the stripped half
	var views := [["whole", minf(1920.0 * 0.86 / bb.size.x, 1080.0 * 0.8 / bb.size.y), bb.get_center()], ["low", Game.CAM_ZOOM * 0.7, Vector2(bb.position.x + bb.size.x * 0.35, mid + 2.0 * Geom.M)]]
	for look in ["old", "new"]:
		Pal.solid = look == "new"
		w.redraw_all(true)
		w.dirty_back = true
		w.cover_layer.queue_redraw()
		w.back_layer.queue_redraw()
		for v in views:
			await _hold(g, v[2], v[1], 30)
			Cap.save(root, "res://tests/out/stripback_%s_%s_%s_%s.png" % [tag, sid, look, v[0]])
	Pal.solid = true
	print("STRIP BACK %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	g.queue_free()
	await _frames(6)
	quit(1 if fails > 0 else 0)
