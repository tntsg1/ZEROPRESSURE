extends SceneTree
# CF-90 sample ship, the readable chain (97 号; user 2026-10-28: all 26 containers, by bay on the
# board; ends inwards against props first; a bending bar over each bay): the card names the wall
# and both ways; the board has a row a bay with its boxes, bending and worth, and warns of the
# tight rods; a bay emptied out of order kinks, logged by cause on the boxes beyond it; the review
# groups the boxes by state, the losses by cause, and says what to do next time. Own saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/cf90_chain_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
var g
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_cf90chain_save.json"
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


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "cf90"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null

	# ---- the card
	check(CoreAsset.has(g), "CF-90 has a core asset")
	var ca: Dictionary = CoreAsset.card(g)
	check(str(ca.get("name", "")) == "货柜墙" and ca.methods.size() == 2 and str(ca.methods[1].name) == "撑杆抢里侧", "the card: %s, %s" % [ca.get("name", ""), str(ca.methods.map(func(m): return m.name))])
	var whole := 0.0
	for bay in g.boxbeam.cfg.bays:
		for t in bay:
			whole += float(g.world.tag(str(t)).value)
	check(absf(float(ca.full) - whole) < 1.0, "whole: %s, 26 boxes" % Pal.money(ca.full))

	# ---- the board as it starts
	var b0: Dictionary = CoreAsset.board(g)
	check(b0.rows.size() == 7 and str(b0.rows[3].text).contains("船坞夹持") and str(b0.rows[0].text).begins_with("4/4 箱"), "the board, a row a bay: %s" % str(b0.rows.map(func(r): return r.text)))
	check((b0.warn as Array).any(func(x): return str(x).contains("花篮螺丝")), "the rods still tight, warned")
	check(g.boxbeam.bars != null, "the bending bars over the bays")

	# ---- bay 3 emptied with bays 1–2 full: the wall kinks, the boxes beyond it damaged
	for t in ["C31", "C32", "C33", "C34"]:
		_free(t)
		await _frames(3)
	await _frames(30)
	var b1: Dictionary = CoreAsset.board(g)
	check(g.boxbeam.kinked.has("fwd") and str(b1.rows[2].text).contains("已折弯"), "bay 3 out of order: %s" % b1.rows[2].text)
	check(not b1.recent.is_empty() and str(b1.recent[0].text).ends_with("箱梁折弯"), "the losses as they come: %s" % str(b1.recent.map(func(r): return "%s −%s" % [r.text, Pal.money(r.money)])))

	# ---- the review
	var rv: Dictionary = CoreAsset.review(g)
	var words: Array = rv.units.map(func(u): return str(u.text))
	check(words.any(func(s): return s.begins_with("受损 8 箱")) and words.any(func(s): return s.begins_with("完好")), "the boxes by state: %s" % str(words))
	var kinds: Array = rv.lost.map(func(l): return l.k)
	check(kinds.has("kink"), "the losses by cause: %s" % str(kinds))
	check(str(rv.advice) == CoreAsset.advice("kink"), "next time: %s" % rv.advice)
	print("CF90 CHAIN %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
