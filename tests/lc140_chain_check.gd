extends SceneTree
# LC-140 sample ship, the readable chain (98 号; user 2026-10-28: the small ship alone; out whole
# against broken up; the way out by real geometry; the locks numbered by the cradle; it rolls out
# for real): the card names it and both ways; the board walks the safe sequence; a loose piece in
# the way out stops the winch and is named; cleared, it rolls out (slow to start, steady, easing
# off) and is paid as one; the review says it went out whole. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/lc140_chain_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
var fails := 0
var finished := false


func _initialize() -> void:
	SaveGame.path = "user://zp_test_lc140chain_save.json"
	SaveGame.allow_test = true
	_run()


func _process(_dt: float) -> bool:
	return finished


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	Engine.time_scale = 8.0
	await _frames(int(s * 60.0 / 8.0))
	Engine.time_scale = 1.0


func _ctrl(g, id: String) -> Dictionary:
	var c = g.world.ctrls[id]
	return {"kind": "ctrl", "ctrl": c, "pos": g.world.ctrl_world(c)}


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "lc140"
	var g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(3)
	var ns = g.nested

	# ---- the card and the board as it starts
	var ca: Dictionary = CoreAsset.card(g)
	check(str(ca.get("name", "")) == "内载小船" and ca.methods.size() == 2, "the card: %s, %s" % [ca.get("name", ""), str(ca.methods.map(func(m): return m.name))])
	check(float(ca.full) > 900000.0 + 135600.0 and float(ca.full) < 1100000.0, "whole: %s (premium, equipment, hull)" % Pal.money(ca.full))
	var b0: Dictionary = CoreAsset.board(g)
	var names: Array = b0.rows.map(func(r): return str(r.name))
	check(names == ["电池", "燃料", "气压", "托架锁", "船首门", "出口", "整船"], "the board: %s" % str(names))
	check(str(b0.rows[3].text).contains("下一个 CL-1") and str(b0.rows[5].text) == "净空", "locks: %s · way out: %s" % [b0.rows[3].text, b0.rows[5].text])

	# ---- the safe sequence
	g.do_wrench(_ctrl(g, "SK"))
	g.do_hose(_ctrl(g, "PSF"))
	g.do_hose(_ctrl(g, "G-S"))
	g.do_hose(_ctrl(g, "G-H"))
	var n := 0
	while (not ns.hazards().is_empty() or g.sys.P("H") > 5.0) and n < 600:
		await _secs(5.0)
		n += 5
	for l in ["CL-1", "CL-2", "CL-3", "CL-4"]:
		g.do_wrench(_ctrl(g, l))
		await _frames(2)
	g.do_wrench(_ctrl(g, "BOW"))
	n = 0
	while not ns.door_open() and n < 600:
		await _frames(10)
		n += 10
	check(ns.hazards().is_empty() and ns.locks_held().is_empty() and ns.door_open(), "made safe, the locks off from the stern, the door up")

	# ---- a loose piece in the way out: the winch refuses, the piece named
	var junk = null
	for id in g.world.order:
		var q = g.world.pieces[id]
		if not q.gone and q.cls == "metal" and q.mass > 0.3 and q.mass < 2.0 and not ns.cfg.pieces.has(q.tag) and Geom.centroid(q.poly).x > 80.0 * Geom.M:
			junk = q
			break
	for j in g.world.joints_of(junk).duplicate():
		g.world.kill_joint(j)
	g.world.relink()
	await _frames(2)
	junk.body.global_position = Vector2(14.0, 0.0) * Geom.M
	junk.body.linear_velocity = Vector2.ZERO
	await _frames(40)
	check(ns.exit_block().has(junk.id) and ns.blockers().has("exit"), "a loose piece in the way out: blocked (%s)" % str(ns.blockers()))
	var b1: Dictionary = CoreAsset.board(g)
	check(str(b1.rows[5].text).contains("挡路"), "the board says so: %s" % b1.rows[5].text)
	g.do_wrench(_ctrl(g, "WINCH"))
	await _frames(4)
	check(not ns.out and g.messages.any(func(m): return m[0] == "nested_not_ready" and str(m[3]).contains("出口")), "the winch refuses: %s" % str(g.messages.filter(func(m): return m[0] == "nested_not_ready").map(func(m): return m[3])))
	g.do_wrench(_ctrl(g, "WINCH"))
	# cleared
	junk.body.global_position = Vector2(200.0, -80.0) * Geom.M
	junk.body.linear_velocity = Vector2.ZERO
	await _frames(40)
	check(ns.exit_block().is_empty(), "cleared: the way out is clear")

	# ---- it rolls out
	g.do_wrench(_ctrl(g, "WINCH"))
	await _frames(4)
	check(ns.out and ns.travel() < 0.02, "out it goes, slowly at first (%.3f)" % ns.travel())
	var tt: float = float(ns.cfg.get("time", 12.0))
	await _frames(int(60.0 * tt * 0.5))
	var mid: float = ns.travel()
	check(mid > 0.3 and mid < 0.7 and ns.rolling() > 0.95, "halfway: %.2f of the way, rolling steady (%.2f)" % [mid, ns.rolling()])
	await _frames(int(60.0 * tt * 0.5) + 90)
	check(ns.travel() == 1.0 and ns._ghost.is_empty(), "out and gone")
	var b2: Dictionary = CoreAsset.board(g)
	check(str(b2.rows[6].text).begins_with("已拖出"), "the board: %s" % b2.rows[6].text)
	var rv: Dictionary = CoreAsset.review(g)
	check(str(rv.units[0].text) == "整船拖出" and float(rv.got) > 900000.0 and float(rv.got) <= float(rv.full) + 1.0 and rv.lost.is_empty(), "the review: %s, %s in hand of %s" % [rv.units[0].text, Pal.money(rv.got), Pal.money(rv.full)])
	print("LC140 CHAIN %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true
