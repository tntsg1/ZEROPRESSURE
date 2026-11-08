extends "res://tests/guide_check.gd"
const Hall = preload("res://scripts/hall_market.gd")

func _initialize() -> void:
	Career.path = "user://zp_test_order_click_career.json"
	SaveGame.path = "user://zp_test_order_click_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()

func _click(ui, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	ui._gui_input(ev)

func _run() -> void:
	Txt.zh = true
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.active = {}
	Career.data.story_job = {}
	Career.data.prologue_done = true
	Career.data.seen = {"port_walk": true, "intro": true, "belt_prelude": true, "first_ship": true}
	Career.data.port = {"salvage": 1, "trade": 1}
	var orders: Array = []
	for id in ["CLICK-A", "CLICK-B"]:
		orders.append({"id": id, "client": "测试客户", "cat": "equip", "kind": "p_winch", "n": 1.0, "lv": 1, "price": 9000.0, "k": 1.3, "at": Hall.clock(), "due": Hall.clock() + 600.0, "state": "open", "got": 0.0, "held": []})
	Hall.data().orders = orders
	await _spawn()
	g.open_hall("orders")
	await _frames(40)
	var ui = g.console_ui
	check(ui != null and ui.tab == "orders", "orders page opened")
	check(ui._btns.has("take") and ui._btns.has("o:CLICK-A"), "selected card and its action are drawn")
	if not ui._btns.has("take"):
		quit(1)
		return
	var btn: Rect2 = ui._btns["take"]
	check(ui._hit_button(btn.get_center()) == "take", "button wins over the enclosing card")
	_click(ui, btn.get_center())
	await _frames(4)
	check(str(Hall.order("CLICK-A").get("state", "")) == "taken", "left click takes the order without stock")
	check(ui.message.contains("接了"), "accepting displays feedback")
	btn = ui._btns["take"]
	_click(ui, btn.get_center())
	await _frames(4)
	check(str(Hall.order("CLICK-A").get("state", "")) == "open", "left click on the same action returns the order")
	g.sfx.last_play.erase("menu")
	_click(ui, (ui._btns["o:CLICK-B"] as Rect2).get_center())
	await _frames(3)
	check(ui.ord_sel == "CLICK-B", "clicking a different card still selects it")
	check(g.sfx.last_play.has("menu"), "selecting a custom-drawn card plays click feedback")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_ENTER
	ui._unhandled_input(key)
	await _frames(3)
	check(str(Hall.order("CLICK-B").get("state", "")) == "taken", "Enter still takes the selected order")
	ui.close()
	g.queue_free()
	await _frames(4)
	quit(1 if fails else 0)
