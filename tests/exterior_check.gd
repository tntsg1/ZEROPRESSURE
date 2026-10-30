extends "res://tests/guide_check.gd"
# 43 号: the station's outside, cleaned up. What each district keeps outside (PortArt.exterior_rects)
# cuts into no other district and not into the hub; the processing district's exhaust stays under
# the tug station; and shots of the cleaned-up places.
#   tools/run_test.sh tests/exterior_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_exterior_career.json"
	SaveGame.path = "user://zp_test_exterior_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _circle_hits(r: Rect2, radius: float) -> bool:
	var q := Vector2(clampf(0.0, r.position.x, r.end.x), clampf(0.0, r.position.y, r.end.y))
	return q.length() < radius


func _shot(at: Vector2, zoom: float, name: String) -> void:
	g.cam_override = at
	g.cam_pos = at
	g.zoom_override = zoom
	g.zoom_now = zoom
	await _frames(40)
	Cap.save(root, "res://tests/out/%s.png" % name)


func _run() -> void:
	Txt.zh = true
	var clean := true
	var notes: Array = []
	for zone in PortArt.ANGLE:
		for rr in PortArt.exterior_rects(zone):
			var r: Rect2 = rr
			for other in PortArt.ANGLE:
				if other == zone or other == "salvage":
					continue
				var ob := Rect2(PortArt.district_at(other) - PortArt.BOX * 0.5, PortArt.BOX)
				if r.intersects(ob):
					clean = false
					notes.append("%s→%s" % [zone, other])
			if _circle_hits(r, PortArt.HUB_R):
				clean = false
				notes.append("%s→hub" % zone)
	check(clean, "nothing outside a district cuts into another district or the hub %s" % str(notes))
	var vent: Rect2 = PortArt.exterior_rects("process")[0]
	var tug_box := Rect2(PortArt.district_at("tug") - PortArt.BOX * 0.5, PortArt.BOX)
	check(vent.position.y > tug_box.end.y, "the processing exhaust tops out %.1f m under the tug station" % (vent.position.y - tug_box.end.y))
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "tug": 1, "cargo": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	var m := PortStructure.M()
	var c := PortStructure.centre()
	await _shot(c + (PortArt.district_at("process") + PortArt.district_at("tug")) * 0.5 * m, 0.22, "exterior_process_tug_zh")
	await _shot(c + PortArt.district_at("cargo") * m + Vector2(30, 10) * m, 0.2, "exterior_cargo_zh")
	await _shot(c + PortArt.district_at("trade") * m + Vector2(40, 0) * m, 0.2, "exterior_trade_zh")
	await _shot(c + PortArt.district_at("power") * m, 0.22, "exterior_power_zh")
	# 56 号: the processing roof — its plant under 6 m, its exhaust over the baghouse riser (x 42 m)
	var proc: Array = PortArt.exterior_rects("process")
	var tall := 0.0
	for rr in proc:
		tall = maxf(tall, (rr as Rect2).size.y)
	check(tall <= 6.0 + 0.001, "the processing roof's plant stays within 6 m (%.1f)" % tall)
	var pbox := Rect2(PortArt.district_at("process") - PortArt.BOX * 0.5, PortArt.BOX)
	var vx: float = (proc[0] as Rect2).get_center().x - pbox.position.x
	check(absf(vx - 42.0) <= 1.0, "the exhaust stands over the baghouse riser (x %.1f m)" % vx)
	# the cooler's fans: still while the furnace is cold, turning while it heats on grid power
	var a0 := PortArt.fan_angle()
	await _frames(30)
	var still := absf(PortArt.fan_angle() - a0) < 0.0001
	PortArt.test_furnace = true
	var a1 := PortArt.fan_angle()
	await _frames(30)
	var turns := absf(PortArt.fan_angle() - a1) > 0.01
	check(still and turns, "the cooler's fans turn only while the arc furnace heats (still %s, turning %s)" % [still, turns])
	await _shot(c + PortArt.district_at("process") * m + Vector2(0, -8) * m, 0.45, "exterior_process_on_zh")
	PortArt.test_furnace = false
	# the salvage district: the parts store shows the parts held; no idle pit cranes
	Career.data.parts = []
	for k in 3:
		Career.data.parts.append({"uid": "T:P%d:%d" % [k, k], "cls": "power", "tag": "P%d" % k, "nk": "p_battery", "cond": 0.9, "value": 1000.0, "ship": "tug", "job": "T"})
	check(PortArt.parts_held() == 3, "the parts store holds the parts really held (3)")
	check(g.dock.ships != null and not g.dock.ships.alongside(), "the empty berth has no contract ships over its corridor (RT-07 and the barge come with a contract)")
	var src := FileAccess.get_file_as_string("res://scripts/port_art.gd")
	check(src.find("pit cranes between the berths (parked") < 0, "no idle pit cranes on the quay")
	await _shot(c + PortArt.district_at("salvage") * m + Vector2(-60, -10) * m, 0.3, "exterior_salvage_zh")
	g.cam_override = null
	g.zoom_override = -1.0
	g.queue_free()
	await _frames(4)
	print("EXTERIOR %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
