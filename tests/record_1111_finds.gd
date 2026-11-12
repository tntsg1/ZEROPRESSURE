extends "res://tests/record_1111_clean.gd"
# Video (2026-11-11, 认真拆有奖励 stages 3 and 5): GR-7 — the meter finds a spares box in the pump, the
# wrench opens the cover once it is drained, the box goes into the equipment mouth clean; the battery's
# charge fed back into the port over the lead; with the machines on (J) the hauler brings the charged
# NAV unit and the 1.8 MPa bottle and the drain rack beside the mouth empties them first. Test saves only.
#   tools/run_test.sh tests/record_1111_finds.gd --write-movie G:/temp/zp_rec_20261110/finds1111.avi --fixed-fps 60
#   python tools/rec_1110.py cut finds_1111 - finds1111


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "gr7"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	var face: Vector2 = Dock.ZONES.equip.face
	var mouth: Vector2 = Dock.zpos("equip")
	var side := Vector2(-face.y, face.x)
	var park := mouth + face * 13.0 * M
	var bodies := {}
	var i := 0
	for t in ["CP-E", "B-01", "NAV-01", "TK-B2"]:
		var p = g.world.tag(t)
		if p == null:
			print("missing ", t)
			continue
		bodies[t] = await _loose(p, park + side * (i - 1.5) * 3.2 * M)
		i += 1
	# the pump, staged: water in it (GR-7 carries none) and a spares box behind its cover
	g.sys.fvol["demo_water"] = {"fluid": "water", "amount": 0.2, "piece": "CP-E", "full": 0.2}
	g.clean._snapshot()
	var pump = g.world.tag("CP-E")
	g.finds.traits[str(pump.id)] = {"type": "spare", "revealed": false, "opened": false, "ruined": false, "worth": 900.0, "maker": "MAKER-A"}
	await _frames(40)
	# ---- 1. the meter, the ✦, the cover
	var pb = bodies["CP-E"]
	var spot := mouth + face * 6.5 * M - side * 2.0 * M
	pb.global_position = spot
	pb.reset_physics_interpolation()
	g.drone.global_position = spot + Vector2(-2.6, -1.4) * M
	g.drone.linear_velocity = Vector2.ZERO
	hold_at = spot + Vector2(-0.8, -0.6) * M
	zoom = 2.4
	await _frames(30)
	kit.keep(true, "测量：发现泵里藏着备件匣")
	var at: Vector2 = g.world.frame(pump) * Geom.centroid(pump.poly)
	g.tools.tool = 1
	await _frames(20)
	g.do_measure({"kind": "inspect", "piece": pump, "pos": at})
	await _frames(100)
	kit.keep(false)
	kit.keep(true, "还有水，盖子打不开；先排液再开盖")
	g.tools.tool = 4
	g.do_wrench({"kind": "lid", "piece": pump, "pos": at})
	await _frames(70)
	# drained (as the hose would), then the cover
	g.sys.set_fluid("demo_water", 0.0)
	g.sfx.play("pump_loop")
	await _frames(30)
	g.do_wrench({"kind": "lid", "piece": pump, "pos": at})
	await _frames(70)
	kit.keep(false)
	kit.keep(true, "备件匣干净送进设备口")
	var box = g.world.pieces[g.world.order[g.world.order.size() - 1]]
	if box.body != null:
		box.body.global_position = mouth + face * 2.6 * M
		box.body.reset_physics_interpolation()
		box.body.linear_velocity = -face * 60.0
	hold_at = mouth + face * 2.4 * M
	await _wait_gone(box, 240)
	await _frames(60)
	kit.keep(false)
	# ---- 2. the battery's charge, fed back
	var bb = bodies["B-01"]
	var bspot := mouth + face * 6.0 * M + side * 2.5 * M
	bb.global_position = bspot
	bb.reset_physics_interpolation()
	g.drone.global_position = bspot + Vector2(-2.4, -1.6) * M
	g.drone.linear_velocity = Vector2.ZERO
	hold_at = bspot + Vector2(-1.0, -0.6) * M
	zoom = 2.2
	await _frames(30)
	kit.keep(true, "电池接回馈线：余电充进港区电网")
	g.tools.tool = 5
	g.do_hose({"kind": "batt", "piece": g.world.tag("B-01"), "pos": bspot})
	for k in 420:
		await process_frame
		if not g.clean.feeds.has("B-01") and k > 60:
			break
	await _frames(80)
	kit.keep(false)
	# ---- 3. the machines on: the hauler brings what still holds something to the drain rack
	var hl := Hauler.new()
	hl.game = g
	hl.process_mode = Node.PROCESS_MODE_PAUSABLE
	g.add_child(hl)
	g.hauler = hl
	g.auto_paused = false
	g.drone.global_position = mouth + face * 9.0 * M + side * 9.0 * M
	for t in ["NAV-01", "TK-B2"]:
		bodies[t].freeze = false
	hold_at = mouth + face * 3.0 * M + side * 2.0 * M
	zoom = 1.5
	kit.keep(true, "开着 J：搬运无人机把带电、带压的件送上泄放架，泄完再收")
	var nav = g.world.tag("NAV-01")
	var tk = g.world.tag("TK-B2")
	for k in 60 * 40:
		await process_frame
		if nav.gone and tk.gone:
			break
	await _frames(60)
	kit.keep(false)
	print("REC clean=%d best=%d mishaps=%d drained=%d batt=%.3f MWh finds=%d" % [g.clean.clean_n, g.clean.best, g.clean.mishaps.size(), g.clean.drained_ids.size(), g.clean.batt_mwh, g.finds.found.size()])
	await _frames(10)
	quit(0)
