extends "res://tests/guide_check.gd"
# 72 号: the tug yard. Hulks towed home wait on open-air berths outside the tug station (1 / 2 / 4
# by its stage); with the yard full no tug is sent; the station's stage sets how long a ship can
# be towed; a company tug, charged, tows for half the quote and comes home flat, charging on the
# grid (3 MW, the tug group); the contract's opening pushes the hulk from its yard berth to the
# dock. Own saves only.
#   tools/run_test.sh tests/tug_yard_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_tug_yard_career.json"
	SaveGame.path = "user://zp_test_tug_yard_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _find(ship: String, id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var o := Market.offer(rng, Career.data, 1, {}, "full", ship, "salvage")
	o.id = id
	o.find = true
	o.station = 0
	var q := ShipMarket.find_quote(o)
	o.fee = float(q.fee)
	o.tow_days = float(q.run.tof)
	Career.data.offers.append(o)
	return o


func _arrive(id: String) -> void:
	var a := ShipMarket.asset(id)
	Shipping.data().day = float(a.run.depart) + float(a.run.tof) + 0.01
	ShipMarket.tick()
	ShipMarket.asset(id).seen_in = true
	Career.save()


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.offers = []
	Career.data.money = 500000.0
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.upgrades = {"berth88": true}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	# ---- stage 0: one berth, the rented tug, short ships only
	check(TugYard.slots() == 1 and TugYard.max_len() == 44.0, "stage 0: one yard berth, ships up to 44 m")
	var long := _find("tw64", "F-LONG")
	var i_long: int = Career.data.offers.find(long)
	var r := ShipMarket.tow_find(i_long)
	check(not r.ok and "拖不动" in str(r.reason), "a 64 m ship is too long for the rented tug: %s" % str(r.get("reason", "")))
	var a1 := _find("tug", "F-A1")
	r = ShipMarket.tow_find(Career.data.offers.find(a1))
	check(r.ok and str(ShipMarket.asset("F-A1").get("tug", "-")) == "" and is_equal_approx(float(r.fee), float(a1.fee)), "sent with the contractor's tug at the full quote")
	var a2 := _find("tug", "F-A2")
	r = ShipMarket.tow_find(Career.data.offers.find(a2))
	check(not r.ok and "泊位满了" in str(r.reason), "the yard full (one on its way): nothing more sent: %s" % str(r.get("reason", "")))
	_arrive("F-A1")
	check(int(ShipMarket.asset("F-A1").get("yard", -1)) == 0 and TugYard.taken().size() == 1, "home: it lies on yard berth 1")
	# ---- stage 1: two berths, our own TG-1 at half fee
	Career.data.port["tug"] = 1
	check(TugYard.slots() == 2 and TugYard.max_len() == 88.0 and TugYard.ready_tug() == "TG-1", "stage 1: two berths, up to 88 m, TG-1 ready")
	var fee_q := float(long.fee)
	r = ShipMarket.tow_find(Career.data.offers.find(long))
	check(r.ok and str(ShipMarket.asset("F-LONG").tug) == "TG-1" and is_equal_approx(float(r.fee), snappedf(fee_q * 0.5, 100.0)), "TG-1 tows the 64 m ship for half the quote (%s of %s)" % [Pal.money(float(r.fee)), Pal.money(fee_q)])
	check(TugYard.ready_tug() == "" and "TG-1 出航中" in TugYard.status(), "TG-1 is away: %s" % TugYard.status())
	_arrive("F-LONG")
	check(int(ShipMarket.asset("F-LONG").yard) == 1 and TugYard.charge("TG-1") == 0.0, "home on berth 2, TG-1 flat")
	check(TugYard.full() and TugYard.block("tug") != "", "the yard full again")
	# charging on the grid
	await _spawn()
	await _frames(20)
	Career.data.port["power"] = 1
	var al := Grid.dispatch(g)
	check(al.has("tug_TG-1") and is_equal_approx(float(al["tug_TG-1"].own), 3.0), "TG-1 charges on the grid: 3 MW to the tug group")
	var c0 := TugYard.charge("TG-1")
	TugYard.advance(g, 30.0)
	check(absf(TugYard.charge("TG-1") - c0 - 0.5) < 0.01, "half charged in 30 s at full power (%.2f → %.2f)" % [c0, TugYard.charge("TG-1")])
	Career.data.port["power"] = 0
	var fake := preload("res://tests/grid_check.gd").Fake.new()
	fake.group = "process"
	fake.mw = 24.0
	root.add_child(fake)
	Grid.add_load_source(fake)
	await _frames(2)
	TugYard.advance(g, 30.0)
	check(TugYard.charge("TG-1") < 0.5 + 0.05 and TugYard.charge("TG-1") >= 0.5, "short of power (tugs last), it barely charges (%.2f)" % TugYard.charge("TG-1"))
	fake.queue_free()
	Career.data.port["power"] = 1
	await _frames(2)
	TugYard.advance(g, 40.0)
	check(TugYard.charge("TG-1") >= 1.0 and TugYard.ready_tug() == "TG-1", "charged: TG-1 ready again")
	# the yard drawn: two hulks on their berths
	g.port_view = true
	await _frames(30)
	g.cam_override = TugYard.slot_px(0) + Vector2(-30, -10) * Geom.M
	g.zoom_override = 0.22
	await _frames(40)
	Cap.save(root, "res://tests/out/tug_yard_zh.png")
	g.port_view = false
	g.cam_override = null
	g.zoom_override = -1.0
	check(g.tow_traffic._parked.size() == 2 and g.tow_traffic._parked.all(func(p): return int(p.slot) in [0, 1]), "the yard holds both, each on its berth")
	g.queue_free()
	await _frames(4)
	# ---- pushed in: the contract's opening starts at its yard berth
	Career.data.active = {}
	ShipMarket.cards()
	var idx := -1
	for i in Career.data.offers.size():
		if str(Career.data.offers[i].get("id", "")) == "F-LONG":
			idx = i
	var job := Career.accept(idx)
	check(str(job.get("id", "")) == "F-LONG", "the hulk in the yard is taken to strip (idx %d, active %s, offers %s)" % [idx, str(Career.data.active.get("id", "")), str(Career.data.offers.map(func(o): return [str(o.get("id", "")), o.get("queued", false)]))])
	if job.is_empty():
		quit()
		return
	Game.contract = job
	Game.start_ship = str(job.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	await _frames(20)
	var from: Vector2 = g.yard_start()
	check(from != Vector2.INF and from.distance_to(TugYard.slot_px(1)) < 120.0 * Geom.M, "the opening starts at yard berth 2")
	check(g.state == "intro" and g.world.position.distance_to(from) < 60.0 * Geom.M, "the hulk leaves from there (%.0f m off)" % (g.world.position.distance_to(from) / Geom.M))
	await _frames(150)
	Cap.save(root, "res://tests/out/tug_yard_push_zh.png")
	# the push round the station (PUSH_T) and the push in (~6 s), not a fixed wait
	var t := 0
	while g.state == "intro" and t < int((g.PUSH_T + 8.0) * 60.0):
		await _frames(1)
		t += 1
	check(g.world.position == Vector2.ZERO and g.state != "intro", "and ends in the dock (%s)" % g.state)
	g.queue_free()
	await _frames(4)
	print("TUG YARD %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
