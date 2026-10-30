extends "res://tests/guide_check.gd"
# 87-6: the work boat tows. From the berth the drone boards the boat, the player drives it out to
# the derelict section DS-1, hitches the line at its eye (not from too far, not too fast, not a
# load too heavy), takes up the slack and tows it round to the delivery box off the berth (the line
# really pulls: taut, the section follows, the boat feels the load), casts off, and the section is
# taken: the fee paid, its steel on the books. A jerk parts the line; the boat can also push it.
# Half-way the tow survives a save. Then the boat goes home and the drone gets out. Own saves only.
#   tools/run_test.sh tests/boat_tow_check.gd --fixed-fps 60

const BoatTow = preload("res://scripts/boat_tow.gd")
var tw


func _initialize() -> void:
	Career.path = "user://zp_test_boattow_career.json"
	SaveGame.path = "user://zp_test_boattow_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fresh() -> void:
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.data.money = 10000.0
	Career.save()


func _stern_at(p: Vector2) -> void:
	# the boat placed so its stern sits at p, still
	var b = g.boat
	b.global_position = p + Vector2.from_angle(b.heading) * WorkBoat.LEN * 0.5 * Geom.M
	b.linear_velocity = Vector2.ZERO


# drive the boat (its own thrust: input.move) along points, easing off when the line is hard
func _drive(points: Array, vmax: float, limit_s: float) -> float:
	var b = g.boat
	var t := 0.0
	var k := 0
	while t < limit_s and k < points.size():
		var to: Vector2 = points[k]
		var d: Vector2 = to - b.global_position
		if d.length() < 6.0 * Geom.M:
			k += 1
			continue
		var want: Vector2 = d.normalized() * vmax * Geom.M
		var err: Vector2 = want - b.linear_velocity
		g.bot.move = err.normalized() if err.length() > 0.3 * Geom.M and tw.tension < 20.0 else Vector2.ZERO
		g.bot.brake = false
		await process_frame
		t += 1.0 / 60.0
	g.bot.move = Vector2.ZERO
	return t


func _brake(limit_s: float) -> void:
	var b = g.boat
	var t := 0.0
	g.bot.brake = true
	while t < limit_s and b.linear_velocity.length() > 0.2 * Geom.M:
		await process_frame
		t += 1.0 / 60.0
	g.bot.brake = false


func _run() -> void:
	Txt.zh = true
	_fresh()
	await _spawn()
	await _frames(10)
	tw = g.boat_tow
	check(tw != null and tw.hulk != null and is_equal_approx(tw.hulk.mass, BoatTow.HULK_MASS), "the derelict section is out there (%.0f t)" % (tw.hulk.mass if tw != null and tw.hulk != null else -1.0))
	check(tw.hitch_reason() == "tow_not_aboard", "the line needs the boat crewed")
	# board at the berth pad
	g.drone.global_position = g.boat.global_position
	g.boat.board()
	check(g.boat.aboard, "the drone boards the boat at the berth")
	check(tw.hitch_reason() == "tow_too_far", "from the berth: too far to hitch")
	# out to the section (its own thrust), the stern up to the eye
	var t_out := await _drive([tw.eye() + Vector2(10.0, 0.0) * Geom.M], 6.0, 90.0)
	await _brake(10.0)
	report_line("drove out in %.1f s" % t_out)
	g.boat.heading = (g.boat.global_position - tw.eye()).angle()
	_stern_at(tw.eye() + (g.boat.global_position - tw.eye()).normalized() * 3.0 * Geom.M)
	g.boat.linear_velocity = Vector2(3.0 * Geom.M, 0)
	check(tw.hitch_reason() == "tow_too_fast", "moving 3 m/s against it: too fast to hitch")
	g.boat.linear_velocity = Vector2.ZERO
	tw.hulk.mass = 140.0
	check(tw.hitch_reason() == "tow_too_heavy", "a 140 t load is more than the boat can tow")
	tw.hulk.mass = BoatTow.HULK_MASS
	check(tw.hitch_reason() == "", "close, slow, a 28 t load: it can hitch")
	tw.toggle()
	check(tw.hitched, "T: the line is on")
	g.cam_override = tw.eye()
	g.zoom_override = 0.6
	for i in 60:
		await process_frame
	Cap.save(root, "res://tests/out/boat_hitch_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	# tow it home: out round the station and back to the delivery box
	var p0: Vector2 = tw.hulk.global_position
	var dp: Vector2 = BoatTow.deliver_point()
	# round the processing district (west, then south of it), then east into the box
	var route: Array = [Vector2(-158.0, -80.0) * Geom.M, Vector2(-150.0, -50.0) * Geom.M, Vector2(-85.0, -44.0) * Geom.M, dp + Vector2(10.0, 4.0) * Geom.M]
	var t_tow := await _drive(route.slice(0, 1), 2.0, 60.0)
	check(tw.peak > 1.0 and tw.hulk.global_position.distance_to(p0) > 8.0 * Geom.M, "taut, the line pulls the section after the boat (moved %.0f m, peak %.1f kN)" % [tw.hulk.global_position.distance_to(p0) / Geom.M, tw.peak])
	check(tw.hitched and tw.peak < BoatTow.BREAK_KN, "towed gently, the line holds")
	g.cam_override = (g.boat.global_position + tw.hulk.global_position) * 0.5
	g.zoom_override = 0.4
	for i in 60:
		await process_frame
	Cap.save(root, "res://tests/out/boat_towing_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	# half-way: a save holds the tow
	tw.save()
	var hp: Vector2 = tw.hulk.global_position
	g.queue_free()
	await _frames(4)
	Career.data = {}
	Career.load_or_new()
	await _spawn()
	await _frames(10)
	tw = g.boat_tow
	check(tw.hulk != null and tw.hulk.global_position.distance_to(hp) < 3.0 * Geom.M, "after loading the section is where it was (drifting on as it was)")
	check(not tw.hitched, "the boat loads at its pad, so the line counts as cast off")
	# back out to the section, hitch again, go on
	g.drone.global_position = g.boat.global_position
	g.boat.board()
	g.boat.heading = (tw.eye() - tw.hulk.global_position).angle()
	_stern_at(tw.eye() + (tw.eye() - tw.hulk.global_position).normalized() * 3.0 * Geom.M)
	tw.hulk.linear_velocity = Vector2.ZERO
	await _frames(2)
	tw.toggle()
	check(tw.hitched, "hitched again")
	t_tow += await _drive(route.slice(1), 2.0, 300.0)
	await _brake(20.0)
	report_line("towed in %.1f s, peak %.1f kN" % [t_tow, tw.peak])
	# the section into the box: cast off and let it come to rest
	if tw.hulk != null:
		var to_box: float = tw.hulk.global_position.distance_to(dp) / Geom.M
		report_line("section %.0f m from the box when the boat stops" % to_box)
	tw.toggle()
	check(not tw.hitched, "T again: the line cast off")
	var money0 := float(Career.data.money)
	var steel0 := float(Career.data.get("structure_t", 0.0))
	# a last nudge: push it in with the fenders if it lies short
	var waited := 0.0
	while waited < 60.0 and not tw.done:
		if tw.hulk != null and is_instance_valid(tw.hulk) and tw.hulk.global_position.distance_to(dp) > BoatTow.DELIVER_R * Geom.M * 0.8:
			var to: Vector2 = dp - tw.hulk.global_position
			var behind: Vector2 = tw.hulk.global_position - to.normalized() * (BoatTow.HULK_SIZE.x * 0.5 + WorkBoat.LEN * 0.5 + 0.5) * Geom.M
			var dd: Vector2 = behind - g.boat.global_position
			g.bot.move = (dd.normalized() if dd.length() > 1.0 * Geom.M else to.normalized()) if g.boat.linear_velocity.length() < 2.0 * Geom.M else Vector2.ZERO
		else:
			g.bot.move = Vector2.ZERO
			g.bot.brake = true
		await process_frame
		waited += 1.0 / 60.0
	g.bot.move = Vector2.ZERO
	g.bot.brake = false
	check(tw.done and Career.data.get("tow", {}).get("done", false), "delivered: the section is taken (%.0f s)" % waited)
	check(is_equal_approx(float(Career.data.money), money0 + BoatTow.FEE) and is_equal_approx(float(Career.data.get("structure_t", 0.0)), steel0 + BoatTow.STEEL_T), "the fee paid ($%.0f) and its steel on the books (+%.0f t), once" % [BoatTow.FEE, BoatTow.STEEL_T])
	# home: the boat back at the berth pad, the drone out
	var home := WorkBoat.pad_at("berth")
	await _drive([home + Vector2(0, -10.0) * Geom.M, home], 5.0, 120.0)
	await _brake(10.0)
	for i in 240:
		await process_frame
		if g.boat.pad == "berth" and g.boat.stopped():
			break
	check(g.boat.pad == "berth" and g.boat.leave() and not g.boat.aboard, "home at the berth pad, the drone gets out")
	g.queue_free()
	await _frames(4)

	# a jerk parts the line; a push moves it
	_fresh()
	await _spawn()
	await _frames(10)
	tw = g.boat_tow
	g.drone.global_position = g.boat.global_position
	g.boat.board()
	g.boat.heading = 0.0
	_stern_at(tw.eye() + Vector2(2.0 * Geom.M, 0))
	tw.toggle()
	g.boat.linear_velocity = Vector2(16.0 * Geom.M, 0)
	for i in 120:
		g.bot.move = Vector2.RIGHT
		g.bot.dash = true
		await process_frame
		if not tw.hitched:
			break
	g.bot.move = Vector2.ZERO
	g.bot.dash = false
	check(not tw.hitched and g.incidents.any(func(i): return i[1] == "tow_parted"), "a jerk at full dash parts the line (peak %.0f kN)" % tw.peak)
	await _brake(10.0)
	var hv0: float = tw.hulk.linear_velocity.length()
	g.boat.heading = PI
	_stern_at(tw.hulk.global_position + Vector2((BoatTow.HULK_SIZE.x * 0.5 + WorkBoat.LEN + 1.5) * Geom.M, 0))
	for i in 180:
		g.bot.move = Vector2.LEFT
		await process_frame
	g.bot.move = Vector2.ZERO
	check(tw.hulk.linear_velocity.length() > hv0 + 0.3 * Geom.M, "the boat pushes it with its fenders (%.1f m/s)" % (tw.hulk.linear_velocity.length() / Geom.M))
	g.queue_free()
	await _frames(4)
	# the districts before and after their first stage: the power district dead, then running
	_fresh()
	await _spawn()
	await _frames(10)
	var box: Rect2 = PortStructure.box("power")
	for st in [0, 1]:
		var pt: Dictionary = Career.data.get("port", {})
		pt["power"] = st
		Career.data.port = pt
		g.cam_override = box.get_center()
		g.zoom_override = 0.6
		for i in 80:
			await process_frame
		Cap.save(root, "res://tests/out/district_power_stage%d_zh.png" % st)
	g.cam_override = null
	g.zoom_override = -1.0
	check(Port.stage("power") == 1, "the power district shot dead (stage 0) and running (stage 1)")
	g.queue_free()
	await _frames(4)
	print("BOAT TOW %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func report_line(s: String) -> void:
	print("  " + s)
