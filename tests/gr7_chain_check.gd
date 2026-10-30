extends SceneTree
# GR-7 sample ship, the readable chain (95 号; user 2026-10-28: the propulsion set and the hold's
# cargo; careful against demolition, money and time measured by the salvage bot): the card names
# both groups and both ways; the board has a row per unit with its state and worth; a knock and a
# cut through a unit are logged with their cause and money; the review counts what each group kept,
# the losses by cause, and says what to do next time. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/gr7_chain_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
var g
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_gr7chain_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "gr7"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null

	# ---- the card
	check(CoreAsset.has(g), "GR-7 has a core asset")
	var ca: Dictionary = CoreAsset.card(g)
	check(str(ca.get("name", "")) == "推进总成与货舱货物" and ca.methods.size() == 2, "the card: %s, %d ways" % [ca.get("name", ""), ca.methods.size()])
	var whole := 0.0
	for t in ["ENG-C", "ENG-F", "T-F01", "C-01", "C-02", "C-03"]:
		var p = g.world.tag(t)
		check(p != null, "unit %s aboard" % t)
		if p != null:
			whole += float(p.value)
	check(absf(float(ca.full) - whole) < 1.0, "whole: %s" % Pal.money(ca.full))
	for m in ca.methods:
		check(float(m.hi) >= float(m.lo) and (m.minutes as Array).size() == 2 and str(m.risks) != "", "%s: %s–%s, %s min" % [m.name, Pal.money(m.lo), Pal.money(m.hi), str(m.minutes)])
	check(float(ca.methods[0].hi) > float(ca.methods[1].hi), "taking it apart pays more than breaking it up")
	check(int(ca.methods[0].minutes[0]) > int(ca.methods[1].minutes[0]) and str(ca.methods[1].risks).contains("实测"), "the time and money measured by the bot, not guessed")

	# ---- the board as it starts: a row per unit, all whole, the ship not yet safe
	var b0: Dictionary = CoreAsset.board(g)
	check(b0.rows.size() == 6 and b0.rows.all(func(r): return str(r.text).ends_with("完好")), "the board: six units, whole")
	check(absf(float(b0.worth) - whole) < 1.0, "worth all of it: %s" % Pal.money(b0.worth))
	print("    warn ", b0.warn)

	# ---- a knock on the way, and the beam through a unit
	var eng = g.world.tag("ENG-F")
	g._dent(eng, maxf(0.0, eng.cond - 0.3), "dv_impact")
	var crate = g.world.tag("C-02")
	g.on_cut_into(crate, g.world.frame(crate) * Geom.centroid(crate.poly))
	await _frames(2)
	var b1: Dictionary = CoreAsset.board(g)
	check(b1.recent.size() >= 2 and str(b1.recent[0].text) == "C-02 · 切坏" and str(b1.recent[1].text) == "ENG-F · 撞伤", "the losses as they come: %s" % str(b1.recent.map(func(r): return "%s −%s" % [r.text, Pal.money(r.money)])))
	check(CoreAsset.unit_state(g, eng) == "受损 30%" and CoreAsset.unit_state(g, crate) == "切坏", "the states: %s / %s" % [CoreAsset.unit_state(g, eng), CoreAsset.unit_state(g, crate)])
	check(float(b1.worth) < whole - float(crate.value) + 1.0, "worth less: %s" % Pal.money(b1.worth))

	# ---- the review
	var rv: Dictionary = CoreAsset.review(g)
	var words: Array = rv.units.map(func(u): return str(u.text))
	check(words.has("推进总成：保住 3 / 3 件") and words.has("货舱货物：保住 2 / 3 件"), "the groups: %s" % str(words))
	var kinds: Array = rv.lost.map(func(l): return l.k)
	check(kinds.size() == 2 and kinds.has("eq_cut") and kinds.has("eq_impact"), "the losses by cause: %s" % str(kinds))
	check(str(rv.advice) == CoreAsset.advice(str(rv.lost[0].k)), "next time: %s" % rv.advice)
	check(rv.reasons.size() >= 2, "why: %s" % str(rv.reasons))
	print("GR7 CHAIN %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
