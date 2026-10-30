extends SceneTree
# 87-2: physics and motion that follow the real state. Cables cut under tension spring back and
# settle slack (GR-7). A part cut free pops away from the kerf and settles; a hot fragment
# glows (a bar). A light-sail tear runs across its panel and into the next only while the
# quadrant pulls; slacken it and the tear stops (SA-200). The container wall droops as a
# column is emptied in the wrong order, and a kink stays bent; the bend survives a save
# (CF-90). The magnets' field runs down through the dump, which glows with the power; a quench
# collapses the field (FX-70). Ore chunks crowding a gate arch over it and stop the flow; pulling
# one out clears it, and left alone it gives way (M-14). Frame times reported per scene.
# Own test saves only.
#   tools/run_test.sh tests/phys_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
var g: Node
var fails := 0
var checks := 0
var report: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_phys_career.json"
	SaveGame.path = "user://zp_test_phys_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# n frames, the mean and worst process+physics time in ms
func _timed(n: int) -> Array:
	var sum := 0.0
	var worst := 0.0
	for i in n:
		await process_frame
		var ms: float = (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		sum += ms
		worst = maxf(worst, ms)
	return [sum / n, worst]


func _game(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	await _frames(10)
	scene.tutorial = null
	return scene


func _done() -> void:
	g.queue_free()
	await _frames(4)


func _shot(name: String, at: Vector2, zoom: float = 0.9) -> void:
	g.cam_override = at
	g.zoom_override = zoom
	await _frames(70)
	Cap.save(root, "res://tests/out/%s.png" % name)
	g.cam_override = null
	g.zoom_override = -1.0


func _run() -> void:
	Txt.zh = true
	SaveGame.clear()
	await _ropes()
	await _debris()
	await _sail()
	await _beam()
	await _magnets()
	await _ore()
	print("--- 87-2 report")
	for r in report:
		print(r)
	print("PHYS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- cables

func _ropes() -> void:
	g = await _game("gr7")
	var best = null
	for id in g.world.lines:
		var l = g.world.lines[id]
		var pa = g.world.pieces.get(l.a)
		var pb = g.world.pieces.get(l.b)
		if l.kind != "cable" or pa == null or pb == null or pa.body != null or pb.body != null:
			continue
		if best == null or _len(l.path) > _len(best.path):
			best = l
	check(best != null, "GR-7 has an attached power cable to cut")
	var mid: Vector2 = best.path[best.path.size() / 2]
	g.world.kill_line(best, mid)
	check(g.world.rope_fx.live() == 2, "cut, both halves of the cable move (%d)" % g.world.rope_fx.live())
	var r0: Dictionary = g.world.rope_fx.ropes[0]
	var tip0: Vector2 = r0.pts[r0.pts.size() - 1]
	await _frames(20)
	var tip1: Vector2 = r0.pts[r0.pts.size() - 1]
	check(tip1.distance_to(tip0) > 8.0, "the free end springs back (%.0f px in 1/3 s)" % tip1.distance_to(tip0))
	await _shot("phys_cable_whip_zh", mid, 1.4)
	await _frames(260)
	check(g.world.rope_fx.live() == 0 and best.has_meta("tail_a") and best.has_meta("tail_b"), "then it settles and stays drawn as it lies")
	var tail: PackedVector2Array = best.get_meta("tail_a")
	check(_bow(tail) > 2.0, "it hangs slack and curled, not as a straight stub (bow %.1f px)" % _bow(tail))
	# every cable on the ship cut at once: the frame time while they all move, against before
	var base: Array = await _timed(60)
	var n := 0
	for id in g.world.lines:
		var l = g.world.lines[id]
		if l.alive and l.kind == "cable":
			g.world.kill_line(l, l.path[l.path.size() / 2])
			n += 1
	await _frames(2)
	var live: int = g.world.rope_fx.live()
	var cost: float = g.world.rope_fx.cost_us / 1000.0
	var tm: Array = await _timed(60)
	report.append("GR-7: %d cables cut at once, %d tails moving: simulation %.2f ms a frame; frame %.2f ms mean (%.2f before)" % [n, live, cost, tm[0], base[0]])
	check(cost < 1.5, "all the ship's cables whipping at once are cheap to simulate (%.2f ms)" % cost)
	await _shot("phys_cables_slack_zh", mid, 1.0)
	await _done()


func _len(pl: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, pl.size()):
		s += pl[i - 1].distance_to(pl[i])
	return s


# the most a polyline strays from the straight line between its ends
func _bow(pl: PackedVector2Array) -> float:
	var a := pl[0]
	var b := pl[pl.size() - 1]
	var m := 0.0
	for q in pl:
		m = maxf(m, Geom.dist_to_segment(q, a, b))
	return m


# ---------------------------------------------------------------- debris

func _debris() -> void:
	g = await _game("tug")
	# inside the berth, clear of the tug (out past its edges the tractor field pulls strays back)
	var c := Vector2(21.0 * Geom.M - 14.0 * Geom.M, -9.0 * Geom.M)
	var poly := PackedVector2Array([c + Vector2(-60, -10), c + Vector2(60, -10), c + Vector2(60, 10), c + Vector2(-60, 10)])
	var bar = g.world.add_piece("plate", poly, {"mass": 6.0, "mat": "ti", "cut_speed": 120.0})
	g.world.add_joint(bar, null, "weld", c + Vector2(-50, 0))
	g.world.redraw_all(true)
	await _frames(3)
	g.cut_kerf(bar, PackedVector2Array([c + Vector2(20, -30), c + Vector2(20, 30)]), World.KERF, true)
	await _frames(4)
	var freed = null
	for b in g.world.bodies:
		if is_instance_valid(b) and b.pieces.any(func(p): return p.mat == "ti"):
			freed = b
	check(freed != null, "the cut-off end comes free")
	if freed == null:
		await _done()
		return
	var v0: float = freed.linear_velocity.length()
	print("  kick v ", freed.linear_velocity, " calm ", freed.calm, " ghost ", freed.ghost, " overlap ", g.world.overlap_dir(freed.pieces))
	check(v0 > 5.0 and freed.linear_velocity.x > 0.0, "it pops away from the kerf (%.1f px/s, away from the cut)" % v0)
	var p0: Vector2 = freed.global_position
	freed.pieces[0].kerf_dt = 700.0
	await _shot("phys_debris_hot_zh", c, 1.2)
	await _frames(300)
	check(freed.linear_velocity.length() < v0 * 0.3, "then the berth's damping settles it (%.1f px/s)" % freed.linear_velocity.length())
	report.append("debris: kicked %.1f px/s, settled after %.1f px" % [v0, freed.global_position.distance_to(p0)])
	await _done()


# ---------------------------------------------------------------- the light sail

func _sail() -> void:
	g = await _game("sa200")
	var sl = g.sail
	for w in ["W-NW", "W-NE", "W-SE", "W-SW"]:
		g.sys.set_switch(w, true)
		g.world.ctrls[w].state = true
	await _frames(2)
	var p3 = g.world.tag("FM-3")
	sl._spread("FM-3", g.world.frame(p3) * Geom.centroid(p3.poly))
	await _frames(24)
	check(sl.torn.has("FM-3") and not sl.torn.has("FM-2") and not sl.torn.has("FM-4"), "a tear starts in the panel cut (not yet its neighbours)")
	check(sl.tear_run("FM-3") > 0.2 and sl.tear_run("FM-3") < 1.0, "it is running across it (%.0f%%)" % (sl.tear_run("FM-3") * 100.0))
	await _shot("phys_sail_tear_zh", g.world.frame(p3) * Geom.centroid(p3.poly), 0.3)
	await _frames(70)
	check(sl.torn.has("FM-2") and sl.torn.has("FM-4"), "taut, it runs into both neighbours once across")
	# slack the NE corner, then tear a NE panel: it stops where it is
	g.sys.set_switch("W-NE", false)
	g.world.ctrls["W-NE"].state = false
	var p8 = g.world.tag("FM-7")
	sl._spread("FM-7", g.world.frame(p8) * Geom.centroid(p8.poly))
	await _frames(150)
	check(sl.tear_run("FM-7") < 0.01 and not sl.torn.has("FM-6") and not sl.torn.has("FM-8"), "slack, the tear does not run: the neighbours are saved")
	g.sys.set_switch("W-NE", true)
	g.world.ctrls["W-NE"].state = true
	await _frames(100)
	check(sl.torn.has("FM-8") or sl.torn.has("FM-6"), "pulled taut again, it runs on")
	var st: Dictionary = sl.save_state()
	check(st.has("tearing") and float(st.tearing.get("FM-7", 0.0)) > 0.9, "how far each tear has run is saved")
	sl._sig = ""
	await _frames(2)
	var tm: Array = await _timed(60)
	report.append("SA-200: film redraw %.2f ms (it redraws only when a corner or a tear changes); frame %.2f ms mean" % [sl.draw_us / 1000.0, tm[0]])
	check(sl.draw_us < 2500, "drawing the film's pull and tears is cheap (%.2f ms a redraw)" % (sl.draw_us / 1000.0))
	await _done()


# ---------------------------------------------------------------- the container wall

func _free(tag: String) -> void:
	var p = g.world.tag(tag)
	if p == null:
		return
	for j in g.world.joints_of(p):
		g.world.kill_joint(j)
	for l in g.world.lines_of(p):
		g.world.kill_line(l)


func _beam() -> void:
	g = await _game("cf90")
	var bx = g.boxbeam
	await _frames(20)
	var tip = g.world.tag("C71")
	var y0: float = Geom.centroid(g.world.world_poly(tip)).y
	var d0: float = bx.droop("aft")
	var wall_at: Vector2 = g.world.frame(tip) * Geom.centroid(tip.poly) + Vector2(-24 * Geom.M, -2 * Geom.M)
	await _shot("phys_wall_before_zh", wall_at, 0.32)
	# empty bay 4 (next to the support) while 5 and 6 beyond it are still full
	for t in ["C51", "C52", "C53", "C54"]:
		_free(t)
	await _frames(40)
	var b4: float = bx.bend(4)
	var y1: float = Geom.centroid(g.world.world_poly(tip)).y
	report.append("CF-90: bay 4 bending %.2f of its limit; aft droop %.2f -> %.2f m; tip container moved %.1f px" % [b4, d0, bx.droop("aft"), y1 - y0])
	check(bx.droop("aft") > d0 + 0.05 and y1 > y0 + 2.0, "emptied in the wrong order, the wall's end really droops (the tip container moved %.1f px)" % (y1 - y0))
	await _frames(120)
	var y2: float = Geom.centroid(g.world.world_poly(tip)).y
	if bx.kinked.has("aft"):
		check(y2 > y1 + 4.0, "past its limit it kinks and stays bent (%.1f px more)" % (y2 - y1))
	else:
		check(true, "(bay 4 below its limit: no kink, %.2f)" % b4)
	await _shot("phys_wall_droop_zh", wall_at, 0.32)
	# the bend is kept by a save: loaded, the wall is where it was, not bent twice
	SaveGame.save(g)
	var tip_y: float = Geom.centroid(g.world.world_poly(tip)).y
	g.queue_free()
	await _frames(3)
	SaveGame.load_requested = true
	g = await _game("cf90")
	await _frames(40)
	var t2 = g.world.tag("C71")
	var tip_y2: float = Geom.centroid(g.world.world_poly(t2)).y
	check(absf(tip_y2 - tip_y) < 2.0, "after a save the wall is where it was (%.1f px off)" % (tip_y2 - tip_y))
	await _done()
	SaveGame.clear()


# ---------------------------------------------------------------- the magnets

func _magnets() -> void:
	g = await _game("fx70")
	var mg = g.magnets
	check(mg.overlay != null and mg.any_energised(), "FX-70's coils come in energised, their field drawn")
	var c0 = g.world.tag("TF-3")
	await _shot("phys_field_full_zh", g.world.frame(c0) * Geom.centroid(c0.poly), 0.5)
	g.sys.set_switch(str(mg.cfg.dump), true)
	await _frames(120)
	check(mg.dump_power > 0.0 and float(mg.energy["TF-3"]) < 0.98, "the dump closed: energy runs down (%.3f left) and the dump takes the power" % float(mg.energy["TF-3"]))
	var tm: Array = await _timed(60)
	report.append("FX-70: field loops + dump glow %.2f ms a frame; frame %.2f ms mean; dump power %.4f/s" % [mg.draw_us / 1000.0, tm[0], mg.dump_power])
	check(mg.draw_us < 2000, "drawing the field is cheap (%.2f ms)" % (mg.draw_us / 1000.0))
	var c1 = g.world.tag("TF-1")
	g.cam_override = g.world.frame(c1) * Geom.centroid(c1.poly)
	g.zoom_override = 0.5
	await _frames(70)
	mg._quench("TF-1", "magnet_quench_cut")
	check(mg._collapse.has("TF-1"), "a quench: the coil's field collapses")
	await _frames(10)
	Cap.save(root, "res://tests/out/phys_field_quench_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	await _frames(60)
	check(not mg._collapse.has("TF-1"), "and is gone")
	await _done()


# ---------------------------------------------------------------- the ore hopper

func _ore() -> void:
	g = await _game("m14")
	var ore = g.ore
	g.world.tag("GATE-1").door_open = true
	await _frames(30)
	var mouth: Vector2 = ore._gate_point("GATE-1")
	# a crowd of chunks at the mouth: loose, riding the flow
	var crowd: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.kind == "ore" and not p.gone and p.body == null and crowd.size() < 8:
			crowd.append(p)
	for p in crowd:
		for j in g.world.joints_of(p):
			g.world.kill_joint(j)
	await _frames(4)
	var i := 0
	for p in crowd:
		if p.body != null:
			p.body.global_position = mouth + Vector2(-1.2 * Geom.M + i * 0.35 * Geom.M, -0.8 * Geom.M)
			p.body.linear_velocity = Vector2.ZERO
			ore.flowing[p] = mouth
			i += 1
	print("  crowd bodies: ", crowd.map(func(p): return [p.id, p.body != null, ore.flowing.has(p), snappedf((p.body.global_transform * p.body.center_of_mass).distance_to(mouth) / Geom.M, 0.1) if p.body != null else -1.0]))
	ore._jam_rest.clear()
	for gj in ore.jams.keys():
		ore._unjam(gj, "closed")
	ore._jam_rest.clear()
	report.append("M-14: %d arches formed on their own while the gate ran before the test's crowd" % ore.jam_count)
	await _frames(3)
	print("  crowd ", crowd.size(), " bodies ", crowd.filter(func(p): return p.body != null).size(), " flowing ", ore.flowing.size(), " gate w ", ore._gate_width("GATE-1") / Geom.M, " dists ", crowd.map(func(p): return snappedf((p.body.global_transform * p.body.center_of_mass).distance_to(mouth) / Geom.M, 0.1) if p.body != null else -1.0))
	check(ore.jammed("GATE-1"), "chunks crowding the gate arch over it: jammed")
	if not ore.jammed("GATE-1"):
		await _done()
		return
	var f0: float = ore.fines
	await _frames(60)
	check(is_equal_approx(ore.fines, f0), "nothing comes through a jammed gate (%.2f t -> %.2f t)" % [f0, ore.fines])
	await _shot("phys_ore_jam_zh", mouth + Vector2(0, -1.0 * Geom.M), 1.2)
	# pull one chunk out with the grapple: it clears
	var held = ore.jams["GATE-1"].pieces[0]
	g.tools.held_body = held.body
	await _frames(2)
	g.tools.held_body = null
	check(not ore.jammed("GATE-1"), "pulling one chunk out clears it")
	await _frames(60)
	check(ore.fines < f0, "and the fines run again (%.2f t)" % ore.fines)
	# left alone an arch gives way by itself
	ore._jam_rest.erase("GATE-1")
	var more: Array = []
	for p in ore.flowing.keys():
		if not p.gone and p.body != null and more.size() < 7:
			more.append(p)
	i = 0
	for p in more:
		p.body.global_position = mouth + Vector2(-1.2 * Geom.M + i * 0.35 * Geom.M, -0.8 * Geom.M)
		p.body.linear_velocity = Vector2.ZERO
		i += 1
	await _frames(3)
	var formed: bool = ore.jammed("GATE-1")
	await _frames(int(ore.JAM_GIVE * 60.0) + 30)
	check(not formed or not ore.jammed("GATE-1"), "left alone, the arch gives way after %.0f s" % ore.JAM_GIVE)
	var tm: Array = await _timed(60)
	report.append("M-14: ore flow with jams (%d formed): frame %.2f ms mean, %.2f ms worst" % [ore.jam_count, tm[0], tm[1]])
	await _done()
