extends "res://tests/guide_check.gd"
# 77 号 (G6.4): services that pay without a ship to strip. Tug charters take a real company tug
# for the round trip on real orbits (not free for our own tows), cost propellant, a charge on
# the grid and wear (a shop visit every third), and pay the fee on return; demand is finite and
# offers expire. Third-party storage needs a row given to clients, takes real room (20 t a row),
# comes in and goes out by the forklifts, is never the company's stock, and pays by the period
# and a handling fee. Automation takes only what is inside the player's bounds, keeps a tug back,
# keeps room free, stops on "no new work", never takes what it cannot pay for. Then half an hour
# of game time with no ship stripped: charters, storage and the gas line's supply each end with
# a positive profit that comes from real orders. Own saves only.
#   tools/run_test.sh tests/business_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_business_career.json"
	SaveGame.path = "user://zp_test_business_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _tick(dt: float) -> void:
	Charter.advance(dt)
	Depot.advance(dt)
	GasLine.advance(g, dt)
	Warehouse.advance(g, dt)
	TugYard.advance(g, dt)


func _stock() -> Dictionary:
	return Career.data.exchange.actors.company.stock


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.seed = 20261026
	Career.data.market = true
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1, "cargo": 1, "tug": 1}
	Career.data.upgrades = {"gas_line": 1, "lox_tank": 1}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.exchange = Exchange.fresh(300000.0)
	Career.save()
	await _spawn()
	await _frames(20)
	# ---------------------------------------------------------------- tug charters
	check(Charter.open() and Charter.data().offers.is_empty(), "the tug station works, TG-1 is home; no charter offered yet")
	Charter.advance(Charter.EVERY)
	check(Charter.data().offers.size() == 1, "one comes after four minutes")
	for i in 6:
		Charter.advance(Charter.EVERY)
	check(Charter.data().offers.size() <= Charter.MAX_OPEN, "never more than three at a time (%d) — they also expire" % Charter.data().offers.size())
	# the best one
	var best := {}
	for o in Charter.data().offers:
		if best.is_empty() or Charter.net(o) > Charter.net(best):
			best = o
	var m0 := float(Career.data.money)
	var prop := Charter.prop_cost(best)
	var fee := float(best.fee)
	var r := Charter.accept(str(best.id))
	check(r.ok and str(r.tug) == "TG-1" and is_equal_approx(m0 - float(Career.data.money), prop), "taken: TG-1 goes, the propellant paid now (%s)" % Pal.money(prop))
	check(not TugFleet.home(0) and TugYard.ready_tug() == "", "TG-1 is away on the charter: not free for our own tows")
	var j: Dictionary = Charter.data().jobs[0]
	check(float(j.secs) > 60.0, "the round trip is flown on real orbits (%d s)" % int(float(j.secs)))
	Charter.advance(float(j.secs) + 0.1)
	check(Charter.data().jobs.is_empty() and TugFleet.home(0) and TugYard.charge("TG-1") == 0.0, "back: home, and flat")
	check(is_equal_approx(float(Charter.data().earned), fee), "the fee paid on return (%s)" % Pal.money(fee))
	var e0 := float(Charter.data().spent)
	for i in 12:
		TugYard.advance(g, 5.0)
	check(TugYard.charge("TG-1") >= 1.0 and float(Charter.data().spent) > e0, "it charges on the grid, and the charge is the charter's cost")
	# wear: every third charter, a minute in the shop
	Charter.data().wear["TG-1"] = Charter.WEAR_LIMIT - 1
	Career.data.tug_charge = {"TG-1": 1.0}
	Charter.new_offer()
	var o2: Dictionary = Charter.data().offers.back()
	Charter.accept(str(o2.id))
	Charter.advance(float(o2.secs) + 0.1)
	check(Charter.in_service("TG-1") and TugYard.ready_tug() == "", "the third charter: TG-1 is in the shop")
	Career.data.tug_charge = {"TG-1": 1.0}
	Charter.advance(Charter.SERVICE_S + 0.1)
	check(not Charter.in_service("TG-1") and TugYard.ready_tug() == "TG-1", "a minute later it is ready again")
	# automation bounds
	var ca: Dictionary = Charter.data().auto
	Charter.data().offers = []
	Charter.new_offer()
	var ao: Dictionary = Charter.data().offers.back()
	ca.on = true
	ca.min_net = Charter.net(ao) + 1.0
	Charter.data().t = 0.0
	Charter.advance(1.0)
	check(Charter.data().jobs.is_empty(), "auto: an offer under the player's minimum is left alone")
	ca.min_net = Charter.net(ao) - 1.0
	ca.stop_new = true
	Charter.advance(1.0)
	check(Charter.data().jobs.is_empty(), "auto: 'no new work' stops it")
	ca.stop_new = false
	var keep_money := float(Career.data.money)
	Career.data.money = Charter.prop_cost(ao) - 1.0
	Charter.advance(1.0)
	check(Charter.data().jobs.is_empty(), "auto: never takes what it cannot pay for")
	Career.data.money = keep_money
	Career.data.port["tug"] = 2
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 0.5}
	Charter.advance(1.0)
	check(Charter.data().jobs.is_empty(), "auto with two tugs, one flat: one is kept back for our own tows")
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
	Charter.advance(1.0)
	check(Charter.data().jobs.size() == 1, "both ready: it takes the charter")
	ca.on = false
	Charter.advance(float(Charter.data().jobs[0].secs) + 0.1)
	Career.data.port["tug"] = 1
	# ---------------------------------------------------------------- third-party storage
	Depot.advance(Depot.EVERY)
	var dof: Dictionary = Depot.data().offers.back()
	check(Depot.accept_block(str(dof.id)).contains("客户货"), "no row for clients yet: %s" % Depot.accept_block(str(dof.id)))
	Warehouse.set_row(7, "client")
	var stock0 := JSON.stringify(_stock())
	# the forklifts carry (the drone's own carrying is tests/cargo_floor_check.gd)
	Depot.set_fork_in(true)
	var dr := Depot.accept(str(dof.id))
	check(dr.ok and int(dr.row) == 7 and not Warehouse.job("DEPOT-IN:" + str(dof.id)).is_empty(), "B4 given to clients: taken, the forklift puts it away")
	check(JSON.stringify(_stock()) == stock0, "clients' goods are not the company's stock (not for sale, not for the furnace)")
	check(is_equal_approx(Depot.free_t(), Depot.ROW_CAP - float(dof.t)), "it takes real room: %.0f t of 20 left" % Depot.free_t())
	var big := Depot.new_offer()
	big.t = Depot.free_t() + 1.0
	check(Depot.accept_block(str(big.id)) != "", "a lot bigger than the room left is refused: %s" % Depot.accept_block(str(big.id)))
	Depot.decline(str(big.id))
	for i in 40:
		Warehouse.advance(g, 1.0)
		Depot.advance(1.0)
	var lot: Dictionary = Depot.data().lots[0]
	check(str(lot.state) == "stored", "on the rack")
	var de0 := float(Depot.data().earned)
	Depot.advance(Depot.PERIOD + 0.1)
	check(is_equal_approx(float(Depot.data().earned) - de0, float(lot.fee)), "a period: the fee paid (%s)" % Pal.money(float(lot.fee)))
	lot.left = 1
	Depot.advance(Depot.PERIOD + 0.1)
	check(str(lot.state) == "due" and not Warehouse.job("DEPOT:" + str(lot.id)).is_empty(), "due: a forklift goes for it")
	for i in 60:
		Warehouse.advance(g, 1.0)
		Depot.advance(1.0)
	check(Depot.data().lots.is_empty() and is_equal_approx(Depot.free_t(), Depot.ROW_CAP), "collected, the handling fee paid, the room free again")
	# ---------------------------------------------------------------- half an hour, no ship stripped
	Career.data.money = 300000.0
	Career.data.port["tug"] = 2
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
	Career.data.erase("charter")
	Career.data.erase("depot")
	Career.data.erase("gas")
	Charter.data().auto.on = true
	Charter.data().auto.min_net = 500.0
	Charter.data().auto.max_jobs = 2
	Depot.data().auto.on = true
	Depot.data().auto.min_fee = 150.0
	var gd := GasLine.data()
	gd.made = 2
	GasLine.set_auto("process", true)
	GasLine.set_auto("liquefy", true)
	GasLine.set_auto("supply", true)
	gd.auto.keep_lox = 0.0
	gd.auto.keep_o2 = 0.0
	gd.auto.min_price = 0.2
	# automatic feed buying, within its bounds
	gd.callers.append({"id": "SUP-T", "ship": "T", "want": "lox", "grade": "ind", "kg": 2000.0, "price": 0.6, "eta": 999.0, "stay": 60.0, "partial": true, "state": "offered", "reserved": 0.0, "got": 0.0, "t": 0.0})
	gd.auto.buy = true
	gd.auto.buy_max_price = 50.0
	GasLine.advance(g, 0.1)
	check(gd.orders.is_empty(), "auto-buy: the supplier's price over the player's cap — nothing bought")
	gd.auto.buy_max_price = 70.0
	gd.auto.cash_floor = float(Career.data.money)
	GasLine.advance(g, 0.1)
	check(gd.orders.is_empty(), "auto-buy: it would take the cash under the floor — nothing bought")
	gd.auto.cash_floor = 50000.0
	GasLine.advance(g, 0.1)
	check(gd.orders.size() == 1 and GasLine.oxygen_short() < 2000.0, "auto-buy: a ship wants 2 t of oxygen nobody has — 10 t of feed ordered, once")
	GasLine.advance(g, 0.1)
	var tons := 0.0
	for o in gd.orders:
		tons += float(o.t)
	check(gd.orders.size() == 2 and is_equal_approx(tons, 11.0) and GasLine.oxygen_short() == 0.0, "then only the 1 t still short — 11 t in all, the shortfall covered, no more")
	gd.callers = []
	gd.orders = []
	gd.earned = 0.0
	gd.spent = 0.0
	var money_start := float(Career.data.money)
	var bought := 0.0
	var t := 0.0
	while t < 1800.0:
		# the gas line buys its own feed (auto-buy, within its bounds); stopped near the end
		if t >= 1500.0:
			gd.auto.buy = false
		var n_orders: int = gd.orders.size()
		_tick(5.0)
		if gd.orders.size() > n_orders:
			bought += float(gd.orders.back().t)
		t += 5.0
		if int(t) % 60 == 0:
			await _frames(1)
	# time up: no new work; what is running is finished, then the books are closed
	Charter.data().auto.stop_new = true
	Depot.data().auto.stop_new = true
	gd.auto.supply = false
	for c in gd.callers:
		if str(c.state) == "offered":
			c.state = "passed"
	var extra := 0.0
	while extra < 1500.0 and (not Charter.data().jobs.is_empty() or gd.callers.any(func(c): return str(c.state) in ["accepted", "docked"])):
		_tick(5.0)
		extra += 5.0
	var cd: Dictionary = Charter.data()
	var dd: Dictionary = Depot.data()
	var cn := float(cd.earned) - float(cd.spent)
	var dn := float(dd.earned) - float(dd.spent)
	var gn := float(gd.earned) - float(gd.spent)
	print("  30 min: charter %s / %s, storage %s / %s, supply %s / %s (%.0f t bought)" % [Pal.money(float(cd.earned)), Pal.money(float(cd.spent)), Pal.money(float(dd.earned)), Pal.money(float(dd.spent)), Pal.money(float(gd.earned)), Pal.money(float(gd.spent)), bought])
	check(float(cd.earned) > 0.0 and cn > 0.0, "tug charters made a profit: %s" % Pal.money(cn))
	check(float(dd.earned) > 0.0 and dn > 0.0, "storage made a profit: %s" % Pal.money(dn))
	check(float(gd.earned) > 0.0 and gn > 0.0, "the gas supply made a profit: %s" % Pal.money(gn))
	var paid_out := 0.0
	for c in gd.callers:
		paid_out += float(c.get("paid", 0.0))
	check(paid_out > 0.0 and absf(paid_out - float(gd.earned)) < 1.0, "every dollar the supply earned was paid by a ship's order (%s)" % Pal.money(paid_out))
	check(cd.offers.size() <= Charter.MAX_OPEN and dd.offers.size() <= Depot.MAX_OPEN and gd.callers.filter(func(c): return str(c.state) in ["offered", "accepted", "docked"]).size() <= GasLine.CALL_MAX, "the demand stayed finite throughout")
	print("  money %s → %s" % [Pal.money(money_start), Pal.money(float(Career.data.money))])
	# the consoles
	for z in ["tug", "cargo"]:
		g.drone.global_position = PortStructure.console_spot(z)
		await _frames(10)
		g.open_district(z)
		await _frames(20)
		check(g.console_ui != null and g.console_ui.biz_box != null and g.console_ui.biz_box.get_child_count() > 2, "the %s console shows its business" % z)
		Cap.save(root, "res://tests/out/business_%s_zh.png" % z)
		if g.console_ui != null:
			g.console_ui.close()
		await _frames(4)
	g.queue_free()
	await _frames(4)
	print("BUSINESS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
