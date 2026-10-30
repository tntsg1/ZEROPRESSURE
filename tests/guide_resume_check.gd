extends SceneTree
# The port's guides (user 2026-10-28: "新手导览必须一次做完…做完一半之后重新进来还得重新再玩"; "开发者
# 模式，我明明都跳过了，还要我再做一次"):
#  - the port walk cut short and picked up again starts at the very step it reached (legs back to
#    it first when the drone is elsewhere, not counted), and goes on saving the step it is at
#  - the belt prologue cut short starts again at its step, or at the last one the hulk allows
#  - the developer's skip leaves nothing running and nothing waiting in that career
# Own test career and saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/guide_resume_check.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Career.path = "user://zp_test_guide_resume_career.json"
	SaveGame.path = "user://zp_test_guide_resume_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _berth():
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	g.tutorial = null
	return g


# what is running or waiting in this game: a list of names
func _guides(g) -> Array:
	var out: Array = []
	if g.walk_on():
		out.append("port_walk")
	if g.port_tour != null and is_instance_valid(g.port_tour):
		out.append("port_tour")
	if g.coach_on():
		out.append("first_ship")
	if g.prologue != null and is_instance_valid(g.prologue) and not g.prologue.done:
		out.append("prologue")
	if preload("res://scripts/port_walk.gd").due():
		out.append("port_walk due")
	if preload("res://scripts/port_tour.gd").due():
		out.append("port_tour due")
	if Onboard.active():
		out.append("onboard " + Onboard.stage())
	return out


func _run() -> void:
	# a career past its first ship, the walk not done
	Career.start_new()
	DevPanel.skip_guides()
	var seen: Dictionary = Career.data.seen
	seen.erase("port_walk")
	seen.erase("port_walk_started")
	Career.data.seen = seen
	Career.data.erase("guide_at")
	Career.save()

	# ---- the walk, cut short at the ring's console (108 号: the first walk is the core only), picked up again
	var g = await _berth()
	g.start_port_walk(true)
	await _frames(5)
	var pw = g.port_walk
	check(pw != null and pw.step == 0 and pw.back.is_empty(), "the first walk starts at its first step")
	var at := -1
	for i in pw.steps.size():
		if pw.steps[i] == ["console", "ring"]:
			at = i
	pw.step = at - 1
	pw.next_step()
	check(Career.guide_at("port_walk") == at, "each step reached is kept (%d, the ring's console)" % Career.guide_at("port_walk"))
	g.queue_free()
	await _frames(3)
	g = await _berth()
	g.start_port_walk(true)
	await _frames(5)
	pw = g.port_walk
	var legs: Array = pw.back.map(func(l): return str(l[0]) + ":" + str(l[1]))
	check(pw.step == at and pw.kind() == "gate", "picked up again at that very step (%d), out of the berth first" % pw.step)
	check(legs == ["gate:", "hub:"], "the legs back to it: %s" % str(legs))
	check(not pw.forced, "a walk picked up again can be ended")
	# the legs pass: none of them is kept as the tour's step
	for i in 2:
		pw.next_step()
	check(pw.back.is_empty() and pw.kind() == "console" and pw.zone() == "ring", "after the legs: the ring's console step itself (%s:%s)" % [pw.kind(), pw.zone()])
	check(Career.guide_at("port_walk") == at, "the legs did not move the kept step")
	pw.next_step()
	check(Career.guide_at("port_walk") == at + 1, "the next step is kept as it is reached")
	# picked up in the district itself: no legs
	g.drone.global_position = PortStructure.console_spot("ring")
	pw.back = pw._legs_to(at)
	check(pw.back.is_empty(), "already in the district: straight on, no legs")
	g.queue_free()
	await _frames(3)

	# ---- the developer's skip: nothing running, nothing waiting
	g = await _berth()
	g.start_port_walk(true)
	await _frames(3)
	check(g.walk_on(), "(a walk is running before the skip)")
	DevPanel.skip_guides()
	await _frames(3)
	check(not g.walk_on(), "the skip ends the walk that is running")
	g.queue_free()
	await _frames(3)
	g = await _berth()
	await _frames(240)
	var left := _guides(g)
	check(left.is_empty(), "the career loaded again after the skip: no guide running or due %s" % str(left))
	g.queue_free()
	await _frames(3)

	# ---- the belt prologue, cut short at "clear" (the mast was cut): on a fresh hulk it goes on
	# from "cut", the first three steps not asked again; a step reached is kept
	Career.start_new()
	Career.data.term_open = {}
	Career.guide_keep("prologue", 4)
	Game.start_ship = "belt"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	check(g.prologue != null and g.prologue.STEPS[g.prologue.step] == "cut", "the prologue picked up again at the cut (the mast is on the fresh hulk): %s" % str(g.prologue.STEPS[g.prologue.step]) if g.prologue != null else "-")
	check(g.tool_ok(2) and not g.tool_ok(1), "the cut's tool is open")
	var mast = g.prologue._piece("MAST")
	for j in g.world.joints_of(mast).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	await _frames(20)
	check(g.prologue.STEPS[g.prologue.step] == "clear" and Career.guide_at("prologue") == 4, "past the cut: \"clear\", and that step kept (%d)" % Career.guide_at("prologue"))
	g.queue_free()
	await _frames(3)

	SaveGame.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	print("GUIDE RESUME %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
