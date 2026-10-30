extends "res://tests/guide_check.gd"
# 87-5: every facility built by its own trade. Each berth repair and each port district's two
# stages has a plan: its family's machines and steps (a crane goes up by the assist crane and the
# hydraulic wrench, the power district by the transformer barge, the cable layer and energising,
# the ring by track lengths and contact wire), the job still as long as its price says. The steps
# run in order with the parts going up one by one; while something hangs on the crane the drone in
# the lift zone stops the work; a job half done survives a save; done, the facility is the port's
# (the crane in the upgrades, the power district at stage 1, then 2). One shot per trade.
# Own test saves only.
#   tools/run_test.sh tests/works_trades_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_trades_career.json"
	SaveGame.path = "user://zp_test_trades_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _job(id: String, kind: String, total: float, extra: Dictionary = {}) -> void:
	var j := {"id": id, "kind": kind, "with_parts": false, "total": total, "left": total}
	j.merge(extra, true)
	Career.data.works = j
	Career.save()


func _keys(id: String) -> Array:
	return WorksPlan.steps(id, 100.0).map(func(s): return str(s[0]))


func _machines(id: String) -> Array:
	var out: Array = []
	for i in WorksPlan.steps(id, 100.0).size():
		out.append(WorksPlan.machine(id, i))
	return out


func _run() -> void:
	Txt.zh = true
	Career.start_new()
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.save()
	# every facility has its trade
	var missing: Array = []
	for row in Repair.ITEMS:
		if not WorksPlan.has(str(row[0])):
			missing.append(row[0])
	for z in Port.ZONES:
		for n in [1, 2]:
			if not WorksPlan.has("port:%s:%d" % [z, n]):
				missing.append("port:%s:%d" % [z, n])
	check(missing.is_empty(), "every berth repair and every district stage has its own plan (%s)" % str(missing))
	var fams := {}
	for row in Repair.ITEMS:
		fams[WorksPlan.family(str(row[0]))] = true
	for z in Port.ZONES:
		fams[WorksPlan.family("port:%s:1" % z)] = true
	check(fams.size() >= 8, "%d different trades" % fams.size())
	check(_machines("crane").has("crane") and _machines("crane").has("torque") and _keys("crane").has("connect"), "the crane: an assist crane, a hydraulic wrench, rope reeved (%s)" % str(_machines("crane")))
	check(_machines("port:power:1").has("cable") and WorksPlan.family("port:power:1") == "power", "the power district: the cable layer, energising")
	check(_machines("arm").has("survey"), "the arm: laser alignment")
	check(_machines("gas_line")[0] == "purge" and _machines("gas_line").has("welder"), "the gas line: purged first, the joints welded")
	var texts := func(id): return WorksPlan.steps(id, 100.0).map(func(st): return str(st[2]))
	check(texts.call("crane") != texts.call("port:power:1") and WorksPlan.spec("crane").part[0] != WorksPlan.spec("port:power:1").part[0] and _machines("arm") != _machines("crane"), "the trades differ: their steps, their parts, their machines")
	# the time is still what the price says (no rebalancing of the economy)
	Works.BUILD_TIME = true
	var cost := Repair.price("crane", false)
	var t_old := Works.duration(cost)
	var s := 0.0
	for st in WorksPlan.steps("crane", t_old):
		s += float(st[1])
	check(absf(s - t_old) < 0.01, "the crane's steps add up to its old time (%.0f s)" % t_old)

	await _spawn()
	await _frames(10)
	# the crane, step by step
	_job("crane", "repair", t_old)
	var seen: Array = []
	var units: Array = []
	var shots := {}
	var far := Vector2(-200.0, -200.0) * Geom.M
	while Works.busy():
		var a := WorksPlan.at(Works.current())
		if seen.is_empty() or seen[seen.size() - 1] != str(a[1]):
			seen.append(str(a[1]))
		if str(a[1]) == "lift":
			units.append(g.works_site._units_up(Works.current(), int(a[0]), float(a[2])))
		var m := WorksPlan.machine("crane", int(a[0]))
		if not shots.has(m) and float(a[2]) > 0.45 and m in ["crane", "torque", "cable", "tester", "boat"]:
			shots[m] = true
			g.cam_override = Works.spot() + Vector2(0, -3.0 * Geom.M)
			g.zoom_override = 1.1
			for k in 70:
				await process_frame
			Cap.save(root, "res://tests/out/trades_crane_%s_zh.png" % m)
			g.cam_override = null
			g.zoom_override = -1.0
		if Works.advance(0.5, far):
			break
		await process_frame
	check(seen == _keys("crane"), "the crane's steps run in order (%s)" % str(seen))
	check(units.size() > 2 and units[0] < units[units.size() - 1] and units[units.size() - 1] > 3.0, "the jib sections go up one by one (%.1f -> %.1f)" % [units[0] if not units.is_empty() else -1.0, units[units.size() - 1] if not units.is_empty() else -1.0])
	check(Career.data.upgrades.has("crane"), "done: the crane is the berth's")

	# the lift zone: the drone under the load stops the work
	_job("arm", "repair", 60.0)
	var lift_at := 0.0
	for st in WorksPlan.steps("arm", 60.0):
		if str(st[0]) == "lift":
			break
		lift_at += float(st[1])
	Works.advance(lift_at + 0.5, far)
	check(Works.lifting(Works.current()), "the arm's sections hanging on the crane")
	var left0 := float(Works.current().left)
	Works.advance(2.0, Works.spot())
	check(Works.held == "lockout" and is_equal_approx(float(Works.current().left), left0), "the drone in the lift zone: the work stops")
	g.drone.global_position = Works.spot() + Vector2(2.0 * Geom.M, -1.0 * Geom.M)
	g.cam_override = Works.spot() + Vector2(0, -3.0 * Geom.M)
	g.zoom_override = 1.1
	for k in 70:
		await process_frame
	Cap.save(root, "res://tests/out/trades_lockout_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	Works.advance(2.0, far)
	check(float(Works.current().left) < left0, "out of it, the work goes on")
	# half done survives a save
	var cur_left := float(Works.current().left)
	Career.save()
	Career.data = {}
	Career.load_or_new()
	check(Works.busy() and is_equal_approx(float(Works.current().left), cur_left) and Works.lifting(Works.current()) == WorksPlan.at(Works.current())[1].begins_with("lift"), "a job half done is where it was after loading")
	while Works.busy():
		Works.advance(1.0, far)
	check(Career.data.upgrades.has("arm"), "done: the arm is the berth's")

	# the power district, both stages: shots of its trade
	for n in [1, 2]:
		_job("port:power:%d" % n, "port", 60.0, {"zone": "power", "stage": n})
		var shot_m := {}
		while Works.busy():
			var a2 := WorksPlan.at(Works.current())
			var m2 := WorksPlan.machine("port:power:%d" % n, int(a2[0]))
			if n == 1 and not shot_m.has(m2) and float(a2[2]) > 0.5 and m2 in ["boat", "crane", "cable", "tester"]:
				shot_m[m2] = true
				g.cam_override = Works.spot() + Vector2(0, -2.0 * Geom.M)
				g.zoom_override = 1.1
				for k in 70:
					await process_frame
				Cap.save(root, "res://tests/out/trades_power_%s_zh.png" % m2)
				g.cam_override = null
				g.zoom_override = -1.0
			if Works.advance(0.5, far):
				break
			await process_frame
		check(Port.stage("power") == n, "the power district's stage %d built" % n)
	# a weld and a ring shot for the record
	for pair in [["berth88", "repair", {}, "welder", "trades_structure_weld_zh"], ["port:ring:1", "port", {"zone": "ring", "stage": 1}, "cable", "trades_ring_wire_zh"], ["gas_line", "repair", {}, "purge", "trades_pipe_purge_zh"]]:
		_job(str(pair[0]), str(pair[1]), 60.0, pair[2])
		var done := false
		while Works.busy() and not done:
			var a3 := WorksPlan.at(Works.current())
			if WorksPlan.machine(str(pair[0]), int(a3[0])) == str(pair[3]) and float(a3[2]) > 0.5:
				g.cam_override = Works.spot() + Vector2(0, -2.0 * Geom.M)
				g.zoom_override = 1.1
				for k in 70:
					await process_frame
				Cap.save(root, "res://tests/out/%s.png" % str(pair[4]))
				g.cam_override = null
				g.zoom_override = -1.0
				done = true
			Works.advance(0.5, far)
			await process_frame
		Career.data.erase("works")
		check(done, "%s: its %s at work" % [pair[0], pair[3]])
	Career.save()
	g.queue_free()
	await _frames(4)
	print("WORKS TRADES %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
