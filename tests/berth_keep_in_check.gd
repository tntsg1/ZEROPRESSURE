extends "res://tests/berth_layout_check.gd"
# 2026-11-09 (user: "我这个本来很大，现在缩小之后，我怎么跑到外面去了"): a tall ship's contract lifts the
# berth's top and drops its floor; the empty berth after it comes up at the standard height, and the drone
# carried over (Game.carry) low in the hold was left under the new floor, out in the vacuum. Now the berth's
# tractor field draws it back in: smoothly (no jump a frame), through the girders, arriving at rest, its
# collisions back; it stays in. A loose piece left outside a berth laid out smaller is drawn in the same way.
# Before / after pictures (Game.KEEP_IN_ON). Own test saves only.
#   tools/run_test.sh tests/berth_keep_in_check.gd --fixed-fps 60

const ALL := {"berth88": 1, "berth120": 1, "berth200": 1, "berth620": 1}
const SHIP := "cv138"           # 150 m berth, top lifted 13.4 m, floor dropped 7.3 m


func _initialize() -> void:
	Career.path = "user://zp_test_berthkeep_career.json"
	SaveGame.path = "user://zp_test_berthkeep_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	for on in [false, true]:
		Game.KEEP_IN_ON = on
		await _case(on)
	Game.KEEP_IN_ON = true
	await _loose_piece()
	if g != null and is_instance_valid(g):
		g.queue_free()
		await _frames(4)
	print("BERTH KEEP IN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


# a tall ship's contract, the drone low at the far end of its dropped hold, settled: into the empty berth
func _case(on: bool) -> void:
	if g != null and is_instance_valid(g):
		g.queue_free()
		await _frames(4)
	_career()
	Career.data.upgrades = ALL.duplicate()
	Game.start_ship = SHIP
	Game.contract = {"id": "KEEP-" + SHIP, "ship": SHIP, "fee": 1000.0, "kit": ALL.duplicate()}
	Career.data.active = Game.contract.duplicate()
	Career.save()
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	await _frames(60)
	var M := Geom.M
	var tall_floor := Dock.FLOOR_Y
	if on:
		check(Dock.DROP > 1.0 and Dock.LIFT > 1.0, "%s: its contract's berth is lifted %.1f m and dropped %.1f m" % [SHIP, Dock.LIFT, Dock.DROP])
	var at := Vector2(Dock.FLOOR_X1 - 8.0, Dock.FLOOR_Y - 1.5) * M
	g.drone.alive = true
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(5)
	g._to_berth()
	var n := 0
	while (current_scene == g or current_scene == null or not current_scene.has_method("in_berth")) and n < 600:
		await _frames(1)
		n += 1
	g = current_scene
	# from the very first frame of the empty berth: how far it moves a frame, where it ends
	var w := 0
	while (g.drone == null or not g.drone.alive) and w < 120:
		await _frames(1)
		w += 1
	var start: Vector2 = g.drone.global_position
	check(Dock.FLOOR_Y < tall_floor - 1.0, "the empty berth after it is lower-floored (%.1f m, was %.1f m)" % [Dock.FLOOR_Y, tall_floor])
	if on:
		check(g.out_of_berth(start) == false or g.berth_gliding(), "the drone carried %.1f m down, under the new %.1f m floor, is being drawn in" % [start.y / M, Dock.FLOOR_Y])
	var last := start
	var worst := 0.0
	for i in 200:
		await _frames(1)
		var p: Vector2 = g.drone.global_position
		worst = maxf(worst, p.distance_to(last) / M)
		last = p
	var inner := g.berth_inner() as Rect2
	var m: Vector2 = g.drone.global_position / M
	if not on:
		check(m.y > Dock.FLOOR_Y, "before: the drone is left under the floor, outside the berth (%.1f m under a %.1f m floor)" % [m.y, Dock.FLOOR_Y])
		await _picture("before")
		return
	check(inner.has_point(m) and m.y < Dock.FLOOR_Y - 1.0, "after 3.3 s the drone is inside the berth (%s, floor %.1f m)" % [m.snapped(Vector2(0.1, 0.1)), Dock.FLOOR_Y])
	check(worst < 1.5, "drawn in smoothly: never more than 1.5 m a frame (worst %.2f m)" % worst)
	check(not g.berth_gliding() and not g.drone.freeze and g.drone.collision_mask != 0, "arrived: free again, its collisions back (mask %d)" % g.drone.collision_mask)
	check(g.drone.linear_velocity.length() / M < 2.0, "arrived at rest (%.2f m/s)" % (g.drone.linear_velocity.length() / M))
	for i in 120:
		await _frames(1)
	m = g.drone.global_position / M
	check(inner.has_point(m) and m.y < Dock.FLOOR_Y, "and stays in (%s)" % m.snapped(Vector2(0.1, 0.1)))
	await _picture("after")


func _picture(tag: String) -> void:
	g.cam_override = Vector2((Dock.FLOOR_X1 - 30.0) * Geom.M, 2.0 * Geom.M)
	g.zoom_override = 0.5
	await _frames(50)
	Cap.save(root, "res://tests/out/berth_keep_in_%s.png" % tag)
	g.cam_override = null
	g.zoom_override = -1.0


# a loose piece outside a berth laid out shorter and lower than it was: drawn in like the drone
func _loose_piece() -> void:
	var M := Geom.M
	var poly := PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	var at := Vector2(Dock.FLOOR_X1 + 30.0, Dock.FLOOR_Y + 12.0) * M
	var sq := PackedVector2Array()
	for q in poly:
		sq.append(at + q * M)
	var p = g.world.add_piece("plate", sq, {})
	g.world.rebuild_cols(p)
	var b = g.world.make_body([p], null)
	await _frames(3)
	check(b != null and is_instance_valid(b) and g.out_of_berth(b.global_position), "a loose piece lies outside the berth (%s)" % (b.global_position / M).snapped(Vector2(0.1, 0.1)) if b != null else "no body")
	if b == null:
		return
	g.keep_in_berth()
	check(g.berth_gliding(), "the field takes it")
	var last: Vector2 = b.global_position
	var worst := 0.0
	for i in 200:
		await _frames(1)
		if not is_instance_valid(b):
			break
		var stepm: float = b.global_position.distance_to(last) / M
		if stepm > 1.5:
			print("  piece jump frame %d: %.2f m (gliding %s) %s -> %s" % [i, stepm, g.berth_gliding(), (last / M).snapped(Vector2(0.1, 0.1)), (b.global_position / M).snapped(Vector2(0.1, 0.1))])
		worst = maxf(worst, stepm)
		last = b.global_position
	check(is_instance_valid(b) and not g.out_of_berth(b.global_position), "the piece is drawn inside (%s)" % (last / M).snapped(Vector2(0.1, 0.1)))
	check(worst < 1.5, "smoothly (worst %.2f m a frame)" % worst)
	check(is_instance_valid(b) and not g.berth_gliding() and b.collision_mask != 0, "free again, collisions back")
