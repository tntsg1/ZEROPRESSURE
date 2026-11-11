extends "res://tests/guide_reach_check.gd"
# 引导可达性 (2026-11-10), the guides besides the port walk, with the player's keys only (the helpers of
# tests/guide_reach_check.gd): the on-site task guide's "fly to" steps — the first heat from the berth up to
# the furnace console (E, Enter), then its "往下看" a look with the ring on the furnace; the shuttle task; the
# berth's faults "飞去看看" (logged within Repair.FIND_M); the tripped set's "带我去" (the lead folds within
# 3 m). Each from where the one before left the drone, along the drawn way, no wall passed, in time.
#   tools/run_test.sh tests/guide_reach_tasks_check.gd --fixed-fps 60

const GuideCards = preload("res://scripts/guide_cards.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_reach2_career.json"
	SaveGame.path = "user://zp_test_reach2_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _row(what: String, t0: float, ok: bool, budget: float, note := "") -> void:
	var s := clock - t0
	log_rows.append({"walk": "task", "step": what, "kind": "", "zone": "", "s": s, "ok": ok and s <= budget, "note": note})
	check(ok and s <= budget, "%s: done with the keys in %.1f s (≤ %.0f s) %s" % [what, s, budget, note])


func _run() -> void:
	_career()
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1, "ring": 1}
	Career.data.heat_count = 0
	Career.data.material_batches = []
	Career.data.upgrades = {}
	Career.data.erase("faults_found")
	HallMarket.data().orders = []
	Career.save()
	await _spawn()
	g.bot.erase("move")
	g.bot.erase("brake")
	g.bot.erase("dash")
	await _frames(10)
	var j0 := jumps
	# ---- the berth's faults: fly over to each (the guide's "飞去看看", logged close up)
	g.drone.global_position = Dock.centre() * Geom.M
	for i in 10:
		await _tick()
	for id in Repair.FAULTS:
		if Repair.found(str(id)):
			continue
		g.guide.begin("repair", str(id))
		await _wait_until(func(): return not g.guide.step.is_empty(), 1.0)
		check(bool(g.guide.step.get("fly", false)), "fault %s: a fly step, its way drawn (%s)" % [id, str(g.guide.step.get("title", ""))])
		var t0 := clock
		var ok := await _fly(RepairShow.spot(str(id)), func(): return Repair.found(str(id)), 40.0)
		_row("fault " + str(id), t0, ok, 30.0)
		g.guide.stop()
	# ---- the first heat: from the berth to the furnace console, E, Enter, then the look
	g.drone.global_position = Dock.centre() * Geom.M
	_last = Vector2.INF
	for i in 10:
		await _tick()
	g.guide.begin("heat")
	await _wait_until(func(): return not g.guide.step.is_empty(), 1.0)
	check(bool(g.guide.step.get("fly", false)) and g.guide.step.get("target", Vector2.INF).distance_to(Gal.term("furnace")) < 1.0, "heat: first a fly step to the furnace console (%s)" % str(g.guide.step.get("title", "")))
	var t1 := clock
	var ok1 := await _fly(Gal.term("furnace"), func(): return g.industrial_heat.near() and g.drone.global_position.distance_to(Gal.term("furnace")) < 1.2 * Geom.M and g.drone.linear_velocity.length() < 1.2 * Geom.M, 90.0)
	if ok1:
		await _tap(KEY_E)
		ok1 = await _wait_until(func(): return g.console_ui != null, 1.5)
	_row("heat: berth → furnace console, E", t1, ok1, 75.0, _local(g.drone.global_position))
	if ok1:
		await _tap(KEY_ENTER)
		await _wait_until(func(): return not ProcessQueue.open_entries().is_empty(), 1.5)
		await _close_page()
		var looked := await _wait_until(func(): return str(g.guide.step.get("title", "")).begins_with("往下看") or bool(g.guide.step.get("look", false)), 30.0)
		var st: Dictionary = g.guide.step
		var pl = g.get("plant")
		var furnace := Vector2(float(pl.X) + 1.0, float(pl.F) + 5.0) * Geom.M if pl != null else Vector2.INF
		check(looked and bool(st.get("look", false)) and st.get("target", Vector2.INF).distance_to(furnace) < 1.0 and not bool(st.get("fly", false)),
			"heat: '往下看' is a look — the ring on the furnace, no way drawn (%s · %s)" % [str(st.get("title", "")), str(st.get("name", ""))])
		var seen := await _wait_until(func(): return ViewCull.view(g).grow(-60.0).has_point(furnace), 2.5)
		check(seen, "  and the camera shows the furnace without the drone flown there (drone at %s)" % _local(g.drone.global_position))
	g.guide.stop()
	# ---- the shuttle task: to the nearest stop, E, a district, ridden
	var t2 := clock
	g.guide.begin("transit")
	await _wait_until(func(): return not g.guide.step.is_empty(), 1.0)
	var to: Vector2 = g.guide.step.get("target", Vector2.INF)
	var ok2 := await _arrive(to, 1.5, 40.0, func(): return g.tram.near_station() != "" and g.drone.linear_velocity.length() < 1.0 * Geom.M)
	if ok2:
		await _tap(KEY_E)
		ok2 = await _wait_until(func(): return g.console_ui != null, 1.5) and _press(Port.name_of("power"))
		if ok2:
			ok2 = await _wait_until(func(): return g.tram.riding, 30.0)
			ok2 = ok2 and await _wait_until(func(): return not g.tram.riding and g.tram.phase == "", 40.0)
	_row("transit: to the stop, E, ride to power", t2, ok2, 75.0, "from " + _local(to))
	g.guide.stop()
	# ---- the tripped set's lead (the guide card's only "带我去"): from the power stop to each set's spot
	for gen in ["tg", "fc"]:
		var t3 := clock
		GuideCards.take_me(g, "trip", {"gen": gen})
		await _tick()
		var lead = null
		for c in g.get_children():
			if c.get_script() == preload("res://scripts/guide_lead.gd"):
				lead = c
		check(lead != null, "trip %s: the lead is up" % gen)
		if lead == null:
			continue
		var at: Vector2 = lead.target
		var ok3 := await _fly(at, func(): return not is_instance_valid(lead) or lead.is_queued_for_deletion(), 50.0)
		ok3 = ok3 and g.drone.global_position.distance_to(at) < 3.5 * Geom.M
		_row("trip %s: lead to the set (%s)" % [gen, _local(at)], t3, ok3, 45.0)
		if is_instance_valid(lead):
			lead.queue_free()
	check(jumps == j0, "no wall passed — the drone never jumped (%d)" % (jumps - j0))
	print("REACH TABLE")
	for r in log_rows:
		print("| %s | %.1f | %s | %s |" % [r.step, r.s, "ok" if r.ok else "FAIL", r.note])
	print("GUIDE REACH TASKS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	_release()
	g.queue_free()
	await _frames(4)
	quit()
