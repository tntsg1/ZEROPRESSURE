extends "res://tests/recoil_check.gd"
# The user's rulings on the codex audit (design/图鉴对标_审计_20261110.md, 用户定案), first batch:
#   1 the numbers: cryo jacket leak 10x, ARK-01's core 65 mSv/h at 7 m, every oxygen bottle
#     15 MPa and every CO₂ bottle 5.7 MPa, the hydraulic leak has its words
#   2 any loose piece brought up hard on the hull loses condition (no contact impulse needed),
#     no more than IMPACT_CAP in one knock
#   3 a cut tank later taken off the ship: its liquid still comes out of the kerf, not off
#     somewhere else (liquids.gd _slit_spot)
#   4 a supply water tank (bellows, 150 kPa) cut: the water comes out at the real flow
#   5 a hatch with air on one side and vacuum on the other, cut through: blown out of its
#     frame toward the vacuum; with the room vented first it only comes apart
#   6 the beam within 0.7 m of any pane (ARK-01, no glazing list in its file): it crazes;
#     1.5 m off it does not
#   7 a charged battery pierced (CV-138's chargers): thermal runaway, over 600 °C, venting
#     electrolyte vapour that burns in the air, the charger beside it goes too; a drained
#     one cut does nothing
#   8 flammability limits: hydrogen filling a closed room is too rich to light, a cylinder's
#     worth let into it mixes and lights, a wisp spread thin is too lean
#   9 a thin tank (ARK-01's water tank WT-1) drawn in a room with air: it buckles; drawn
#     with the room vented first: it holds
#  10 a pump left powered with the hose still drawing its line dry (HG-170's coolant pump):
#     smoke, then its seal goes at 30 s; powered down: nothing
#  11 a level gauge taken off a cryogenic tank still under its ullage (FR-26 LG-1 on T-1):
#     the socket sprays; the ullage vented first: nothing
#  12 a fire bottle taken off with the bus live (ARK-01): its solenoid fires it; bus dead: no
#  13 a thruster taken off live with propellant aboard (S-09 RCS-Q1): one short pulse kicks
#     it; bus dead: no
#  15 the measuring tool names a tank's liquid: hydraulic oil, coolant, water; never "water"
#     for what is not
#  16 HG-170's generator and intake compressor, the bus cut: they coast down; while they turn
#     the generator reads its remanence (tens of volts) and a cut bursts the rotor; stopped,
#     neither
#  17 a molecular pump (FX-70 VAC) taken off still turning: its casing is flung round
#  18 loaded beams cut through (DR-150 derrick leg, IC-120 saddle beam, OB-90 strut): the snap,
#     the parts ring and stay kinked, what is close is hit; a kerf that does not go through: no
#  14 a transformer on the live bus (ARK-01 XFMR-111): its high side reads 4.4 kV and a cut
#     into it arcs at that
# tools/run_test.sh tests/codex_match_check.gd [-- 2 3]   (writes tests/out/match_*.png)


func _initialize() -> void:
	SaveGame.path = "user://zp_test_match_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_match_career.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _shot_m(g, at: Vector2, zoom: float, name: String) -> void:
	g.cam_override = at
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom
	g.zoom_override = zoom
	await process_frame
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tests/out/match_%s.png" % name))
	print("  shot tests/out/match_%s.png" % name)


func _run() -> void:
	only = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	if _on(1):
		_m1()
	if _on(2):
		await _m2()
	if _on(3):
		await _m3()
	if _on(4):
		await _m4()
	if _on(5):
		await _m5()
	if _on(6):
		await _m6()
	if _on(7):
		await _m7()
	if _on(8):
		await _m8()
	if _on(9):
		await _m9()
	if _on(10):
		await _m10()
	if _on(11):
		await _m11()
	if _on(12):
		await _m12()
	if _on(13):
		await _m13()
	if _on(14):
		await _m14()
	if _on(15):
		await _m15()
	if _on(16):
		await _m16()
	if _on(17):
		await _m17()
	if _on(18):
		await _m18()
	print("match: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
	quit(1 if fails > 0 else 0)


func _m1() -> void:
	print("match: 1 the numbers")
	var C = load("res://scripts/cryo.gd")
	check(is_equal_approx(C.LEAK_LOST / C.LEAK, 10.0), "a lost jacket lets heat in 10 times as fast (%.4f / %.4f °C/s)" % [C.LEAK_LOST, C.LEAK])
	var ark: Dictionary = Ship.load_data("ark01")
	var r7: float = float(ark.reactor.rate) / 49.0
	check(r7 > 60.0 and r7 < 70.0, "ARK-01's core: %.1f mSv/h at 7 m" % r7)
	var bad := []
	var n := 0
	for f in DirAccess.get_files_at("res://ships/"):
		if not f.ends_with(".json"):
			continue
		var d: Dictionary = Ship.load_data(f.get_basename())
		var keys := {}
		for pd in d.get("pieces", []):
			keys[str(pd.get("key", ""))] = str(pd.get("name_key", ""))
		for k in d.get("gas", {}).get("vessels", {}):
			var v: Dictionary = d.gas.vessels[k]
			var nk: String = keys.get(str(v.get("piece", "")), "")
			var want := 0.0
			if nk in ["p_o2bottle", "p_o2_bottle"]:
				want = 15000.0
			elif nk == "p_co2_bottle":
				want = 5700.0
			if want > 0.0:
				n += 1
				if absf(float(v.get("kpa", 0.0)) - want) > 1.0:
					bad.append("%s %s %.0f" % [f, k, float(v.get("kpa", 0.0))])
	check(n >= 20 and bad.is_empty(), "%d oxygen/CO₂ bottles in the ship files at 15 / 5.7 MPa %s" % [n, bad])
	Txt.zh = true
	var zh: String = Txt.t("leak_hydraulic")
	Txt.zh = false
	var en: String = Txt.t("leak_hydraulic")
	check(zh == "液压管断了，液压油在往外漏。" and en == "Hydraulic line cut: oil is leaking out.", "the hydraulic leak has its words: %s / %s" % [zh, en])


# a plain piece of equipment, no gas or liquid in it
func _plain(g):
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or p.cls != "equip" or not p.intact:
			continue
		if p.fragile < 0.3 or g.sys.tank_vol(p) != "" or g.sys.fluid_in_piece(p) != "":
			continue
		var bb := Geom.bbox(p.poly)
		if bb.size.x > 2.5 * M or bb.size.y > 2.5 * M or bb.size.x < 0.6 * M:
			continue
		return p
	return null


func _m2() -> void:
	print("match: 2 a loose piece knocked on the hull loses condition, capped")
	var g = await _game("ch110")
	var p = _plain(g)
	check(p != null, "a plain piece of equipment: %s (fragile %.2f)" % [p.name_key if p != null else "-", p.fragile if p != null else 0.0])
	if p == null:
		await _done(g)
		return
	var sx: float = Geom.centroid(p.poly).x
	var at: Vector2 = _open_spot(g, sx, 2.5)
	var b = await _loose(g, p, at)
	check(b != null, "taken off, out over the hull")
	if b == null:
		await _done(g)
		return
	var c0: float = p.cond
	b.linear_velocity = Vector2(0, 9.0 * M)
	var first := -1.0
	var drops := 0
	var last: float = c0
	var low := 1.0
	for i in 120 * 2:
		await physics_frame
		if p.cond < last - 1e-6:
			drops += 1
			if first < 0.0:
				first = last - p.cond
				last = p.cond
				await _shot_m(g, b.global_position, 1.6, "impact")
		last = p.cond
	check(first > 0.0, "it hits the hull at 9 m/s and loses condition (%.1f%% the first knock, %d knocks)" % [first * 100.0, drops])
	check(first <= g.IMPACT_CAP + 1e-6 and c0 - last <= g.IMPACT_CAP * drops + 1e-6, "no more than %.0f%% a knock (%.1f%% in all)" % [g.IMPACT_CAP * 100.0, (c0 - last) * 100.0])
	await _done(g)


func _cut_tank(g, p) -> void:
	var c := _centre(g, p)
	var bb := Geom.bbox(g.world.world_poly(p))
	g.cut_kerf(p, PackedVector2Array([c - Vector2(bb.size.x * 0.3, 0), c + Vector2(bb.size.x * 0.3, 0)]))


func _leak_of(g, p):
	for lk in g.sys.leaks:
		if lk.get("piece") == p:
			return lk
	return null


func _m3() -> void:
	print("match: 3 a cut tank taken off the ship still lets its liquid out of the kerf")
	var g = await _game("ch110")
	var wt = _of(g, "p_water_tank")
	g.world.reveal(g.world.room_at(_centre(g, wt)), _centre(g, wt))
	_cut_tank(g, wt)
	await _frames(60)
	var lk = _leak_of(g, wt)
	check(lk != null and (lk.get("slit", []) as Array).size() >= 2, "the kerf is the opening")
	var at: Vector2 = _clear_spot(g, 4.0)
	var b = await _loose(g, wt, at)
	await _frames(90)
	var poly: PackedVector2Array = g.world.world_poly(wt) if b != null else PackedVector2Array()
	var bb := Geom.bbox(poly).grow(1.2 * M)
	var spot: Array = g.liquids._slit_spot(lk, g.leak_pos(lk), Vector2.UP) if lk != null else [Vector2.INF]
	var bulb_ok := false
	for k in (lk.get("_bulbs", {}) as Dictionary) if lk != null else {}:
		bulb_ok = bulb_ok or bb.has_point(lk._bulbs[k].pos)
	check(b != null and bb.has_point(spot[0]) and bb.has_point(g.leak_pos(lk)), "loose, the liquid wells up on its own kerf (%.1f m from the tank's middle)" % ((spot[0] as Vector2).distance_to(_centre(g, wt)) / M if b != null else -1.0))
	check(bulb_ok or g.liquids.count("water") > 0, "and the water is there, on the tank")
	await _shot_m(g, _centre(g, wt), 1.4, "slit_loose")
	await _done(g)


func _m4() -> void:
	print("match: 4 a supply water tank cut: the bellows pushes the water out")
	var g = await _game("ch110")
	var wt = _of(g, "p_water_tank")
	var fv: String = g.sys.fluid_in_piece(wt)
	var v0: float = g.sys.fluid(fv)
	g.world.reveal(g.world.room_at(_centre(g, wt)), _centre(g, wt))
	_cut_tank(g, wt)
	await _frames(120)
	var lk = _leak_of(g, wt)
	var vel: float = float(lk.get("v", 0.0)) if lk != null else 0.0
	var want := sqrt(2.0 * (150.0 - 101.0) * 1000.0 / 1000.0)
	check(absf(vel - want) < 1.5, "the jet: %.1f m/s (bellows 150 kPa against the room's 101: %.1f m/s)" % [vel, want])
	var q: float = (v0 - g.sys.fluid(fv)) / 2.0
	check(q > 0.02 and q < 0.08, "%.0f L/s out of the %.0f cm² kerf" % [q * 1000.0, float(lk.area) * 1e4 if lk != null else 0.0])
	check(g.liquids.count("water") > 3, "a chain of globules (%d)" % g.liquids.count("water"))
	await _shot_m(g, _centre(g, wt), 1.4, "water_tank")
	await _done(g)


func _m5() -> void:
	print("match: 5 a hatch cut through with a pressure difference across it is blown out")
	var g = await _game("ch110")
	var d = g.world.tag("HT-U1")
	var bb := Geom.bbox(g.world.world_poly(d))
	var c := bb.get_center()
	var tall: bool = bb.size.y >= bb.size.x
	var n := Vector2(1, 0) if tall else Vector2(0, 1)
	var half: float = (bb.size.x if tall else bb.size.y) * 0.5 + 0.5 * M
	var pa: float = g.recoil._kpa_at(c + n * half)
	var pb: float = g.recoil._kpa_at(c - n * half)
	var low: Vector2 = -n if pa > pb else n
	var room: String = g.world.room_at(c + n * half) if pa > pb else g.world.room_at(c - n * half)
	check(absf(pa - pb) > 50.0, "HT-U1: %.0f kPa one side, %.0f the other" % [pa, pb])
	g.world.reveal(room, c)
	# a kerf across it the short way, in the middle
	var ax: Vector2 = n
	var a: Vector2 = c - ax * half
	var b: Vector2 = c + ax * half
	g.cut_kerf(d, PackedVector2Array([a, b]))
	# its fastest, before it meets whatever is over the hull (the berth's truss, 4 m up)
	var v := Vector2.ZERO
	for i in 40:
		await physics_frame
		if d.body != null and d.body.linear_velocity.length() > v.length():
			v = d.body.linear_velocity
		if i == 14:
			await _shot_m(g, c + low * 1.5 * M, 1.3, "door_blown")
	check(g.incidents.any(func(e): return e[1] == "door_blown"), "the hatch is blown out of its frame")
	check(d.body != null and v.length() > 5.0 * M and v.normalized().dot(low) > 0.5, "it flies toward the vacuum at %.1f m/s (along %.2f)" % [v.length() / M, v.normalized().dot(low) if v.length() > 0.0 else 0.0])
	check(d.body != null and g.recoil.flying.has(d.body.get_instance_id()), "and it is dangerous to what it hits")
	await _done(g)
	# control: the room vented first (no difference): it only comes apart
	g = await _game("ch110")
	d = g.world.tag("HT-U1")
	g.sys.vols[room].n = 0.0
	await _frames(10)
	g.cut_kerf(d, PackedVector2Array([a, b]))
	await _frames(50)
	var v2: float = d.body.linear_velocity.length() / M if d.body != null else 0.0
	check(not g.incidents.any(func(e): return e[1] == "door_blown") and v2 < 2.0, "with the room at %.0f kPa it is not blown (%.1f m/s)" % [g.sys.P(room), v2])
	await _done(g)


# a piece other than a pane under a point
func _other_at(g, pt: Vector2, not_p):
	for q in g.world.pieces_at(pt):
		if q != not_p and not q.gone and q.body == null and not (q.art == "glass" and q.cls == "equip"):
			return q
	return null


# a short kerf on a neighbour of pane, d metres out from its edge
func _cut_near(g, pane, d: float) -> bool:
	var bb := Geom.bbox(g.world.world_poly(pane))
	var c := bb.get_center()
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var edge: float = absf((bb.size * 0.5).dot(dir))
		var pt: Vector2 = c + dir * (edge + d * M)
		var q = _other_at(g, pt, pane)
		if q != null:
			var t: Vector2 = dir.orthogonal() * 0.15 * M
			g.cut_kerf(q, PackedVector2Array([pt - t, pt + t]))
			return true
	return false


func _m6() -> void:
	print("match: 6 the beam near any pane crazes it (ARK-01 lists no glazing)")
	var g = await _game("ark01")
	check(not g.atmos.active(), "ARK-01 has no oxygen-hall config")
	var near = g.world.tag("GL-L2")
	var far = g.world.tag("GL-U4")
	check(near != null and far != null and g.atmos.panes().size() >= 12, "%d panes aboard" % g.atmos.panes().size())
	g.world.reveal(g.world.room_at(_centre(g, near)), _centre(g, near))
	var ok1: bool = _cut_near(g, near, 0.35)
	await _frames(4)
	await _shot_m(g, _centre(g, near), 2.0, "glass_craze")
	check(ok1 and near.cond <= 0.151, "cut 0.35 m off GL-L2: it crazes (condition %.2f)" % near.cond)
	check(g.incidents.any(func(e): return e[1] == "glass_craze"), "the craze is booked")
	var ok2: bool = _cut_near(g, far, 1.5)
	await _frames(4)
	check(ok2 and far.cond > 0.9, "cut 1.5 m off GL-U4: it holds (condition %.2f)" % far.cond)
	await _done(g)


func _m7() -> void:
	print("match: 7 a charged battery pierced runs away")
	var g = await _game("cv138")
	var a = g.world.tag("CHG-1")
	var nb = null
	var ab := Geom.bbox(g.world.world_poly(a)).grow(1.2 * M)
	for t in ["CHG-2", "CHG-3", "CHG-4", "CHG-5", "CHG-6"]:
		var q = g.world.tag(t)
		if q != null and ab.intersects(Geom.bbox(g.world.world_poly(q))):
			nb = q
			break
	check(a != null and nb != null, "CHG-1 and its neighbour %s (charge %.2f)" % [nb.tag if nb != null else "-", g.runaway.charge_of(a)])
	var c := _centre(g, a)
	g.world.reveal(g.world.room_at(c), c)
	var bb := Geom.bbox(g.world.world_poly(a))
	g.cut_kerf(a, PackedVector2Array([c - Vector2(bb.size.x * 0.25, 0), c + Vector2(bb.size.x * 0.25, 0)]))
	check(g.runaway.running(a), "pierced charged: thermal runaway")
	await _frames(120 * 3)
	var vap := 0.0
	for v in g.combustion.vapour:
		if v.look == "electrolyte":
			vap += float(v.kg)
	check(a.temp > 600.0, "it climbs to %.0f °C" % a.temp)
	check(vap > 0.0 or g.combustion.burnt_kg > 0.0, "venting electrolyte vapour (%.2f kg adrift, %.2f kg burnt)" % [vap, g.combustion.burnt_kg])
	await _shot_m(g, c, 1.6, "battery_runaway")
	await _frames(120 * 1)
	check(g.combustion.burnt_kg > 0.0, "the vapour burns in the room's air (%.2f kg)" % g.combustion.burnt_kg)
	check(nb != null and (g.runaway.running(nb) or nb.has_meta("runaway_done")), "the charger beside it catches it")
	await _frames(120 * 6)
	check(a.cond < 0.01 and a.has_meta("runaway_done"), "burnt out: the pack is scrap")
	await _done(g)
	# control: drained first
	g = await _game("cv138")
	a = g.world.tag("CHG-1")
	if g.sys.src.has(a.tag):
		g.sys.src[a.tag].charge = 0.0
	if g.sys.iso.has(a.tag):
		g.sys.iso[a.tag].charge = 0.0
	c = _centre(g, a)
	g.cut_kerf(a, PackedVector2Array([c - Vector2(bb.size.x * 0.25, 0), c + Vector2(bb.size.x * 0.25, 0)]))
	await _frames(60)
	check(not g.runaway.running(a) and a.temp < 100.0, "drained first: cut, nothing (%.0f °C)" % a.temp)
	await _done(g)


func _m8() -> void:
	print("match: 8 flammability limits")
	var g = await _game("ch110")
	var cb = g.combustion
	var room := "U2"
	var at: Vector2 = g.world.rooms[room].bbox.get_center()
	var vr: float = float(g.sys.vols[room].V)
	var pr: float = g.sys.P(room)
	check(pr > 90.0, "room U2: %.0f kPa, %.0f m³" % [pr, vr])
	# enough hydrogen to fill nine tenths of the closed room: too rich
	var kg_rich: float = 0.9 * vr * pr * 1000.0 / (8.314 * 293.0) * 0.002
	cb.vapour.append({"pos": at, "vel": Vector2.ZERO, "kg": kg_rich, "look": "lh2", "r": 0.6, "t": 0.0, "burn": -1.0, "ign": -1.0})
	var u: Dictionary = cb.vapour.back()
	var x0: float = cb.mix_frac(u)
	cb.spark(at, 1.0)
	await _frames(3)
	check(x0 > 0.75 and float(u.burn) < 0.0, "%.2f kg filling the room: %.0f%% hydrogen, over the 75%% upper limit: the spark does nothing" % [kg_rich, x0 * 100.0])
	cb.vapour.erase(u)
	# a cylinder's worth let out into the same room: it mixes into a flammable cloud
	cb.vapour.append({"pos": at, "vel": Vector2.ZERO, "kg": 0.05, "look": "lh2", "r": 0.6, "t": 0.0, "burn": -1.0, "ign": -1.0})
	var m: Dictionary = cb.vapour.back()
	var x1: float = cb.mix_frac(m)
	cb.spark(at, 1.0)
	await _frames(3)
	check(x1 > 0.04 and x1 < 0.75 and float(m.burn) >= 0.0, "50 g let out: %.1f%%, it lights" % (x1 * 100.0))
	await _shot_m(g, at, 1.2, "h2_limits")
	await _frames(60)
	# a wisp spread through 2 m: under the 4% lower limit
	cb.vapour.append({"pos": at, "vel": Vector2.ZERO, "kg": 0.002, "look": "lh2", "r": 2.0, "t": 0.0, "burn": -1.0, "ign": -1.0})
	var w: Dictionary = cb.vapour.back()
	var x2: float = cb.mix_frac(w)
	cb.spark(at, 2.5)
	await _frames(3)
	check(x2 < 0.04 and float(w.burn) < 0.0, "a wisp: %.2f%%, under the 4%% lower limit: it does not light" % (x2 * 100.0))
	await _done(g)


# every fixing undone, where it stands: what it does as it comes off (no teleport)
func _free(g, p) -> void:
	for l in g.world.lines_of(p).duplicate():
		g.world.kill_line(l, g.world.line_end_world(l, 0 if l.a == p.id else 1))
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	var w := 0
	while p.body == null and w < 30:
		await physics_frame
		w += 1


func _dead_bus(g) -> void:
	for t in g.sys.src_order:
		g.sys.drain_source(t)
		g.sys.stop_source(t)
	await _frames(10)


func _m9() -> void:
	print("match: 9 a thin tank drawn under the room's air buckles")
	for vent in [false, true]:
		var g = await _game("ark01")
		var t = g.world.tag("WT-1")
		var room: String = g.world.room_at(_centre(g, t))
		if vent:
			g.sys.vols[room].n = 0.0
			await _frames(30)
		var c = g.world.ctrls["PW-1"]
		g.world.reveal(room, _centre(g, t))
		g.do_hose({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})
		var a0: float = g.sys.fluid("wt1")
		for i in 120 * 4:
			await physics_frame
			if g.codex_rules.buckled.has(t.id):
				break
		var drawn: float = a0 - g.sys.fluid("wt1")
		if not vent:
			await _frames(20)
			await _shot_m(g, _centre(g, t), 1.8, "tank_buckled")
			check(drawn > 0.0 and g.codex_rules.buckled.has(t.id) and t.cond <= 0.451, "room at %.0f kPa, %.0f L drawn: WT-1 buckles (condition %.2f)" % [g.sys.P(room), drawn * 1000.0, t.cond])
		else:
			check(drawn > 0.0 and not g.codex_rules.buckled.has(t.id), "room vented first (%.0f kPa), %.0f L drawn: it holds" % [g.sys.P(room), drawn * 1000.0])
		await _done(g)


func _m10() -> void:
	print("match: 10 a pump left powered on a drained line runs dry")
	for off in [false, true]:
		var g = await _game("hg170")
		var pmp = g.world.tag("MCP-1")
		if off:
			await _dead_bus(g)
		g.world.reveal(g.world.room_at(_centre(g, pmp)), _centre(g, pmp))
		await _frames(5)
		# drawn off at its port, nearly dry, the hose left on it
		g.sys.set_fluid("loop", g.sys.fluid("loop") * 0.05)
		var c = g.world.ctrls[str(g.sys.fvol["loop"].port)]
		g.do_hose({"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)})
		var hot := 0.0
		for i in 120 * 31:
			await physics_frame
			if i == 120 * 15 and not off:
				hot = pmp.temp
				await _shot_m(g, _centre(g, pmp), 1.8, "pump_dry")
		if not off:
			check(hot > 80.0, "half way it is hot and smoking (%.0f °C)" % hot)
			check(pmp.has_meta("ran_dry") and pmp.cond <= 0.501, "at 30 s its seal goes (condition %.2f)" % pmp.cond)
		else:
			check(not pmp.has_meta("ran_dry") and pmp.cond > 0.99, "powered down first: nothing (%.0f °C)" % pmp.temp)
		await _done(g)


func _m11() -> void:
	print("match: 11 a gauge taken off a tank under pressure sprays")
	for vent in [false, true]:
		var g = await _game("fr26")
		var lg = g.world.tag("LG-1")
		var t = g.world.tag("T-1")
		var uk: String = g.sys.tank_vol(t)
		if vent:
			g.sys.vols[uk].n = 0.0
		g.world.reveal(g.world.room_at(_centre(g, lg)), _centre(g, lg))
		var n0: int = g.sys.leaks.size()
		await _free(g, lg)
		await _frames(30)
		var sprayed: bool = g.incidents.any(func(e): return e[1] == "gauge_spray")
		if not vent:
			await _shot_m(g, _centre(g, t), 1.6, "gauge_spray")
			check(lg.body != null and sprayed and g.sys.leaks.size() > n0, "LG-1 off T-1 (ullage %.0f kPa): the socket sprays" % g.sys.P(uk))
		else:
			check(lg.body != null and not sprayed, "the ullage vented first: nothing")
		await _done(g)


func _m12() -> void:
	print("match: 12 a fire bottle taken off with the bus live fires")
	for off in [false, true]:
		var g = await _game("ark01")
		var fb = g.world.tag("FIRE-110")
		if off:
			await _dead_bus(g)
		g.world.reveal(g.world.room_at(_centre(g, fb)), _centre(g, fb))
		await _free(g, fb)
		await _frames(8)
		var jet = g.recoil._jet_of(fb, "neck")
		if not off:
			await _shot_m(g, _centre(g, fb), 1.8, "solenoid")
			check(g.sys.bus_live and jet != null, "bus live: its solenoid fires it (a jet at its neck)")
		else:
			check(not g.sys.bus_live and jet == null, "bus dead: it comes off quiet")
		await _done(g)


func _m13() -> void:
	print("match: 13 a thruster taken off live fires a pulse")
	var quiet := 0.0
	for off in [true, false]:
		var g = await _game("s09")
		var r = g.world.tag("RCS-Q1")
		if off:
			await _dead_bus(g)
		g.world.reveal(g.world.room_at(_centre(g, r)), _centre(g, r))
		await _free(g, r)
		var vmax := 0.0
		for i in 50:
			await physics_frame
			if r.body != null:
				vmax = maxf(vmax, r.body.linear_velocity.length())
			if i == 10 and not off:
				await _shot_m(g, _centre(g, r), 1.8, "rcs_pulse")
		if not off:
			check(g.incidents.any(func(e): return e[1] == "rcs_fired") and vmax > quiet + 2.0 * M, "live: it kicks itself off at %.1f m/s (%.1f off a dead bus)" % [vmax / M, quiet / M])
		else:
			quiet = vmax
			check(not g.incidents.any(func(e): return e[1] == "rcs_fired"), "bus dead: it comes off quiet (%.1f m/s)" % (vmax / M))
		await _done(g)


func _m14() -> void:
	print("match: 14 a transformer steps the bus up")
	var g = await _game("ark01")
	var x = g.world.tag("XFMR-111")
	var v: float = g.sys.piece_volts(x)
	check(absf(v - g.sys.bus_volts() * 10.0) < 1.0 and v > 4000.0, "XFMR-111 on the %.0f V bus: its high side %.0f V" % [g.sys.bus_volts(), v])
	var c := _centre(g, x)
	g.world.reveal(g.world.room_at(c), c)
	var bb := Geom.bbox(g.world.world_poly(x))
	g.cut_kerf(x, PackedVector2Array([c - Vector2(bb.size.x * 0.2, 0), c + Vector2(bb.size.x * 0.2, 0)]))
	await _frames(3)
	check(g.incidents.any(func(e): return e[1] == "arc" and str(e[2]).begins_with("4400")), "cut into it: an arc at 4.4 kV")
	await _done(g)


func _m15() -> void:
	print("match: 15 the measuring tool names a tank's liquid")
	var want := {"hydraulic": "液压油", "glycol": "冷却液", "water": "水", "coolant": "冷却液"}
	var seen := {}
	Txt.zh = true
	for ship in ["cv138", "ch110", "gr7"]:
		var g = await _game(ship)
		var s = g.sys
		for k in s.fvol:
			var v: Dictionary = s.fvol[k]
			var kind: String = str(v.get("fluid", ""))
			if not want.has(kind) or seen.has(kind) or v.has("look"):
				continue
			var p = g.world.tag(str(v.get("piece", "")))
			if p == null:
				continue
			var txt: String = " ".join(s.contents_reading(p).map(func(x): return str(x)))
			seen[kind] = txt
			var ok: bool = txt.find(want[kind]) >= 0 and (kind == "water" or txt.find("水 ") < 0)
			check(ok, "%s tank %s reads: %s" % [kind, p.tag, txt])
		await _done(g)
	check(seen.has("hydraulic"), "a hydraulic tank was read")


func _m16() -> void:
	print("match: 16 rotors coast down; a generator's remanence")
	var g = await _game("hg170")
	var gen = g.world.tag("GEN-1")
	var comp = g.world.tag("INT-C")
	var rg = g.spin.rotor_of(gen)
	check(rg != null and float(rg.w) > 0.9 and g.spin.rotor_of(comp) != null, "GEN-1 and INT-C turning with the bus live")
	await _dead_bus(g)
	await _frames(120 * 3)
	var v: float = g.sys.piece_volts(gen)
	check(not g.sys.bus_live and g.spin.turning(gen) and v > 30.0 and v < 100.0, "bus dead 3 s: GEN-1 still turning (%.0f%%), its remanence %.0f V" % [float(rg.w) * 100.0, v])
	var c := _centre(g, gen)
	g.world.reveal(g.world.room_at(c), c)
	g.drone.global_position = c + Vector2(-2.0, -1.0) * M
	await _shot_m(g, _centre(g, comp), 1.6, "rotor_coast")
	var hp0: float = g.drone.integrity
	var bb := Geom.bbox(g.world.world_poly(gen))
	g.cut_kerf(gen, PackedVector2Array([c - Vector2(bb.size.x * 0.2, 0), c + Vector2(bb.size.x * 0.2, 0)]))
	await _frames(4)
	await _shot_m(g, c, 1.4, "rotor_burst")
	check(g.incidents.any(func(e): return e[1] == "rotor_burst") and g.incidents.any(func(e): return e[1] == "arc"), "cut while it turns: the rotor bursts, and the remanence arcs")
	check(g.drone.integrity < hp0, "the drone beside it is hit (%.0f → %.0f, %.1f m off, alive %s)" % [hp0, g.drone.integrity, g.drone.global_position.distance_to(c) / M, g.drone.alive])
	g.drone.global_position = Vector2(-60.0, -60.0) * M
	await _frames(120 * 40)
	var cc := _centre(g, comp)
	var cb := Geom.bbox(g.world.world_poly(comp))
	var n0: int = g.incidents.filter(func(e): return e[1] == "rotor_burst").size()
	g.cut_kerf(comp, PackedVector2Array([cc - Vector2(cb.size.x * 0.2, 0), cc + Vector2(cb.size.x * 0.2, 0)]))
	await _frames(4)
	check(not g.spin.turning(comp) and g.incidents.filter(func(e): return e[1] == "rotor_burst").size() == n0, "43 s on, INT-C has stopped: cut, no burst")
	await _done(g)


func _m17() -> void:
	print("match: 17 a pump taken off still turning is flung round")
	for wait in [false, true]:
		var g = await _game("fx70")
		var vac = g.world.tag("VAC")
		await _dead_bus(g)
		if wait:
			await _frames(120 * 70)
		g.world.reveal(g.world.room_at(_centre(g, vac)), _centre(g, vac))
		var turning: bool = g.spin.turning(vac)
		await _free(g, vac)
		var spin := 0.0
		for i in 30:
			await physics_frame
			if vac.body != null:
				spin = maxf(spin, absf(vac.body.angular_velocity))
		var kicked: bool = g.incidents.any(func(e): return e[1] == "rotor_kick")
		if not wait:
			check(turning and kicked and spin > 2.0, "off at once: still turning, its casing flung round (%.1f rad/s)" % spin)
		else:
			check(not turning and not kicked, "waited 70 s for it to stop: it comes off quiet (%.1f rad/s)" % spin)
		await _done(g)


# the angle of a piece's longest edge (world)
func _long_ang(g, p) -> float:
	var pts: PackedVector2Array = g.world.world_poly(p)
	var best := 0.0
	var ang := 0.0
	for i in pts.size():
		var d: Vector2 = pts[(i + 1) % pts.size()] - pts[i]
		if d.length() > best:
			best = d.length()
			ang = fposmod(d.angle(), PI)
	return ang


func _m18() -> void:
	print("match: 18 loaded beams spring, kink and ring when cut through")
	for e in [["dr150", "DL-A2"], ["ic120", "BU-2"], ["ob90", "BRC-U"]]:
		var g = await _game(e[0])
		var b = g.world.tag(e[1])
		var c := _centre(g, b)
		var bb := Geom.bbox(g.world.world_poly(b))
		var across: Vector2 = Vector2(0, 1) if bb.size.x >= bb.size.y else Vector2(1, 0)
		var half: float = (bb.size.y if bb.size.x >= bb.size.y else bb.size.x) * 0.5 + 0.3 * M
		g.world.reveal(g.world.room_at(c), c)
		# a nick first: not through, nothing lets go
		g.cut_kerf(b, PackedVector2Array([c - across * half, c - across * half * 0.4]))
		await _frames(5)
		check(not g.incidents.any(func(x): return x[1] == "beam_snap"), "%s %s nicked, not through: it holds" % [e[0], e[1]])
		var a0 := _long_ang(g, b)
		g.drone.global_position = c + across * 2.0 * M
		g.drone.linear_velocity = Vector2.ZERO
		# past the drone's first second (it cannot be hurt as it launches)
		await _frames(130)
		var off: float = 2.0 if e[0] != "ob90" else 1.4
		g.drone.global_position = c + across * off * M
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(2)
		var hp0: float = g.drone.integrity
		g.cut_kerf(b, PackedVector2Array([c - across * half, c + across * half]))
		await _frames(18)
		await _shot_m(g, c, 1.1 if e[0] != "ob90" else 1.6, "beam_%s" % e[0])
		await _frames(30)
		await _shot_m(g, c, 1.1 if e[0] != "ob90" else 1.6, "beam_%s_ring" % e[0])
		await _frames(90)
		var kink: float = fposmod(absf(a0 - _long_ang(g, b)), PI) if not b.gone and b.body == null else 0.0
		kink = minf(kink, PI - kink)
		check(g.incidents.any(func(x): return x[1] == "beam_snap"), "cut through: it snaps")
		check(b.body != null or kink > 0.015, "the part still fixed stays bent (%.1f°)" % rad_to_deg(kink))
		check(g.drone.integrity < hp0, "the drone %.1f m off is hit (%.0f → %.0f)" % [off, hp0, g.drone.integrity])
		await _done(g)
