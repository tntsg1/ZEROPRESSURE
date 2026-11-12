extends "res://tests/guide_check.gd"
# 138 号 (user 2026-11-11: "为什么说我买了4艘船，但是我实际上只能拆1艘船呢？"): four hulks bought — one
# still on its way, one home, two held at the port for a lien / a waste bill. The tug yard's count
# and what the find-ships page shows must agree: every hulk that holds a berth is either on its way
# (said in the head line) or a card on the page; a held one's card says why and for how much, and
# taking it is refused with that reason; paid, it can be started. Shots before / after.
# Own test saves only.
#   tools/run_test.sh tests/yard_count_check.gd --fixed-fps 60 [-- before]


func _initialize() -> void:
	Career.path = "user://zp_test_yard_count_career.json"
	SaveGame.path = "user://zp_test_yard_count_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _buy(ship: String, n: int, title: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + n
	var o := Market.offer(rng, Career.data, 1, {}, "full", ship)
	o.erase("_ship")
	var id := "SM-Y%d" % n
	o.id = id
	o.bought = true
	o.drift_years = 0
	o.fee = 0.0
	var now := Shipping.day()
	ShipMarket.data().listings.append({"id": id, "offer": o, "station": 0, "price": 1000.0,
		"statements": [{"cat": "structure", "how": "clean", "traps": []}, {"cat": "systems", "how": "clean", "traps": []}],
		"title": title, "rating": {"score": 9, "agency": "bsi", "day": now, "paid": false}, "inspected": {}, "listed": now, "expires": now + 9999.0, "floor": 900.0})
	var r := ShipMarket.buy(id)
	return id if r.ok else ""


func _run() -> void:
	var before := OS.get_cmdline_user_args().has("before")
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 50000000.0
	Career.data.port = {"salvage": 2, "trade": 1, "tug": 2, "power": 1, "cargo": 1, "process": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "port_walk": true, "starmap_tour": true}
	Career.data.offers = []
	var ups: Dictionary = Career.data.get("upgrades", {})
	for k in ["berth88", "berth120", "berth200"]:
		ups[k] = true
	Career.data.upgrades = ups
	Career.save()
	await _spawn()
	await _frames(30)
	var ids := [
		_buy("md160", 1, {"kind": ""}),
		_buy("gr7", 2, {"kind": "lien", "amount": 4300.0, "how": "omitted"}),
		_buy("s09", 3, {"kind": "waste", "amount": 2600.0, "how": "omitted"}),
		_buy("pod", 4, {"kind": ""})]
	check(not ids.has(""), "four hulks bought (%s)" % str(ids))
	# three come home now (one plain, two held), the fourth is still on its way
	for i in 3:
		var a := ShipMarket.asset(str(ids[i]))
		a.run.depart = Shipping.day() - ShipMarket.tow_span(a) - 1.0
	ShipMarket.asset(str(ids[3])).run.depart = Shipping.day() + 1.0e6
	ShipMarket.tick()
	for a in ShipMarket.data().assets:
		a.seen_in = true          # brought in already (not what this checks)
	var states: Array = ids.map(func(id): return str(ShipMarket.asset(str(id)).state))
	print("states: %s · yard %d/%d" % [str(states), TugYard.taken().size(), TugYard.slots()])
	g.open_console("terminal")
	await _frames(30)
	var term = g.console_ui
	term._skip_boot()
	term.set_tab(0)
	await _frames(40)
	var cards: Array = term.offers().filter(func(o): return o.get("bought", false))
	var way := ShipMarket.on_the_way().size()
	print("cards on the page: %s · on the way %d" % [str(cards.map(func(o): return str(o.id))), way])
	Cap.save(root, "res://tests/out/yard_count_%s_zh.png" % ("before" if before else "after"))
	if before:
		quit(0)
		return
	check(TugYard.taken().size() == cards.size() + way, "the yard's count is what the page shows: %d = %d cards + %d on the way" % [TugYard.taken().size(), cards.size(), way])
	var held_cards: Array = cards.filter(func(o): return o.get("port_held", false))
	check(held_cards.size() == 2 and held_cards.all(func(o): return str(o.get("held_why", "")).contains("$")), "the two held ones are cards that say why and how much")
	check(TugYard.status().contains("扣留 2") and TugYard.status().contains("在途 1"), "the yard line splits the count (%s)" % TugYard.status())
	# taking a held one: refused with its reason; the market's 我的船 opens to pay it
	var hi := -1
	for i in term.offers().size():
		if str(term.offers()[i].get("id", "")) == str(ids[1]):
			hi = i
	term.take(hi)
	await _frames(20)
	check(Career.active().is_empty(), "a held card is not taken")
	var page: String = "" if g.console_ui == null else str(g.console_ui.get_script().resource_path).get_file()
	check(page == "ship_market_panel.gd" and g.console_ui.cat == "mine", "…and 二手船市 · 我的船 opens to pay it (%s)" % page)
	# paid: the card is an ordinary one and can be taken
	var paid := ShipMarket.pay_title(str(ids[1]))
	ShipMarket.cards()
	var c2: Array = Career.data.offers.filter(func(o): return str(o.get("id", "")) == str(ids[1]))
	check(paid.ok and c2.size() == 1 and not c2[0].get("port_held", false), "paid, its card is free to start")
	g.queue_free()
	await _frames(4)
	print("YARD COUNT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(1 if fails > 0 else 0)
