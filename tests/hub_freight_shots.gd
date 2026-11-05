extends "res://tests/guide_check.gd"
# 130 号: the freight trains, for the eye. A new port (one train); the mended port with the demo flow:
# the whole hub with several trains running, a wagon's rollers pushing a crate into a hatch, an arm
# loading, the card over a train.
#   tools/run_test.sh tests/hub_freight_shots.gd --fixed-fps 60 -- tag=after
const W = preload("res://scripts/hub_works.gd")
const FW = preload("res://scripts/freight_works.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_hub_freight_shots_career.json"
	SaveGame.path = "user://zp_test_hub_freight_shots_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _put(at: Vector2, zoom: float) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom


func _shot(name: String, at: Vector2, zoom: float, wait := 3) -> void:
	_put(at, zoom)
	await _frames(wait)
	_put(at, zoom)
	await _frames(1)
	var p := "res://tests/out/hub130_%s_%s.png" % [name, _arg("tag", "after")]
	Cap.save(root, p)
	print("  shot " + ProjectSettings.globalize_path(p))


func _moving() -> int:
	var n := 0
	for tr in FW.trains:
		if tr.moving:
			n += 1
	return n


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 0, "trade": 0, "process": 0, "power": 0, "cargo": 0, "tug": 0, "ring": 0}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	var st: Dictionary = Career.data.exchange.actors.company.stock
	st["ferrous_scrap:1"] = 3.0
	st["steel_billet:1"] = 2.5
	st["steel_plate:1"] = 1.6
	# a few machines in the warehouse, for the cages' line art
	Career.data.goods = [{"uid": "t1", "cat": "equip", "ship": "cf90", "tag": "CON-N", "nk": "p_cockpit_console", "name": "驾驶台", "value": 900.0, "mass": 0.4},
		{"uid": "t2", "cat": "equip", "ship": "cl104", "tag": "CH-1", "nk": "p_chiller", "name": "冷水机", "value": 2400.0, "mass": 1.2}]
	Career.save()
	await _spawn()
	await _frames(10)
	var c := PortStructure.centre()
	var M := PortStructure.M()
	g.drone.global_position = c + Vector2(-14.0, -17.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	# the cards follow a probe, never the real pointer (it may be anywhere on the user's screen)
	var far := Vector2(-1e7, -1e7)
	g.freight.card.probe = far
	if g.port_structure != null and g.port_structure.get("interiors") != null and g.port_structure.interiors.get("card") != null:
		g.port_structure.interiors.card.probe = far
	# a new port: one train, running a real shipment straight across (the ring dead)
	Career.data.port.cargo = 1
	FW._base = 0.5
	for i in 60 * 40:
		await _frames(1)
		if _moving() >= 1 and i > 60 * 6 and FW.trains[0].speed > 4.0 * M:
			break
	print("  start: %d train(s)" % FW.trains.size())
	await _shot("start_one_train", FW.behind(FW.trains[0], 4.0 * M), 0.5, 1)
	await _shot("start_hall", c, 0.32, 1)
	# the port mended, the demo flow on
	Career.data.port = {"salvage": 2, "trade": 2, "process": 2, "power": 2, "cargo": 2, "tug": 2, "ring": 2}
	W.demo = true
	var got_busy := false
	var got_push := false
	var got_arm := false
	for i in 60 * 240:
		await _frames(1)
		if not got_busy and _moving() >= 2 and i > 60 * 20:
			got_busy = true
			await _shot("busy_hall", c, 0.32)
			await _shot("busy_hub", c, 0.55)
		if not got_push:
			for tr in FW.trains:
				var pa := FW.push_at(tr)
				if not pa.is_empty() and float(pa[2]) > 0.35 and float(pa[2]) < 0.65:
					got_push = true
					await _shot("push", (pa[0] as Vector2).lerp(pa[1], 0.5), 1.2, 2)
					break
		if not got_arm and i > 60 * 30:
			for z in W.arms:
				if W.arms[z].parcel != null and str(W.arms[z].phase) in ["to_cradle", "lift_hatch"]:
					got_arm = true
					await _shot("arm", c + W.hatch_at(z).lerp(W.cradle_at(0, W.slot_angle(z)), 0.4) * M, 1.0, 2)
					break
		if got_busy and got_push and got_arm:
			break
	# 130 号 review: the hub view three times, 5 s apart — freight moving in each, arms moving
	var view_c := c
	var view_z := 0.4
	var half: Vector2 = Vector2(1920.0, 1080.0) * 0.5 / (view_z)
	var in_view := func(p: Vector2) -> bool: return absf(p.x - view_c.x) < half.x and absf(p.y - view_c.y) < half.y
	var counts: Array = []
	for i in 60 * 120:
		await _frames(1)
		var mv := 0
		for tr in FW.trains:
			if tr.moving and in_view.call(tr.pos):
				mv += 1
		if mv >= 2:
			break
	for k in 3:
		var mv2 := 0
		for tr in FW.trains:
			if tr.moving and in_view.call(tr.pos):
				mv2 += 1
		var arms := 0
		for z in W.arms:
			if str(W.arms[z].phase) != "park":
				arms += 1
		counts.append([mv2, arms])
		var hst := []
		for z in W.arms:
			var hz: Dictionary = W._hatch(z)
			hst.append("%s:%s/%s hatch=%s" % [z, W.arms[z].phase, W.arms[z].task, "-" if hz.parcel == null else str(hz.parcel.at)])
		var pz := []
		for pp in W.parcels:
			pz.append("%s>%s@%s" % [pp.from, pp.to, pp.at])
		print("    hub: parcels %d queue %d %s theta=%.2f target=%.2f dwell=%.1f" % [W.parcels.size(), FW.queue.size(), hst, W.theta, W.target, W.dwell])
		print("      %s" % str(pz))
		await _shot("hub_seq%d" % (k + 1), view_c, view_z, 1)
		await _frames(60 * 5 - 4)
	print("  hub view, 5 s apart: [freight moving in view, arms working] %s" % str(counts))
	# the dispatching drawn (developer view): who holds which track, the shuttle's wanted track
	FW.show_blocks = true
	await _shot("blocks", view_c, view_z, 1)
	FW.show_blocks = false
	# the cargo district's freight line through its warehouse floor, close up
	# (the drone inside the district: its floor and racks are drawn only then)
	var cl_at: Vector2 = FW.ext_end("cargo").lerp(Tram.station_at("cargo"), 0.5)
	g.drone.global_position = cl_at + Vector2(0.0, -3.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(30)
	await _shot("cargo_line", cl_at, 1.1, 3)
	# the drone standing by the cargo district's shuttle stop: the freight keeps running (it gives way only
	# when the shuttle is called)
	var sp := Tram.station_at("cargo")
	g.drone.global_position = sp + Tram.platform_side("cargo") * 2.0 * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	var got_near := false
	for i in 60 * 120:
		await _frames(1)
		var t0: Dictionary = FW.trains[0]
		if t0.moving and (t0.pos as Vector2).distance_to(sp) < 22.0 * M:
			got_near = true
			await _shot("near_stop", sp.lerp(t0.pos, 0.4), 0.8, 1)
			break
	print("  near stop: freight moving past the drone %s" % got_near)
	# the card over a train (the pointer stood in for by a probe: the mouse is never moved)
	var tr0: Dictionary = FW.trains[0]
	for tr in FW.trains:
		if tr.moving or not (tr.step as Dictionary).is_empty():
			tr0 = tr
			break
	var fv = g.freight
	fv.card.probe = FW.cars(tr0)[1][0]
	_put(fv.card.probe, 0.9)
	for i in 50:
		fv.card.probe = FW.cars(tr0)[1][0]
		g.cam_override = fv.card.probe
		await _frames(1)
	await _shot("card", fv.card.probe, 0.9, 1)
	print("  moments: busy %s push %s arm %s; pushed %d taken %d delivered %d" % [got_busy, got_push, got_arm, FW.pushed, FW.taken, FW.delivered])
	W.demo = false
	g.queue_free()
	await _frames(4)
	quit(0)
