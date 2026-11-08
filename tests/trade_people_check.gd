extends "res://tests/guide_check.gd"
# 75 号: the trade port's people. Callers come every couple of minutes once the trade district
# works, two at most; their temper sets how they take a counter-offer (easy-going most, shrewd
# least, and the shrewd may meet you halfway); one in a hurry leaves after a minute; turned down
# or sent away they leave; a deal moves the money and the goods. The three companies' standing
# contracts deliver from the warehouse on time or miss, the reputation follows, the next
# contract's price follows the reputation, and too low a reputation gets none. Own saves only.
#   tools/run_test.sh tests/trade_people_check.gd --fixed-fps 60



func _initialize() -> void:
	Career.path = "user://zp_test_trade_people_career.json"
	SaveGame.path = "user://zp_test_trade_people_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _stock() -> Dictionary:
	return Career.data.exchange.actors.company.stock


func _caller(temper: String, want: String, salt: int) -> Dictionary:
	var v := {"id": "T-%d" % salt, "kind": "merchant", "temper": temper, "want": want, "key": "steel_billet:1", "qty": 1.0, "price": 1000.0, "state": "waiting", "t": 9.0, "left": 60.0, "salt": salt}
	TradePeople.vis().list.append(v)
	return v


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "process": 1, "cargo": 1}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = Exchange.fresh(500000.0)
	_stock()["steel_billet:1"] = 1000.0
	Career.save()
	# ---- callers
	TradePeople.advance(300.0)
	check(TradePeople.here().is_empty(), "nobody comes before the trade district works")
	Career.data.port["trade"] = 1
	TradePeople.vis().t = 0.0
	TradePeople.advance(TradePeople.EVERY - 1.0)
	check(TradePeople.here().is_empty(), "not before two minutes")
	TradePeople.advance(2.0)
	var first: Array = TradePeople.here()
	check(first.size() == 1 and str(first[0].state) == "arriving", "one comes in: %s" % (TradePeople.card_name(first[0]) if not first.is_empty() else "-"))
	TradePeople.advance(TradePeople.ARRIVE_S)
	check(not first.is_empty() and str(first[0].state) != "arriving", "alongside at the pier")
	for i in 3:
		TradePeople.advance(TradePeople.EVERY)
	check(TradePeople.here().size() <= TradePeople.MAX_HERE, "two at most at the pier (%d)" % TradePeople.here().size())
	for v in TradePeople.here():
		v.state = "gone"
	# ---- tempers
	var took := {"frank": 0, "shrewd": 0}
	var halfway := 0
	for i in 120:
		for tmp in ["frank", "shrewd"]:
			var v := _caller(tmp, "buy", 1000 + i * 3 + (0 if tmp == "frank" else 1))
			var r := TradePeople.haggle(str(v.id), "medium")
			if str(r.get("said", "")) == "yes":
				took[tmp] += 1
			elif str(r.get("said", "")) == "halfway":
				halfway += 1
				v.state = "gone"
	check(int(took.frank) > int(took.shrewd) + 20, "an easy-going caller takes a 12 pct ask more often than a shrewd one (%d vs %d of 120)" % [int(took.frank), int(took.shrewd)])
	check(halfway > 10, "the shrewd often meet you halfway (%d)" % halfway)
	# a deal: he buys
	var m0 := float(Career.data.money)
	var s0 := float(_stock()["steel_billet:1"])
	var b := _caller("frank", "buy", 7)
	check(TradePeople.accept(str(b.id)).ok and is_equal_approx(float(Career.data.money) - m0, 1000.0) and is_equal_approx(s0 - float(_stock()["steel_billet:1"]), 1.0), "he buys a tonne at 1,000: the money in, the billet out")
	# he sells
	var sl := _caller("frank", "sell", 8)
	m0 = float(Career.data.money)
	s0 = float(_stock()["steel_billet:1"])
	check(TradePeople.accept(str(sl.id)).ok and is_equal_approx(m0 - float(Career.data.money), 1000.0) and is_equal_approx(float(_stock()["steel_billet:1"]) - s0, 1.0), "he sells a tonne: the money out, the billet in")
	# halfway, then taken
	var hw := {}
	for i in 60:
		var v := _caller("shrewd", "buy", 5000 + i)
		var r := TradePeople.haggle(str(v.id), "hard")
		if str(r.get("said", "")) == "halfway":
			hw = v
			break
		v.state = "gone"
	check(not hw.is_empty() and str(hw.state) == "countered" and float(hw.price) > 1000.0 and float(hw.price) < 1250.0, "a shrewd one meets a 25 pct ask halfway (%.0f)" % float(hw.get("price", 0.0)))
	if not hw.is_empty():
		check(not TradePeople.haggle(str(hw.id), "small").ok and TradePeople.accept(str(hw.id)).ok, "then it is take or leave: taken at the middle")
	# in a hurry
	var hu := _caller("hurry", "buy", 9)
	TradePeople.advance(61.0)
	check(str(hu.state) == "gone", "one in a hurry leaves after a minute")
	var rf := _caller("frank", "buy", 10)
	check(TradePeople.refuse(str(rf.id)).ok and str(rf.state) == "gone", "sent away, he leaves")
	# ---- the companies
	var orgs := TradePeople.orgs()
	TradePeople.advance(0.1)
	var who: String = orgs.keys()[0]
	var of: Dictionary = orgs[who].offer
	check(orgs.size() == 3 and not of.is_empty() and int(of.get("times", 0)) == 3, "each company offers a standing contract (%s: %.1f t %s at %.0f)" % [TradePeople.org_name(who), float(of.get("qty", 0.0)), Ops.item_name(str(of.get("key", ""))), float(of.get("price", 0.0))])
	check(TradePeople.take_contract(who).ok and TradePeople.drop_contract(who).ok and orgs[who].contract.is_empty(), "taken and handed back before the first delivery, at no cost")
	orgs[who].offer = of.duplicate()
	TradePeople.take_contract(who)
	var key := str(orgs[who].contract.key)
	_stock()[key] = 10.0
	m0 = float(Career.data.money)
	TradePeople.advance(TradePeople.PERIOD + 0.1)
	check(int(orgs[who].rep) == 1 and float(Career.data.money) > m0 and not TradePeople.drop_contract(who).ok, "delivered on time: paid, reputation +1, no handing back now")
	_stock()[key] = 0.0
	TradePeople.advance(TradePeople.PERIOD + 0.1)
	check(int(orgs[who].rep) == 0, "missed (none in stock): reputation -1")
	_stock()[key] = 10.0
	TradePeople.advance(TradePeople.PERIOD + 0.1)
	check(orgs[who].contract.is_empty() and int(orgs[who].rep) == 1, "three deliveries and the contract is done")
	orgs[who].rep = 5
	orgs[who].offer = {}
	TradePeople.advance(0.1)
	check(not orgs[who].offer.is_empty() and float(orgs[who].offer.price) > Exchange.ref_price(str(orgs[who].offer.key)) * 1.1, "with reputation 5 the next contract pays more (%.0f)" % float(orgs[who].offer.get("price", 0.0)))
	orgs[who].rep = -4
	orgs[who].offer = {}
	TradePeople.advance(0.1)
	check(orgs[who].offer.is_empty(), "under -3 the company gives none")
	orgs[who].rep = 0
	orgs[who].offer = {}
	# ---- saved
	Career.save()
	var keep := JSON.stringify(JSON.parse_string(JSON.stringify([Career.data.visitors, Career.data.orgs])))
	Career.data = {}
	Career.load_or_new()
	check(JSON.stringify(JSON.parse_string(JSON.stringify([Career.data.get("visitors", {}), Career.data.get("orgs", {})]))) == keep, "callers and contracts are in the save")
	# ---- the pier and the console
	for v in TradePeople.vis().list:
		v.state = "gone"
	TradePeople.vis().t = 0.0
	TradePeople.advance(TradePeople.EVERY + 0.1)
	TradePeople.advance(TradePeople.ARRIVE_S)
	await _spawn()
	await _frames(20)
	g.drone.global_position = PortStructure.console_spot("trade")
	g.drone.linear_velocity = Vector2.ZERO
	g.cam_override = PortStructure.box("trade").get_center() + Vector2(25, 0) * Geom.M
	g.zoom_override = 0.4
	await _frames(40)
	Cap.save(root, "res://tests/out/trade_pier_zh.png")
	g.cam_override = null
	g.zoom_override = -1.0
	g.open_district("trade")
	await _frames(20)
	# 132 号: one visitor card at a time, the companies folded into one line (a row each inside)
	check(g.console_ui != null and g.console_ui.get("trade_box") != null and g.console_ui.trade_box.get_child_count() >= 1 and g.console_ui.org_list.get_child_count() >= 3, "the trade console shows the caller and the three companies")
	Cap.save(root, "res://tests/out/trade_people_console_zh.png")
	if g.console_ui != null:
		g.console_ui.close()
	g.queue_free()
	await _frames(4)
	print("TRADE PEOPLE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
