extends "res://tests/codex_match_check.gd"
# The codex audit, second round (design/图鉴对标_审计_第二轮_20261110.md): what the book says
# that the game did not do, now done.
#   1 a pane with cabin pressure behind it let go of its fixings: blown out toward the low
#     side and shattered; the room vented first: it comes away whole
#   2 an armour plate's kerf heat over 150 °C reaches the equipment beside it: it heats and
#     loses value, never more than 20 %; far equipment untouched
#   3 an inverter's DC link: the bus cut, it still reads hundreds of volts, a cut arcs;
#     a minute on it is under 30 V
#   4 a molecular pump still spinning, air let into its room: the rotor crashes; the room
#     already at pressure: nothing
#   5 the turbo-expander coasts down (HG-170 TX-1) like the other rotors
#   6 every reason a piece loses value for has its words
#   7 FX-70's dump resistor taken out mid-dump: the energised coils quench; taken out with the
#     dump open: no quench, but the dump no longer brings the energy down
#   8 an eddy-current sorter's magnet drum pulls the drone in (M-14 / MF-126)
#   9 an electrolyser cut into: its knallgas goes up (BL-88)
#  10 a UV steriliser's lamp broken by the beam: mercury, the machines round it lose 5 % (HB-86)
#  11 a humidifier runs hot (90 °C), cools once the bus is cut
# tools/run_test.sh tests/codex_match2_check.gd [-- 2 3]   (writes tests/out/match2_*.png)


func _initialize() -> void:
	SaveGame.path = "user://zp_test_match2_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_match2_career.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _run() -> void:
	only = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	if _on(1):
		await _n1()
	if _on(2):
		await _n2()
	if _on(3):
		await _n3()
	if _on(4):
		await _n4()
	if _on(5):
		await _n5()
	if _on(6):
		_n6()
	if _on(7):
		await _n7()
	if _on(8):
		await _n8()
	if _on(9):
		await _n9()
	if _on(10):
		await _n10()
	if _on(11):
		await _n11()
	print("match2: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
	quit(1 if fails > 0 else 0)


func _shot2(g, at: Vector2, zoom: float, name: String) -> void:
	await _shot_m(g, at, zoom, "2_" + name)


# a pane that has cabin air on one side and less on the other (as codex_rules.gd on_freed sees it)
func _pane_dp(g, q) -> float:
	var bb := Geom.bbox(g.world.world_poly(q))
	var c := bb.get_center()
	var tall: bool = bb.size.y >= bb.size.x
	var n := Vector2(1, 0) if tall else Vector2(0, 1)
	var half: float = (bb.size.x if tall else bb.size.y) * 0.5 + 0.5 * M
	return absf(g.codex_rules._kpa_at(c + n * half) - g.codex_rules._kpa_at(c - n * half))


func _free(g, p) -> void:
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	for l in g.world.lines_of(p).duplicate():
		g.world.kill_line(l)


func _n1() -> void:
	print("match2: 1 a pane with pressure behind it pushed out")
	for ship in ["my48", "hb86", "st40", "qc30", "ob90", "jd38", "med47", "cl104"]:
		var g = await _game(ship)
		var pane = null
		var calm = null
		for q in g.atmos.panes():
			if q.body != null or q.gone or not q.intact or g.codex_rules._liner_pane(q):
				continue
			var dp := _pane_dp(g, q)
			if dp >= 40.0 and pane == null:
				pane = q
			elif dp < 5.0 and calm == null:
				calm = q
		if pane == null:
			await _done(g)
			continue
		print("  %s: %s with %.0f kPa across, %s with none" % [ship, pane.tag, _pane_dp(g, pane), calm.tag if calm != null else "-"])
		var c := _centre(g, pane)
		g.world.reveal(g.world.room_at(c), c)
		_free(g, pane)
		await _frames(3)
		check(pane.body != null and pane.has_meta("pane_out"), "%s let go under pressure: blown out" % pane.tag)
		check(pane.cond <= 0.051, "it shattered (condition %.2f)" % pane.cond)
		var v: float = pane.body.linear_velocity.length() / M if pane.body != null else 0.0
		check(v > 1.0, "thrown out at %.1f m/s" % v)
		check(g.incidents.any(func(e): return e[1] == "pane_out"), "booked")
		await _shot2(g, c, 1.6, "pane_out")
		if calm != null:
			_free(g, calm)
			await _frames(3)
			check(calm.cond > 0.9 and not calm.has_meta("pane_out"), "%s with no difference across it comes away whole (%.2f)" % [calm.tag, calm.cond])
		await _done(g)
		return
	check(false, "a pane with cabin pressure across it on some ship")


func _set_kpa(g, room: String, kpa: float) -> void:
	var v = g.sys.vols.get(room)
	if v != null:
		v.n = kpa * v.V


func _n2() -> void:
	print("match2: 2 an armour plate's kerf heat reaches its neighbours")
	for ship in ["es112", "pt34", "ev55", "ark01", "qc30"]:
		var g = await _game(ship)
		var plate = null
		var near = null
		for a in g.codex_rules.armour:
			if a.gone or a.body != null:
				continue
			var ap: PackedVector2Array = g.world.world_poly(a)
			var bb := Geom.bbox(ap).grow(0.3 * M)
			for id in g.world.order:
				var q = g.world.pieces[id]
				if q == a or q.gone or q.cls != "equip" or not q.intact or str(q.mat) in g.codex_rules.ARMOUR_MATS or q.art == "armor":
					continue
				if bb.intersects(Geom.bbox(g.world.world_poly(q))):
					near = q
					break
			if near != null:
				plate = a
				break
		if plate == null:
			await _done(g)
			continue
		var far = null
		for id in g.world.order:
			var q = g.world.pieces[id]
			if q.cls == "equip" and q.intact and not q.gone and q != near and _centre(g, q).distance_to(_centre(g, plate)) > 8.0 * M:
				far = q
				break
		print("  %s: plate %s (%s), beside it %s" % [ship, plate.tag if plate.tag != "" else str(plate.id), plate.mat, near.tag])
		var c0: float = near.cond
		var f0: float = far.cond if far != null else 1.0
		plate.kerf_dt = 320.0
		await _frames(120 * 2)
		check(near.cond < c0 - 0.01, "%s beside the hot plate loses value (%.2f → %.2f)" % [near.tag, c0, near.cond])
		check(near.temp > 100.0, "and heats (%.0f °C)" % near.temp)
		check(g.incidents.any(func(e): return e[1] == "armour_heat"), "booked")
		await _shot2(g, _centre(g, near), 2.0, "armour_heat")
		for i in 30:
			plate.kerf_dt = 400.0
			await _frames(60)
		check(c0 - near.cond <= 0.2 + 0.001, "never more than 20 %% (lost %.2f)" % (c0 - near.cond))
		check(far == null or absf(far.cond - f0) < 0.001, "equipment 8 m off is untouched")
		plate.kerf_dt = 100.0
		var c1: float = near.cond
		await _frames(120)
		check(absf(near.cond - c1) < 0.001, "under 150 °C it stops")
		await _done(g)
		return
	check(false, "an armour plate with equipment beside it on some ship")


func _n3() -> void:
	print("match2: 3 an inverter's DC link still charged")
	for ship in ["mf126", "st40", "sv122", "tb180", "md160", "ch110", "es112", "tw64"]:
		var g = await _game(ship)
		var inv = null
		for id in g.codex_rules.residuals:
			var p = g.codex_rules.residuals[id].p
			if str(g.codex_rules.residuals[id].kind) == "inverter" and g.codex_rules._fed(p):
				inv = p
				break
		if inv == null:
			await _done(g)
			continue
		var v0: float = g.sys.piece_volts(inv)
		print("  %s: %s reads %.0f V with the bus live" % [ship, inv.tag, v0])
		check(v0 >= 400.0, "%s on the live bus: %.0f V" % [inv.tag, v0])
		await _bus_off(g)
		await _frames(120 * 5)
		var v5: float = g.sys.piece_volts(inv)
		check(not g.sys.bus_live and v5 > 300.0 and v5 < 700.0, "bus dead 5 s: the link still holds %.0f V" % v5)
		var c := _centre(g, inv)
		g.world.reveal(g.world.room_at(c), c)
		var arcs0: int = g.incidents.filter(func(e): return e[1] == "arc").size()
		var bb := Geom.bbox(g.world.world_poly(inv))
		g.cut_kerf(inv, PackedVector2Array([c - Vector2(bb.size.x * 0.3, 0), c + Vector2(bb.size.x * 0.3, 0)]))
		await _frames(4)
		check(g.incidents.filter(func(e): return e[1] == "arc").size() > arcs0, "cut into it: it arcs")
		await _shot2(g, c, 2.0, "dc_link_arc")
		await _done(g)
		# a second time, waited out
		g = await _game(ship)
		inv = g.world.tag(inv.tag)
		await _bus_off(g)
		await _frames(120 * 60)
		var v60: float = g.sys.piece_volts(inv)
		check(v60 < 30.0, "a minute on: %.1f V" % v60)
		await _done(g)
		return
	check(false, "an inverter fed from the bus on some ship")


func _n4() -> void:
	print("match2: 4 air into a spinning molecular pump")
	for ship in ["fx70", "qc30"]:
		var g = await _game(ship)
		var pump = null
		for r in g.spin.rotors:
			if r.art == "turbo_pump":
				pump = r
		if pump == null:
			await _done(g)
			continue
		var p = pump.p
		var room: String = g.world.room_at(_centre(g, p))
		print("  %s: %s in %s at %.0f kPa" % [ship, p.tag, room, g.sys.P(room)])
		check(room != "", "%s stands in a room" % p.tag)
		# the room already at pressure: nothing
		pump.w = 1.0
		await _frames(120)
		check(not p.has_meta("inrush") and p.cond > 0.9, "spinning in a room at pressure: nothing (%.2f)" % p.cond)
		# pumped down, then air let in at once
		_set_kpa(g, room, 0.5)
		await _frames(120 * 6)
		print("    pumped down: %.1f kPa, lag %.1f" % [g.sys.P(room), float(pump.get("lag", -1.0))])
		pump.w = 1.0
		_set_kpa(g, room, 60.0)
		await _frames(6)
		print("    air in: %.1f kPa, lag %.1f" % [g.sys.P(room), float(pump.get("lag", -1.0))])
		check(p.has_meta("inrush") and p.cond <= 0.301, "air let into it spinning: the rotor crashes (%.2f)" % p.cond)
		check(g.incidents.any(func(e): return e[1] == "rotor_inrush"), "booked")
		await _shot2(g, _centre(g, p), 2.0, "inrush")
		await _frames(120)
		check(float(pump.w) == 0.0, "a wrecked rotor does not turn again")
		await _done(g)
		# stopped first: nothing
		g = await _game(ship)
		for r in g.spin.rotors:
			if r.art == "turbo_pump":
				pump = r
		p = pump.p
		_set_kpa(g, room, 0.5)
		await _frames(120 * 6)
		pump.w = 0.0
		g.spin.set_physics_process(false)
		_set_kpa(g, room, 60.0)
		g.spin.set_physics_process(true)
		await _frames(30)
		check(not p.has_meta("inrush"), "stopped when the air comes in: nothing")
		await _done(g)
		return
	check(false, "a molecular pump on FX-70 or QC-30")


func _n5() -> void:
	print("match2: 5 the turbo-expander coasts")
	var g = await _game("hg170")
	var tx = null
	for r in g.spin.rotors:
		if r.art == "turboexpander":
			tx = r
	check(tx != null, "HG-170's turbo-expander has a rotor")
	if tx != null:
		tx.w = 1.0
		await _bus_off(g)
		await _frames(120 * 15)
		check(g.spin.turning(tx.p), "15 s after the bus went it still turns (%.0f%%)" % (float(tx.w) * 100.0))
		await _frames(120 * 30)
		check(not g.spin.turning(tx.p), "45 s on it has stopped (%.0f%%)" % (float(tx.w) * 100.0))
	await _done(g)


func _n6() -> void:
	print("match2: 6 every reason for lost value has its words")
	var miss := []
	for f in ["recoil.gd", "runaway.gd", "codex_rules.gd", "spin.gd", "prestress.gd"]:
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		var re := RegEx.new()
		re.compile("\"((dv|loss)_[a-z_]+)\"")
		for m in re.search_all(src):
			var k := m.get_string(1)
			if Txt.t(k) == k and not miss.has(k):
				miss.append(k)
	check(miss.is_empty(), "no raw reason keys %s" % [miss])


func _by_art(g, art: String):
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and p.cls == "equip" and p.intact and Codex.device_entry(Codex.art_of(p)) == art:
			return p
	return null


func _cut_through(g, p) -> void:
	var c := _centre(g, p)
	g.world.reveal(g.world.room_at(c), c)
	var bb := Geom.bbox(g.world.world_poly(p))
	g.cut_kerf(p, PackedVector2Array([c - Vector2(bb.size.x * 0.3, 0), c + Vector2(bb.size.x * 0.3, 0)]))


func _n7() -> void:
	print("match2: 7 FX-70's dump resistor")
	var g = await _game("fx70")
	var mg = g.magnets
	var res = mg._resistor()
	var dump: String = str(mg.cfg.get("dump", ""))
	check(res != null and dump != "", "the dump resistor %s and its switch %s" % [res.tag if res != null else "-", dump])
	g.sys.set_switch(dump, true)
	await _frames(120)
	check(mg.any_energised(), "the coils still hold their energy a second into the dump")
	_free(g, res)
	await _frames(10)
	check(not mg.any_energised() and not mg.quenched.is_empty(), "the resistor taken out mid-dump: %d coils quench" % mg.quenched.size())
	check(g.incidents.any(func(e): return e[1] == "dump_res_lost"), "booked")
	await _shot2(g, _centre(g, g.world.tag(mg.quenched.keys()[0])) if not mg.quenched.is_empty() else _centre(g, res), 0.8, "dump_res_quench")
	await _done(g)
	g = await _game("fx70")
	mg = g.magnets
	res = mg._resistor()
	_free(g, res)
	await _frames(10)
	check(mg.quenched.is_empty(), "taken out with the dump open: nothing quenches")
	var e0: float = float(mg.energy.values()[0])
	g.sys.set_switch(dump, true)
	await _frames(120 * 10)
	var e1: float = float(mg.energy.values()[0])
	check(absf(e1 - e0) < 0.001, "and the dump no longer brings the energy down (%.3f → %.3f)" % [e0, e1])
	await _done(g)


func _n8() -> void:
	print("match2: 8 a sorter's magnet drum")
	for ship in ["mf126", "m14"]:
		var g = await _game(ship)
		var so = _by_art(g, "sorter")
		if so == null:
			await _done(g)
			continue
		var c := _centre(g, so)
		g.world.reveal(g.world.room_at(c), c)
		var sb := Geom.bbox(g.world.world_poly(so))
		var reach: float = g.codex_rules.SORT_R * M
		var from: Vector2 = Vector2(c.x, sb.position.y - 1.2 * M)
		print("    sorter %.1f x %.1f m, reach %.2f m, drone at %.2f m, room %s" % [sb.size.x / M, sb.size.y / M, reach / M, from.distance_to(c) / M, g.world.room_at(from)])
		g.drone.spawn_t = 10.0
		g.drone.global_position = from
		g.drone.linear_velocity = Vector2.ZERO
		var wp: PackedVector2Array = g.world.world_poly(so)
		var d0: float = Geom.dist_to_boundary(from, wp)
		await _frames(120)
		var d1: float = 0.0 if Geometry2D.is_point_in_polygon(g.drone.global_position, wp) else Geom.dist_to_boundary(g.drone.global_position, wp)
		print("  %s: %s, the drone %.2f m → %.2f m off its casing" % [ship, so.tag, d0 / M, d1 / M])
		check(d1 < d0 - 0.2 * M, "the drone is pulled in toward %s" % so.tag)
		await _frames(240)
		check(g.incidents.any(func(e): return e[1] == "sorter_pull"), "dragged onto the drum: knocked, booked")
		await _shot2(g, c, 2.0, "sorter_pull")
		await _done(g)
		return
	check(false, "a sorter on MF-126 or M-14")


func _n9() -> void:
	print("match2: 9 an electrolyser cut into")
	var g = await _game("bl88")
	var el = _by_art(g, "electrolyser")
	check(el != null, "BL-88's electrolyser %s" % (el.tag if el != null else "-"))
	if el != null:
		var b0: float = g.combustion.burnt_kg
		_cut_through(g, el)
		await _frames(8)
		await _shot2(g, _centre(g, el), 1.6, "knallgas")
		await _frames(120 * 2)
		check(g.incidents.any(func(e): return e[1] == "knallgas"), "booked")
		check(g.combustion.burnt_kg > b0, "the hydrogen burnt with its own oxygen (%.3f kg)" % (g.combustion.burnt_kg - b0))
	await _done(g)


func _n10() -> void:
	print("match2: 10 a UV lamp broken by the beam")
	var g = await _game("hb86")
	var uv = _by_art(g, "uv_steriliser")
	check(uv != null, "HB-86's UV steriliser %s" % (uv.tag if uv != null else "-"))
	if uv != null:
		var c := _centre(g, uv)
		var near: Array = []
		for q in g._equip_near(c, 3.0 * M):
			if q != uv and q.intact and g.world.room_at(_centre(g, q)) == g.world.room_at(c):
				near.append([q, q.cond])
		_cut_through(g, uv)
		await _frames(30)
		await _shot2(g, c, 1.6, "uv_mercury")
		check(g.incidents.any(func(e): return e[1] == "mercury"), "booked")
		var hit := 0
		for e in near:
			if absf(float(e[1]) - e[0].cond - 0.05) < 0.002:
				hit += 1
		check(near.is_empty() or hit == near.size(), "%d of %d machines round it lose 5 %%" % [hit, near.size()])
	await _done(g)


func _n11() -> void:
	print("match2: 11 a humidifier runs hot")
	for ship in ["cl104", "hb86", "ic120"]:
		var g = await _game(ship)
		var hu = _by_art(g, "humidifier")
		if hu == null or not g.codex_rules._fed(hu):
			await _done(g)
			continue
		await _frames(30)
		check(Mat.temp(hu) >= 89.0, "%s %s running: %.0f °C" % [ship, hu.tag, Mat.temp(hu)])
		await _bus_off(g)
		await _frames(120 * 60)
		check(Mat.temp(hu) < 60.0, "a minute after the bus went: %.0f °C" % Mat.temp(hu))
		await _done(g)
		return
	check(false, "a humidifier on a live bus")
