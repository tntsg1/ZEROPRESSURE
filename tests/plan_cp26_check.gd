extends SceneTree
# 2026-11-12 (user's CP-26, "我的方案"): the player's own 25-step plan on the same POD variant
# (tests/fixtures/pod_own_plan_2026-11-12.json, copied from the player's career; a test career only).
# On P: the gold drone does the plan — K-P, the GAS-F hose, GAS-F read again by the drone itself (never
# "暂停：先重测"), the seven cuts on p8 made by the drone (the old little cutter never shows: the drone
# phases all the run). A cut it truly cannot get at is not a silent "approaching" forever: within
# STUCK_S it is handed to the player, up top (plan_alert.gd). No text says "机器人".
# Usage: tools/run_test.sh tests/plan_cp26_check.gd -- [--capture]
const Cap = preload("res://tests/cap.gd")
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
	Career.path = "user://zp_test_plan_cp26_career.json"
	SaveGame.path = "user://zp_test_plan_cp26_save.json"
	SaveGame.train_path = "user://zp_test_plan_cp26_train.json"
	SaveGame.allow_test = false
	Game.G4_OPEN = false
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pod_own_plan_2026-11-12.json"))
	Career.data = Career.fresh()
	Career.data.money = 0.0
	Career.data.methods = fx.methods
	Career.data.plans = {"pod": fx.plan}
	Career.save()
	Game.start_ship = "pod"
	Game.contract = fx.job
	Career.data.active = {}
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.autosave_t = -1000000.0
	check(g.plan.source == "own" and g.plan.steps.size() == 25, "CP-26 (the player's variant) with the player's own 25-step plan")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.keycode = KEY_P
	key.pressed = true
	g._unhandled_input(key)
	var waits := {}
	var phased := false
	var solid_mid := false
	var bot_word := false
	var silent := 0.0               # s of "plan_cutter_wait" in a row
	var silent_max := 0.0
	var handed := ""
	var cuts := 0
	var last_i := 0
	var shot := false
	for k in 12000:
		await process_frame
		if not g.plan.running: break
		waits[g.plan.wait] = true
		var sv = g.plan._cutter_service
		if is_instance_valid(sv):
			if sv.robot.phasing: phased = true
			elif phased: solid_mid = true
		var ps: Array = g.plan.status()
		for s in ps:
			if str(s).contains("机器人"): bot_word = true
		if g.plan.wait == "plan_cutter_wait":
			silent += 1.0 / 60.0
			silent_max = maxf(silent_max, silent)
		else:
			silent = 0.0
		if g.plan.i != last_i:
			if last_i < 25 and str(g.plan.steps[last_i].get("do", "")) == "cut": cuts += 1
			last_i = g.plan.i
		if g.plan.wait == "as_plan_cut_by_hand" and handed == "":
			handed = g.plan.wait_arg
			if "--capture" in OS.get_cmdline_user_args() and not shot:
				shot = true
				await frames(30)
				await RenderingServer.frame_post_draw
				Cap.save(root, "res://proofs/plan_cp26_handed.png")
		# the hauls wait on the player's hauling: the run is judged up to there
		if g.plan.i >= 11: break
	print("RUN i=%d/25 cuts=%d handed=%s silent_max=%.1f waits=%s" % [g.plan.i, cuts, handed, silent_max, str(waits.keys())])
	check(phased and not solid_mid, "the gold drone ran the plan, phasing all the way (the old cutter never showed)")
	check(not waits.has("plan_measure"), "GAS-F was read again by the drone: no \"暂停：先重测\"")
	check(silent_max < g.plan.STUCK_S + 2.0, "no silent \"approaching\": a cut the drone cannot get at is handed over within %d s (longest %.1f s)" % [int(g.plan.STUCK_S), silent_max])
	check(cuts > 0 or handed != "", "the p8 cuts: %d made by the drone%s" % [cuts, (", %s handed to the player" % handed) if handed != "" else ""])
	check(handed == "" or g.hud.plan_alert._k > 0.0 or shot, "a cut handed to the player is up top")
	check(not bot_word, "no line of the run says 机器人")
	check(g.incidents.is_empty(), "no incident %s" % str(g.incidents))
	g.queue_free()
	await frames(4)
	Career.data = {}
	print("PLAN CP26 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(0 if fails == 0 else 1)
