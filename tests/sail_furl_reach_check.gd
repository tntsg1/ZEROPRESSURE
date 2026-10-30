extends "res://tests/guide_check.gd"
# user 2026-10-27 ("光帆飞船怎么才能让它完整地收起来？我又进不去"): SA-200 furled the player's way,
# through the real controls in the order the codex and the start hint give — everything in reach
# of the drone, the gondola vented before its hatch, the brakes and motors inside it hidden until
# it is open — and four rolls at the end. Own test saves only.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/sail_furl_reach_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_sail_reach_career.json"
	SaveGame.path = "user://zp_test_sail_reach_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _op(id: String) -> bool:
	var c = g.world.ctrls.get(id)
	if c == null:
		return false
	return g._operate(c, g.world.ctrl_world(c))


func _run() -> void:
	Txt.zh = true
	Game.start_ship = "sa200"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(30)
	g.tutorial = null
	var M := Geom.M
	var inner := Rect2((Dock.BOUNDS.position + Vector2(0.0, 2.0)) * M, (Dock.BOUNDS.size - Vector2(2.5, 2.0)) * M)
	var far := []
	for id in ["GND", "G-G", "HT-G", "W-NW", "W-NE", "W-SE", "W-SW", "F-NW", "F-NE", "F-SE", "F-SW"]:
		if not inner.has_point(g.world.ctrl_world(g.world.ctrls[id])):
			far.append(id)
	check(far.is_empty(), "every control the furling needs is inside the drone's field (%s)" % str(far))
	check(not g.world.rooms["G"].revealed, "the brakes and motors are inside the closed gondola, not seen yet")
	check(str(g.ship.get("hints", {}).get("start", [""])[0]).contains("HT-G") and Txt.t("cx_m_sail_c").contains("HT-G") and Txt.t("cx_m_sail_x").contains("5 kPa"), "the start hint and the codex say the order: earth, vent, hatch, brakes, motors")
	# 1 earth it
	_op("GND")
	check(g.sail.grounded(), "1: earthed at the bottom-left")
	# 2 vent the gondola (the hose's work, done here at once)
	g.sys.vols["G"].n = 0.0
	g.sys.topology_dirty = true
	await _frames(3)
	check(g.sys.P("G") < 5.0, "2: the gondola vented (%.1f kPa)" % g.sys.P("G"))
	# 3 open the hatch
	check(_op("HT-G"), "3: the hatch opens")
	# the door swings open, then the gas grid sees the gondola open to space
	for i in 180:
		await _frames(1)
		if g.world.rooms["G"].revealed:
			break
	check(g.world.rooms["G"].revealed, "  the gondola is open: its brakes and motors are seen")
	# 4 the brakes off, 5 the motors on
	for q in ["NW", "NE", "SE", "SW"]:
		_op("W-" + q)
	await _frames(3)
	check(["NW", "NE", "SE", "SW"].all(func(q): return not g.sail.taut(q)), "4: all four corners slack")
	for q in ["NW", "NE", "SE", "SW"]:
		_op("F-" + q)
	var f := 0
	while not ["NW", "NE", "SE", "SW"].all(func(q): return g.sail.furled(q)) and f < 60 * 120:
		await _frames(1)
		f += 1
	check(["NW", "NE", "SE", "SW"].all(func(q): return g.sail.furled(q)), "5: all four corners furled onto their winches (%.0f s)" % (f / 60.0))
	g.cam_override = g.world.ctrl_world(g.world.ctrls["HT-G"])
	g.zoom_override = 0.12
	await _frames(20)
	Cap.save(root, "res://tests/out/sail_furled_zh.png")
	print("SAIL FURL REACH %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
