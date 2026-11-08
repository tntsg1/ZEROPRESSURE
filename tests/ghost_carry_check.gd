extends "res://tests/guide_check.gd"
# Crane ghost (user 2026-11-08: "起重机、吊车这类机器干脆都改成可以穿模"): a load in the crane's hook or
# a hauler's claw passes through every structure on its way to the mouth — no route planning, no
# "is the way wide enough" check, never load_no_route / load_obstructed — and gets its own collision
# back when it is let go. Two loads boxed in by solid walls (a 5 t one for the crane, a 1 t one for
# the hauler) both reach a mouth with wait_reason empty the whole way.
#   tools/run_test.sh tests/ghost_carry_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_ghostcarry_career.json"
	SaveGame.path = "user://zp_test_ghostcarry_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rect(at: Vector2, size: Vector2, key: String, mass: float, cls: String = "equip"):
	var a := at - size * 0.5
	var b := at + size * 0.5
	return g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "cls": cls, "barrier": false, "mass": mass, "value": 3000.0})


# a closed box of attached hull walls around c (m): nothing gets out of it without passing a wall
func _box(c_m: Vector2, half: Vector2, tag: String) -> void:
	var c := c_m * Geom.M
	var t := 0.3
	for r in [Rect2(-half.x, -half.y, half.x * 2.0, t), Rect2(-half.x, half.y - t, half.x * 2.0, t), Rect2(-half.x, -half.y, t, half.y * 2.0), Rect2(half.x - t, -half.y, t, half.y * 2.0)]:
		var w = g.world.add_piece("hull", PackedVector2Array([c + r.position * Geom.M, c + Vector2(r.end.x, r.position.y) * Geom.M, c + r.end * Geom.M, c + Vector2(r.position.x, r.end.y) * Geom.M]), {"key": tag, "cls": "metal", "barrier": true, "mass": 1.0, "value": 1.0})
		g.world.rebuild_cols(w)
	g.nav_grid().dirty = true
	g.nav_grid()._built_frame = -100000


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"crane": 1, "hauler": 1}}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.global_position = Vector2(-8, -14) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	check(g.crane != null and g.hauler != null, "a crane and a hauler aboard")
	var ex: float = Dock.zpos("equip").x / Geom.M
	# ---- the crane: a 5 t piece shut in a wall box
	var big_c := Vector2(ex - 9.0, -3.0)
	_box(big_c, Vector2(2.2, 1.8), "GBOX")
	var big = _rect(big_c * Geom.M, Vector2(1.6, 1.0) * Geom.M, "BIG-5T", 5.0)
	g.world.make_body([big], null)
	big.body.linear_velocity = Vector2.ZERO
	var big_body = big.body
	var mask0: int = big_body.collision_mask
	await _frames(5)
	check(g.crane.toggle(big_body) == "crane_marked", "the boxed 5 t piece marked for the crane")
	var reasons := {}
	var ghosted := false
	var picked := false
	for i in 4000:
		await _frames(1)
		if g.crane.wait_reason != "": reasons[g.crane.wait_reason] = true
		if g.crane.body == big_body and g.crane.state == "carry":
			picked = true
			if is_instance_valid(big_body) and big_body.collision_mask == 0: ghosted = true
		if big.gone: break
	if not big.gone:
		print("  crane: state %s zone %s wait '%s' hook %s" % [g.crane.state, g.crane.zone, g.crane.wait_reason, str(g.crane.pos / Geom.M)])
	check(picked and ghosted, "in the hook the load collides with nothing (mask 0 while carried)")
	check(big.gone and g.income_equip > 0.0, "the crane took it out through the walls into a mouth ($%d)" % int(g.income_equip))
	check(reasons.is_empty(), "the crane's wait_reason stayed empty the whole way (%s)" % str(reasons.keys()))
	# ---- the hauler: a 1 t piece shut in a wall box (no grid route in or out)
	var small_c := Vector2(ex - 16.0, -3.0)
	_box(small_c, Vector2(1.6, 1.4), "HBOX")
	var small = _rect(small_c * Geom.M, Vector2(0.9, 0.7) * Geom.M, "SMALL-1T", 1.0)
	g.world.make_body([small], null)
	small.body.linear_velocity = Vector2.ZERO
	var small_body = small.body
	await _frames(5)
	var key: String = g.hauler.toggle(small_body)
	check(key == "hauler_marked", "the boxed 1 t piece marked for the hauler (%s)" % key)
	reasons = {}
	ghosted = false
	picked = false
	var income0: float = g.income_equip + g.income_metal if "income_metal" in g else g.income_equip
	for i in 4000:
		await _frames(1)
		if g.hauler.wait_reason != "": reasons[g.hauler.wait_reason] = true
		if g.hauler.body == small_body and g.hauler.state == "carry":
			picked = true
			if is_instance_valid(small_body) and small_body.collision_mask == 0: ghosted = true
		if small.gone: break
	if not small.gone:
		print("  hauler: state %s zone %s wait '%s' at %s" % [g.hauler.state, g.hauler.zone, g.hauler.wait_reason, str(g.hauler.pos / Geom.M)])
	check(picked and ghosted, "in the claw the load collides with nothing (mask 0 while carried)")
	check(small.gone, "the hauler took it out through the walls into a mouth")
	check(reasons.is_empty(), "the hauler's wait_reason stayed empty the whole way (%s)" % str(reasons.keys()))
	# ---- let go mid-way: its own collision comes back
	var free_p = _rect(Vector2(ex - 4.0, -3.0) * Geom.M, Vector2(1.6, 1.0) * Geom.M, "DROP-5T", 5.0)
	g.world.make_body([free_p], null)
	free_p.body.linear_velocity = Vector2.ZERO
	await _frames(5)
	g.crane.toggle(free_p.body)
	var carrying := await _until(func(): return g.crane.body == free_p.body and g.crane.state == "carry", 2000)
	await _frames(10)
	g.crane.halt()
	await _frames(3)
	check(carrying and is_instance_valid(free_p.body) and free_p.body.collision_mask != 0 and free_p.body.collision_layer == 1, "let go on the way, the load collides again (mask %d → %d)" % [mask0, free_p.body.collision_mask if is_instance_valid(free_p.body) else -1])
	print("GHOST CARRY CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
