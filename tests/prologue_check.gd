extends "res://tests/guide_check.gd"
# 32 号: the asteroid-belt prologue. A new career starts in the belt, not in TS-1: no berth, no
# port; the hulk adrift with a bent mast over its tow eye; six steps taught as they come; the
# cable on, the career goes on at Berth 07 with TUG-001 waiting. Own test saves only.
#   tools/run_test.sh tests/prologue_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_prologue_career.json"
	SaveGame.path = "user://zp_test_prologue_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _step() -> String:
	return str(g.prologue.STEPS[mini(g.prologue.step, g.prologue.STEPS.size() - 1)]) if not g.prologue.done else "done"


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
	await _frames(30)
	check(g.belt and g.prologue != null, "a new career begins in the belt prologue")
	check(not g.dock.visible and g.dock.bounds_body.collision_layer == 0, "no berth out here")
	check(g.tutorial == null, "no TS-1 lessons")
	check(g.prologue._piece("MAST") != null and not g.prologue.mast_free(), "the bent mast is welded over the tow eye")
	await _frames(90)
	Cap.save(root, "res://tests/out/prologue_start_zh.png")
	check(_step() == "fly", "step 1: fly over (%s)" % g.prologue.title.text)
	# 80 号 Q2: the prologue locks the tools too — flying first, then one tool a step
	check(not g.tool_ok(1) and not g.tool_ok(2) and not g.tool_ok(3), "flying: every tool locked (%s)" % g.open_tools_text())
	check(g.drone.global_position.distance_to(g.prologue.hulk_centre()) > 30.0 * Geom.M, "the drone starts at the tug, a good way off")
	g.drone.global_position = g.prologue.hulk_centre() + Vector2(-5, -6) * Geom.M
	await _frames(4)
	check(_step() == "brake", "step 2: stop")
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(50)
	check(_step() == "measure", "step 3: read the hulk")
	check(g.tool_ok(1) and not g.tool_ok(2) and not g.tool_ok(3), "reading: the meter only")
	g.prologue.step_t = g.prologue.STUCK_1 - 0.01
	await _frames(3)
	check(g.prologue.body.text.contains("还没找到"), "20 s stuck: the card adds where to go")
	g.log_op("measure")
	await _frames(4)
	check(_step() == "cut", "step 4: cut the mast")
	check(g.tool_ok(2) and not g.tool_ok(1) and not g.tool_ok(3), "cutting: the laser only")
	Cap.save(root, "res://tests/out/prologue_cut_zh.png")
	var mast = g.prologue._piece("MAST")
	for j in g.world.joints_of(mast).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	await _frames(6)
	mast = g.prologue._piece("MAST")
	check(g.prologue.mast_free(), "cut at its foot, the mast is a body of its own")
	check(_step() == "clear", "step 5: grapple it clear")
	check(g.tool_ok(3) and not g.tool_ok(2), "clearing: the grapple only")
	mast = g.prologue._piece("MAST")
	mast.body.global_position = g.prologue.eye() + Vector2(12, -4) * Geom.M
	mast.body.linear_velocity = Vector2.ZERO
	await _frames(6)
	check(_step() == "tow", "step 6: the cable (%s)" % g.prologue.title.text)
	g.drone.global_position = g.prologue.eye() + Vector2(1, 0) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(3)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	g.prologue._unhandled_input(ev)
	await _frames(3)
	check(Career.data.get("prologue_done", false) and Career.data.get("certified", false), "the cable on: the prologue is done and the career certified")
	check(Career.data.get("seen", {}).has("belt_prelude"), "the tow home is not shown twice")
	await _frames(30)
	print("PROLOGUE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
