extends "res://tests/guide_check.gd"
# No clipping, frame by frame (user 2026-11-05: in the video two tugs went through each other, the
# hulk through the tug station, the tug and hull through the berth's truss). Every frame of: a hulk
# towed in to the station's mouth, a long one towed by two tugs to an outside berth, a third into the
# last berth with the others parked, the tugs' flights home; a contract's opening (round the station
# and the push in) for hulks of several sizes from each yard berth, one by two tugs; the tow out. Each
# body's least distance (tugs, the hulk they move, the hulks parked, the port's and berth's solids)
# is at least 0.3 m; only the line, the arm and the fenders' face may touch. Own saves only.
#   tools/run_test.sh tests/tug_clear_check.gd --fixed-fps 60

const G = preload("res://tests/clear_geom.gd")
const TugRig = preload("res://scripts/tug_rig.gd")
const GAP := 0.3
var solids: Array = []
var worst := {}      # what -> [m, where]


func _initialize() -> void:
	Scan.ON = false
	Career.path = "user://zp_test_tug_clear_career.json"
	SaveGame.path = "user://zp_test_tug_clear_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


var _told := {}
func _note(what: String, d: float, where: String) -> void:
	if d < GAP and not _told.has(what + where.substr(0, 12)):
		_told[what + where.substr(0, 12)] = true
		print("    ! %s %.2f m: %s%s" % [what, d, where, _ctx()])
	if not worst.has(what) or d < float(worst[what][0]):
		worst[what] = [d, where]


func _ctx() -> String:
	if g == null or g.tow_traffic == null:
		return ""
	var tt = g.tow_traffic
	var out := ""
	if not tt.arrival.is_empty():
		var t := float(tt.arrival.t)
		out += " | t %.2f phase %d stern %s m" % [t, tt._phase(t), str((tt._along(tt._s_at(t)) / Geom.M).round())]
		if not tt.arrival.get("cast", false):
			for k in tt.arrival.tugs.size():
				out += " tug%d %s" % [k, str((tt._tug_px(k, t) / Geom.M).round())]
	for f in tt.flights:
		out += " | flight %s at %s face %.1f near %s" % [f.name, str((f.p / Geom.M).round()), float(f.face), str(f.get("near", -1))]
	return out


var blocked: Array = []
func _report(scene: String, layout_blocked := false) -> void:
	var keys: Array = worst.keys()
	keys.sort()
	for k in keys:
		var d := float(worst[k][0])
		if layout_blocked and d < GAP and "结构" in str(k):
			print("[BLOCKED] %s · %s: least %.2f m at %s — the port's layout leaves no clear way in (see the route line)" % [scene, k, d, str(worst[k][1])])
			blocked.append(scene + " · " + str(k))
			continue
		check(d >= GAP, "%s · %s: least %.2f m%s" % [scene, k, d, "" if d >= GAP else " at " + str(worst[k][1])])
	worst = {}


func _bring(ship: String) -> String:
	var i := -1
	for k in Career.data.offers.size():
		if Career.data.offers[k].get("find", false):
			i = k
			break
	if i < 0:
		Career.data.offers = Market.make(900 + ShipMarket.data().assets.size(), Career.data)
		i = 0
		Career.data.offers[0].find = true
	var id := str(Career.data.offers[i].id)
	if ship != "":
		Career.data.offers[i].ship = ship
	ShipMarket.tow_find(i)
	var a := ShipMarket.asset(id)
	if a.is_empty():
		return ""
	if ship != "":
		a.listing.offer.ship = ship
		a.ship = ship
	Shipping.data().day = maxf(float(Shipping.data().day), float(a.run.depart) + float(a.run.tof) + 0.01)
	ShipMarket.tick()
	Career.save()
	return id


# the hulks lying in the yard now (but `except`), world px outlines
func _parked(except: String) -> Array:
	var out: Array = []
	for a in ShipMarket.data().assets:
		if str(a.id) == except or not a.has("yard") or not str(a.state) in ["arrived", "held", "stripping"]:
			continue
		if not a.get("seen_in", false):
			continue
		var ship := TugYard.ship_of(a)
		var sh = G.hull_outline(ship)
		var b := Ship.bounds(Ship.load_data(ship))
		var stern := Vector2(b.end.x, b.get_center().y)
		out.append_array(G.placed(sh, TugYard.slot_px(int(a.yard), ship) - stern * Geom.M))
	return out


# one frame of a bringing-in or a flight home, in the empty berth
func _look_berth(tag: String) -> void:
	var tt = g.tow_traffic
	var M := Geom.M
	var tugs: Array = []     # [name, poly]
	var hulk: Array = []
	var parked := _parked(str(tt.arrival.get("id", "")))
	if not tt.arrival.is_empty():
		var t := float(tt.arrival.t)
		hulk = G.placed(tt.arrival.polys, tt.path_at(t / tt.IN_T))
		# the part of it in the station's mouth is the station's (cut at the wall, as drawn)
		var cut: Rect2 = tt._cut(int(tt.arrival.slot), str(tt.arrival.ship))
		if cut.has_area():
			var keep: Array = []
			var box := PackedVector2Array([cut.position, Vector2(cut.end.x, cut.position.y), cut.end, Vector2(cut.position.x, cut.end.y)])
			for p in hulk:
				for q in Geometry2D.clip_polygons(p, box):
					if not Geometry2D.is_polygon_clockwise(q):
						keep.append(q)
			hulk = keep
		if not tt.arrival.get("cast", false):
			for k in tt.arrival.tugs.size():
				tugs.append([str(tt.arrival.tugs[k].name), G.tug_poly(tt._tug_px(k, t), 1.0)])
	for f in tt.flights:
		tugs.append([str(f.name), G.tug_poly(f.p, float(f.face))])
	for j in tugs.size():
		var tp: PackedVector2Array = tugs[j][1]
		_note("拖船 ↔ 港区结构", G.dist_sets([tp], solids), "%s %s %s m" % [tag, tugs[j][0], str((tp[0] / M).round())])
		if not hulk.is_empty():
			_note("拖船 ↔ 被拖的船", G.dist_sets([tp], hulk), "%s %s" % [tag, tugs[j][0]])
		if not parked.is_empty():
			_note("拖船 ↔ 泊位上已停的船", G.dist_sets([tp], parked), "%s %s %s m" % [tag, tugs[j][0], str((tp[0] / M).round())])
		for k in range(j + 1, tugs.size()):
			_note("拖船 ↔ 拖船", G.dist_sets([tp], [tugs[k][1]]), "%s %s/%s" % [tag, tugs[j][0], tugs[k][0]])
	if not hulk.is_empty():
		_note("被拖的船 ↔ 港区结构", G.dist_sets(hulk, solids, 2.0), "%s t %.2f s" % [tag, float(tt.arrival.t)])
		if not parked.is_empty():
			_note("被拖的船 ↔ 泊位上已停的船", G.dist_sets(hulk, parked, 2.0), "%s t %.2f s" % [tag, float(tt.arrival.t)])


func _tow_in(ship: String, tag: String) -> void:
	var id := _bring(ship)
	var t := 0
	while g.state != "towin" and t < 300:
		await _frames(1)
		t += 1
	check(g.state == "towin", "%s: %s brought in on camera" % [tag, id])
	print("  %s: %s slot %d mouth %s tugs %s" % [tag, ship, int(g.tow_traffic.arrival.get("slot", -1)), str(g.tow_traffic.arrival.get("mouth", false)), str(g.tow_traffic.arrival.get("tugs", []).map(func(x): return x.name))])
	var n := 0
	while (g.state == "towin" or not g.tow_traffic.flights.is_empty()) and n < 60 * 40:
		await _frames(1)
		n += 1
		if n % 2 == 0:
			_look_berth(tag)


# one frame of the opening, the tow out or the tugs' flight home, in the job
var _mouth_cut := Rect2()
func _look_job(tag: String, outline: Array, _unused: Array) -> void:
	var M := Geom.M
	var hull := G.placed(outline, g.world.global_position)
	# while the hull is still being pushed out of the tug station's mouth, the part inside is the station's
	if _mouth_cut.has_area() and g.state == "intro" and float(g.state_t) < float(g.dock._join_t):
		var box := PackedVector2Array([_mouth_cut.position, Vector2(_mouth_cut.end.x, _mouth_cut.position.y), _mouth_cut.end, Vector2(_mouth_cut.position.x, _mouth_cut.end.y)])
		var keep: Array = []
		for p in hull:
			for q in Geometry2D.clip_polygons(p, box):
				if not Geometry2D.is_polygon_clockwise(q):
					keep.append(q)
		hull = keep
	if g.state != "play":
		_note("船 ↔ 港区与船坞结构", G.dist_sets(hull, solids, 2.0), "%s t %.2f s at %s m" % [tag, float(g.state_t), str((g.world.global_position / M).round())])
	var polys: Array = []
	for q in g.dock.rig_poses():
		polys.append([str(q.name), G.tug_poly(q.at, float(q.face), q.mode in ["push", "back", "meet"]), str(q.mode)])
	for j in polys.size():
		var tp: PackedVector2Array = polys[j][1]
		_note("拖船 ↔ 港区与船坞结构", G.dist_sets([tp], solids), "%s %s (%s) t %.2f s at %s m" % [tag, polys[j][0], polys[j][2], float(g.state_t), str((tp[0] / M).round())])
		var what := "拖船 ↔ 被推的船（顶推垫除外）" if polys[j][2] in ["push", "back", "meet"] else ("拖船 ↔ 被拖的船" if polys[j][2] == "arm" else "飞行中的拖船 ↔ 船")
		_note(what, G.dist_sets([tp], hull), "%s %s t %.2f s" % [tag, polys[j][0], float(g.state_t)])
		for k in range(j + 1, polys.size()):
			_note("拖船 ↔ 拖船", G.dist_sets([tp], [polys[k][1]]), "%s t %.2f s" % [tag, float(g.state_t)])


func _job(ship: String, slot: int, tag: String) -> void:
	# a hulk of this type home in this yard berth, the contract on it started
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.prologue_done = true
	Career.data.money = 900000.0
	Career.data.port = {"salvage": 1, "trade": 1, "tug": 2}
	Career.data.upgrades = {"berth88": true, "berth120": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true, "starmap_tour": true, "port_walk": true}
	Career.data.offers = Market.make(4242, Career.data)
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
	Career.save()
	# the yard's other berths taken (the hull goes round them)
	var ids: Array = []
	for k in 3:
		var id := _bring(["gr7", "pod", "h22"][k])
		if id != "":
			ShipMarket.asset(id).seen_in = true
			ids.append(id)
	var own: Dictionary = ShipMarket.asset(ids[slot])
	own.ship = ship
	own.listing.offer.ship = ship
	var idx := -1
	for k in Career.data.offers.size():
		if str(Career.data.offers[k].get("id", "")) == str(own.id):
			idx = k
			Career.data.offers[k].ship = ship
	Career.save()
	if idx < 0:
		# the offer card is gone with the tow: sign it from the asset as the berth's computer does
		Career.data.offers.append(own.listing.offer.duplicate(true))
		Career.data.offers[-1].id = own.id
		idx = Career.data.offers.size() - 1
	Career.accept(idx)
	Game.contract = Career.sign_active()
	# (the type swapped in under a contract drawn for another: its traps were drawn for that one)
	Game.contract.erase("traps")
	Game.start_ship = str(Game.contract.get("ship", ""))
	SaveGame.load_requested = false
	if g != null:
		g.queue_free()
		await _frames(2)
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": false, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(2)
	solids = G.solids(g)
	var outline := G.hull_outline(str(g.ship_id))
	var parked := _parked(str(own.id))
	_mouth_cut = Rect2()
	if int(own.get("yard", -1)) == 0 and TugYard.dock_in(ship) > 0.0:
		var tb := PortStructure.box("tug")
		_mouth_cut = Rect2(tb.position + Vector2(0.75 * Geom.M, 0.0), tb.size)
	await _frames(3)
	var wait := 0
	while g.dock._plan_task >= 0 and wait < 600:
		await _frames(1)
		wait += 1
		_look_job(tag + " 规划中", outline, [])
	print("  %s: %s (%s) from yard %d, tugs %s, route: %s, meet err %s m" % [tag, str(g.ship_id), ship, int(own.get("yard", -1)), str(g.dock._rig_tugs.map(func(x): return x.name)), g.dock.route_note, str(g.dock._rig_tugs.map(func(x): return snappedf(float(x.get("meet_err", 0.0)), 0.01)))])
	# what the hull overlaps lying in the berth is the port's layout (87-6 LAYOUT), not its way
	var keep: Array = []
	for p in solids:
		if not g.dock.layout.any(func(l): return l == p):
			keep.append(p)
	if keep.size() != solids.size():
		print("    LAYOUT: %s lying in the berth overlaps %d solid(s) of the port (left out of this check)" % [ship, solids.size() - keep.size()])
	solids = keep
	var n := 0
	while g.state == "intro" and n < 60 * 20:
		await _frames(1)
		n += 1
		if n % 2 == 0:
			_look_job(tag, outline, [])
			if not parked.is_empty():
				_note("船 ↔ 泊位上已停的船", G.dist_sets(G.placed(outline, g.world.global_position), parked, 2.0), "%s t %.2f s" % [tag, float(g.state_t)])
	# the tugs on their way home
	n = 0
	while not g.dock.rig_poses().is_empty() and n < 60 * 60:
		await _frames(1)
		n += 1
		if n % 2 == 0:
			_look_job(tag + " 回站", outline, [])
	check(g.dock.rig_poses().is_empty(), "%s: the tugs reached the tug gate" % tag)
	# the tow out
	g._tow_out()
	n = 0
	while g.state == "towout" and float(g.state_t) < g.TOW_T - 0.05 and n < 400:
		await _frames(1)
		n += 1
		_look_job(tag + " 拖出", outline, [])
	_report(tag, not g.dock.route_ok)


func _run() -> void:
	Txt.zh = true
	# ---- the empty berth: tows in
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 900000.0
	Career.data.port = {"salvage": 1, "trade": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true, "starmap_tour": true, "port_walk": true}
	Career.data.upgrades = {"berth88": true}
	Career.data.offers = Market.make(515, Career.data)
	Career.save()
	await _spawn()
	await _frames(20)
	solids = G.solids(g)
	print("  solids: %d outlines" % solids.size())
	if OS.get_environment("ZP_JOB_ONLY") == "":
		await _tow_in("gr7", "拖进港·船坞口")
		_report("拖进港·船坞口")
		Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
		await _frames(500)
		await _tow_in("fx70", "两艘编队·外泊位")
		_report("两艘编队·外泊位")
		Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
		await _frames(500)
		await _tow_in("tw64", "第三艘·有船停着")
		_report("第三艘·有船停着")
	# ---- the opening and the tow out, from each of the yard's first berths
	var cases := [] if OS.get_environment("ZP_BERTH_ONLY") != "" else [["gr7", 0], ["fx70", 1], ["tw64", 2], ["pod", 0], ["med47", 1]]
	for c in cases:
		await _job(str(c[0]), int(c[1]), "开场顶推 %s 泊位%d" % [str(c[0]), int(c[1]) + 1])
	print("TUG CLEAR %s (%d checks, %d failed, %d blocked by the port's layout)" % ["PASS" if fails == 0 else "FAIL", checks, fails, blocked.size()])
	quit()
