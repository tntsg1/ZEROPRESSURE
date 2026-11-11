extends "res://tests/guide_check.gd"
# The berth's gas recovery receiver follows the berth (2026-11-11, user: "这个收集液体的东西，它没有随着我
# 舱室的变大而变大"): for a 48 m, 88 m, 118 m and 185 m ship (each with the berth its career would have
# bought) the receiver set — drums, plinth, header — and its run up the tower and along the boom stay
# clear of the berth's working space (Dock.BOUNDS), the ship's every piece (where it lies and where it
# slides in from), the tower, the terminals and the parts rack, and the crane's rail; and a bigger
# berth has a bigger receiver. Shots (not headless): the docking, the berth stripping, the empty berth.
#   tools/run_test.sh tests/recv_berth_check.gd --fixed-fps 60 [-- ships=my48,bl88 shots=1]

const GP = preload("res://scripts/gas_pipes.gd")
# each with the berths its career must have bought to take it (Dock.needs: a ship takes a tier 6 m longer)
const CASES := [["my48", ["berth88"], 0], ["bl88", ["berth88", "berth120"], 1], ["fl116", ["berth88", "berth120", "berth200"], 2], ["tb180", ["berth88", "berth120", "berth200"], 2]]


func _initialize() -> void:
	Career.path = "user://zp_test_recv_berth_career.json"
	SaveGame.path = "user://zp_test_recv_berth_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _career(ups: Array, berth_now: float) -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 2, "power": 1, "cargo": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"port_walk_started": true, "belt_prelude": true, "first_ship": true, "intro": true, "gas_flow_film": true}
	Career.data.prologue_done = true
	Career.data.exchange = preload("res://scripts/industrial_exchange.gd").fresh(500000.0)
	Career.data.upgrades = {"gas_line": true, "lox_tank": true}
	for u in ups:
		Career.data.upgrades[u] = true
	if berth_now > 0.0:
		Career.data.berth_now = berth_now
	Career.save()


# the receiver set and its run in world px: [what, rect]
func _parts(gp) -> Array:
	var out := []
	var o: Vector2 = gp._o
	var m: float = gp._m
	var wr := func(r: Rect2) -> Rect2: return Rect2(o + r.position * m, r.size * m)
	for d in gp.recv:
		out.append(["drum", wr.call(d)])
	out.append(["plinth", wr.call(gp.plinth)])
	# the header from the tower's foot on (its first metre is inside the foot, as it is meant to be)
	var hp: Array = gp.h_path
	for i in range(1, hp.size()):
		out.append(["header", wr.call(Rect2(hp[i - 1], Vector2.ZERO).expand(hp[i]).grow(0.25))])
	# the run, as far as the port's fixed run (G_TAIL) starts: up the tower, along the boom
	var gpp: Array = gp.g_path
	for i in range(1, gpp.size()):
		if gpp[i - 1] == GP.G_TAIL[0]:
			break
		out.append(["run", wr.call(Rect2(gpp[i - 1], Vector2.ZERO).expand(gpp[i]).grow(GP.G_W * 0.5))])
	return out


func _check_case(gp, label: String, ship_rects: Array) -> void:
	var M := Geom.M
	var bounds := Rect2(Dock.BOUNDS.position * M, Dock.BOUNDS.size * M)
	var tower := Rect2(Vector2(Dock.TOWER_X, Dock.RAIL_Y - 2.6) * M, Vector2(0.6, Dock.FLOOR_Y - Dock.RAIL_Y + 2.6) * M)
	var consoles := []
	for i in Consoles.SPOTS.size():
		consoles.append(Rect2(Consoles.centre(i), Vector2.ZERO).grow(1.2 * M))
	consoles.append(Rect2(Consoles.RACK * M, Consoles.RACK_SIZE * M))
	consoles.append(Rect2(Consoles.kiosk_at(), Vector2.ZERO).grow(1.0 * M))
	# the parts store standing on the quay to the left, and the quay truss (port_art _salvage)
	var store := Rect2(Vector2(-68.0, -16.0) * M, Vector2(50.0, Dock.FLOOR_Y + 19.0) * M)
	var quay := Rect2(Vector2(-70.0, Dock.FLOOR_Y + GP.QUAY_DOWN) * M, Vector2(Dock.FLOOR_X1 + 195.0, 4.0) * M)
	var crane := Rect2(Vector2(Dock.TOWER_X, Crane.rail_y() / M - 0.4) * M, Vector2(Dock.FLOOR_X1 - Dock.TOWER_X, 0.8) * M)
	var hits := []
	for pr in _parts(gp):
		var r: Rect2 = (pr[1] as Rect2).grow(-0.05 * M)    # standing on a thing is not overlapping it
		if r.intersects(bounds):
			hits.append("%s×船坞作业区" % pr[0])
		if pr[0] != "header" and r.intersects(tower):
			hits.append("%s×塔架" % pr[0])
		for c in consoles:
			if r.intersects(c):
				hits.append("%s×终端/零件架" % pr[0])
		if r.intersects(store):
			hits.append("%s×零件库" % pr[0])
		if r.intersects(quay):
			hits.append("%s×码头桁架" % pr[0])
		if r.intersects(crane):
			hits.append("%s×吊车轨" % pr[0])
		for s in ship_rects:
			if r.intersects(s):
				hits.append("%s×船体" % pr[0])
				break
	check(hits.is_empty(), "%s: the receiver set (%d drum%s) and its run clear of the berth, the ship (%d pieces, lying and sliding in), tower, terminals, crane %s" % [label, gp.recv.size(), "s" if gp.recv.size() > 1 else "", ship_rects.size(), str(hits) if not hits.is_empty() else ""])
	# it stands by the berth's fixed end, on the quay truss: the plinth's underside on the truss's top
	var d0: Rect2 = _parts(gp)[0][1]
	var pl: Rect2 = Rect2(gp._o + gp.plinth.position * gp._m, gp.plinth.size * gp._m)
	check(absf(d0.end.x - (Dock.TOWER_X - GP.RECV_OUT) * M) < 2.0 and absf(pl.end.y - (Dock.FLOOR_Y + GP.QUAY_DOWN) * M) < 2.0 and d0.position.x > GP.STORE_X1 * M, "%s: the receiver stands on the quay truss between the parts store and the tower (drum %.1f..%.1f m, plinth on %.1f m; quay top %.1f m)" % [label, d0.position.x / M, d0.end.x / M, pl.end.y / M, Dock.FLOOR_Y + GP.QUAY_DOWN])


func _shot(name: String, at: Vector2, zoom_px_m: float) -> void:
	if DisplayServer.get_name() == "headless" or _arg("shots", "1") != "1":
		return
	g.cam_override = at
	g.zoom_override = zoom_px_m / Geom.M
	g.cam_pos = at
	g.zoom_now = g.zoom_override
	await _frames(20)
	Cap.save(root, "res://tests/out/recvberth_%s.png" % name)


func _run() -> void:
	var only := _arg("ships", "")
	var sizes := {}
	for cs in CASES:
		var id: String = cs[0]
		if only != "" and not only.split(",").has(id):
			continue
		var ups: Array = cs[1]
		var want_tier: int = cs[2]
		# --- the ship coming in, then stripped
		_career(ups, 0.0)
		Game.contract = {"id": "RB-" + id, "ship": id}
		Game.start_ship = id
		SaveGame.load_requested = false
		g = load("res://scenes/main.tscn").instantiate()
		var kit := {}
		for u in ups:
			kit[u] = true
		g.bot = {"skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
		root.add_child(g)
		await _frames(3)
		var gp = g.gas_works.pipes if g.gas_works != null else null
		check(gp != null, "%s: the gas works and its pipes are up" % id)
		if gp == null:
			g.queue_free()
			await _frames(5)
			continue
		gp._layout()
		check(GP.recv_tier(g) == want_tier, "%s: berth %.0f m (paid for %.0f m) gets receiver size %d (want %d)" % [id, Dock.floor_end, Dock.owned(g._upgrades_for_berth()), GP.recv_tier(g), want_tier])
		sizes[id] = [gp.recv.size(), (gp.recv[0] as Rect2).size]
		var M := Geom.M
		var c := Rect2(Dock.BOUNDS.position * M, Dock.BOUNDS.size * M).get_center()
		var rc: Vector2 = gp._o + gp.recv_rect().get_center() * gp._m
		# the docking: the hull slides in from the right of the berth (world.position runs ship_offset → 0)
		var ship_rects := []
		for q in g.world.pieces.values():
			var bb := Geom.bbox(g.world.world_poly(q))
			# (world_poly is in the world node's frame: where the piece lies once docked)
			ship_rects.append(Rect2(bb.position + Vector2(g.ship_offset, 0.0), bb.size).merge(bb))
		await _frames(30)
		await _shot("%s_arrive" % id, Vector2(rc.x + 30.0 * M, rc.y - 14.0 * M), 6.0)
		var w := 0
		while str(g.state) != "play" and w < 60 * 20:
			await process_frame
			w += 1
		gp._layout()
		_check_case(gp, "%s %.0f m stripping" % [id, Dock.floor_end], ship_rects)
		await _shot("%s_strip_near" % id, rc + Vector2(8.0, -6.0) * M, 12.0)
		await _shot("%s_strip_wide" % id, Vector2(lerpf(rc.x, c.x, 0.5), rc.y - 14.0 * M), 3.5)
		var flen := Dock.floor_end
		g.queue_free()
		await _frames(5)
		# --- the empty berth as the contract left it
		_career(ups, flen)
		Game.contract = {}
		Game.start_ship = "berth"
		g = load("res://scenes/main.tscn").instantiate()
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(g)
		await _frames(30)
		gp = g.gas_works.pipes if g.gas_works != null else null
		if gp != null:
			gp._layout()
			_check_case(gp, "%s empty berth %.0f m" % [id, Dock.floor_end], [])
			var rc2: Vector2 = gp._o + gp.recv_rect().get_center() * gp._m
			await _shot("%s_empty" % id, Vector2(rc2.x + 22.0 * Geom.M, rc2.y - 12.0 * Geom.M), 5.0)
		g.queue_free()
		await _frames(5)
	if sizes.has("my48") and sizes.has("tb180"):
		check(int(sizes.tb180[0]) > int(sizes.my48[0]) and (sizes.fl116[1] as Vector2).x > (sizes.my48[1] as Vector2).x if sizes.has("fl116") else true, "bigger berths, bigger receivers: %s" % str(sizes))
	print("RECV BERTH %s (%d of %d)" % ["PASS" if fails == 0 else "FAIL", checks - fails, checks])
	quit(1 if fails > 0 else 0)
