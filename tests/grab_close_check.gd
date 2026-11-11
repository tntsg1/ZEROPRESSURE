extends "res://tests/guide_check.gd"
# Bug 2026-11-10 (user: "我拿东西如果拿离我太近的话，反而会把我推着走"): a load pulled in close on
# the grapple kept shoving the drone away. The player's load keeps its collision (user: "主角肯定是要
# 碰撞才好玩"); the line now stops where the load clears the drone (its size counted, not a fixed
# 1.4 m from the grab point), and at that gap it can no longer pull the load into the drone (that part
# of the pull is taken off: a stop that does no work). A real knock is one collision.
# Real keys: 3 (or X for the range mode) and the left button; only the pointer is placed.
#   A  light 0.5 m piece pulled right in: hover 5 s, the drone does not drift
#   B  heavy 2.2 m piece (near the grapple's rating) caught at its middle: the same
#   C  range mode, three wide pieces pulled in: the same
#   D  the pointer past the drone: the load swings across into it, knocks it once and settles; the
#      drone is never pushed along (before: 409 px/s and still going)
# Own test saves only.
#   tools/run_test.sh tests/grab_close_check.gd --fixed-fps 60

const V_MAX := 12.0     # px/s: the most the drone may move while hovering (a heavy load still settling)
const V_END := 3.0      # px/s: and at the end of the 5 s
const DRIFT_MAX := 20.0 # px over the 5 s hover


func _initialize() -> void:
	Career.path = "user://zp_test_grabclose_career.json"
	SaveGame.path = "user://zp_test_grabclose_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _rect(at: Vector2, size: Vector2, key: String, mass: float):
	var a := at - size * 0.5
	var b := at + size * 0.5
	var p = g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "tag": key, "cls": "metal", "barrier": false, "mass": mass, "value": 100.0})
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	return p


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


func _game(kit: Dictionary) -> void:
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "kit": kit}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	await _tap(KEY_3)


func _place(at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


# pull in with the pointer 0.3 m off the drone, let it settle 1.5 s, then hover 5 s: [max |v|, drift]
func _hover(touching: Callable) -> Array:
	var M := Geom.M
	for i in 90:
		g.bot.aim = g.drone.global_position + Vector2(0.3, 0.0) * M
		await physics_frame
	var x0: Vector2 = g.drone.global_position
	var vmax := 0.0
	var touched := false
	for i in 300:
		g.bot.aim = g.drone.global_position + Vector2(0.3, 0.0) * M
		await physics_frame
		vmax = maxf(vmax, g.drone.linear_velocity.length())
		touched = touched or touching.call()
	return [vmax, g.drone.global_position.distance_to(x0), touched, g.drone.linear_velocity.length()]


func _single(name: String, base: Vector2, size: Vector2, mass: float) -> void:
	var M := Geom.M
	_place(base)
	var p = _rect(base + Vector2(2.6, 0.0) * M, size * M, name, mass)
	await _frames(4)
	g.bot.aim = p.body.global_transform * p.body.center_of_mass
	await _frames(3)
	_mouse(true)
	await _frames(4)
	var b = p.body
	check(g.tools.held_body == b and b.total_mass() < g.grab_max(), "%s: caught with the left button (%.2f t of %.1f t)" % [name, b.total_mass(), g.grab_max()])
	var r: Array = await _hover(func(): return b in g.drone.get_colliding_bodies())
	var gd: float = g.tools.grab_point().distance_to(g.drone.global_position) / M
	print("  %s: hover 5 s  max |v| %.1f px/s  end |v| %.1f  drift %.1f px  line %.2f m  touched %s" % [name, r[0], r[3], r[1], gd, r[2]])
	check(r[0] < V_MAX and r[3] < V_END and r[1] < DRIFT_MAX, "%s: pulled in close, the drone hovers (max %.1f px/s, end %.1f, %.1f px in 5 s)" % [name, r[0], r[3], r[1]])
	check(not r[2], "%s: the drone never collides with its own load" % name)
	check(gd * M >= size.x * 0.5 * M + Drone.R, "%s: the load stops clear of the drone (line %.2f m)" % [name, gd])
	_mouse(false)
	await _frames(4)
	check(g.tools.held_body == null and b.collision_mask != 0 and not b.get_collision_exceptions().has(g.drone), "%s: let go, it touches again (the drone too)" % name)
	b.queue_free()
	await _frames(2)


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	await _game({})
	check(g.tools.tool == 3, "key 3: the grapple")
	await _single("LIGHT", Vector2(40, -6) * M, Vector2(0.5, 0.5), 0.1)
	await _single("HEAVY", Vector2(52, -6) * M, Vector2(2.2, 2.2), 2.6)

	# ---------------- D: the load swung across onto the drone (it keeps its collision): a knock, not a push
	var dbase := Vector2(46, -6) * M
	_place(dbase)
	var p = _rect(dbase + Vector2(2.6, 0.0) * M, Vector2(1.4, 1.4) * M, "SWING", 0.8)
	await _frames(4)
	g.bot.aim = p.body.global_transform * p.body.center_of_mass
	await _frames(3)
	_mouse(true)
	await _frames(4)
	var b = p.body
	check(g.tools.held_body == b and b.collision_mask == FreeBody.MASK, "D: caught, the player's load keeps its collision")
	var touched_at := -1
	var vmax := 0.0
	var v_after := 0.0
	for i in 300:
		g.bot.aim = g.drone.global_position + Vector2(-2.4, 0.0) * M
		await physics_frame
		vmax = maxf(vmax, g.drone.linear_velocity.length())
		if touched_at < 0 and b in g.drone.get_colliding_bodies():
			touched_at = i
		if touched_at >= 0 and i == touched_at + 90:
			v_after = g.drone.linear_velocity.length()
	var v_end: float = g.drone.linear_velocity.length()
	print("  D: swung across  contact at frame %d  drone max %.0f px/s, 1.5 s after %.1f, end %.1f  drift %.0f px" % [touched_at, vmax, v_after, v_end, g.drone.global_position.distance_to(dbase)])
	check(v_end < V_END and (touched_at < 0 or v_after < vmax * 0.5), "D: knocked once at most, then it settles: never pushed along (max %.0f, end %.1f px/s)" % [vmax, v_end])
	_mouse(false)
	await _frames(4)

	g.queue_free()
	await _frames(4)

	# ---------------- C: range mode
	await _game({"skill_grapple_multi": 1})
	var mg = g.tools.multi
	await _tap(KEY_X)
	check(mg.on, "key X: range mode")
	var base := Vector2(40, -6) * M
	_place(base)
	var bodies := []
	for i in 3:
		var q = _rect(base + Vector2(2.4, (i - 1) * 1.3) * M, Vector2(1.2, 1.1) * M, "FIELD-%d" % i, 0.4)
		bodies.append(q.body)
	await _frames(4)
	g.bot.aim = base + Vector2(2.4, 0.0) * M
	await _frames(3)
	_mouse(true)
	await _frames(4)
	check(mg.holding() and mg.held.size() == 3, "C: the field takes the three pieces (%d)" % mg.held.size())
	var r: Array = await _hover(func():
		for x in bodies:
			if x in g.drone.get_colliding_bodies():
				return true
		return false)
	print("  RANGE: hover 5 s  max |v| %.1f px/s  end |v| %.1f  drift %.1f px  touched %s" % [r[0], r[3], r[1], r[2]])
	check(r[0] < V_MAX and r[3] < V_END and r[1] < DRIFT_MAX, "C: range mode pulled in close, the drone hovers (max %.1f px/s, end %.1f, %.1f px in 5 s)" % [r[0], r[3], r[1]])
	check(not r[2], "C: the drone never collides with the field's loads")
	_mouse(false)
	await _frames(4)
	print("grab_close_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
