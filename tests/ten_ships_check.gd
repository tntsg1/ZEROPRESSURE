extends SceneTree
# 111 号: the ten small ships a new hand meets first (TUG to IH-55) each read like the sample
# ships: a card with two ways, a board with its units, a first step that points somewhere; and
# the five with a mechanism of their own walked through it, the step following each move —
# QC-30's fridge warmed in order, H-22 degaussed / bled / unpinned, JD-38's doors before its
# rail locks, IH-55's bags let down before their tensioners, EV-55 cooled before its instruments.
# Test saves only. godot --headless --fixed-fps 60 --path . -s tests/ten_ships_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
const TEN := ["tug", "pod", "s09", "qc30", "jd38", "h22", "st40", "my48", "ev55", "ih55"]

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
	SaveGame.path = "user://zp_test_tenships_save.json"
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


func _says(st: Dictionary, bit: String) -> bool:
	return not st.is_empty() and str(st.t).find(bit) >= 0


# do what the step says, the way a hand would, until a step says one of `stop` (or 30 steps):
# a port: what it reaches emptied; a switch, a door, a socket, a discharge: thrown once; a step
# under way: a few seconds' wait
func _follow(g, stop: Array, label: String) -> Dictionary:
	var st := NextStep.of(g)
	for i in 30:
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
		var id := ""
		for c in g.world.ctrls:
			if str(st.t).find(str(c)) >= 0 and str(c).length() > id.length():
				id = str(c)
		if id == "":
			return st
		var c = g.world.ctrls[id]
		if c.kind == "port":
			var tg := str(c.target)
			if g.sys.vols.has(tg):
				g.sys.vols[tg].n = 0.0
			if g.sys.fvol.has(tg):
				g.sys.fvol[tg].amount = 0.0
		else:
			_op(g, id)
		await _frames(110 if c.kind in ["door", "hatch"] else 6)
		st = NextStep.of(g)
	return st


# every room let down to nothing and opened, so a step can only be the ship's own
func _open_all(g) -> void:
	for r in g.world.rooms:
		if g.sys.vols.has(r):
			g.sys.vols[r].n = 0.0
		g.world.reveal(r, g.world.rooms[r].bbox.get_center())


func _run() -> void:
	for ship in TEN:
		var g := _start(ship)
		await _frames(30)
		var cd: Dictionary = CoreAsset.card(g)
		var b: Dictionary = CoreAsset.board(g)
		var st: Dictionary = NextStep.of(g)
		print("  %s: %s · %s ｜ %s" % [ship, cd.get("name", ""), Pal.money(float(cd.get("full", 0.0))), st.get("t", "")])
		check(not cd.is_empty() and (cd.methods as Array).size() == 2 and float(cd.full) > 0.0, "%s: a card with two ways and a whole worth" % ship)
		check(not b.is_empty() and not (b.rows as Array).is_empty(), "%s: a board with its units (%d rows)" % [ship, (b.get("rows", []) as Array).size()])
		check(not st.is_empty() and ((st.at as Vector2).is_finite() or st.get("wait", false)), "%s: a first step that points somewhere" % ship)
		var rv: Dictionary = CoreAsset.review(g)
		check(not rv.is_empty() and not (rv.units as Array).is_empty(), "%s: a review" % ship)
		g.queue_free()
		await _frames(3)
	await _qc30()
	await _h22()
	await _jd38()
	await _ih55()
	await _ev55()
	print("TEN SHIPS CHECK %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)


func _qc30() -> void:
	var g := _start("qc30")
	await _frames(30)
	_open_all(g)
	await _frames(5)
	var st := NextStep.of(g)
	print("  qc30 1: ", st.get("t", ""))
	check(_says(st, "VI-LOCK"), "QC-30: the isolation table first")
	_op(g, "VI-LOCK")
	await _frames(3)
	st = NextStep.of(g)
	check(_says(st, "CIRC"), "then the circulation off (%s)" % st.get("t", ""))
	_op(g, "CIRC")
	await _frames(3)
	st = NextStep.of(g)
	check(_says(st, "G-MIX"), "then the mixture recovered at G-MIX (%s)" % st.get("t", ""))
	g.sys.vols[g.dilution.cfg.mix].n = 0.0
	await _frames(3)
	st = NextStep.of(g)
	check(_says(st, "PT"), "then the pulse tube off (%s)" % st.get("t", ""))
	_op(g, "PT")
	await _frames(3)
	st = NextStep.of(g)
	check(st.get("wait", false) and _says(st, "回温") and str(st.how).find("30 K") >= 0, "then warming, no heaters before 30 K (%s)" % st.get("t", ""))
	g.dilution.temp[g.dilution.mxc()] = 40.0
	await _frames(2)
	st = NextStep.of(g)
	check(_says(st, "HEAT"), "past 30 K: the heaters may go on (%s)" % st.get("t", ""))
	for k in g.dilution.temp:
		g.dilution.temp[k] = 293.0
	await _frames(2)
	st = await _follow(g, ["QPU", "STG-"], "qc30")
	check(_says(st, "QPU") or _says(st, "STG-"), "warm: made safe, then the chip and the stack come off (%s)" % st.get("t", ""))
	check(g.dilution.cracked == "", "the chip never cracked on the way")
	g.queue_free()
	await _frames(3)


func _h22() -> void:
	var g := _start("h22")
	await _frames(30)
	_open_all(g)
	await _frames(5)
	var st := await _follow(g, ["DEGAUSS"], "h22")
	print("  h22: ", st.get("t", ""))
	check(_says(st, "DEGAUSS"), "H-22: made safe, then degauss (%s)" % st.get("t", ""))
	_op(g, "DEGAUSS")
	await _frames(3)
	check(g.mech.field("TH-U") < 1.0, "the heads lost their field")
	st = NextStep.of(g)
	print("  h22: ", st.get("t", ""))
	check(_says(st, "ACC-P") or _says(st, "PIN"), "then the accumulator or the pins (%s)" % st.get("t", ""))
	if g.sys.vols.has("ACC"):
		g.sys.vols["ACC"].n = 0.0
	await _frames(3)
	st = NextStep.of(g)
	check(_says(st, "PIN"), "then a pin (%s)" % st.get("t", ""))
	g.queue_free()
	await _frames(3)


func _jd38() -> void:
	var g := _start("jd38")
	await _frames(30)
	var st := await _follow(g, ["先开门"], "jd38")
	print("  jd38: ", st.get("t", ""))
	check(_says(st, "DR-"), "JD-38: made safe, then a door on the boxes' way out (%s)" % st.get("t", ""))
	st = await _follow(g, ["LK-U", "LK-L"], "jd38")
	print("  jd38: ", st.get("t", ""))
	check(_says(st, "LK-U") or _says(st, "LK-L"), "the doors open (on the berth's supply if need be), then the rail lock (%s)" % st.get("t", ""))
	_op(g, "LK-U")
	await _frames(240)
	var b1 = g.world.tag("BOX-1")
	check(b1 != null and b1.body != null, "released, BOX-1 runs out on its rail (loose)")
	g.queue_free()
	await _frames(3)


func _ih55() -> void:
	var g := _start("ih55")
	await _frames(30)
	var st := NextStep.of(g)
	print("  ih55: ", st.get("t", ""))
	check(_says(st, "BV-"), "IH-55: a bag let down first (%s)" % st.get("t", ""))
	for b in g.softshell.cfg.bags:
		g.sys.vols[str(g.softshell.cfg.bags[b].vessel)].n = 0.0
	await _frames(3)
	st = NextStep.of(g)
	print("  ih55: ", st.get("t", ""))
	check(_says(st, "TN-"), "then a tensioner (%s)" % st.get("t", ""))
	g.queue_free()
	await _frames(3)


func _ev55() -> void:
	var g := _start("ev55")
	await _frames(30)
	var st := NextStep.of(g)
	print("  ev55: ", st.get("t", ""))
	check(_says(st, "COOL-S"), "EV-55: the cooling loop first (%s)" % st.get("t", ""))
	_op(g, "COOL-S")
	await _frames(3)
	st = NextStep.of(g)
	print("  ev55: ", st.get("t", ""))
	check(st.get("wait", false) and _says(st, "降温"), "then a wait for the instruments to cool (%s)" % st.get("t", ""))
	for z in g.thermal.temp:
		g.thermal.temp[z] = 40.0
	await _frames(3)
	st = NextStep.of(g)
	print("  ev55: ", st.get("t", ""))
	check(not _says(st, "降温"), "cool: on to the next thing (%s)" % st.get("t", ""))
	g.queue_free()
	await _frames(3)
