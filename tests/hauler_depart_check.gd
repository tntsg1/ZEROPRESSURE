extends "res://tests/guide_check.gd"
# The hauling drones do not stand idle by scrap they can take (user 2026-11-10: "有时候无人机明明能捡的，
# 还在那傻站了"). The cause found by tests/hauler_idle_probe.gd: with the rail arm fitted, the haulers
# left anything the arm *could* take to the arm, which carries one piece at a time; and a piece still
# easing out of the hull was put off for 2 s. Now:
#   A  loose scrap in the berth, the arm fitted: both idle haulers set off within 1 s, and the arm
#      takes a piece of its own — nobody goes for the same one
#   B  a piece just cut loose, still easing out of the hull: a machine sets off for it at once
#   C  a piece too heavy for them: they leave it, and say why — the reason (hauler.refuse_reason) is
#      what the pointer shows over it and the sign drawn on it
#   D  a marked light piece wedged between two heavy ones: gripped and carried (haulers alone)
#   E  (2026-11-11, FR-33: "刚拆下来一个零件，这无人机无动于衷") a hauler already after a piece by itself,
#      the operator marks that piece: it keeps on (it used to drop it and put it off 6 s)
#   F  a marked piece no hauler can take now: a loose one is still fetched within 1 s (the marks
#      used to keep both haulers off every other piece)
# Own test saves only.
#   tools/run_test.sh tests/hauler_depart_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_haulerdepart_career.json"
	SaveGame.path = "user://zp_test_haulerdepart_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rect(at: Vector2, size: Vector2, key: String, mass: float, cls: String = "metal"):
	var a := at - size * 0.5
	var b := at + size * 0.5
	var p = g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "tag": key, "cls": cls, "barrier": false, "mass": mass, "value": 100.0})
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "hauler2": 1, "arm": 1}}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-8, -14) * M
	g.drone.linear_velocity = Vector2.ZERO
	if g.arm == null:
		g.arm = RecoveryArm.new()
		g.arm.game = g
		g.add_child(g.arm)
	var hs: Array = g.haulers()
	check(hs.size() == 2 and g.arm != null, "two hauling drones and the rail arm")
	await _frames(30)
	for h in hs:
		check(h.state == "idle", "%s idle before" % h.who)
	# ---------------- A: four pieces of scrap
	var ex: float = Dock.zpos("equip").x / M
	var bodies := []
	for i in 4:
		bodies.append(_rect(Vector2(ex - 8.0 - i * 2.0, -4.0) * M, Vector2(0.6, 0.5) * M, "SCRAP-%d" % i, 0.4).body)
	var went := {}
	var arm_went := false
	for f in 60:
		await physics_frame
		for h in hs:
			if not went.has(h.who) and h.state != "idle":
				went[h.who] = (f + 1) / 60.0
		if g.arm.state != "idle":
			arm_went = true
	print("  A: set off after %s · arm %s" % [str(went), arm_went])
	check(went.size() == 2 and went.values().all(func(s): return s <= 1.0), "A: both idle haulers set off within 1 s (%s)" % str(went))
	var targets := hs.map(func(h): return h.body).filter(func(b): return b != null)
	if g.arm.body != null: targets.append(g.arm.body)
	var unique := {}
	for b in targets: unique[b] = true
	check(unique.size() == targets.size(), "A: no two machines go for the same piece (%d machines, %d pieces)" % [targets.size(), unique.size()])
	# let them clear the lot
	await _until(func(): return bodies.all(func(b): return not is_instance_valid(b) or b.capture != null or b.pieces.is_empty()), 4000)
	await _until(func(): return hs.all(func(h): return h.state == "idle"), 2000)
	# ---------------- B: a piece still easing out of the hull is taken at once
	var wall = g.world.add_piece("hull", Geom.rect_poly(Rect2(Vector2(ex - 12.0, -9.0) * M, Vector2(2.0, 2.0) * M)), {"key": "B-WALL", "cls": "metal", "barrier": true, "mass": 1.0, "value": 1.0})
	g.world.rebuild_cols(wall)
	var sunk = _rect(Vector2(ex - 11.0, -7.4) * M, Vector2(0.8, 0.8) * M, "SUNK", 0.4).body
	sunk.start_ghost(Vector2.DOWN)
	check(sunk.ghost > 0.0, "B: a piece easing out of the hull")
	var b_went := -1.0
	for f in 60:
		await physics_frame
		if hs.any(func(h): return h.body == sunk) or g.arm.body == sunk:
			b_went = (f + 1) / 60.0
			break
	check(b_went >= 0.0 and b_went <= 1.0, "B: a machine (a hauler or the arm) goes for it within 1 s (%.2f s)" % b_went)
	await _until(func(): return not is_instance_valid(sunk) or sunk.capture != null, 4000)
	await _until(func(): return hs.all(func(h): return h.state == "idle"), 2000)
	# ---------------- C: too heavy
	var heavy = _rect(Vector2(ex - 9.0, -4.0) * M, Vector2(1.4, 1.0) * M, "HEAVY", 2.4).body
	for f in 90:
		await physics_frame
	check(hs.all(func(h): return h.body != heavy), "C: a 2.4 t piece is left alone")
	var why: String = g.hauler.refuse_reason(heavy)
	check(why == "hauler_heavy", "C: and the reason is that it is too heavy (%s: %s)" % [why, g.txt(why)])
	var said: String = g.hauler.refuse_text(heavy)
	check(said.begins_with("2.4 t") and "1.5 t" in said, "C: the words say how heavy and what would take it (%s)" % said)
	# the pointer over it, the grapple in hand: the hover finds it (and the tools draw the reason there)
	g.tools.set_tool(3, true)
	g.drone.global_position = (heavy.global_transform * heavy.center_of_mass) + Vector2(3.0, 0.0) * M
	g.bot.aim = heavy.global_transform * heavy.center_of_mass
	await _frames(4)
	check(g.tools.hover.get("kind", "") == "piece" and g.tools.hover.piece.body == heavy, "C: the pointer over it finds it (the reason shows by the pointer)")
	heavy.global_position += Vector2(0.0, 60.0) * M
	heavy.queue_free()
	await _frames(4)
	# ---------------- D: a marked light piece between two heavy ones (user 2026-11-11: the haulers
	# hovered by the marked pieces and never took them)
	g.tools.set_tool(2, true)
	g.drone.global_position = Vector2(-8, -14) * M
	# (the haulers alone here: the arm would take it otherwise)
	await _until(func(): return g.arm.state == "idle", 3000)
	g.arm.queue_free()
	g.arm = null
	await _frames(2)
	var dc := Vector2(ex - 10.0, -5.0) * M
	var w1 = _rect(dc + Vector2(-1.15, 0.0) * M, Vector2(1.2, 1.6) * M, "HEAVY-L", 3.0).body
	var w2 = _rect(dc + Vector2(1.15, 0.0) * M, Vector2(1.2, 1.6) * M, "HEAVY-R", 3.0).body
	var mid = _rect(dc, Vector2(0.6, 0.6) * M, "WEDGED", 0.3).body
	await _frames(2)
	print("  D: mark → %s" % g.hauler.toggle(mid))
	var d_pick := -1.0
	var d_close := INF
	for f in 600:
		await physics_frame
		for h in hs:
			if h.body == mid:
				d_close = minf(d_close, h.pos.distance_to(mid.global_transform * mid.center_of_mass))
				if h.state in ["carry", "release"] and d_pick < 0.0:
					d_pick = (f + 1) / 60.0
		if d_pick >= 0.0: break
	print("  D: gripped after %.2f s (closest %.1f px) · %s" % [d_pick, d_close, str(hs.map(func(h): return "%s %s" % [h.who, h.state]))])
	check(d_pick >= 0.0 and d_pick <= 6.0, "D: a marked piece between two heavy ones is gripped and carried (%.2f s)" % d_pick)
	await _until(func(): return hs.all(func(h): return h.state == "idle"), 3000)
	# ---------------- E: a hauler already after a piece of its own accord, then the operator marks it
	var e = _rect(Vector2(ex - 9.0, -3.0) * M, Vector2(0.6, 0.5) * M, "E-SCRAP", 0.4).body
	var eh = null
	for f in 60:
		await physics_frame
		for h in hs:
			if h.body == e: eh = h
		if eh != null: break
	check(eh != null and eh.auto_pickup, "E: a hauler sets off for a fresh piece by itself")
	print("  E: mark → %s" % g.hauler.toggle(e))
	var kept := true
	for f in 30:
		await physics_frame
		kept = kept and eh != null and eh.body == e
	check(kept and float(e.get_meta("no_way_till", -1.0)) < 0.0, "E: marking the piece it is after: it keeps on (no 6 s put-off)")
	await _until(func(): return not is_instance_valid(e) or e.capture != null, 3000)
	await _until(func(): return hs.all(func(h): return h.state == "idle"), 3000)
	# ---------------- F: a marked piece nobody can take now does not keep them off the rest
	var fx = _rect(Vector2(ex - 15.0, -3.0) * M, Vector2(0.6, 0.5) * M, "F-MARKED", 0.4).body
	g.hauler.toggle(fx)
	fx.set_meta("no_way_till", g.hauler.t + 30.0)
	var fy = _rect(Vector2(ex - 9.0, -3.0) * M, Vector2(0.6, 0.5) * M, "F-LOOSE", 0.4).body
	var f_went := -1.0
	for f in 90:
		await physics_frame
		if hs.any(func(h): return h.body == fy):
			f_went = (f + 1) / 60.0
			break
	check(f_went >= 0.0 and f_went <= 1.0, "F: with a marked piece put off, a hauler still sets off for the loose one within 1 s (%.2f s)" % f_went)
	g.hauler.queue.erase(fx)
	fx.queue_free()
	await _until(func(): return hs.all(func(h): return h.state == "idle"), 3000)
	# ---------------- G (user 2026-11-11, MY-48: the safe unscrewed, no hauler came): whole equipment,
	# loose and unmarked, is taken by itself with the machines on and goes into the equipment mouth
	var gp = _rect(Vector2(ex - 12.0, -3.0) * M, Vector2(0.8, 0.6) * M, "G-SAFE", 0.4, "equip")
	var gb = gp.body
	check(gp.intact and not g.dock.is_scrap(gb) and not g.hauler.queue.has(gb), "G: a loose intact piece of equipment, unmarked")
	var g_went := -1.0
	for f in 180:
		await physics_frame
		if hs.any(func(h): return h.body == gb):
			g_went = (f + 1) / 60.0
			break
	check(g_went >= 0.0 and g_went <= 3.0, "G: a hauler sets off for it within 3 s (%.2f s)" % g_went)
	var g_mouth := ""
	await _until(func(): return not is_instance_valid(gb) or gb.capture != null, 4000)
	if is_instance_valid(gb) and gb.capture != null: g_mouth = str(gb.capture.get("zone", "")) if gb.capture is Dictionary else "taken"
	check(not is_instance_valid(gb) or gb.capture != null, "G: and it goes into a mouth (%s)" % g_mouth)
	# with the machines off it stays where it is
	var gq = _rect(Vector2(ex - 12.0, -3.0) * M, Vector2(0.8, 0.6) * M, "G-OFF", 0.4, "equip").body
	g.toggle_auto()
	for f in 120:
		await physics_frame
	check(hs.all(func(h): return h.body != gq), "G: with the machines off (J) no hauler takes it")
	g.toggle_auto()
	print("hauler_depart_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
