extends "res://tests/guide_check.gd"
# Held by a machine = no collision (user 2026-11-10: "抓取的东西没有碰撞……负的无人机、那些蓝色无人机，还有
# 爪钩，它们抓取的那一瞬间就直接没有碰撞了。不要主角"). Every machine that picks a body up goes through
# FreeBody.hold_begin / hold_end: the crane's hook, the hauler's claw (the blue hauling drones), the rail
# arm, the works crew's drones. For each:
#   - held, it is on CARRY_LAYER with an empty mask, all the way;
#   - a loose piece and the drone put right on top of the held load feel no push;
#   - carried out of a closed box of hull walls (crane, hauler): out, never stuck;
#   - let go overlapping something, it stays untouchable and is not shot off, and touches again once
#     it is clear.
# The player's own drone keeps its grapple's collision ("主角肯定是要碰撞才好玩"):
#   - single and range grapple: held, the load still collides (mask MASK); hauled at a hull wall it
#     is stopped by it;
#   - the quantum tunnelling upgrade (量子隧穿效应): N does nothing until it is fitted; fitted and on,
#     the load passes the wall (TUNNEL_MASK) with its effect (entry and exit halos, ripples on the
#     wall faces; three key frames saved to tests/out/tunnel_*.png with -- shots); let go or switched
#     off inside the wall, it stays untouchable until clear and is never shot out.
# Drone and range grapple by real keys (3, X, N, the left button; only the pointer is placed).
# Own test saves only.
#   tools/run_test.sh tests/hold_nocollide_check.gd --fixed-fps 60 [-- shots]

const SLOW := 70.0     # px/s: let go overlapping, nothing moves faster than this (calm eases at 60)
const STILL := 4.0     # px/s: a piece or the drone on top of a held load


func _initialize() -> void:
	Career.path = "user://zp_test_holdnc_career.json"
	SaveGame.path = "user://zp_test_holdnc_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rect(at: Vector2, size: Vector2, key: String, mass: float, cls: String = "metal"):
	var a := at - size * 0.5
	var b := at + size * 0.5
	var p = g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "tag": key, "cls": cls, "barrier": false, "mass": mass, "value": 500.0})
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


func _box(c_m: Vector2, half: Vector2, tag: String) -> void:
	var c := c_m * Geom.M
	var t := 0.3
	for r in [Rect2(-half.x, -half.y, half.x * 2.0, t), Rect2(-half.x, half.y - t, half.x * 2.0, t), Rect2(-half.x, -half.y, t, half.y * 2.0), Rect2(half.x - t, -half.y, t, half.y * 2.0)]:
		var w = g.world.add_piece("hull", PackedVector2Array([c + r.position * Geom.M, c + Vector2(r.end.x, r.position.y) * Geom.M, c + r.end * Geom.M, c + Vector2(r.position.x, r.end.y) * Geom.M]), {"key": tag, "tag": tag, "cls": "metal", "barrier": true, "mass": 1.0, "value": 1.0})
		g.world.rebuild_cols(w)
	g.nav_grid().dirty = true
	g.nav_grid()._built_frame = -100000


func _key(k: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _tap(k: int) -> void:
	_key(k, true)
	await _frames(2)
	_key(k, false)
	await _frames(2)


func _mouse(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(ev)


func _com(b) -> Vector2:
	return b.global_transform * b.center_of_mass


func _held_ok(b) -> bool:
	return is_instance_valid(b) and b.collision_layer == FreeBody.CARRY_LAYER and b.collision_mask == 0


func _game(kit: Dictionary) -> void:
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0


func _place_drone(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


# a loose piece (and, if asked, the drone) put right on the held load for 0.5 s: [piece |v| max, drone |v| max]
func _on_top(held, name: String, with_drone: bool) -> void:
	var at: Vector2 = _com(held)
	var q = _rect(at, Vector2(0.5, 0.5) * Geom.M, name + "-BY", 0.2)
	var by = q.body
	if with_drone:
		_place_drone(at + Vector2(0.1, 0.0) * Geom.M)
	var vb := 0.0
	var vd := 0.0
	var touched := false
	for i in 30:
		await physics_frame
		if is_instance_valid(by):
			vb = maxf(vb, by.linear_velocity.length())
			touched = touched or held in by.get_colliding_bodies()
		if with_drone:
			vd = maxf(vd, g.drone.linear_velocity.length())
			touched = touched or held in g.drone.get_colliding_bodies()
	print("  %s: on top of the held load  piece %.1f px/s  drone %.1f px/s  touched %s" % [name, vb, vd, touched])
	check(vb < STILL and vd < STILL and not touched, "%s: a piece%s on top of the held load feel no push (%.1f / %.1f px/s)" % [name, " and the drone" if with_drone else "", vb, vd])
	if is_instance_valid(by):
		by.global_position += Vector2(0.0, 40.0) * Geom.M
		by.queue_free()
	await physics_frame


# let go overlapping a loose piece: nothing faster than it was already going (or SLOW), it stays untouchable while overlapping, then touches
func _let_go_over(held, name: String, release: Callable) -> void:
	var q = _rect(_com(held), Vector2(0.6, 0.6) * Geom.M, name + "-UNDER", 0.3)
	var by = q.body
	await physics_frame
	var v0: float = held.linear_velocity.length()
	print("  %s: before let-go  load %.1f px/s  overlap %s" % [name, v0, str(g.world.overlap_dir(held.pieces))])
	await release.call()
	var vmax := 0.0
	var ghosted := true
	for i in 30:
		await physics_frame
		if not is_instance_valid(held):
			break
		vmax = maxf(vmax, maxf(held.linear_velocity.length(), by.linear_velocity.length()))
		# (a load let go on the move may slide clear of it within these 0.5 s: then it may touch again)
		if g.world.overlap_dir(held.pieces).is_empty():
			break
		ghosted = ghosted and held.collision_layer == FreeBody.CARRY_LAYER and held.collision_mask == 0
	check(is_instance_valid(held) and ghosted, "%s: let go overlapping a piece, it stays untouchable while they overlap" % name)
	# the piece underneath taken away: clear, it touches again
	by.global_position += Vector2(0.0, 40.0) * Geom.M
	by.queue_free()
	# (a load let go on the move may drift over other loose pieces first: up to 3 s to come clear)
	for i in 180:
		await physics_frame
		if is_instance_valid(held):
			vmax = maxf(vmax, held.linear_velocity.length())
			if i >= 30 and held.collision_layer == 1:
				break
	print("  %s: let go overlapping  max %.1f px/s  layer %d mask %d  freeze %s clearing %.2f carried %s arm %s overlap %s" % [name, vmax, held.collision_layer if is_instance_valid(held) else -1, held.collision_mask if is_instance_valid(held) else -1, held.freeze, held.clearing, held.held(), held.get_meta("arm", false), str(g.world.overlap_dir(held.pieces))])
	check(vmax <= maxf(SLOW, v0 + 5.0), "%s: never shot off (max %.1f px/s after, %.1f before)" % [name, vmax, v0])
	check(is_instance_valid(held) and held.collision_layer == 1 and held.collision_mask == FreeBody.MASK, "%s: clear, it collides again" % name)


func _carrier(name: String, machine, at_m: Vector2, mass: float, boxed: bool, cls: String = "equip") -> void:
	var M := Geom.M
	if boxed:
		_box(at_m, Vector2(1.8, 1.4), name + "-BOX")
	var p = _rect(at_m * M, Vector2(1.0, 0.7) * M, name + "-LOAD", mass, cls)
	var b = p.body
	await _frames(5)
	if machine is RecoveryArm:
		machine.queue.append(b)
	else:
		print("  %s: marked → %s" % [name, machine.toggle(b)])
	var carrying: bool = await _until(func(): return machine.body == b and machine.state == "carry", 3000)
	check(carrying, "%s: picked the load up" % name)
	if not carrying:
		print("  %s: state %s wait '%s'" % [name, machine.state, str(machine.get("wait_reason"))])
		return
	await _frames(2)
	check(_held_ok(b), "%s: held, on the carry layer with an empty mask (layer %d mask %d)" % [name, b.collision_layer, b.collision_mask])
	if not boxed:
		await _on_top(b, name, true)
		_place_drone(Vector2(-8, -14) * M)
	if boxed:
		var all_held := true
		var gone := false
		for i in 4000:
			await physics_frame
			if p.gone:
				gone = true
				break
			if machine.body == b and machine.state == "carry":
				all_held = all_held and _held_ok(b)
		check(gone and all_held, "%s: out of the closed box into a mouth, held without collision all the way" % name)
	else:
		await _let_go_over(b, name, func(): machine.halt())


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	# ---------------- crane, hauler, arm
	await _game({"crane": 1, "hauler": 1, "arm": 1})
	_place_drone(Vector2(-8, -14) * M)
	if g.arm == null:
		g.arm = RecoveryArm.new()
		g.arm.game = g
		g.add_child(g.arm)
	check(g.crane != null and g.hauler != null and g.arm != null, "a crane, a hauler and the rail arm")
	var ex: float = Dock.zpos("equip").x / M
	await _carrier("CRANE", g.crane, Vector2(ex - 9.0, -3.0), 4.0, true)
	await _carrier("HAULER", g.hauler, Vector2(ex - 16.0, -3.0), 1.0, true)
	await _carrier("CRANE-DROP", g.crane, Vector2(ex - 4.0, -3.0), 4.0, false)
	await _carrier("HAULER-DROP", g.hauler, Vector2(ex - 12.0, -8.0), 1.0, false)
	await _carrier("ARM-DROP", g.arm, Vector2(ex - 6.0, -8.0), 0.5, false, "metal")
	g.queue_free()
	await _frames(4)

	# ---------------- the works crew's drone (辅助无人机)
	await _game({})
	_place_drone(Vector2(-8, -14) * M)
	var cd = preload("res://scripts/crew_drone.gd").new()
	cd.game = g
	g.add_child(cd)
	var cp = _rect(Vector2(40.0, -6.0) * M, Vector2(0.8, 0.6) * M, "CREW-LOAD", 0.3)
	var cb = cp.body
	cd.global_position = _com(cb) - Vector2(0, 30)
	cd.hook(cb)
	await _frames(2)
	check(_held_ok(cb), "CREW DRONE: on its hook, the load is on the carry layer with an empty mask")
	await _on_top(cb, "CREW DRONE", true)
	_place_drone(Vector2(-8, -14) * M)
	await _let_go_over(cb, "CREW DRONE", func():
		cd.drop()
		await physics_frame)
	cd.queue_free()
	g.queue_free()
	await _frames(4)

	# ---------------- the player's grapple: collision kept
	await _game({"skill_grapple_multi": 1})
	await _tap(KEY_3)
	check(g.tools.tool == 3, "key 3: the grapple")
	var c := Vector2(24.0, -6.0)
	_box(c, Vector2(2.4, 1.4), "GBOX")
	var a = _rect(c * M, Vector2(1.6, 0.8) * M, "BOXED", 1.0)
	var ab = a.body
	_place_drone((c + Vector2(4.2, 0.0)) * M)
	await _frames(5)
	g.bot.aim = _com(ab)
	await _frames(2)
	_mouse(true)
	await _frames(3)
	check(g.tools.held_body == ab and ab.collision_layer == 1 and ab.collision_mask == FreeBody.MASK, "GRAPPLE: the player's load keeps its collision (layer %d mask %d)" % [ab.collision_layer, ab.collision_mask])
	var x0: float = _com(ab).x
	for i in 150:
		g.bot.aim = Vector2(c.x + 6.0, c.y) * M
		await physics_frame
	var moved: float = (_com(ab).x - x0) / M
	print("  GRAPPLE: hauled at the box wall  moved %.2f m  mask %d" % [moved, ab.collision_mask])
	check(moved < 2.0, "GRAPPLE: hauled at a hull wall, the wall stops it (%.2f m, wall at 2.0 m)" % moved)
	await _tap(KEY_N)
	check(not g.tools.tunnel_on() and ab.collision_mask == FreeBody.MASK, "key N, nothing fitted: no tunnelling")
	_mouse(false)
	await _frames(4)
	# range mode: the field's pieces keep theirs too
	var mg = g.tools.multi
	await _tap(KEY_X)
	var base := Vector2(44, -6) * M
	_place_drone(base)
	var bodies := []
	for i in 3:
		bodies.append(_rect(base + Vector2(2.6, (i - 1) * 1.0) * M, Vector2(0.8, 0.7) * M, "FIELD-%d" % i, 0.4).body)
	await _frames(4)
	g.bot.aim = base + Vector2(2.6, 0.0) * M
	await _frames(2)
	_mouse(true)
	await _frames(4)
	check(mg.on and mg.holding() and mg.held.size() == 3 and bodies.all(func(x): return x.collision_layer == 1 and x.collision_mask == FreeBody.MASK), "RANGE: three pieces held by key X, each keeps its collision")
	_mouse(false)
	await _frames(4)
	g.queue_free()
	await _frames(4)

	# ---------------- the quantum tunnelling upgrade
	var shots := "shots" in OS.get_cmdline_user_args()
	await _game({"skill_grapple_multi": 1, "tunnel": 1})
	await _tap(KEY_3)
	check(g.tools.tunnel_fitted() and g.tools.tunnel_on(), "TUNNEL: fitted, on by itself (user 2026-11-11: 升级默认开启)")
	await _tap(KEY_N)
	check(not g.tools.tunnel_on(), "TUNNEL: key N switches it off")
	await _tap(KEY_N)
	check(g.tools.tunnel_on(), "TUNNEL: and on again")
	_box(c, Vector2(2.4, 1.4), "TBOX")
	var ta = _rect(c * M, Vector2(1.6, 0.8) * M, "TUNNELLED", 1.0)
	var tb = ta.body
	_place_drone((c + Vector2(4.2, 0.0)) * M)
	await _frames(5)
	g.bot.aim = _com(tb)
	await _frames(2)
	_mouse(true)
	await _frames(3)
	check(g.tools.held_body == tb and tb.collision_layer == FreeBody.TUNNEL_LAYER and tb.collision_mask == FreeBody.TUNNEL_MASK, "TUNNEL: held, it passes hull, berth and pieces (mask %d), still meets the drone" % tb.collision_mask)
	if shots:
		g.cam_override = (c + Vector2(2.0, 0.0)) * M
		g.zoom_override = 2.2
		g.zoom_now = 2.2
		g.zoom_target = 2.2
	var fx = g.tools.tunnel_fx
	var e0: int = fx.stats.entries
	var tx0: float = _com(tb).x
	var shot_n := 0
	var ripples := 0
	var fx_in := 0
	for i in 240:
		g.bot.aim = Vector2(c.x + 7.0, c.y) * M
		await physics_frame
		ripples = maxi(ripples, int(fx.stats.rings))
		if fx.stats.inside > 0: fx_in += 1
		if shots and fx.stats.inside > 0 and shot_n < 3 and fx_in % 9 == 0:
			await process_frame
			Cap.save(root, "res://tests/out/tunnel_%d.png" % shot_n)
			shot_n += 1
	var tmoved: float = (_com(tb).x - tx0) / M
	print("  TUNNEL: hauled through the box wall  moved %.2f m  entries %d exits %d halos %d ripples (most at once) %d  shots %d" % [tmoved, fx.stats.entries - e0, fx.stats.exits, fx.stats.halos, ripples, shot_n])
	check(tmoved > 3.0, "TUNNEL: hauled out through the hull wall (%.2f m)" % tmoved)
	check(fx.stats.entries > e0 and fx.stats.exits >= 1 and fx.stats.halos >= 2 and ripples > 0, "TUNNEL: the effect played: halo in, ripples on the wall faces, halo out")
	_mouse(false)
	await _frames(4)
	if shots:
		g.cam_override = null
		g.zoom_override = -1.0
	# let go inside a hull wall, tunnelling: untouchable till clear, never shot out
	var w := Vector2(34.0, -6.0)
	_box(w, Vector2(1.0, 1.0), "WALL")
	var sp = _rect((w + Vector2(1.0, 0.0)) * M, Vector2(0.8, 0.8) * M, "IN-WALL", 0.5)
	var sb = sp.body
	_place_drone((w + Vector2(3.6, 0.0)) * M)
	await _frames(4)
	g.bot.aim = _com(sb)
	await _frames(2)
	_mouse(true)
	for i in 20:
		g.bot.aim = _com(sb)
		await physics_frame
	print("  IN-WALL: before let-go held %s tethered %s tunneling %s mask %d overlap %s" % [g.tools.held_body == sb, sb.tethered, sb.tunneling, sb.collision_mask, str(g.world.overlap_dir(sb.pieces))])
	_mouse(false)
	await _frames(2)
	print("  IN-WALL: after let-go held %s tethered %s tunneling %s layer %d mask %d clearing %.2f" % [g.tools.held_body == sb, sb.tethered, sb.tunneling, sb.collision_layer, sb.collision_mask, sb.clearing])
	var vmax := 0.0
	var ghost_while := false
	var back := false
	for i in 400:
		await physics_frame
		vmax = maxf(vmax, sb.linear_velocity.length())
		if i < 10: ghost_while = sb.collision_layer == FreeBody.CARRY_LAYER and sb.collision_mask == 0
		if sb.collision_layer == 1:
			back = true
			break
	print("  IN-WALL: let go in a hull wall  max %.1f px/s  back %s  mask %d" % [vmax, back, sb.collision_mask])
	check(ghost_while and vmax < SLOW, "TUNNEL: let go inside a hull wall, untouchable, eases out (max %.1f px/s)" % vmax)
	check(back and sb.collision_mask == FreeBody.MASK and g.world.overlap_dir(sb.pieces).is_empty(), "TUNNEL: clear of the wall, it collides again")
	# switched off with the load inside a wall: the same
	var w2 := Vector2(52.0, -6.0)
	_box(w2, Vector2(1.0, 1.0), "WALL2")
	var s2 = _rect((w2 + Vector2(1.0, 0.0)) * M, Vector2(0.8, 0.8) * M, "SWITCHED", 0.5)
	var b2 = s2.body
	_place_drone((w2 + Vector2(3.6, 0.0)) * M)
	await _frames(4)
	g.bot.aim = _com(b2)
	await _frames(2)
	_mouse(true)
	for i in 20:
		g.bot.aim = _com(b2)
		await physics_frame
	await _tap(KEY_N)
	var still_ghost: bool = b2.collision_layer == FreeBody.CARRY_LAYER and b2.collision_mask == 0
	check(not g.tools.tunnel_on() and still_ghost, "TUNNEL: N off with the load inside a wall: it stays untouchable until clear")
	_mouse(false)
	var v2 := 0.0
	var back2 := false
	for i in 400:
		await physics_frame
		v2 = maxf(v2, b2.linear_velocity.length())
		if b2.collision_layer == 1:
			back2 = true
			break
	check(back2 and v2 < SLOW, "TUNNEL: and comes out gently, then collides again (max %.1f px/s)" % v2)
	# range mode tunnels too
	await _tap(KEY_N)
	await _tap(KEY_X)
	var rbase := Vector2(64, -6) * M
	_place_drone(rbase)
	var rb := []
	for i in 3:
		rb.append(_rect(rbase + Vector2(2.6, (i - 1) * 1.0) * M, Vector2(0.8, 0.7) * M, "TFIELD-%d" % i, 0.4).body)
	await _frames(4)
	g.bot.aim = rbase + Vector2(2.6, 0.0) * M
	await _frames(2)
	_mouse(true)
	await _frames(4)
	check(g.tools.tunnel_on() and g.tools.multi.holding() and rb.all(func(x): return x.collision_mask == FreeBody.TUNNEL_MASK), "TUNNEL: the range mode's pieces tunnel too")
	_mouse(false)
	await _frames(4)
	print("hold_nocollide_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
