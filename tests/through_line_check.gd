extends "res://tests/guide_check.gd"
# 37 号: the through line. One press at the sorting desk: the feed comes in, the drives start
# themselves, the ferrous is read on its way by the in-line assay and goes straight into the arc
# furnace, which strikes its arcs by itself; only the nonferrous mix goes back to the warehouse.
# Selling is a listing: the client buys it, paid on the sale. Own test saves only.
#   tools/run_test.sh tests/through_line_check.gd --fixed-fps 60
const Ex = preload("res://scripts/industrial_exchange.gd")


func _initialize() -> void:
	# 73 号: this test is about the physical feed and delivery runs, not the racks: goods leave at once
	Warehouse.ON = false
	# 64 号: this checks the older feed chain (bought / kept scrap, sorting); kept in code, switched off in play
	Career.INGOTS = false
	preload("res://scripts/industrial_exchange.gd").INGOTS = false
	Career.path = "user://zp_test_through_career.json"
	SaveGame.path = "user://zp_test_through_save.json"
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
	# a tonne of mixed metal with its record, as the training run hands it over
	Career.data.drill = {}
	Career.data.term_open = {}
	check(Drill.grant().ok, "a tonne of mixed metal in stock")
	Career.data.drill = {"granted": true, "done": true}
	var mixed0 := _stock("mixed_metal:0")
	g.drone.global_position = g.industrial_sort.site()
	g.drone.linear_velocity = Vector2.ZERO
	await _frames(20)
	g.open_sort()
	await _frames(10)
	var ui = g.console_ui
	check(ui != null and str(ui.main.text).begins_with("完整加工流程"), "the sorting desk's one button: run the line (%s)" % (ui.main.text if ui != null else ""))
	check(is_equal_approx(ui.quantity.value, 1.0), "it offers what is in stock (%.2f t)" % ui.quantity.value)
	ui.main.pressed.emit()
	await _frames(4)
	check(Career.data.industrial_sort.get("through", false) and is_equal_approx(_stock("mixed_metal:0"), mixed0 - 1.0), "one press: the tonne leaves the stock for the line")
	ui.close()
	await _frames(4)
	check(await _until_state("industrial_sort", "processing", 20000), "the feed reaches the line")
	await _frames(30)
	check(bool(g.industrial_sort.line().company_powered), "the drives start themselves")
	check(await _until_state("industrial_heat", "processing", 30000), "the ferrous goes into the arc furnace")
	var h: Dictionary = Career.data.industrial_heat
	var a1 := str(h.source_lots[0].source_id)
	check(a1.ends_with("/FE/A1") and str(Career.data.exchange.actors.company.lots[a1].key) == "ferrous_scrap:1", "read by the in-line assay and made grade 1 on its way (%s)" % a1)
	check(is_equal_approx(float(g.plant.smelter.input_t), float(h.quantity)), "charged into the furnace: %.2f t" % float(h.quantity))
	check(_stock("ferrous_scrap:0") < 0.001 and _stock("ferrous_scrap:1") < 0.001, "it never went through the warehouse")
	await _frames(120)
	h = Career.data.industrial_heat
	check(h.get("auto", false) and g.plant.smelter.manual_power > 0.99, "the furnace struck its arcs by itself")
	check(await _until_state("industrial_sort", "complete", 30000), "the nonferrous mix goes back to the warehouse")
	check(_stock("nonferrous_mix:0") > 0.05, "nonferrous in stock: %.2f t" % _stock("nonferrous_mix:0"))
	# selling: a listing, bought by the client, paid at once
	var st: Dictionary = Career.data.exchange
	st.actors.company.lots["TEST-BIL"] = {"id": "TEST-BIL", "key": "steel_billet:1", "available": 1.0, "total": 1.0, "origin": "manufactured"}
	st.actors.company.stock["steel_billet:1"] = float(st.actors.company.stock.get("steel_billet:1", 0.0)) + 1.0
	Career.save()
	var cash := float(Career.data.money)
	var r := Ex.command("post", {"side": "sell", "item": "steel_billet", "grade": 1, "quantity": 1.0, "price": 1100.0})
	check(r.ok and float(Career.data.money) > cash + 1000.0, "listed at the client's price: bought and paid on the spot (+$%.0f)" % (float(Career.data.money) - cash))
	g.queue_free()
	await _frames(4)
	print("THROUGH LINE %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit()
