extends SceneTree
# AX-40 逆火 (scripts/antimatter.gd, scripts/annihilation.gd; design/新船点子_10艘_详细版_20261111.md §4):
# the trap's confinement on the main bus only. Every way of losing the bus annihilates it at once —
# the main switch, a cable of the chain cut, the magnet supply's connector pulled, the battery taken
# out, the beam into the trap; the wrench's pointer or the beam near the chain warns first; the right
# way (measure, the portable confinement supply on, dual supply, the bus off, the trap unbolted and
# craned whole into the antimatter cradle) takes it out with nothing lost and pays $80,000; the
# portable supply taken back with the bus dead annihilates it; the mouths keep the trap and the rest
# apart; an annihilation settles like the detonation (drone, berth rebuilt, the fine).
#   godot --headless --path . --fixed-fps 60 -s tests/ax40_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_ax40_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_ax40_career.json"
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "ax40"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _done(g) -> void:
	g.queue_free()
	# a vented room leaves the gas grid's worker (and the autosave's writer) busy a while: a new ship
	# straight on top of it, or quitting, crashes the engine on the way out
	await _frames(240)


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _confine(g) -> void:
	var tr = g.anti.trap
	g.gear.act({"kind": "place", "type": "confine", "piece": tr, "pos": g.world.frame(tr) * Geom.centroid(tr.poly)})


func _cut_line(g, id: String) -> void:
	var l = g.world.lines[id]
	var path: PackedVector2Array = g.world.line_path_world(l)
	var mid := path[path.size() / 2].lerp(path[path.size() / 2 - 1], 0.5)
	var d: Vector2 = (path[path.size() / 2] - path[path.size() / 2 - 1]).normalized().orthogonal()
	for hit in g.world.cut_lines(PackedVector2Array([mid - d * 30.0, mid + d * 30.0])):
		g.on_line_cut(hit[0], hit[1])


func _unplug(g, id: String, piece_tag: String) -> void:
	var l = g.world.lines[id]
	var p = g.world.tag(piece_tag)
	var end := 0 if l.a == p.id else 1
	g.do_wrench({"kind": "connector", "line": l, "end": end, "pos": g.world.line_end_world(l, end)})


func _gone_up(g, n: int = 30) -> bool:
	for i in n:
		await process_frame
		if g.state == "nuke":
			return true
	return g.state == "nuke"


func _run() -> void:
	print("AX40: the ship as it comes")
	var g = _game()
	await _frames(90)
	var a = g.anti
	check(a != null and a.active() and a.trap != null, "the antimatter trap is known")
	check(a.main_volts() > 1.0 and a.armed, "the trap is confined on the main bus (%.0f V) and armed" % a.main_volts())
	check(Dock.ZONES.has("anti") and Dock.kind("anti") == "anti", "the berth has the antimatter cradle")
	check(g.has_upgrade("crane") and g.crane != null, "the job lends the crane for the 9 t trap")
	check(g.gear.carried.any(func(it): return it.type == "confine" and it.lent), "the portable confinement supply is lent with the ship")
	check(not g.world.tag("TRAP").has_meta("segments") or (g.world.tag("TRAP").get_meta("segments", []) as Array).is_empty(), "the trap carries no marked cut lines")
	g.do_measure(_ctrl(g, "CONF"))
	var rd: Dictionary = g.sys.readings.get("CONF", {})
	check(str(rd.get("text", "")).find("断电即湮灭") >= 0 or str(rd.get("text", "")).find("LOSE IT") >= 0, "the readout says it: %s" % str(rd.get("text", "")))
	await _frames(180)
	check(g.state == "play" and a.done == "", "left alone three seconds: nothing happens")
	# the wrench's pointer at the main switch: the chain flares, nothing thrown
	g.tools.tool = 2
	var km: Vector2 = g.world.ctrl_world(g.world.ctrls["K-M"])
	g.bot.aim = km + Vector2(20, 0)
	await _frames(20)
	check(a._near_t > 0.0 and a._warn_k > 0.0, "the wrench near the main switch: the chain warns")
	check(g.state == "play", "a warning only: the trap is still confined")
	# the main switch thrown with nothing else on it
	g.do_wrench(_ctrl(g, "K-M"))
	check(await _gone_up(g), "the main switch off with no portable supply: it annihilates at once")
	check(_count(g, "annihilation") == 1 and a.done == "annihilated", "the annihilation is on the record")
	await _frames(100)
	check(not g.world.visible and not g.drone.visible, "the hull and the drone are gone")
	# the card, then the settlement
	var nk = g.nuke
	for i in 60 * 12:
		await process_frame
		if nk.card:
			break
	check(nk.card, "the cinematic runs to its card (%.1f s)" % nk.t)
	await _frames(150)
	nk.skip()
	await _frames(10)
	check(g.ended and g.nuked, "any key on the card: the contract settles")
	var keys: Array = g.loss_lines.map(func(l): return l[0])
	check(keys.has("loss_anni") and keys.has("loss_berth_rebuild") and keys.has("loss_drone"), "the bill: the antimatter fine, the berth rebuilt, the drone")
	await _done(g)

	print("AX40: every other way of losing the bus")
	for way in ["cut_A1", "cut_A2", "unplug_A2", "cut_p1", "battery_out", "supply_cut"]:
		g = _game()
		await _frames(90)
		a = g.anti
		match way:
			"cut_A1": _cut_line(g, "A1")
			"cut_A2": _cut_line(g, "A2")
			"cut_p1": _cut_line(g, "p1")
			"unplug_A2": _unplug(g, "A2", "TRAP")
			"battery_out":
				# the battery taken out: its connector pulled, its bolts undone
				_unplug(g, "p1", "BAT-E")
			"supply_cut":
				var mps = g.world.tag("MPS")
				var c: Vector2 = g.world.frame(mps) * Geom.centroid(mps.poly)
				g.on_cut_into(mps, c)
				g.on_kerf(mps, g.world.commit_cut(mps, PackedVector2Array([c + Vector2(-80, -40), c + Vector2(80, -40), c + Vector2(80, -30), c + Vector2(-80, -30)])))
		check(await _gone_up(g, 40), "%s: it annihilates at once" % way)
		await _done(g)

	print("AX40: the beam into the trap annihilates it even on the portable supply")
	g = _game()
	await _frames(90)
	a = g.anti
	_confine(g)
	await _frames(150)
	check(a.portable(), "the portable supply carries the trap")
	var tr = a.trap
	var tc: Vector2 = g.world.frame(tr) * Geom.centroid(tr.poly)
	g.on_cut_into(tr, tc + Vector2(0, -96))
	g.on_kerf(tr, g.world.commit_cut(tr, PackedVector2Array([tc + Vector2(-140, -100), tc + Vector2(140, -100), tc + Vector2(140, -92), tc + Vector2(-140, -92)])))
	check(await _gone_up(g, 40), "a cut into the trap: it annihilates")
	await _done(g)

	print("AX40: the right way")
	g = _game()
	await _frames(90)
	a = g.anti
	g.do_measure(_ctrl(g, "CONF"))
	_confine(g)
	await _frames(30)
	check(not a.portable() and a.portable_k() > 0.0, "the portable supply taking up the load (%.0f %%)" % (a.portable_k() * 100.0))
	await _frames(120)
	check(a.portable() and a.reading()[0] == 2.0, "dual supply: %s" % str(a.reading()[1]))
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(60)
	check(g.state == "play" and a.done == "" and a.main_volts() < 1.0, "the main switch off: the bus dead, the trap still confined")
	check(str(a.reading()[1]).find("便携") >= 0 or str(a.reading()[1]).find("PORTABLE") >= 0, "the readout: %s" % str(a.reading()[1]))
	# the chain no longer warns: cutting a chain cable now is harmless
	_cut_line(g, "A1")
	await _frames(30)
	check(g.state == "play", "on the portable supply, the chain's cable cut does nothing")
	# vent the hall, then unbolt the trap and pull its lead
	g.do_hose(_ctrl(g, "G-T"))
	for i in 60 * 30:
		await process_frame
		if g.sys.P("T") < 5.0:
			break
	tr = a.trap
	for j in g.world.joints_of(tr).duplicate():
		if j.type in ["bolt", "lock"]:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
			await _frames(2)
	for l in g.world.lines_of(tr).duplicate():
		var end := 0 if l.a == tr.id else 1
		g.do_wrench({"kind": "connector", "line": l, "end": end, "pos": g.world.line_end_world(l, end)})
	await _frames(20)
	check(tr.body != null and g.state == "play", "the trap is free, still confined")
	check(tr.body.total_mass() > 8.0 and tr.body.total_mass() <= Methods.crane_t(), "9 t: a crane load (%.1f t)" % tr.body.total_mass())
	check(g.crane._zone_for(tr.body) == "anti", "the crane takes it to the antimatter cradle")
	# a stray piece at the cradle is refused; the trap at the equipment bay is refused
	var j_eq: Dictionary = g.judge(tr.body, "equip")
	check(not j_eq.ok and j_eq.reason == "rej_anti_mouth", "the equipment bay refuses the trap")
	check(not g.judge(tr.body, "hazard").ok, "the hazard bay refuses it too")
	var b = tr.body
	var mouth: Vector2 = Dock.zpos("anti")
	for i in 60 * 8:
		if tr.gone:
			break
		if is_instance_valid(b):
			b.global_position = mouth - b.global_transform.basis_xform(b.center_of_mass)
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
		await process_frame
	check(tr.gone and tr.into == "anti", "the trap goes into the antimatter cradle whole")
	await _frames(10)
	var paid: float = 0.0
	for l in g.ledger:
		if l[1] == "anti":
			paid += float(l[2])
	check(paid >= 79000.0, "it pays its worth (%s)" % Pal.money(paid))
	check(a.done == "delivered" and g.state == "play" and _count(g, "annihilation") == 0, "nothing annihilated, the portable supply handed over with it")
	check(g.mandatory_ok.has("TRAP"), "the trap counts as delivered")
	await _done(g)

	print("AX40: the portable supply taken back with the bus dead")
	g = _game()
	await _frames(90)
	a = g.anti
	_confine(g)
	await _frames(150)
	g.do_wrench(_ctrl(g, "K-M"))
	await _frames(30)
	check(g.state == "play", "on the portable supply with the bus off")
	g.gear.retrieve(g.gear.units.filter(func(u): return u.type == "confine")[0])
	check(await _gone_up(g, 40), "the portable supply taken back: it annihilates")
	await _done(g)

	# the gas grid's worker may still be busy with the vented hall: let it finish before the engine quits
	await _frames(240)
	print("AX40: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	finished = true
