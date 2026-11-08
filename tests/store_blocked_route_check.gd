extends "res://tests/guide_check.gd"

func _initialize() -> void:
	Career.path = "user://zp_test_blocked_route_career.json"
	SaveGame.path = "user://zp_test_blocked_route_save.json"
	SaveGame.allow_test = true
	_run.call_deferred()

func _run() -> void:
	Career.data = SaveGame.read_career(Career.path)
	check(not Career.data.is_empty() and StoreBook.blocks_next_job(), "the copied career has goods waiting")
	if Career.data.is_empty() or not StoreBook.blocks_next_job():
		quit(1)
		return
	var id := "i:" + str(StoreBook.inbox()[0].uid)
	var pending := StoreBook.inbox().size()
	var cash := float(Career.data.money)
	await _spawn()
	g.open_console("terminal")
	await _frames(5)
	var term = g.console_ui
	term.set_tab(0)
	var index := -1
	for i in term.offers().size():
		var offer: Dictionary = term.offers()[i]
		if not offer.get("find", false) and not offer.get("queued", false):
			index = i
			break
	check(index >= 0, "an arrived ship can be selected")
	if index < 0:
		quit(1)
		return
	term.take(index)
	await _frames(5)
	var ui = g.console_ui
	check(ui != null and ui.has_method("sell_sel") and ui.sel == id, "blocked start opens the warehouse with the waiting item selected")
	check(StoreBook.inbox().size() == pending and is_equal_approx(float(Career.data.money), cash), "opening does not sell or modify the waiting cargo")
	if ui != null and ui.has_method("sell_sel"):
		ui.sell_sel()
		check(not StoreBook.blocks_next_job() and float(Career.data.money) > cash, "selling the selected item clears the blocker and pays")
	print("BLOCKED ROUTE: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
