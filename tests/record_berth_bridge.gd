extends "res://tests/berth_layout_check.gd"
# 方案 A: ~30 s for the owner — the standard 50 m berth (or the tier given after --) hung under the port: from the hub the shuttle runs down the
# bridge to the berth's stop; out, up to the gate's hook station, Enter, the top rail to the far end and
# back to the tower end, Enter, fly on. Own test saves only.
#   tools/run_test.sh tests/record_berth_bridge.gd --write-movie recordings/zeropressure_berth_bridge.avi --fixed-fps 30

func _initialize() -> void:
	Career.path = "user://zp_test_recbridge_career.json"
	SaveGame.path = "user://zp_test_recbridge_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fold() -> void:
	if g != null and g.get("hud") != null and g.hud.get("voice") != null and is_instance_valid(g.hud.voice):
		g.hud.voice.fold()


func _secs(s: float) -> void:
	for i in int(s * 30.0):
		_fold()
		await _frames(1)


func _run() -> void:
	var tier := 50.0
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			tier = float(a)
	await _layout(tier)
	var M := Geom.M
	var tr = g.tram
	var w0 := 0
	while tr.phase != "" and w0 < 30 * 60:
		await _frames(1)
		w0 += 1
	g.drone.global_position = Tram.station_at("ring")
	g.drone.linear_velocity = Vector2.ZERO
	await _secs(1.0)
	tr.call_to("ring", "salvage")
	var n := 0
	while n < 30 * 40 and not (str(tr.at) == "salvage" and tr.phase in ["", "alight", "return"]):
		if tr.phase in ["board", "wait"]:
			g.drone.global_position = Tram.station_at("ring")
		_fold()
		await _frames(1)
		n += 1
	await _secs(1.0)
	# up to the gate's hook station by the keys
	var rail = g.top_rail
	var gi := 0
	for i in rail.stations.size():
		if rail.gap != Vector2.ZERO and absf(float(rail.stations[i].x) - (rail.gap.x + rail.gap.y) * 0.5) < 0.1:
			gi = i
	var hp: Vector2 = _hook_point(gi)
	# over the gate's middle first, then straight down through it (it is 4 m wide)
	var above := Vector2(hp.x, g.drone.global_position.y)
	for i in 120:
		var to0: Vector2 = above - g.drone.global_position
		if absf(to0.x) < 0.25 * M and g.drone.linear_velocity.length() < 0.5 * M:
			break
		g.bot.move = Vector2(clampf(to0.x / (1.5 * M), -1.0, 1.0), 0.0)
		_fold()
		await _frames(1)
	for i in 240:
		var to: Vector2 = hp - g.drone.global_position
		if rail.near_station() == gi and g.drone.linear_velocity.length() < 0.6 * M:
			break
		var want: Vector2 = to / (3.0 * M)
		g.bot.move = (want - g.drone.linear_velocity / (6.0 * M)).limit_length(1.0)
		_fold()
		await _frames(1)
	g.bot.move = Vector2.ZERO
	g.bot.move = Vector2.ZERO
	await _secs(0.6)
	await _enter()
	await _secs(0.8)
	print("  REC hooked ", rail.hooked, " near ", rail.near_station(), " drone-hp m ", (g.drone.global_position - hp) / M, " car ", rail.stations[gi].car, " x ", rail.stations[gi].x, " gap ", rail.gap)
	var space: PhysicsDirectSpaceState2D = g.get_world_2d().direct_space_state
	for dy in [-2.0, -1.0, 0.0, 1.0]:
		var q := PhysicsPointQueryParameters2D.new()
		q.collision_mask = g.drone.collision_mask
		q.position = Vector2(hp.x, (Dock.RAIL_Y + dy) * M)
		print("  REC at gate x, y rail%+.0f: " % dy, space.intersect_point(q, 4).map(func(h): return str(h.collider.name)))
	g.bot.move = Vector2(1, 0)
	var guard := 0
	while rail.hooked >= 0 and rail.hx < rail.x1 - 0.7 and guard < 30 * 12:
		_fold()
		await _frames(1)
		guard += 1
	g.bot.move = Vector2(-1, 0)
	guard = 0
	while rail.hooked >= 0 and rail.hx > rail.x0 + 0.7 and guard < 30 * 12:
		_fold()
		await _frames(1)
		guard += 1
	g.bot.move = Vector2.ZERO
	await _secs(0.8)
	await _enter()
	await _secs(0.4)
	g.bot.move = Vector2(0.6, 0.8)
	await _secs(1.4)
	g.bot.move = Vector2.ZERO
	await _secs(1.5)
	quit()
