extends "res://tests/berth_layout_check.gd"
# 船坞自适应 (user 2026-11-08, Q1=B, Q2=A): a contract's berth = its ship's length + 12 m, never under the
# standard 50 m nor past the longest tier bought (a developer's oversize contract still gets the tier it
# needs; a contract saved before keeps the whole berth it had). With 620 m bought, ships of 40, 100 and 300 m
# take 52, 112 and 312 m; with only the standard berth, 50. At each length the berth is clear of the port,
# its bridge comes down to its gate, the shuttle gets to it and the way in for its hull is clear. Then, with
# the cinematics on: a short ship's contract after the 620 m empty berth draws the berth in with the build,
# a long one's after it runs it out again — every frame of both the bridge's foot sits on the gate and the
# port is placed by the berth as it is that frame. Own test saves only.
#   tools/run_test.sh tests/berth_adaptive_check.gd --fixed-fps 60

const ALL := {"berth88": 1, "berth120": 1, "berth200": 1, "berth620": 1}


func _initialize() -> void:
	Career.path = "user://zp_test_berthadapt_career.json"
	SaveGame.path = "user://zp_test_berthadapt_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the empty berth as the last contract left it (Career berth_now), with these extensions bought
func _layout_len(len_: float, up: Dictionary) -> void:
	if g != null and is_instance_valid(g):
		g.queue_free()
		await _frames(4)
	_career()
	var u: Dictionary = Career.data.get("upgrades", {})
	for k in up:
		u[k] = up[k]
	Career.data.upgrades = u
	Career.data["berth_now"] = len_
	Career.save()
	await _spawn()
	await _frames(30)


func _run() -> void:
	# the lengths
	for c in [[40.0, ALL, 52.0], [100.0, ALL, 112.0], [300.0, ALL, 312.0], [40.0, {}, 50.0], [80.0, {}, 88.0], [115.0, ALL, 127.0], [600.0, ALL, 612.0], [608.0, {}, 620.0]]:
		var got := Dock.length_for(float(c[0]), c[1])
		check(absf(got - float(c[2])) < 0.01, "a %.0f m ship, %.0f m bought: a %.0f m berth (%.1f)" % [c[0], Dock.owned(c[1]), c[2], got])
	check(absf(Dock.length_for_tier(40.0, ALL) - 620.0) < 0.01, "a contract saved before keeps the whole berth it had (620)")
	check(absf(Dock.owned(ALL) - 620.0) < 0.01, "what can be taken still reads the longest tier bought (620)")
	# each length laid out: the same checks as every tier's
	for c in [[52.0, ALL], [112.0, ALL], [312.0, ALL], [50.0, {}]]:
		await _layout_len(float(c[0]), c[1])
		check(absf(Dock.FLOOR_X1 - float(c[0])) < 0.05, "%.0f m: the empty berth stays as the last contract left it (%.1f m)" % [c[0], Dock.FLOOR_X1])
		await _check_berth(float(c[0]), float(c[0]) - Dock.BERTH_ROOM)
	if g != null and is_instance_valid(g):
		g.queue_free()
		await _frames(4)
	# the build between: 620 m → a 42 m ship's 54 m → a 138 m ship's 150 m
	await _layout_len(620.0, ALL)
	g.queue_free()
	await _frames(4)
	Game.cine_in_tests = true
	for c in [["gr7", 620.0, 54.0], ["cv138", 54.0, 150.0]]:
		await _contract(str(c[0]), float(c[1]), float(c[2]))
	Game.cine_in_tests = false
	print("BERTH ADAPTIVE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


var save_file := ""
var watch_every := 1          # record_berth_adaptive: frames between the checks
var shots := false


# a contract for this ship started after a berth `from` m long: the berth builds to `to` m
func _contract(ship: String, from: float, to: float) -> void:
	Dock.configure_shape(from, 0.0, 0.0)
	Game.start_ship = ship
	Game.contract = {"id": "ADAPT-" + ship, "ship": ship, "fee": 1000.0, "kit": ALL.duplicate()}
	Career.data.active = Game.contract.duplicate()
	Career.data["berth_now"] = from
	Career.save()
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	var n := 0
	while g.state != "build" and n < 60 * 20:
		await _frames(1)
		n += 1
	check(g.state == "build" and g.build != null, "%s: the contract opens with the berth's build (%.0f → %.0f m)" % [ship, from, to])
	var worst := 0.0
	var mono := true
	var last := from
	var frames := 0
	var M := Geom.M
	while g.state == "build" and frames < 60 * 90:
		await _frames(watch_every)
		frames += watch_every
		var x := Dock.FLOOR_X1
		if (to < from and x > last + 0.01) or (to > from and x < last - 0.01):
			mono = false
		last = x
		# the bridge's foot on the gate, and the port where the berth puts it this frame
		var foot: Vector2 = PortStructure.corridor_end("salvage")
		if g.berth_bridge == null or not g.berth_bridge.visible:
			foot = Vector2.INF
		var gate: Rect2 = g.dock.port_gate()
		var want := Vector2(gate.get_center().x, Dock.RAIL_Y - 0.3) * M
		worst = maxf(worst, foot.distance_to(want) / M)
	check(g.state != "build", "%s: the build finishes (%.1f s)" % [ship, frames / 60.0])
	check(absf(Dock.FLOOR_X1 - to) < 0.05 and absf(g.berth_len - to) < 0.05, "%s: the berth is %.0f m (%.1f)" % [ship, to, Dock.FLOOR_X1])
	check(mono, "%s: it %s all the way, never back" % [ship, "draws in" if to < from else "runs out"])
	check(worst < 0.05, "%s: every frame the bridge's foot is on the gate (worst %.2f m off)" % [ship, worst])
	check(absf(float(Career.data.get("berth_now", 0.0)) - to) < 0.05, "%s: the career remembers the berth at %.0f m" % [ship, to])
	# saved and loaded: the contract keeps its berth even if the rule would now give another
	var d := {}
	if to > 100.0:
		# the save is only made once it is at work (the hull brought in)
		var w := 0
		while g.state != "play" and w < 60 * 60:
			await _frames(1)
			w += 1
		SaveGame.save(g)
		await _frames(5)
		save_file = SaveGame.file_for(g)
		d = SaveGame.read(save_file)
		check(absf(float(d.get("berth_len", -1.0)) - to) < 0.05, "%s: its save keeps the berth's length (%.1f)" % [ship, float(d.get("berth_len", -1.0))])
	g.queue_free()
	await _frames(4)
	if to > 100.0:
		# a save from before (no length in it): the whole berth it had then, not the ship's
		d.erase("berth_len")
		SaveGame.write_file(save_file, d)
		Game.start_ship = ship
		Game.contract = {"id": "ADAPT-" + ship, "ship": ship, "fee": 1000.0, "kit": ALL.duplicate()}
		Career.data.active = Game.contract.duplicate()
		SaveGame.load_requested = true
		g = load("res://scenes/main.tscn").instantiate()
		root.add_child(g)
		current_scene = g
		await _frames(20)
		check(absf(g.berth_len - 620.0) < 0.05, "%s: an old save of it keeps the 620 m berth it had then (%.1f)" % [ship, g.berth_len])
		g.queue_free()
		await _frames(4)
