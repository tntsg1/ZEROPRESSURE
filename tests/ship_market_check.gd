extends "res://tests/guide_check.gd"
# 33 号: the hulk market. Eight listings fixed until bought or expired; each a real ship whose
# traps are its true condition; the seller's statements, the rating and the two inspections;
# buying pays price and tow at once; the tow arrives on its Lambert arc and the hulk waits as
# an own-ship card; it is built with the very traps listed; a plainly false statement pays
# a claim once. Own test saves only.
#   tools/run_test.sh tests/ship_market_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_ship_market_career.json"
	SaveGame.path = "user://zp_test_ship_market_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 2000000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(90)
	var d := ShipMarket.data()
	check(d.listings.size() == ShipMarket.LISTINGS, "eight listings (%d)" % d.listings.size())
	var ids: Array = d.listings.map(func(l): return str(l.id))
	await _frames(70)
	check(ShipMarket.data().listings.map(func(l): return str(l.id)) == ids, "they stay put while nobody buys")
	# the statements against the truth
	var sorts := {}
	var honest := true
	for l in d.listings:
		for s in l.statements:
			sorts[str(s.how)] = true
			var truth: Array = l.offer.traps.filter(func(t): return ShipMarket.category(t) == str(s.cat))
			if (str(s.how) == "clean") != truth.is_empty():
				honest = false
	check(honest, "a category the seller calls clean really is, and every other carries a trap")
	print("statement kinds seen: ", sorts.keys())
	# pick one with traps on both sides if there is one
	var pick: Dictionary = d.listings[0]
	for l in d.listings:
		if l.offer.traps.size() >= 2 and ShipMarket.fits(l):
			pick = l
	var id := str(pick.id)
	var cash := float(Career.data.money)
	var r := ShipMarket.inspect(id, "structure")
	var l2 := ShipMarket.listing(id)
	var truth_s: Array = l2.offer.traps.filter(func(t): return ShipMarket.category(t) == "structure")
	check(r.ok and l2.inspected.structure == truth_s and float(Career.data.money) < cash, "the structure inspection finds exactly its side's traps, and costs (%s)" % str(truth_s))
	r = ShipMarket.inspect(id, "systems")
	l2 = ShipMarket.listing(id)
	var truth_y: Array = l2.offer.traps.filter(func(t): return ShipMarket.category(t) == "systems")
	check(r.ok and l2.inspected.systems == truth_y, "the systems inspection the same for its side (%s)" % str(truth_y))
	g.open_ship_market()
	await _frames(6)
	g.console_ui.chosen = id
	g.console_ui._detail()
	await _frames(20)
	Cap.save(root, "res://tests/out/ship_market_zh.png")
	g.console_ui.close()
	await _frames(4)
	# buy: price and tow at once
	var q := ShipMarket.tow_quote(l2)
	cash = float(Career.data.money)
	r = ShipMarket.buy(id)
	check(r.ok and is_equal_approx(float(Career.data.money), cash - float(l2.price) - float(q.fee)), "bought: price %s and tow %s paid at once" % [Pal.money(float(l2.price)), Pal.money(float(q.fee))])
	check(ShipMarket.listing(id).is_empty() and str(ShipMarket.asset(id).state) == "towing", "the listing is closed and the tow under way")
	await _frames(80)
	check(ShipMarket.data().listings.size() == ShipMarket.LISTINGS, "a new listing takes its place")
	var a := ShipMarket.asset(id)
	Shipping.data().day = float(a.run.depart) + float(a.run.tof) + 0.1
	await _frames(80)
	# 63 号: the bringing-in plays on arrival; skipped here as a player may
	if g.tow_traffic != null and g.state == "towin":
		g.tow_traffic.finish()
		await _frames(4)
	a = ShipMarket.asset(id)
	# 57 号: a title defect holds it until paid
	if str(a.state) == "held":
		ShipMarket.pay_title(id)
		await _frames(10)
		a = ShipMarket.asset(id)
	check(str(a.state) == "arrived", "the tow arrives")
	# 63 号: this test is about the books, not the bringing-in on camera
	a.seen_in = true
	var card := {}
	for o in Career.data.offers:
		if str(o.get("id", "")) == id:
			card = o
	check(not card.is_empty() and card.get("bought", false) and float(card.fee) == 0.0 and card.get("owner", "") == "salvage", "it waits as an own-ship card: no fee, all its material the company's")
	# the hulk in the berth carries exactly the listed traps
	var built := Variant.make(Ship.load_data(str(card.ship)), card)
	check(card.traps == pick.offer.traps, "the card carries the listed condition (%s)" % str(card.traps))
	g.open_console("terminal")
	await _frames(6)
	g.console_ui._skip_boot()
	g.console_ui.set_tab(0)
	await _frames(30)
	Cap.save(root, "res://tests/out/ship_market_card_zh.png")
	g.console_ui.close()
	await _frames(4)
	# stripped: a plainly false statement pays once
	var lied := false
	for s in pick.statements:
		if str(s.how) == "false" and not s.traps.is_empty():
			lied = true
	var hist: Array = Career.data.get("history", [])
	hist.append({"id": id, "ship": str(card.ship), "net": 0.0})
	Career.data.history = hist
	await _frames(80)
	a = ShipMarket.asset(id)
	check(str(a.state) == "stripped", "stripped once its job is in the history")
	var amount := ShipMarket.claimable(a)
	check((amount > 0.0) == lied, "a claim only where the seller said a side was clean and it was not (%s)" % ("lied" if lied else "no false statement"))
	if lied:
		cash = float(Career.data.money)
		check(ShipMarket.claim(id).ok and float(Career.data.money) > cash and not ShipMarket.claim(id).ok, "paid once, not twice")
	# a seller who said a side was clean when it was not: bought, stripped, claimed once
	var liar := {}
	for k in 120:
		var l3 := ShipMarket._make(5000 + k)
		for s in l3.get("statements", []):
			if str(s.how) == "false" and not s.traps.is_empty() and ShipMarket.fits(l3):
				liar = l3
		if not liar.is_empty():
			break
	check(not liar.is_empty(), "sellers do sometimes lie outright")
	if not liar.is_empty():
		ShipMarket.data().listings.append(liar)
		var lid := str(liar.id)
		check(ShipMarket.buy(lid).ok, "the liar's hulk bought")
		var la := ShipMarket.asset(lid)
		Shipping.data().day = float(la.run.depart) + float(la.run.tof) + 0.1
		await _frames(80)
		if g.tow_traffic != null and g.state == "towin":
			g.tow_traffic.finish()
			await _frames(4)
		# 57 号: a title defect holds it until paid
		if str(ShipMarket.asset(lid).state) == "held":
			ShipMarket.pay_title(lid)
		ShipMarket.asset(lid).seen_in = true
		if g.tow_traffic != null and g.state == "towin":
			g.tow_traffic.finish()
		var h2: Array = Career.data.get("history", [])
		h2.append({"id": lid, "ship": str(liar.offer.ship), "net": 0.0})
		Career.data.history = h2
		await _frames(80)
		la = ShipMarket.asset(lid)
		var due := ShipMarket.claimable(la)
		check(due > 0.0 and due <= ShipMarket.CLAIM_CAP, "stripped, the false statement is claimable (%s)" % Pal.money(due))
		cash = float(Career.data.money)
		check(ShipMarket.claim(lid).ok and is_equal_approx(float(Career.data.money), cash + due), "the claim is paid")
		check(not ShipMarket.claim(lid).ok, "and only once")
	g.queue_free()
	await _frames(4)
	print("SHIP MARKET %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
