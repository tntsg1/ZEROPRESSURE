extends SceneTree
# World.pieces_at / piece_at through the grid of attached pieces (60 FPS work 2026-10-27) find
# exactly what the walk through every piece in draw order found: on ARK-01, SA-200 and NR-95 at
# rest, with 150 loose plates, after cuts that leave pieces in two, after a loose body drifts, after a displaced part,
# after a save is read back. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/pick_grid_check.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_pick_grid.json"
	SaveGame.allow_test = true
	_run.call_deferred()


# the old look-up, kept here as the reference
func _walk(w, at: Vector2) -> Array:
	var out: Array = []
	for i in range(w.order.size() - 1, -1, -1):
		var p = w.pieces[w.order[i]]
		if p.gone or (p.door and p.door_open):
			continue
		if w.piece_contains(p, at):
			out.append(p)
	out.sort_custom(func(a, b): return (a.body != null) and (b.body == null))
	return out


func _ids(a: Array) -> Array:
	var s := a.map(func(p): return p.id)
	s.sort()
	return s


func _top(a: Array):
	return a[0].id if not a.is_empty() else -1


func _compare(g, label: String, n: int) -> void:
	var w = g.world
	var r := Rect2()
	for id in w.order:
		var p = w.pieces[id]
		if p.gone:
			continue
		var b := Geom.bbox(w.world_poly(p))
		r = b if r.size == Vector2.ZERO else r.merge(b)
	r = r.grow(2.0 * Geom.M)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var bad := 0
	var top_bad := 0
	var hits := 0
	var t_grid := 0
	var t_walk := 0
	for i in n:
		var at := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var t0 := Time.get_ticks_usec()
		var got: Array = w.pieces_at(at)
		var t1 := Time.get_ticks_usec()
		var want: Array = _walk(w, at)
		var t2 := Time.get_ticks_usec()
		t_grid += t1 - t0
		t_walk += t2 - t1
		if not want.is_empty():
			hits += 1
		if _ids(got) != _ids(want):
			bad += 1
		# the top attached piece (and the top loose one) must be the same as before
		var ga := got.filter(func(p): return p.body == null)
		var wa := want.filter(func(p): return p.body == null)
		if _top(ga) != _top(wa):
			top_bad += 1
		var one = w.piece_at(at)
		var ref = null
		for j in range(w.order.size() - 1, -1, -1):
			var p = w.pieces[w.order[j]]
			if p.gone or (p.door and p.door_open):
				continue
			if w.piece_contains(p, at):
				ref = p
				break
		if one != ref:
			top_bad += 1
	check(bad == 0 and top_bad == 0, "%s: %d points (%d on a piece) give the same pieces (%d differ) and the same top piece (%d differ); %.1f µs a look-up against %.1f" % [label, n, hits, bad, top_bad, t_grid / float(n), t_walk / float(n)])


func _ship(id: String):
	Game.contract = {}
	Game.start_ship = id
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	for i in 30:
		await process_frame
	return g


func _run() -> void:
	for id in ["ark01", "sa200", "nr95"]:
		var g = await _ship(id)
		var w = g.world
		_compare(g, id + " at rest", 1500)
		# cuts straight across a few attached pieces: each leaves the old piece smaller and new ones
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var cut := 0
		for k in 40:
			var p = w.pieces[w.order[rng.randi() % w.order.size()]]
			if p.gone or p.body != null or p.cls == "equip" or p.poly.size() < 3:
				continue
			var b := Geom.bbox(p.poly)
			var y := b.position.y + b.size.y * 0.5
			g.cut_kerf(p, PackedVector2Array([Vector2(b.position.x - 20, y), Vector2(b.end.x + 20, y)]))
			cut += 1
			if cut >= 8:
				break
		for i in 90:
			await process_frame
		_compare(g, id + " after %d cuts (%d loose bodies)" % [cut, w.bodies.size()], 1500)
		# a bent part
		for pid in w.order:
			var p = w.pieces[pid]
			if not p.gone and p.body == null and p.kind in ["beam", "strut", "rib", "plate"]:
				w.displace(p, Transform2D(0.0, Vector2(1.5 * Geom.M, 0.7 * Geom.M)))
				break
		_compare(g, id + " after a displaced part", 800)
		if id == "nr95":
			SaveGame.save(g)
			g.queue_free()
			await process_frame
			SaveGame.load_requested = true
			var g2 = await _ship(id)
			_compare(g2, id + " read back from a save", 800)
			g2.queue_free()
			SaveGame.clear()
		else:
			g.queue_free()
		await process_frame
	# a berth full of loose plates, drifting and knocking into each other
	var gt = await _ship("tug")
	var cc: Vector2 = Dock.BAY * Geom.M + Vector2(26.0, 2.0) * Geom.M
	for i in 150:
		var at := cc + Vector2((i % 25) * 0.85 * Geom.M - 10.6 * Geom.M, (i / 25) * 1.0 * Geom.M - 5.0 * Geom.M)
		var h := Vector2(14, 10)
		gt.world.add_piece("plate", PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)]), {"mass": 0.2})
	gt.world.dirty_links = true
	for i in 120:
		await process_frame
	_compare(gt, "tug with %d loose bodies" % gt.world.bodies.size(), 1500)
	gt.queue_free()
	await process_frame
	print("PICK GRID %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
