extends SceneTree
# 87-4: SA-200 "Kite": the furled light sail is the ship's prize. The ship's value counts it; the
# careful way (earthed, the corners slack, each corner's furling motor on) winds every panel onto
# its winch (each panel really shortening as it goes) and leaves a roll per corner, bolted, graded
# by good area x quality; a corner with a torn panel grades lower. Wound taut, the film overloads
# and the motor trips; wound unearthed, it is pinholed; the quick way (cut the film) leaves scrap
# worth almost nothing. A roll is equipment of its own, shelved in a career as a sail roll and
# sold once from the rack. The furling survives a save half-way. Own test saves only.
#   tools/run_test.sh tests/sail_roll_check.gd --fixed-fps 60
const Cap = preload("res://tests/cap.gd")
const Sail = preload("res://scripts/sail.gd")
var g: Node
var fails := 0
var checks := 0
var report: Array = []


func _initialize() -> void:
	Career.path = "user://zp_test_sailroll_career.json"
	SaveGame.path = "user://zp_test_sailroll_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _game() -> Node:
	Game.contract = {}
	Game.start_ship = "sa200"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(scene)
	await _frames(10)
	scene.tutorial = null
	return scene


func _switch(id: String, on: bool) -> void:
	g.sys.set_switch(id, on)
	g.world.ctrls[id].state = on


func _prep(earth: bool, slack: bool) -> void:
	_switch("GND", earth)
	for w in ["W-NW", "W-NE", "W-SE", "W-SW"]:
		_switch(w, not slack)


func _motors(on: bool) -> void:
	for q in ["NW", "NE", "SE", "SW"]:
		_switch("F-" + q, on)


func _wait_furled(limit_s: float) -> float:
	var t := 0.0
	while t < limit_s:
		await process_frame
		t += 1.0 / 60.0
		var all := true
		for q in ["NW", "NE", "SE", "SW"]:
			if not g.sail.furled(q):
				all = false
		if all:
			break
	return t


func _run() -> void:
	Txt.zh = true
	SaveGame.clear()
	# the books
	var d: Dictionary = Ship.load_data("sa200")
	var asset: float = Sail.asset_full(d)
	report.append("SA-200: sail furled whole worth $%.0f (of $168,000 with FM-9 already torn); contract total $%.0f" % [asset, float(d.value.total)])
	check(asset > 150000.0 and asset < 168000.0, "the sail's worth counts its torn panel out ($%.0f)" % asset)
	check(asset > float(d.value.total) * 0.4, "the sail is the ship's prize (%.0f%% of the ship)" % (asset / float(d.value.total) * 100.0))
	var eng := 0.0
	for pd in d.pieces:
		if str(pd.get("cls", "")) == "equip":
			eng = maxf(eng, float(pd.get("value", 0.0)))
	check(asset / 4.0 > eng, "each corner's roll is worth more than any unit on board ($%.0f > $%.0f)" % [asset / 4.0, eng])
	var vd: Dictionary = d.duplicate(true)
	Variant.revalue(vd)
	check(absf(float(vd.value.total) - float(d.value.total)) < float(d.value.total) * 0.05, "a market contract's total counts it too ($%.0f)" % float(vd.value.total))

	# the careful way
	g = await _game()
	var sl = g.sail
	check(g.rate_base() >= asset, "the recovery's denominator counts the sail")
	_prep(true, true)
	await _frames(3)
	_motors(true)
	var p1 = g.world.tag(sl._quad_panels("NW")[0])
	var a0: float = Geom.area(p1.poly)
	await _frames(120)
	report.append("panel %s after 2 s winding: %.0f%% of its area left (gone %s)" % [p1.tag, Geom.area(p1.poly) / a0 * 100.0, p1.gone])
	# (its outline is cut back in twelfths of the panel, so up to one step behind the drum)
	check(p1.gone or Geom.area(p1.poly) < a0 * 0.8, "the panel on the drum really shortens as it winds on")
	g.world.reveal("G", g.world.rooms.G.from)
	g.cam_override = sl._winch_at("NW") + Vector2(-10.0 * Geom.M, 0)
	g.zoom_override = 0.18
	await _frames(70)
	Cap.save(root, "res://tests/out/sail_furling_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	var t: float = await _wait_furled(60.0)
	report.append("careful furl: all four corners in %.1f s" % t)
	var grades := {}
	for q in ["NW", "NE", "SE", "SW"]:
		var roll = g.world.tag("ROLL-" + q)
		check(roll != null and not roll.gone and roll.cls == "equip" and roll.intact, "corner %s: its roll on the winch" % q)
		if roll != null:
			grades[q] = roll.cond
			check(g.world.joints_of(roll).any(func(j): return j.alive and j.type == "bolt"), "  bolted to the winch until unbolted")
	report.append("grades: %s" % str(grades))
	check(float(grades.get("NW", 0.0)) >= 0.9, "a whole corner wound slack and earthed grades A (%.2f)" % float(grades.get("NW", 0.0)))
	check(float(grades.get("NE", 1.0)) < float(grades.get("NW", 0.0)), "the corner with the torn panel grades lower (%.2f)" % float(grades.get("NE", 1.0)))
	var left := 0
	for tg in sl.cfg.panels:
		var p = g.world.tag(str(tg))
		if p != null and not p.gone:
			left += 1
	check(left == 0, "no film left on the frame")
	var roll_nw = g.world.tag("ROLL-NW")
	check(Repair.class_of(roll_nw, g.sys) == "sail", "a roll is shelved as a sail roll")
	var worth: float = g.piece_value(roll_nw, "equip")
	check(is_equal_approx(worth, roll_nw.value * roll_nw.cond), "the equipment mouth pays it its value x grade ($%.0f)" % worth)
	var total_rolls := 0.0
	for q in grades:
		total_rolls += g.world.tag("ROLL-" + q).value * float(grades[q])
	check(total_rolls <= asset + 1.0, "the rolls together never pay more than the sail is worth ($%.0f of $%.0f)" % [total_rolls, asset])
	report.append("careful: the four rolls fetch $%.0f" % total_rolls)
	g.cam_override = g.world.frame(roll_nw) * Geom.centroid(roll_nw.poly)
	g.zoom_override = 0.9
	await _frames(70)
	Cap.save(root, "res://tests/out/sail_roll_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	# unbolted, it comes loose
	for j in g.world.joints_of(roll_nw):
		g.world.kill_joint(j)
	g.world.dirty_links = true
	await _frames(6)
	check(roll_nw.body != null, "unbolted, the roll comes loose to carry off")
	g.queue_free()
	await _frames(4)

	# taut: the film overloads, the motor trips
	g = await _game()
	sl = g.sail
	_prep(true, false)
	await _frames(3)
	_switch("F-NW", true)
	await _frames(10)
	check(not sl.motor_on("NW") and sl.furl.get("NW", {}).get("dmg", 0.0) > 0.0 and g.incidents.any(func(i): return i[1] == "furl_overload"), "furled taut: the film overloads, the motor trips")
	g.queue_free()
	await _frames(4)

	# unearthed: pinholes all the way
	g = await _game()
	sl = g.sail
	_prep(false, true)
	await _frames(3)
	_switch("F-SW", true)
	var tt := 0.0
	while tt < 40.0 and not sl.furled("SW"):
		await process_frame
		tt += 1.0 / 60.0
	var g_static: float = g.world.tag("ROLL-SW").cond if g.world.tag("ROLL-SW") != null else 1.0
	report.append("unearthed SW roll grade %.2f" % g_static)
	check(sl.furled("SW") and g_static < 0.9, "wound unearthed the film is pinholed: grade %.2f" % g_static)
	g.queue_free()
	await _frames(4)

	# the quick way: the film cut to waste
	g = await _game()
	sl = g.sail
	_prep(true, true)
	await _frames(3)
	var scrap := 0.0
	for tg in sl.cfg.panels:
		var p = g.world.tag(str(tg))
		if p != null and not p.gone:
			sl._spread(str(tg))
			scrap += g.world.scrap_value(p)
	await _frames(3)
	report.append("quick way: the whole film as scrap $%.0f against $%.0f furled" % [scrap, asset])
	check(scrap < asset * 0.02, "cut to waste, the film is scrap: $%.0f (the rolls would be $%.0f)" % [scrap, asset])
	check(sl.torn.size() == sl.cfg.panels.size(), "every panel torn")
	g.queue_free()
	await _frames(4)

	# a save half-way through furling
	g = await _game()
	sl = g.sail
	_prep(true, true)
	_switch("F-SE", true)
	await _frames(int(60.0 * 3.5 / sl.FURL_RATE))
	var k_before: int = int(sl.furl.SE.k)
	SaveGame.save(g)
	g.queue_free()
	await _frames(3)
	SaveGame.load_requested = true
	g = await _game()
	sl = g.sail
	check(int(sl.furl.get("SE", {}).get("k", -1)) == k_before and sl.motor_on("SE"), "loaded half-way: %d panels on the drum, the motor still on" % k_before)
	tt = 0.0
	while tt < 40.0 and not sl.furled("SE"):
		await process_frame
		tt += 1.0 / 60.0
	check(sl.furled("SE") and g.world.tag("ROLL-SE") != null and g.world.tag("ROLL-SE").cond >= 0.9, "and it finishes into one roll, grade %.2f" % (g.world.tag("ROLL-SE").cond if g.world.tag("ROLL-SE") != null else 0.0))
	var n_rolls := 0
	for id in g.world.order:
		if str(g.world.pieces[id].tag) == "ROLL-SE" and not g.world.pieces[id].gone:
			n_rolls += 1
	check(n_rolls == 1, "one roll, not two")
	g.queue_free()
	await _frames(4)
	SaveGame.clear()

	# the shelf: a roll kept, then sold once
	Career.data = Career.fresh()
	Career.data.money = 1000.0
	Career.data.parts = [{"uid": "J:ROLL-NW:1", "cls": "sail", "tag": "ROLL-NW", "nk": "p_sail_roll", "cond": 0.95, "value": 42000.0, "ship": "sa200", "job": "J"}]
	Career.save()
	check(Repair.shelf_by_class().sail.size() == 1, "kept: it sits on the parts rack as a sail roll")
	check(Repair.sell("J:ROLL-NW:1") == "" and is_equal_approx(float(Career.data.money), 1000.0 + 39900.0), "sold: $39,900 (value x grade), once")
	check(Repair.sell("J:ROLL-NW:1") != "" and is_equal_approx(float(Career.data.money), 40900.0), "a second sale of the same roll is refused")

	# 87-7: listed for the sail-makers: grade B or better, 8 % over a direct sale, sold once after a while
	Career.data.parts = [{"uid": "J:ROLL-SE:2", "cls": "sail", "tag": "ROLL-SE", "nk": "p_sail_roll", "cond": 0.95, "value": 42000.0, "ship": "sa200", "job": "J"},
		{"uid": "J:ROLL-SW:3", "cls": "sail", "tag": "ROLL-SW", "nk": "p_sail_roll", "cond": 0.44, "value": 42000.0, "ship": "sa200", "job": "J"}]
	Career.data.money = 0.0
	Career.save()
	check(Repair.list_part("J:ROLL-SW:3", true) != "", "a grade D roll cannot be listed, only sold")
	check(Repair.list_part("J:ROLL-SE:2", true) == "", "a grade A roll is listed")
	check(Repair.sell("J:ROLL-SE:2") != "", "a listed roll is not sold off the rack meanwhile")
	var ask: float = Repair.list_price({"cond": 0.95, "value": 42000.0})
	Repair.advance_listings(60.0)
	check(is_equal_approx(float(Career.data.money), 0.0), "not sold yet after a minute")
	var sold: Array = Repair.advance_listings(61.0)
	check(sold == ["ROLL-SE"] and is_equal_approx(float(Career.data.money), ask * (1.0 - Repair.LIST_FEE)), "sold after 2 minutes: $%.0f (direct: $39,900)" % float(Career.data.money))
	check(Repair.advance_listings(200.0).is_empty() and Career.data.parts.size() == 1, "and only once")
	print("--- 87-4 report")
	for r in report:
		print(r)
	print("SAIL ROLL %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
