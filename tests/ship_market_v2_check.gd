extends "res://tests/guide_check.gd"
# 41 号: the hulk market's second version. One counter-offer per listing (at the seller's floor it
# is bought at that price; under it, refused for good); a deposit holds the quote and counts toward
# the price, lost when the hold runs out; an own hulk listed at or under its buyer's fixed mind is
# bought and paid at once (3% fee), over it it waits, and relisting does not move the mind; an
# inspection raises what buyers will pay; a rating proved false can be reported once, and the
# agency's record shows it (a paid rating as a proven conflict of interest). Own test saves only.
#   tools/run_test.sh tests/ship_market_v2_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_ship_market2_career.json"
	SaveGame.path = "user://zp_test_ship_market2_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _fit(skip: Array) -> Dictionary:
	for l in ShipMarket.data().listings:
		if ShipMarket.fits(l) and not str(l.id) in skip:
			return l
	return {}


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 5000000.0
	# 72 号: room in the tug yard for the several hulks this test buys
	Career.data.port = {"salvage": 1, "trade": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.offers = []
	Career.save()
	await _spawn()
	await _frames(90)
	var d := ShipMarket.data()
	var floors := true
	for l in d.listings:
		var k := float(l.floor) / float(l.price)
		floors = floors and k >= 0.8 and k <= 0.98 and l.rating.has("paid")
	check(floors, "every listing has its seller's floor and whether its rating was paid for")
	# ---- the counter-offer
	var a := _fit([])
	var aid := str(a.id)
	check(not ShipMarket.haggle(aid, float(a.price) * 0.7).ok, "no lower than 80% of the ask")
	var low := maxf(ceilf(float(a.price) * 0.8 / 100.0) * 100.0, float(a.floor) - 500.0)
	if low < float(a.floor):
		var r := ShipMarket.haggle(aid, low)
		check(r.ok and not r.accepted and ShipMarket.listing(aid).get("haggled", false), "under the floor: refused")
		check(not ShipMarket.haggle(aid, float(a.price) * 0.99).ok, "and no second try")
	else:
		check(true, "(its floor is at 80%%: nothing to refuse)")
		check(true, "(no second try to test)")
	var b := _fit([aid])
	var bid := str(b.id)
	var cash := float(Career.data.money)
	var fee := float(ShipMarket.tow_quote(b).fee)
	var offer := float(b.floor)
	var r2 := ShipMarket.haggle(bid, offer)
	var asset_b := ShipMarket.asset(bid)
	check(r2.ok and r2.accepted and absf(float(asset_b.price) - offer) < 1.0 and absf(cash - float(Career.data.money) - offer - float(asset_b.tow)) < 1.0 and float(asset_b.tow) <= fee, "at the floor: bought at that price (%s, ask %s)" % [Pal.money(offer), Pal.money(float(b.price))])
	# ---- the held quote
	var c := _fit([aid, bid])
	var cid := str(c.id)
	cash = float(Career.data.money)
	var h := ShipMarket.hold(cid)
	var dep := float(h.get("deposit", 0.0))
	check(h.ok and absf(cash - float(Career.data.money) - float(c.price) * 0.02) < 10.0, "a 2%% deposit holds it (%s)" % Pal.money(dep))
	var held_fee := float(ShipMarket.tow_quote(ShipMarket.listing(cid)).fee)
	cash = float(Career.data.money)
	check(ShipMarket.buy(cid).ok and absf(cash - float(Career.data.money) - (float(c.price) + held_fee - dep)) < 1.0, "bought, the deposit counts toward the price")
	var e := _fit([aid, bid, cid])
	var eid := str(e.id)
	cash = float(Career.data.money)
	ShipMarket.hold(eid)
	ShipMarket.listing(eid).hold.until = Shipping.day()
	ShipMarket.listing(eid).expires = Shipping.day() + 9999.0
	await _frames(80)
	check(not ShipMarket.listing(eid).has("hold") and float(Career.data.money) < cash - 1.0, "the hold runs out: the deposit is the seller's")
	# ---- an inspection raises what buyers will pay (a side found clean)
	var raised := false
	for l in ShipMarket.data().listings:
		for cat in ["structure", "systems"]:
			if l.inspected.has(cat) or not l.offer.traps.filter(func(t): return ShipMarket.category(t) == cat).is_empty():
				continue
			var before := ShipMarket.reservation(l)
			ShipMarket.inspect(str(l.id), cat)
			raised = ShipMarket.reservation(ShipMarket.listing(str(l.id))) > before
			break
		if raised:
			break
	check(raised, "a clean inspection raises the buyers' mind")
	# ---- resale
	asset_b = ShipMarket.asset(bid)
	var m := ShipMarket.mind(asset_b)
	var band := ShipMarket.interest(asset_b)
	check(float(band[0]) <= m and m <= float(band[1]) + 1000.0, "the hint brackets the buyers' mind")
	var asset_c := ShipMarket.asset(cid)
	var mc := ShipMarket.mind(asset_c)
	check(ShipMarket.resell(cid, mc + 20000.0).ok, "listed over the mind")
	ShipMarket.asset(cid).resale.due = Shipping.day()
	await _frames(80)
	check(str(ShipMarket.asset(cid).state) != "sold", "over the mind: nobody buys")
	ShipMarket.unlist(cid)
	ShipMarket.resell(cid, mc + 20000.0)
	check(is_equal_approx(ShipMarket.mind(ShipMarket.asset(cid)), mc), "relisting does not move the mind")
	ShipMarket.unlist(cid)
	cash = float(Career.data.money)
	var price := snappedf(m - 100.0, 100.0)
	check(ShipMarket.resell(bid, price).ok, "listed under the mind")
	ShipMarket.asset(bid).resale.due = Shipping.day()
	await _frames(80)
	asset_b = ShipMarket.asset(bid)
	check(str(asset_b.state) == "sold" and absf(float(Career.data.money) - cash - price * 0.97) < 1.0, "a buyer takes it, paid at once less 3%% (+%s)" % Pal.money(float(Career.data.money) - cash))
	check(not Career.data.get("offers", []).any(func(o): return str(o.get("id", "")) == bid), "and its card is gone")
	# ---- the agency's record
	var ac := ShipMarket.asset(cid)
	var ag := str(ac.listing.rating.agency)
	var covered: String = ShipMarket.AGENCIES[ag].covers[0]
	var trap: String = ShipMarket.STRUCTURE[0] if covered == "structure" else "live_capacitor"
	ac.listing.offer.traps = [trap]
	ac.listing.rating.score = 8
	ac.listing.rating.paid = true
	ac.state = "stripped"
	var rec0 := ShipMarket.record(ag)
	var rp := ShipMarket.report(cid)
	var rec1 := ShipMarket.record(ag)
	check(rp.ok and rp.paid and int(rec1.misrated) == int(rec0.misrated) + 1 and int(rec1.paid) == int(rec0.paid) + 1, "a false rating reported: on the record, the paid rating proved")
	check(ShipMarket.record_text(ag).find("利益关联已证实") >= 0, "the record says so: %s" % ShipMarket.record_text(ag))
	check(not ShipMarket.report(cid).ok, "reported once only")
	g.queue_free()
	await _frames(4)
	print("SHIP MARKET V2 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
