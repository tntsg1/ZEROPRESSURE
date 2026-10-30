extends SceneTree
# The beam into a fission core detonates it at once (user 2026-10-27; scripts/reactor.gd, scripts/nuke.gd),
# real beam: a kerf across the core with a drum unlocked goes prompt critical (equipment round it
# wrecked, a fine, the field over the berth, the heart gone with it); with every drum locked the
# beam reaches the heart, the 3-2-1 count runs and stops when the beam is let go; held, it
# detonates: the cinematic runs to its card, the contract settles void with the fines and
# nothing left to deliver, and a career marks the berth for rebuilding.
#   godot --headless --path . --fixed-fps 60 -s tests/nuke_check.gd

var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_nuke_save.json"
	SaveGame.allow_test = true
	Career.path = "user://zp_test_nuke_career.json"
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
	Game.start_ship = "nr95"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	return scene


func _count(g, kind: String) -> int:
	return g.incidents.filter(func(i): return i[1] == kind).size()


func _m(x: float, y: float) -> Vector2:
	return Vector2(x, y) * Geom.M


# hold the drone still where the beam can reach the core
func _park(g, at: Vector2) -> void:
	g.drone.global_position = at
	g.drone.linear_velocity = Vector2.ZERO
	g.drone.reset_physics_interpolation()


func _run() -> void:
	print("NUKE: the beam into the NR-95 core, drums as they came")
	var g = _game()
	await _frames(70)
	var r = g.reactor
	var core = g.world.tag("CORE")
	check(r.cores.has(core), "the NR-95 core is known as a fission core")
	# a stroke from above down into the core's top edge, with the real beam
	var top: Vector2 = g.world.frame(core) * Geom.centroid(core.poly) + _m(0.0, -1.4)
	_park(g, top + _m(0.0, -3.2))
	# the beam starts a metre short of the core, then is drawn down into it
	g.bot.aim = top + _m(0.0, -1.0)
	g.bot.lmb = true
	var warned := false
	var went := -1.0
	for i in 900:
		_park(g, top + _m(0.0, -3.2))
		if i == 30:
			g.bot.aim = top + _m(0.0, 0.8)
		await process_frame
		if r._near_t > 0.0:
			warned = true
		if g.state == "nuke":
			went = i / 60.0
			break
	g.bot.lmb = false
	check(warned, "the beam closing on the core warns first")
	check(went >= 0.0 and r.nuked, "the beam touches the core: it detonates at once (%.1f s after the press, the cut through the casing first)" % went)
	check(_count(g, "core_detonation") == 1, "the detonation is on the record")
	var nk = g.nuke
	await _frames(20)
	check(not g.world.visible and not g.dock.visible and not g.drone.visible, "the hull, the berth and the drone are gone in the flash")
	check(nk.shards.size() >= 100 and nk.zones.size() == Port.ZONES.size(), "the plating flies as %d shards; the shell reaches all %d districts" % [nk.shards.size(), nk.zones.size()])
	# the montage runs on its own to the card
	var hit_all := false
	for i in 60 * 20:
		await process_frame
		if nk.card:
			hit_all = nk.zones.all(func(z): return z.hit)
			break
	check(nk.card and hit_all, "the shell swept every district, then the card (at %.1f s)" % nk.t)
	await _frames(150)
	nk.skip()
	await _frames(10)
	check(g.ended and g.nuked and g.state == "ending", "any key on the card: the contract settles")
	var keys: Array = g.loss_lines.map(func(l): return l[0])
	check(keys.has("loss_nuke") and keys.has("loss_berth_rebuild") and keys.has("loss_drone"), "the bill: the nuclear fine, the berth rebuilt, the drone")
	check(g.losses >= nk.NUKE_FINE + nk.BERTH_REBUILD and g.pieces_left().is_empty() and g.income_rest == 0.0, "nothing left to deliver, %s lost" % Pal.money(g.losses))
	check(g.settle_report().get("nuke", false), "the settlement says so")
	g.queue_free()
	await _frames(10)

	print("NUKE: every fission core, any ship; not the furnace core")
	for e in [["pt34", "REACT", true], ["ark01", "CORE-M", true], ["ark01", "SEC-R", true], ["mf126", "CORE", false]]:
		Game.contract = {}
		Game.start_ship = e[0]
		var sc: Node = load("res://scenes/main.tscn").instantiate()
		sc.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
		root.add_child(sc)
		await _frames(30)
		var pc = sc.world.tag(e[1])
		sc.on_cut_into(pc, sc.world.frame(pc) * Geom.centroid(pc.poly))
		await _frames(3)
		check((sc.state == "nuke") == e[2], "%s %s cut: %s" % [e[0].to_upper(), e[1], "it detonates" if e[2] else "no detonation (a furnace, not a reactor)"])
		sc.queue_free()
		await _frames(10)

	print("NUKE: a career's berth is marked for rebuilding")
	Career.data = Career.fresh()
	Career.data.active = {"id": "nuke-t", "ship": "nr95", "fee": 0.0, "fee_paid": true}
	var res: Dictionary = Career.settle({"job_id": "nuke-t", "earned": 0.0, "losses": 800000.0, "nuke": true, "grade": 0})
	check(not res.get("save_failed", false) and Career.data.get("berth_rebuild", false), "settled: the berth waits to be rebuilt")
	check(float(Career.data.loan) > 0.0, "a loss past the cash goes onto the loan (%s)" % Pal.money(float(Career.data.loan)))
	Career.save()
	# the next scene: the berth is built again from what is left of it
	Game.cine_in_tests = true
	g = _game()
	await _frames(20)
	g.job = {"id": "nuke-next", "ship": "nr95"}
	g.bot = null
	g.build = null
	g.state = "play"
	g._maybe_build()
	check(g.state == "build" and g.build != null and absf(float(g.build.x_a) - Dock.MIN_REBUILD) < 0.1 and not g.build.quick,
		"the berth is rebuilt from its %.0f m stump, the whole procedure" % (float(g.build.x_a) if g.build != null else -1.0))
	check(not Career.data.has("berth_rebuild"), "once: the mark is cleared")
	Game.cine_in_tests = false
	g.queue_free()
	await _frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	print("NUKE %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
	quit(1 if fails > 0 else 0)
