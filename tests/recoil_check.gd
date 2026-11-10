extends SceneTree
# Recoil (scripts/recoil.gd): a container that opens under pressure is pushed back by its
# own jet, and the book's numbers hold (cx_gastank_b/x, cx_s_ullage_b, cx_hpu_b).
#   1 the grapple yanks VT-80's charged oxygen bottle O2B (15 MPa) off its locks: the valve shears,
#     it is thrown the way away from its neck, fast; the grapple lets go
#   2 the same bottle vented at its port first: torn loose, nothing jets
#   3 a charged fire bottle (DR-150) knocked hard: its valve goes, it flies off; the jet
#     thrust follows the pressure down; it hurts the drone it runs into
#   4 the same fire bottle vented first and knocked as hard: nothing
#   5 a bottle charged below its burst pressure, cut: a hole it jets out of, pushed away
#     from the kerf, harder as the kerf grows
#   6 a liquid tank under an ullage, cut while loose: the liquid's momentum pushes it back
#   8 a hose torn off a charged accumulator (CV-138 ACC-G) with it: a jet at the fitting;
#     with the vessel's valve shut first, nothing
#   7 the book's own bottle (50 L, 200 bar): the thrust is tens of times its weight, it
#     empties in seconds
# tools/run_test.sh tests/recoil_check.gd   (writes tests/out/recoil_*.png)

const M := 48.0
const R = preload("res://scripts/recoil.gd")
var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_recoil_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_recoil_career.json"
	root.add_child(preload("res://tests/test_window.gd").new())
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _game(ship: String):
	Game.contract = {}
	Game.start_ship = ship
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var w := 0
	while str(g.state) != "play" and w < 60 * 40:
		await process_frame
		w += 1
	g.drone.global_position = Vector2(-60.0, -60.0) * M
	g.drone.linear_velocity = Vector2.ZERO
	return g


func _done(g) -> void:
	g.queue_free()
	await _frames(3)


func _by_key(g, key: String):
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and p.key == key:
			return p
	return null


func _of(g, name_key: String):
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and p.name_key == name_key and p.body == null:
			return p
	return null


func _centre(g, p) -> Vector2:
	return g.world.frame(p) * Geom.centroid(p.poly)


func _shot(g, at: Vector2, zoom: float, name: String) -> void:
	g.cam_override = at
	g.cam_pos = at
	g.cam_vel = Vector2.ZERO
	g.zoom_now = zoom
	g.zoom_override = zoom
	await process_frame
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tests/out/recoil_%s.png" % name))
	print("  shot tests/out/recoil_%s.png" % name)


# vent a vessel at its port with a hose (the pump), time warped, until it is below kpa
func _vent(g, port_id: String, kpa: float) -> float:
	var c = g.world.ctrls[port_id]
	var at: Vector2 = g.world.ctrl_world(c)
	var room: String = str(c.hidden_room) if "hidden_room" in c else ""
	if room != "":
		g.world.reveal(room, at)
	g.do_hose({"kind": "ctrl", "ctrl": c, "pos": at})
	var t := 0
	while g.sys.P(str(c.target)) > kpa and t < 60 * 60:
		await physics_frame
		t += 1
	return g.sys.P(str(c.target))


# take a piece off the ship as the wrench would (every fixing undone), out into open space
func _loose(g, p, at: Vector2, turn := 0.0):
	for l in g.world.lines_of(p).duplicate():
		g.world.kill_line(l, g.world.line_end_world(l, 0 if l.a == p.id else 1))
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	var w := 0
	while p.body == null and w < 30:
		await physics_frame
		w += 1
	var b = p.body
	if b == null:
		return null
	b.global_position = at
	b.rotation = turn
	b.linear_velocity = Vector2.ZERO
	b.angular_velocity = 0.0
	b.calm = 0.0
	b.settle = 0.0
	b.reset_physics_interpolation()
	await _frames(40)
	b.linear_velocity = Vector2.ZERO
	b.angular_velocity = 0.0
	return b


# a spot in the open over the ship at x (inside the berth, clear of the hull by gap)
func _open_spot(g, x: float, gap: float) -> Vector2:
	var top := INF
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q.gone or q.body != null:
			continue
		var qb := Geom.bbox(q.poly)
		if qb.position.x - 1.5 * M < x and qb.end.x + 1.5 * M > x:
			top = minf(top, qb.position.y)
	var inner: Rect2 = Game.berth_inner()
	return Vector2(x, maxf(top - gap * M, inner.position.y + 2.5 * M))


# a spot in the berth with nothing within clear metres: no piece, no line
func _clear_spot(g, clear: float) -> Vector2:
	var inner: Rect2 = Game.berth_inner()
	var y := inner.position.y + 3.0 * M
	while y < inner.end.y - 3.0 * M:
		var x := inner.position.x + 4.0 * M
		while x < inner.end.x - 4.0 * M:
			var at := Vector2(x, y)
			var ok := true
			for id in g.world.order:
				var q = g.world.pieces[id]
				if not q.gone and q.body == null and Geom.bbox(q.poly).grow(clear * M).has_point(at):
					ok = false
					break
			if ok:
				for id in g.world.lines:
					var l = g.world.lines[id]
					if l.alive and Geom.dist_to_polyline(at, g.world.line_path_world(l)) < clear * M:
						ok = false
						break
			if ok:
				return at
			x += 2.0 * M
		y += 2.0 * M
	return inner.position + Vector2(6.0, 3.0) * M


# the grapple on p, pulled hard away until its fixings give (tools.gd physics_step)
func _yank(g, p, dir: Vector2) -> bool:
	var c := _centre(g, p)
	g.drone.global_position = c - dir * 2.0 * M
	g.drone.linear_velocity = Vector2.ZERO
	g.tools.set_tool(3)
	g.bot.lmb = true
	g.tools.held_piece = p
	g.tools.held_body = null
	g.tools.held_local = Geom.centroid(p.poly)
	var torn := false
	for i in 60 * 6:
		g.bot.aim = c + dir * 6.0 * M
		g.drone.global_position = c - dir * 2.0 * M
		await physics_frame
		if g.incidents.any(func(e): return e[1] == "torn"):
			torn = true
			break
	return torn


var only: Array = []


func _on(n: int) -> bool:
	return only.is_empty() or str(n) in only


func _run() -> void:
	only = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))
	if _on(1):
		await _s1()
	if _on(2):
		await _s2()
	if _on(3):
		await _s3()
	if _on(4):
		await _s4()
	if _on(5):
		await _s5()
	if _on(6):
		await _s6()
	if _on(7):
		_s7()
	if _on(8):
		await _s8(false)
		await _s8(true)
	print("recoil: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
	quit(1 if fails > 0 else 0)


func _s1() -> void:
	print("recoil: 1 the grapple yanks a charged bottle off its locks (VT-80 O2B, 15 MPa O2)")
	var g = await _game("vt80")
	var s = g.sys
	var ob = _by_key(g, "O2B")
	var vol: String = s.tank_vol(ob)
	check(ob != null and s.P(vol) > 5000.0, "O2B holds oxygen at %.0f kPa, held by %d locks" % [s.P(vol), g.world.joints_of(ob).size()])
	g.world.reveal("Q", _centre(g, ob))
	var neck: Array = g.recoil.neck_of(ob)
	var away: Vector2 = -(neck[1] as Vector2)
	var torn: bool = await _yank(g, ob, Vector2(-1, 0))
	var jet = g.recoil._jet_of(ob, "neck")
	check(torn and jet != null, "torn off its locks, its valve shears (a jet at its neck)")
	check(g.tools.held_piece == null, "the grapple cannot hold the kick: it lets go")
	await _frames(2)
	var f0: float = float(jet.f) if jet != null else 0.0
	var v0: Vector2 = ob.body.linear_velocity if ob.body != null else Vector2.ZERO
	var vmax := 0.0
	for i in 12:
		await physics_frame
		vmax = maxf(vmax, ob.body.linear_velocity.length() / M if ob.body != null else 0.0)
	var v1: Vector2 = ob.body.linear_velocity if ob.body != null else Vector2.ZERO
	var acc: Vector2 = (v1 - v0) / (12.0 / 120.0) / M
	var mb: float = ob.body.total_mass() if ob.body != null else 0.15
	check(f0 > 2500.0, "the jet's thrust: %.1f kN (C_F·Δp·A, 25 mm neck), %.1f times the bottle's %.0f kg weight" % [f0 / 1000.0, f0 / (mb * 9810.0), mb * 1000.0])
	check(acc.length() > 0.7 * f0 / (mb * 1000.0) and acc.normalized().dot(away) > 0.8, "it accelerates away from its neck at %.0f m/s² (thrust/mass %.0f), along the neck's opposite %.2f" % [acc.length(), f0 / (mb * 1000.0), acc.normalized().dot(away) if acc.length() > 0.0 else 0.0])
	await _shot(g, _centre(g, ob), 1.3, "neck_yank")
	var p0: Vector2 = _centre(g, ob)
	for i in 60:
		await physics_frame
		vmax = maxf(vmax, ob.body.linear_velocity.length() / M if ob.body != null else 0.0)
	check(vmax > 4.0, "driven into what is in its way in room Q (%.1f m/s at most)" % vmax)
	await _frames(120 * 6)
	var jl = g.recoil._jet_of(ob, "neck")
	var room_p: float = s.P("Q")
	check((jl == null or float(jl.f) < f0 * 0.02) and s.P(vol) < room_p + 30.0, "spent within seconds: down to the room's %.0f kPa (%.0f kPa), thrust %.0f N" % [room_p, s.P(vol), float(jl.f) if jl != null else 0.0])
	g.bot.lmb = false
	await _done(g)


func _s2() -> void:
	print("recoil: 2 the same bottle vented at its port first")
	var g = await _game("vt80")
	var ob = _by_key(g, "O2B")
	var left: float = await _vent(g, "PO", 150.0)
	check(left < 150.0, "vented through its port PO: %.0f kPa" % left)
	g.sys.hoses.clear()
	var torn: bool = await _yank(g, ob, Vector2(-1, 0))
	await _frames(20)
	check(torn and g.recoil.jets.is_empty(), "torn loose, nothing jets")
	var vv: float = ob.body.linear_velocity.length() / M if ob.body != null else 0.0
	check(vv < 3.0, "and it is not thrown (%.1f m/s)" % vv)
	g.bot.lmb = false
	await _done(g)


# a loose bottle sent at the hull at 7 m/s; true when its valve went
func _bus_off(g) -> void:
	for t in g.sys.src_order:
		g.sys.drain_source(t)
		g.sys.stop_source(t)
	await _frames(10)


func _knock(g, b, p) -> bool:
	b.linear_velocity = Vector2(0, 7.0 * M)
	for i in 240:
		await physics_frame
		if g.recoil._jet_of(p, "neck") != null:
			return true
	return false


func _s3() -> void:
	print("recoil: 3 a charged fire bottle knocked hard (DR-150, 5.7 MPa CO2)")
	var g = await _game("dr150")
	var s = g.sys
	var fb = _of(g, "p_ark_fire_bottle")
	var vol: String = s.tank_vol(fb)
	# the bus dead first: with it live the bottle's solenoid fires it as it comes off
	# (codex_rules.gd); this one is about the knock
	await _bus_off(g)
	var b = await _loose(g, fb, _open_spot(g, Geom.centroid(fb.poly).x, 4.0), PI)
	check(b != null and s.P(vol) > 5000.0, "unbolted and out in the open, neck down, still at %.0f kPa" % s.P(vol))
	var hit: bool = await _knock(g, b, fb)
	check(hit, "it hits the hull at 7 m/s: its valve is knocked off")
	var jet = g.recoil._jet_of(fb, "neck")
	await _frames(2)
	var fa: float = float(jet.f) if jet != null else 0.0
	var pa: float = s.P(vol)
	await _frames(24)
	var dir: Vector2 = b.linear_velocity.normalized()
	var spd: float = b.linear_velocity.length() / M
	check(spd > 4.0 and dir.y < -0.7, "the jet throws it back up off the hull: %.1f m/s" % spd)
	g.drone.global_position = b.global_position + dir * 2.5 * M
	g.drone.linear_velocity = Vector2.ZERO
	var hp0: float = g.drone.integrity
	await _shot(g, b.global_position + dir * 1.2 * M, 1.3, "neck_knock")
	await _frames(30)
	var fb2: float = float(jet.f) if jet != null and g.recoil.jets.has(jet) else 0.0
	var pb: float = s.P(vol)
	var room_p: float = g.recoil._outside(g.world.frame(fb) * g.recoil._local(jet)) if jet != null else 0.0
	var want: float = fa * (pb - room_p) / maxf(pa - room_p, 1.0)
	check(fa > 1000.0 and pb < pa and absf(fb2 - want) < fa * 0.1, "the thrust follows the pressure down: %.2f kN at %.0f kPa → %.2f kN at %.0f kPa" % [fa / 1000.0, pa, fb2 / 1000.0, pb])
	check(g.drone.integrity < hp0, "the drone in its way is hurt (%.0f → %.0f)" % [hp0, g.drone.integrity])
	await _done(g)


func _s4() -> void:
	print("recoil: 4 the same fire bottle vented first, knocked as hard")
	var g = await _game("dr150")
	var fb = _of(g, "p_ark_fire_bottle")
	var left: float = await _vent(g, str(fb.tag) + "-V", 120.0)
	g.sys.hoses.clear()
	check(left < 120.0, "vented: %.0f kPa" % left)
	var b = await _loose(g, fb, _open_spot(g, Geom.centroid(fb.poly).x, 4.0))
	var hit: bool = await _knock(g, b, fb)
	check(not hit and g.recoil.jets.is_empty(), "it hits the hull at 7 m/s: nothing jets")
	await _done(g)


func _s5() -> void:
	print("recoil: 5 a bottle charged below its burst pressure, cut")
	var g = await _game("dr150")
	var fb = _of(g, "p_ark_fire_bottle")
	var left: float = await _vent(g, str(fb.tag) + "-V", 185.0)
	g.sys.hoses.clear()
	var b = await _loose(g, fb, _clear_spot(g, 4.0))
	var c: Vector2 = b.global_position
	var bb: Rect2 = Geom.bbox(g.world.world_poly(fb))
	# a short kerf in from its left side
	var x0 := bb.position.x + 2.0
	g.cut_kerf(fb, PackedVector2Array([Vector2(x0, c.y), Vector2(x0 + 6.0, c.y)]))
	var jet = g.recoil._jet_of(fb, "hole")
	check(not g.incidents.any(func(e): return e[1] == "burst") and jet != null, "at %.0f kPa it does not burst: the kerf is a hole it jets out of" % left)
	var a0: float = float(jet.area) if jet != null else 0.0
	await _frames(3)
	var f1: float = float(jet.f) if jet != null else 0.0
	g.cut_kerf(fb, PackedVector2Array([Vector2(x0, c.y - 6.0), Vector2(x0, c.y + 6.0)]))
	await _frames(2)
	var f2: float = float(jet.f) if jet != null and g.recoil.jets.has(jet) else 0.0
	check(jet != null and float(jet.area) > a0 and f2 > f1, "the kerf grows, so does the hole and its push (%.0f → %.0f N)" % [f1, f2])
	await _frames(20)
	check(b.linear_velocity.x > 0.3 * M, "pushed away from the kerf (to the right): %.2f m/s" % (b.linear_velocity.x / M))
	await _shot(g, b.global_position, 1.6, "kerf_hole")
	await _done(g)


func _s6() -> void:
	print("recoil: 6 a liquid tank under an ullage, cut while loose")
	var d: Dictionary = Ship.load_data("dr150").duplicate(true)
	var wt := ""
	var small := INF
	for k in d.fluids.volumes:
		var fe: Dictionary = d.fluids.volumes[k]
		if fe.get("contents", false) and str(fe.get("piece", "")) != "" and float(fe.get("full", 99.0)) < small:
			small = float(fe.get("full", 99.0))
			wt = str(fe.piece)
	d.gas.vessels["WT~U"] = {"V": 0.05, "kpa": 190.0, "burst": 200.0, "piece": wt}
	Ship.override("dr150", d)
	var g = await _game("dr150")
	var s = g.sys
	var tk = g.world.tag(wt)
	var fv: String = s.fluid_in_piece(tk)
	var b = await _loose(g, tk, _clear_spot(g, 5.0))
	check(b != null and s.fluid(fv) > 0.02, "tank %s (%s) loose with %.2f m³ under 190 kPa of gas, %.2f t" % [wt, str(s.fvol[fv].get("look", "")), s.fluid(fv), b.total_mass()])
	var c: Vector2 = b.global_position
	var bb: Rect2 = Geom.bbox(g.world.world_poly(tk))
	var x0 := bb.position.x + 2.0
	g.cut_kerf(tk, PackedVector2Array([Vector2(x0, c.y - 8.0), Vector2(x0, c.y + 8.0)]))
	var imp := 0.0
	var gimp := 0.0
	var fl := 0.0
	var v0: float = b.linear_velocity.x
	for i in 14:
		await physics_frame
		for j in g.recoil.jets:
			if j.piece == tk:
				gimp += float(j.f) / 120.0
		for e in s.leaks:
			if e.piece == tk:
				fl = maxf(fl, float(e.get("recoil", 0.0)))
				imp += float(e.get("recoil", 0.0)) / 120.0
	check(not g.incidents.any(func(e): return e[1] in ["fire", "prop_blast"]), "nothing else going on round it (no fire)")
	check(fl > 20.0, "the liquid going out of the kerf pushes it back: up to %.0f N (ρ·Q·v)" % fl)
	var dv: float = (b.linear_velocity.x - v0) / M
	var want: float = (imp + gimp) / (b.total_mass() * 1000.0)
	check(dv > 0.0 and dv > want * 0.6 and dv < want * 1.6, "away from the kerf: %.3f m/s in 0.12 s (the liquid's and the gas's impulse say %.3f, the liquid's share %.0f%%)" % [dv, want, 100.0 * imp / maxf(imp + gimp, 1e-6)])
	await _shot(g, b.global_position, 1.3, "liquid")
	await _done(g)
	Ship._cache.erase("dr150")


func _s7() -> void:
	print("recoil: 7 the book's bottle (cx_gastank_x: 50 L at 200 bar)")
	var f_book: float = R.CF * 20000.0 * 1000.0 * R.NECK_A
	var w_book: float = 0.065 * 1000.0 * 9.81
	check(f_book / w_book > 10.0 and f_book / w_book < 60.0, "its sheared valve's thrust %.1f kN is %.0f times its 65 kg weight" % [f_book / 1000.0, f_book / w_book])
	var tau: float = 0.05 / (R.K_FLOW * R.NECK_A)
	check(tau > 0.3 and tau < 5.0, "it empties with a time constant of %.2f s" % tau)
	var e_book: float = 20000.0e3 * 0.05 / 0.4 * (1.0 - pow(101.0 / 20000.0, 0.4 / 1.4))
	check(e_book > 1.2e6 and e_book < 2.5e6, "its stored energy (adiabatic) %.1f MJ, the book's about 1.5 MJ" % (e_book / 1.0e6))


func _s8(shut: bool) -> void:
	print("recoil: 8 the grapple tears CV-138's accumulator ACC-G loose, its hose with it%s" % (" (its valve shut first)" if shut else ""))
	Ship._cache.erase("cv138")
	if shut:
		var d: Dictionary = Ship.load_data("cv138").duplicate(true)
		# a valve on the vessel, shut (systems.gd gas_valves; its control is off)
		d.gas["valves"] = d.gas.get("valves", []) + [{"a": "ACC-G", "b": "ACC-G", "ctrl": "TEST-SHUT", "g": 0.0}]
		Ship.override("cv138", d)
	var g = await _game("cv138")
	var s = g.sys
	var acc = _by_key(g, "ACC-G")
	var vol: String = s.tank_vol(acc)
	var pipes: int = g.world.lines_of(acc).filter(func(l): return l.kind == "pipe").size()
	check(acc != null and s.P(vol) > 2000.0 and pipes > 0, "ACC-G: nitrogen at %.0f kPa, %d hose(s), held by locks" % [s.P(vol), pipes])
	var torn: bool = await _yank(g, acc, Vector2(-1, 0))
	await _frames(3)
	var jet = g.recoil._jet_of(acc, "fit")
	if shut:
		check(torn and jet == null and g.recoil.jets.is_empty(), "torn loose with its valve shut: nothing jets")
	else:
		check(torn and jet != null, "torn loose, the fitting goes: a jet where the hose was")
		var fn: float = float(jet.f) if jet != null else 0.0
		check(fn > 300.0 and fn < 1500.0, "a 16 mm fitting at %.0f kPa: %.0f N" % [s.P(vol), fn])
		await _shot(g, _centre(g, acc), 1.4, "fitting")
	g.bot.lmb = false
	await _done(g)
	Ship._cache.erase("cv138")
