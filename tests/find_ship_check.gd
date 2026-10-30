extends "res://tests/guide_check.gd"
# 62 号: the find-ships page. The market is the belt's unowned hulks only (each with the station
# it drifts near and a quoted tow), no client contracts; sending a tug pays the tow, the card goes,
# the hulk is on its way home as an asset; short of cash nothing happens; arrived, it is a card
# to strip like a bought hulk, and it is in the hulk market's own ships. Own saves only.
#   tools/run_test.sh tests/find_ship_check.gd --fixed-fps 60


func _initialize() -> void:
	# 68 号: this test reads the hulks the market drew by itself (before the star-map sweep)
	Scan.ON = false
	Career.path = "user://zp_test_find_ship_career.json"
	SaveGame.path = "user://zp_test_find_ship_save.json"
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
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.offers = Market.make(4242, Career.data)
	Career.save()
	# ---- the market: finds only
	var offers: Array = Career.data.offers
	var all_finds := not offers.is_empty()
	for o in offers:
		all_finds = all_finds and o.get("find", false) and str(o.get("owner", "")) == "salvage" and o.has("station") and float(o.fee) > 0.0 and float(o.get("tow_days", 0.0)) > 0.0
	check(all_finds, "the market is the belt's unowned hulks, each with its station and quoted tow (%d)" % offers.size())
	var several_seeds_clean := true
	for sd in [1, 7, 99, 1234]:
		for o in Market.make(sd, Career.data):
			several_seeds_clean = several_seeds_clean and o.get("find", false)
	check(several_seeds_clean, "no client contract on any market")
	await _spawn()
	await _frames(20)
	# ---- short of cash with a tow already on credit: nothing happens (80 号: the first tow is
	# free and one more may go on credit — tests/tow_credit_check.gd)
	var first: Dictionary = Career.data.offers[0]
	Career.data.seen["first_tow"] = true
	Career.data.tow_owed = 500.0
	Career.data.money = float(first.fee) - 1.0
	Career.save()
	var poor := ShipMarket.tow_find(0)
	check(not poor.ok and Career.data.offers.size() == offers.size() and absf(float(Career.data.money) - (float(first.fee) - 1.0)) < 0.01, "short of the tow: nothing sent, nothing taken")
	# ---- sent
	Career.data.tow_owed = 0.0
	Career.data.money = 300000.0
	Career.save()
	var id := str(first.id)
	var r := ShipMarket.tow_find(0)
	var a := ShipMarket.asset(id)
	check(r.ok and absf(300000.0 - float(Career.data.money) - float(first.fee)) < 0.01 and not Career.data.offers.any(func(o): return str(o.get("id", "")) == id) and str(a.get("state", "")) == "towing", "a tug sent: the tow paid (%s), the card gone, the hulk on its way" % Pal.money(float(first.fee)))
	check(ShipMarket.on_the_way().size() == 1 and float(ShipMarket.on_the_way()[0].left_s) > 0.0, "it is listed on the way home (%d s)" % int(float(ShipMarket.on_the_way()[0].left_s)))
	# the page while it is on the way
	g.open_console("terminal")
	await _frames(6)
	var term = g.console_ui
	term._skip_boot()
	term.set_tab(0)
	await _frames(40)
	Cap.save(root, "res://tests/out/find_ships_zh.png")
	term.close()
	await _frames(6)
	# ---- arrived: a card to strip
	Shipping.data().day = float(a.run.depart) + float(a.run.tof) + 0.01
	ShipMarket.tick()
	Career.save()
	await _frames(4)
	var card := {}
	for o in Career.data.offers:
		if str(o.get("id", "")) == id:
			card = o
	check(str(ShipMarket.asset(id).state) == "arrived" and not card.is_empty() and card.get("bought", false) and float(card.get("fee", 0.0)) == 0.0, "arrived: a card to strip, nothing more to pay")
	check(ShipMarket.data().assets.any(func(x): return str(x.id) == id and x.get("found", false)), "and it is in the hulk market's own ships")
	var idx: int = Career.data.offers.find(card)
	var job := Career.accept(idx)
	check(str(job.get("id", "")) == id and str(job.get("ship", "")) == str(first.ship), "taking it starts the job on that ship (%s)" % str(job.get("ship", "")))
	g.queue_free()
	await _frames(4)
	print("FIND SHIP %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
