extends "res://tests/guide_check.gd"
# 公测反馈 #21 / #19 / #12 (2026-11-13), run as the public-test build (Demo.forced):
#   #21 the prologue's tow eye: judged within Prologue.TOW_R (3 m, the ring drawn at that radius), a real E
#       press inside hooks on, outside it does not (and says how far)
#   #19 the tow home and the first ship's mouth tour are not skipped by the press that came before (1.5 s);
#       while TUG-001's guide walks its steps the next-step guide is quiet (one voice), back at its last step
#   #12 a course step whose target is out of its tool's reach says so on the card (and is quiet in reach);
#       the career's course from TUT_03 opens every tool each of its steps asks for
# Test saves only.
#   tools/run_test.sh tests/tutorial_fb_check.gd --fixed-fps 60


func _initialize() -> void:
	Demo.forced = true
	Career.path = "user://zp_test_tutfb_career.json"
	SaveGame.path = "user://zp_test_tutfb_save.json"
	SaveGame.train_path = "user://zp_test_tutfb_training.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.get_viewport().push_input(ev)
	await _frames(1)
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.keycode = code
	root.get_viewport().push_input(up)
	await _frames(1)


func _run() -> void:
	Txt.zh = true
	check(Demo.on(), "(the public-test build)")
	await _tow_eye()
	await _tow_home()
	await _first_ship()
	await _course()
	await _real_path()
	print("TUTORIAL FB %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


# ---- #21
func _tow_eye() -> void:
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
	var mast = pr._piece("MAST")
	for j in g.world.joints_of(mast).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	await _frames(4)
	mast = pr._piece("MAST")
	mast.body.global_position = pr.eye() + Vector2(14, -8) * Geom.M
	mast.body.linear_velocity = Vector2.ZERO
	pr.step = pr.STEPS.find("tow")
	pr._show()
	await _frames(5)
	check(pr.TOW_R >= 3.0, "#21 the tow eye is judged within %.1f m (the ring drawn at that radius)" % pr.TOW_R)
	# outside: a press does not hook, and says how far
	var away: Vector2 = pr.eye() + Vector2(0.0, -6.0) * Geom.M
	g.drone.global_position = away
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(3)
	g.hud.hint_text = ""
	await _key(KEY_E)
	await _frames(4)
	check(not pr.done and str(g.hud.hint_text).contains("再靠近"), "#21 a press %.1f m out: not hooked, it says how far ('%s')" % [g.drone.global_position.distance_to(pr.eye()) / Geom.M, g.hud.hint_text])
	# inside, where the old 2.5 m judgement missed: hooks on
	var spot: Vector2 = pr.eye() + Vector2(0.0, -2.8) * Geom.M
	for i in 30:
		g.drone.global_position = spot
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(1)
	var dist: float = g.drone.global_position.distance_to(pr.eye()) / Geom.M
	await _key(KEY_E)
	await _frames(4)
	check(pr.done, "#21 a press %.1f m from the eye (inside the ring): the cable is on" % dist)
	Cap.save(root, "res://tests/out/tutfb_tow.png")
	g.queue_free()
	# the cable on goes on to TUG-001 for real (a scene of its own): not kept under the next checks
	await _frames(30)
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await _frames(5)


# ---- #19 the tow home
func _tow_home() -> void:
	Career.data.prologue_done = true
	Career.save()
	var pre = preload("res://scripts/belt_prelude.gd").new()
	var gone := [false]
	pre.on_done = func(): gone[0] = true
	root.add_child(pre)
	await _frames(10)
	await _key(KEY_SPACE)
	await _frames(2)
	check(not gone[0], "#19 the press right after hooking does not skip the tow home")
	await _frames(int(1.6 * 60))
	Cap.save(root, "res://tests/out/tutfb_tow_home.png")
	await _key(KEY_SPACE)
	await _frames(2)
	check(gone[0], "  a press after 1.5 s still skips it (Space)")
	if is_instance_valid(pre):
		pre.queue_free()
	await _frames(3)


# ---- #19 TUG-001's guide
func _first_ship() -> void:
	Game.coach_in_tests = true
	if Career.active().is_empty():
		Career.data.active = Career.opening(0)
	Career.save()
	Game.start_ship = str(Career.active().ship)
	Game.contract = Career.active()
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	var co = g.coach
	check(co != null and co.STEPS[co.step] == "mouths", "#19 TUG-001: the guide starts at the mouths tour")
	co._unhandled_input(_kev(KEY_E))
	await _frames(2)
	check(co.STEPS[co.step] == "mouths", "#19 a press carried over does not skip the tour at once")
	co.mouth_t = 1.6
	co._unhandled_input(_kev(KEY_SPACE))
	await _frames(3)
	check(co.STEPS[co.step] == "blueprint", "  a press after 1.5 s skips it (step %s)" % co.STEPS[co.step])
	check(NextStep.of(g).is_empty() and not NextStep.on(g), "#19 one voice: no next-step line or mark beside the guide's steps")
	await _frames(30)
	Cap.save(root, "res://tests/out/tutfb_first_step.png")
	co.step = co.STEPS.find("rest")
	await _frames(3)
	check(NextStep.on(g), "  at its last step ('the rest is yours') the next-step guide speaks again")
	Game.coach_in_tests = false
	g.queue_free()
	await _frames(5)


func _kev(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	return ev


# ---- #12 the course
func _course() -> void:
	Game.course_start = Game.TS1_ADV_FROM
	Game.start_ship = "ts1"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(40)
	for n in g.get_children():
		if n.has_method("lessons_left"):
			n.t = 5.0
			n._close()
	await _frames(5)
	var tut = g.tutorial
	check(tut.first == 4, "#12 the career's course from TUT_03")
	# every step of lessons 5–9: the tools it asks for are open
	var missing: Array = []
	for li in range(tut.first, tut.lessons().size()):
		tut.lesson_i = li
		var steps: Array = tut.lessons()[li].steps
		for si in steps.size():
			tut.step_i = si
			for x in steps[si].get("tools", []):
				if not g.tool_ok(int(x)):
					missing.append("%s/%s:%d" % [tut.lesson().id, steps[si].id, int(x)])
	check(missing.is_empty(), "#12 every step of the five lessons has its tools open %s" % str(missing))
	# the remeasure step, the drone far off: the card says so; close: quiet
	tut.lesson_i = tut.first
	var steps3: Array = tut.lesson().steps
	for si in steps3.size():
		if str(steps3[si].id) == "remeasure":
			tut.step_i = si
	var pt: Vector2 = tut.target_pos()
	g.drone.global_position = pt + Vector2(22.0, 0.0) * Geom.M
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(2)
	var far: String = tut.far_hint()
	check(far.contains("飞近") and far.contains("占位"), "#12 out of reach at the remeasure step: '%s'" % far)
	await _frames(20)
	Cap.save(root, "res://tests/out/tutfb_far.png")
	g.drone.global_position = pt + Vector2(-1.5, -1.5) * Geom.M
	await _frames(2)
	check(tut.far_hint() == "", "  in reach: nothing extra on the card")
	g.queue_free()
	await _frames(5)


func _scene_after(old) -> Node:
	for i in 900:
		await process_frame
		if current_scene != null and current_scene != old and current_scene.get("state") != null:
			break
	await _frames(10)
	return current_scene


# ---- a player's own way (B 站评论, 2026-11-13): a new company, the prologue, E on the tow eye, TUG-001's
# guide (Tab for real), Esc → end the contract early, on into the course — every key pressed for real
func _real_path() -> void:
	Game.coach_in_tests = true
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
	var mast = pr._piece("MAST")
	for j in g.world.joints_of(mast).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	await _frames(4)
	mast = pr._piece("MAST")
	mast.body.global_position = pr.eye() + Vector2(14, -8) * Geom.M
	mast.body.linear_velocity = Vector2.ZERO
	pr.step = pr.STEPS.find("tow")
	for i in 20:
		g.drone.global_position = pr.eye() + Vector2(0.0, -2.0) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO
		await _frames(1)
	var belt = g
	await _key(KEY_E)
	check(pr.done, "path: E on the tow eye hooks the cable")
	g = await _scene_after(belt)
	if is_instance_valid(belt):
		belt.queue_free()
	check(g != null and str(g.job.get("id", "")) == "TUG-001" and g.prologue == null, "path: on to TUG-001 — the prologue gone with its scene (no step of it left)")
	for i in 600:
		await process_frame
		if g.state == "play":
			break
	if g.contract_open:
		await _key(KEY_SPACE)
	await _frames(10)
	var co = g.coach
	check(co != null and not g.contract_open, "path: TUG-001's guide on, the contract card closed by Space")
	co.mouth_t = 1.6
	await _key(KEY_SPACE)
	await _frames(5)
	check(co.STEPS[co.step] == "blueprint" and not g.tool_ok(1), "path: step 1 'Tab', the tools shut by the guide's own step (not by the prologue)")
	await _key(KEY_TAB)
	await _frames(5)
	check(co.STEPS[co.step] == "measure" and g.tool_ok(1), "path: Tab opens the blueprint, step 2, the meter open (step %s)" % co.STEPS[co.step])
	# Esc, end the contract early (the menu's two presses), then on from the settlement
	await _key(KEY_ESCAPE)
	check(g.menu_open, "path: Esc opens the menu")
	g.toggle_menu()
	g.finish_contract(true)
	await _frames(30)
	check(g.state == "ending", "path: the contract ended early")
	var tug = g
	g.leave()
	g = await _scene_after(tug)
	if is_instance_valid(tug):
		tug.queue_free()
	var tut = g.get("tutorial") if g != null else null
	check(tut != null and tut.first == 4, "path: on into the course, from its fifth lesson (TUT_03)")
	if tut != null:
		for n in g.get_children():
			if n.has_method("lessons_left"):
				await _frames(60)
				await _key(KEY_SPACE)
		for i in 900:
			await process_frame
			if g.state == "play":
				break
		# the course's own Tab step (TUT_03 "trace"), with the overview button clicked before: Tab still works
		var steps: Array = tut.lesson().steps
		for si in steps.size():
			if str(steps[si].id) == "trace":
				tut.step_i = si
		tut._enter_step()
		for n in g.get_children():
			if n is TutorialHud:
				n.overview_button.grab_focus()
		await _frames(5)
		await _key(KEY_TAB)
		await _frames(10)
		check(tut.bp_seen and str(tut.step().get("id", "")) != "trace", "path: the course's Tab step passes even with its overview button clicked (now %s)" % str(tut.step().get("id", "")))
	Game.coach_in_tests = false
	if g != null:
		g.queue_free()
	await _frames(5)
