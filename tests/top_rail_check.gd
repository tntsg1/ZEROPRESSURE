extends "res://tests/collision_audit.gd"
# 128 号 第 6 段 顶部快线: every berth tier (50, 88, 120, 200, 620 m): hooked at a station with Enter, the
# whole rail in about 5 s (20 % of its length a second); no inertia while hooked (the key let go, it
# stands the same frame); Enter again: the drone is free from rest and flies with its own inertia; the
# rail is solid and blocks neither the crane's carrying height nor any mouth's way in. Two pictures:
# the longest berth whole, the drone hooked close up. Own test saves only.
#   tools/run_test.sh tests/top_rail_check.gd --fixed-fps 60

const T_MIN := 4.3
const T_MAX := 5.3
const Crane = preload("res://scripts/crane.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_toprail_career.json"
	SaveGame.path = "user://zp_test_toprail_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _enter() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.physical_keycode = KEY_ENTER
		ev.pressed = down
		Input.parse_input_event(ev)
		await _frames(1)


func _hook_point(i: int) -> Vector2:
	var tr = g.top_rail
	return tr.global_position + Vector2(float(tr.stations[i].x), tr.y_hang()) * Geom.M


func _run() -> void:
	_career()
	await _spawn()
	await _frames(30)
	var tr = g.top_rail
	check(tr != null, "the berth has its top rail")
	for tier in [50.0, 88.0, 120.0, 200.0, 620.0]:
		g._layout_shape(tier, 0.0, 0.0)
		g.dock._bounds()
		tr.rebuild()
		await _frames(5)
		var L: float = tr.length()
		# the station at the tower end
		var first := 0
		g.drone.global_position = _hook_point(first)
		g.drone.linear_velocity = Vector2.ZERO
		g.bot.move = Vector2.ZERO
		await _frames(3)
		check(tr.near_station() == first, "%.0f m: the drone is at a station's hook point" % tier)
		await _enter()
		await _frames(int(tr.LATCH_S * 60.0) + 4)
		check(tr.hooked == first and g.drone.freeze, "%.0f m: Enter hooks it on" % tier)
		# end to end
		var start_x: float = tr.hx
		g.bot.move = Vector2(1, 0)
		var n := 0
		while tr.hx < tr.x1 - 0.61 and n < 1200:
			await _frames(1)
			n += 1
		var secs := n / 60.0
		var full: float = secs * (tr.length() - 1.2) / maxf(tr.x1 - 0.6 - start_x, 0.01)
		print("  %.0f m berth: rail %.1f m, %.1f m/s, %.2f s from the station to the far end (%.2f s the whole length), %d stations" % [tier, L, tr.speed(), secs, full, tr.stations.size()])
		check(full >= T_MIN and full <= T_MAX, "%.0f m: the whole rail in %.2f s (%.1f–%.1f)" % [tier, full, T_MIN, T_MAX])
		# no inertia: let go, it stands the same frame
		g.bot.move = Vector2(-1, 0)
		await _frames(20)
		var x_go: float = tr.hx
		g.bot.move = Vector2.ZERO
		await _frames(1)
		var x_stop: float = tr.hx
		await _frames(10)
		check(absf(tr.hx - x_stop) < 0.001 and absf(x_stop - x_go) <= tr.speed() / 60.0 + 0.001 and g.drone.linear_velocity == Vector2.ZERO, "%.0f m: no inertia hooked (key up: stopped the frame after, %.3f m after)" % [tier, absf(tr.hx - x_go)])
		var g0: Vector2 = g.drone.global_position
		check(g0.distance_to(tr.global_position + Vector2(tr.hx, tr.y_hang()) * Geom.M) < 1.0, "%.0f m: the drone hangs under its carriage" % tier)
		# release: from rest, then its own inertia
		await _enter()
		await _frames(1)
		check(tr.hooked == -1 and not g.drone.freeze and g.drone.linear_velocity.length() < 1.0, "%.0f m: Enter lets go, the drone at rest (%.1f px/s)" % [tier, g.drone.linear_velocity.length()])
		g.bot.move = Vector2(1, 0)
		await _frames(2)
		var v2: float = g.drone.linear_velocity.x
		await _frames(10)
		var v12: float = g.drone.linear_velocity.x
		g.bot.move = Vector2.ZERO
		await _frames(1)
		var v13: float = g.drone.linear_velocity.x
		check(v2 > 0.0 and v12 > v2 * 1.5 and v13 > 0.0, "%.0f m: free again it speeds up and coasts like a drone (%.0f → %.0f px/s, still %.0f after the key)" % [tier, v2, v12, v13])
		await _frames(30)
		# the rail does not stand in the crane's or the mouths' way
		var space: PhysicsDirectSpaceState2D = g.get_world_2d().direct_space_state
		var blocked := ""
		var ys := [Crane.LIFT_Y - 1.0, Crane.LIFT_Y]
		var x: float = tr.x0
		while x < tr.x1:
			for yy in ys:
				var q := PhysicsPointQueryParameters2D.new()
				q.position = tr.global_position + Vector2(x, float(yy)) * Geom.M
				q.collision_mask = 4
				for h in space.intersect_point(q, 4):
					if h.collider == tr.body:
						blocked = "crane %.1f m" % x
			x += 1.0
		for id in Dock.ZONES:
			var zp: Vector2 = g.dock.zpos(id)
			var f: Vector2 = Dock.ZONES[id].face
			var rq := PhysicsRayQueryParameters2D.create(zp - f * 4.0 * Geom.M, zp + f * 0.2 * Geom.M, 4)
			var hit := space.intersect_ray(rq)
			if not hit.is_empty() and hit.collider == tr.body:
				blocked += " mouth " + str(id)
		check(blocked == "", "%.0f m: the rail blocks neither the crane's load nor any mouth's way in%s" % [tier, (" (" + blocked + ")") if blocked != "" else ""])
		# the rail is solid: a drone flown up into it stops under it
		g.drone.global_position = tr.global_position + Vector2(tr.x1 - 4.0, tr.y_hang() + 1.0) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO
		for i in 40:
			g.drone.linear_velocity = Vector2(0, -6.0 * Geom.M)
			await _frames(1)
		check(g.drone.global_position.y > tr.global_position.y + (tr.y_beam() + tr.TRACK_H) * Geom.M, "%.0f m: the rail is solid: the drone stops under it" % tier)
		g.drone.linear_velocity = Vector2.ZERO
		if tier == 620.0:
			await _pictures()
	g._layout_shape(50.0, 0.0, 0.0)
	g.queue_free()
	await _frames(4)
	print("TOP RAIL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


func _pictures() -> void:
	var tr = g.top_rail
	var M := Geom.M
	# the longest berth whole, the rail along its top
	var r := Rect2(tr.global_position + Vector2(tr.x0 - 4.0, Dock.RAIL_Y - 6.0) * M, Vector2(tr.length() + 8.0, Dock.FLOOR_Y - Dock.RAIL_Y + 10.0) * M)
	_put(r.get_center(), _zoom_for(r))
	_ui(false)
	await _frames(8)
	Cap.save(root, "res://tests/out/top_rail_620_whole.png")
	_ui(true)
	# hooked, close up, half way along
	var mid := 1
	for i in tr.stations.size():
		if tr.gap == Vector2.ZERO or float(tr.stations[i].x) > tr.gap.y + 8.0:
			mid = i
			break
	g.drone.global_position = _hook_point(mid)
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(3)
	await _enter()
	_ui(false)
	_put(_hook_point(mid) + Vector2(0, -0.8 * M), 2.2)
	for i in 8:
		await _frames(1)
	Cap.save(root, "res://tests/out/top_rail_latching.png")
	await _frames(20)
	Cap.save(root, "res://tests/out/top_rail_hooked.png")
	_ui(true)
	await _enter()
	await _frames(3)
	g.cam_override = null
	g.zoom_override = -1.0
