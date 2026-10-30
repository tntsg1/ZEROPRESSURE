extends "res://tests/guide_check.gd"
# 39 号: rush bids and the first automation. A client's rush is a time-limited high bid for grade 1
# billet from the company only: list at its price and it is paid at once; let it run out and it
# lapses with nothing charged. After three tapped heats the arc furnace's auto sample-and-tap can
# be bought; fitted, a through-line heat goes from one press to billets in stock unattended.
# Own test saves only.
#   tools/run_test.sh tests/rush_auto_check.gd --fixed-fps 60
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	# 73 号: this test is about the physical feed and delivery runs, not the racks: goods leave at once
	Warehouse.ON = false
	Career.path = "user://zp_test_rush_career.json"
	SaveGame.path = "user://zp_test_rush_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _stock(key: String) -> float:
	return float(Career.data.exchange.actors.company.stock.get(key, 0.0))


func _until_state(key: String, target: String, limit: int) -> bool:
	for i in limit:
		await _frames(1)
		if str(Career.data.get(key, {}).get("state", "")) == target:
			return true
	return false


func _until_rush(limit: int) -> Dictionary:
	for i in limit:
		await _frames(1)
		var o: Dictionary = Ex.rush_order(Career.data.exchange)
		if not o.is_empty():
			return o
	return {}


func _rush_decision() -> Dictionary:
	for d in Ops.decisions(g):
		if str(d.title).begins_with("加急"):
			return d
	return {}


func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 300000.0
	Career.data.port = {"salvage": 1, "trade": 1, "process": 1, "power": 1}
	Career.data.drill = {"granted": true, "done": true}
	Career.save()
	await _spawn()
	await _frames(10)
	check(Ex.command("view").ok, "the exchange is open")
	# ---- a rush bid
	Career.data.exchange.rush_next = float(Career.data.exchange.clock)
	var o := await _until_rush(120)
	check(not o.is_empty(), "a rush bid goes up")
	check(str(o.owner) in Ex.RUSH_BUYERS and str(o.get("exclusive_seller", "")) == Ex.PLAYER, "from a port client, for the company only (%s)" % str(o.get("owner", "")))
	var k := float(o.get("price", 0.0)) / 1100.0
	check(k >= Ex.RUSH_K.x - 0.01 and k <= Ex.RUSH_K.y + 0.01 and float(o.quantity) >= 0.5 and float(o.quantity) <= 1.5, "%.2f t at %.2f× the client price" % [float(o.get("quantity", 0.0)), k])
	var d := _rush_decision()
	check(not d.is_empty() and int(d.level) == Ops.CHANCE and str(d.go) == "clients", "the home page shows it as a chance while there are no billets (%s)" % str(d.get("title", "")))
	await _frames(30)
	check(float(Ex.rush_order(Career.data.exchange).get("remaining", 0.0)) == float(o.quantity), "nobody else's billets fill it")
	# billets in stock: list at the rush price, paid at once
	var st: Dictionary = Career.data.exchange
	st.actors.company.lots["TEST-BIL"] = {"id": "TEST-BIL", "key": "steel_billet:1", "available": 2.0, "total": 2.0, "origin": "manufactured"}
	st.actors.company.stock["steel_billet:1"] = float(st.actors.company.stock.get("steel_billet:1", 0.0)) + 2.0
	Career.save()
	d = _rush_decision()
	check(not d.is_empty() and int(d.level) == Ops.TODO, "with billets it is a job")
	var cash := float(Career.data.money)
	var want := float(o.quantity) * float(o.price) * (1.0 - Ex.FEE)
	var r := Ex.command("rush_sell")
	check(r.ok and absf(float(Career.data.money) - cash - want) < 1.0, "listed at the rush price: paid on the spot (+$%.0f of $%.0f)" % [float(Career.data.money) - cash, want])
	check(Ex.rush_order(Career.data.exchange).is_empty(), "the rush is filled")
	# ---- the next one runs out: cancelled, nothing charged
	Career.data.exchange.rush_next = float(Career.data.exchange.clock)
	o = await _until_rush(120)
	check(not o.is_empty(), "another rush later")
	var buyer := str(o.owner)
	var buyer_cash := float(Career.data.exchange.actors[buyer].cash)
	var reserved := float(o.cash_reserved)
	cash = float(Career.data.money)
	o.expires = float(Career.data.exchange.clock) + 0.5
	var lapsed := false
	for i in 120:
		await _frames(1)
		if Ex.rush_order(Career.data.exchange).is_empty():
			lapsed = true
			break
	var gone: Dictionary = {}
	for row in Career.data.exchange.orders:
		if str(row.id) == str(o.id):
			gone = row
	check(lapsed and str(gone.get("state", "")) == "cancelled", "run out, it is cancelled")
	check(absf(float(Career.data.money) - cash) < 0.01 and absf(float(Career.data.exchange.actors[buyer].cash) - buyer_cash - reserved) < 0.01, "no penalty; the client's money goes back")
	check(float(Career.data.exchange.rush_next) >= float(Career.data.exchange.clock) + Ex.RUSH_GAP.x - 1.0, "the next one is minutes away")
	Career.data.exchange.rush_next = 1.0e9
	# ---- the first automation
	check(not HeatAuto.offer() and not HeatAuto.install().ok, "not before three heats")
	Career.data.heat_count = 3
	check(HeatAuto.offer(), "offered after three heats")
	var money0 := float(Career.data.money)
	check(HeatAuto.install().ok and HeatAuto.on() and absf(money0 - float(Career.data.money) - HeatAuto.PRICE) < 0.01, "fitted for %s" % Pal.money(HeatAuto.PRICE))
	# one press at the sorting desk, then hands off until the billets are in stock
	# a tonne of mixed metal with its record (the training ticket is spent once billets have sold)
	var receipt := {"id": "TEST-MIX", "mass_t": 1.0, "material": "ungraded_scrap", "grade": 0, "state": "raw_received", "storage": "exchange",
		"material_profile": {"version": 1, "nonmagnetic_share": Drill.SHARE, "basis": "port_authority_grant"}, "origin": "port_authority_grant"}
	Career.data.material_batches.append(receipt)
	Ex.import_received(Career.data.exchange, [receipt])
	Ex.sync_batches(Career.data, Career.data.exchange)
	check(Career.save() and _stock("mixed_metal:0") >= 1.0, "a tonne of mixed metal in stock")
	var billets0 := _stock("steel_billet:1") + _stock("steel_billet:0") + _stock("steel_billet:2")
	g.drone.global_position = g.industrial_sort.site()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(20)
	g.open_sort()
	await _frames(10)
	var ui = g.console_ui
	ui.main.pressed.emit()
	await _frames(4)
	ui.close()
	await _frames(4)
	check(await _until_state("industrial_heat", "processing", 50000), "the line charges the furnace")
	# away from the desk: no one presses sample or tap
	g.drone.global_position = g.industrial_sort.site()
	var tapped := false
	for i in 60000:
		await _frames(1)
		if str(g.plant.smelter.phase) in ["tilt", "pour"]:
			tapped = true
			break
	check(tapped, "sampled and tapped by itself")
	check(await _until_state("industrial_heat", "complete", 40000), "the billets come back to the warehouse")
	var billets1 := _stock("steel_billet:1") + _stock("steel_billet:0") + _stock("steel_billet:2")
	check(billets1 > billets0 + 0.1 and int(Career.data.heat_count) == 4, "billets in stock (+%.2f t), heat count %d" % [billets1 - billets0, int(Career.data.get("heat_count", 0))])
	g.queue_free()
	await _frames(4)
	print("RUSH AUTO %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
