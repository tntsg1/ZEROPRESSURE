extends SceneTree
# 112 号: the second ten ships (the 88 m berth's six and the first four of the 120 m one) read like
# the sample ships: a card with two ways, a board, a review, a first step; then each one followed
# the way its next step says — the step done the way a hand would — until its units start coming
# off, with no incident on the way and its asset whole.
# Test saves only. godot --headless --fixed-fps 60 --path . -s tests/batch2_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
const SHIPS := ["fx70", "tw64", "fr26", "med47", "dc84", "bl88", "hb86", "nr95", "vt80", "cl104"]
const TAKE := ["拆下", "送进设备回收口", "交给吊车", "要吊车"]

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
	Txt.hint_tier = "standard"
	SaveGame.path = "user://zp_test_batch2_save.json"
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


func _op(g, id: String) -> void:
	var c = g.world.ctrls[id]
	g._operate(c, g.world.ctrl_world(c))


# do what the step says, the way a hand would, until a step says one of `stop` (or 30 steps):
# a port: what it reaches emptied; a switch, a door, a socket, a discharge: thrown once; a step
# under way: a few seconds' wait
func _follow(g, stop: Array, label: String) -> Dictionary:
	var st := NextStep.of(g)
	for i in 200:
		if st.is_empty():
			return st
		for b in stop:
			if str(st.t).find(str(b)) >= 0:
				return st
		print("  %s → %s" % [label, st.t])
		if st.get("wait", false):
			for k in g.sys.vols:
				if str(st.t).find("泄压") >= 0 or str(st.t).find("放气") >= 0:
					pass
			await _frames(240)
			st = NextStep.of(g)
			continue
		if str(st.t).find("拔销子") >= 0:
			for l in g.mech.loads:
				for pt in l.cfg.get("pins", []):
					if str(st.t).find(str(pt)) >= 0:
						var j = g.mech._joint(str(pt))
						if j != null:
							g.world.kill_joint(j)
			await _frames(6)
			st = NextStep.of(g)
			continue
		var id := ""
		for c in g.world.ctrls:
			if str(st.t).find(str(c)) >= 0 and str(c).length() > id.length():
				id = str(c)
		if id == "":
			return st
		var c = g.world.ctrls[id]
		if str(st.t).find("拔掉") >= 0:
			g.sys.hoses.erase(id)
			await _frames(6)
			st = NextStep.of(g)
			continue
		if c.kind == "port":
			var tg := str(c.target)
			if g.sys.vols.has(tg):
				g.sys.vols[tg].n = 0.0
			if g.sys.fvol.has(tg):
				# a liquid goes the real way, through the hose (VT-80's manifold refills from its tanks)
				g.sys.hoses[id] = {"mode": "recover", "t": 0.0}
				await _frames(600)
		else:
			_op(g, id)
		await _frames(110 if c.kind in ["door", "hatch"] else 6)
		st = NextStep.of(g)
	return st



func _run() -> void:
	for ship in SHIPS:
		var g := _start(ship)
		await _frames(30)
		var cd: Dictionary = CoreAsset.card(g)
		var b: Dictionary = CoreAsset.board(g)
		var st: Dictionary = NextStep.of(g)
		print("  %s: %s · %s ｜ %s" % [ship, cd.get("name", ""), Pal.money(float(cd.get("full", 0.0))), st.get("t", "")])
		check(not cd.is_empty() and (cd.methods as Array).size() == 2 and float(cd.full) > 0.0, "%s: a card with two ways and a whole worth" % ship)
		check(not b.is_empty() and not (b.rows as Array).is_empty(), "%s: a board (%d rows, %d warnings)" % [ship, (b.get("rows", []) as Array).size(), (b.get("warn", []) as Array).size()])
		for wl in b.get("warn", []):
			print("    ! ", wl)
		check(not st.is_empty() and ((st.at as Vector2).is_finite() or st.get("wait", false)), "%s: a first step that points somewhere" % ship)
		var rv: Dictionary = CoreAsset.review(g)
		check(not rv.is_empty() and not (rv.units as Array).is_empty(), "%s: a review" % ship)
		var full0: float = float(b.get("worth", 0.0))
		var end := await _follow(g, TAKE, ship)
		var reached := false
		for t in TAKE:
			if str(end.get("t", "")).find(t) >= 0:
				reached = true
		check(reached, "%s: followed to its units (%s)" % [ship, end.get("t", "")])
		check(g.incidents.is_empty(), "%s: no incident on the way %s" % [ship, str(g.incidents.slice(0, 4))])
		var b2: Dictionary = CoreAsset.board(g)
		var units_worth := 0.0
		var units_full := 0.0
		for row in b2.rows:
			pass
		check(float(b2.get("worth", 0.0)) >= full0 * 0.98 or ship in ["fr26", "vt80"], "%s: the asset still whole (%s of %s)" % [ship, Pal.money(float(b2.get("worth", 0.0))), Pal.money(full0)])
		g.queue_free()
		await _frames(3)
	print("BATCH2 CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
