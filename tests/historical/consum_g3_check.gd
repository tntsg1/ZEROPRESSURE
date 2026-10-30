# Historical G3 acceptance before 2026-10-23 tool-part retirement.
# Current acceptance: tests/consum_check.gd. Input helpers retained for reuse.
extends SceneTree
# G3 acceptance (design/G3_消耗件设计稿_2026-10-21.md): the consumable tool parts.
#   1  a new career has a standard part in each tool; buying, fitting and swapping
#      keep the shelf and the funds straight; a failed write changes nothing
#   2  on the job (the test's bot wears parts): a reading wears the probe by one; a real
#      stroke through a plate wears the lens by what it cut; a grab wears the capacitor
#      by the load's mass; a worn-out part stops its tool
#   3  cheap parts fail when the test says so: the lens bursts on the first bite (the
#      drone scalded, the lens gone), the capacitor lets go within three seconds
#   4  the fine probe shows condition like the inspection kit; the fine capacitor holds 5 t
#   5  a swap asked on site waits for the bay; the job's wear is written back at the end;
#      a mid-job save keeps what is left
#   6  an old career's skill volumes are refunded on load
# Test files only; the player's career is never touched.
# godot --headless --path . --fixed-fps 60 -s tests/consum_check.gd

const BOT := {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "consum": true}
var fails := 0
var checks := 0
var finished := false


func _initialize() -> void:
	Career.path = "user://zp_test_consum_career.json"
	SaveGame.path = "user://zp_test_consum_save.json"
	SaveGame.train_path = "user://zp_test_consum_training.json"
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


# the drone held on its spot, the tool chosen, the pointer on the target and the button pressed
func _click(g, tool: int, at: Vector2, hold_frames: int = 60) -> void:
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


# a laser stroke drawn across a plate by real input: the pointer walks from a to b with the button down
func _stroke(g, a: Vector2, b: Vector2, frames: int = 90) -> void:
	g.tools.set_tool(2, true)
	var spot := (a + b) * 0.5 + Vector2(0, -2.2 * Geom.M)
	for i in frames + 20:
		g.drone.global_position = spot
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		var k := clampf(float(i - 2) / frames, 0.0, 1.0)
		g.bot.aim = a.lerp(b, k)
		g.bot.lmb = i >= 2 and i < frames + 2
		await process_frame
	g.bot.lmb = false
	await _frames(5)


func _top_plate(g) -> Dictionary:
	# the top hull plate of the hold, its outline and a stroke across it
	var p = g.world.piece_at(Vector2(18.0, -3.78) * Geom.M)
	var bb := Geom.bbox(g.world.world_poly(p))
	return {"piece": p, "a": Vector2(bb.position.x + 0.3 * Geom.M, bb.get_center().y), "b": Vector2(bb.position.x + 2.3 * Geom.M, bb.get_center().y)}


func _run() -> void:
	print("CONSUM: a new career")
	Career.data = {}
	Career.start_new()
	var d := Career.data
	for tool in Consum.TOOLS:
		check(int(Consum.fitted(tool).tier) == 1 and float(Consum.fitted(tool).left) == Consum.capacity(tool, 1) and Consum.shelf(tool).is_empty(), "%s: a standard part fitted, the shelf empty" % tool)
	d.market = true
	d.done = 3
	d.money = 20000.0
	d.story_job = {}
	d.active = {}
	Career.save()
	# ---- 1: buying, fitting, swapping
	var good_path := Career.path
	Career.path = "user://"
	var why := Consum.buy("lens", 2)
	Career.path = good_path
	check(why != "" and float(Career.data.money) == 20000.0 and Consum.shelf("lens").is_empty(), "a purchase that cannot be written spends nothing (%s)" % why)
	check(Consum.buy("lens", 2) == "" and float(Career.data.money) == 14000.0 and Consum.shelf("lens").size() == 1 and int(Consum.shelf("lens")[0].tier) == 2, "a fine lens bought onto the shelf")
	check(Consum.buy("cap", 0) == "" and Consum.buy("probe", 0) == "" and float(Career.data.money) == 13100.0, "a cheap capacitor and a cheap probe bought")
	check(Consum.fit("lens", 0) == "" and int(Consum.fitted("lens").tier) == 2 and Consum.shelf("lens").size() == 1 and int(Consum.shelf("lens")[0].tier) == 1, "the fine lens fitted; the standard one back on the shelf with its 120 m")
	check(Consum.fit("cap", 0) == "" and int(Consum.fitted("cap").tier) == 0 and Consum.fit("probe", 0) == "" and int(Consum.fitted("probe").tier) == 0, "the cheap capacitor and probe fitted")
	# ---- 2 & 3: on the job (cheap parts set to fail)
	var ot := Career.take_trial("g1b")
	check(not ot.is_empty() and ot.has("consum") and int(ot.consum.lens.tier) == 2, "the job carries what is fitted")
	Game.start_ship = ot.ship
	Game.contract = Career.active()
	var g = _game()
	await _frames(3)
	for room in ["B", "C"]:
		g.sys.vols[room].n = 0.0
	check(g.has_upgrade("scan_kit") == false, "a cheap probe shows no condition")
	Consum.force_fail = true
	# the cheap capacitor lets go: a plate freed by its fixings (the wrench's handler), held by real input
	var gp = g.world.piece_at(Vector2(22.0, -3.78) * Geom.M)
	for j in g.world.joints_of(gp):
		if j.alive:
			g.do_wrench({"kind": "joint", "joint": j, "pos": g.world.joint_world(j)})
	for l in g.world.lines_of(gp):
		if l.alive:
			g.world.kill_line(l)
	await _frames(3)
	var loose = gp.body
	check(loose != null, "the plate is loose (%.1f t)" % (loose.total_mass() if loose != null else 0.0))
	if loose != null:
		var lp = gp
		var cap0 := Consum.left(g, "cap")
		# the grapple holds while the button is down: pressed, held, then the cheap capacitor's turn
		var at: Vector2 = g.world.frame(lp) * Geom.centroid(lp.poly)
		g.tools.set_tool(3, true)
		var spot := at + Vector2(-1.6 * Geom.M, -0.4 * Geom.M)
		var held := false
		var slipped := false
		for i in 260:
			if i < 6:
				g.drone.global_position = spot
				g.drone.linear_velocity = Vector2.ZERO
				g.drone.reset_physics_interpolation()
			if i == 2:
				g.bot.aim = at
				g.bot.lmb = true
			if i == 4:
				held = g.tools.held_piece == lp
			if i > 4 and held and g.tools.held_piece == null:
				slipped = true
				break
			await process_frame
		g.bot.lmb = false
		await _frames(3)
		check(held and cap0 - Consum.left(g, "cap") >= Consum.CAP_MIN - 0.001, "the grab wore the cheap capacitor by the load (%.2f t)" % (cap0 - Consum.left(g, "cap")))
		check(slipped and Consum.left(g, "cap") == 0.0 and g.incidents.any(func(e): return str(e).find("cap_slip") >= 0), "the cheap capacitor let go within three seconds and is finished")
		await _click(g, 3, g.world.frame(lp) * Geom.centroid(lp.poly), 10)
		check(g.tools.held_piece == null, "a worn-out capacitor holds nothing")
	# the fine lens wears by what it cuts: a stroke across the hold's top plate
	var tp := _top_plate(g)
	await _stroke(g, tp.a, tp.b, 90)
	check(Consum.left(g, "lens") < 300.0 and Consum.left(g, "lens") > 290.0 and tp.piece != null, "the fine lens wore by the plate it cut: %.2f m used" % (300.0 - Consum.left(g, "lens")))
	# the cheap probe: a reading wears it by one and reads off
	var port = g.world.ctrls.get("GAS-D")
	var pr0 := Consum.left(g, "probe")
	await _click(g, 1, g.world.ctrl_world(port), 40)
	var r: Dictionary = g.sys.readings.get("GAS-D", {})
	check(Consum.left(g, "probe") == pr0 - 1.0 and not r.is_empty() and r.has("noise"), "a reading wore the cheap probe by one and carries its noise (%.2f)" % float(r.get("noise", 0.0)))
	# the cheap lens bursts on its first bite
	Consum.force_fail = false
	Career.data.money = 50000.0
	check(Consum.buy("lens", 0) == "", "a cheap lens bought on site")
	g.job.fit_pending = {"lens": Consum.shelf("lens").size() - 1}
	g.drone.global_position = Dock.BAY * Geom.M
	await _frames(3)
	check(g.job.fit_pending.is_empty() and Consum.tier(g, "lens") == 0 and Consum.shelf("lens").any(func(p): return int(p.tier) == 2), "the swap waited for the bay: the cheap lens in, the fine one back on the shelf with its metres")
	Consum.force_fail = true
	var hp0: float = g.drone.integrity
	# another plate still on the ship, next to the first
	var p2 = g.world.piece_at(Vector2(13.0, -3.78) * Geom.M)
	var bb2 := Geom.bbox(g.world.world_poly(p2)) if p2 != null else Rect2()
	var tp2 := {"piece": p2, "a": Vector2(bb2.position.x + 0.3 * Geom.M, bb2.get_center().y), "b": Vector2(bb2.position.x + 2.3 * Geom.M, bb2.get_center().y)}
	if tp2.piece != null:
		await _stroke(g, tp2.a, tp2.b, 60)
	check(Consum.left(g, "lens") == 0.0 and g.drone.integrity < hp0 and g.incidents.any(func(e): return str(e).find("lens_burst") >= 0), "the cheap lens burst as it bit: gone, the drone scalded (%.0f → %.0f)" % [hp0, g.drone.integrity])
	Consum.force_fail = false
	await _stroke(g, tp2.a, tp2.b, 30)
	check(Consum.left(g, "lens") == 0.0 and not g.tools.cutting, "a worn-out lens cuts nothing")
	# ---- 5: saved and read back, then settled
	SaveGame.save(g)
	var probe_left := Consum.left(g, "probe")
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
	check(Consum.left(g, "probe") == probe_left and Consum.left(g, "lens") == 0.0 and Consum.tier(g, "lens") == 0, "read back: the parts as they were")
	g.finish_contract(true)
	await _frames(5)
	check(float(Consum.fitted("probe").left) == probe_left and float(Consum.fitted("lens").left) == 0.0 and float(Consum.fitted("cap").left) == 0.0, "settled: the wear written back to what is fitted")
	g.queue_free()
	await _frames(2)
	# ---- 4: fine parts
	Career.data.money = 50000.0
	check(Consum.buy("probe", 2) == "" and Consum.fit("probe", Consum.shelf("probe").size() - 1) == "" and Consum.buy("cap", 2) == "" and Consum.fit("cap", Consum.shelf("cap").size() - 1) == "", "fine probe and capacitor fitted")
	var oc := Career.take_trial("g1a")
	Game.start_ship = oc.ship
	Game.contract = Career.active()
	g = _game()
	await _frames(3)
	check(g.has_upgrade("scan_kit") and g.grab_max() >= 5.0, "the fine probe reads condition; the fine capacitor holds 5 t")
	g.finish_contract(true)
	await _frames(5)
	g.queue_free()
	await _frames(2)
	# ---- 6: an old career's volumes refunded
	var old := Career.fresh()
	old.erase("consum")
	old.erase("fitted")
	old.done = 2
	old.money = 1000.0
	old.upgrades = {"skill_drive": 2, "skill_laser_power": 1, "grapple5": 1}
	old.growth_goal = "drive"
	old.route_goals = ["skill:drive", "buy:hauler"]
	Career.data = old
	Career.save()
	Career.data = {}
	Career.load_or_new()
	d = Career.data
	check(not d.upgrades.has("skill_drive") and not d.upgrades.has("skill_laser_power") and d.upgrades.has("grapple5") and absf(float(d.money) - (1000.0 + 12000.0 + 63000.0 + 14000.0)) < 1.0, "the volumes refunded (%d), the shop's grapple kept" % int(d.money))
	check(d.growth_goal == "" and d.route_goals == ["buy:hauler"] and d.has("consum") and int(d.fitted.lens.tier) == 1, "no skill goals left; standard parts fitted")
	print("CONSUM %s  (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	finished = true
