extends SceneTree
# CF-90's temporary prop (97 号; user 2026-10-28: new field gear, lent two on CF-90; under a bay it
# carries that bay and every bay outboard; rated 60 t, past that it bows and buckles): with a prop
# under bay 2 the inner bay 3 is emptied first and the wall holds; the prop taken away, the wall
# kinks at once; a prop under bay 5 carrying three full bays (about 78 t) bows and buckles, and is
# lost. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/cf90_prop_check.gd

var g
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_cf90prop_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _free(t: String) -> void:
	var p = g.world.tag(t)
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	g.world.relink()


func _place(bay_tag: String) -> Dictionary:
	var gr = g.gear
	gr.sel = gr.carried_types().find("prop")
	var p = g.world.tag(bay_tag)
	var at: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
	var tg: Dictionary = gr.target(at, {}, {"kind": "piece", "piece": p, "pos": at})
	if tg.is_empty():
		return {}
	gr.act(tg)
	return gr.props().back()


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "cf90"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	var bx = g.boxbeam
	var gr = g.gear
	check(gr.carried.filter(func(c): return c.type == "prop").size() == 2 and gr.carried.all(func(c): return c.lent), "two props lent for CF-90: %s" % str(gr.carried))

	# ---- a prop under bay 2 (index 1): bays 1 and 2 bear on it
	var u := _place("C21")
	check(not u.is_empty() and int(u.bay) == 1, "the prop stands under bay 2")
	await _frames(20)
	check(absf(float(u.load) - bx.prop_load(1)) < 0.01 and u.load > 50.0 and u.load < 60.0, "it carries bays 1–2: %.1f t of its 60" % u.load)
	check(bx.bend(1) == 0.0 and bx.bend(0) == 0.0, "the propped bays bend no more")
	# bay 3 (index 2) emptied first, from the top: the wall holds
	for t in ["C31", "C32", "C33", "C34"]:
		_free(t)
		await _frames(3)
	await _frames(30)
	check(not bx.kinked.has("fwd") and bx.bend(2) == 0.0, "bay 3 emptied first with the prop in: no kink (bend %.0f%%)" % (bx.bend(2) * 100.0))
	# the prop taken away: the load is back on the empty bay
	gr.retrieve(u)
	await _frames(30)
	check(bx.kinked.has("fwd") and int(bx.kink_bay.fwd) == 2, "the prop taken away: the wall kinks at the empty bay")

	# ---- a prop under bay 5 (index 4): bays 5–7, about 78 t, past its rating
	var u2 := _place("C51")
	check(not u2.is_empty() and int(u2.bay) == 4, "a prop under bay 5")
	await _frames(20)
	check(u2.load > 60.0 and float(u2.over) > 0.0, "it carries %.1f t: past 60, bowing (%.1f s)" % [u2.load, u2.over])
	await _frames(120)
	check(not gr.units.has(u2) and gr.lost.any(func(l): return l.type == "prop" and l.why == "gear_why_buckled"), "and it buckled: lost")
	check(g.incidents.any(func(i): return i[1] == "prop_buckle"), "an incident: %s" % str(g.incidents.filter(func(i): return i[1] in ["prop_buckle", "beam_kink"])))
	print("CF90 PROP %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
