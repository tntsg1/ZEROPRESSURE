extends "res://tests/guide_check.gd"
const Hall = preload("res://scripts/hall_market.gd")

func _initialize() -> void:
	Career.path = "user://zp_test_quantity_career.json"
	SaveGame.path = "user://zp_test_quantity_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _slide(ui, factor: float) -> void:
	ui._layout()
	var r: Rect2 = ui._btns["quantity"]
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(lerpf(r.position.x + 16, r.end.x - 16, factor), r.get_center().y)
	ui._gui_input(event)
	event = event.duplicate()
	event.pressed = false
	ui._gui_input(event)

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
	StoreBook._add_raw(Exchange.INGOT, 5.0, "test", "")
	await _spawn()
	g.open_store()
	await _frames(10)
	var ui = g.console_ui
	var raws: Array = ui.items.filter(func(it): return str(it.id).begins_with("r:"))
	ui.select(str(raws[0].id))
	ui._layout()
	check(ui._btns.has("quantity") and not ui._btns.has("keep"), "material slider replaces keep")
	check(ui._quantity_chosen().size() == 1 and str(ui._quantity_chosen()[0].id) == str(raws[0].id) and is_equal_approx(float(ui._quantity_chosen()[0].t), 2.0), "one bundle means the item actually selected")
	_slide(ui, 0.0)
	check(ui.quantity == 0, "left end selects zero")
	var initial := float(Career.data.money)
	ui._press("sell")
	check(is_equal_approx(float(Career.data.money), initial) and is_equal_approx(float(StoreBook.raw_stock()[Exchange.INGOT]), 5.0), "zero cannot sell any stock")
	_slide(ui, 1.0)
	check(ui.quantity == 3, "right end selects all three bundles")
	_slide(ui, 2.0 / 3.0)
	check(ui.quantity == 2 and is_equal_approx(float(ui._quantity_chosen()[0].t) + float(ui._quantity_chosen()[1].t), 3.0), "two bundles include the one-tonne partial bundle")
	if DisplayServer.get_name() != "headless":
		await _frames(3)
		Cap.save(root, "res://tests/out/store_quantity_check.png")
	ui._press("trade")
	check(Hall.listings().size() == 2 and is_equal_approx(float(StoreBook.raw_stock()[Exchange.INGOT]), 2.0), "listing removes exactly the chosen three tonnes")
	check(is_equal_approx(float(Career.data.money), initial), "exchange listings do not pay immediately")
	ui.select(str(ui.items.filter(func(it): return str(it.id).begins_with("r:"))[0].id))
	ui._layout()
	_slide(ui, 1.0)
	ui._press("sell")
	check(float(StoreBook.raw_stock().get(Exchange.INGOT, 0.0)) < 0.01 and float(Career.data.money) > initial, "recycling sells the remainder and pays immediately")
	ui.on_close.call()
	g.queue_free()
	await _frames(4)
	quit(1 if fails else 0)
