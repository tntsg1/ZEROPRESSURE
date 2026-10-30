extends SceneTree
# 110 号: the sample ships' "next step" (scripts/next_step.gd). OB-90 walked the right way round —
# vent the instrument room, the control room, the hatch, the inner door, the three locks, the cover,
# then the outer ring — the step following each move; on the hardcore tier there is none. Then the
# other five sample ships each give a first step that points somewhere.
# Test saves only. godot --headless --fixed-fps 60 --path . -s tests/next_step_check.gd

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("[PASS] " if ok else "[FAIL] ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	SaveGame.path = "user://zp_test_nextstep_save.json"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _start(ship: String) -> Node:
	Game.contract = {}
	Game.start_ship = ship
	SaveGame.load_requested = false
	var g: Node = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	return g


func _ns(g) -> Dictionary:
	return NextStep.of(g)


func _until_open(g, room: String) -> void:
	var n := 0
	while g.world.room_hidden(room) and n < 900:
		await physics_frame
		n += 1
	print("  (%s open after %d frames)" % [room, n])


func _vent(g, room: String) -> void:
	g.sys.vols[room].n = 0.0


func _op(g, id: String) -> void:
	var c = g.world.ctrls[id]
	g._operate(c, g.world.ctrl_world(c))


func _says(st: Dictionary, bits: Array) -> bool:
	if st.is_empty():
		return false
	for b in bits:
		if str(st.t).find(str(b)) < 0:
			return false
	return true


func _run() -> void:
	Txt.hint_tier = "standard"
	var g := _start("ob90")
	await _frames(30)
	var st := _ns(g)
	print("  1: ", st.get("t", ""), " · ", st.get("how", ""))
	check(_says(st, ["G-I"]) and str(st.t).find("抽空") >= 0, "first: vent the instrument room at G-I (%s)" % st.get("t", ""))
	check(st.has("at") and (st.at as Vector2).is_finite() and (st.at as Vector2).distance_to(g.world.ctrl_world(g.world.ctrls["G-I"])) < 1.0, "the mark stands on G-I")
	g.sys.hoses["G-I"] = {"mode": "recover", "t": 0.0}
	await _frames(2)
	st = _ns(g)
	check(st.get("wait", false) and str(st.t).find("泄压中") >= 0, "hosed: venting, under way (%s)" % st.get("t", ""))
	g.sys.hoses.erase("G-I")
	_vent(g, "I")
	await _frames(3)
	st = _ns(g)
	print("  2: ", st.get("t", ""))
	check(_says(st, ["G-C"]), "the inner door is in the control room: vent that at G-C (%s)" % st.get("t", ""))
	_vent(g, "C")
	await _frames(3)
	st = _ns(g)
	print("  3: ", st.get("t", ""))
	check(_says(st, ["HT-C"]), "then open the hatch HT-C (%s)" % st.get("t", ""))
	_op(g, "HT-C")
	await _frames(2)
	st = _ns(g)
	check(g.world.tag("HT-C").door_open, "the hatch is open")
	await _until_open(g, "C")
	check(not g.world.room_hidden("C"), "the control room is open")
	st = _ns(g)
	print("  4: ", st.get("t", ""))
	check(_says(st, ["D-0"]), "then the inner door D-0 (%s)" % st.get("t", ""))
	_op(g, "D-0")
	await _until_open(g, "I")
	check(not g.world.room_hidden("I"), "the instrument room is open")
	st = _ns(g)
	print("  5: ", st.get("t", ""))
	check(_says(st, ["LK-3", "外圈"]), "the outer ring's lock first (%s)" % st.get("t", ""))
	for id in ["LK-3", "LK-2", "LK-1"]:
		_op(g, id)
		await _frames(3)
	st = _ns(g)
	print("  6: ", st.get("t", ""))
	check(_says(st, ["CVR"]), "locked: the cover next (%s)" % st.get("t", ""))
	_op(g, "CVR")
	await _frames(10)
	st = _ns(g)
	check(st.get("wait", false) and str(st.t).find("防尘罩") >= 0, "the cover coming down, under way (%s)" % st.get("t", ""))
	var n := 0
	while g.optics.cover_down() < 0.96 and n < 1800:
		await physics_frame
		n += 1
	st = _ns(g)
	print("  7: ", st.get("t", ""), " · ", st.get("how", ""))
	var seg := ""
	for t in g.optics.cfg.segments:
		if str(st.get("t", "")).find(str(t)) >= 0:
			seg = str(t)
	check(seg != "" and int(g.optics.cfg.segments[seg].ring) == 3, "then a segment of the outer ring (%s)" % st.get("t", ""))
	var b: Dictionary = preload("res://scripts/core_asset.gd").board(g)
	check(b.warn.is_empty() and not b.rows[0].alert, "the board: no warning left, the locks row safe")
	Txt.hint_tier = "hardcore"
	check(_ns(g).is_empty(), "hardcore: no next step")
	Txt.hint_tier = "standard"
	g.queue_free()
	await _frames(3)
	# the lock row before anything: its fix says which switches
	var g2 := _start("ob90")
	await _frames(20)
	var b2: Dictionary = preload("res://scripts/core_asset.gd").board(g2)
	check(b2.rows[0].alert and str(b2.rows[0].get("fix", "")).find("LK-") >= 0, "the locks row says how: %s" % b2.rows[0].get("fix", ""))
	check(str(b2.warn[0]).find("CVR") >= 0, "the cover warning says which switch: %s" % b2.warn[0])
	g2.queue_free()
	await _frames(3)
	for ship in ["sa200", "gr7", "m14", "cf90", "lc140"]:
		var gs := _start(ship)
		await _frames(30)
		var s0 := _ns(gs)
		print("  %s: %s · %s" % [ship, s0.get("t", ""), s0.get("how", "")])
		check(not s0.is_empty() and str(s0.t) != "" and ((s0.at as Vector2).is_finite() or s0.get("wait", false)), "%s: a first step that points somewhere" % ship)
		gs.queue_free()
		await _frames(3)
	print("NEXT STEP CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
