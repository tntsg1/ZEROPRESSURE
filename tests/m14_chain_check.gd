extends SceneTree
# M-14 sample ship, the readable chain (96 号; user 2026-10-28: the ore and the crushing line
# together; the gates slowly against prising the hopper open; the hopper's state by the hopper
# too): the card names both and both ways; the board has the hopper, the chunks, each gate and the
# line's units; a gate opened pays the fines as they run; a wall taken off below the heap pours
# the fines out unpaid and says so; the review counts the ore in and lost and the line kept, the
# losses by cause, and what to do next time. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/m14_chain_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
var g
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_m14chain_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _free(p) -> void:
	for j in g.world.joints_of(p).duplicate():
		g.world.kill_joint(j)
	g.world.relink()


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "m14"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	var o = g.ore

	# ---- the card
	check(CoreAsset.has(g), "M-14 has a core asset")
	var ca: Dictionary = CoreAsset.card(g)
	check(str(ca.get("name", "")) == "矿料与破碎筛分总成" and ca.methods.size() == 2, "the card: %s, %d ways" % [ca.get("name", ""), ca.methods.size()])
	var of := CoreAsset.ore_full(g)
	check(of > 34.0 * 900.0, "the ore whole: %s (the fines alone %s)" % [Pal.money(of), Pal.money(34.0 * 900.0)])
	check(absf(float(ca.full) - of - 56000.0) < 1.0, "whole, ore and line: %s" % Pal.money(ca.full))
	check(o.shell.size() == 6, "the hopper's shell found: %s" % str(o.shell.keys()))

	# ---- the board as it starts
	var b0: Dictionary = CoreAsset.board(g)
	var names: Array = b0.rows.map(func(r): return str(r.name))
	check(names.slice(0, 4) == ["矿仓", "矿块", "GATE-1", "GATE-2"] and b0.rows.size() == 9, "the board: %s" % str(names))
	check(str(b0.rows[2].text).ends_with("关"), "the gates shut: %s" % b0.rows[2].text)

	# ---- a gate opened: the fines run and pay
	g.world.tag("GATE-1").door_open = true
	await _frames(120)
	var b1: Dictionary = CoreAsset.board(g)
	check(o.paid > 100.0 and o.fines < 34.0, "through the gate: %.1f t left, %s in" % [o.fines, Pal.money(o.paid)])
	check(str(b1.rows[2].text).contains("t/s") or str(b1.rows[2].text).contains("堵拱"), "the gate's row: %s" % b1.rows[2].text)
	g.world.tag("GATE-1").door_open = false
	await _frames(5)

	# ---- a wall off below the heap: the fines pour out of it, unpaid
	var paid0: float = o.paid
	_free(o.shell["HW-L"][0])
	await _frames(150)
	check(o.spilled > 1.0 and absf(o.paid - paid0) < 1.0, "the hole: %.1f t out of it, nothing paid for it" % o.spilled)
	var b2: Dictionary = CoreAsset.board(g)
	check((b2.warn as Array).any(func(x): return str(x).contains("细矿正在洒落")) or o.fines <= 0.0, "warned: %s" % str(b2.warn))
	check(b2.recent.any(func(r): return str(r.text) == "ORE · 细矿洒落"), "the loss as it comes: %s" % str(b2.recent.map(func(r): return "%s −%s" % [r.text, Pal.money(r.money)])))

	# ---- the beam through the crusher
	var cr = g.world.tag("CRUSH-H")
	g.on_cut_into(cr, g.world.frame(cr) * Geom.centroid(cr.poly))
	await _frames(2)
	check(CoreAsset.unit_state(g, cr) == "切坏", "the crusher cut: %s" % CoreAsset.unit_state(g, cr))

	# ---- the review
	var rv: Dictionary = CoreAsset.review(g)
	var words: Array = rv.units.map(func(u): return str(u.text))
	check(str(words[0]).begins_with("矿料：收") and words.has("破碎筛分：保住 4 / 5 件"), "the review: %s" % str(words))
	print("    ", rv.units[0].sub)
	var kinds: Array = rv.lost.map(func(l): return l.k)
	check(kinds.has("ore_spill") and kinds.has("eq_cut"), "the losses by cause: %s" % str(kinds))
	check(str(rv.advice) == CoreAsset.advice(str(rv.lost[0].k)), "next time: %s" % rv.advice)
	print("M14 CHAIN %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
