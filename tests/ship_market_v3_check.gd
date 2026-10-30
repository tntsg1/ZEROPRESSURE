extends "res://tests/guide_check.gd"
# 57 号: title defects, the agencies' public record, the stretched far runs. A yard's lien or the
# waste liability is fixed when a listing is drawn and the title search finds it; such a hulk is
# held at the port until it is paid (no contract card before, one after; not paid without the
# cash); an unsaid defect paid is claimable once for what was paid, a said one is not. Listings
# that run out are half published to their agency's public record. Far runs fly a slower, true
# Lambert arc (the near ones unchanged). Own test saves only.
#   tools/run_test.sh tests/ship_market_v3_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_ship_market3_career.json"
	SaveGame.path = "user://zp_test_ship_market3_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# a fitting listing whose title is of this kind and said this way (drawn until one turns up)
func _find(kind: String, how: String) -> Dictionary:
	var d := ShipMarket.data()
	for l in d.listings:
		var t := ShipMarket.title_of(l)
		if ShipMarket.fits(l) and str(t.kind) == kind and (kind == "" or str(t.how) == how):
			return l
	for i in 400:
		var l := ShipMarket._make(9000 + i)
		if l.is_empty() or not ShipMarket.fits(l):
			continue
		var t := ShipMarket.title_of(l)
		if str(t.kind) == kind and (kind == "" or str(t.how) == how):
			d.listings.append(l)
			Career.save()
			return l
	return {}


# fly a bought hulk home: the clock past its arrival, the market ticked
func _arrive(id: String) -> void:
	var a := ShipMarket.asset(id)
	Shipping.data().day = float(a.run.depart) + float(a.run.tof) + 0.01
	ShipMarket.tick()
	Career.save()
	await _frames(2)


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
	# ---- fixed at the draw; the title search finds it
	var all_titled := true
	for l in ShipMarket.data().listings:
		all_titled = all_titled and l.has("title")
	check(all_titled, "every listing carries its title when drawn")
	var lien := _find("lien", "omitted")
	check(not lien.is_empty(), "a hulk under an unsaid yard lien turns up")
	var lid := str(lien.id)
	var cash := float(Career.data.money)
	var ins := ShipMarket.inspect(lid, "title")
	check(ins.ok and ins.found == ["lien"] and absf(cash - float(Career.data.money) - ShipMarket.TITLE_COST) < 0.01, "the title search ($800) finds the lien")
	check(ShipMarket.title_text(ShipMarket.listing(lid)).find("未提") >= 0, "the seller's title line says nothing of it")
	# ---- held at the port until paid
	check(ShipMarket.buy(lid).ok, "bought")
	await _arrive(lid)
	var a := ShipMarket.asset(lid)
	var carded: bool = Career.data.offers.any(func(o): return str(o.get("id", "")) == lid)
	check(str(a.state) == "held" and not carded, "it arrives held by the lien: no contract card")
	var due := float(ShipMarket.title_of(a.listing).amount)
	Career.data.money = due - 1.0
	Career.save()
	var poor := ShipMarket.pay_title(lid)
	check(not poor.ok and absf(float(Career.data.money) - (due - 1.0)) < 0.01 and str(ShipMarket.asset(lid).state) == "held", "short of cash: not paid, nothing taken")
	Career.data.money = 5000000.0
	Career.save()
	cash = float(Career.data.money)
	var paid := ShipMarket.pay_title(lid)
	carded = Career.data.offers.any(func(o): return str(o.get("id", "")) == lid)
	check(paid.ok and absf(cash - float(Career.data.money) - due) < 0.01 and str(ShipMarket.asset(lid).state) == "arrived" and carded, "paid %s: released, its contract card on the page" % Pal.money(due))
	# ---- the claim: the amount paid, once
	var can := ShipMarket.title_claimable(ShipMarket.asset(lid))
	cash = float(Career.data.money)
	var c1 := ShipMarket.claim_title(lid)
	var c2 := ShipMarket.claim_title(lid)
	check(absf(can - minf(ShipMarket.CLAIM_CAP, due)) < 0.01 and c1.ok and not c2.ok and absf(float(Career.data.money) - cash - can) < 0.01, "the unsaid lien is claimed back once (%s)" % Pal.money(can))
	# a said defect: the ask was cut, nothing to claim
	var said := _find("waste", "admitted")
	if said.is_empty():
		said = _find("lien", "admitted")
	check(not said.is_empty() and ShipMarket.title_text(said).find("让过") >= 0, "a seller who says so states it in the title line")
	var sid := str(said.id)
	ShipMarket.buy(sid)
	await _arrive(sid)
	ShipMarket.pay_title(sid)
	check(ShipMarket.title_claimable(ShipMarket.asset(sid)) <= 0.0, "said and paid: nothing to claim")
	# ---- the public record
	var d := ShipMarket.data()
	d.agency_log = []
	var n0 := 0
	var expired: Array = []
	for l in d.listings:
		if not l.has("hold"):
			l.expires = Shipping.day() - 1.0
			expired.append(l)
			if hash(str(l.id)) % 2 == 0:
				n0 += 1
	ShipMarket.refresh()
	check(d.agency_log.size() == n0 and n0 > 0, "listings that ran out: half go on the agencies' public record (%d of %d)" % [n0, expired.size()])
	var ag := str(d.agency_log[0].ag)
	var pr := ShipMarket.public_record(ag)
	var want := 0
	for e in d.agency_log:
		if str(e.ag) == ag:
			want += 1
	check(int(pr.n) == want and ShipMarket.public_text(ag).find("公开记录") >= 0, "its public record counts its results (%s)" % ShipMarket.public_text(ag))
	# ---- the far runs, stretched and still true
	var near_ok := true
	var far_ok := true
	var lands := true
	for i in Orbits.STATIONS.size():
		var tr := Orbits.transfer(Orbits.station(i), Orbits.PORT, 300.0)
		if tr.is_empty():
			continue
		if tr.has("tof_fast"):
			far_ok = far_ok and float(tr.tof) > float(tr.tof_fast) and float(tr.tof) <= Orbits.STRETCH_MAX + 0.01
		else:
			near_ok = near_ok and float(tr.tof) <= Orbits.STRETCH_FROM + 0.01
		lands = lands and Orbits.on_transfer(tr, 1.0).distance_to(Orbits.pos(Orbits.PORT, 300.0 + float(tr.tof))) < 1e-4
	check(near_ok and far_ok and lands, "near runs as they were, far runs flown slower (≤ %d days) on arcs that still meet the port" % int(Orbits.STRETCH_MAX))
	# shots: a listing's detail with its title line and three inspections, a held card
	g.open_ship_market()
	await _frames(40)
	var panel = g.console_ui
	if panel != null and panel.has_method("_detail"):
		panel.chosen = str(_find("waste", "omitted").get("id", ""))
		panel._detail()
		if panel.more_box != null:
			panel.more_box.visible = true
		await _frames(30)
		Cap.save(root, "res://tests/out/ship_market_title_zh.png")
	g.queue_free()
	await _frames(4)
	print("SHIP MARKET V3 %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
