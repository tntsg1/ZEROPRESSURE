extends "res://tests/guide_check.gd"
# 公测反馈 #10 (2026-11-13): the belt prologue's marks on what they mean. Each step: the mark inside its target's
# box (the hulk, the mast's welds, the loose mast, the tow eye), on the screen from where the step begins. The
# cut step's welds are cut with the laser where the mark is (the bot's aim on them): the mast comes free, and
# nothing goes off. The laser's light softer and off the guide's orange. Shots in tests/out/prologue_marks/.
#   tools/run_test.sh tests/prologue_marks_check.gd --fixed-fps 60                 (-- --demo: the public build)
#   ... -- --before    (Prologue.MARK_ON / CutawayLight.SOFT_ON off: the before pictures)
const Prologue = preload("res://scripts/prologue.gd")
const CutawayLight = preload("res://scripts/cutaway_light.gd")
var before := false
var demo := false
var tag := ""


func _initialize() -> void:
	Career.path = "user://zp_test_prologue_marks_career.json"
	SaveGame.path = "user://zp_test_prologue_marks_save.json"
	SaveGame.allow_test = true
	before = OS.get_cmdline_user_args().has("--before")
	demo = OS.get_cmdline_user_args().has("--demo")
	if before:
		Prologue.MARK_ON = false
		CutawayLight.SOFT_ON = false
	if demo:
		preload("res://scripts/demo.gd").forced = true
	tag = ("_demo" if demo else "") + ("_before" if before else "")
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _step() -> String:
	return str(g.prologue.STEPS[mini(g.prologue.step, g.prologue.STEPS.size() - 1)]) if not g.prologue.done else "done"


func _box(p) -> Rect2:
	return Geom.bbox(g.world.world_poly(p))


func _on_screen(at: Vector2) -> bool:
	return ViewCull.view(g).grow(-40.0).has_point(at)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out/prologue_marks"))
	root.get_viewport().get_texture().get_image().save_png("res://tests/out/prologue_marks/%s%s.png" % [name, tag])


func _settle(n := 40) -> void:
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(n)


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	Career.data.term_open = {}
	Career.save()
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	var pr = g.prologue
	check(g.belt and pr != null, "the belt prologue is up%s" % (" (the public build)" if demo else ""))
	if pr == null:
		quit()
		return
	var keel = pr._keel()
	var mast = pr._piece("MAST")
	# the hulk: every piece still on the keel's frame
	var hulk := Rect2()
	for p in g.world.pieces.values():
		if not p.gone and p != mast:
			hulk = _box(p) if hulk.size == Vector2.ZERO else hulk.merge(_box(p))
	# ---- 1-3: fly, brake, measure — the mark on the hulk
	for s in ["fly", "brake", "measure"]:
		check(_step() == s, "step %s" % s)
		var at: Vector2 = pr._target()
		check(hulk.grow(0.5 * Geom.M).has_point(at), "  %s: the mark on the hulk (%s in %s)" % [s, str(at / Geom.M), str(hulk.size / Geom.M)])
		if s == "fly":
			g.drone.global_position = pr.hulk_centre() + Vector2(-5, -6) * Geom.M
			await _frames(4)
		elif s == "brake":
			await _settle(50)
		else:
			check(_on_screen(at), "  measure: the mark on the screen from where the drone stopped")
			g.log_op("measure")
			await _frames(4)
	# ---- 4: cut — on the welds, not the tow eye
	check(_step() == "cut", "step cut")
	await _settle(30)
	var welds: Array = pr.welds()
	var at4: Vector2 = pr._target()
	check(not welds.is_empty(), "cut: the mast is held by %d welds" % welds.size())
	var near_weld := welds.any(func(q): return (q as Vector2).distance_to(at4) < 1.5 * Geom.M) or (not welds.is_empty() and at4.distance_to(welds.reduce(func(a, q): return a + q, Vector2.ZERO) / welds.size()) < 0.1)
	var on_mast := _box(mast).grow(1.0 * Geom.M).has_point(at4)
	print("  cut mark %s · welds %s · eye %s · mast box %s" % [str(at4 / Geom.M), str(welds.map(func(q): return q / Geom.M)), str(pr.eye() / Geom.M), str(_box(mast).position / Geom.M)])
	if not before:
		check(near_weld and on_mast, "cut: the mark on the mast's welds, inside the mast's box")
		check(at4.distance_to(pr.eye()) > 0.5 * Geom.M or on_mast, "cut: not on the empty tow eye")
	check(_on_screen(at4), "cut: the mark on the screen from the hulk")
	await _shot("cut_mark")
	# the laser where the mark is: weld by weld, the bot's aim on each
	g.tools.set_tool(2, true)
	await _frames(4)
	var inc0: int = g.incidents.size()
	g.bot = {"aim": at4, "lmb": false, "move": Vector2.ZERO}
	var shot_taken := false
	for wi in 12:
		var ws: Array = pr.welds()
		if ws.is_empty():
			break
		var q: Vector2 = ws[0]
		g.drone.global_position = q + Vector2(-2.2, -2.2) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO
		for f in 150:
			# sweep a little across the weld
			g.bot.aim = q + Vector2(0.4 * sin(f * 0.12), 0.4 * cos(f * 0.09)) * Geom.M
			g.bot.lmb = true
			g.drone.linear_velocity = Vector2.ZERO
			await _frames(1)
			if f >= 4 and not shot_taken and g.tools.cutting:
				shot_taken = true
				await _shot("laser_light")
			if pr.welds().size() < ws.size() or pr.mast_free():
				break
	g.bot.lmb = false
	await _frames(10)
	check(pr.mast_free() or pr.welds().is_empty(), "cut where the mark is: the mast comes free (%d welds left)" % pr.welds().size())
	check(g.incidents.size() == inc0, "cut where the mark is: nothing goes off %s" % str(g.incidents.slice(inc0)))
	# ---- 5: clear — the mark on the loose mast
	await _frames(6)
	if _step() == "clear":
		mast = pr._piece("MAST")
		var at5: Vector2 = pr._target()
		check(mast != null and _box(mast).grow(0.5 * Geom.M).has_point(at5), "clear: the mark on the loose mast")
		check(_on_screen(at5), "clear: on the screen")
		mast.body.global_position = pr.eye() + Vector2(12, -4) * Geom.M
		mast.body.linear_velocity = Vector2.ZERO
		await _frames(8)
	# ---- 6: tow — the eye, on the stern frame
	check(_step() == "tow", "step tow (%s)" % _step())
	var at6: Vector2 = pr._target()
	var on_stern := false
	for p in g.world.pieces.values():
		if not p.gone and p != pr._piece("MAST") and _box(p).grow(0.8 * Geom.M).has_point(at6):
			on_stern = true
	check(on_stern, "tow: the eye is on the hulk's stern frame (%s)" % str(at6 / Geom.M))
	g.drone.global_position = at6 + Vector2(-4, -3) * Geom.M
	await _settle(30)
	check(_on_screen(at6), "tow: on the screen")
	g.bot = null
	print("PROLOGUE MARKS %s (%d checks, %d failed)%s" % ["PASS" if fails == 0 else "FAIL", checks, fails, tag])
	g.queue_free()
	await _frames(4)
	quit()
