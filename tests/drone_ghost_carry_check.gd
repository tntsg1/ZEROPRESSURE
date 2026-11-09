extends "res://tests/guide_check.gd"
# The drone's grapple carries through structure (user 2026-11-09: "还有无人机经常出现穿模的状况，我不是让它
# 取消碰撞了吗"), as the crane's hook does since 2026-11-08: a loose piece on the magnetic line collides
# with nothing (mask 0) until it is let go; let go inside the ship it eases out (FreeBody.start_ghost,
# for as long as its size needs), never flung, never left wedged. The drone itself still collides.
#   A  a 1 t piece shut in a box of hull walls is hauled straight out through the wall
#   B  a piece let go half sunk in a thick hull block (2 m to clear) eases out, slowly, and touches again
#   C  a carried piece still goes into the equipment mouth
#   D  a carried body that splits: the part left off the line gets its collision back
# Own test saves only.
#   tools/run_test.sh tests/drone_ghost_carry_check.gd --fixed-fps 60 [-- shots]


func _initialize() -> void:
	Career.path = "user://zp_test_droneghost_career.json"
	SaveGame.path = "user://zp_test_droneghost_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rect(at: Vector2, size: Vector2, key: String, mass: float, cls: String = "equip"):
	var a := at - size * 0.5
	var b := at + size * 0.5
	return g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "tag": key, "cls": cls, "barrier": false, "mass": mass, "value": 3000.0})


func _hull(r: Rect2, tag: String) -> void:
	var M := Geom.M
	var w = g.world.add_piece("hull", PackedVector2Array([r.position * M, Vector2(r.end.x, r.position.y) * M, r.end * M, Vector2(r.position.x, r.end.y) * M]), {"key": tag, "tag": tag, "cls": "metal", "barrier": true, "mass": 1.0, "value": 1.0})
	g.world.rebuild_cols(w)


func _box(c: Vector2, half: Vector2, tag: String) -> void:
	var t := 0.3
	for r in [Rect2(-half.x, -half.y, half.x * 2.0, t), Rect2(-half.x, half.y - t, half.x * 2.0, t), Rect2(-half.x, -half.y, t, half.y * 2.0), Rect2(half.x - t, -half.y, t, half.y * 2.0)]:
		_hull(Rect2(c + r.position, r.size), tag)


func _com(b) -> Vector2:
	return b.global_transform * b.center_of_mass


func _hold(p, at: Vector2) -> void:
	g.tools.held_piece = p
	g.tools.held_body = p.body
	g.tools.held_local = g.world.frame(p).affine_inverse() * at
	g.bot.lmb = true


func _drop() -> void:
	g.bot.lmb = false
	g.bot.move = Vector2.ZERO
	await _frames(2)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var shots := "shots" in OS.get_cmdline_user_args()
	var tag := "after" if "after" in OS.get_cmdline_user_args() else "before"
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {}}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	g.tools.set_tool(3, true)
	var M := Geom.M
	print("grab_max %.2f t" % g.grab_max())
	# ---------------- A: out of a closed box through its wall
	var c := Vector2(24.0, -6.0)
	_box(c, Vector2(2.4, 1.4), "GBOX")
	var a = _rect(c * M, Vector2(1.6, 0.8) * M, "BOXED-1T", 1.0, "metal")
	g.world.make_body([a], null)
	a.body.linear_velocity = Vector2.ZERO
	var ab = a.body
	g.drone.global_position = (c + Vector2(4.2, 0.0)) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	if shots:
		g.cam_override = (c + Vector2(3.0, 0.0)) * M
	await _frames(10)
	_hold(a, _com(ab))
	var ghosted := false
	var x0: float = _com(ab).x
	var drone_in_wall := false
	for i in 300:
		g.bot.move = Vector2(1, 0) if i < 200 else Vector2.ZERO
		g.bot.aim = g.drone.global_position + Vector2(-2.0 * M, 0.0)
		await _frames(1)
		if ab.collision_mask == 0: ghosted = true
		if shots and i == 70:
			Cap.save(root, "res://tests/out/drone_ghost_%s_box.png" % tag)
		if (g.drone.global_position / M).x > c.x - 2.4 and (g.drone.global_position / M).x < c.x + 2.4 and absf(g.drone.global_position.y / M - c.y) < 1.4:
			drone_in_wall = true
	var out_x: float = (_com(ab).x - x0) / M
	print("  A: load moved %.2f m (box half-width 2.4 m), mask while held %d" % [out_x, ab.collision_mask])
	check(ghosted, "A: on the line the load collides with nothing (mask 0)")
	check(out_x > 3.2, "A: hauled straight out through the box wall (%.2f m)" % out_x)
	check(not drone_in_wall, "A: the drone itself still keeps out of the box")
	await _drop()
	check(ab.collision_mask == FreeBody.MASK, "A: let go in the open, its collision is back (%d)" % ab.collision_mask)
	g.cam_override = null
	# ---------------- B: let go half sunk in a thick hull block
	var bc := Vector2(30.0, -10.0)
	_hull(Rect2(bc - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), "BLOCK")
	var bp = _rect((bc + Vector2(-1.5, 0.0)) * M, Vector2(3.0, 1.2) * M, "SUNK-1T", 1.0, "metal")
	g.world.make_body([bp], null)
	var bb = bp.body
	await _frames(1)
	bb.linear_velocity = Vector2.ZERO
	g.drone.global_position = (bc + Vector2(-5.0, 0.0)) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	_hold(bp, _com(bb))
	g.bot.hold = true
	g.bot.aim = _com(bb)
	await _frames(20)
	g.bot.hold = false
	var hits0: int = FreeBody.guard_hits
	await _drop()
	var vmax := 0.0
	var clear_t := -1.0
	for i in 600:
		await _frames(1)
		if not is_instance_valid(bb): break
		vmax = maxf(vmax, bb.linear_velocity.length())
		if clear_t < 0.0 and g.world.overlap_dir(bb.pieces).is_empty():
			clear_t = i / 60.0
		if clear_t >= 0.0 and bb.collision_mask == FreeBody.MASK and i > clear_t * 60.0 + 30: break
	print("  B: clear after %.2f s, top speed %.0f px/s, mask %d, guard hits +%d" % [clear_t, vmax, bb.collision_mask, FreeBody.guard_hits - hits0])
	check(clear_t >= 0.0, "B: let go 2 m deep in the hull, it eased all the way out (%.2f s)" % clear_t)
	check(vmax < 120.0, "B: never flung out (top %.0f px/s)" % vmax)
	check(bb.collision_mask == FreeBody.MASK, "B: and collides again once clear")
	# ---------------- C: still goes into the equipment mouth
	var zp: Vector2 = Dock.zpos("equip")
	var face: Vector2 = Dock.ZONES["equip"].face
	var cp = _rect(zp + face * 2.2 * M, Vector2(0.8, 0.6) * M, "MOUTH-05", 0.5, "equip")
	g.world.make_body([cp], null)
	var cb = cp.body
	await _frames(1)
	cb.linear_velocity = Vector2.ZERO
	g.drone.global_position = zp + face * 5.0 * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	_hold(cp, _com(cb))
	var inc0: float = g.income_equip
	var taken := false
	for i in 600:
		g.bot.hold = true
		g.bot.aim = zp - face * 0.5 * M
		await _frames(1)
		if cp.gone or not is_instance_valid(cb) or cb.capture != null:
			taken = true
			break
	g.bot.hold = false
	await _drop()
	await _frames(120)
	check(taken, "C: a carried piece is still swallowed by the equipment mouth (income +$%d)" % int(g.income_equip - inc0))
	# ---------------- D: a carried body splits; the part off the line touches again
	var dc := Vector2(20.0, -12.0)
	var d1 = _rect((dc + Vector2(-0.5, 0.0)) * M, Vector2(1.0, 0.6) * M, "SPLIT-A", 0.6, "metal")
	var d2 = _rect((dc + Vector2(0.5, 0.0)) * M, Vector2(1.0, 0.6) * M, "SPLIT-B", 0.4, "metal")
	g.world.make_body([d1, d2], null)
	var db = d1.body
	await _frames(1)
	db.linear_velocity = Vector2.ZERO
	g.drone.global_position = (dc + Vector2(3.5, 0.0)) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	_hold(d2, _com(db))
	g.bot.hold = true
	g.bot.aim = _com(db)
	await _frames(10)
	var held_mask0: int = db.collision_mask
	# the held piece goes off as the lighter part (what world.regroup does when a body falls apart)
	var nb = g.world.make_body([d2], db)
	db.refresh()
	await _frames(10)
	print("  D: before split mask %d; held part mask %d, part left %d" % [held_mask0, nb.collision_mask, db.collision_mask])
	check(held_mask0 == 0 and g.tools.held_body == nb and nb.collision_mask == 0, "D: the grapple carries on with the split-off part, still through everything")
	check(db.collision_mask == FreeBody.MASK, "D: the part left behind collides again")
	g.bot.hold = false
	await _drop()
	check(nb.collision_mask == FreeBody.MASK or not g.world.overlap_dir(nb.pieces).is_empty(), "D: let go, the carried part touches again")
	# ---------------- E: too heavy for the grapple, nothing is carried: it stays solid
	var ec := Vector2(14.0, -12.0)
	var ep = _rect(ec * M, Vector2(1.6, 1.0) * M, "HEAVY", g.grab_max() + 2.0, "metal")
	g.world.make_body([ep], null)
	var eb = ep.body
	await _frames(1)
	eb.linear_velocity = Vector2.ZERO
	g.drone.global_position = (ec + Vector2(3.0, 0.0)) * M
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	_hold(ep, _com(eb))
	g.bot.hold = true
	g.bot.aim = _com(eb)
	await _frames(20)
	check(g.tools.overweight and eb.collision_mask == FreeBody.MASK, "E: an overweight piece on the line stays solid (mask %d)" % eb.collision_mask)
	g.bot.hold = false
	await _drop()
	print("DRONE GHOST CARRY: %d/%d" % [checks - fails, checks])
	quit(1 if fails > 0 else 0)
