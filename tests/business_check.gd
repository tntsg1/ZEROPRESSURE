extends "res://tests/guide_check.gd"
# 77 号 (G6.4), cut down by 128 号 第 6 段 (2026-11-07: the tug charters and the third-party
# storage are deleted): the gas line's automation buys its feed within the player's bounds, and
# half an hour of game time with no ship stripped ends with a positive profit on the gas supply
# that comes from real orders. The tug and cargo consoles no longer offer either service.
# Own saves only.
#   tools/run_test.sh tests/business_check.gd --fixed-fps 60


func _initialize() -> void:
	Career.path = "user://zp_test_business_career.json"
	SaveGame.path = "user://zp_test_business_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _tick(dt: float) -> void:
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
	# ---------------------------------------------------------------- half an hour, no ship stripped
	Career.data.money = 300000.0
	Career.data.port["tug"] = 2
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
	Career.data.erase("gas")
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
	gd.auto.supply = false
	for c in gd.callers:
		if str(c.state) == "offered":
			c.state = "passed"
	var extra := 0.0
	while extra < 1500.0 and gd.callers.any(func(c): return str(c.state) in ["accepted", "docked"]):
		_tick(5.0)
		extra += 5.0
	var gn := float(gd.earned) - float(gd.spent)
	print("  30 min: supply %s / %s (%.0f t bought)" % [Pal.money(float(gd.earned)), Pal.money(float(gd.spent)), bought])
	check(float(gd.earned) > 0.0 and gn > 0.0, "the gas supply made a profit: %s" % Pal.money(gn))
	var paid_out := 0.0
	for c in gd.callers:
		paid_out += float(c.get("paid", 0.0))
	check(paid_out > 0.0 and absf(paid_out - float(gd.earned)) < 1.0, "every dollar the supply earned was paid by a ship's order (%s)" % Pal.money(paid_out))
	check(gd.callers.filter(func(c): return str(c.state) in ["offered", "accepted", "docked"]).size() <= GasLine.CALL_MAX, "the demand stayed finite throughout")
	print("  money %s → %s" % [Pal.money(money_start), Pal.money(float(Career.data.money))])
	# the consoles: 128 号 第 6 段 — no tug charters, no third-party storage any more
	for z in ["tug", "cargo"]:
		g.drone.global_position = PortStructure.console_spot(z)
		await _frames(10)
		g.open_district(z)
		await _frames(20)
		check(g.console_ui != null and not "biz_box" in g.console_ui and not _texts(g.console_ui).contains("拖船外运") and not _texts(g.console_ui).contains("第三方仓储") and not _texts(g.console_ui).contains("接这单"), "the %s console has no charters or third-party storage" % z)
		Cap.save(root, "res://tests/out/business_%s_zh.png" % z)
		if g.console_ui != null:
			g.console_ui.close()
		await _frames(4)
	g.queue_free()
	await _frames(4)
	print("BUSINESS %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()


func _texts(n: Node) -> String:
	var out := ""
	if n is Label or n is Button or n is RichTextLabel:
		out += str(n.text) + "
"
	for c in n.get_children():
		out += _texts(c)
	return out
