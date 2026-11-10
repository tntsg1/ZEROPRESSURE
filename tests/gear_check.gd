extends SceneTree
# G1 acceptance (design/G1_短循环设计稿_2026-10-21.md): the field gear.
#   A  the loadout: taken out of the warehouse at signing, a failed write spends
#      nothing; a probe put on a port by real input keeps its reading live; the
#      contract saved and read back keeps the unit, the carried list and the
#      drops; the probe taken back by input; the drone lost drops its modules
#      at the crash site, where the grapple picks them up by input; the early
#      end settles: what came back is on the shelf again.
#   B  the trial with the lent anchor: the anchor shot onto the hold's floor by
#      input; the floor band severed (every joint and line out of the band, as
#      the laser would); the winch hauls the ~10 t band into the trough and the
#      furnace takes it whole: Section Separated. The anchor is cast off at the
#      post and fetched by the grapple; settlement opens the anchor and puts one
#      on the shelf; the lent one goes back, not onto the shelf.
#   C  the trial with the lent pump: the hold's port shut off; the pump stuck
#      on a hold wall by input drains the room with no hose on; then on a
#      charged bottle; the pump taken back; the bot finishes the ship and the
#      drained bottle goes whole into the equipment bay: Pressure Equipment
#      Recovered. A pump left on a piece that goes down a mouth is lost at its
#      price; a lent one at no charge.
# Test files only; the player's career is never touched.
# godot --headless --path . --fixed-fps 60 -s tests/gear_check.gd

const Bot = preload("res://tests/salvage_bot.gd")
const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "warp": true}
var fails := 0
var checks := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_gear_career.json"
	SaveGame.path = "user://zp_test_gear_save.json"
	SaveGame.train_path = "user://zp_test_gear_training.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path, SaveGame.train_path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game() -> Node:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = BOT.duplicate()
	root.add_child(scene)
	return scene


# the operator's input: the drone put within reach, the tool chosen, the pointer on the
# spot and the button pressed, then the job's time to run
# (the drone is held on its spot for the job's time: a spot inside the hull would
# otherwise shove it out of reach before the job is done)
func _click(g, tool: int, at: Vector2, hold_frames: int = 70) -> void:
	g.tools.set_tool(tool, true)
	var spot := at + Vector2(-1.6 * Geom.M, -0.4 * Geom.M)
	for i in hold_frames + 5:
		g.drone.global_position = spot
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		if i == 2:
			g.bot.aim = at
			g.bot.lmb = true
		if i == 5:
			g.bot.lmb = false
		await process_frame


func _piece_center(g, p) -> Vector2:
	return g.world.frame(p) * Geom.centroid(p.poly)


func _wait(cond: Callable, limit: int) -> bool:
	for i in limit:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _run() -> void:
	print("GEAR: a career with gear on the shelf")
	Career.data = {}
	Career.start_new()
	var d := Career.data
	d.market = true
	d.done = 3
	d.money = 200000.0
	d.story_job = {}
	d.active = {}
	d.gear = {"probe": 1}
	Career.save()
	# ---- the loadout: a failed write spends nothing
	var good_path := Career.path
	Career.path = "user://"   # a directory: the write must fail
	var snap := JSON.stringify(Career.data, "", true)
	var why := Career.set_loadout([], {"probe": 1})
	check(why != "" and JSON.stringify(Career.data, "", true) == snap, "a loadout that cannot be written changes nothing (%s)" % why)
	Career.path = good_path
	why = Career.set_loadout([], {"probe": 1})
	check(why == "" and Career.data.loadout.mods.is_empty() and int(Career.data.loadout.deploy.probe) == 1, "the loadout saved: one probe")
	# ---- A: the trial contract, the probe
	var oa := Career.take_trial("g1a")
	check(not oa.is_empty() and oa.ship == "s09" and oa.trial == "g1a" and Career.active().id == oa.id, "trial A taken: %s" % str(oa.get("id", "")))
	var ga: Dictionary = Career.active().gear
	check(ga.mods.is_empty() and int(ga.deploy.get("probe", 0)) == 1 and ga.lent.is_empty(), "the job carries the loadout: %s" % str(ga))
	d = Career.data
	check(int(d.gear.probe) == 0, "the shelf is empty while it is out")
	Game.start_ship = oa.ship
	Game.contract = Career.active()
	var g = _game()
	await _frames(3)
	check(g.gear != null and g.gear.carried.size() == 1 and g.gear.mods.is_empty() and g.gear.in_hand() == "probe", "on site: one probe in hand")
	# a gas port in the open: the probe goes on it
	var port = null
	for id in g.world.ctrls:
		var c = g.world.ctrls[id]
		if c.kind == "port" and c.medium == "gas" and not g.world.room_hidden(c.hidden_room) and g.world.ctrl_alive(c) and g.sys.P(c.target) > 20.0:
			port = c
			break
	check(port != null, "a visible gas port to put the probe on: %s" % (port.id if port != null else "none"))
	var at: Vector2 = g.world.ctrl_world(port)
	await _click(g, 6, at)
	check(g.gear.units.size() == 1 and g.gear.units[0].type == "probe" and g.gear.carried.is_empty(), "the probe deployed by input on %s" % port.id)
	var key: String = port.id
	check(g.sys.readings.has(key) and g.sys.readings[key].get("live", false), "its reading is live")
	# the reading stays live while the room's pressure changes: vent it and see
	var r0: float = float(g.sys.readings[key].val)
	g.sys.vols[port.target].n *= 0.3
	await _frames(70)
	check(absf(float(g.sys.readings[key].val) - r0) > 1.0 and not g.sys.stale(g.sys.readings[key]), "the probe followed the change (%.0f -> %.0f) and the tag never went stale" % [r0, g.sys.readings[key].val])
	# saved and read back
	SaveGame.save(g)
	var carried_before: Array = g.gear.carried.duplicate(true)
	g.queue_free()
	await _frames(2)
	Career.data = {}
	Ship.clear_cache()
	Career.load_or_new()
	Game.contract = Career.active()
	Game.start_ship = Career.active().ship
	SaveGame.load_requested = true
	g = _game()
	await _frames(3)
	check(g.gear.units.size() == 1 and g.gear.units[0].type == "probe" and g.gear.units[0].ctrl == key and g.gear.carried == carried_before, "read back: the probe still on %s, the drone as it was" % key)
	check(g.sys.readings.has(key) and g.sys.readings[key].get("live", false), "read back: the reading is live again")
	# taken back by input
	at = g.world.ctrl_world(port)
	await _click(g, 6, at)
	check(g.gear.units.is_empty() and g.gear.carried.size() == 1 and not g.sys.readings[key].get("live", false), "the probe taken back by input; the reading is an ordinary one again")
	# the drone lost: three things drop; the grapple picks them up
	var crash: Vector2 = g.drone.global_position
	g.drone.hurt(1000.0, crash + Vector2(10, 0))
	await _frames(2)
	check(not g.drone.alive and g.gear.drops.size() == 1 and g.gear.carried.is_empty(), "the drone lost: %d thing dropped at the crash site" % g.gear.drops.size())
	await _wait(func(): return g.drone.alive, 400)
	check(g.drone.alive, "a replacement drone is out")
	var picked := 0
	for k in 3:
		if g.gear.drops.is_empty():
			break
		var dp: Vector2 = g.gear.drops[0].pos
		await _click(g, 3, dp, 10)
		picked += 1
	check(g.gear.drops.is_empty() and g.gear.carried.size() == 1, "picked up by the grapple (%d clicks)" % picked)
	# the early end: everything came back
	g.finish_contract(true)
	await _frames(5)
	var cr: Dictionary = g.career_result
	check(not cr.is_empty() and cr.gear.back.size() == 1 and cr.gear.lost.is_empty() and cr.gear.feats.is_empty(), "settled: the probe back, nothing lost: %s" % str(cr.gear))
	check(int(Career.data.gear.probe) == 1, "the shelf has it again")
	check(int(Career.data.trials.g1a) == 1 and Career.active().is_empty(), "trial A counted once")
	g.queue_free()
	await _frames(2)

	# ---- B: the lent anchor hauls the hold's floor band into the furnace
	print("GEAR: trial B, the anchor")
	Career.set_loadout([], {})
	var ob := Career.take_trial("g1b")
	check(not ob.is_empty() and ob.ship == "gr7" and int(Career.active().gear.lent.get("anchor", 0)) == 1, "trial B taken with an anchor lent")
	Game.start_ship = ob.ship
	Game.contract = Career.active()
	g = _game()
	await _frames(3)
	check(g.gear.carried.size() == 1 and g.gear.carried[0].type == "anchor" and g.gear.carried[0].lent, "the lent anchor is aboard")
	# the hold emptied first (a cut into a pressurised hold blows out: not what this is about)
	for room in ["B", "C"]:
		g.sys.vols[room].n = 0.0
	# the floor band cut out as the laser would: two strokes down through the hold's
	# lower shell at frames 12 and 25, then the fixings left between the band and the
	# rest undone (bolts by the wrench's handler, welds and lines as a cut would)
	var cuts := 0
	for xm in [12.0, 25.0]:
		var pl := PackedVector2Array([Vector2(xm, 2.6) * Geom.M, Vector2(xm, 4.4) * Geom.M])
		for id in g.world.order.duplicate():
			var p = g.world.pieces[id]
			if p.gone or p.body != null or p.cls != "metal":
				continue
			var bb := Geom.bbox(p.poly)
			if bb.position.y / Geom.M >= 2.6 and bb.position.x < xm * Geom.M and bb.end.x > xm * Geom.M:
				g.cut_kerf(p, pl)
				cuts += 1
		await _frames(2)
	var band: Array = []
	var band_m := 0.0
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.cls != "metal" or p.body != null:
			continue
		var bb := Geom.bbox(p.poly)
		if bb.position.x / Geom.M >= 12.0 and bb.end.x / Geom.M <= 25.0 and bb.position.y / Geom.M >= 2.6:
			band.append(p)
			band_m += p.mass
	check(cuts >= 4 and band.size() >= 3 and band_m >= Gear.SECTION_T, "the hold's floor band cut out: %d strokes, %d pieces, %.1f t" % [cuts, band.size(), band_m])
	# the anchor shot onto the band by input while it still hangs on its fixings
	var target = band[0]
	for p in band:
		if p.mass > target.mass:
			target = p
	var tc := _piece_center(g, target)
	await _click(g, 6, tc)
	check(g.gear.units.size() == 1 and g.gear.units[0].type == "anchor" and g.gear.units[0].piece == target.id and target.body == null, "the anchor on %s (%.1f t) by input, the band still fixed" % [target.tag if target.tag != "" else str(target.id), target.mass])
	# then the fixings left between the band and the rest
	var in_band := {}
	for p in band:
		in_band[p.id] = true
	var cut_j := 0
	for j in g.world.joints:
		if j.alive and (in_band.has(j.a) != in_band.has(j.b)):
			if j.type in ["bolt", "lock", "clamp"]:
				g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
			else:
				g.world.kill_joint(j)
			cut_j += 1
	for lid in g.world.lines.keys():
		var l = g.world.lines[lid]
		if l.alive and (in_band.has(l.a) != in_band.has(l.b)):
			g.world.kill_line(l)
	await _frames(3)
	var body = target.body
	check(body != null and body.total_mass() >= Gear.SECTION_T, "the band is free as one body (%d fixings undone, %.1f t)" % [cut_j, body.total_mass() if body != null else 0.0])
	check(g.gear.units.size() == 1 and g.gear.unit_pos(g.gear.units[0]).distance_to(_piece_center(g, target)) < 2.0 * Geom.M, "the anchor rides with the band as it comes loose")
	# 128 号 第 7 段: the achievement is gone — the band hauled into the furnace is all that counts
	var hauled := await _wait(func(): return target.gone, 2400)
	check(hauled and g.gear.feats_now.is_empty(), "the winch hauled the band into the furnace, no achievement (%s)" % str(g.gear.feats_now))
	check(g.gear.units.is_empty() and g.gear.drops.size() == 1 and g.gear.drops[0].type == "anchor", "the anchor cast off at the post")
	if not g.gear.drops.is_empty():
		await _click(g, 3, g.gear.drops[0].pos, 10)
	check(g.gear.drops.is_empty() and g.gear.carried.size() == 1 and g.gear.carried[0].type == "anchor", "the anchor fetched by the grapple")
	g.finish_contract(true)
	await _frames(5)
	cr = g.career_result
	check(cr.gear.feats.is_empty() and cr.gear.grants.is_empty() and cr.gear.back.is_empty() and cr.gear.lost.is_empty(), "settled: no achievement, no anchor given; the lent one back to the lender: %s" % str(cr.gear))
	check(not Career.data.get("feats", {}).has("section") and int(Career.data.gear.get("anchor", 0)) == 0, "the anchor comes with its method (the rigging order), not from this")
	g.queue_free()
	await _frames(2)

	# ---- C: the lent pump through a wall and on a bottle; the bot finishes
	print("GEAR: trial C, the pump")
	var oc := Career.take_trial("g1c")
	check(not oc.is_empty() and oc.traps == ["wrong_valve"] and int(Career.active().gear.lent.get("pump", 0)) == 1, "trial C taken: the hold's port shut off, a pump lent")
	Game.start_ship = oc.ship
	Game.contract = Career.active()
	g = _game()
	await _frames(3)
	var pc: float = g.sys.P("C")
	check(pc > 50.0 and not g.sys.on("V-C01"), "the hold holds %.0f kPa behind a shut valve" % pc)
	# a wall of the hold: a barrier piece whose middle lies within a metre of room C
	var wall = null
	var room_c = g.world.rooms["C"]
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or not p.barrier or p.body != null or p.cls != "metal":
			continue
		var c := _piece_center(g, p)
		var near := false
		for n in 8:
			if Geometry2D.is_point_in_polygon(c + Vector2.from_angle(TAU * n / 8.0) * 0.8 * Geom.M, room_c.poly):
				near = true
		if near and not g.world.hidden(c):
			wall = p
			break
	check(wall != null, "a wall of the hold in the open: %s" % (str(wall.id) if wall != null else "none"))
	await _click(g, 6, _piece_center(g, wall))
	var on_wall: bool = g.gear.units.size() == 1 and g.gear.units[0].type == "pump"
	var wall_vol: String = g.gear.units[0].vol if on_wall else ""
	check(on_wall and wall_vol in ["B", "C"] and g.sys.hoses.is_empty(), "the pump on the wall by input, drawing room %s, no hose anywhere" % wall_vol)
	var drained := await _wait(func(): return on_wall and g.sys.P(wall_vol) < 1.0, 1800)
	check(drained and g.sys.hoses.is_empty(), "the room drained through the wall: %.1f kPa, still no hose" % (g.sys.P(wall_vol) if on_wall else -1.0))
	if on_wall:
		await _click(g, 6, g.world.frame(wall) * g.gear.units[0].local)
	check(g.gear.units.is_empty() and g.gear.carried.size() == 1, "the pump taken back by input")
	# the bottle: in room B, opened for the test; the pump drains it with no hose
	g.world.reveal("B", _piece_center(g, g.world.tag("TK-B1")))
	await _frames(2)
	var bottle = g.world.tag("TK-B1")
	var p1: float = g.sys.P("T1")
	await _click(g, 6, _piece_center(g, bottle))
	var on_bottle: bool = g.gear.units.size() == 1 and g.gear.units[0].vol == "T1"
	check(on_bottle, "the pump on bottle TK-B1 (%.0f kPa) by input" % p1)
	var empty := await _wait(func(): return g.sys.P("T1") < 1.0, 2400)
	check(empty and g.sys.hoses.is_empty(), "the bottle drained with no hose: %.1f kPa" % g.sys.P("T1"))
	if on_bottle:
		await _click(g, 6, g.world.frame(bottle) * g.gear.units[0].local)
	check(g.gear.units.is_empty() and g.gear.carried.size() == 1, "the pump taken back")
	# the bot takes the ship apart; the drained bottle goes whole into the equipment bay
	var bot = Bot.new(g)
	var f := 0
	while not bot.step():
		f += 1
		await process_frame
	await _frames(5)
	var sum: Dictionary = bot.summary()
	print("  trial C: ", sum)
	check(sum.ended, "the bot finished trial C")
	cr = g.career_result
	check(cr.gear.feats.is_empty() and cr.gear.grants.is_empty(), "settled: no achievement, no pump given: %s" % str(cr.gear))
	check(not Career.data.get("feats", {}).has("pressure"), "the pump comes with its method (the GR-7 borrow job), not from this")
	# trial D below starts from a pump on the shelf (it was the achievement's gift before 128 号 第 7 段)
	Career.data.gear["pump"] = int(Career.data.gear.get("pump", 0)) + 1
	Career.save()
	g.queue_free()
	await _frames(2)

	# ---- D: a pump left on a bottle that goes down a mouth is lost; the berth's own at its price, a lent one free
	print("GEAR: a pump left on the piece")
	Career.set_loadout([], {"pump": 1})
	var od := Career.take_trial("g1c")
	check(int(Career.active().gear.deploy.get("pump", 0)) == 1 and int(Career.active().gear.lent.get("pump", 0)) == 1 and int(Career.data.gear.pump) == 0, "the berth's own pump and the lent one both aboard")
	Game.start_ship = od.ship
	Game.contract = Career.active()
	g = _game()
	await _frames(3)
	g.world.reveal("B", _piece_center(g, g.world.tag("TK-B1")))
	await _frames(2)
	bottle = g.world.tag("TK-B1")
	await _click(g, 6, _piece_center(g, bottle))
	var lent_first: bool = g.gear.units.size() == 1 and g.gear.units[0].lent
	check(lent_first, "the lent pump goes on first, the berth's own stays in hand")
	await _wait(func(): return g.sys.P("T1") < 1.0, 2400)
	# the bottle's fixings undone by the wrench's handler and the bottle fed to the bay by the grapple
	for j in g.world.joints_of(bottle):
		if j.alive:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	for l in g.world.lines_of(bottle):
		if l.alive:
			g.world.kill_line(l)
	await _frames(3)
	check(bottle.body != null, "the bottle is free")
	if bottle.body != null:
		bottle.body.global_position = Dock.zpos("equip") + Vector2(0, 1.4 * Geom.M)
		bottle.body.linear_velocity = Vector2(0, -60.0)
		bottle.body.reset_physics_interpolation()
	var gone := await _wait(func(): return bottle.gone, 600)
	check(gone and g.gear.units.is_empty() and g.gear.lost.size() == 1 and g.gear.lost[0].lent, "the bottle went into the bay with the lent pump on it: lost, lent")
	g.finish_contract(true)
	await _frames(5)
	cr = g.career_result
	check(cr.gear.lent_lost == ["pump"] and cr.gear.lost.is_empty() and cr.gear.back == ["pump"] and float(cr.gear.lost_cost) == 0.0, "settled: the lent pump lost at no charge, the berth's own back: %s" % str(cr.gear))
	check(int(Career.data.gear.pump) == 1, "the berth's pump is on the shelf again")
	g.queue_free()
	await _frames(2)
	print("GEAR %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	finished = true
