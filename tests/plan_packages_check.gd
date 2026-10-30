extends SceneTree
var g: Node
var checks := 0
var fails := 0
func _initialize() -> void:
	# 61 号 hides the work plans in play (G4_OPEN); these check the plans themselves
	Game.G4_OPEN = true
	_run.call_deferred()
func frames(n: int) -> void:
	for k in n: await process_frame
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",text])
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_g4_packages_career.json"
	Career.data = Career.fresh()
	SaveGame.path = "user://zp_test_g4_packages_save.json"
	SaveGame.allow_test = false
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO,"kit":{"hauler":1}}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.drone.global_position = Vector2(-5,-12) * Geom.M
	var at: Vector2 = Dock.zpos("equip") + Dock.ZONES.equip.face * 3.0 * Geom.M
	var p = g.world.add_piece("cargo",PackedVector2Array([at+Vector2(-9,-9),at+Vector2(9,-9),at+Vector2(9,9),at+Vector2(-9,9)]),{"key":"PACKAGE-LOAD","tag":"PACKAGE-LOAD","cls":"equip","value":100.0,"mass":0.1})
	g.world.make_body([p],null)
	var c = g.world.ctrls.values()[0]
	var before: bool = c.state
	var defs: Array = [
		{"id":"blocked","version":1,"ship":"pod","label":"局部结构切离","kind":"verified","targets":["MISSING-PLATE"],"protected":[],"deps":[],"steps":[{"do":"cut","key":"MISSING-PLATE","pl":[[0,0],[0,1]],"pre":[]}]},
		{"id":"dependent","version":1,"ship":"pod","label":"依赖切离的后续工序","kind":"verified","targets":[],"protected":[],"deps":["blocked"],"steps":[{"do":"w","ctrl":c.id,"pre":[]}]},
		{"id":"independent","version":1,"ship":"pod","label":"已松脱设备转运","kind":"verified","targets":[p.key],"protected":[],"deps":[],"steps":[{"do":"haul","keys":[p.key],"zone":"equip","pre":[]}]}
	]
	var book = g.plan.packages
	book.catalogue = defs.duplicate(true)
	book.protected = ["MISSING-PLATE"]
	check(not book.authorize(["blocked"]) and book.jobs.is_empty(),"preservation conflict refuses authorization without creating work")
	book.protected.clear()
	book.catalogue[0].version = 99
	check(not book.authorize(["blocked"]),"unknown package schema versions cannot execute")
	book.catalogue = defs.duplicate(true)
	check(not book.authorize(["dependent"]),"missing dependency cannot be authorized")
	book.catalogue[0].deps = ["dependent"]
	check(not book.authorize(["blocked","dependent"]),"cyclic dependency cannot start")
	book.catalogue = defs.duplicate(true)
	check(book.authorize(["blocked","dependent","independent"]),"a valid independent package set is explicitly authorized")
	g.plan.package_mode = true
	g.plan.running = true
	for k in 4200:
		await process_frame
		if book.complete(book._job("independent")): break
	check(book.complete(book._job("independent")) and g.income_equip > 0,"unrelated hauling actually delivers while a cut package is blocked")
	check(book._job("blocked").worker.i == 0 and book._job("blocked").worker.wait == "plan_changed","missing structural target remains paused, never skipped")
	check(book._job("dependent").worker.i == 0 and c.state == before,"dependent work cannot run before its prerequisite")
	check(g.plan.running and g.plan.status()[1] != Txt.t("plan_done"),"a successful independent job does not falsely complete the blocked package set")
	g.plan.cancel()
	check(book.jobs.all(func(j):return not j.worker.running),"P stop revokes execution for every package")
	var state := JSON.parse_string(JSON.stringify(g.plan.save_state())) as Dictionary
	g.plan.load_state(state)
	check(book.complete(book._job("independent")) and book._job("blocked").worker.i == 0,"serialized package progress stays independent on reload")
	Career.data.plan_books = {"pod":defs.duplicate(true)}
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	event.pressed = true
	g._unhandled_input(event)
	await frames(5)
	check(g.console_ui != null and paused and g.paused_sim,"the real P key opens a paused authorization preview")
	if g.console_ui != null:
		var panel = g.console_ui
		check(panel.checks.size() == 3 and not g.plan.running,"preview lists packages without starting any machine")
		check(panel.get_viewport().gui_get_focus_owner() != null,"preview opens with keyboard focus")
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			preload("res://tests/cap.gd").save(root,"res://proofs/g4_packages_preview.png")
		var close_event := InputEventKey.new()
		close_event.physical_keycode = KEY_ESCAPE
		close_event.pressed = true
		panel._unhandled_input(close_event)
		await frames(3)
		check(g.console_ui == null and not paused and not g.paused_sim,"Escape restores the live ship without authorizing work")
		g._unhandled_input(event)
		await frames(3)
		panel = g.console_ui
		for id in panel.checks: panel.checks[id].button_pressed = id == "independent"
		panel.authorize()
		await frames(3)
		check(g.console_ui == null and not paused and book.selected == ["independent"],"explicit authorization closes the preview and runs only the selected package")
		check(not book._job("blocked").enabled and not book._job("dependent").enabled,"unselected blocked and dependent work stays disabled")
	# A knife path through an adjacent preserved unit is a conflict even when keys differ.
	var center := Vector2(32,-6) * Geom.M
	var shape := PackedVector2Array([center+Vector2(-20,-10),center+Vector2(20,-10),center+Vector2(20,10),center+Vector2(-20,10)])
	var structure = g.world.add_piece("hull",shape,{"key":"STRUCTURE"})
	var protected_unit = g.world.add_piece("equip",shape,{"key":"KEEP-UNIT","cls":"equip"})
	book.protected = [protected_unit.key]
	var path := {"do":"cut","key":structure.key,"pl":[[center.x-30,center.y],[center.x+30,center.y]],"pre":[]}
	check(book.cut_conflicts(path).has("KEEP-UNIT"),"a path through a different preserved component is rejected geometrically")
	var near: Dictionary = path.duplicate(true)
	near.pl = [[center.x-30,center.y-12],[center.x+30,center.y-12]]
	check(book.cut_conflicts(near).has("KEEP-UNIT"),"preservation includes physical kerf width rather than only the beam centerline")
	g.plan._step_cut(path,100.0)
	check(g.plan.wait == "plan_cut_preserved" and not structure.has_meta("cuts"),"runtime preservation gate blocks actual material removal")
	book.protected.clear()
	var cut_record: Array = [{"do":"cut","key":"STRUCTURE","pl":path.pl,"pre":[],"before":["before"],"after":["after"],"links":[]}]
	book.archive_recording(cut_record)
	var count: int = Career.data.plan_books.pod.size()
	book.archive_recording(cut_record)
	check(Career.data.plan_books.pod.size() == count,"identical safe recordings do not create duplicate package revisions")
	check(Career.data.plan_books.pod.any(func(d):return d.get("kind","") == "verified" and d.get("targets",[]).has("STRUCTURE")),"safe local recordings retain their target and verified result metadata")
	var generated: Dictionary = Career.data.plan_books.pod.filter(func(d):return d.get("targets",[]).has("STRUCTURE"))[0]
	var language_before: bool = Txt.zh
	Txt.zh = false
	check(book.display_name(generated).begins_with("VERIFIED KERF"),"automatically recorded package titles follow the current language")
	Txt.zh = language_before
	var validation = g.plan.get_script().new()
	validation.setup(g)
	validation.load_state(g.plan.save_state())
	var child_id: int = validation.packages._job("independent").worker.get_instance_id()
	validation.free()
	check(not is_instance_id_valid(child_id),"temporary off-tree save validation releases its package executors")
	g.plan.running = true
	g.incident("impact","unrelated scrap")
	check(g.plan.running,"an unrelated impact does not discard or stop validated independent work")
	g.incident("arc","global electrical incident")
	check(not g.plan.running and book.jobs.all(func(j):return not j.worker.running),"a global electrical incident stops all authorized execution")
	check(book.complete(book._job("independent")),"global emergency stop preserves already completed package progress")
	g.queue_free()
	await frames(4)
	var drain := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain: await process_frame
	print("PLAN PACKAGES %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
