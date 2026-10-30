extends SceneTree
# 87-3: the grapple's range mode. Not fitted, X does nothing. Fitted, X switches modes; the field
# takes the loose pieces round the pointer, nearest first, up to its count: steel, aluminium,
# titanium, ceramic, composite alike (user: every material); never a piece still fixed to the
# ship; a precision unit or a hazard only with the guard off. Caught, each piece stays its own
# body (no merging, no copies, mass kept) and the group keeps its layout as it is hauled. Over its
# rating it overloads (red, the pull thinner); it never takes more than half again. Hauled to the
# scrap mouth each piece is swallowed and paid once. A save while holding loads with nothing
# held and nothing doubled. Own test saves only.
#   tools/run_test.sh tests/multi_grab_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var g: Node
var fails := 0
var checks := 0
var report: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_multigrab_career.json"
	SaveGame.path = "user://zp_test_multigrab_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game(kit: Dictionary) -> Node:
	Game.contract = {}
	Game.start_ship = "tug"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	await _frames(10)
	scene.tutorial = null
	scene.tools.tool = 3
	return scene


# a loose piece (no fixings: it floats free) of a material, at a point
func _loose(at: Vector2, mat: String, mass: float, opts: Dictionary = {}) -> Object:
	var h := Vector2(16, 12)
	var poly := PackedVector2Array([at - h, at + Vector2(h.x, -h.y), at + h, at + Vector2(-h.x, h.y)])
	var o := {"mat": mat, "mass": mass}
	o.merge(opts, true)
	return g.world.add_piece("plate", poly, o)


func _x(shift := false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_X
	ev.keycode = KEY_X
	ev.pressed = true
	ev.shift_pressed = shift
	g.tools.toggle_multi(shift)


func _hold_drone(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO


func _run() -> void:
	Txt.zh = true
	# not fitted: nothing
	g = await _game({})
	_x()
	check(not g.tools.multi.fitted() and not g.tools.multi.on, "no field grapple fitted: X does not switch")
	g.queue_free()
	await _frames(4)

	g = await _game({"skill_grapple_multi": 1})
	var mg = g.tools.multi
	check(mg.fitted() and mg.count() == 4 and is_equal_approx(mg.radius(), 2.5 * Geom.M), "volume I: 4 pieces, 2.5 m")
	_x()
	check(mg.on, "X: range mode")
	# a pile in clear berth space: five materials, a fixed plate, a precision unit, a hazard
	var c := Vector2(10.0 * Geom.M, -9.0 * Geom.M)
	var pile := {}
	var k := 0
	for mat in ["steel", "al", "ti", "ceramic", "composite"]:
		pile[mat] = _loose(c + Vector2(-60 + 30 * k, (k % 2) * 26 - 13), mat, 0.4)
		k += 1
	var fixed = _loose(c + Vector2(0, 50), "steel", 0.4)
	g.world.add_joint(fixed, null, "weld", c + Vector2(0, 50))
	var unit = _loose(c + Vector2(40, -40), "steel", 0.3, {"cls": "equip", "value": 30000.0, "fragile": 0.7, "dest": "equip"})
	var tank = _loose(c + Vector2(-40, -40), "steel", 0.3, {"hazard": "gas_tank"})
	g.world.redraw_all(true)
	g.world.dirty_links = true
	await _frames(6)
	var pieces0: int = g.world.pieces.size()
	var cands: Array = mg.candidates(c)
	var reasons := {}
	for cd in cands:
		for p in cd[0].pieces:
			reasons[p.id] = cd[1]
	check(not reasons.has(fixed.id), "a piece still fixed to the ship is not a candidate")
	check(reasons.get(unit.id, "") == "guarded" and reasons.get(tank.id, "") == "guarded", "the precision unit and the hazard are guarded")
	# guard off: the precision unit and the hazard are taken too
	_x(true)
	check(not mg.guard, "Shift+X: guard off")
	_hold_drone(c + Vector2(0, 3.0 * Geom.M))
	var cands2: Array = mg.candidates(unit.center_world())
	var unit_ok := false
	for cd in cands2:
		if cd[0].pieces.has(unit) and cd[1] == "":
			unit_ok = true
	if not unit_ok:
		print("  unit gone=", unit.gone, " body=", unit.body, " cands=", cands2.map(func(cd): return [cd[0].pieces.map(func(p): return p.id), cd[1]]), " unit id ", unit.id)
	check(unit_ok, "with the guard off the precision unit is a candidate")
	_x(true)
	check(mg.guard, "Shift+X again: guard back on")
	_hold_drone(c + Vector2(0, 3.0 * Geom.M))
	g.bot.aim = c
	g.cam_override = c + Vector2(0, 1.0 * Geom.M)
	g.zoom_override = 1.5
	for i in 70:
		_hold_drone(c + Vector2(0, 3.0 * Geom.M))
		await process_frame
	Cap.save(root, "res://tests/out/multigrab_select_zh.png")
	g.bot.lmb = true
	await _frames(2)
	_hold_drone(c + Vector2(0, 3.0 * Geom.M))
	var held_ids := {}
	for h in mg.held:
		for p in h.body.pieces:
			held_ids[p.id] = true
	check(mg.held.size() == 4, "caught: the nearest 4 (its count)")
	var mats := {}
	for mat in pile:
		if held_ids.has(pile[mat].id):
			mats[mat] = true
	check(mats.size() == 4 and not held_ids.has(unit.id) and not held_ids.has(tank.id) and not held_ids.has(fixed.id), "any material is taken (%s), the guarded and the fixed are not" % str(mats.keys()))
	Cap.save(root, "res://tests/out/multigrab_caught_zh.png")
	# each a body of its own, nothing merged or copied
	var bodies := {}
	for h in mg.held:
		bodies[h.body.get_instance_id()] = true
	check(bodies.size() == mg.held.size() and g.world.pieces.size() == pieces0, "each piece stays its own body; no piece merged or copied")
	var m0: float = mg.mass_held()
	# haul them 6 m to the right; the layout holds
	var d0 := _pair_dists(mg)
	var com0 := _coms(mg)
	for i in 180:
		var drone_at: Vector2 = c + Vector2(6.0 * Geom.M * i / 180.0, 3.0 * Geom.M)
		_hold_drone(drone_at)
		g.bot.aim = drone_at + Vector2(0, -3.0 * Geom.M)
		await process_frame
	await _frames(40)
	var com1 := _coms(mg)
	var moved := 0
	for i in com0.size():
		if i < com1.size() and com1[i].x - com0[i].x > 3.5 * Geom.M:
			moved += 1
	check(moved == mg.held.size(), "hauled 6 m: every piece came along (%d/%d)" % [moved, mg.held.size()])
	var d1 := _pair_dists(mg)
	var worst := 0.0
	for i in d0.size():
		if i < d1.size():
			worst = maxf(worst, absf(d1[i] - d0[i]) / maxf(d0[i], 1.0))
	check(worst < 0.4, "the group keeps its layout (pairwise spacing within %.0f%%)" % (worst * 100.0))
	check(is_equal_approx(mg.mass_held(), m0), "the mass held is what was caught (%.2f t)" % mg.mass_held())
	report.append("haul: %d pieces %.2f t, layout drift %.0f%%" % [mg.held.size(), m0, worst * 100.0])
	g.cam_override = _coms(mg)[0]
	await _frames(40)
	Cap.save(root, "res://tests/out/multigrab_haul_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	g.bot.lmb = false
	await _frames(3)
	check(not mg.holding(), "let go: all released")
	g.queue_free()
	await _frames(4)

	# overload: heavy pieces against volume I's rating (single grapple 3 t)
	g = await _game({"skill_grapple_multi": 1})
	mg = g.tools.multi
	_x()
	c = Vector2(10.0 * Geom.M, -9.0 * Geom.M)
	for i in 4:
		_loose(c + Vector2(-48 + 32 * i, 0), "steel", 1.3)
	g.world.redraw_all(true)
	g.world.dirty_links = true
	await _frames(6)
	_hold_drone(c + Vector2(0, 3.0 * Geom.M))
	g.bot.aim = c
	g.bot.lmb = true
	g.cam_override = c
	g.zoom_override = 1.5
	for i in 60:
		_hold_drone(c + Vector2(0, 3.0 * Geom.M))
		await process_frame
	report.append("overload: %d held, %.1f t of %.1f t rated, %.2f MW of %.2f" % [mg.held.size(), mg.mass_held(), mg.mass_cap(), mg.power_mw(), mg.rated_mw()])
	check(mg.mass_held() <= mg.mass_cap() * mg.DROP_OVER + 0.001, "it never takes more than half again its rating (%.1f t of %.1f)" % [mg.mass_held(), mg.mass_cap()])
	check(mg.overload > 0.0 and mg.power_mw() > mg.rated_mw(), "over its rating: overloaded, drawing more than rated")
	Cap.save(root, "res://tests/out/multigrab_overload_zh.png")
	g.bot.lmb = false
	await _frames(3)
	g.queue_free()
	await _frames(4)

	# to the scrap mouth: each piece swallowed and paid once
	g = await _game({"skill_grapple_multi": 3})
	mg = g.tools.multi
	_x()
	var mouth: Vector2 = Dock.zpos("metal")
	c = mouth + Vector2(-6.0 * Geom.M, -4.0 * Geom.M)
	var made: Array = []
	for i in 6:
		made.append(_loose(c + Vector2(-50 + 20 * i, (i % 2) * 20), "steel", 0.25))
	g.world.redraw_all(true)
	g.world.dirty_links = true
	await _frames(6)
	var want := 0.0
	for p in made:
		want += g.world.scrap_value(p)
	var m_before: float = g.income_metal
	_hold_drone(c + Vector2(0, 3.0 * Geom.M))
	g.bot.aim = c
	g.bot.lmb = true
	await _frames(3)
	var caught: int = mg.held.size()
	var t0 := Time.get_ticks_usec()
	for i in 360:
		var u := minf(1.0, i / 200.0)
		var drone_at: Vector2 = (c + Vector2(0, 3.0 * Geom.M)).lerp(mouth + Vector2(-2.0 * Geom.M, -2.0 * Geom.M), u)
		_hold_drone(drone_at)
		g.bot.aim = mouth
		await process_frame
	g.bot.lmb = false
	await _frames(300)
	var gone := 0
	for p in made:
		if p.gone:
			gone += 1
	var paid: float = g.income_metal - m_before
	report.append("mouth: %d caught, %d swallowed, paid $%.0f of $%.0f" % [caught, gone, paid, want])
	check(caught == 6 and gone >= 5, "the field hauls 6 pieces into the scrap mouth, each swallowed (%d)" % gone)
	check(paid <= want + 1.0 and paid >= want * (gone / 6.0) - 1.0, "each paid once, no more than they are worth ($%.0f of $%.0f)" % [paid, want])
	g.queue_free()
	await _frames(4)

	# a save while holding: nothing held, nothing doubled after loading
	SaveGame.clear()
	g = await _game({"skill_grapple_multi": 2})
	mg = g.tools.multi
	_x()
	c = Vector2(10.0 * Geom.M, -9.0 * Geom.M)
	for i in 5:
		_loose(c + Vector2(-50 + 25 * i, 0), "al", 0.3)
	g.world.redraw_all(true)
	g.world.dirty_links = true
	await _frames(6)
	_hold_drone(c + Vector2(0, 3.0 * Geom.M))
	g.bot.aim = c
	g.bot.lmb = true
	await _frames(10)
	var n_pieces: int = g.world.pieces.size()
	var n_held: int = mg.held.size()
	var su := Time.get_ticks_usec()
	mg.step(1.0 / 60.0, c)
	var step_us := Time.get_ticks_usec() - su
	report.append("field step with %d pieces: %d µs" % [n_held, step_us])
	check(step_us < 1500, "the field's step is cheap (%d µs for %d pieces)" % [step_us, n_held])
	SaveGame.save(g)
	g.queue_free()
	await _frames(3)
	SaveGame.load_requested = true
	g = await _game({"skill_grapple_multi": 2})
	await _frames(6)
	check(g.world.pieces.size() == n_pieces and not g.tools.multi.holding(), "a save while holding loads with nothing held and nothing doubled (%d pieces)" % g.world.pieces.size())
	g.queue_free()
	await _frames(4)
	SaveGame.clear()
	print("--- 87-3 report")
	for r in report:
		print(r)
	print("MULTIGRAB %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _coms(mg) -> Array:
	var out: Array = []
	for h in mg.held:
		out.append(h.body.global_transform * h.body.center_of_mass)
	return out


func _pair_dists(mg) -> Array:
	var cs := _coms(mg)
	var out: Array = []
	for i in cs.size():
		for j in range(i + 1, cs.size()):
			out.append(cs[i].distance_to(cs[j]))
	return out
