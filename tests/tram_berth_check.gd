extends "res://tests/guide_check.gd"
# 97 号: the berth's shuttle stop and the finer train. The stop stands in the berth's port gate,
# known from the start (old saves too); every ride from any stop to any other is planned on the
# rails without a lap of the hub (a reversal past a switch where it cannot turn in the way it
# faces); the switches are set before the train runs over them; the doors open at the stop and
# shut before it moves; the bodies lean on their springs through the curves; the drone steps off
# onto the platform, clear of every wall. Own test saves only.
#   godot --headless --fixed-fps 60 -s tests/tram_berth_check.gd


func _initialize() -> void:
	Career.path = "user://zp_test_tram_berth_career.json"
	SaveGame.path = "user://zp_test_tram_berth_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _free_at(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = 1 | 4 | World.STATIC_LAYER
	return g.get_world_2d().direct_space_state.intersect_point(q, 4).is_empty()


# ride from `here` to `to` with the drone; returns [seconds, reversals, switch faults, door faults, max lean m]
func _ride(here: String, to: String) -> Array:
	var tr = g.tram
	g.drone.global_position = Tram.station_at(here) + Tram.platform_side(here) * 1.2 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(2)
	if not tr.call_to(here, to):
		return [-1.0, 0, 0, 0, 0.0]
	var f := 0
	var flips := 0
	var lead0: int = tr.lead
	var sw_bad := 0
	var door_bad := 0
	var lean_max := 0.0
	var toes := {}
	for sw in tr._switches:
		toes[sw.id] = (sw.a[0] as Vector2) + Backdrop.port_centre_px()
	while (tr.phase != "" or tr.door[0] > 0.01) and f < 60 * 60:
		await _frames(1)
		f += 1
		if tr.lead != lead0:
			flips += 1
			lead0 = tr.lead
		if tr.speed > 0.0:
			# a moving train has its doors shut and every switch of its leg set where it is
			if tr.door[0] > 0.01 or tr.door[1] > 0.01:
				door_bad += 1
			for id in tr._leg_sw:
				for b in tr._bob:
					if (b as Vector2).distance_to(toes[id]) < 0.8 * Geom.M and absf(float(tr.sw_pos.get(id, 0.0)) - float(tr._leg_sw[id])) > 0.01:
						sw_bad += 1
		for l in tr.lean:
			lean_max = maxf(lean_max, (l as Vector2).length())
	return [f / 60.0, flips, sw_bad, door_bad, lean_max]


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "cargo": 1, "power": 1, "tug": 1}
	# an old save: two districts known, nothing of the berth's stop
	Career.data.tram_found = ["ring", "power"]
	Career.save()
	await _spawn()
	await _frames(10)
	var tr = g.tram
	var M := Geom.M
	# the stop
	check("salvage" in Tram.stations(), "the berth's stop is one of the stations")
	check("salvage" in Tram.found() and "power" in Tram.found() and "trade" not in Tram.found(), "known from the start, an old save's stops kept (%s)" % str(Tram.found()))
	Tram.discover("salvage")
	check("salvage" not in Career.data.tram_found, "nothing new saved for it")
	var gate: Rect2 = g.dock.port_gate()
	var sp := Tram.station_at("salvage")
	check(absf(sp.x - gate.get_center().x * M) < 0.05 * M and absf(sp.y - (Dock.RAIL_Y - Tram.BERTH_STOP) * M) < 0.05 * M, "it stands in the berth's port gate, %.1f m above the rail" % Tram.BERTH_STOP)
	var off := Tram.alight_at("salvage")
	check(off.y < Dock.RAIL_Y * M and absf(off.x - gate.get_center().x * M) < gate.size.x * 0.5 * M, "the drone steps off over the gate's opening: straight down into the berth")
	g.drone.global_position = Vector2(gate.get_center().x, Dock.RAIL_Y + 1.0) * M
	await _frames(2)
	check(tr.near_station() != "salvage", "from inside the berth the stop is not offered")
	g.drone.global_position = Vector2(gate.get_center().x, Dock.RAIL_Y - 1.2) * M
	await _frames(2)
	check(tr.near_station() == "salvage", "a metre out of the gate: the stop is there")
	# every ride planned: from its stop to the other, continuous, no lap of the hub
	var worst := ""
	var worst_len := 0.0
	var gaps := 0
	var laps := 0
	var two := []
	for a in Tram.stations():
		for b in Tram.stations():
			if a == b:
				continue
			var lg: Array = Tram.plan(a, b)
			var pts: Array = []
			for l in lg:
				pts.append_array(l.pts)
			if (pts[0] as Vector2).distance_to(Tram.station_at(a)) > 1.0 or (pts[-1] as Vector2).distance_to(Tram.station_at(b)) > 1.0:
				gaps += 1
			for i in range(1, lg.size()):
				if ((lg[i - 1].pts as Array)[-1] as Vector2).distance_to(lg[i].pts[0]) > 1.0:
					gaps += 1
			var ln := 0.0
			for l in lg:
				ln += preload("res://scripts/tram_art.gd").length(l.pts) / M
			if ln > worst_len:
				worst_len = ln
				worst = "%s→%s" % [a, b]
			# the loop's own travel: never most of a lap
			var turn := 0.0
			for l in lg:
				var c := Backdrop.port_centre_px()
				var prev = null
				for p in l.pts:
					if (p as Vector2).distance_to(c) < (Tram.LOOP_R + 0.2) * M and (p as Vector2).distance_to(c) > (Tram.LOOP_R - 0.2) * M:
						var an := ((p as Vector2) - c).angle()
						if prev != null:
							turn += absf(angle_difference(prev, an))
						prev = an
			if turn > PI * 1.5:
				laps += 1
				print("  lap: %s→%s %.0f°" % [a, b, rad_to_deg(turn)])
			if lg.size() > 1:
				two.append("%s→%s" % [a, b])
	check(gaps == 0, "every ride runs from its stop to the other, each leg on from where the last stopped")
	check(laps == 0, "no ride runs more than three quarters of the hub's loop (the longest %s, %.0f m)" % [worst, worst_len])
	# 道岔缩短 (user 2026-11-10): the turnouts take 16° of the loop, not 46°: no two stops' overlap, so no
	# ride changes ends (the hub's stop and the processing line's used to)
	check(two.is_empty(), "no ride changes ends: every one turns in straight (%s)" % ", ".join(two))
	# every switch the plans name is one that stands on the rails
	var ids := {}
	for sw in tr._switches:
		ids[sw.id] = true
	var unknown := 0
	for a in Tram.stations():
		for b in Tram.stations():
			if a != b:
				for l in Tram.plan(a, b):
					for id in l.sw:
						if not ids.has(id):
							unknown += 1
	# 130 号: 18, the berth's freight siding (salvage:s) and the ring's passing loop (p1:a, p1:b)
	check(unknown == 0 and ids.size() == 21, "the plans set only switches that exist (%d switches, %d unknown)" % [ids.size(), unknown])
	# the still track is built a slice a frame: no frame gives it more than a few ms
	for i in 120:
		if tr._job == null:
			break
		await _frames(1)
	print("  slowest job %.2f ms, slowest mesh made %.2f ms" % [tr.build_job_us / 1000.0, tr.build_cut_us / 1000.0])
	check(tr._job == null and not tr._track.is_empty(), "the track is built (%d meshes, %.1f ms in all over its frames)" % [tr._track.size(), tr.build_us / 1000.0])
	# a frame gives it BUILD_SLICE and at most one job past that: the jobs must be short (the slice
	# itself is wall time, and a busy machine can stretch any one of them)
	check(tr.build_job_us < 2000 and tr.plan_us < 3000, "no frame of it takes long: jobs at most %.2f ms (a frame %.1f ms + one job; longest slice seen %.1f ms), the lines and switches first %.1f ms" % [tr.build_job_us / 1000.0, Tram.BUILD_SLICE / 1000.0, tr.build_slice_us / 1000.0, tr.plan_us / 1000.0])
	# rides: hub → berth (one reversal), berth → trade (straight through), process → tug
	Career.data.tram_found = ["ring", "power", "tug", "process", "trade", "cargo"]
	for r in [["ring", "salvage"], ["salvage", "trade"], ["trade", "salvage"], ["salvage", "ring"], ["process", "tug"]]:
		if tr.at != r[0]:
			# bring the car to the stop first (a fetch)
			pass
		var res: Array = await _ride(r[0], r[1])
		check(res[0] > 0.0 and tr.at == r[1] and not tr.riding, "%s → %s: there in %.1f s, %d reversal(s)" % [r[0], r[1], res[0], res[1]])
		check(res[2] == 0, "  every switch set before a bogie reached it (%d faults)" % res[2])
		check(res[3] == 0, "  the doors shut whenever it moved (%d frames open)" % res[3])
		check(_free_at(g.drone.global_position), "  the drone stepped off onto the platform, clear of walls")
		if r[0] == "ring" and r[1] == "salvage":
			check(res[1] == 0 and res[0] < 14.0, "  the hub's stop to the berth's: straight on, quick (%.1f s)" % res[0])
		if r[0] == "salvage" and r[1] == "trade":
			check(res[4] > 0.03 and res[4] < 0.2, "  the bodies lean on their springs through the curves (%.2f m at most)" % res[4])
	# every stop's platform clear of walls
	var blocked := []
	for s in Tram.stations():
		if not _free_at(Tram.alight_at(s)):
			blocked.append(s)
	check(blocked.is_empty(), "every platform is clear of walls %s" % str(blocked))
	g.queue_free()
	await _frames(4)
	print("TRAM BERTH %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
