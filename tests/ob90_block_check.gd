extends SceneTree
# OB-90 sample ship, the second way (94 号; user 2026-10-28: the whole mirror is 32.6 t, over the
# crane's 12 t: a backplane at a time): with the cover down and the rings locked, the outermost
# backplane cut free (its struts, its neighbour, its cables) comes away as one block of about
# 5.4 t with its three segments whole; the crane can take it; the equipment mouth takes it as one
# unit at the segments' worth — and by the real route: with the tube's casing stripped first (with
# it on, the crane finds no way out for a 2.6 x 5.9 m load), marked, the crane lifts it, carries it
# to its mouth, and it is paid for. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/ob90_block_check.gd

var g
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ob90block_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _switch(id: String, on: bool) -> void:
	g.sys.set_switch(id, on)
	g.world.ctrls[id].state = on


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ob90"
	g = load("res://scenes/main.tscn").instantiate()
	# the berth's crane fitted: the second way needs it
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": 1}}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	var op = g.optics
	_switch("CVR", true)
	for k in 60 * 16:
		await process_frame
		if op.cover_down() > 0.5:
			break
	for r in ["1", "2", "3"]:
		_switch(str(op.cfg.locks[r]), true)
	await _frames(10)
	check(op.cover_down() > 0.5 and op.ring_locked(1) and op.ring_locked(2) and op.ring_locked(3), "the cover down, the three rings locked (MCC powered: %s)" % str(op._powered(str(op.cfg.mcc))))
	# the outermost backplane on the upper half: the one carrying ring 3
	var bp = g.world.tag("BP-U1")
	var block: Array = [bp]
	for j in g.world.joints_of(bp):
		var o = g.world.pieces.get(j.b if j.a == bp.id else j.a)
		if o != null and str(o.name_key) in ["p_ob_actuator"]:
			block.append(o)
	for a in block.duplicate():
		for j in g.world.joints_of(a):
			var o = g.world.pieces.get(j.b if j.a == a.id else j.a)
			if o != null and str(o.name_key) == "p_ob_segment" and not block.has(o):
				block.append(o)
	var segs: Array = block.filter(func(p): return str(p.name_key) == "p_ob_segment")
	check(segs.size() == 3 and segs.all(func(p): return int(op.cfg.segments[p.tag].ring) == 3), "BP-U1 carries the three ring-3 segments: %s" % str(segs.map(func(p): return p.tag)))
	# cut it free: every joint and cable from the block to anything else
	var ids := {}
	for p in block:
		ids[p.id] = true
	for j in g.world.joints.duplicate():
		if j.alive and (ids.has(j.a) != ids.has(j.b)):
			g.world.kill_joint(j)
	for id in g.world.lines:
		var l = g.world.lines[id]
		if l.alive and (ids.has(l.a) != ids.has(l.b)):
			g.world.kill_line(l)
	g.world.relink()
	await _frames(5)
	var b = bp.body
	check(b != null and block.all(func(p): return p.body == b), "it comes away as one body")
	if b == null:
		print("OB90 BLOCK FAIL (%d failed)" % (fails))
		quit(1)
		return
	check(absf(b.total_mass() - 5.45) < 0.3 and b.total_mass() <= 12.0, "a block of %.2f t: within the crane's 12 t" % b.total_mass())
	check(segs.all(func(p): return p.intact and p.cond >= 0.99), "its segments whole (cond %s)" % str(segs.map(func(p): return snappedf(p.cond, 0.01))))
	check(op.is_block(b), "seen as a mirror block")
	var v: Dictionary = g.judge(b, "equip")
	check(v.ok, "the equipment mouth takes it as one unit (%s)" % str(v))
	var seg_worth := 0.0
	for p in segs:
		seg_worth += p.value * p.cond
	check(v.ok and float(v.value) >= seg_worth * 0.95, "worth its segments: %s (segments %s)" % [Pal.money(float(v.get("value", 0.0))), Pal.money(seg_worth)])
	# the inner ones still on the mirror: none chipped (outer ring first)
	var chipped: Array = op.cfg.segments.keys().filter(func(t): return op.chipped.has(str(t)))
	check(chipped.is_empty(), "taken outermost first, nothing chipped")
	# the real route: marked for the crane, lifted, carried, taken in by its mouth
	check(g.crane != null, "the berth has its crane")
	if g.crane != null:
		# the casing given up first (the way's own premise): the tube and everything round the mirror
		# stripped, only the mirror's own blocks left in the berth
		var cut := 0
		for id in g.world.order.duplicate():
			var p = g.world.pieces[id]
			if p.gone or p.body != null or str(p.name_key) in ["p_ob_segment", "p_ob_actuator", "p_ob_backplane"]:
				continue
			g.world.remove_piece(p)
			cut += 1
		g.world.relink()
		await _frames(5)
		print("  (the casing stripped first: %d pieces)" % cut)
		var said: String = g.crane.toggle(b)
		check(said == "crane_marked", "marked for the crane (%s), to %s" % [said, g.crane._zone_for(b)])
		var earned0: float = g.earned()
		var taken := false
		var n := 0
		for k in 60 * 240:
			await process_frame
			n = k
			if segs.all(func(p): return p.gone):
				taken = true
				break
		check(taken, "the crane brought it to its mouth and it was taken in (%.0f s)" % (n / 60.0))
		await _frames(30)
		check(g.earned() - earned0 >= seg_worth * 0.9, "paid as the mirror it is: +%s" % Pal.money(g.earned() - earned0))
	print("OB90 BLOCK %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
