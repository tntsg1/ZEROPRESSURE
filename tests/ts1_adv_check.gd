extends "res://tests/guide_check.gd"
# 双重教程 (owner 2026-11-12, "b"; a public-test player: "一上来就拆船，拆完了学会了，结果怎么又是另一个
# 更基础的新手教程"): after TUG-001 the career goes into the base course from its fifth lesson (TUT_03),
# a bridging card first; the course's numbering and marks count from there; the exam offer at its end
# is unchanged; TS-1 started from the menu is the full nine lessons. Run for the public-test build and
# the full game. Test saves only.
#   tools/run_test.sh tests/ts1_adv_check.gd --fixed-fps 60

const ColdOpen = preload("res://scripts/cold_open.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_ts1adv_career.json"
	SaveGame.path = "user://zp_test_ts1adv_save.json"
	SaveGame.train_path = "user://zp_test_ts1adv_training.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _scene(ship: String, job: Dictionary, as_bot := false) -> void:
	Game.start_ship = ship
	Game.contract = job
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	if as_bot:
		g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)


func _bridge():
	for n in g.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("ts1_bridge.gd"):
			return n
	return null


func _flow(tag: String, demo: bool) -> void:
	Demo.forced = demo
	SaveGame.clear(SaveGame.train_path)
	check(Demo.on() == demo, "%s: build %s" % [tag, "public test" if demo else "full game"])
	# ---- cold open, prologue
	Career.start_new()
	Career.data.term_open = {}
	Career.save()
	await _scene("belt", {})
	await _frames(5)
	check(g.prologue != null and g.prologue.cold != null, "%s: the cold open plays" % tag)
	g.prologue.cold.film.finish()
	await _frames(5)
	g.finish_prologue()
	check(Game.start_ship == "tug" and Career.data.get("ts1_after", false), "%s: prologue done, TUG-001 next (not the course)" % tag)
	g.queue_free()
	await _frames(5)
	# ---- TUG-001, stripped: the course from its fifth lesson
	Career.data.prologue_done = true
	if Career.active().is_empty():
		Career.data.active = Career.opening(0)
	Career.save()
	await _scene(str(Career.active().ship), Career.active(), true)
	await _frames(12)
	check(str(g.job.get("id", "")) == "TUG-001", "%s: TUG-001 in the berth" % tag)
	Career.data.history = [{"id": "TUG-001"}]
	Career.data.done = 1
	Career.save()
	g._to_berth()
	check(Game.start_ship == "ts1" and Career.data.get("ts1_required", false) and Game.course_start == "TUT_03", "%s: TUG-001 stripped → the course from TUT_03 (start %s, from %s)" % [tag, Game.start_ship, Game.course_start])
	# the real way there: the wipe loads the course scene as the current scene
	var old = g
	for i in 240:
		await process_frame
		if current_scene != null and current_scene != old and current_scene.get("tutorial") != null:
			break
	if is_instance_valid(old):
		old.queue_free()
	g = current_scene
	await _frames(8)
	check(g != null and g.get("tutorial") != null, "%s: the wipe took it into the course scene" % tag)
	var tut = g.tutorial
	check(tut != null and tut.first == 4 and str(tut.lesson().get("id", "")) == "TUT_03" and Game.course_start == "", "%s: the course starts at lesson 5 of 9 (TUT_03), the start read once" % tag)
	var br = _bridge()
	check(br != null and get_root_paused(), "%s: the bridging card is up, the game waiting under it" % tag)
	if br != null:
		check(br.lessons_left().size() == 5, "  it lists the five lessons ahead (%s)" % str(br.lessons_left()))
		check(br.keys_row().contains("Z") and br.keys_row().contains("V"), "  and the keys the skipped lessons taught")
		await _frames(50)
		Cap.save(root, "res://tests/out/ts1_adv_bridge_%s.png" % tag)
		br._close()
		await _frames(5)
	check(not get_root_paused() and Career.data.get("seen", {}).has("ts1_bridge"), "%s: any key: the course goes on, the card once per career" % tag)
	await _frames(420)
	Cap.save(root, "res://tests/out/ts1_adv_course_%s.png" % tag)
	var hud = null
	for n in g.get_children():
		if n is TutorialHud:
			hud = n
	check(tut.first == 4 and (4 - tut.first + 1) == 1, "%s: the HUD counts lessons from here (lesson 1 of 5)" % tag)
	# ---- the course passed: the exam offer, unchanged; then back to the berth
	tut.lesson_i = tut.lessons().size() - 1
	tut.step_i = 0
	tut.flags[tut.lesson().done_flag] = true
	tut.lesson_i = tut.lessons().size()
	tut._finish()
	await _frames(10)
	check(tut.done and str(Career.data.get("cert_kind", "")) == "full", "%s: the course done: certified" % tag)
	check(str(tut.course.get("exam_offer", "")) != "", "  the exam offer is still made at its end")
	Career.data.active = {}          # TUG-001 was settled before the course (the test skipped the settling)
	Career.save()
	g.after_training("contract")
	check(Game.start_ship == "berth" or Game.start_ship == "", "%s: on to the berth after it (start %s)" % [tag, Game.start_ship])
	check(not Game.ts1_due(), "  nothing owed any more")
	await _frames(20)
	# the course scene was the current scene: whatever after_training loaded is gone with it
	for i in 120:
		await process_frame
		if current_scene != g:
			break
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	if is_instance_valid(g):
		g.queue_free()
	await _frames(10)


func get_root_paused() -> bool:
	return paused


func _run() -> void:
	Txt.zh = true
	ColdOpen.in_tests = true
	await _flow("demo", true)
	await _flow("full", false)
	# ---- the full course from the menu: nine lessons, no card
	Demo.forced = false
	SaveGame.clear(SaveGame.train_path)
	Game.course_start = ""
	await _scene("ts1", {})
	await _frames(8)
	check(g.tutorial != null and g.tutorial.first == 0 and g.tutorial.lesson_i == 0 and _bridge() == null, "TS-1 from the menu: the full course from lesson 0, no bridging card")
	ColdOpen.in_tests = false
	print("TS1 ADV %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
