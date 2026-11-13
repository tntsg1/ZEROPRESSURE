extends SceneTree
const Cap = preload("res://tests/cap.gd")
var fails := 0
var checks := 0
var job_sequence := 0
func _initialize() -> void:
	# 61 号 hides the work plans in play (G4_OPEN); these check the plans themselves
	Game.G4_OPEN = true
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func game(ship_id: String = "tug") -> Node:
	job_sequence += 1
	Game.start_ship = ship_id
	Game.contract = {"id":"PLAN-SETTLE-%d" % job_sequence,"ship":ship_id,"fee":0,"time":900,"kit":{}}
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	return g
func work(g, c) -> void:
	g.do_wrench({"kind":"ctrl","ctrl":c,"pos":g.world.ctrl_world(c)})
func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_plan_settlement_career.json"
	SaveGame.path = "user://zp_test_plan_settlement_save.json"
	SaveGame.allow_test = true
	Career.data = Career.fresh()
	# the test's own contract is the one in hand (settlement refuses a report for another job)
	Career.data.active = {}
	Career.save()
	var g = game()
	await frames(3)
	var sw = null
	var door = null
	for c in g.world.ctrls.values():
		if c.kind == "switch": sw = c
		if c.kind == "door": door = c
	check(sw != null and door != null,"real tug controls loaded")
	if sw == null or door == null: quit(1); return
	check(g.plan.toggle() == "plan_none","P explains that controls/hoses must be worked, not just measured")
	g.sys.bus_live = false
	g.sys.aux = false
	work(g,door)
	check(g.plan.rec.is_empty() and g.plan.toggle() == "plan_rejected","a door without power is not recorded and P explains why")
	g.plan.steps = [{"do":"w","ctrl":door.id,"pre":[]}]
	g.plan.i = 0
	g.plan.running = true
	# 2026-11-12: the plan's drone works the door where it stands: put it there, as if it had flown over
	var sv = g.plan.cutter_service()
	sv.robot.set_phasing(true)
	sv.robot.global_position = g.world.ctrl_world(door) + Vector2(0.0, -g.plan.CODEX_STANDOFF)
	sv.robot.linear_velocity = Vector2.ZERO
	g.plan._physics_process(2.0)
	check(g.plan.i == 0 and g.plan.wait == "plan_preset_blocked","a refused real door operation does not advance the machine plan")
	g.plan.cancel()
	g.plan.steps.clear()
	work(g,sw)
	check(g.plan.rec.size() == 1 and g.plan.toggle() == "plan_pending","successful manual operation is pending settlement")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.pressed = true
	g._unhandled_input(key)
	check(g.messages.any(func(m): return m[3] == Txt.t("plan_pending") % "1"),"real P key displays the formatted pending step count")
	var recorded: Array = g.plan.rec.duplicate(true)
	check(recorded[0].has("value") and recorded[0].value == sw.state,"successful controls record their resulting state rather than a blind toggle")
	g.incident("impact","unrelated debris")
	g.incident("drone_hit","collision")
	g.finish_contract(true)
	check(Career.data.plans.get("tug",[]) == recorded,"menu settlement saves steps despite unrelated collision/injury")
	check(g.plan.result_key == "plan_saved" and not g.plan.result_text().is_empty(),"settlement reports the saved step count")
	if "--capture" in OS.get_cmdline_user_args():
		g.hud.in_t = 5.0
		g.hud.t = 5.0
		g.hud.end_t = 30.0
		await frames(3)
		await RenderingServer.frame_post_draw
		Cap.save(root,"res://proofs/plan_settlement.png")
	g.queue_free()
	await frames(3)
	Career.data = {}
	Career.load_or_new()
	check(Career.data.plans.get("tug",[]) == recorded,"saved plan survives reloading the career from disk")
	g = game()
	await frames(3)
	check(g.plan.steps == recorded and g.plan.toggle() == "plan_running","next ship of the type loads the plan and P starts it")
	var ready_ctrl = g.world.ctrls[recorded[0].ctrl]
	ready_ctrl.state = bool(recorded[0].value)
	g.plan._physics_process(2.0)
	check(g.plan.i == 1 and ready_ctrl.state == bool(recorded[0].value),"an already satisfied control result is not toggled back")
	g.plan.cancel()
	g.plan.rec = []
	g.finish_contract(true)
	check(Career.data.plans.get("tug",[]) == recorded,"a job with no recorded actions preserves the previous plan")
	check(g.plan.result_key == "plan_no_actions","empty recording gets an explicit settlement reason")
	g.queue_free()
	await frames(3)
	g = game()
	await frames(3)
	var c = g.world.ctrls[recorded[0].ctrl]
	g.plan.on_player("w",c)
	g.plan.finish_player(true)
	g.plan.on_player("w",c)
	g.incident("motor",c.id)
	g.plan.finish_player(false)
	check(g.plan.rec.size() == 1 and g.plan.record_blocked == c.id,"an unsafe operation keeps only the earlier successful prefix")
	g.plan.on_player("w",c)
	g.plan.finish_player(true)
	check(g.plan.rec.size() == 1,"steps depending on the unsafe operation are not appended")
	var state: Dictionary = g.plan.save_state()
	g.plan.record_blocked = ""
	g.plan.load_state(state)
	check(g.plan.record_blocked == c.id,"recording stop reason survives save/resume")
	g.finish_contract(false)
	check(g.plan.result_key == "plan_saved_prefix" and Career.data.plans.tug.size() == 1,"automatic settlement also saves the valid prefix")
	g.queue_free()
	await frames(3)
	# With no saved plan, the next contract retains the previous empty-job reason.
	Career.data.plans = {}
	Career.data.plan_notes = {"tug":{"key":"plan_no_actions","arg":""}}
	g = game()
	await frames(3)
	check(g.plan.toggle() == "plan_no_actions","P shows why the previous job generated no plan")
	g.plan.on_player("w",g.world.ctrls[recorded[0].ctrl])
	g.incident("motor","first operation")
	g.plan.finish_player(false)
	check(g.plan.toggle() == "plan_record_blocked","P identifies an unsafe first operation with no usable prefix")
	g.queue_free()
	await frames(3)
	g = game("gr7")
	await frames(3)
	work(g,g.world.ctrls["HATCH-JAM"])
	g.sys.aux = true
	var hatch = g.world.tag("HATCH-1")
	g.world.add_joint(hatch,null,"seam",Geom.centroid(hatch.poly))
	var before_incidents: int = g.incidents.size()
	work(g,g.world.ctrls["HATCH-SW"])
	check(g.incidents.size() > before_incidents and g.plan.record_blocked == "HATCH-SW","actual welded-hatch motor accident stops the recorder")
	check(g.plan.rec.size() == 1 and g.plan.rec[0].ctrl == "HATCH-JAM","actual failed hatch operation preserves the preceding jam-clearing step")
	g.queue_free()
	await frames(3)
	print("PLAN SETTLEMENT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(0 if fails == 0 else 1)
