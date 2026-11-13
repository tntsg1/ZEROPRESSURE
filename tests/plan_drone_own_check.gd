extends SceneTree
# 2026-11-12 (评审定): the player's own recorded plan is run by the same visible drone as the codex's.
#   P on a plan of the player's own: the drone (the berth's cutter, the operator's airframe) flies out,
#   phasing through walls, and works each switch and hose beside it; a step whose gauge was read when
#   the plan was made and is not read now does not stop at "暂停：先重测": the drone flies to the gauge,
#   measures it and the plan goes on by itself, to the end, no incident.
# Test careers only. Usage: tools/run_test.sh tests/plan_drone_own_check.gd
var fails := 0
var checks := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_plan_drone_own_career.json"
	SaveGame.path = "user://zp_test_plan_drone_own_save.json"
	SaveGame.train_path = "user://zp_test_plan_drone_own_train.json"
	SaveGame.allow_test = false
	Game.G4_OPEN = false
	Career.data = Career.fresh()
	Career.data.money = 0.0
	Career.data.methods = {"cutter": 3}
	# the player's own plan for POD: power off, then a hose on GAS-F that wants GAS-F read first
	var own := [
		{"do": "w", "ctrl": "K-P", "pre": [], "value": false},
		{"do": "h", "ctrl": "GAS-F", "pre": [{"key": "GAS-F", "kind": "pressure", "val": 120.0}], "value": true},
	]
	Career.data.plans = {"pod": own}
	Career.save()
	Game.start_ship = "pod"
	Game.contract = {"id": "DRONE-OWN-T", "ship": "pod", "fee": 0, "time": 3600, "kit": {}}
	Career.data.active = {}
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.autosave_t = -1000000.0
	check(g.plan.source == "own" and g.plan.steps.size() == own.size(), "POD with a plan of the player's own: that plan is loaded (%d steps)" % g.plan.steps.size())
	check(g.sys.readings.get("GAS-F") == null, "GAS-F has not been read on this job")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.keycode = KEY_P
	key.pressed = true
	g._unhandled_input(key)
	check(g.plan.running and g.plan.source == "own", "P runs the player's own plan")
	var waits := {}
	var phased := false
	var solid_mid := false
	var at_site := 0
	var off_site := 0
	var read_at := INF
	var through := false
	var frame := 0
	for k in 20000:
		await process_frame
		frame = k
		if not g.plan.running: break
		waits[g.plan.wait] = true
		var sv = g.plan._cutter_service
		if not is_instance_valid(sv): continue
		var rb = sv.robot
		if rb.phasing: phased = true
		elif phased: solid_mid = true
		var tw = g.tools.tunnel_fx.watch.get(rb.get_instance_id())
		if tw != null: through = true
		if is_inf(read_at) and g.sys.readings.get("GAS-F") != null:
			read_at = rb.global_position.distance_to(g.world.ctrl_world(g.world.ctrls["GAS-F"]))
		var cur: Dictionary = g.plan.steps[g.plan.i] if g.plan.i < g.plan.steps.size() else {}
		if str(cur.get("do", "")) in ["w", "h"] and g.plan.step_t > 0.0 and g.plan.wait == "":
			if rb.global_position.distance_to(g.world.ctrl_world(g.world.ctrls[str(cur.ctrl)])) <= g.plan.CODEX_STANDOFF + 8.0: at_site += 1
			else: off_site += 1
	print("RUN frames=%d i=%d/%d waits=%s" % [frame, g.plan.i, g.plan.steps.size(), str(waits.keys())])
	check(phased and not solid_mid, "the drone came out for the player's own plan and phased all the run")
	check(waits.has("as_plan_fly") and at_site > 0 and off_site == 0, "it flew to K-P and GAS-F and worked each beside it (%d frames at a control, %d away)" % [at_site, off_site])
	check(not waits.has("plan_measure") and not is_inf(read_at) and read_at <= g.plan.CODEX_STANDOFF + 8.0, "GAS-F unread: no \"暂停：先重测\", the drone measured it at the gauge (%.0f px off)" % read_at)
	check(through, "the phasing look was drawn for it")
	check(g.plan.i == g.plan.steps.size() and not g.plan.running and g.sys.hoses.has("GAS-F"), "the plan went on by itself to the end (GAS-F hose on)")
	check(g.incidents.is_empty(), "no incident %s" % str(g.incidents))
	g.queue_free()
	await frames(4)
	Career.data = {}
	print("PLAN DRONE OWN %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(0 if fails == 0 else 1)
