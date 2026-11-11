extends "res://tests/guide_check.gd"
# Probe (bug 2026-11-10 "我拿东西如果拿离我太近的话，反而会把我推着走"): a load pulled in close to
# the drone on the grapple. Real keys (3, left button), aim held by the pointer only; no move key.
# Prints drone drift, grab distance, tether force, whether the drone touches its own load.
#   tools/run_test.sh tests/grab_close_probe.gd --fixed-fps 60

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
	return g.world.add_piece("cargo", PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]), {"key": key, "tag": key, "cls": "metal", "barrier": false, "mass": mass, "value": 100.0})


func _key(k: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _mouse(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(ev)


func _case(name: String, size: Vector2, mass: float, grab_off: Vector2, aim_off: Vector2, base: Vector2, at_m: float = 2.6) -> void:
	var M := Geom.M
	g.drone.global_position = base
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()
	var p = _rect(base + Vector2(at_m, 0.0) * M, size * M, name, mass)
	g.world.make_body([p], null)
	p.body.linear_velocity = Vector2.ZERO
	await _frames(4)
	var at: Vector2 = p.body.global_transform * p.body.center_of_mass + grab_off * M
	g.bot.aim = at
	await _frames(3)
	_mouse(true)
	await _frames(4)
	if g.tools.held_body == null: print("  hover=", g.tools.hover)
	print("[%s] held=%s mass=%.2f t grab_max=%.2f reach=%.2f m" % [name, g.tools.held_body != null, p.body.total_mass(), g.grab_max(), g.tools.reach(3) / M])
	# pull the load in: the pointer goes right next to the drone
	g.bot.aim = g.drone.global_position + aim_off * M
	var x0: Vector2 = g.drone.global_position
	for i in 300:
		g.bot.aim = g.drone.global_position + aim_off * M
		await physics_frame
		if i % 30 == 29:
			var gp: Vector2 = g.tools.grab_point()
			var touch: bool = p.body in g.drone.get_colliding_bodies()
			print("  t=%.1fs drift=%.0f px v=(%.0f,%.0f) |v|=%.0f grab_d=%.2f m force=%.2f touch=%s body_mask=%d" % [(i + 1) / 60.0, g.drone.global_position.distance_to(x0), g.drone.linear_velocity.x, g.drone.linear_velocity.y, g.drone.linear_velocity.length(), gp.distance_to(g.drone.global_position) / M, g.tools.tether_force, touch, p.body.collision_mask])
	_mouse(false)
	await _frames(4)
	if is_instance_valid(p.body):
		p.body.queue_free()


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "kit": {}}
	root.add_child(g)
	await _frames(8)
	g.tutorial = null
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	_key(KEY_3, true)
	await _frames(2)
	_key(KEY_3, false)
	await _frames(2)
	print("tool=%d" % g.tools.tool)
	var M := Geom.M
	await _case("LIGHT", Vector2(0.5, 0.5), 0.1, Vector2.ZERO, Vector2(0.3, 0.0), Vector2(40, -6) * M)
	await _case("WIDE", Vector2(2.2, 2.2), 0.6, Vector2.ZERO, Vector2(0.3, 0.0), Vector2(40, 6) * M)
	await _case("BAR-FAR-END", Vector2(3.0, 0.4), 0.8, Vector2(1.4, 0.0), Vector2(0.3, 0.0), Vector2(52, -6) * M, 1.9)
	quit(0)
