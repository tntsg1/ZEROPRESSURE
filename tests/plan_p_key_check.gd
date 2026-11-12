extends SceneTree
# 2026-11-11 (user: "我在切这个吊运货仓，我按 P 键也毫无作用啊"): the plan key follows the cutter
# method (scripts/methods.gd "cutter"), not Game.G4_OPEN, and always answers.
#   not bought -> as_plan_not_bought · no plan for the type -> as_plan_none · recording -> HUD line
#   a stripped ship's plan saved at settlement -> the next ship of the type replays it on P to the end
#   Shift+P: tier 1 says it needs tier 2, tier 2 skips the step
# Test careers and saves only. Usage: tools/run_test.sh tests/plan_p_key_check.gd -- [ships...] [--capture]
const Cap = preload("res://tests/cap.gd")
var fails := 0
var checks := 0
var seq := 0
var shot := false
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
	Game.contract = {"id":"PLAN-P-%d" % seq,"ship":ship_id,"fee":0,"time":900,"kit":{}}
	Career.data.active = {}
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
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
func said(g, key: String, arg: String = "") -> bool:
	var text: String = Txt.t(key)
	if "%s" in text: text = text % arg
	return g.messages.any(func(m): return m[3] == text)
func done(g) -> void:
	g.queue_free()
	await frames(4)
# keyed structure still on the ship with no pressurised room beside it: what the cutter may cut
func targets(g, n: int) -> Array:
	var out: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or p.key == "" or p.door or p.cls == "equip": continue
		if not g.plan._rooms_by_piece(p).is_empty(): continue
		var r := Rect2(p.poly[0], Vector2.ZERO)
		for q in p.poly: r = r.expand(q)
		if r.size.x < 0.8 * Geom.M and r.size.y < 0.8 * Geom.M: continue
		out.append([p, r])
		if out.size() >= n: break
	return out
# the operator's own work on a ship: a switch, then cuts across keyed structure
func strip_by_hand(g) -> int:
	var worked := 0
	for c in g.world.ctrls.values():
		if c.kind == "switch":
			g.do_wrench({"kind":"ctrl","ctrl":c,"pos":g.world.ctrl_world(c)})
			worked += 1
			break
	# the ship's middle: a cut starts on the far side of the piece from it, out where the berth's
	# cutter can come at it (a kerf front between cargo is out of its reach, as it is for the drone)
	var mid := Vector2.ZERO
	for id in g.world.order: mid += Geom.centroid(g.world.pieces[id].poly)
	mid /= maxf(1.0, g.world.order.size())
	var picked: Array = targets(g, 12)
	picked.sort_custom(func(x, y): return x[1].size.x / maxf(1.0, x[1].size.y) > y[1].size.x / maxf(1.0, y[1].size.y))
	for t in picked.slice(0, 3):
		var p = t[0]
		var r: Rect2 = t[1]
		var c := r.get_center()
		var a: Vector2
		var b: Vector2
		if r.size.x >= r.size.y:   # long along x: a cut across it, from its outer face in
			a = Vector2(c.x, r.end.y) if c.y > mid.y else Vector2(c.x, r.position.y)
			b = Vector2(c.x, r.position.y - 6.0) if c.y > mid.y else Vector2(c.x, r.end.y + 6.0)
		else:
			a = Vector2(r.end.x, c.y) if c.x > mid.x else Vector2(r.position.x, c.y)
			b = Vector2(r.position.x - 6.0, c.y) if c.x > mid.x else Vector2(r.end.x + 6.0, c.y)
		var f: Transform2D = g.world.frame(p)
		g.cut_kerf(p, PackedVector2Array([f * a, f * b]))
		await frames(2)
	return worked
func replay(g, label: String) -> void:
	var n: int = g.plan.steps.size()
	press(g)
	check(g.plan.running and said(g, "plan_running"), "%s: P starts the replay of the saved %d steps" % [label, n])
	var head_ok := false
	for k in 9000:
		await process_frame
		if g.plan.running:
			var ps: Array = g.plan.status()
			if not ps.is_empty() and str(ps[0]) == Txt.t("as_plan_title") % [mini(g.plan.i + 1, n), n] and str(ps[1]) != "": head_ok = true
			if not shot and g.plan.i >= 1 and "--capture" in OS.get_cmdline_user_args():
				shot = true
				await RenderingServer.frame_post_draw
				Cap.save(root, "res://proofs/plan_p_replay.png")
		if not g.plan.running: break
	print("%s REPLAY i=%d/%d wait=%s arg=%s cutter=%s" % [label, g.plan.i, n, g.plan.wait, g.plan.wait_arg, g.plan.cutter_service().reason])
	check(head_ok, "%s: while it runs the HUD line reads progress n/%d and the current step" % [label, n])
	check(g.plan.i == n and not g.plan.running and said(g, "plan_done"), "%s: the replay runs to the end and says so" % label)
	check(int(g.ops.get("plan", 0)) > 0 and g.incidents.is_empty(), "%s: the steps were done by machine, no incident" % label)

func _run() -> void:
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_plan_p_key_career.json"
	SaveGame.path = "user://zp_test_plan_p_key_save.json"
	SaveGame.train_path = "user://zp_test_plan_p_key_train.json"
	SaveGame.allow_test = false
	Game.G4_OPEN = false
	var ships: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"): ships.append(a)
	if ships.is_empty(): ships = ["pod"]
	for ship in ships:
		Career.data = Career.fresh()
		Career.data.active = {}
		Career.data.methods = {}
		Career.save()
		var first: bool = ship == ships[0]
		var g = await game(ship)
		check(g.career(), "%s: a career contract" % ship)
		if first:
			press(g)
			check(said(g, "as_plan_not_bought") and not g.plan.running, "%s: P without the method says it is not bought yet" % ship)
			check(not g.plan_shown(), "%s: without the method the plan has no HUD line" % ship)
		Career.data.methods = {"cutter": 1}
		if first:
			press(g)
			check(said(g, "as_plan_none") and not g.plan.running, "%s: P with the method but no plan for the type says how to get one" % ship)
			var ps: Array = g.plan.status()
			check(g.plan_shown() and ps.size() == 2 and ps[0] == Txt.t("as_plan_rec_title"), "%s: the HUD shows the plan recording" % ship)
		var worked := await strip_by_hand(g)
		var rec_n: int = g.plan.rec.size()
		print("%s RECORDED %d steps (%d controls): %s" % [ship, rec_n, worked, str(g.plan.rec.map(func(s): return str(s.get("do","")) + ":" + str(s.get("key", s.get("ctrl","")))))])
		check(rec_n >= 2 and g.plan.rec.any(func(s): return s.get("do","") == "cut"), "%s: the operator's switch and cuts are written down" % ship)
		# a cut that set something off stops the recording there: the line says so, settlement keeps the prefix
		var blocked: bool = g.plan.record_blocked != ""
		print("%s STATUS %s blocked=%s" % [ship, str(g.plan.status()), g.plan.record_blocked])
		check(g.plan.status()[1] == Txt.t("as_plan_rec_stopped" if blocked else "as_plan_rec_line") % rec_n, "%s: the recording line counts the steps%s" % [ship, " (stopped at an incident)" if blocked else ""])
		g.finish_contract(true)
		await frames(2)
		var saved: Array = Career.data.get("plans", {}).get(ship, [])
		check(saved.size() == rec_n and g.plan.result_key == ("plan_saved_prefix" if blocked else "plan_saved"), "%s: the settlement saves the type's plan (%d steps, %s)" % [ship, saved.size(), g.plan.result_key])
		await done(g)
		# the next ship of the type
		g = await game(ship)
		check(g.plan.steps.size() == rec_n, "%s: the next ship of the type has the plan" % ship)
		await replay(g, ship)
		if first:
			# Shift+P at tier 1: it says the skip is tier 2's
			await done(g)
			g = await game(ship)
			press(g)
			press(g, true)
			check(said(g, "as_plan_skip_tier") and g.plan.i == 0 and g.plan.running, "%s: Shift+P at tier 1 says skipping is tier 2" % ship)
			press(g)
			check(not g.plan.running and said(g, "plan_stopped"), "%s: P again stops it" % ship)
			await done(g)
			Career.data.methods = {"cutter": 2}
			g = await game(ship)
			press(g)
			await frames(2)
			var before: int = g.plan.i
			press(g, true)
			check(g.plan.i == before + 1 and said(g, "plan_skipped") and g.plan.running, "%s: Shift+P at tier 2 skips the step the machine is on" % ship)
			for k in 9000:
				await process_frame
				if not g.plan.running: break
			check(g.plan.i == g.plan.steps.size() and said(g, "plan_done"), "%s: after the skip the rest still runs to the end" % ship)
		await done(g)
	Career.data = {}
	print("PLAN P KEY %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	var drain_until := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < drain_until: await process_frame
	quit(0 if fails == 0 else 1)
