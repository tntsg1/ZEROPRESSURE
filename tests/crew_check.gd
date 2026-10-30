extends SceneTree
# The works crew building for real (92 号, scripts/crew.gd; user 2026-10-28: "硬核的修复就是无人机
# 真的修复那个位置，把残骸拉走"). In the empty berth of a career:
#  - the lights repair: the crew comes in; the broken lamp is a real piece welded in place; the
#    cutter burns the welds; the wreck is hauled off (into the furnace); the boat brings the new
#    lamp and its battery, the hauler sets each on its seat; every bolt run home; the cable laid;
#    the test; the lights are the berth's, nothing of the crew's left in the world
#  - a job loaded half way goes on at its step with what earlier steps left (the parts seated)
#  - a port district's works: the wreck goes aboard the boat
#  - the player's hand (Q4): a wreck the operator takes is left to them
# Own test career and saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/crew_check.gd

const Crew = preload("res://scripts/crew.gd")
var fails := 0
var g


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	Career.path = "user://zp_test_crew_career.json"
	SaveGame.path = "user://zp_test_crew_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _berth() -> void:
	Game.contract = {}
	Game.start_ship = "berth"
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(40)
	g.tutorial = null


func _crew_pieces() -> Array:
	var out: Array = []
	for id in g.world.order:
		var p = g.world.pieces[id]
		if not p.gone and str(p.key).begins_with("crew:"):
			out.append(p)
	return out


func _step() -> String:
	var j := Works.current()
	return "" if j.is_empty() else str(WorksPlan.at(j)[1])


# run until the step changes away from `key` (or the job ends); false on timeout
func _through(key: String, max_s: float) -> bool:
	var n := int(max_s * 60.0)
	for k in n:
		await process_frame
		if _step() != key:
			return true
	return false


func _run() -> void:
	Txt.zh = true
	Crew.in_tests = true
	Career.start_new()
	DevPanel.skip_guides()
	Career.data.upgrades.erase("lights")
	Career.data.works = {"id": "lights", "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0}
	Career.save()
	await _berth()
	await _frames(10)
	var j := Works.current()
	check(j.get("crew", false) and _step() == "isolate", "the crew takes the job (step %s)" % _step())
	check(g.crew.wreck.size() == 2 and not g.crew.wreck[0].gone and g.crew.wreck[0].body == null, "the broken lamp and its hanging cable are real pieces, welded in place")
	check(g.world.joints_of(g.crew.wreck[0]).size() == 2, "two welds hold the lamp")
	check(await _through("isolate", 25.0), "isolate: done when the bot has tagged the circuit out")
	check(g.crew.tagged, "the tag hangs on the box")
	# remove: the welds burnt through, the wreck freed and hauled off
	var welds_before := 0
	for p in g.crew.wreck:
		welds_before += g.world.joints_of(p).size()
	var freed := false
	var n := 0
	while _step() == "remove" and n < 60 * 90:
		await process_frame
		n += 1
		if not freed and g.crew.wreck.any(func(p): return p.body != null):
			freed = true
	check(freed, "cut free, the wreck is loose bodies (%d welds burnt)" % welds_before)
	check(_step() != "remove", "remove: done once the wreck is gone (%.0f s)" % (n / 60.0))
	check(g.crew.wreck.all(func(p): return p.gone), "every piece of wreck is gone (into the furnace or carried off)")
	check(g.crew.swallowed >= 1, "hauled for real: %d piece(s) into the furnace, %d cleared" % [g.crew.swallowed, g.crew.carried])
	# bring and lift: the boat, the parts on their seats
	check(await _through("bring", 30.0), "bring: the boat comes back with the parts")
	check(g.crew.parts.size() == 2 and g.crew.parts.all(func(p): return p.body != null), "the new lamp head and its battery are real bodies")
	check(await _through("lift", 90.0), "lift: each part carried and set down")
	var seated := true
	for k in g.crew.parts.size():
		var b = g.crew.parts[k].body
		var com: Vector2 = b.global_transform * b.center_of_mass
		if not b.freeze or com.distance_to(g.crew.c_of(k)) > 8.0:
			seated = false
	check(seated, "both parts sit on their seats, held fast")
	check(await _through("fasten", 60.0), "fasten: done")
	check(g.crew.bolts.size() == 8 and g.crew.bolts.all(func(b): return b[1]), "all eight bolts run home")
	check(await _through("connect", 40.0), "connect: done")
	check(g.crew.cable.size() >= 3, "a cable laid from the box to the lamp (%d points)" % g.crew.cable.size())
	var ok_end := false
	for k in 60 * 30:
		await process_frame
		if not Works.busy():
			ok_end = true
			break
	check(ok_end and g.has_upgrade("lights"), "test passed: the lights are the berth's")
	check(_crew_pieces().is_empty() and g.crew.drones.is_empty(), "nothing of the crew's left in the world")
	g.queue_free()
	await _frames(3)

	# ---- a job loaded at its fastening: the parts are on their seats already
	Career.data.upgrades.erase("furnace_main")
	var fi := -1
	var st := WorksPlan.steps("furnace_main")
	for k in st.size():
		if str(st[k][0]) == "fasten":
			fi = k
	Career.data.works = {"id": "furnace_main", "kind": "repair", "with_parts": true, "total": 50.0, "left": 20.0, "crew": true, "step": fi}
	Career.save()
	await _berth()
	await _frames(20)
	check(_step() == "fasten", "loaded at the fastening, the crew goes on there")
	check(g.crew.wreck.is_empty() and g.crew.parts.size() == 2 and g.crew.parts.all(func(p): return p.body != null and p.body.freeze), "no wreck any more; the parts already on their seats")
	g.queue_free()
	await _frames(3)

	# ---- the operator's hand (Q4): the wreck held by the drone is left to it
	Career.data.upgrades.erase("net_fix")
	Career.data.works = {"id": "net_fix", "kind": "repair", "with_parts": true, "total": 50.0, "left": 50.0}
	Career.save()
	await _berth()
	await _frames(10)
	await _through("isolate", 25.0)
	var taken = null
	for k in 60 * 40:
		await process_frame
		for p in g.crew.wreck:
			if not p.gone and p.body != null:
				taken = p
				break
		if taken != null:
			break
	check(taken != null, "the torn mesh cut loose")
	if taken != null:
		g.tools.held_body = taken.body
		var pulled := false
		await _frames(2)
		for k in 60 * 12:
			await process_frame
			var hd = g.crew.drones.get("hauler")
			if hd != null and hd.load == taken.body:
				pulled = true
		check(not pulled, "the operator holds a piece: the crew never pulls it away (%d left to the operator)" % g.crew.lent)
		g.tools.held_body = null
		g.world.remove_piece(taken)
		var gone_all := false
		for k in 60 * 150:
			await process_frame
			if _step() != "remove":
				gone_all = true
				break
		if not gone_all:
			print("  net stuck: ", _step(), " q ", g.crew.queue.map(func(a): return a.do), " busy ", g.crew._busy, " wreck ", g.crew.wreck.map(func(p): return [p.gone, p.body != null, g.world.joints_of(p).size()]))
		check(gone_all, "the rest hauled; the piece the operator dealt with counts as gone")
	g.queue_free()
	await _frames(3)

	# ---- a port district's works: the wreck aboard the boat
	Career.data.erase("works")
	var pt: Dictionary = Career.data.get("port", {})
	pt["power"] = 0
	Career.data.port = pt
	Career.data.works = {"id": "port:power:1", "kind": "port", "zone": "power", "stage": 1, "with_parts": true, "total": 60.0, "left": 60.0}
	Career.save()
	await _berth()
	await _frames(10)
	check(g.crew.in_port() and g.crew.wreck.size() >= 1, "at the power district: its burnt switchgear is there to take out (%d)" % g.crew.wreck.size())
	var done_port := false
	for k in 60 * 200:
		await process_frame
		if not Works.busy():
			done_port = true
			break
	if not done_port:
		var cd = g.crew.drones.get("cutter")
		print("  port job stuck at ", _step(), " queue ", g.crew.queue.map(func(a): return a.do), " busy ", g.crew._busy, " wreck ", g.crew.wreck.map(func(p): return [p.gone, p.body != null, g.world.joints_of(p).size()]), " cutter ", cd.global_position if cd else Vector2.INF, " goal ", cd.goal if cd else Vector2.INF, " vel ", cd.vel if cd else Vector2.ZERO, " hauler ", g.crew.drones.get("hauler").global_position if g.crew.drones.has("hauler") else Vector2.INF, " state ", g.state)
	check(done_port and Port.stage("power") >= 1, "the power district's first part built (stage %d)" % Port.stage("power"))
	check(_crew_pieces().is_empty(), "the district clear of the crew's pieces")
	g.queue_free()
	await _frames(3)

	Crew.in_tests = false
	SaveGame.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Career.path))
	print("CREW %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
