extends "res://tests/guide_check.gd"
# 35 号: the shuttle with some weight to it — up to 20 m/s, slowing before each curve to what
# 4 m/s² sideways allows, a smooth stop; two cars, the second following the first.
#   tools/run_test.sh tests/tram_feel_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_tram_feel_career.json"
	SaveGame.path = "user://zp_test_tram_feel_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1}
	Career.save()
	await _spawn()
	await _frames(10)
	var tr = g.tram
	g.drone.global_position = Tram.station_at("process")
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(4)
	check(tr.call_to("process", "cargo"), "called at the processing district, bound for cargo")
	var top := 0.0
	var over := 0.0
	var frames := 0
	var ride := 0
	var shot := false
	# user 2026-10-27: through the hub's curves the car turned in jerks. The train's axis (lead car
	# to second car, either way round: at a station the rear car takes the lead) per frame, and how
	# far either car jumps in a frame
	var axis := func(): return (tr.position_px - tr._rear_now()).angle()
	var h_prev: float = axis.call()
	var cars_prev: Array = [tr.position_px, tr._rear_now()]
	var turn_max := 0.0
	var turned := 0.0
	var jump := 0.0
	while tr.phase != "" and frames < 60 * 60:
		await _frames(1)
		frames += 1
		var hn: float = axis.call()
		var cars: Array = [tr.position_px, tr._rear_now()]
		if tr.phase in ["ride", "fetch", "board"]:
			var dh := absf(angle_difference(h_prev, hn))
			dh = minf(dh, PI - dh)
			turn_max = maxf(turn_max, dh)
			turned += dh
			# each car against the nearer of the two a frame ago (the lead may have changed ends)
			for c in cars:
				jump = maxf(jump, minf(c.distance_to(cars_prev[0]), c.distance_to(cars_prev[1])))
		h_prev = hn
		cars_prev = cars
		if tr.phase in ["board", "ride", "alight"]:
			ride += 1
		top = maxf(top, tr.speed)
		if tr.phase == "ride" and not tr.limits.is_empty():
			over = maxf(over, tr.speed - float(tr.limits[0]) - sqrt(2.0 * Tram.ACCEL * (tr.path[0] as Vector2).distance_to(tr.position_px)))
		if not shot and tr.phase == "ride" and tr.speed > 0.8 * Tram.SPEED:
			shot = true
			g.cam_override = tr.position_px
			g.zoom_override = 0.35
			await _frames(2)
			Cap.save(root, "res://tests/out/tram_ride_zh.png")
			g.cam_override = null
			g.zoom_override = -1.0
	var secs := ride / 60.0
	check(tr.at == "cargo" and not tr.riding, "it comes for the drone (%.1f s), then the ride (%.1f s)" % [(frames - ride) / 60.0, secs])
	# (130 号 review: top speed 36 m/s; the corridors are too short to reach it all, as a real line's)
	check(top > 0.55 * Tram.SPEED and top <= Tram.SPEED + 0.01, "it gets up to speed on the corridors (%.1f of %.0f m/s)" % [top / Geom.M, Tram.SPEED / Geom.M])
	check(over <= 0.5 * Geom.M, "it never runs into a curve faster than the curve allows (worst %.2f m/s over)" % (over / Geom.M))
	check(turned > 1.0 and turn_max < deg_to_rad(3.0), "it turns through the curves smoothly: %.0f° in all, never more than %.1f° a frame" % [rad_to_deg(turned), rad_to_deg(turn_max)])
	check(jump < Tram.SPEED / 60.0 * 1.2, "no car ever jumps: at most %.2f m in a frame (top speed is %.2f)" % [jump / Geom.M, Tram.SPEED / 60.0 / Geom.M])
	# 130 号: the freight trains share the rails; the shuttle comes first but may wait a moment for one to
	# clear (this ride: 17.6 s with no freight, 18.2 s with it)
	# (at 20 m/s it took 17.6 s; at 36 m/s, 15.3 s: boarding and stepping off take the same)
	check(secs > 6.0 and secs < 17.0, "a ride across the port, boarding to stepping off, takes a sensible time (%.1f s)" % secs)
	g.queue_free()
	await _frames(4)
	print("TRAM FEEL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
