extends "res://tests/guide_check.gd"
const Hall = preload("res://scripts/hall_market.gd")

func _initialize() -> void:
	Career.path = "user://zp_test_multi_trade_career.json"
	SaveGame.path = "user://zp_test_multi_trade_save.json"
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
	Career.data.prologue_done = true
	Career.data.seen = {"port_walk": true, "intro": true, "belt_prelude": true, "first_ship": true}
	Career.data.port = {"salvage": 1, "trade": 1}
	Career.data.money = 10000.0
	Career.data.parts = [
		{"uid": "batch-a", "nk": "p_battery", "cls": "power", "cond": 1.0, "value": 2000.0, "ship": "tug", "tag": "BAT-T", "mass": 0.4},
		{"uid": "batch-b", "nk": "p_pump", "cls": "power", "cond": 1.0, "value": 3000.0, "ship": "tug", "tag": "PUMP-T", "mass": 0.5}]
	StoreBook._add_raw(Exchange.INGOT, 5.0, "test", "")
	await _spawn()
	g.open_store()
	await _frames(10)
	var ui = g.console_ui
	var raws: Array = ui.items.filter(func(it): return str(it.id).begins_with("r:"))
	check(raws.size() == 3, "5 tonnes create three bundles")
	if raws.size() != 3:
		quit(1)
		return
	var first := str(raws[0].id)
	var last := str(raws[2].id)
	ui._multi = {first: true, last: true, "p:batch-a": true}
	ui._layout()
	var money := float(Career.data.money)
	var before_n := Hall.listings().size()
	check(ui.trade_open(), "trade port is open")
	if DisplayServer.get_name() != "headless":
		await _frames(3)
		Cap.save(root, "res://tests/out/store_multi_trade_check.png")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (ui._btns["trade"] as Rect2).get_center()
	ui._gui_input(click)
	check(Hall.listings().size() == before_n + 3, "the selected two bundles and equipment are listed")
	check(is_equal_approx(float(StoreBook.raw_stock().get(Exchange.INGOT, 0.0)), 2.0), "the unselected two-tonne bundle stays in stock")
	check(Career.data.parts.size() == 1 and str(Career.data.parts[0].uid) == "batch-b", "unselected equipment stays in stock")
	check(is_equal_approx(float(Career.data.money), money), "no cash arrives before the listings sell")
	check(ui.message.contains("成交后") and ui.message.contains("5%"), "message explains delayed payment and fee")
	var saved := SaveGame.read_career(Career.path)
	check(saved.get("hall", {}).get("listings", []).size() == before_n + 3, "listings are saved for the next session")
	var listed_t := 0.0
	for listing in Hall.listings():
		listed_t += float(listing.pl.get("t", 0.0))
	check(is_equal_approx(listed_t, 3.0), "the selected full and partial bundles total three tonnes")
	Career.data.port.trade = 0
	ui._multi = {"p:batch-b": true, "missing": true}
	ui._press("trade")
	check(Career.data.parts.size() == 1 and ui._multi.size() == 2 and ui.message.contains("开放"), "a closed exchange leaves selection and goods untouched")
	Career.data.port.trade = 1
	ui._multi = {"p:batch-b": true, "missing": true}
	ui._press("trade")
	check(ui.message.contains("1 件未挂单") and Career.data.parts.is_empty(), "partial failure reports the count and preserves successful listing")
	ui.on_close.call()
	g.queue_free()
	await _frames(4)
	quit(1 if fails else 0)
