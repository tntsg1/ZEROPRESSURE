extends SceneTree
# 切割宝典 (scripts/plan_codex.gd, phase B): the shipwrights' plans for ship types never stripped.
#   no codex, no own plan: P says there is none and names the codex
#   the methods page card: price, buy, owned
#   with the codex: three types never stripped run their codex plan on P to the end, no incident
#   safety: a codex cut never goes into a room still under pressure
#   an own plan wins; Shift+P (stopped) changes to the codex's and back; a codex run keeps the own plan
#   not for ARK-01 / AX-40
# Test careers only. Usage: tools/run_test.sh tests/plan_codex_check.gd -- [ships...] [--capture]
const Cap = preload("res://tests/cap.gd")
const Codex = preload("res://scripts/plan_codex.gd")
var fails := 0
var checks := 0
var seq := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
func game(ship_id: String) -> Node:
	seq += 1
	Game.start_ship = ship_id
	Game.contract = {"id":"CODEX-T-%d" % seq,"ship":ship_id,"fee":0,"time":3600,"kit":{}}
	Career.data.active = {}
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(10)
	g.tutorial = null
	g.autosave_t = -1000000.0
	return g
func press(g, shift: bool = false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	key.keycode = KEY_P
	key.pressed = true
	key.shift_pressed = shift
	g._unhandled_input(key)
func said(g, key: String) -> bool:
	return g.messages.any(func(m): return m[3] == Txt.t(key))
func done(g) -> void:
	g.queue_free()
	await frames(4)
func fresh(money: float = 0.0) -> void:
	Career.data = Career.fresh()
	Career.data.money = money
	Career.data.methods = {}
	Career.data.plans = {}
	Career.save()
func cuts_of(ship: String) -> int:
	return Codex.steps(ship).filter(func(s): return s.get("do","") == "cut").size()

func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_plan_codex_career.json"
	SaveGame.path = "user://zp_test_plan_codex_save.json"
	SaveGame.train_path = "user://zp_test_plan_codex_train.json"
	SaveGame.allow_test = false
	Game.G4_OPEN = false
	var types: Array = Codex.types()
	check(types.size() >= 3 and not Codex.has("ark01") and not Codex.has("ax40"), "the codex ships plans for %d types, not ARK-01 or AX-40" % types.size())
	var ships: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"): ships.append(a)
	if ships.is_empty():
		# POD and the two codex types with the most cuts
		var by_cuts: Array = types.duplicate()
		by_cuts.sort_custom(func(a, b): return cuts_of(a) > cuts_of(b))
		ships = ["pod"] + by_cuts.filter(func(s): return s != "pod").slice(0, 2)
	print("SHIPS ", ships, " cuts ", ships.map(func(s): return cuts_of(s)))
	# 1. no codex, never stripped: P says how to get a plan, codex named
	fresh(0.0)
	Career.data.methods = {"cutter": 1}
	var g = await game(ships[0])
	press(g)
	check(said(g, "as_plan_none") and "宝典" in Txt.t("as_plan_none") and not g.plan.running, "no codex, never stripped: P says there is no plan yet and names the codex")
	await done(g)
	# 2. the methods page card
	fresh(150000.0)
	check(not Codex.node().ready and Codex.buy() != "" and not Codex.owned(), "short of $200,000 the codex cannot be bought")
	fresh(260000.0)
	var n := Codex.node()
	check(n.kind == "codex" and n.ready and not n.done, "the card is ready to buy with the money")
	check(Codex.buy() == "" and Codex.owned() and is_equal_approx(float(Career.data.money), 60000.0), "buying it takes $200,000 and owns it")
	check(Codex.node().done, "the card then shows it owned")
	# 3. three types never stripped, codex owned, cutter method not: P runs the codex plan to the end
	for ship in ships:
		if not Codex.has(ship):
			check(false, "%s has a codex plan" % ship)
			continue
		g = await game(ship)
		var n_steps: int = g.plan.steps.size()
		check(g.plan.source == "codex" and n_steps == Codex.steps(ship).size(), "%s never stripped: the codex plan is loaded (%d steps)" % [ship, n_steps])
		press(g)
		check(g.plan.running and said(g, "plan_running"), "%s: P starts it" % ship)
		var head_ok := false
		var shot := false
		var unsafe := []
		for k in 40000:
			await process_frame
			if not g.plan.running: break
			var ps: Array = g.plan.status()
			if not ps.is_empty() and str(ps[0]) == Txt.t("as_plan_title_codex") % [mini(g.plan.i + 1, n_steps), n_steps]: head_ok = true
			# the safety rule: the cutter fires only with the rooms beside the cut empty
			var service = g.plan._cutter_service
			if is_instance_valid(service) and service.robot.beam_on and g.plan.i < n_steps:
				for room in g.plan.steps[g.plan.i].get("rooms", []):
					if g.sys.P(str(room)) > g.plan.SAFE_KPA: unsafe.append(str(room))
				if not shot and "--capture" in OS.get_cmdline_user_args():
					shot = true
					await RenderingServer.frame_post_draw
					Cap.save(root, "res://proofs/plan_codex_replay_%s.png" % ship)
		print("%s REPLAY i=%d/%d wait=%s %s" % [ship, g.plan.i, n_steps, g.plan.wait, g.plan.wait_arg])
		check(head_ok, "%s: the HUD line reads the codex plan's progress" % ship)
		check(g.plan.i == n_steps and not g.plan.running and said(g, "plan_done"), "%s: every step done (safety work and cuts)" % ship)
		check(g.incidents.is_empty() and unsafe.is_empty(), "%s: no incident, no cut beside a pressurised room %s" % [ship, str(unsafe)])
		check(int(g.ops.get("plan", 0)) > 0, "%s: the steps were done by the berth's machines" % ship)
		await done(g)
	# 4. a codex cut waits for a room put back under pressure
	var cut_ship := ""
	for s in ships:
		if Codex.steps(s).any(func(st): return st.get("do","") == "cut" and not st.get("rooms", []).is_empty()): cut_ship = s
	if cut_ship != "":
		g = await game(cut_ship)
		var k0: int = g.plan.steps.find_custom(func(st): return st.get("do","") == "cut" and not st.get("rooms", []).is_empty())
		var room := str(g.plan.steps[k0].rooms[0])
		g.plan.i = k0
		g.plan.running = true
		g.sys.vols[room].n = 80.0 * float(g.sys.vols[room].V)
		var shape: Array = g.plan._shape(g.world.key_piece(str(g.plan.steps[k0].key)))
		await frames(240)
		check(g.plan.i == k0 and g.plan.wait == "plan_cut_pressure" and g.plan._shape(g.world.key_piece(str(g.plan.steps[k0].key))) == shape, "%s: a codex cut beside room %s under pressure waits and cuts nothing" % [cut_ship, room])
		await done(g)
	else:
		print("(no codex cut beside a room among %s: the pressure hold is covered by tests/plan_laser_check.gd)" % str(ships))
	# 5. an own plan wins; Shift+P changes over and back; a codex run keeps the own plan
	var ship2: String = ships[0]
	var own := [{"do":"w","ctrl":"K-P","pre":[],"value":false}] if ship2 == "pod" else Codex.steps(ship2).slice(0, 1)
	Career.data.plans = {ship2: own}
	Career.save()
	g = await game(ship2)
	check(g.plan.source == "own" and g.plan.steps.size() == own.size(), "%s: with a plan of the player's own, that one is run" % ship2)
	press(g, true)
	check(g.plan.source == "codex" and said(g, "as_plan_src_codex") and str(Career.data.plan_pick.get(ship2, "")) == "codex", "Shift+P (stopped) changes to the codex's plan and keeps the choice")
	press(g, true)
	check(g.plan.source == "own" and said(g, "as_plan_src_own"), "Shift+P again changes back")
	press(g, true)
	press(g)
	for k in 20000:
		await process_frame
		if not g.plan.running: break
	g.finish_contract(true)
	await frames(2)
	check(Career.data.plans.get(ship2, []) == own and g.plan.result_key == "as_plan_codex_ran", "a job that ran the codex leaves the player's own plan as it was")
	await done(g)
	Career.data = {}
	print("PLAN CODEX %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(0 if fails == 0 else 1)
