extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 range grapple, a guarded piece (multi_grab.guarded: hazard, ≥$15,000, fragile, the
# contract's must-keep): its mark on the field — before, a big cross over its whole outline; now a
# small shield at its box's corner, fixed on screen, and the reason by the pointer over it. IC-120,
# its contents let go, the field over a guarded one (key X; the pointer placed). Saves
# tests/out/multi_guard_<tag>.png; checks the reason line.
#   tools/run_test.sh tests/multi_guard_shot.gd --fixed-fps 60 -- <tag>

func _initialize() -> void:
	Career.path = "user://zp_test_mguard_career.json"
	SaveGame.path = "user://zp_test_mguard_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 else "now"
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "ic120"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "move": Vector2.ZERO, "kit": {"skill_grapple_multi": 3}}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	g.auto_paused = true
	for n in g.world.rooms:
		g.world.rooms[n].revealed = true
	# the pump room's contents let go where they are
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or p.cls != "equip":
			continue
		for j in g.world.joints_of(p).duplicate():
			if j.alive:
				g.on_snap(j)
	await _frames(20)
	for b in g.world.bodies:
		if is_instance_valid(b):
			b.linear_velocity = Vector2.ZERO
			b.freeze = true
	var mg = g.tools.multi
	# the guarded body with the most loose neighbours within the field
	var best = null
	var bn := -1
	for b in g.world.bodies:
		if not is_instance_valid(b) or not mg.guarded(b):
			continue
		var c: Vector2 = _com(b)
		var nn := 0
		for o in g.world.bodies:
			if is_instance_valid(o) and _com(o).distance_to(c) < mg.radius():
				nn += 1
		if nn > bn:
			bn = nn
			best = b
	check(best != null, "a guarded loose body (%s)" % (best.pieces[0].tag if best != null else "-"))
	if best == null:
		quit(1)
		return
	await _tap(KEY_3)
	await _tap(KEY_X)
	var at: Vector2 = _com(best)
	_place_drone(at + Vector2(-4.0, -2.5) * Geom.M)
	g.bot.aim = at
	g.cam_override = at + Vector2(-1.0, 0.0) * Geom.M
	g.zoom_override = 1.6
	g.zoom_now = 1.6
	g.zoom_target = 1.6
	await _frames(40)
	var why: String = mg.guard_reason(best) if mg.has_method("guard_reason") else "-"
	print("GUARD %s %s %.2f t value %.0f fragile %.2f hazard '%s' → %s (%s)" % [tag, best.pieces[0].tag, best.total_mass(), best.pieces[0].value, best.pieces[0].fragile, best.pieces[0].hazard, why, g.txt(why) if why != "-" else ""])
	Cap.save(root, "res://tests/out/multi_guard_%s.png" % tag)
	if why != "-":
		check(why.begins_with("as_mg_guard_") and g.txt(why).contains("按 X"), "the reason by the pointer: %s" % g.txt(why))
	print("multi_guard_shot: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
