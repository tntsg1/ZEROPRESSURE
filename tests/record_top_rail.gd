extends "res://tests/top_rail_check.gd"
# 128 号 第 6 段 顶部快线: ~20 s for the owner — an 88 m berth: fly to the tower-end station, Enter (the
# arm drops, the jaws close), right to the far end with no inertia, stop, Enter, fly on with the drone's own
# inertia. Own test saves only.
#   tools/run_test.sh tests/record_top_rail.gd --write-movie recordings/zeropressure_top_rail.avi --fixed-fps 30

func _initialize() -> void:
	Career.path = "user://zp_test_rectoprail_career.json"
	SaveGame.path = "user://zp_test_rectoprail_save.json"
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
	_career()
	await _spawn()
	await _frames(20)
	var tr = g.top_rail
	g._layout_shape(88.0, 0.0, 0.0)
	g.dock._bounds()
	tr.rebuild()
	await _frames(5)
	var M := Geom.M
	var p0: Vector2 = _hook_point(0)
	g.drone.global_position = p0 + Vector2(6.0, 5.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	# fly up to the station by the keys (its own inertia)
	for i in 75:
		var to: Vector2 = p0 - g.drone.global_position
		g.bot.move = to.normalized() * clampf(to.length() / (2.0 * M), 0.0, 1.0)
		_fold()
		await _frames(1)
	g.bot.move = Vector2.ZERO
	await _secs(1.0)
	await _enter()
	await _secs(1.2)
	g.bot.move = Vector2(1, 0)
	while tr.hx < tr.x1 - 0.7:
		_fold()
		await _frames(1)
	g.bot.move = Vector2.ZERO
	await _secs(1.2)
	g.bot.move = Vector2(-1, 0)
	await _secs(0.8)
	g.bot.move = Vector2.ZERO
	await _secs(1.0)
	await _enter()
	await _secs(0.5)
	g.bot.move = Vector2(-0.6, 0.8)
	await _secs(1.6)
	g.bot.move = Vector2.ZERO
	await _secs(2.0)
	g._layout_shape(50.0, 0.0, 0.0)
	quit()
