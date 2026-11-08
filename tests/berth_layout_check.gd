extends "res://tests/top_rail_check.gd"
# 128 号 第 6 段 方案 A: a berth of every tier (50, 88, 120, 200, 620 m) hangs clear of the port: its outline
# touches no district, no corridor but its own bridge, not the hub or its rail, no other line's track, not the
# cargo yard or the freight pier; the bridge's walls reach down to the boom over the gate; the shuttle rides
# from the hub down the bridge to the berth's stop; the tow-in planner finds the way in for a hull. Pictures:
# the 0-key panorama at 88 and 620 m. Own test saves only.
#   tools/run_test.sh tests/berth_layout_check.gd --fixed-fps 60

const TIERS := [50.0, 88.0, 120.0, 200.0, 620.0]
const TowRoute = preload("res://scripts/tow_route.gd")
const TugWorks = preload("res://scripts/tug_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_berthlay_career.json"
	SaveGame.path = "user://zp_test_berthlay_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _aabb(cs: CollisionShape2D) -> Rect2:
	var sh = cs.shape
	var h := Vector2.ZERO
	if sh is RectangleShape2D:
		h = sh.size * 0.5
	elif sh is CircleShape2D:
		h = Vector2.ONE * sh.radius
	elif sh is SegmentShape2D:
		var xf0 := cs.global_transform
		return Rect2(xf0 * sh.a, Vector2.ZERO).expand(xf0 * sh.b)
	else:
		return Rect2(cs.global_position, Vector2.ZERO)
	var xf := cs.global_transform
	var r := Rect2(xf * -h, Vector2.ZERO)
	for v in [Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)]:
		r = r.expand(xf * v)
	return r


# a fresh berth scene with the extensions owned that make the empty berth this long (how the game lays it out)
func _layout(tier: float) -> void:
	if g != null and is_instance_valid(g):
		g.queue_free()
		await _frames(4)
	_career()
	var up: Dictionary = Career.data.get("upgrades", {})
	for k in ["berth88", "berth120", "berth200", "berth620"]:
		up.erase(k)
	for t2 in Dock.TIERS:
		if str(t2[1]) != "" and float(t2[0]) <= tier:
			up[str(t2[1])] = 1
	Career.data.upgrades = up
	Career.save()
	await _spawn()
	await _frames(30)


func _run() -> void:
	var M := Geom.M
	for tier in TIERS:
		await _layout(tier)
		check(absf(Dock.FLOOR_X1 - tier) < 0.5, "%.0f m: the berth laid out at its tier (%.0f m)" % [tier, Dock.FLOOR_X1])
		var berth := Rect2(Dock.BOUNDS.position * M, Dock.BOUNDS.size * M)
		var c := Backdrop.port_centre_px()
		var cx: float = g.port_structure.corridor_end("salvage").x
		var bridge := Rect2(Vector2(cx - (PortStructure.HALF_SALVAGE + 1.5) * M, c.y), Vector2((PortStructure.HALF_SALVAGE + 1.5) * 2.0 * M, berth.position.y - c.y + 6.0 * M))
		var hit: Array = []
		for z in PortArt.ANGLE:
			if z != "salvage" and PortStructure.box(z).grow(2.0 * M).intersects(berth):
				hit.append(z)
		# the hub and its outer rail
		var hr := (PortArt.RAIL_R + 2.0) * M
		if Rect2(c - Vector2(hr, hr), Vector2(hr, hr) * 2.0).intersects(berth):
			hit.append("hub")
		# every still structure but the berth's own and its bridge
		var own := [g.dock.bounds_body, g.top_rail.body]
		for b in root.find_children("*", "StaticBody2D", true, false):
			if b in own or (int(b.collision_layer) & (4 | 16)) == 0 or str(b.name) == "TugHulls":
				continue
			for cs in b.get_children():
				if not (cs is CollisionShape2D) or cs.disabled:
					continue
				var bb := _aabb(cs)
				if bridge.encloses(bb) or bridge.intersects(bb) and bb.get_center().x > bridge.position.x and bb.get_center().x < bridge.end.x:
					continue
				if bb.intersects(berth.grow(-0.2 * M)):
					hit.append(str(b.name) + "@" + str((bb.get_center() - c) / M))
		# other lines' track
		for z in PortArt.ANGLE:
			if z == "salvage":
				continue
			for p in Tram._leg(z):
				if berth.has_point(p):
					hit.append("track " + z)
		check(hit.is_empty(), "%.0f m: the berth (drop %.1f m) is clear of the port%s" % [tier, Dock.berth_drop(), (": " + str(hit)) if not hit.is_empty() else ""])
		# the bridge reaches down to the boom over the gate
		var foot: Vector2 = g.port_structure.corridor_end("salvage")
		check(absf(foot.y - (Dock.RAIL_Y - 0.3) * M) < 2.0 and absf(foot.x - g.dock.port_gate().get_center().x * M) < 1.0 * M, "%.0f m: the bridge's walls come down to the boom over the gate" % tier)
		# the shuttle: hub to the berth
		var tr = g.tram
		var w0 := 0
		while tr.phase != "" and w0 < 60 * 60:
			await _frames(1)
			w0 += 1
		g.drone.global_position = Tram.station_at("ring")
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(4)
		var ok: bool = tr.call_to("ring", "salvage")
		var n := 0
		while n < 60 * 90 and not (str(tr.at) == "salvage" and tr.phase in ["", "alight", "return"]):
			if tr.phase == "board" or tr.phase == "wait":
				g.drone.global_position = Tram.station_at("ring")
			await _frames(1)
			n += 1
		check(ok and str(tr.at) == "salvage", "%.0f m: the shuttle runs from the hub down the bridge to the berth (%.1f s, %.0f m of track)" % [tier, n / 60.0, Tram.station_at("ring").distance_to(Tram.station_at("salvage")) / M])
		await _frames(30)
		# the tow-in: a hull is pushed in along the berth's line from its open right end (game.yard_start: no
		# trip from the tug yard any more): that way in, as far out as the hull starts, holds nothing of the port
		# the hull starts game.ship_offset (60 m) right of its berthed place: the lane is that and the longest
		# hull the tier takes (its length less 6 m), from the berth's open end
		var lane := Rect2(Vector2(Dock.FLOOR_X1 - 2.0, Dock.BOUNDS.position.y + 1.0) * M, Vector2(g.ship_offset / M + tier - 6.0 + 4.0, Dock.BOUNDS.size.y - 2.0) * M)
		var in_lane: Array = []
		for b in root.find_children("*", "StaticBody2D", true, false):
			if b in own or (int(b.collision_layer) & (4 | 16)) == 0 or str(b.name) == "TugHulls":
				continue
			for cs in b.get_children():
				if cs is CollisionShape2D and not cs.disabled and _aabb(cs).intersects(lane):
					in_lane.append(str(b.name) + "@" + str((_aabb(cs).get_center() - Backdrop.port_centre_px()) / M))
		for z in PortArt.ANGLE:
			if z != "salvage" and PortStructure.box(z).intersects(lane):
				in_lane.append(z)
		check(in_lane.is_empty(), "%.0f m: the tow-in lane off the berth's open end is clear%s" % [tier, (": " + str(in_lane)) if not in_lane.is_empty() else ""])
		if tier == 50.0 or tier == 88.0 or tier == 620.0:
			g.port_view = true
			_ui(false)
			for i in 90:
				await _frames(1)
			Cap.save(root, "res://tests/out/berth_layout_pano_%d.png" % int(tier))
			g.port_view = false
			_ui(true)
			await _frames(20)
	g.queue_free()
	await _frames(4)
	print("BERTH LAYOUT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
