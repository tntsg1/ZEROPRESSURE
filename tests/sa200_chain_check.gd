extends SceneTree
# SA-200 sample ship, the readable chain (93 号; user 2026-10-27 "这一单是我赚出来的", 2026-10-28
# answers): the contract card names the core asset and both ways with money, time and risk; the
# board follows each corner and logs every loss with its cause and money; the review says what
# came in, what was lost and why, and one thing to do next time. Own test saves only.
#   godot --headless --path . --fixed-fps 60 -s tests/sa200_chain_check.gd

const CoreAsset = preload("res://scripts/core_asset.gd")
var g
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _initialize() -> void:
	SaveGame.path = "user://zp_test_sa200chain_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _switch(id: String, on: bool) -> void:
	g.sys.set_switch(id, on)
	g.world.ctrls[id].state = on


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	Game.start_ship = "sa200"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(10)
	g.tutorial = null
	var sl = g.sail

	# ---- the card
	var ca: Dictionary = CoreAsset.card(g)
	check(ca.get("name", "") == "光帆" and ca.methods.size() == 2, "the card names the core asset and two ways")
	var furl: Dictionary = ca.methods[0]
	var scrap: Dictionary = ca.methods[1]
	check(furl.lo > 100000.0 and furl.hi <= 168000.0 and furl.lo < furl.hi, "furled whole: %s–%s" % [Pal.money(furl.lo), Pal.money(furl.hi)])
	check(scrap.hi < furl.lo * 0.2, "cut to scrap: about %s" % Pal.money(scrap.hi))
	check((furl.minutes as Array).size() == 2 and str(furl.risks).contains("张力") and str(scrap.risks) != "", "each with its time and its risk")
	var b0: Dictionary = CoreAsset.board(g)
	check(b0.rows.size() == 4 and b0.recent.is_empty() and float(b0.worth) > 100000.0, "the board: four corners, nothing lost yet, worth %s" % Pal.money(b0.worth))

	# ---- a panel cut while its corner is taut: logged with its cause and money
	var panel := ""
	for t in sl.cfg.panels:
		if str(sl.cfg.panels[t].quad) == "SE" and not sl.torn.has(t):
			panel = str(t)
			break
	_switch("GND", true)
	sl.on_cut(g.world.tag(panel))
	await _frames(2)
	var ev: Array = sl.events.filter(func(e): return e.k == "cut_taut")
	check(not ev.is_empty() and float(ev[0].money) > 1000.0 and str(ev[0].q) == "SE", "cut taut: logged as such at SE, −%s" % Pal.money(float(ev[0].money) if not ev.is_empty() else 0.0))
	var b1: Dictionary = CoreAsset.board(g)
	check(not b1.recent.is_empty() and str(b1.recent[0].text).contains("带张力切断"), "the board shows it: %s" % (str(b1.recent[0].text) if not b1.recent.is_empty() else "-"))
	check(float(b1.worth) < float(b0.worth), "the sail is worth less now: %s" % Pal.money(b1.worth))
	# stop the tear running: slacken SE
	_switch("W-SE", false)

	# ---- NW furled unearthed: static pinholes, logged; NE furled properly
	_switch("GND", false)
	_switch("W-NW", false)
	_switch("F-NW", true)
	for k in 60 * 60:
		await process_frame
		if sl.furled("NW"):
			break
	check(sl.furled("NW") and sl.events.any(func(e): return e.k == "static"), "NW wound unearthed: static logged")
	_switch("GND", true)
	_switch("W-NE", false)
	_switch("F-NE", true)
	for k in 60 * 60:
		await process_frame
		if sl.furled("NE"):
			break
	var ne: Dictionary = sl.corner_state("NE")
	# NE holds the panel torn before the ship came in: its best is under A
	check(ne.done and float(ne.grade) >= 0.8 and not sl.events.any(func(e): return e.q == "NE"), "NE earthed and slack: rolled grade %s (%d%%), no loss of its own" % [sl.grade_letter(float(ne.grade)), int(float(ne.grade) * 100.0)])
	var b2: Dictionary = CoreAsset.board(g)
	var rows_done: int = b2.rows.filter(func(r): return r.done).size()
	check(rows_done == 2, "the board: two corners rolled")

	# ---- the review
	var rv: Dictionary = CoreAsset.review(g)
	check(rv.units.size() == 2, "the review lists the two rolls")
	check(rv.units.all(func(r): return str(r.sub).contains("绞盘")), "still on their winches: said so")
	var kinds: Array = rv.lost.map(func(l): return l.k)
	check(kinds.has("cut_taut") and kinds.has("static"), "what was lost, by cause: %s" % str(kinds))
	check(rv.reasons.size() >= 2 and str(rv.reasons[0]).contains("收成 2 卷") and str(rv.reasons[0]).contains("挂在绞盘上"), "why: %s" % str(rv.reasons))
	check(str(rv.advice) != "" and (str(rv.advice) == CoreAsset.advice(str(rv.lost[0].k))), "next time: %s" % rv.advice)

	# ---- saved and read back: the log goes with it
	var st: Dictionary = sl.save_state()
	check((st.get("events", []) as Array).size() == sl.events.size(), "the losses are kept in the save")
	print("SA200 CHAIN %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
