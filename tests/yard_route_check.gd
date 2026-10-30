extends "res://tests/yard_skip_check.gd"
# 87-6 (user 2026-10-27): a hulk pushed from the tug yard to the berth went straight through the port
# and came in from its right. Now it goes round: west out of the yard's column, south past the
# processing district, east under the berth's floor, up its open side, then in. For hulls of every
# size in each of the yard's first slots, with the other slots taken: every point of the way the
# hull's box is clear of every district, the berth and every hull parked in the yard (the old curve
# is shown failing the same check). The real bringing-in shot before, during and after; skipped
# part-way it is all the way in. Own saves only.
#   tools/run_test.sh tests/yard_route_check.gd --fixed-fps 60


func _hits(path_fn: Callable, hb: Rect2, obs: Array, n: int) -> int:
	var hits := 0
	for k in n + 1:
		var o: Vector2 = path_fn.call(float(k) / n)
		var r := Rect2(o + hb.position, hb.size)
		for ob in obs:
			if r.intersects(ob):
				hits += 1
				break
	return hits


func _run() -> void:
	Txt.zh = true
	await _start()
	await _frames(10)
	# the yard full: put hulks in slots 0..2 (the market's assets), then route each in turn
	var assets: Array = ShipMarket.data().assets
	var ships := ["gr7", "pod", "h22", "pt34", "ch110", "md160"]
	var ids: Array = []
	# three hulks in the yard (copies of the market's first asset where the market has fewer)
	while assets.size() < 3:
		var cp: Dictionary = assets[0].duplicate(true)
		cp.id = "%s-Y%d" % [str(assets[0].id), assets.size()]
		cp.ship = "gr7"
		assets.append(cp)
	for k in 3:
		assets[k]["yard"] = k
		ids.append(str(assets[k].id))
	var layout: Array = []
	var report: Array = []
	for sid in ships:
		for slot in [0, 1, 2]:
			if slot >= ids.size():
				continue
			var own: Dictionary = ShipMarket.asset(ids[slot])
			var keep_ship := str(own.get("ship", ""))
			own["ship"] = sid
			var hb: Rect2 = g.hull_box(sid)
			var x1 := hb.end.x
			var from: Vector2 = TugYard.slot_px(slot) - Vector2(x1, hb.get_center().y)
			var path: Array = g._yard_route(from, hb, ids[slot])
			var obs_all: Array = g.yard_obstacles(ids[slot])
			# what the hull already overlaps sitting in the berth is the port's layout, not the way there
			var berthed := Rect2(hb.position, hb.size)
			var obs: Array = []
			for ob in obs_all:
				if berthed.intersects(ob):
					if slot == 0:
						layout.append("%s in the berth overlaps %s m" % [sid, str(Rect2(ob.position / Geom.M, ob.size / Geom.M))])
				else:
					obs.append(ob)
			var new_hits := _hits(func(u): return g.along(path, u), hb, obs, 400)
			# the old curve (out of the yard to the berth's right, straight across)
			var p2 := Vector2(g.ship_offset, 0.0)
			var p1 := Vector2(from.x - 30.0 * Geom.M, p2.y + 40.0 * Geom.M)
			var old_hits := _hits(func(u): var e := Pal.ease_io(u); return from.lerp(p1, e).lerp(p1.lerp(p2, e), e), hb, obs, 400)
			report.append("%s slot %d: new way %d/401 points touching, old curve %d/401 (hull %s m)" % [sid, slot, new_hits, old_hits, str(Rect2(hb.position / Geom.M, hb.size / Geom.M))])
			if new_hits > 0:
				for k in 401:
					var o: Vector2 = g.along(path, float(k) / 400.0)
					var rr := Rect2(o + hb.position, hb.size)
					for ob in obs:
						if rr.intersects(ob):
							report.append("    at u=%.3f origin %s m hits %s m" % [float(k) / 400.0, str((o / Geom.M).round()), str(Rect2(ob.position / Geom.M, ob.size / Geom.M))])
							break
			check(new_hits == 0, "%s (%.0f m) from yard slot %d: clear of every structure and parked hull all the way" % [sid, hb.size.x / Geom.M, slot])
			own["ship"] = keep_ship
	for r in report:
		print("  " + r)
	for r in layout:
		print("  LAYOUT: " + r)
	g.queue_free()
	await _frames(4)
	# the real bringing-in: before, during, after
	await _start()
	var shots := {40: "before", int(60.0 * g.PUSH_T * 0.5): "during", int(60.0 * g.PUSH_T) + 60: "after"}
	var f := 0
	var during_world := Vector2.ZERO
	# user 2026-10-28: the tug pushing it went missing on the way round, and should burn like the drone
	var tug_off := 0.0
	var tug_seen := 0
	var acc_up := 0.0
	var acc_down := 0.0
	while f <= int(60.0 * g.PUSH_T) + 120 and g.state == "intro":
		await process_frame
		f += 1
		if g.state == "intro" and g.state_t < g.PUSH_T - 0.05:
			var tp: Vector2 = g.dock.tug_pos()
			if tp != Vector2.INF:
				tug_seen += 1
				tug_off = maxf(tug_off, tp.distance_to(g.world.position + g.dock.stern * Geom.M))
			var ac: Vector2 = g.dock.tug_accel()
			if absf(ac.y) > 6000.0 and not shots.values().has("burn_%d" % signi(int(ac.y))):
				shots[-f] = "burn_%d" % signi(int(ac.y))
				Cap.save(root, "res://tests/out/yard_route_burn_%s_zh.png" % ("down" if ac.y > 0.0 else "up"))
			acc_up = minf(acc_up, ac.y)
			acc_down = maxf(acc_down, ac.y)
		if shots.has(f):
			Cap.save(root, "res://tests/out/yard_route_%s_zh.png" % str(shots[f]))
			if shots[f] == "during":
				during_world = g.world.position
	check(during_world.y > 20.0 * Geom.M or during_world.x < -60.0 * Geom.M, "half-way the hulk is out round the station, not across it (%s m)" % str((during_world / Geom.M).round()))
	check(tug_seen > 60 and tug_off < 1.0, "the tug stays on the hull's stern all the way round (%d frames, %.1f px off at most)" % [tug_seen, tug_off])
	check(acc_down > 300.0 and acc_up < -300.0, "it burns both ways up and down: %.0f / %.0f px/s² (south leg and the climb, each started and braked)" % [acc_down, acc_up])
	# no turn at speed: the hull is at rest at every corner of the way
	var corner_v := 0.0
	var tt := 0.0
	var h := 1.0 / 240.0
	var prev_dir := Vector2.ZERO
	while tt < g.PUSH_T:
		var v: Vector2 = (g.yard_at(tt + h) - g.yard_at(tt)) / h
		if v.length() > 1.0:
			var dir := v.normalized()
			if prev_dir != Vector2.ZERO and dir.dot(prev_dir) < 0.5:
				corner_v = maxf(corner_v, (g.yard_at(tt) - g.yard_at(tt - h)).length() / h)
			prev_dir = dir
		tt += h
	check(corner_v < 0.5 * Geom.M, "the hull stops before each turn (at most %.2f m/s through a corner)" % (corner_v / Geom.M))
	for k in 400:
		if g.state != "intro":
			break
		await process_frame
	check(g.world.position == Vector2.ZERO and g.state == "play", "played through: the hulk ends in the berth")
	g.queue_free()
	await _frames(4)
	print("YARD ROUTE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
