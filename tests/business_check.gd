extends "res://tests/guide_check.gd"
# 77 号 (G6.4), cut down by 128 号 第 6 段 (2026-11-07: the tug charters and the third-party
# storage are deleted; 132 号: no passing ships buy gas): the gas line's automation runs within the
# player's bounds, buys no feed when nobody is short, and half an hour of game time puts the hoses'
# gas into the LOX tank for the exchange. The tug and cargo consoles no longer offer either service.
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
	gd.auto.keep_o2 = 0.0
	# 132 号 (user 2026-11-07 "燃料外运也删了"): no passing ship asks, so the feed buying finds no shortfall
	check(not GasLine.set_auto("supply", true).ok, "no 'take supply orders' switch any more")
	# 132 号 (user 2026-11-07): no automatic feed buying any more; an old save's switch is dropped
	check(not GasLine.set_auto("buy", true).ok, "no 'buy feed' switch any more")
	gd.auto["buy"] = true
	gd.auto["buy_max_price"] = 70.0
	gd.auto["cash_floor"] = 50000.0
	var gd2 := GasLine.data()
	check(not gd2.auto.has("buy") and not gd2.auto.has("buy_max_price") and not gd2.auto.has("cash_floor"), "an old save's feed-buying setting is dropped")
	GasLine.advance(g, 0.1)
	check(gd.orders.is_empty(), "nothing bought by itself")
	# half an hour, no ship stripped: two batches of the hoses' gas go through the line into the tank
	GasLine.receive({"o2": 2100.0, "n2": 7800.0, "ar": 100.0}, "TUG-001")
	GasLine.receive({"o2": 2100.0, "n2": 7800.0, "ar": 100.0}, "S09-001")
	var money_start := float(Career.data.money)
	var said: Array = []
	var t := 0.0
	while t < 1800.0:
		said += GasLine.advance(g, 5.0)
		Warehouse.advance(g, 5.0)
		TugYard.advance(g, 5.0)
		t += 5.0
		if int(t) % 60 == 0:
			await _frames(1)
	print("  30 min: earned %s, spent %s, LOX %.0f kg" % [Pal.money(float(gd.earned)), Pal.money(float(gd.spent)), float(gd.lox.kg)])
	check(not gd.has("callers") and not said.any(func(x): return str(x).find("补给") >= 0), "half an hour: no passing ship asked for supply")
	check(float(gd.earned) == 0.0, "nothing earned from passing ships (LOX is sold on the exchange)")
	check(float(gd.lox.kg) > 1000.0, "the line made LOX into the tank for the exchange (%.0f kg)" % float(gd.lox.kg))
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
